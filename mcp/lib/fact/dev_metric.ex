defmodule Fact.DevMetric do
  @moduledoc """

  """

  use Instream.Series
  # alias Fact.DevMetric
  # import(Fact.Influx, only: [write: 2])

  series do
    database(Application.get_env(:mcp, Fact.Influx) |> Keyword.get(:database))
    measurement("dev_metric")

    tag(:remote_host)
    tag(:device)
    tag(:env, default: Application.get_env(:mcp, :build_env, "dev"))

    field(:val)
  end

  def record(opts)
      when is_list(opts) do
  end
end
