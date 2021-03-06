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

  import Ecto.Query, only: [from: 2]

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
        Logger.warn([
          dc_name(dc),
          " does not have an active profile to activate"
        ])

        {:no_active_profile, dc}

      unhandled ->
        Logger.warn([
          dc_name(dc),
          " activate active profile unhandled condition ",
          inspect(unhandled, pretty: true)
        ])
    end
  end

  def activate_profile(%Dutycycle{log: log} = dc, profile, _opts)
      when is_binary(profile) do
    with {:ok, %Profile{}} <- Profile.activate(dc, profile),
         {:ok, dc} <- activate(dc),
         dc <- reload(dc),
         # use next_phase:2 to start the run phase and get the
         # active profile
         {:first_phase, {:ok, dc, active_profile, mode}} <-
           {:first_phase, next_phase(:run, dc)},
         {:control_device, {rc, pos}, dc}
         when rc in [:ok, :pending] and is_boolean(pos) <-
           control_device(dc, lazy: false) do
      log &&
        Logger.info([
          dc_name(dc),
          " activated profile ",
          inspect(Profile.name(active_profile)),
          " first phase ",
          inspect(mode, pretty: true)
        ])

      {:ok, reload(dc), active_profile, mode}
    else
      {:none, %Profile{}} ->
        Logger.warn([dc_name(dc), " deactivated, profile none"])

        {rc, dc} = deactivate(dc)

        {rc, reload(dc), %Profile{name: "none"}, :none}

      {:activate_profile_failed, error} ->
        Logger.warn(["activate failed ", inspect(error, pretty: true)])

        {:failed, profile, error}

      # HACK: should better handle when the device doesn't exist
      {:first_phase, {:control_device, {:not_found, _res}, _dc} = check} ->
        control_device_log(check)
        {:ok, profile, check}

      {:first_phase, {:control_device, _pos_res, _dc} = check} ->
        control_device_log(check)
        {:failed, profile, check}

      {:first_phase, error} ->
        Logger.warn(["next_phase() failed: ", inspect(error, pretty: true)])

      {:ok, {:position, pos}, dc} ->
        log?(dc) &&
          Logger.debug([
            dc_name(dc),
            " device state is ",
            inspect(pos, pretty: true),
            " after profile activation"
          ])

        {:ok, dc, Profile.active(dc), :run}

      {:control_device, _res, dc} = res ->
        control_device_log(res)
        {:failed, dc}

      error ->
        Logger.warn([
          "unhandled activate failure ",
          inspect(error, pretty: true)
        ])

        {:failed, dc}
    end
  end

  def active?(%Dutycycle{active: val}), do: val

  # def add(list) when is_list(list) do
  #   for(dc <- list) do
  #     add(dc)
  #   end
  # end

  def add(%Dutycycle{name: name} = dc) do
    cs = changeset(dc, Map.take(dc, possible_changes()))

    with {:cs_valid, true} <- {:cs_valid, cs.valid?()},
         {:ok, _dc} <- insert(cs),
         %Dutycycle{} = dc <- find(name) do
      reload(dc)
    else
      {:cs_valid, false} ->
        {:invalid_changes, cs}

      {:add_state, rc} ->
        Logger.warn([
          "add() failed to insert %State{}: ",
          inspect(rc, pretty: true)
        ])

      error ->
        Logger.warn(["add() failure: ", inspect(error, pretty: true)])

        {:failed, error}
    end
  end

  def add(catchall), do: {:failed, {:bad_args, catchall}}

  # FUNCTION HEADER
  def all(atom, opts \\ [])

  def all(:ids, opts) when is_list(opts) do
    from(dc in Dutycycle, select: dc.id) |> Repo.all()
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

  def dc_name(%Dutycycle{name: name}), do: inspect(name, pretty: true)
  def dc_name(catchall), do: inspect(catchall, pretty: true)

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
    Logger.warn([
      "invalid args: device_change(",
      inspect(d, pretty: true),
      " ",
      inspect(device, pretty: true),
      ")"
    ])

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

  defp next_phase(mode, %Dutycycle{} = dc, opts \\ []) when is_list(opts) do
    with {%Dutycycle{} = dc, {:ok, %State{}}} <-
           State.next_phase(mode, dc, log_transition: log?(dc)),
         dc <- reload(dc),
         {:control_device, {rc, _pos}, dc} when rc in [:ok, :pending] <-
           control_device(dc, opts) do
      active_profile = Profile.active(dc)
      {:ok, dc, active_profile, mode}
    else
      {:control_device, _pos_res, _dc} = check -> control_device_log(check)
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
         {:control_device, {rc, false}, dc} when rc in [:ok, :pending] <-
           control_device(dc, lazy: false) do
      {:ok, dc}
    else
      {:invalid_changes, errors} ->
        Logger.warn([inspect(errors, pretty: true)])
        dc = reload(dc)
        {:failed, dc}

      {:control_device, _pos_res, _dc} = check ->
        control_device_log(check)

      # {:ok, {:position, nil}, %Dutycycle{} = dc} ->
      #   {:ok, dc}
      #
      # {:ok, {:position, true}, %Dutycycle{device: device} = dc} ->
      #   Logger.warn([
      #     inspect(device, pretty: true),
      #     " position is true after halt"
      #   ])
      #
      #   {:device_still_true, dc}
      #
      # {:ok, {:position, {:not_found, device}}, %Dutycycle{} = dc} ->
      #   Logger.warn([
      #     dc_name(dc),
      #     " device ",
      #     inspect(device, pretty: true),
      #     " does not exist at time of halt"
      #   ])
      #
      #   {:device_not_found, dc}

      error ->
        Logger.warn(["halt() unhandled error: ", inspect(error, pretty: true)])

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
    profile_name = Keyword.get(opts, :profile, false)

    cond do
      only_active and not is_binary(profile_name) ->
        Profile.active(dc)

      is_binary(profile_name) ->
        Profile.find(dc, profile_name)

      # if no opts were specified return all profile names and active flag
      true ->
        for(
          %Profile{name: name, active: active} <- profiles,
          do: %{profile: name, active: active}
        )
    end
  end

  def reload(%Dutycycle{id: id}), do: reload(id)

  def reload(id) when is_number(id),
    do:
      Repo.get!(Dutycycle, id)
      |> preload([:state, :profiles], force: true)

  def scheduled_work_ms(%Dutycycle{scheduled_work_ms: ms}), do: ms

  def shutdown(%Dutycycle{name: name, log: log} = dc) do
    next_phase(:offline, dc, ack: false)

    log &&
      Logger.info([inspect(name, pretty: true), "shutdown and marked offline"])
  end

  def start(%Dutycycle{active: active} = dc) do
    no_active_profile = Profile.none?(dc)

    cond do
      not active ->
        log?(dc) && Logger.info([dc_name(dc), " is inactive"])
        # ensure the state represents the Dutycycle is up but inactive
        next_phase(:stop, dc)

        {:ok, :inactive}

      no_active_profile ->
        log?(dc) &&
          Logger.info([dc_name(dc), " does not have an active profile"])

        # ensure the state represents the Dutycycle is up but inactive
        next_phase(:stop, dc)

        {:ok, :inactive}

      true ->
        active_profile = Profile.active(dc)

        log?(dc) &&
          Logger.info([
            dc_name(dc),
            " will start with profile",
            inspect(Profile.name(active_profile), pretty: true)
          ])

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
        Logger.warn([
          inspect(name, pretty: true),
          "does not exist, can't update"
        ])

        {:not_found, name}
    end
  end

  def update(%Dutycycle{name: name, log: log} = dc, opts) when is_list(opts) do
    set = Keyword.take(opts, possible_changes()) |> Enum.into(%{})

    cs = changeset(dc, set)

    if cs.valid? do
      dc = update!(cs) |> reload()

      log &&
        Logger.info([
          inspect(name, pretty: true),
          " updated ",
          inspect(opts, pretty: true)
        ])

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
         opts
       )
       when is_list(opts) do
    sw_state =
      Switch.Alias.position(device,
        position: dev_state,
        lazy: Keyword.get(opts, :lazy, true),
        ack: Keyword.get(opts, :ack, true),
        log: log
      )

    sw_state =
      case sw_state do
        {rc, position} when is_list(position) ->
          {rc, Keyword.get(position, :position)}

        {rc, position} when is_boolean(position) ->
          {rc, position}

        {rc, position} ->
          {rc, position}
      end

    case sw_state do
      {rc, position} when rc in [:ok, :pending] ->
        log?(dc) && position == dev_state &&
          Logger.debug([control_device_log(dc), " position set correctly"])

        not position == dev_state &&
          Logger.warn([
            control_device_log(dc),
            "position ",
            inspect(sw_state),
            "is not ",
            inspect(dev_state),
            " (should be equal)"
          ])

      {:not_found, _} ->
        log?(dc) && Logger.warn([control_device_log(dc), " does not exist"])

      anything ->
        Logger.warn([
          control_device_log(dc),
          " unmatched result ",
          inspect(anything, pretty: true)
        ])
    end

    {:control_device, sw_state, dc}
  end

  defp control_device_log({:control_device, {pos_rc, _pos}, _dc} = rc)
       when pos_rc in [:ok, :pending],
       do: rc

  defp control_device_log(
         {:control_device, {:not_found, _pos},
          %Dutycycle{name: name, device: device} = _dc} = rc
       ) do
    Logger.warn([
      name,
      " device ",
      inspect(device, pretty: true),
      " does not exist"
    ])

    rc
  end

  defp control_device_log({:control_device, pos_res, _dc} = rc) do
    Logger.warn(["control_device_log() issue: ", inspect(pos_res, pretty: true)])

    rc
  end

  defp control_device_log(%Dutycycle{device: device} = dc),
    do: [dc_name(dc), " device ", inspect(device, pretty: true)]

  defp deactivate(%Dutycycle{} = dc) do
    update(dc, active: false)
  end

  defp possible_changes,
    do: [:name, :comment, :device, :log, :active, :scheduled_work_ms]
end
