defmodule Switch.Device do
  @moduledoc false

  require Logger
  use Ecto.Schema

  import Ecto.Changeset,
    only: [
      cast: 3,
      cast_embed: 3,
      validate_required: 2,
      validate_format: 3,
      validate_number: 3,
      unique_constraint: 3
    ]

  import Ecto.Query, only: [from: 2]
  import Janice.Common.DB, only: [name_regex: 0]
  import Janice.TimeSupport, only: [from_unix: 1, ttl_check: 4, utc_now: 0]
  import Mqtt.Client, only: [publish_cmd: 1]

  alias Mqtt.SetSwitch
  alias Switch.{Alias, Device, Command}

  @timestamps_opts [type: :utc_datetime_usec]

  schema "switch_device" do
    field(:device, :string)
    field(:host, :string)

    embeds_many :states, State do
      field(:pio, :integer, default: nil)
      field(:state, :boolean, default: false)
    end

    field(:dev_latency_us, :integer)
    field(:ttl_ms, :integer, default: 60_000)
    field(:last_seen_at, :utc_datetime_usec)
    field(:last_cmd_at, :utc_datetime_usec)
    field(:discovered_at, :utc_datetime_usec)

    embeds_one :log_opts, LogOpts do
      field(:log, :boolean, default: false)
      field(:external_update, :boolean, default: false)
      field(:cmd_rt, :boolean, default: false)
      field(:dev_latency, :boolean, default: false)
    end

    has_many(:cmds, Command, foreign_key: :device_id, references: :id)

    has_many(:aliases, Alias, foreign_key: :device_id, references: :id)

    timestamps()
  end

  def add(list) when is_list(list) do
    for %Device{} = x <- list do
      upsert(x, x)
    end
  end

  def add_cmd(%Device{} = sd, sw_alias, %DateTime{} = dt)
      when is_binary(sw_alias) do
    sd = reload(sd)
    %Command{refid: refid} = Command.add(sd, sw_alias, dt)

    {rc, sd} = upsert(sd, last_cmd_at: dt)

    cmd_query = from(c in Command, where: c.refid == ^refid)

    if rc == :ok,
      do:
        {:ok,
         reload(sd)
         |> Repo.preload(cmds: cmd_query)},
      else: {rc, sd}
  end

  def alias_from_legacy(
        %{name: name, pio: pio, switch: %{device: device}} = legacy
      ) do
    extra_opts =
      Map.take(legacy, [:description, :invert_state, :ttl_ms]) |> Enum.into([])

    opts = [create: true, name: name, pio: pio] ++ extra_opts

    dev_alias(device, opts)
  end

  def dev_alias(device, opts) when is_binary(device) and is_list(opts) do
    sd = find(device)

    if is_nil(sd), do: {:not_found, device}, else: dev_alias(sd, opts)
  end

  def dev_alias(%Device{aliases: aliases} = sd, opts) when is_list(opts) do
    create = Keyword.get(opts, :create, false)
    alias_name = Keyword.get(opts, :name)
    pio = Keyword.get(opts, :pio)
    {exists_rc, sa} = find_alias_by_pio(sd, pio)

    check_args =
      is_binary(alias_name) and is_integer(pio) and pio >= 0 and
        pio < pio_count(sd)

    cond do
      check_args == false ->
        {:bad_args, sd, opts}

      create and exists_rc == :ok ->
        Alias.rename(sa, [name: alias_name] ++ opts)

      create ->
        Alias.create(sd, alias_name, pio, opts)

      true ->
        find_alias(sd, alias_name, pio, opts)
    end
  end

  def exists?(device, pio) when is_binary(device) and is_integer(pio) do
    {rc, _res} = pio_state(device, pio)

    if rc in [:ok, :ttl_expired], do: true, else: false
  end

  def find(id) when is_integer(id) do
    Repo.get_by(__MODULE__, id: id)
    |> preload_unacked_cmds()
    |> Repo.preload(:aliases)
  end

  def find(device) when is_binary(device) do
    Repo.get_by(__MODULE__, device: device)
    |> preload_unacked_cmds()
    |> Repo.preload(:aliases)
  end

  def find_alias(
        %Device{aliases: aliases},
        alias_name,
        alias_pio,
        _opts \\ []
      )
      when is_binary(alias_name) and is_integer(alias_pio) and alias_pio >= 0 do
    found =
      for %Alias{name: name, pio: pio} = x
          when name == alias_name and pio == alias_pio <- aliases,
          do: x

    if Enum.empty?(found),
      do: {:not_found, {alias_name, alias_pio}},
      else: {:ok, hd(found)}
  end

  def find_alias_by_pio(
        %Device{aliases: aliases},
        alias_pio,
        _opts \\ []
      )
      when is_integer(alias_pio) and alias_pio >= 0 do
    found =
      for %Alias{pio: pio} = x
          when pio == alias_pio <- aliases,
          do: x

    if Enum.empty?(found),
      do: {:not_found, {alias_pio}},
      else: {:ok, hd(found)}
  end

  def log?(%Device{log_opts: %{log: log}}), do: log

  def pio_count(%Device{states: states}), do: Enum.count(states)

  def pio_count(device) when is_binary(device) do
    sd = find(device)

    if is_nil(sd),
      do: {:not_found, device},
      else: pio_count(sd)
  end

  # function header
  def pio_state(device, pio, opts \\ [])

  def pio_state(device, pio, opts)
      when is_binary(device) and
             is_integer(pio) and
             pio >= 0 and
             is_list(opts) do
    sd = find(device)

    if is_nil(sd), do: {:not_found, device}, else: pio_state(sd, pio, opts)
  end

  def pio_state(%Device{} = sd, pio, opts)
      when is_integer(pio) and
             pio >= 0 and
             is_list(opts) do
    actual_pio_state(sd, pio, opts)
  end

  def record_cmd(%Device{} = sd, %Alias{name: sw_alias}, opts)
      when is_list(opts) do
    publish = true

    sd = reload(sd)

    with %{state: state, pio: pio} <-
           Keyword.get(opts, :cmd_map, {:bad_args, opts}),
         {:ok, %Device{device: device} = sd} <-
           add_cmd(sd, sw_alias, utc_now()),
         # NOTE: add_cmd/3 returns the Device with the new Command preloaded
         {:cmd, %Command{refid: refid} = cmd} <- {:cmd, hd(sd.cmds)},
         {:refid, true} <- {:refid, is_binary(refid)},
         {:publish, true} <- {:publish, publish} do
      rc =
        SetSwitch.new_cmd(device, %{pio: pio, state: state}, refid, opts)
        |> publish_cmd()

      log?(sd) &&
        Logger.info([
          "record_cmd() rc: ",
          inspect(rc, pretty: true),
          "cmd: ",
          inspect(cmd, pretty: true)
        ])

      {:pending,
       [
         position: state,
         refid: refid,
         pub_rc: rc
       ]}
    else
      error ->
        Logger.warn(["record_cmd() error: ", inspect(error, pretty: true)])
        {:error, [error]}
    end
  end

  def reload(%Device{id: id}) do
    Repo.get_by!(__MODULE__, id: id)
    |> preload_unacked_cmds()
    |> Repo.preload(:aliases)
  end

  def reload(nil), do: nil

  # Readings from External Sources

  # Processing of Readings from external sources is performed by
  # calling update/1 of interested modules.  When the :processed key is false
  # the Reading hasn't been processed by another module.

  # If update/1 is called with processed: false and type: "switch" then attempt
  # to process the Reading.  Switch.Device is not interested in Readings
  # other than those of type "switch"
  def upsert(
        %{
          processed: false,
          type: "switch",
          device: _device,
          host: _host,
          mtime: mtime,
          states: _states
        } = r
      ) do
    what_to_change = [:device, :host, :states, :dev_latency_us, :ttl_ms]

    changes =
      Map.merge(
        Map.take(r, what_to_change),
        # NOTE: the second map passed to Map.merge/2 replaces duplicate
        #       keys which is the intended behavior in this instance.
        %{
          discovered_at: from_unix(mtime),
          last_cmd_at: utc_now(),
          last_seen_at: utc_now()
        }
      )

    # return reading:
    #   1. add the upsert results to the map (processed: {rc, res}) to signal
    #      other modules in the pipeline that the reading was processed
    #   2. send the reading to Command.ack_if_needed/1 to handle tracking
    #      of the command
    Map.put(r, :processed, upsert(%Device{}, changes))
    |> Command.ack_if_needed()
  end

  def upsert(%{processed: _anything} = r),
    do: r

  def upsert(catchall), do: {:bad_args, catchall}

  # support Keyword list of updates
  def upsert(%Device{} = x, params) when is_list(params),
    do: upsert(x, Enum.into(params, %{}))

  # Device.update/2 will update a %Device{} using the map passed in
  def upsert(%Device{} = x, params) when is_map(params) do
    cs = changeset(x, Map.take(params, possible_changes()))

    replace_cols = [
      :host,
      :states,
      :dev_latency_us,
      :last_seen_at,
      :last_cmd_at,
      :updated_at,
      :ttl_ms
    ]

    with {:cs_valid, true} <- {:cs_valid, cs.valid?()},
         # the keys on_conflict: and conflict_target: indicate the insert
         # is an "upsert"
         {:ok, %Device{id: _id} = x} <-
           Repo.insert(cs,
             on_conflict: {:replace, replace_cols},
             returning: true,
             conflict_target: :device
           ) do
      {:ok, x}
    else
      {:cs_valid, false} ->
        {:invalid_changes, cs}

      {:error, rc} ->
        {:error, rc}

      error ->
        error
    end
    |> check_result(x, __ENV__)
  end

  defp actual_pio_state(%Device{device: device} = sd, pio, opts) do
    alias Switch.Device.State

    find_fn = fn %State{pio: p} -> p == pio end

    with %Device{states: states, last_seen_at: seen_at, ttl_ms: ttl_ms} <- sd,
         %State{state: state} <- Enum.find(states, find_fn) do
      ttl_check(seen_at, state, ttl_ms, opts)
    else
      _anything ->
        {:bad_pio, {device, pio}}
    end
  end

  defp changeset(x, params) when is_list(params) do
    changeset(x, Enum.into(params, %{}))
  end

  defp changeset(x, params) when is_map(params) do
    x
    |> ensure_log_opts()
    |> cast(params, cast_changes())
    |> cast_embed(:states, with: &states_changeset/2, required: true)
    |> cast_embed(:log_opts,
      with: &log_opts_changeset/2,
      required: true
    )
    |> validate_required(possible_changes())
    |> validate_format(:device, name_regex())
    |> validate_format(:host, name_regex())
    |> validate_number(:dev_latency_us, greater_than_or_equal_to: 0)
    |> validate_number(:ttl_ms,
      greater_than_or_equal_to: 0
    )
    |> unique_constraint(:device, name: :switch_device_device_index)
  end

  defp check_result(res, x, env) do
    case res do
      # all is well, simply return the res
      {:ok, %Device{}} ->
        true

      {:invalid_changes, cs} ->
        Logger.warn([
          caller(env),
          " invalid changes: ",
          inspect(cs, pretty: true)
        ])

      {:error, rc} ->
        Logger.warn([
          caller(env),
          " failed rc: ",
          inspect(rc, pretty: true),
          " for: ",
          inspect(x, pretty: true)
        ])

      true ->
        Logger.warn([
          caller(env),
          " error: ",
          inspect(res, pretty: true),
          " for: ",
          inspect(x, pretty: true)
        ])
    end

    res
  end

  defp ensure_log_opts(%Device{log_opts: rtm} = x) do
    if is_nil(rtm),
      do: Map.put(x, :log_opts, %Device.LogOpts{}),
      else: x
  end

  defp caller(%{function: {func, arity}}),
    do: [Atom.to_string(func), "/", Integer.to_string(arity)]

  # defp log?(%Device{log_opts: opts}), do: Keyword.get(opts, :log, false)

  defp preload_unacked_cmds(sd, limit \\ 1)
       when is_integer(limit) and limit >= 1 do
    alias Switch.Command

    Repo.preload(sd,
      cmds:
        from(sc in Command,
          where: sc.acked == false,
          order_by: [desc: sc.inserted_at],
          limit: ^limit
        )
    )
  end

  #
  # Changeset Functions
  #

  defp log_opts_changeset(schema, params) when is_list(params) do
    log_opts_changeset(schema, Enum.into(params, %{}))
  end

  defp log_opts_changeset(schema, params) when is_map(params) do
    schema
    |> cast(params, [:log, :external_update, :cmd_rt, :dev_latency])
  end

  defp states_changeset(schema, params) do
    schema
    |> cast(params, [:pio, :state])
  end

  #
  # Changeset Lists
  #

  defp cast_changes,
    do: [
      :device,
      :host,
      :dev_latency_us,
      :ttl_ms,
      :discovered_at,
      :last_cmd_at,
      :last_seen_at
    ]

  defp possible_changes,
    do: [
      :device,
      :host,
      :states,
      :dev_latency_us,
      :ttl_ms,
      :discovered_at,
      :last_cmd_at,
      :last_seen_at,
      :log_opts
    ]
end
