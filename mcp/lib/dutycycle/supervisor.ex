defmodule Dutycycle.Supervisor do
  @moduledoc false

  require Logger
  use Supervisor

  def init(args) do
    Logger.info(fn -> "init()" end)

    ids = Dutycycle.all(:ids)

    dc_children =
      for id <- ids do
        {Dutycycle.Server, Map.put(args, :id, id)}
      end

    # List all child processes to be supervised
    children =
      [
        {Mixtank.Control, args}
      ] ++ dc_children

    # Starts a worker by calling: Mqtt.Worker.start_link(arg)
    # {Mqtt.Worker, arg},

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :rest_for_one, name: Dutycycle.Supervisor]
    Supervisor.init(children, opts)
  end

  def is_duty_server?(a) when is_atom(a) do
    str = Atom.to_string(a)

    String.contains?(str, "Duty_ID")
  end

  def known_servers do
    children = Supervisor.which_children(Dutycycle.Supervisor)

    for {server_name, _pid, _type, _modules} <- children, is_duty_server?(server_name) do
      server_name
      # rx = ~r/Duty_ID(?<id>\d+)/x
      #
      # Regex.named_captures(rx, server_name) |> Map.get(:id) |> String.to_integer()
    end
  end

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end
end
