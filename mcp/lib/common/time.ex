defmodule Janice.TimeSupport do
  @moduledoc false
  require Logger
  use Timex

  def before_time(:utc_now, x) do
    utc_now() |> Timex.shift(milliseconds: ms(x) * -1)
  end

  def from_unix(mtime) do
    {:ok, dt} = DateTime.from_unix(mtime)
    Timex.shift(dt, microseconds: 1) |> Timex.shift(microseconds: -1)
  end

  def ms({:ms, x}) when is_number(x), do: x
  def ms({:secs, x}) when is_number(x), do: x * 1000
  def ms({:mins, x}) when is_number(x), do: ms({:secs, x * 60})
  def ms({:hrs, x}) when is_number(x), do: ms({:mins, x * 60})
  def ms({:days, x}) when is_number(x), do: ms({:hrs, x * 24})
  def ms({:weeks, x}) when is_number(x), do: ms({:days, x * 7})
  def ms({:months, x}) when is_number(x), do: ms({:weeks, x * 4})

  def ms(unsupported) do
    Logger.warn(fn -> "ms(#{inspect(unsupported)}) is not supported" end)
    nil
  end

  def unix_now do
    DateTime.utc_now() |> DateTime.to_unix(:microseconds)
  end

  def unix_now(:second) do
    DateTime.utc_now() |> DateTime.to_unix(:second)
  end

  def utc_now do
    DateTime.utc_now()
  end
end
