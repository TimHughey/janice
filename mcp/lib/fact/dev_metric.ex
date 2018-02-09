defmodule Fact.DevMetric do
  @moduledoc """

  """

  use Instream.Series
  alias Fact.DevMetric
  import(Fact.Influx, only: [write: 2])

  series do
    database("merc_repo")
    measurement("dev_metric")

    tag(:remote_host, default: "unknown_host")
    tag(:device, default: "unknown_device")
    tag(:env, default: "dev")

    field(:val)
  end

  def record(opts)
      when is_list(opts) do
  end
end
