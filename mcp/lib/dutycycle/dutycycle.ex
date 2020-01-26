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

  import Repo, only: [one: 1, insert_or_update!: 1, update!: 1, preload: 3]

  import Ecto.Changeset,
    only: [cast: 3, validate_required: 2, validate_format: 3]

  import Ecto.Query, only: [from: 2]

  import Janice.Common.DB, only: [name_regex: 0]

  alias Dutycycle.Profile
  alias Dutycycle.Server
  alias Dutycycle.State

  schema "dutycycle" do
    field(:name)
    field(:comment)
    field(:log, :boolean)
    field(:last_profile)
    field(:device)
    field(:stopped, :boolean)
    has_one(:state, State)
    has_many(:profiles, Profile)

    timestamps(usec: true)
  end

  def activate_profile(dc, name, opts \\ [])

  # REFACTORED!
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

  # REFACTORED!
  def activate_profile(%Dutycycle{name: name, log: log} = dc, profile, _opts)
      when is_binary(profile) do
    with {:ok, %Profile{} = new_profile} <-
           Profile.activate(dc, profile),
         dc <- reload(dc),
         {:state_run, {dc, {:ok, _st}}} <- {:state_run, State.run(dc)},
         {:ok, dc} <- Dutycycle.stopped(dc, false) do
      log &&
        Logger.debug(fn ->
          "dutycycle #{inspect(name)} profile #{
            inspect(Profile.name(new_profile))
          } activated"
        end)

      {:ok, reload(dc), new_profile, :run}
    else
      {:none, %Profile{}} ->
        {rc, dc} = Dutycycle.stopped(dc, true)

        Logger.warn(fn ->
          "stopping dutycycle due to none profile"
        end)

        {rc, reload(dc), %Profile{name: "none"}, :none}

      {:activate_profile_failed, error} ->
        Logger.warn(fn ->
          "activate failed #{inspect(error, pretty: true)}"
        end)

        {:failed, profile, error}

      {:state_run, error} ->
        Logger.warn(fn ->
          "State.run() failed: #{inspect(error, pretty: true)}"
        end)

      error ->
        Logger.warn(fn ->
          "unhandled activate failure #{inspect(error, pretty: true)}"
        end)

        {:failed, dc}
    end
  end

  def add([]), do: []

  def add([%Dutycycle{} = dc | rest]) do
    [add(dc)] ++ add(rest)
  end

  def add(%Dutycycle{name: name} = dc) do
    q = from(d in Dutycycle, where: d.name == ^name, select: {d})

    case one(q) do
      nil ->
        dc =
          Map.put(dc, :state, %State{}) |> changeset([]) |> insert_or_update!()

        Server.start_server(dc)

      found ->
        Logger.warn(~s/add() [#{dc.name}] already exists/)
        found
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

  # REFACTORED!
  def current_state(%Dutycycle{state: _state} = dc, opts \\ [])
      when is_list(opts) do
    reload = Keyword.get(opts, :reload, false)

    dc = if reload, do: reload(dc), else: dc

    {dc, dc.state}
  end

  # REFACTORED!
  # HAS TEST CASE
  def delete(%Dutycycle{id: id}, opts \\ [timeout: 5 * 60 * 1000]) do
    dc =
      Repo.get(Dutycycle, id)
      |> preload([:state, :profiles], force: true)

    if is_nil(dc),
      do: [server: :not_found, db: :not_found],
      else: [server: Server.delete(dc), db: elem(Repo.delete(dc, opts), 0)]
  end

  # REFACTORED!
  # HAS TEST CASE
  def delete_all(:dangerous) do
    for dc <- Repo.all(Dutycycle), do: delete(dc)
  end

  def device_change(%Dutycycle{} = d, new_device) when is_binary(new_device) do
    # reload the Dutycycle to be safe
    dc = reload(d)

    update(dc, device: new_device)
  end

  def device_change(d, device) do
    Logger.warn(fn ->
      "invalid args: device_change(#{inspect(d, pretty: true)}, #{
        inspect(device, pretty: true)
      }"
    end)

    {:error, :invalid_args}
  end

  # REFACTORED!
  # primary entry point for handling the end of phase
  def end_of_phase(%Dutycycle{} = dc) do
    active_profile = Profile.active(dc)

    end_of_phase(dc, active_profile)
  end

  # REFACTORED!
  # when a dutycycle is running and idle_ms == 0 keep running
  # however update the state to reflect the start of a new phase
  defp end_of_phase(
         %Dutycycle{state: %State{state: "running"}} = dc,
         %Profile{idle_ms: 0}
       ),
       do: next_phase(:run, dc)

  # REFACTORED!
  # when a dutycycle is running and idle_ms > 0 then start the idle phase
  defp end_of_phase(
         %Dutycycle{state: %State{state: "running"}} = dc,
         %Profile{idle_ms: _ms}
       ),
       do: next_phase(:idle, dc)

  # REFACTORED!
  # when a dutycycle is idling and run_ms == 0 keep idling
  # however update the state to reflect the start of a new phase
  defp end_of_phase(
         %Dutycycle{state: %State{state: "idling"}} = dc,
         %Profile{run_ms: 0}
       ),
       do: next_phase(:run, dc)

  # REFACTORED!
  # when a dutycycle is idling and run_ms > 0 then start the run phase
  defp end_of_phase(
         %Dutycycle{state: %State{state: "idling"}} = dc,
         %Profile{run_ms: _ms}
       ),
       do: next_phase(:run, dc)

  # REFACTORED!
  defp next_phase(mode, %Dutycycle{log: log} = dc) do
    with {%Dutycycle{} = dc, {:ok, %State{}}} <- State.next_phase(mode, dc),
         dc <- reload(dc),
         {:ok, {:position, _postition}, dc} <- control_device(dc, log: log) do
      active_profile = Profile.active(dc)
      {:ok, dc, active_profile, mode}
    else
      error -> error
    end
  end

  def get_by(opts) when is_list(opts) do
    filter = Keyword.take(opts, [:id, :device, :name])

    select =
      Keyword.take(opts, [:only]) |> Keyword.get_values(:only) |> List.flatten()

    if Enum.empty?(filter) do
      Logger.warn(fn -> "get_by bad args: #{inspect(opts, pretty: true)}" end)
      []
    else
      dc =
        from(
          d in Dutycycle,
          join: p in assoc(d, :profiles),
          join: s in assoc(d, :state),
          where: ^filter,
          preload: [state: s, profiles: p]
        )
        |> one()

      if is_nil(dc) or Enum.empty?(select), do: dc, else: Map.take(dc, select)
    end
  end

  # REFACTORED!
  def lookup_id(name) when is_binary(name) do
    with query <-
           from(
             d in Dutycycle,
             where: [name: ^name],
             select: [:id]
           ),
         %Dutycycle{id: id} <- one(query) do
      id
    else
      _error ->
        nil
    end
  end

  # REFACTORED!
  def persist_phase_end_timer(%Dutycycle{state: st} = dc, timer) do
    active_profile = Profile.active(dc)
    {rc, _state} = State.persist_phase_timer(st, active_profile, timer)

    if rc == :ok, do: reload(dc), else: dc
  end

  # REFACTORED!
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

  # REFACTORED!
  def reload(%Dutycycle{id: id}), do: reload(id)

  # REFACTORED!
  def reload(id) when is_number(id),
    do:
      Repo.get!(Dutycycle, id)
      |> preload([:state, :profiles], force: true)

  def stop(%Dutycycle{log: log} = dc) do
    with {%Dutycycle{}, {:ok, %State{}}} <- State.stop(dc),
         {:ok, %Dutycycle{}} <- stopped(dc, true),
         {:reload, %Dutycycle{} = dc} <- {:reload, reload(dc)},
         {:ok, {:position, false}, dc} <-
           control_device(dc, lazy: true, log: log) do
      {:ok, dc}
    else
      {:invalid_changes, errors} ->
        Logger.warn(fn -> "#{inspect(errors, pretty: true)}" end)
        dc = reload(dc)
        {:failed, dc}

      {:ok, {:position, nil}, %Dutycycle{} = dc} ->
        {:ok, dc}

      {:ok, {:position, pos}, %Dutycycle{device: device} = dc} ->
        Logger.warn(fn ->
          inspect(device) <>
            "state is " <>
            inspect(pos, pretty: true) <>
            "after stop"
        end)

        {:device_still_true, dc}

      error ->
        Logger.warn(fn ->
          "stop() unhandled error: #{inspect(error, pretty: true)}"
        end)

        {:failed, error}
    end
  end

  def start(%Dutycycle{stopped: true, name: name, log: log}) do
    log && Logger.debug(fn -> "#{inspect(name)} stopped is true" end)

    {:ok, :stopped}
  end

  def start(%Dutycycle{stopped: false, name: name, log: log} = dc) do
    if Profile.none?(dc) do
      log &&
        Logger.info(fn ->
          "dutycycle #{inspect(name)} does not have " <>
            "an active profile"
        end)

      {:ok, :stopped}
    else
      active_profile = Profile.active(dc)

      log &&
        Logger.info(fn ->
          "dutycycle #{inspect(name)} will start with " <>
            " active profile #{inspect(active_profile)}"
        end)

      {:ok, :run, active_profile}
    end
  end

  def stopped(%Dutycycle{} = dc, stop) when is_boolean(stop),
    do: update(dc, stopped: stop)

  def stopped?(%Dutycycle{stopped: val}), do: val

  def update(dc, opts \\ [])

  def update(name, opts) when is_binary(name) and is_list(opts),
    do: get_by([name: name] ++ opts) |> update(opts)

  def update(%Dutycycle{} = dc, opts) when is_list(opts) do
    set = Keyword.take(opts, possible_changes()) |> Enum.into(%{})

    cs = changeset(dc, set)

    if cs.valid? do
      dc = update!(cs) |> reload()
      {:ok, dc}
    else
      {:invalid_changes, cs}
    end
  end

  def update(nil, _opts) do
    Logger.warn(fn ->
      "attempted to update a dutycycle that does not exist"
    end)

    {:error, :not_found}
  end

  defp changeset(dc, params) when is_list(params),
    do: changeset(dc, Enum.into(params, %{}))

  defp changeset(dc, params) when is_map(params) do
    dc
    |> cast(params, possible_changes())
    |> validate_required(possible_changes())
    |> validate_format(:name, name_regex())
  end

  # Private Functions
  # REFACTORED!
  defp control_device(
         %Dutycycle{
           device: device,
           state: %Dutycycle.State{dev_state: dev_state}
         } = dc,
         opts
       )
       when is_list(opts) do
    lazy = Keyword.get(opts, :lazy, true)
    ack = Keyword.get(opts, :ack, true)
    log = Keyword.get(opts, :log, false)

    sw_state =
      Switch.state(device, position: dev_state, lazy: lazy, ack: ack, log: log)

    log && is_nil(sw_state) &&
      Logger.warn(fn ->
        "#{inspect(device)} position is nil, does it exist?"
      end)

    {:ok, {:position, sw_state}, dc}
  end

  # REFACTORED!
  defp dc_name(%Dutycycle{name: name}), do: "#{inspect(name)}"
  defp dc_name(catchall), do: "#{inspect(catchall, pretty: true)}"

  # REFACTORED!
  # defp dev_state(device) when is_binary(device) do
  #   dev_state = Switch.state(device)
  #
  #   if is_nil(dev_state), do: false, else: dev_state
  # end

  # REFACTORED!
  defp possible_changes, do: [:name, :comment, :device, :last_profile, :stopped]
end
