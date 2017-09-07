defmodule Mcp.Influx.ServerState do
  @moduledoc :false

  use Timex

  alias Mcp.Util
  alias Mcp.Influx.ServerState

  defstruct kickstarted: %{status: :never, ts: Timex.zero()},
    last_post: %{status: :never, elapsed: 0, headers: %{}},
    num_posts: 0, num_failures: 0

  def kickstart(%ServerState{} = s) do
    %ServerState{s | kickstarted: %{status: :ok, ts: Timex.now()}}
  end

  def record_post(%ServerState{} = s, res) when is_map(res) do
    record_post(s, res.status, res.elapsed, res.headers)
  end
  def record_post(%ServerState{} = s, :error = status, elapsed_us, headers) do
    s |> record_failure() |> record_post(status, elapsed_us, headers)
  end

  def record_post(%ServerState{} = s, status, elapsed_us, headers)
  when is_atom(status) do
    lp = %{status: status, elapsed_ms: Util.us_to_ms(elapsed_us),
           headers: headers}

    %ServerState{s | last_post: lp, num_posts: s.num_posts + 1}
  end

  def last_post(%ServerState{} = s), do: s.last_post

  defp record_failure(%ServerState{} = s) do
    %ServerState{s | num_failures: s.num_failures + 1}
  end

end
