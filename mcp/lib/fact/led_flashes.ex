defmodule Fact.LedFlashes do
  @moduledoc """
  """
  use Instream.Series
  use Timex

  alias Fact.LedFlashes
  import(Fact.Influx, only: [write: 2])

  series do
    database(Application.get_env(:mcp, Fact.Influx) |> Keyword.get(:database))
    measurement("led_flashes")

    tag(:name)
    tag(:application, default: "janice")
    tag(:env, default: Application.get_env(:mcp, :build_env, "dev"))

    field(:val)
  end

  def record(opts)
      when is_list(opts) do
    def_mtime = Timex.now() |> Timex.to_unix()
    f = %LedFlashes{}

    f = set_tag(f, opts, :name)
    f = set_tag(f, opts, :application)
    f = set_field(f, opts, :val)

    f = %{f | timestamp: Keyword.get(opts, :mtime, def_mtime)}
    write(f, precision: :seconds)
  end

  defp set_tag(map, opts, key)
       when is_map(map) and is_list(opts) and is_atom(key) do
    set_tag(map, key, Keyword.get(opts, key))
  end

  defp set_tag(map, _key, nil) when is_map(map), do: map

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
