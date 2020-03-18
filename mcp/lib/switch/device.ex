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

  alias Janice.TimeSupport
  alias __MODULE__

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
    field(:discovered_at, :utc_datetime_usec)
    field(:last_cmd_at, :utc_datetime_usec)
    field(:last_seen_at, :utc_datetime_usec)

    embeds_one :log_opts, LogOpts do
      field(:log, :boolean, default: false)
      field(:external_update, :boolean, default: false)
      field(:cmd_rt, :boolean, default: false)
      field(:dev_latency, :boolean, default: false)
    end

    has_many(:cmds, Switch.Command, foreign_key: :dev_id, on_delete: :delete_all)

    timestamps()
  end

  def add(list) when is_list(list) do
    for %Device{} = x <- list do
      upsert(x, x)
    end
  end

  def delete_all(:dangerous) do
    for x <- from(y in __MODULE__, select: [:id]) |> Repo.all() do
      Repo.delete(x)
    end
  end

  def exists?(device, pio) when is_binary(device) and is_integer(pio) do
    {rc, _res} = pio_state(device, pio)

    if rc in [:ok, :ttl_expired], do: true, else: false
  end

  def find(id) when is_integer(id),
    do: Repo.get_by(__MODULE__, id: id)

  def find(device) when is_binary(device),
    do: Repo.get_by(__MODULE__, device: device)

  def pio_count(device) when is_binary(device) do
    sd = find(device)

    if is_nil(sd),
      do: {:not_found, device},
      else: Enum.count(Map.get(sd, :states))
  end

  def pio_state(device, pio, opts \\ [])
      when is_binary(device) and
             is_integer(pio) and
             pio >= 0 and
             is_list(opts) do
    sd = find(device)
    new_state = Keyword.get(opts, :state, nil)

    cond do
      is_nil(sd) ->
        {:not_found, device}

      is_nil(new_state) ->
        actual_pio_state(:get, sd, pio, opts)

      is_boolean(new_state) ->
        actual_pio_state(:set, sd, pio, opts)

      true ->
        {:bad_args, {:pio_state, :state_must_be_boolean, new_state}}
    end
  end

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
          discovered_at: TimeSupport.from_unix(mtime),
          last_cmd_at: TimeSupport.utc_now(),
          last_seen_at: TimeSupport.utc_now()
        }
      )

    # return the reading with :processed to the the results of the update
    # to signal to other modules the reading has been processed
    Map.put(r, :processed, upsert(%Device{}, changes))
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
    replace_cols = [:host, :states, :dev_latency_us, :last_seen_at, :updated_at]

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

  defp actual_pio_state(:get, %Device{device: device} = sd, pio, opts) do
    alias Switch.Device.State

    find_fn = fn %State{pio: p} -> p == pio end

    with %Device{states: states, last_seen_at: seen_at, ttl_ms: ttl_ms} <- sd,
         %State{state: state} <- Enum.find(states, find_fn) do
      TimeSupport.ttl_check(seen_at, state, ttl_ms, opts)
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
