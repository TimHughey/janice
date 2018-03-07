defmodule Dutycycle.Server do
  @moduledoc """

  """

  require Logger
  use GenServer
  use Timex

  def child_spec(args) do
    %{id: args.id, start: {Dutycycle.Server, :start_link, [args]}}
  end

  def start_link(args) do
    Logger.info(fn -> "start_link() args: #{inspect(args)}" end)

    dc = Dutycycle.get_by(id: args.id)

    # pieces = String.split(dc.name)
    # dc_name = hd(pieces) |> String.capitalize()

    id_str = String.pad_leading(Integer.to_string(dc.id), 3, "0")
    name = "DutyID" <> id_str
    name_atom = String.to_atom(name)

    s = %{name: name_atom}

    GenServer.start_link(__MODULE__, s, name: name_atom)
  end

  def init(s) do
    {:ok, s}
  end
end
