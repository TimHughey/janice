defmodule Mix.Tasks.Seed do
@moduledoc """
  Seeds the Mercurial database
"""
require Logger
use Mix.Task
import Mix.Ecto
import Seed.Chambers
import Seed.Dutycycles
import Seed.Mixtanks
import Seed.Sensors
import Seed.Switches

# alias Mcp.Chamber

def run(args) do

  repos = parse_repo(args)

  {opts, _, _} = OptionParser.parse args,
    switches: [quiet: :boolean, pool_size: :integer]

  # interesting way to check that a list has a single element, smile
  if tl(repos) != [] do
    Logger.warn fn -> "more than one repo is not supported" end
    Logger.warn fn -> "will use first in the list" end
  end

  repo = hd(repos)

  # special thanks to the Ecto code base for this example of how to start
  # just the Repos
  opts =
    if opts[:quiet],
      do: Keyword.put(opts, :log, false),
      else: opts

  ensure_repo(repo, args)
  {:ok, pid, db} = ensure_started(repo, opts)

  Logger.info fn -> "#{inspect(repo)} started #{inspect(db)}" end

  {:ok, _started} = Application.ensure_all_started(:timex)

  Logger.info fn -> ":timex started" end

  sensors(Mix.env) |>
    Enum.each(fn(x) -> Logger.info("seeding sensor [#{x.name}]")
                        Sensor.add(x) end)

  switches(Mix.env) |>
    Enum.each(fn(x) -> Logger.info("seeding switch [#{x.device}]")
                       Switch.add(x) end)

  mixtanks(Mix.env) |>
    Enum.each( fn (x) -> Logger.info("seeding mixtank [#{x.name}]")
                         Mixtank.add(x) end)
  chambers(Mix.env) |> seed()

  dutycycles(Mix.env) |>
    Enum.each( fn (x) -> Logger.info("seeding dutycycle [#{x.name}]")
                         Dutycycle.add(x) end )

  pid && repo.stop(pid)

  Logger.info fn -> "#{inspect(repo)} stopped" end
end

defp seed([]), do: []
defp seed(%{__struct__: type, name: name} = thing) do
  Logger.info "seeding #{type} #{name}"

  case Repo.insert(thing) do
    {:ok, item}   -> item
    {:error, err} -> Logger.warn fn -> "seed failed #{inspect(type)} " <>
                                      "#{thing.name} #{inspect(err)}" end
                     %{}
    unknown       -> Logger.warn fn -> "unknown failure #{inspect(unknown)}" end
                     %{}
  end
end

defp seed([thing | list]), do: [seed(thing)] ++ seed(list)


end
