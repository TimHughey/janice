defmodule SwitchGroup do
  @moduledoc """
  Provides functionality to control a group of switch states as a group
  """

  require Logger
  use Timex
  use Ecto.Schema

  import Ecto.Query, only: [from: 2]
  import Repo, only: [all: 2, one: 1]

  schema "switch_group" do
    field(:name, :string)
    field(:description, :string, default: "new switch group")
    field(:members, {:array, :string})

    timestamps(usec: true)
  end

  def add(%SwitchGroup{members: members} = sg) do
    if SwitchState.exists?(members) do
      Repo.insert(sg)
    else
      {:bad_members, nil}
    end
  end

  def all(:names), do: from(sg in SwitchGroup, select: sg.name) |> all(timeout: 100)
  def all(:everything), do: from(sg in SwitchGroup, order_by: [sg.name]) |> all(timeout: 100)

  def delete_all(:dangerous) do
    from(sg in SwitchGroup, where: sg.id >= 0) |> Repo.delete_all()
  end

  def get_by(opts) when is_list(opts) do
    filter = Keyword.take(opts, [:name])
    select = Keyword.take(opts, [:only]) |> Keyword.get_values(:only) |> List.flatten()

    if Enum.empty?(filter) do
      Logger.warn(fn -> "get_by bad args: #{inspect(opts)}" end)
      []
    else
      sg = from(sg in SwitchGroup, where: ^filter) |> one()

      if is_nil(sg) or Enum.empty?(select), do: sg, else: Map.take(sg, select)
    end
  end

  def get_by(bad), do: Logger.warn(fn -> "get_by() bad args: #{inspect(bad)}" end)

  def reduce_states(states) when is_list(states) do
    res = Enum.uniq(states)

    cond do
      res == [true] -> true
      res == [false] -> false
      true -> res
    end
  end

  def state(name) when is_binary(name) do
    sg = get_by(name: name)

    if is_nil(sg) do
      Logger.debug(fn -> "#{name} not while RETRIEVING state" end)
      nil
    else
      state(sg)
    end
  end

  def state(%SwitchGroup{name: _name, members: members}) do
    for ss <- members do
      SwitchState.state(ss)
    end
    |> reduce_states()
  end

  # state{} header:
  def state(name, opts \\ [])

  def state(name, opts) when is_binary(name) and is_list(opts) do
    log = Keyword.get(opts, :log, true)

    sg = get_by(name: name)

    if is_nil(sg) do
      log && Logger.debug(fn -> "#{name} not found while SETTING switch group" end)
      nil
    else
      state(sg, opts)
    end
  end

  def state(%SwitchGroup{name: _name, members: members}, opts) when is_list(opts) do
    for ss <- members do
      SwitchState.state(ss, opts)
    end
    |> reduce_states()
  end
end
