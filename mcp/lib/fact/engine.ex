defmodule Fact.EngineMetric do
  @moduledoc """
  """

  use Timex

  alias Fact.EngineMetric
  import(Fact.Influx, only: [write: 2])

  def record(%{} = r) do
    db = Application.get_env(:mcp, Fact.Influx) |> Keyword.get(:database)
    filtered = Enum.take_while(r, &wanted?/1)
    filtered = Keyword.put_new(filtered, :mtime, Timex.now() |> Timex.to_unix())

    tags = [application: "mercurial", env: "#{Mix.env()}"] ++ Enum.take_while(filtered, &tag?/1)

    fields = Enum.take_while(filtered, &field?/1)

    pt = %{tags: tags, fields: fields, timestamp: Keyword.get(filtered, :mtime)}

    write(pt, database: db, async: true, precision: :seconds)
  end

  defp field?({k, _v}), do: k in [:convert_us, :discover_us, :report_us]

  defp tag?({k, _v}), do: k in [:host, :type, :subtype, :vsn, :mtime]

  defp wanted?({k, v}) do
    keep = k in [:host, :vsn, :type, :subtype, :discover_us, :convert_us, :report_us, :mtime]

    if keep do
      cond do
        k == :discover_us and v == 0 -> false
        k == :convert_us and v == 0 -> false
        k == :report_us and v == 0 -> false
      end
    end
  end
end
