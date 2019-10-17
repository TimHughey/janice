defmodule Fact.FreeRamStat do
  @moduledoc false

  require Logger

  use Instream.Series
  alias Fact.FreeRamStat
  alias Fact.FreeRamStat.Fields
  alias Fact.FreeRamStat.Tags

  import(Fact.Influx, only: [write: 2])

  alias Janice.TimeSupport

  series do
    database(Application.get_env(:mcp, Fact.Influx) |> Keyword.get(:database))
    measurement("mcr_stat")

    tag(:remote_host)
    tag(:remote_name)
    tag(:env, default: Application.get_env(:mcp, :build_env, "dev"))
    tag(:mcr_stat, default: "freeram")

    field(:val)
  end

  @doc ~S"""
  Record a completely defined FreeRamStat metric

    ##Examples:
     iex> %{host: "mcr.xxxx", name: "mcr-name", mtime: 1557515656, val: 262000}
     ...> |> Fact.FreeRamStat.record()
     :ok
  """
  def record(%{
        host: host,
        name: name,
        mtime: mtime,
        freeram: freeram,
        record: true
      }) do
    tags = %{
      remote_host: host,
      remote_name: name,
      mcr_stat: "freeram"
    }

    write(
      %FreeRamStat{
        tags: Kernel.struct(Tags, tags),
        fields: Kernel.struct(Fields, %{val: freeram}),
        timestamp: mtime
      },
      precision: :second,
      async: true
    )
  end

  def record(%{record: false}), do: {:not_recorded}

  @doc ~S"""
  Record a FreeRamStat metric that is missing the mcr name

    ##Examples:
     iex> %{host: "mcr.xxxx", mtime: 1557515656, val: 262000}
     ...> |> Fact.FreeRamStat.record()
     :ok
  """
  def record(%{host: host, mtime: _mtime, freeram: _freeram} = r) do
    remote = Remote.get_by(host: host, only: :name)
    name = if is_nil(remote), do: r.host, else: remote.name

    Map.put_new(r, :name, name) |> record()
  end

  @doc ~S"""
  Record a FreeRamStat metric that is missing the mtime

    ##Examples:
     iex> %{host: "mcr.xxxx", name: "mcr-name", val: 262000}
     ...> |> Fact.FreeRamStat.record()
     :ok
  """
  def record(%{host: _host, freeram: _freeram} = r) do
    Map.put_new(r, :mtime, TimeSupport.unix_now(:second)) |> record()
  end

  @doc ~S"""
  Properly handle a request to record an invalid FreeRamStat metric

    ##Examples:
     iex> %{bad_host: "mcr.xxxx", name: "mcr-name", val: 262000}
     ...> |> Fact.FreeRamStat.record()
     :fail
  """
  def record(_nomatch), do: :fail
end
