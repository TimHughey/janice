defmodule Fact.StartupAnnouncement do
  @moduledoc false

  use Instream.Series

  alias Fact.StartupAnnouncement
  import(Fact.Influx, only: [write: 2])

  alias Janice.TimeSupport

  series do
    database(Application.get_env(:mcp, Fact.Influx) |> Keyword.get(:database))
    measurement("run_metric")

    tag(:application, default: "janice")
    tag(:metric, default: "startup_announcement")
    tag(:env, default: Application.get_env(:mcp, :build_env, "dev"))
    tag(:host)
    tag(:vsn, default: "unknown-vsn")
    tag(:hw, default: "unknown-hw")

    field(:val)
  end

  def record(opts)
      when is_list(opts) do
    def_mtime = TimeSupport.unix_now(:second)
    f = %StartupAnnouncement{}

    f = set_tag(f, opts, :host)
    f = set_tag(f, opts, :vsn)
    f = set_field(f, [val: 1], :val)

    f = %{f | timestamp: Keyword.get(opts, :mtime, def_mtime)}
    write(f, precision: :second, async: true)
  end

  defp set_tag(map, opts, key)
       when is_map(map) and is_list(opts) and is_atom(key) do
    set_tag(map, key, Keyword.get(opts, key))
  end

  defp set_tag(map, _key, nil), do: map

  defp set_tag(map, key, value)
       when is_map(map) and is_atom(key) do
    %{map | tags: %{map.tags | key => value}}
  end

  defp set_field(map, opts, key)
       when is_map(map) and is_list(opts) and is_atom(key) do
    set_field(map, key, Keyword.get(opts, key))
  end

  defp set_field(map, _key, nil) when is_map(map), do: map

  defp set_field(map, key, value)
       when is_map(map) and is_atom(key) do
    %{map | fields: %{map.fields | key => value}}
  end
end
