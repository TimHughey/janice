defmodule Fact.StartupAnnouncement do
  @moduledoc """
  """
  use Instream.Series
  use Timex

  alias Fact.StartupAnnouncement
  import(Fact.Influx, only: [write: 2])

  series do
    database    "merc_repo"
    measurement "run_metric"

    tag :application, default: "mercurial"
    tag :metric, default: "startup_announcement"
    tag :env, default: "#{Mix.env}"
    tag :host, default: "unknown-host" 
    tag :vsn, default: "unknown-vsn"

    field :val
  end

  def record(opts)
  when is_list(opts) do
    def_mtime = Timex.now() |> Timex.to_unix()
    f = %StartupAnnouncement{}

    f = set_tag(f, opts, :host)
    f = set_tag(f, opts, :vsn)
    f = set_field(f, [val: 1], :val)

    f = %{f | timestamp: Keyword.get(opts, :mtime, def_mtime)}
    write(f, [precision: :seconds, async: true])
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
