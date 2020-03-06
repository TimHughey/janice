defmodule Janice.TimeSupport do
  @moduledoc false
  require Logger
  use Timex

  def before_time(:utc_now, x) do
    utc_now() |> Timex.shift(milliseconds: ms(x) * -1)
  end

  def duration_from_list(opts), do: list_to_duration(opts)

  def from_unix(mtime) do
    {:ok, dt} = DateTime.from_unix(mtime)
    Timex.shift(dt, microseconds: 1) |> Timex.shift(microseconds: -1)
  end

  def list_to_duration(opts) when is_list(opts) do
    # since there wasn't a capability with Timex.Duration, that I could
    # find after hours of research, we use multiple Timex functions to
    # create the Duration
    ~U[0000-01-01 00:00:00Z]
    |> Timex.shift(Keyword.take(opts, valid_duration_opts()))
    |> Timex.to_gregorian_microseconds()
    |> Duration.from_microseconds()
  end

  def list_to_duration(_anything), do: 0

  def ms({:ms, x}) when is_number(x), do: x |> round()
  def ms({:secs, x}) when is_number(x), do: (x * 1000) |> round()
  def ms({:mins, x}) when is_number(x), do: ms({:secs, x * 60}) |> round()
  def ms({:hrs, x}) when is_number(x), do: ms({:mins, x * 60}) |> round()
  def ms({:days, x}) when is_number(x), do: ms({:hrs, x * 24}) |> round()
  def ms({:weeks, x}) when is_number(x), do: ms({:days, x * 7}) |> round()
  def ms({:months, x}) when is_number(x), do: ms({:weeks, x * 4}) |> round()

  def ms(unsupported) do
    Logger.warn(["ms(", inspect(unsupported), ") is not supported"])
    nil
  end

  def ttl_expired?(at, ttl_ms) when is_integer(ttl_ms) do
    shift_ms = ttl_ms * -1
    ttl_dt = Timex.now() |> Timex.shift(milliseconds: shift_ms)

    Timex.before?(at, ttl_dt)
  end

  def unix_now do
    Timex.now() |> DateTime.to_unix(:microsecond)
  end

  def unix_now(unit) when is_atom(unit) do
    Timex.now() |> DateTime.to_unix(unit)
  end

  def utc_now do
    Timex.now()
  end

  def utc_shift(opts) when is_list(opts) do
    utc_now() |> Timex.shift(opts)
  end

  def utc_shift(%Duration{} = d), do: utc_now() |> Timex.shift(duration: d)

  def utc_shift(_anything), do: utc_now()

  defp valid_duration_opts,
    do: [
      :microseconds,
      :seconds,
      :minutes,
      :hours,
      :days,
      :weeks,
      :months,
      :years
    ]
end
