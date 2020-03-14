defmodule SwitchState do
  @moduledoc """
    The SwitchState module provides the individual pio states for a Switch
  """

  require Logger
  use Ecto.Schema

  import Ecto.Changeset,
    only: [
      cast: 3,
      validate_required: 2,
      validate_format: 3,
      unique_constraint: 2
    ]

  import Repo, only: [get_by: 2, preload: 2, update!: 1, update: 1]

  use Janice.Common.DB
  # import Janice.Common.DB, only: [deprecated_name: 1, name_regex: 0]
  import Janice.TimeSupport, only: [ttl_expired?: 2]

  schema "switch_state" do
    field(:name, :string)
    field(:description, :string, default: "new switch")
    field(:pio, :integer, default: 0)
    field(:invert_state, :boolean, default: false)
    field(:state, :boolean, default: false)
    field(:ttl_ms, :integer)
    field(:log, :boolean, default: false)

    belongs_to(:switch, Switch)

    timestamps(usec: true)
  end

  def changeset(ss, params) do
    ss
    |> cast(params, possible_changes())
    |> validate_required(required_changes())
    |> validate_format(:name, name_regex())
    |> unique_constraint(:name)
  end

  def exists?([]), do: false

  def exists?(names) when is_list(names) do
    res = for n <- names, do: exists?(n)

    Enum.all?(res)
  end

  def exists?(name) when is_binary(name) do
    if is_nil(get_by(__MODULE__, name: name)), do: false, else: true
  end

  # def find(id) when is_integer(id),
  #   do: get_by(__MODULE__, id: id) |> preload(:switch)
  #
  # def find(name) when is_binary(name),
  #   do: get_by(__MODULE__, name: name) |> preload(:switch)

  def invert_position(name, invert)
      when is_binary(name) and is_boolean(invert),
      do: update(name, invert_state: invert)

  def position(name, opts \\ [])
      when is_binary(name) and is_list(opts) do
    lazy = Keyword.get(opts, :lazy, true)
    log = Keyword.get(opts, :log, false)
    position = Keyword.get(opts, :position, nil)

    with %SwitchState{state: curr_position} = ss <-
           find(name) |> preload([:switch]),
         # if the position opt was passed then an update is requested
         {:position, {:opt, true}, _ss} <-
           {:position, {:opt, is_boolean(position)}, ss},
         # the most typical scenario... lazy is true and current position
         # does not match the requsted position
         {:lazy, true, false, _ss} <-
           {:lazy, lazy, position == curr_position, ss} do
      # the requested position does not match the current posiion
      # so update it
      position_update([switch_state: ss, record_cmd: true] ++ opts)
    else
      {:position, {:opt, false}, %SwitchState{} = ss} ->
        # position change not included in opts, just return current position
        position_read([switch_state: ss] ++ opts)

      {:lazy, true, true, %SwitchState{} = ss} ->
        # requested lazy and requested position matches current position
        # nothing to do here... just return the position
        position_read([switch_state: ss] ++ opts)

      {:lazy, _lazy_or_not, _true_or_false, %SwitchState{} = ss} ->
        # regardless if lazy or not the current position does not match
        # the requested position so change the position
        position_update([switch_state: ss, record_cmd: true] ++ opts)

      nil ->
        log && Logger.warn([inspect(name), " not found"])
        {:not_found, name}
    end
  end

  def reload(%SwitchState{id: id}),
    do: Repo.get!(SwitchState, id) |> preload(:switch)

  def replace(x, y)
      when is_integer(x) or (is_binary(x) and is_integer(y)) or
             is_binary(y) do
    with {:was, %SwitchState{id: was_id, name: name, log: log}} <-
           {:was, find(x)},
         {:tobe, %SwitchState{id: tobe_id}} <- {:tobe, find(y)},
         {:ok, _name, _opts} <-
           update(was_id, name: deprecated_name(name), comment: "replaced"),
         {:ok, _name, _opts} <- update(tobe_id, name: name) do
      log &&
        Logger.info([
          inspect(was_id, pretty: true),
          " replaced by ",
          inspect(tobe_id, pretty: true)
        ])

      {:ok, name, [was_id: was_id, is_id: tobe_id]}
    else
      {:was, {:not_found, x} = rc} ->
        Logger.warn([inspect(x, pretty: true), " not found, nothing changed"])

        rc

      {:tobe, {:not_found, y} = rc} ->
        Logger.warn([
          "replacement ",
          inspect(y, pretty: true),
          " not found, nothing changed"
        ])

        rc

      rc ->
        Logger.warn(["unhandled error ", inspect(rc, pretty: true)])
        rc
    end
  end

  # toggle() header
  def toggle(name, opts \\ [])

  def toggle(name, opts) when is_binary(name),
    do: find(name) |> preload([:switch]) |> toggle(opts)

  def toggle(%SwitchState{name: name, state: position} = ss, opts) do
    position(name, lazy: true, position: not position)

    for_ms = Keyword.get(opts, :for_ms, 0)

    if for_ms > 0 do
      Process.sleep(for_ms)
      position(ss, lazy: true, position: position)
    end
  end

  def toggle(nil, _opts), do: {:error, :not_found}

  def update(x, opts) when is_binary(x) or (is_integer(x) and is_list(opts)) do
    case find(x) |> preload([:switch]) do
      %SwitchState{log: log} = ss ->
        log && Logger.info([inspect(x, pretty: true), " found for update"])
        update(ss, opts)

      nil ->
        Logger.warn([inspect(x, pretty: true), " not found for update"])
        {:not_found, x}

      error ->
        Logger.warn([
          inspect(x, pretty: true),
          " unhandled condition ",
          inspect(error, pretty: true)
        ])

        {:error, error}
    end
  end

  def update(%SwitchState{name: name, log: log} = ss, opts)
      when is_list(opts) do
    params = possible_changes(opts)

    with {:params, true} <- {:params, not Enum.empty?(opts)},
         {:changeset, cs} <-
           {:changeset, changeset(ss, params)},
         {:cs_valid, true, _cs} <- {:cs_valid, cs.valid?(), cs},
         {:update, {:ok, %SwitchState{}}} <- {:update, update(cs)} do
      log &&
        Logger.info([
          inspect(name, pretty: true),
          " update successful ",
          inspect(opts, pretty: true)
        ])

      {:ok, name, params}
    else
      {:params, false} ->
        log &&
          Logger.warn([
            inspect(name, pretty: true),
            " no updates specified in ",
            inspect(opts, pretty: true)
          ])

        {:bad_params, params}

      {:cs_valid, false, cs} ->
        log &&
          Logger.warn([
            inspect(name, pretty: true),
            " invalid changes ",
            inspect(cs, pretty: true)
          ])

        {:invalid_changes, cs}

      {:update, rc} ->
        log &&
          Logger.warn([
            inspect(name, pretty: true),
            " update failed ",
            inspect(rc, pretty: true)
          ])

        {:failed, rc}

      error ->
        log &&
          Logger.warn([
            inspect(name, pretty: true),
            "update unhandled error ",
            inspect(error, pretty: true)
          ])

        {:error, error}
    end
  end

  defp invert_position_if_needed(%SwitchState{
         invert_state: true,
         state: position
       }),
       do: not position

  defp invert_position_if_needed(%SwitchState{
         invert_state: false,
         state: position
       }),
       do: position

  defp invert_position_if_needed(position, %SwitchState{
         invert_state: true
       })
       when is_boolean(position),
       do: not position

  defp invert_position_if_needed(position, %SwitchState{
         invert_state: false
       })
       when is_boolean(position),
       do: position

  defp position_read(opts) do
    ss =
      %SwitchState{switch: switch, ttl_ms: ttl_ms} =
      Keyword.get(opts, :switch_state)

    if ttl_expired?(Switch.last_seen_at(switch), ttl_ms),
      do: {:ttl_expired, invert_position_if_needed(ss)},
      else: {:ok, invert_position_if_needed(ss)}
  end

  defp position_update(opts) do
    ss = %SwitchState{pio: pio} = Keyword.get(opts, :switch_state)
    position = Keyword.get(opts, :position) |> invert_position_if_needed(ss)

    opts = [cmd_map: %{pio: pio, state: position}] ++ opts

    changeset(ss, %{state: position})
    |> update!()
    |> reload()
    |> SwitchCmd.record_cmd(opts)
    |> position_read()
  end

  defp possible_changes,
    do: [:name, :description, :state, :invert_state, :ttl_ms, :log]

  defp possible_changes(opts) when is_list(opts),
    do: Keyword.take(opts, possible_changes()) |> Enum.into(%{})

  defp required_changes, do: possible_changes()
end
