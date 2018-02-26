defmodule Fact.EngineMetric do
  @moduledoc """
  """

  use Timex

  use Instream.Series
  import(Fact.Influx, only: [write: 2])
  import(Map, only: [has_key?: 2])
  alias Fact.EngineMetric

  series do
    database(Application.get_env(:mcp, Fact.Influx) |> Keyword.get(:database))
    # 'type' maps to the measurement
    measurement("mcr_stat")

    tag(:application, default: "mercurial")
    tag(:env, default: Application.get_env(:mcp, :build_env, "dev"))
    tag(:host)
    tag(:metric, default: "engine_phase")
    tag(:engine)

    field(:convert_us)
    field(:discover_us)
    field(:report_us)
  end

  def make_point(%{type: "mcr_stat", metric: _, engine: _} = r) do
    filtered = Enum.filter(r, &wanted?/1)

    # Logger.info(fn -> "filter: #{inspect(filtered)}" end)

    tags = Enum.filter(filtered, &tag?/1)
    fields = Enum.filter(filtered, &field?/1)

    pt = %EngineMetric{}
    pt = set_tag(pt, tags, :host)
    pt = set_tag(pt, tags, :metric)
    pt = set_tag(pt, tags, :engine)

    pt = set_field(pt, fields, :convert_us)
    pt = set_field(pt, fields, :discover_us)
    pt = set_field(pt, fields, :report_us)

    %{pt | timestamp: Map.get(r, :mtime, Timex.now() |> Timex.to_unix())}
  end

  # trap when the input map doesn't match
  def make_point(%{}), do: %{}

  def record(%{} = r) do
    db = Application.get_env(:mcp, Fact.Influx) |> Keyword.get(:database)
    make_point(r) |> write(database: db, async: true, precision: :seconds)
  end

  defp field?({k, _v}), do: k in [:convert_us, :discover_us, :report_us]

  defp tag?({k, _v}), do: k in [:vsn, :host, :engine, :mtime]

  defp wanted?({k, v}) do
    keep = k in [:vsn, :host, :engine, :metric, :discover_us, :convert_us, :report_us, :mtime]

    if keep do
      cond do
        k == :discover_us and v == 0 -> false
        k == :convert_us and v == 0 -> false
        k == :report_us and v == 0 -> false
        true -> true
      end
    end
  end

  defp set_tag(m, opts, k)
       when is_map(m) and is_list(opts) and is_atom(k) do
    v = Keyword.get(opts, k, nil)

    if is_nil(v), do: m, else: %{m | tags: %{m.tags | k => v}}
  end

  def set_field(m, opts, k)
      when is_map(m) and is_list(opts) and is_atom(k) do
    v = Keyword.get(opts, k, nil)

    if is_nil(v), do: m, else: %{m | fields: %{m.fields | k => v}}
  end

  def valid?(%{} = r) do
    type = Map.get(r, :type, nil)
    metric = Map.get(r, :metric, nil)
    type === "mcr_stat" and metric === "engine_phase" and has_key?(r, :engine)
  end
end
