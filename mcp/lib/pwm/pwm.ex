defmodule PulseWidth do
  @moduledoc """
    The Sensor module provides the base of a sensor reading.
  """

  require Logger
  use Timex
  use Ecto.Schema

  import Ecto.Changeset,
    only: [
      cast: 3,
      validate_required: 2,
      validate_format: 3,
      validate_number: 3,
      unique_constraint: 3
    ]

  import Ecto.Query, only: [from: 2]

  import Janice.Common.DB, only: [name_regex: 0]
  import Janice.TimeSupport, only: [from_unix: 1, ttl_expired?: 2, utc_now: 0]
  import Mqtt.Client, only: [publish_cmd: 1]

  alias Mqtt.SetPulseWidth

  schema "pwm" do
    field(:name, :string)
    field(:description, :string)
    field(:device, :string)
    field(:host, :string)
    field(:duty, :integer)
    field(:duty_max, :integer)
    field(:duty_min, :integer)
    field(:dev_latency_us, :integer)
    field(:log, :boolean, default: false)
    field(:ttl_ms, :integer, default: 60_000)
    field(:reading_at, :utc_datetime_usec)
    field(:last_seen_at, :utc_datetime_usec)
    field(:metric_at, :utc_datetime_usec, default: nil)
    field(:metric_freq_secs, :integer, default: 60)
    field(:discovered_at, :utc_datetime_usec)
    field(:last_cmd_at, :utc_datetime_usec)

    has_many(:cmds, PulseWidthCmd, foreign_key: :pwm_id)

    timestamps(usec: true)
  end

  def add(%{device: device, host: _host, mtime: mtime} = r) do
    keys = [:device, :host, :duty, :duty_max, :duty_min]

    pwm = %PulseWidth{
      # the PulseWidth name defaults to the device when adding
      name: device,
      reading_at: from_unix(mtime),
      last_seen_at: from_unix(mtime),
      discovered_at: from_unix(mtime)
    }

    [Map.merge(pwm, Map.take(r, keys))] |> add()
  end

  def add(list) when is_list(list) do
    for %PulseWidth{} = p <- list do
      add(p)
    end
  end

  def add(%PulseWidth{name: _name, device: device} = p) do
    cs = changeset(p, Map.take(p, possible_changes()))

    with {:cs_valid, true} <- {:cs_valid, cs.valid?()},
         {:ok, %PulseWidth{id: _id}} <-
           Repo.insert(cs,
             on_conflict: :replace_all,
             conflict_target: :device
           ),
         %PulseWidth{} = pwm <- find_by_device(device) do
      {:ok, pwm}
    else
      {:cs_valid, false} ->
        Logger.warn([
          "add() invalid changes: ",
          inspect(cs, pretty: true)
        ])

        {:invalid_changes, cs}

      {:error, rc} ->
        Logger.warn([
          "add() failed to insert: ",
          inspect(p, pretty: true),
          " rc: ",
          inspect(rc, pretty: true)
        ])

      error ->
        Logger.warn(["add() failure: ", inspect(error, pretty: true)])

        {:failed, error}
    end
  end

  def add(catchall), do: {:bad_args, catchall}

  def add_cmd(%PulseWidth{} = pwm, %DateTime{} = dt) do
    cmd = PulseWidthCmd.add(pwm, dt)

    {rc, pwm} = update(pwm, last_cmd_at: dt)

    cmd_query = from(c in PulseWidthCmd, where: c.refid == ^cmd.refid)

    if rc == :ok,
      do: {:ok, Repo.preload(pwm, cmds: cmd_query)},
      else: {rc, pwm}
  end

  def delete_all(:dangerous) do
    for pwm <- from(pwm in PulseWidth, select: [:id]) |> Repo.all() do
      Repo.delete(pwm)
    end
  end

  def duty(name, opts \\ [])
      when is_binary(name) and is_list(opts) do
    lazy = Keyword.get(opts, :lazy, true)
    log = Keyword.get(opts, :log, false)
    duty = Keyword.get(opts, :duty, nil)

    with %PulseWidth{duty: curr_duty} = pwm <- find(name),
         # if the duty opt was passed then an update is requested
         {:duty, {:opt, true}, _ss} <-
           {:duty, {:opt, is_integer(duty)}, pwm},
         # the most typical scenario... lazy is true and current duty
         # does not match the requsted duty
         {:lazy, true, false, _ss} <-
           {:lazy, lazy, duty == curr_duty, pwm} do
      # the requested duty does not match the current duty, update it
      duty_update([pwm: pwm, record_cmd: true] ++ opts)
    else
      {:duty, {:opt, false}, %PulseWidth{} = pwm} ->
        # duty change not included in opts, just return current duty
        duty_read([pwm: pwm] ++ opts)

      {:lazy, true, true, %PulseWidth{} = pwm} ->
        # requested lazy and requested duty matches current duty
        # nothing to do here... just return the duty
        duty_read([pwm: pwm] ++ opts)

      {:lazy, _lazy_or_not, _true_or_false, %PulseWidth{} = pwm} ->
        # regardless if lazy or not the current duty does not match
        # the requested duty, update it
        duty_update([pwm: pwm, record_cmd: true] ++ opts)

      nil ->
        log && Logger.warn([inspect(name), " not found"])
        {:not_found, name}
    end
  end

  # when processing an external update the reading map will contain
  # the actual %PulseWidth{} struct when it has been found (already exists)
  # in this case perform the appropriate updates
  def external_update(
        %PulseWidth{} = pwm,
        %{
          duty: _duty,
          duty_max: _duty_max,
          duty_min: _duty_min,
          host: _host,
          mtime: mtime,
          msg_recv_dt: msg_recv_at
        } = r
      ) do
    set =
      Enum.into(Map.take(r, external_changes()), []) ++
        [last_seen_at: msg_recv_at, reading_at: from_unix(mtime)]

    update(pwm, set) |> PulseWidthCmd.ack_if_needed(r)
  end

  # when processing an external update and pulse_width is nil this is a
  # previously unknown %PulseWidth{}
  def external_update(nil, %{} = r) do
    add(r)
  end

  # this is the entry point for a raw incoming message before attempting to
  # find the matching %PulseWidth{} struct from the database
  def external_update(%{device: device} = r) do
    find_by_device(device) |> external_update(r)
  end

  def external_update(catchall),
    do:
      Logger.warn([
        "external_update() unhandled msg: ",
        inspect(catchall, pretty: true)
      ])

  def find(id) when is_integer(id),
    do: Repo.get_by(__MODULE__, id: id)

  def find(name) when is_binary(name),
    do: Repo.get_by(__MODULE__, name: name)

  def find_by_device(device) when is_binary(device),
    do: Repo.get_by(__MODULE__, device: device)

  def reload({:ok, %PulseWidth{id: id}}), do: reload(id)

  def reload(%PulseWidth{id: id}), do: reload(id)

  def reload(id) when is_number(id), do: Repo.get!(__MODULE__, id)

  def reload(catchall) do
    Logger.warn(["update() failed: ", inspect(catchall, pretty: true)])
    {:error, catchall}
  end

  def update(name, opts) when is_binary(name) and is_list(opts) do
    pwm = find(name)

    if is_nil(pwm), do: {:not_found, name}, else: update(pwm, opts)
  end

  def update(%PulseWidth{} = pwm, opts) when is_list(opts) do
    set = Keyword.take(opts, possible_changes()) |> Enum.into(%{})

    cs = changeset(pwm, set)

    if cs.valid?,
      do: {:ok, Repo.update(cs, stale_error_field: :stale_error) |> reload()},
      else: {:invalid_changes, cs}
  end

  defp changeset(pwm, params) when is_list(params),
    do: changeset(pwm, Enum.into(params, %{}))

  defp changeset(pwm, params) when is_map(params) do
    pwm
    |> cast(params, possible_changes())
    |> validate_required(required_changes())
    |> validate_format(:name, name_regex())
    |> validate_number(:duty, greater_than_or_equal_to: 0, less_than: 4096)
    |> validate_number(:duty_min,
      greater_than_or_equal_to: 0,
      less_than: 4096
    )
    |> validate_number(:duty_max,
      greater_than_or_equal_to: 0,
      less_than: 4096
    )
    |> unique_constraint(:name, name: :pwm_name_index)
    |> unique_constraint(:device, name: :pwm_device_index)
  end

  defp duty_read(opts) do
    pwm = %PulseWidth{duty: duty, ttl_ms: ttl_ms} = Keyword.get(opts, :pwm)

    if ttl_expired?(last_seen_at(pwm), ttl_ms),
      do: {:ttl_expired, duty},
      else: {:ok, duty}
  end

  defp duty_update(opts) do
    pwm = %PulseWidth{} = Keyword.get(opts, :pwm)
    duty = Keyword.get(opts, :duty)

    {rc, pwm} = update(pwm, duty: duty)

    if rc == :ok do
      opts = [cmd_map: %{duty: duty}] ++ opts
      record_cmd(pwm, opts) |> duty_read()
    else
      {rc, pwm}
    end
  end

  defp last_seen_at(%PulseWidth{last_seen_at: x}), do: x

  defp record_cmd(%PulseWidth{log: log} = pwm, opts) when is_list(opts) do
    publish = Keyword.get(opts, :publish, true)
    duty = Keyword.get(opts, :cmd_map) |> Map.get(:duty)

    with {:ok, %PulseWidth{device: device} = pwm} <- add_cmd(pwm, utc_now()),
         {:cmd, %PulseWidthCmd{} = cmd} <- {:cmd, hd(pwm.cmds)},
         {:refid, refid} <- {:refid, Map.get(cmd, :refid)},
         {:publish, true} <- {:publish, publish},
         %{cmd: _} = cmd <-
           SetPulseWidth.new_cmd(device, duty, refid, opts) do
      rc = SetPulseWidth.json(cmd) |> publish_cmd()

      log &&
        Logger.info([
          "record_cmd() rc: ",
          inspect(rc, pretty: true),
          "cmd: ",
          inspect(cmd, pretty: true)
        ])

      [pwm: pwm] ++ opts
    else
      error ->
        Logger.warn(["record_cmd() error: ", inspect(error, pretty: true)])
        {:error, error}
    end
  end

  # Lists of possible changes for Changeset

  # everything EXCEPT for t%PulseWidth{name: _} can be updated based on the
  # message from the Remote device
  defp external_changes,
    do: [
      :host,
      :duty,
      :duty_max,
      :duty_min,
      :dev_latency_us
    ]

  defp possible_changes,
    do: [
      :name,
      :description,
      :device,
      :host,
      :duty,
      :duty_max,
      :duty_min,
      :dev_latency_us,
      :log,
      :ttl_ms,
      :reading_at,
      :last_seen_at,
      :metric_at,
      :metric_freq_secs,
      :discovered_at,
      :last_cmd_at
    ]

  defp required_changes,
    do: [
      :name,
      :device,
      :host,
      :duty,
      :duty_max,
      :duty_min
    ]
end
