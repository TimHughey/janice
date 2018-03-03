defmodule Mcp.Chamber.Device do
  def license,
    do: """
    Master Control Program for Wiss Landing
    Copyright (C) 2016  Tim Hughey (thughey)

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>
    """

  @moduledoc """
    Foo Bar Foundation
  """

  require Logger
  use Timex

  alias __MODULE__

  @def_name :new_device

  @status :status
  @ts :ts
  @pending_timer :pending_timer

  @disabled :disabled
  @running :running
  @idling :idling

  defstruct name: @def_name,
            ts: Timex.zero(),
            ctrl_dev: "foobar",
            status: @disabled,
            pending_timer: nil

  def create(name, ctrl_dev) when is_atom(name) and is_binary(ctrl_dev) do
    %Device{name: name, ctrl_dev: ctrl_dev, ts: Timex.now()}
  end

  def enabled?(%Device{} = dev) do
    running?(dev) or idling?(dev)
  end

  def disabled?(%Device{@status => @disabled}), do: true
  def disabled?(%Device{}), do: false

  def disable(%Device{} = dev) do
    case dev.status do
      @running -> ctrl_dev_position(dev.ctrl_dev, false)
      @idling -> ctrl_dev_position(dev.ctrl_dev, false)
    end

    cancel_timer(dev)
    update_status(dev, @disabled, nil)
  end

  defp cancel_timer(%Device{@pending_timer => nil}), do: nil

  defp cancel_timer(%Device{} = dev) do
    Logger.debug(fn -> "chamber device [#{dev.name}] -- canceling timer" end)
    Process.cancel_timer(dev.pending_timer)
  end

  def running?(%Device{@status => @running}), do: true
  def running?(%Device{}), do: false

  # if the device is idle or disabled then set it to running
  def run(%Device{@status => status} = dev, timer)
      when (status == @idling or status == @disabled) and (is_reference(timer) or timer == nil) do
    # if there was an existing pending timer cancel it as the new
    # timer will override
    cancel_timer(dev)
    ctrl_dev_position(dev.ctrl_dev, true)

    update_status(dev, @running, timer)
  end

  # alternatively, if the device is already running don't do anything
  def run(%Device{@status => @running} = dev, timer)
      when is_reference(timer) or timer == nil,
      do: dev

  def idling?(%Device{@status => @idling}), do: true
  def idling?(%Device{}), do: false

  # if a device is running or disabled then make it idle
  def idle(%Device{@status => status} = dev, timer)
      when (status == @running or status == @disabled) and (is_reference(timer) or timer == nil) do
    # if there was an existing pending timer cancel it as the new
    # timer will override
    cancel_timer(dev)
    ctrl_dev_position(dev.ctrl_dev, false)

    update_status(dev, @idling, timer)
  end

  # alternatively, if a device is already idle do nothing
  def idle(%Device{@status => @idling} = dev, timer)
      when is_reference(timer) or timer == nil,
      do: dev

  # wrapping the setting of the Switch position to catch
  # improperly configured Chambers
  # note: an undefined (foobar) switch can be set provided
  # the cycle (e.g warm, mist, fae, stir) that uses it is disabled
  defp ctrl_dev_position(dev, pos)
       when is_binary(dev) and is_boolean(pos) do
    SwitchState.state(dev, pos)
  end

  defp ctrl_dev_position("foobar", false), do: nil

  defp ctrl_dev_position("foobar", true) do
    msg = "Chamber: attempt set position-true on a foobar switch"
    Logger.warn(msg)
    nil
  end

  #
  # Map access functions
  #
  def name(%Device{} = dev), do: dev.name
  def ts(%Device{} = dev), do: dev.ts

  def position(%Device{} = dev, b, t)
      when is_boolean(b) and (is_reference(t) or t == nil) do
    case b do
      true -> run(dev, t)
      false -> idle(dev, t)
    end
  end

  # in the case when the prev status is not the new status the ts
  # should be updated to indicate the status has changed
  defp update_status(%Device{@status => pstatus} = dev, nstatus, t)
       when pstatus != nstatus do
    %Device{dev | @status => nstatus, @ts => Timex.now(), @pending_timer => t}
  end

  # in the case when the new status and previous status are the same
  # don't update the ts
  defp update_status(%Device{@status => pstatus} = dev, nstatus, t)
       when pstatus == nstatus do
    %Device{dev | @pending_timer => t}
  end
end
