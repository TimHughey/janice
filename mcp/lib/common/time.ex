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

  def unix_now(:second) do
    DateTime.utc_now() |> DateTime.to_unix(:second)
  end

  # TODO: fix upstream use of :seconds atom  
  def unix_now(:seconds), do: unix_now(:secomd)

  def utc_now do
    DateTime.utc_now()
  end
end
