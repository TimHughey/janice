defmodule Fact.EngineMetric do
  @moduledoc false

  require Logger

  use Instream.Series
  import(Fact.Influx, only: [write: 2])
  import(Map, only: [has_key?: 2])
  alias Fact.EngineMetric

  alias Janice.TimeSupport

  @metric_type "mcr_stat"
  @metric_name "engine_phase"
  @metric_tags [
    :vsn,
    :host,
    :name,
    :engine,
    :metric,
    :discover_us,
    :convert_us,
    :report_us
  ]
  @metric_fields [:convert_us, :discover_us, :report_us, :switch_cmd_us]

  series do
    database(Application.get_env(:mcp, Fact.Influx) |> Keyword.get(:database))
    # 'type' maps to the measurement
    measurement(@metric_type)

    tag(:application, default: "janice")
    tag(:env, default: Application.get_env(:mcp, :build_env, "dev"))
    tag(:host)
    tag(:name)
    tag(:metric, default: @metric_name)
    tag(:engine)

    field(:convert_us)
    field(:discover_us)
    field(:report_us)
    field(:switch_cmd_us)
  end

  def make_point(%{type: @metric_type, metric: _, engine: _} = r) do
    filtered = Enum.filter(r, &wanted?/1)

    # Logger.info(fn -> "filter: #{inspect(filtered)}" end)

    tags = Enum.filter(filtered, &tag?/1)
    fields = Enum.filter(filtered, &field?/1)

    pt = %EngineMetric{}
    pt = set_tag(pt, tags, :host)
    pt = set_tag(pt, tags, :name)
    pt = set_tag(pt, tags, :metric)
    pt = set_tag(pt, tags, :engine)

    pt = set_field(pt, fields, :convert_us)
    pt = set_field(pt, fields, :discover_us)
    pt = set_field(pt, fields, :report_us)
    pt = set_field(pt, fields, :switch_cmd_us)

    %{pt | timestamp: Map.get(r, :mtime, TimeSupport.unix_now(:second))}
  end

  # trap when the input map doesn't match
  def make_point(%{} = r) do
    Logger.warn(fn -> "no match for #{inspect(r)}" end)
    %{}
  end

  def record(%{record: true} = r) do
    db = Application.get_env(:mcp, Fact.Influx) |> Keyword.get(:database)
    make_point(r) |> write(database: db, async: true, precision: :second)
  end

  def record(%{record: false}), do: {:not_recorded}

  defp field?({k, _v}), do: k in @metric_fields

  defp tag?({k, _v}), do: k in @metric_tags

  defp wanted?({k, v}) do
    keep = k in (@metric_tags ++ @metric_fields)

    if keep do
      cond do
        k in @metric_fields and v == 0 -> false
        k in @metric_fields and v > 0 -> true
        k not in @metric_fields -> true
        true -> false
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
    type === @metric_type and metric === @metric_name and has_key?(r, :engine)
  end
end
