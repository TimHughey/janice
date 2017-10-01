defmodule Mcp.Reading do
@moduledoc """
"""

alias __MODULE__
use Timex
require Logger

alias Poison
alias Mcp.McrAlias

@undef "undef"
@version 1
@temp_t "temp"
@switch_t "switch"
@relhum_t "relhum"

@derive [Poison.Encoder]
defstruct version: 0,
          host: @undef,
          device: nil,
          friendly_name: nil,
          type: nil,
          mtime: 0,
          tc: nil,
          tf: nil,
          rh: nil,
          pio: nil,
          pios: 0,
          cmdack: false,
          latency: 0,
          refid: nil,
          p0: true, p1: true, p2: true,  # these aren't actually stored at
          p3: true, p4: true, p5: true,  # this level however listing them
          p6: true, p7: true             # here ensures the atoms are created

@doc ~S"""
Parse a JSON into a Reading

 ##Examples:
  iex> json =
  ...>   ~s({"version": 1, "host": "mcr-macaddr", "device": "ds/29.0000",
  ...>       "mtime": 1506867918, "type": "temp", "tc": 20.0, "tf": 80.0})
  ...> Mcp.Reading.decode!(json) |> Mcp.Reading.metadata?()
  true
"""
def decode!(json)
when is_binary(json) do
  # pre-create necessary atoms
  %{p0: true, p1: true, p2: true, p3: true, p4: true,
    p5: true, p6: true, p7: true}

  r = Poison.decode!(json, [keys: :atoms!, as: %Mcp.Reading{}])
  Map.put(r, :friendly_name, McrAlias.friendly_name(r.device))
end

@doc ~S"""
Does the Reading have the base metadata?

NOTE: 1. As of 2017-10-01 we only support readings from mcr hosts and this is
         enforced by checking the prefix of the host id
      2. We also check the mtime to confirm it is greater than epoch + 1 year.
         This is a safety check for situations where a host is reporting
         readings without the time set

 ##Examples:
  iex> json =
  ...>   ~s({"version": 1, "host":"mcr-macaddr", "device":"ds/28.0000",
  ...>       "mtime": 1506867918, "type": "temp", "tc": 20.0, "tf": 80.0})
  ...> Mcp.Reading.decode!(json) |> Mcp.Reading.metadata?()
  true

  iex> json =
  ...>   ~s({"version": 0, "host": "other-macaddr", "device": "ds/28.0000",
  ...>       "mtime": 1506867918, "type": "temp", "tc": 20.0, "tf": 80.0})
  ...> Mcp.Reading.decode!(json) |> Mcp.Reading.metadata?()
  false
"""
def metadata?(%Reading{} = r) do
  epoch_first_year = (365 * 24 * 60 * 60) - 1 # seconds since epoch for year 2

  r.version === @version and
    (r.mtime > epoch_first_year) and
    String.starts_with?(r.host, "mcr") and
    is_binary(r.type)
end

@doc ~S"""
Is the Reading a temperature?

 ##Examples:
  iex> json =
  ...>   ~s({"version": 1, "host": "mcr-macaddr", "device": "ds/28.0000",
  ...>       "mtime": 1506867918, "type": "temp", "tc": 20.0, "tf": 80.0})
  ...> Mcp.Reading.decode!(json) |> Mcp.Reading.temperature?()
  true
"""
def temperature?(%Reading{} = r) do
  metadata?(r) and
    r.type === @temp_t and
    is_number(r.tc) and
    is_number(r.tf)
end

@doc ~S"""
Is the Reading a relative humidity?

 ##Examples:
 iex> json =
 ...>   ~s({"version": 1, "host": "mcr-macaddr",
 ...>       "device": "ds/29.0000", "mtime": 1506867918,
 ...>       "type": "relhum",
 ...>       "rh": 56.0})
 ...> Mcp.Reading.decode!(json) |> Mcp.Reading.relhum?()
 true
"""
def relhum?(%Reading{} = r) do
  metadata?(r) and
    r.type === @relhum_t and
    is_number(r.rh)
end

@doc ~S"""
Is the Reading a switch?

 ##Examples:
  iex> json =
  ...>   ~s({"version": 1, "host": "mcr-macaddr",
  ...>       "device": "ds/29.0000", "mtime": 1506867918,
  ...>        "type": "switch",
  ...>        "pio": [{"p0": true}, {"p1": false}], "pios": 2})
  ...> Mcp.Reading.decode!(json) |> Mcp.Reading.switch?()
  true
"""
def switch?(%Reading{} = r) do
  metadata?(r) and
    (r.type === @switch_t) and
    is_binary(r.device) and
    is_list(r.pio) and
    r.pios > 0
end

@doc ~S"""
Is the Reading a cmdack?

 ##Examples:
  iex> json =
  ...>   ~s({"version": 1, "host": "mcr-macaddr",
  ...>       "device": "ds/29.0000", "mtime": 1506867918,
  ...>        "type": "switch",
  ...>        "pio": [{"p0": true}, {"p1": false}], "pios": 2,
  ...>        "cmdack": true, "latency": 10, "refid": "uuid"})
  ...> Mcp.Reading.decode!(json) |> Mcp.Reading.cmdack?()
  true
"""
def cmdack?(%Reading{} = r) do
  switch?(r) and
    (r.cmdack === true) and
    (r.latency > 0) and
    is_binary(r.refid)
end

end
