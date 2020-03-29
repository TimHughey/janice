defmodule Switch.Command do
  @moduledoc false

  require Logger
  use Ecto.Schema

  import Ecto.Changeset

  use Janitor

  alias Switch.{Command, Device}

  @timestamps_opts [type: :utc_datetime_usec]

  schema "switch_command" do
    field(:sw_alias, :string)
    field(:refid, Ecto.UUID, autogenerate: true)
    field(:acked, :boolean, default: false)
    field(:orphan, :boolean, default: false)
    field(:rt_latency_us, :integer)
    field(:sent_at, :utc_datetime_usec)
    field(:ack_at, :utc_datetime_usec)

    embeds_one :log_opts, LogOpts do
      field(:log, :boolean, default: false)
      field(:cmd_rt, :boolean, default: false)
    end

    belongs_to(:device, Switch.Device,
      source: :device_id,
      references: :id,
      foreign_key: :device_id
    )

    timestamps()
  end

  def acked?(refid) do
    cmd = find_refid(refid)

    if is_nil(cmd), do: false, else: cmd.acked
  end

  # primary entry point when called from Switch and an ack is needed
  # the single parameter is the reading that has been processed by
  # Device.upsert/1

  # this function returns the reading passed in unchanged
  def ack_if_needed(
        %{
          cmdack: true,
          refid: refid,
          msg_recv_dt: recv_dt,
          processed: {:ok, %Device{}}
        } = r
      ) do
    #
    # base list of changes
    changes = [acked: true, ack_at: utc_now()]

    with {:cmd, %Command{sent_at: sent_at} = cmd} <- {:cmd, find_refid(refid)},
         latency <- Timex.diff(recv_dt, sent_at, :microsecond),
         _ignore <- record_cmd_rt_metric(cmd, latency),
         changes <- [rt_latency_us: latency] ++ changes,
         {:ok, %Command{} = cmd} <- update(cmd, changes) |> untrack() do
      #
      # simply log then return the reading unchanged
      # all work performed within the with conditions
      #
      log?(cmd) &&
        Logger.info(["ack_if_needed(): ", inspect(cmd, pretty: true)])

      r
    else
      # handle the exception case when the refid wasn't found
      # NOTE:  this case should only occur when MQTT messages are forwarded
      #        from another environment that is sending the actual commands
      {:cmd, nil} ->
        r

      error ->
        Logger.warn([
          "ack_if_needed() error: ",
          inspect(error, pretty: true),
          "reading: ",
          inspect(r, pretty: true)
        ])
    end
  end

  # primary entry point when called from Switch and an ack is not needed
  def ack_if_needed(%{processed: {:ok, %Device{}}} = r), do: r

  # error / unmatched function call handling
  def ack_if_needed(unhandled) do
    Logger.warn([
      "ack_if_needed() unhandleds: ",
      inspect(unhandled, pretty: true)
    ])

    unhandled
  end

  def ack_immediate_if_needed({:pending, res} = rc, opts)
      when is_list(res) and is_list(opts) do
    #
    # if ack: false (mcr expected to ack) then immediately ack
    #
    unless Keyword.get(opts, :ack, true) do
      cmd = Keyword.get(res, :refid) |> find_refid()

      if cmd do
        %Command{device: sd, refid: refid} = cmd

        %{
          cmdack: true,
          refid: refid,
          msg_recv_dt: utc_now(),
          processed: {:ok, sd}
        }
        |> Map.merge(Enum.into(opts, %{}))
        |> ack_if_needed()
      end
    end

    rc
  end

  def ack_immediate_if_needed(rc, _opts), do: rc

  def add(%Device{} = sd, sw_alias, %DateTime{} = dt)
      when is_binary(sw_alias) do
    Ecto.build_assoc(
      sd,
      :cmds
    )
    |> changeset(sent_at: dt, sw_alias: sw_alias, acked: false, orphan: false)
    |> Repo.insert!(returning: true)
    |> track()
  end

  def find_refid(refid) when is_binary(refid),
    do: Repo.get_by(__MODULE__, refid: refid) |> Repo.preload([:device])

  def find_refid(nil), do: nil

  def log?(%Command{log_opts: %__MODULE__.LogOpts{log: log}}), do: log

  def reload(%Command{id: id}), do: reload(id)

  def reload(id) when is_integer(id),
    do: Repo.get_by(__MODULE__, id: id) |> Repo.preload([:device])

  defp ensure_log_opts(%Command{log_opts: log_opts} = x) do
    if is_nil(log_opts),
      do: Map.put(x, :log_opts, %__MODULE__.LogOpts{}),
      else: x
  end

  defp changeset(pwmc, params) when is_list(params),
    do: changeset(pwmc, Enum.into(params, %{}))

  defp changeset(pwmc, params) when is_map(params) do
    pwmc
    |> ensure_log_opts()
    |> cast(params, cast_changes())
    |> cast_embed(:log_opts,
      with: &log_opts_changeset/2,
      required: true
    )
    |> validate_required([:sw_alias, :acked, :orphan, :sent_at])
    |> unique_constraint(:refid, name: :switch_command_refid_index)
  end

  defp log_opts_changeset(schema, params) when is_list(params) do
    log_opts_changeset(schema, Enum.into(params, %{}))
  end

  defp log_opts_changeset(schema, params) when is_map(params) do
    schema
    |> cast(params, [:log, :external_update, :cmd_rt, :dev_latency])
  end

  def update(refid, opts) when is_binary(refid) and is_list(opts) do
    cmd = find_refid(refid)

    if is_nil(cmd), do: {:not_found, refid}, else: update(cmd, opts)
  end

  def update(%Command{} = cmd, opts) when is_list(opts) do
    set = Keyword.take(opts, possible_changes()) |> Enum.into(%{})
    cs = changeset(cmd, set)

    if cs.valid?,
      do: {:ok, Repo.update!(cs, returning: true)},
      else: {:invalid_changes, cs}
  end

  defp record_cmd_rt_metric(%Command{sw_alias: device}, latency) do
    alias Fact.RunMetric

    RunMetric.record(
      module: "#{__MODULE__}",
      metric: "sw_cmd_rt_latency_us",
      device: device,
      val: latency
    )
  end

  #
  ## Changeset Helpers
  #
  defp cast_changes,
    do: [:sw_alias, :acked, :orphan, :refid, :rt_latency_us, :sent_at, :ack_at]

  defp possible_changes,
    do: [
      :acked,
      :orphan,
      :rt_latency_us,
      :sent_at,
      :ack_at,
      :log_opts
    ]
end
