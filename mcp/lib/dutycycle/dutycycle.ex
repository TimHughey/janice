defmodule Dutycycle do
  #    Master Control Program for Wiss Landing
  #    Copyright (C) 2016  Tim Hughey (thughey)

  #    This program is free software: you can redistribute it and/or modify
  #    it under the terms of the GNU General Public License as published by
  #    the Free Software Foundation, either version 3 of the License, or
  #    (at your option) any later version.

  #    This program is distributed in the hope that it will be useful,
  #    but WITHOUT ANY WARRANTY; without even the implied warranty of
  #    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  #    GNU General Public License for more details.

  #    You should have received a copy of the GNU General Public License
  #    along with this program.  If not, see <http://www.gnu.org/licenses/>

  @moduledoc """
    Dutycycle schema
  """

  require Logger
  use Ecto.Schema

  import Repo,
    only: [get_by: 2, insert: 1, update!: 1, preload: 2, preload: 3]

  import Ecto.Changeset,
    only: [
      cast: 3,
      validate_required: 2,
      validate_format: 3,
      unique_constraint: 3
    ]

  import Janice.Common.DB, only: [name_regex: 0]

  alias Dutycycle.Profile
  alias Dutycycle.Server
  alias Dutycycle.State

  schema "dutycycle" do
    field(:name)
    field(:comment)
    field(:log, :boolean, default: false)
    field(:device)
    field(:active, :boolean, default: false)
    field(:scheduled_work_ms, :integer, default: 750)
    field(:startup_delay_ms, :integer, default: 10_000)
    has_one(:state, State)
    has_many(:profiles, Profile)

    timestamps(usec: true)
  end

  def activate_profile(dc, name, opts \\ [])

  def activate_profile(%Dutycycle{} = dc, %Profile{name: name}, opts)
      when is_list(opts),
      do: activate_profile(dc, name, opts)

  def activate_profile(%Dutycycle{} = dc, :active, opts) do
    with {:no_active_profile, false} <- {:no_active_profile, Profile.none?(dc)},
         %Profile{} = active_profile <- Profile.active(dc) do
      activate_profile(dc, active_profile, opts)
    else
      {:no_active_profile, true} ->
        Logger.warn(fn ->
          dc_name(dc) <>
            " does not have an active profile to activate"
        end)

        {:no_active_profile, dc}

      unhandled ->
        Logger.warn(fn ->
          dc_name(dc) <>
            " activate active profile unhandled condition " <>
            "#{inspect(unhandled, pretty: true)}"
        end)
    end
  end

  def activate_profile(%Dutycycle{log: log} = dc, profile, _opts)
      when is_binary(profile) do
    with {:ok, %Profile{} = next_profile} <-
           Profile.activate(dc, profile),
         {:ok, dc} <- activate(dc),
         dc <- reload(dc),
         # use the end_of_phase function to determine the start phase
         # when activating the profile and control the device
         {:first_phase, {:ok, dc, _active_profile, mode}} <-
           {:first_phase, end_of_phase(dc, next_profile)},
         {:ok, {:position, true}, dc} <- control_device(dc, lazy: false) do
      log &&
        Logger.info(fn ->
          dc_name(dc) <>
            " activated profile #{inspect(Profile.name(next_profile))}" <>
            " first phase #{inspect(mode, pretty: true)}"
        end)

      {:ok, reload(dc), next_profile, mode}
    else
      {:none, %Profile{}} ->
        Logger.warn(dc_name(dc) <> " deactivated, profile none")

        {rc, dc} = deactivate(dc)

        {rc, reload(dc), %Profile{name: "none"}, :none}

      {:activate_profile_failed, error} ->
        Logger.warn(fn ->
          "activate failed #{inspect(error, pretty: true)}"
        end)

        {:failed, profile, error}

      {:first_phase, error} ->
        Logger.warn(fn ->
          "next_phase() failed: #{inspect(error, pretty: true)}"
        end)

      {:ok, {:position, pos}, dc} ->
        log?(dc) &&
          Logger.debug(fn ->
            dc_name(dc) <>
              " device state is " <>
              inspect(pos, pretty: true) <>
              " after profile activation"
          end)

        {:ok, dc, Profile.active(dc), :run}

      error ->
        Logger.warn(fn ->
          "unhandled activate failure #{inspect(error, pretty: true)}"
        end)

        {:failed, dc}
    end
  end

  def active?(%Dutycycle{active: val}), do: val

  def add([]), do: []

  def add([%Dutycycle{} = dc | rest]) do
    [add(dc)] ++ add(rest)
  end

  def add(%Dutycycle{name: name} = dc) do
    cs = changeset(dc, Map.take(dc, possible_changes()))

    with {:cs_valid, true} <- {:cs_valid, cs.valid?()},
         {:ok, _dc} <- insert(cs),
         %Dutycycle{} = dc <- find(name) do
      # {:add_state, {:ok, %State{}}} <-
      #   {:add_state, Ecto.build_assoc(dc, :state, %State{}) |> Repo.insert()} do
      reload(dc)
      |> Server.start_server()
    else
      {:cs_valid, false} ->
        {:invalid_changes, cs}

      {:add_state, rc} ->
        Logger.warn(
          "add() failed to insert %State{}: #{inspect(rc, pretty: true)}"
        )

      error ->
        Logger.warn("add() failure: #{inspect(error, pretty: true)}")

        {:failed, error}
    end
  end

  # FUNCTION HEADER
  def all(atom, opts \\ [])

  def all(:ids, opts) when is_list(opts) do
    for d <- Repo.all(Dutycycle), do: Map.get(d, :id)
  end

  def all(:names, opts) when is_list(opts) do
    for d <- Repo.all(Dutycycle), do: Map.get(d, :name)
  end

  def current_state(%Dutycycle{state: _state} = dc, opts \\ [])
      when is_list(opts) do
    reload = Keyword.get(opts, :reload, false)

    dc = if reload, do: reload(dc), else: dc

    {dc, dc.state}
  end

  def delete(name) when is_binary(name) do
    dc = find(name)

    if is_nil(dc),
      do: {:not_found, name},
      else: delete(dc)
  end

  def delete(%Dutycycle{id: id}, opts \\ [timeout: 5 * 60 * 1000]) do
    dc =
      Repo.get(__MODULE__, id)
      |> preload([:state, :profiles], force: true)

    if is_nil(dc),
      do: [server: :not_found, db: :not_found],
      else: [server: Server.delete(dc), db: elem(Repo.delete(dc, opts), 0)]
  end

  # HAS TEST CASE
  def delete_all(:dangerous) do
    for dc <- Repo.all(Dutycycle), do: delete(dc)
  end

  def delete_profile(%Dutycycle{profiles: _profiles} = dc, profile_name, _opts)
      when is_binary(profile_name) do
    Profile.delete(dc, profile_name)
  end

  def device_change(%Dutycycle{} = d, new_device) when is_binary(new_device) do
    # reload the Dutycycle to be safe
    dc = reload(d)

    update(dc, device: new_device)
  end

  def device_change(d, device) do
    Logger.warn(
      "invalid args: device_change(#{inspect(d, pretty: true)}, #{
        inspect(device, pretty: true)
      }"
    )

    {:error, :invalid_args}
  end

  def device_check_ms(x) when is_binary(x) or is_integer(x),
    do: find(x) |> Profile.device_check_ms()

  # primary entry point for handling the end of phase
  def end_of_phase(%Dutycycle{} = dc) do
    active_profile = Profile.active(dc)

    end_of_phase(dc, active_profile)
  end

  # special cases:
  #  a. if idle_ms == 0 then always run
  #  b. if run_ms == 0 then always idle
  #  c. if run_ms and idle_ms == 0 then always idle
  #
  # typical cases:
  #  a. idle_ms > 0 then idle after run
  #  b. run_ms > 0 then run after idle

  defp end_of_phase(
         %Dutycycle{state: %State{state: _any}} = dc,
         %Profile{idle_ms: 0, run_ms: 0}
       ),
       do: next_phase(:idle, dc)

  # regardless the current state when idle_ms == 0 the next phase
  # is always run

  # NOTE: only executed if the idle_ms == run_ms == 0 doesn't match
  defp end_of_phase(
         %Dutycycle{state: %State{state: _any}} = dc,
         %Profile{idle_ms: 0}
       ),
       do: next_phase(:run, dc)

  # when a dutycycle is running and idle_ms > 0 then start the idle phase
  defp end_of_phase(
         %Dutycycle{state: %State{state: "running"}} = dc,
         %Profile{idle_ms: ms}
       )
       when ms > 0,
       do: next_phase(:idle, dc)

  # regardless the current state when run_ms == 0 the next phase
  # is always idle

  # NOTE: only executed if the idle_ms == run_ms == 0 doesn't match

  defp end_of_phase(
         %Dutycycle{state: %State{state: _any}} = dc,
         %Profile{run_ms: 0}
       ),
       do: next_phase(:idle, dc)

  # when a dutycycle is idling and run_ms > 0 then start the run phase
  defp end_of_phase(
         %Dutycycle{state: %State{state: "idling"}} = dc,
         %Profile{run_ms: ms}
       )
       when ms > 0,
       do: next_phase(:run, dc)

  # if nothing above has matched and run_ms > 0 then run to handle
  # cases such as "stopped" or "offline"
  defp end_of_phase(
         %Dutycycle{state: %State{state: _state}} = dc,
         %Profile{run_ms: ms}
       )
       when ms > 0 do
    next_phase(:run, dc)
  end

  defp next_phase(mode, %Dutycycle{} = dc) do
    with {%Dutycycle{} = dc, {:ok, %State{}}} <-
           State.next_phase(mode, dc, log_transition: log?(dc)),
         dc <- reload(dc),
         {:ok, {:position, _postition}, dc} <- control_device(dc) do
      active_profile = Profile.active(dc)
      {:ok, dc, active_profile, mode}
    else
      error -> error
    end
  end

  def find(id) when is_integer(id),
    do: get_by(__MODULE__, id: id) |> preload([:state, :profiles])

  def find(name) when is_binary(name),
    do: get_by(__MODULE__, name: name) |> preload([:state, :profiles])

  def halt(%Dutycycle{} = dc) do
    with {%Dutycycle{}, {:ok, %State{}}} <- State.next_phase(:stop, dc),
         {:ok, %Dutycycle{}} <- deactivate(dc),
         {:reload, %Dutycycle{} = dc} <- {:reload, reload(dc)},
         {:ok, {:position, {:ok, false}}, dc} <-
           control_device(dc, lazy: false) do
      {:ok, dc}
    else
      {:invalid_changes, errors} ->
        Logger.warn(fn -> "#{inspect(errors, pretty: true)}" end)
        dc = reload(dc)
        {:failed, dc}

      {:ok, {:position, nil}, %Dutycycle{} = dc} ->
        {:ok, dc}

      {:ok, {:position, true}, %Dutycycle{device: device} = dc} ->
        Logger.warn(
          "#{inspect(device, pretty: true)} position is true after halt"
        )

        {:device_still_true, dc}

      {:ok, {:position, {:not_found, device}}, %Dutycycle{} = dc} ->
        Logger.warn(
          dc_name(dc) <>
            " device #{inspect(device, pretty: true)} does not exist at time of halt"
        )

        {:device_not_found, dc}

      error ->
        Logger.warn("halt() unhandled error: #{inspect(error, pretty: true)}")

        {:failed, error}
    end
  end

  def inactive?(%Dutycycle{active: val}), do: not val

  def log(%Dutycycle{log: log}, opts) when is_list(opts), do: {:ok, log: log}
  def log?(%Dutycycle{log: log}), do: log

  def persist_phase_end_timer(%Dutycycle{state: st} = dc, timer) do
    active_profile = Profile.active(dc)
    {rc, _state} = State.persist_phase_timer(st, active_profile, timer)

    if rc == :ok, do: reload(dc), else: dc
  end

  def profiles(%Dutycycle{profiles: profiles} = dc, opts \\ [])
      when is_list(opts) do
    only_active = Keyword.get(opts, :active, false)

    if only_active,
      do: Profile.active(dc),
      else:
        for(
          %Profile{name: name, active: active} <- profiles,
          do: %{profile: name, active: active}
        )
  end

  def reload(%Dutycycle{id: id}), do: reload(id)

  def reload(id) when is_number(id),
    do:
      Repo.get!(Dutycycle, id)
      |> preload([:state, :profiles], force: true)

  def scheduled_work_ms(%Dutycycle{scheduled_work_ms: ms}), do: ms

  def shutdown(%Dutycycle{name: name, log: log} = dc) do
    next_phase(:offline, dc)

    log &&
      Logger.info("#{inspect(name, pretty: true)} shutdown and marked offline")
  end

  def start(%Dutycycle{active: false} = dc) do
    Dutycycle.log?(dc) && Logger.info(fn -> dc_name(dc) <> " is inactive" end)

    {:ok, :inactive}
  end

  def start(%Dutycycle{active: true} = dc) do
    if Profile.none?(dc) do
      Dutycycle.log?(dc) &&
        Logger.info(fn -> dc_name(dc) <> " does not have an active profile" end)

      {:ok, :inactive}
    else
      active_profile = Profile.active(dc)

      Dutycycle.log?(dc) &&
        Logger.info(fn ->
          dc_name(dc) <>
            " will start with profile #{inspect(Profile.name(active_profile))}"
        end)

      {:ok, :run, active_profile}
    end
  end

  def status({:ok, dc}), do: status(dc)

  def status(%Dutycycle{name: name, active: active} = dc),
    do: [
      name: name,
      active_profile: Profile.active(dc) |> Profile.name(),
      active: active
    ]

  def status(anything), do: anything

  def update(dc, opts \\ [])

  def update(name, opts) when is_binary(name) and is_list(opts) do
    with dc <- find(name),
         {true, _name} <- {%Dutycycle{} = dc, name} do
      update(dc, opts)
    else
      {false, name} ->
        Logger.warn(
          "#{inspect(name, pretty: true)} does not exist, can't update"
        )

        {:not_found, name}
    end
  end

  def update(%Dutycycle{name: name, log: log} = dc, opts) when is_list(opts) do
    set = Keyword.take(opts, possible_changes()) |> Enum.into(%{})

    cs = changeset(dc, set)

    if cs.valid? do
      dc = update!(cs) |> reload()

      log &&
        Logger.info(
          "#{inspect(name, pretty: true)}" <>
            " updated " <> inspect(opts, pretty: true)
        )

      {:ok, dc}
    else
      {:invalid_changes, cs}
    end
  end

  defp activate(%Dutycycle{} = dc),
    do: update(dc, active: true)

  defp changeset(dc, params) when is_list(params),
    do: changeset(dc, Enum.into(params, %{}))

  defp changeset(dc, params) when is_map(params) do
    dc
    |> cast(params, possible_changes())
    |> validate_required(possible_changes())
    |> validate_format(:name, name_regex())
    |> unique_constraint(:name, name: :dutycycle_name_index)
  end

  # Private Functions

  defp control_device(
         %Dutycycle{
           device: device,
           state: %Dutycycle.State{dev_state: dev_state},
           log: log
         } = dc,
         opts \\ []
       )
       when is_list(opts) do
    lazy = Keyword.get(opts, :lazy, true)

    sw_state =
      Switch.position(device, position: dev_state, lazy: lazy, log: log)

    case sw_state do
      {:ok, position} ->
        log?(dc) && position == dev_state &&
          Logger.debug("#{control_device_log(dc)} position set correctly")

        not position == dev_state &&
          Logger.warn(
            "#{control_device_log(dc)} position #{inspect(sw_state)} " <>
              "is not #{inspect(dev_state)} (should be equal)"
          )

      {:not_found, _} ->
        log?(dc) && Logger.warn("#{control_device_log(dc)} does not exist")

      anything ->
        Logger.warn(
          "#{control_device_log(dc)} unmatched result #{
            inspect(anything, pretty: true)
          }"
        )
    end

    {:ok, {:position, sw_state}, dc}
  end

  defp control_device_log(%Dutycycle{device: device} = dc),
    do: dc_name(dc) <> " device #{inspect(device, pretty: true)}"

  defp deactivate(%Dutycycle{} = dc) do
    update(dc, active: false)
  end

  defp dc_name(%Dutycycle{name: name}), do: "#{inspect(name, pretty: true)}"
  defp dc_name(catchall), do: "#{inspect(catchall, pretty: true)} "

  defp possible_changes,
    do: [:name, :comment, :device, :log, :active, :scheduled_work_ms]
end
