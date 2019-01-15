defmodule Janice.TimeSupport do
  @moduledoc false
  use Timex

  def from_unix(mtime) do
    {:ok, dt} = DateTime.from_unix(mtime)
    Timex.shift(dt, microseconds: 1) |> Timex.shift(microseconds: -1)
  end

  def unix_now do
    DateTime.utc_now() |> DateTime.to_unix(:microseconds)
  end

  def unix_now(:seconds) do
    DateTime.utc_now() |> DateTime.to_unix(:seconds)
  end

  def utc_now do
    DateTime.utc_now()
  end
end
