defmodule SwitchGroup do
  @moduledoc """
  Provides functionality to control a group of switch states as a group
  """

  require Logger
  use Ecto.Schema

  import Ecto.Query, only: [from: 2]
  import Repo, only: [all: 2, get_by: 2]

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

  def all(:names),
    do: from(sg in SwitchGroup, select: sg.name) |> all(timeout: 100)

  def all(:everything),
    do: from(sg in SwitchGroup, order_by: [sg.name]) |> all(timeout: 100)

  def delete_all(:dangerous) do
    from(sg in SwitchGroup, where: sg.id >= 0) |> Repo.delete_all()
  end

  def find(name) when is_binary(name), do: get_by(__MODULE__, name: name)

  def position(opt, opts \\ [])

  # position() should only be called from SwitchState if the requested
  # name was not found
  def position({:not_found, name}, opts)
      when is_binary(name) and
             is_list(opts) do
    log = Keyword.get(opts, :log, false)

    with %SwitchGroup{members: members} <- find(name),
         {:members, true, members} <- {:members, is_list(members), members},
         {:positions, 1, res} <- positions(members, opts) do
      hd(res)
    else
      nil ->
        log && Logger.warn("switch group #{inspect(name)} not found")
        {:not_found, name}

      {:members, false, members} ->
        log &&
          Logger.warn(
            "#{inspect(name)} has invalid members #{
              inspect(members, pretty: true)
            }"
          )

        {:error, members}

      error ->
        Logger.warn("unhandled error #{inspect(error, pretty: true)}")
        {:error, error}
    end
  end

  # handle call from Switch when the position has already been found or
  # generated an error
  def position({:ok, _} = rc, _opts), do: rc
  def position({_, _} = rc, _opts), do: rc

  defp positions(members, opts) when is_list(members) and is_list(opts) do
    res =
      for ss <- members do
        SwitchState.position(ss, opts)
      end
      |> Enum.uniq()

    {:positions, length(res), res}
  end
end
