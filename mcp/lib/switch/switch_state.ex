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

  import Ecto.Query, only: [from: 2]
  import Repo, only: [all: 2, get_by: 2, preload: 2, update!: 1, update: 1]

  import Janice.Common.DB, only: [name_regex: 0]
  import Janice.TimeSupport, only: [ttl_expired?: 2]

  schema "switch_state" do
    field(:name, :string)
    field(:description, :string, default: "new switch")
    field(:pio, :integer, default: 0)
    field(:state, :boolean, default: false)
    field(:ttl_ms, :integer)

    belongs_to(:switch, Switch)

    timestamps(usec: true)
  end

  def all(:names) do
    from(ss in SwitchState, select: ss.name) |> all(timeout: 100)
  end

  def all(:everything) do
    from(
      ss in SwitchState,
      join: sw in assoc(ss, :switch),
      order_by: [ss.name],
      preload: [switch: sw]
    )
    |> all(timeout: 100)
  end

  def as_map(%SwitchState{} = ss), do: %{pio: ss.pio, state: ss.state}

  def as_list_of_maps(list) when is_list(list),
    do: for(ss <- list, do: as_map(ss))

  def browse do
    sorted = all(:everything) |> Enum.sort(fn a, b -> a.name <= b.name end)

    Scribe.console(sorted,
      data: [
        {"ID", :id},
        {"Name", :name},
        {"Device", fn x -> x.switch.device end},
        {"Last Seen",
         fn x -> Timex.format!(x.switch.last_seen_at, "{RFC3339z}") end}
      ]
    )
  end

  def changeset(ss, params) do
    # validate name:
    #  -starts with a ~ or alpha char
    #  -contains a mix of:
    #      alpha numeric, slash (/), dash (-), underscore (_), colon (:) and
    #      spaces
    #  -ends with an alpha char
    ss
    |> cast(params, [:name, :description, :state])
    |> validate_required([:name])
    |> validate_format(:name, name_regex())
    |> unique_constraint(:name)
  end

  def change_name(id, to_be, comment \\ "")

  def change_name(id, tobe, comment) when is_integer(id) do
    ss = get_by(SwitchState, id: id)

    if is_nil(ss) do
      Logger.info(fn -> "change name failed" end)
      {:error, :not_found}
    else
      ss
      |> changeset(%{name: tobe, description: comment})
      |> update()
    end
  end

  def change_name(asis, tobe, comment)
      when is_binary(asis) and is_binary(tobe) do
    ss = get_by(SwitchState, name: asis)

    if is_nil(ss) do
      {:error, :not_found}
    else
      ss
      |> changeset(%{name: tobe, description: comment})
      |> update()
    end
  end

  def deprecate(id) when is_integer(id) do
    ss = get_by(SwitchState, id: id)

    if is_nil(ss) do
      Logger.warn(fn -> "deprecate(#{id}) failed" end)
      {:error, :not_found}
    else
      tobe = "~ #{ss.name}-#{Timex.now() |> Timex.format!("{ASN1:UTCtime}")}"

      ss
      |> changeset(%{name: tobe, description: "deprecated"})
      |> update()
    end
  end

  def deprecate(:help), do: deprecate()

  def deprecate do
    IO.puts("Usage:")
    IO.puts("\tSwitchState.deprecate(id)")
  end

  def exists?([]), do: false

  def exists?(names) when is_list(names) do
    res = for n <- names, do: exists?(n)

    Enum.all?(res)
  end

  def exists?(name) when is_binary(name) do
    if is_nil(get_by(__MODULE__, name: name)), do: false, else: true
  end

  def find(name) when is_binary(name),
    do: get_by(__MODULE__, name: name) |> preload(:switch)

  def position(name, opts \\ [])
      when is_binary(name) and is_list(opts) do
    lazy = Keyword.get(opts, :lazy, true)
    log = Keyword.get(opts, :log, false)
    position = Keyword.get(opts, :position, nil)

    with %SwitchState{state: curr_position} = ss <- find(name),
         # if the position opt was passed then an update is requested
         {:position, {:opt, true}, _ss} <-
           {:position, {:opt, is_boolean(position)}, ss},
         # the most typical scenario... lazy is true and current position
         # does not match the requsted position
         {:lazy, true, false, _ss} <-
           {:lazy, lazy, position == curr_position, ss} do
      # the requested position does not match the current posiion
      # so update it
      position_update([switch_state: ss] ++ opts)
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
        position_update([switch_state: ss] ++ opts)

      nil ->
        log && Logger.warn("#{inspect(name)} not found")
        {:not_found, name}
    end
  end

  defp position_read(opts) do
    %SwitchState{state: position, switch: switch, ttl_ms: ttl_ms} =
      Keyword.get(opts, :switch_state)

    if ttl_expired?(Switch.last_seen_at(switch), ttl_ms),
      do: {:ttl_expired, position},
      else: {:ok, position}
  end

  defp position_update(opts) do
    ss = Keyword.get(opts, :switch_state)
    position = Keyword.get(opts, :position)

    changeset(ss, %{state: position})
    |> update!()
    |> SwitchCmd.record_cmd(opts)
    |> position_read()
  end

  def reload(%SwitchState{id: id}),
    do: Repo.get!(SwitchState, id) |> preload(:switch)

  # toggle() header
  def toggle(name, opts \\ [])

  def toggle(name, opts) when is_binary(name),
    do: find(name) |> toggle(opts)

  def toggle(%SwitchState{name: name, state: position} = ss, opts) do
    position(name, lazy: true, position: not position)

    for_ms = Keyword.get(opts, :for_ms, 0)

    if for_ms > 0 do
      Process.sleep(for_ms)
      position(ss, lazy: true, position: position)
    end
  end

  def toggle(nil, _opts), do: {:error, :not_found}
end
