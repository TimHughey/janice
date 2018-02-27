defmodule SwitchState do
  @moduledoc """
    The SwitchState module provides the individual pio states for a Switch
  """

  require Logger
  use Timex
  use Timex.Ecto.Timestamps
  use Ecto.Schema

  # import Ecto.Changeset, only: [cast: 2, change: 2]
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  import Repo, only: [all: 2, get: 2, update!: 1, update: 1, one: 1]

  schema "switch_state" do
    field(:name, :string)
    field(:description, :string, default: "new switch")
    field(:pio, :integer, default: 0)
    field(:state, :boolean, default: nil)
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

  def as_list_of_maps(list) when is_list(list), do: for(ss <- list, do: as_map(ss))

  def changeset(ss, params) do
    ss
    |> cast(params, [:name, :description])
    |> validate_required([:name])
    |> validate_format(:name, ~r/^[\w]+[\w ]{1,}[\w]$/)
    |> unique_constraint(:name)
  end

  def change_name(id, to_be, comment \\ "")

  def change_name(id, tobe, comment) when is_integer(id) do
    ss = get(SwitchState, id)

    if not is_nil(ss) do
      ss
      |> changeset(%{name: tobe, description: comment})
      |> update()
    else
      Logger.info(fn -> "change name failed" end)
      {:error, :not_found}
    end
  end

  def change_name(asis, tobe, comment)
      when is_binary(asis) and is_binary(tobe) do
    ss = get_by_name(asis)

    if not is_nil(ss) do
      ss
      |> changeset(%{name: tobe, description: comment})
      |> update()
    else
      {:error, :not_found}
    end
  end

  # def delete(id) when is_integer(id) do
  #   from(ss in SwitchState, where: ss.id == ^id) |> delete_all()
  # end
  #
  # def delete(name) when is_binary(name) do
  #   from(ss in SwitchState, where: ss.name == ^name) |> delete_all()
  # end

  def get_by(opts) when is_list(opts) do
    filter = Keyword.take(opts, [:name])
    select = Keyword.take(opts, [:only]) |> Keyword.get_values(:only) |> List.flatten()

    if Enum.empty?(filter) do
      Logger.warn(fn -> "get_by bad args: #{inspect(opts)}" end)
      []
    else
      ss = from(ss in SwitchState, where: ^filter) |> one()

      if is_nil(ss) or Enum.empty?(select), do: ss, else: Map.take(ss, select)
    end
  end

  def get_by(bad), do: Logger.warn(fn -> "get_by() bad args: #{inspect(bad)}" end)

  def get_by_name(name) when is_binary(name) do
    from(ss in SwitchState, where: ss.name == ^name) |> one()
  end

  def state(name) when is_binary(name) do
    ss = get_by(name: name)

    if is_nil(ss) do
      Logger.warn(fn -> "#{name} not found while RETRIEVING state" end)
      nil
    else
      ss.state
    end
  end

  # state() header:
  def state(name, opts \\ [])

  # change a switch state (position) by name
  # opts:
  #   lazy: [true | false]
  #   ack: [true | false]
  def state(name, opts) when is_binary(name) and is_list(opts) do
    position = Keyword.get(opts, :position, false)
    lazy = Keyword.get(opts, :lazy, false)

    ss = get_by_name(name)

    cond do
      is_nil(ss) ->
        Logger.warn(fn -> "#{name} not found while SETTING state" end)
        nil

      # only change the ss if it doesn't match requested position when lazy
      lazy and ss.state != position ->
        state(ss, opts ++ [position: position])

      # just return the position if ss matches the requested position when lazy
      lazy and ss.state === position ->
        position

      # force a ss position update
      true ->
        state(ss, opts ++ [position: position])
    end
  end

  def state(%SwitchState{name: name} = ss, opts) when is_list(opts) do
    position = Keyword.get(opts, :position, false)
    new_ss = change(ss, state: position) |> update!()
    SwitchCmd.record_cmd(name, new_ss, opts)
    new_ss.state
  end

  def state(bad, opts) when is_list(opts) do
    Logger.warn(fn -> "state() received #{inspect(bad)}" end)
    nil
  end

  def toggle(id) when is_integer(id) do
    ss = get(SwitchState, id)

    if is_nil(ss) do
      {:error, :not_found}
    else
      state(ss, lazy: true, position: not ss.state)
    end
  end
end
