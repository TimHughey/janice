defmodule DutycycleTest do
  @moduledoc """

  """

  use ExUnit.Case, async: false
  # import ExUnit.CaptureLog
  use Timex

  alias Dutycycle.Profile
  alias Dutycycle.Server
  alias Dutycycle.State

  setup do
    :ok
  end

  @moduletag :dutycycle
  setup_all do
    new_dcs = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 99]
    for n <- new_dcs, do: new_dutycycle(n) |> Dutycycle.add()
    :ok
  end

  def shared_dc, do: Dutycycle.get_by(name: fixed_name())

  def fixed_name, do: name_str(99)

  def get_an_id, do: Dutycycle.get_by(name: fixed_name()) |> Map.get(:id)

  def name_str(n), do: "dutycycle" <> String.pad_leading(Integer.to_string(n), 3, "0")

  def new_dutycycle(n) do
    num_str = String.pad_leading(Integer.to_string(n), 3, "0")
    dev_str = "dutycycle_sw" <> num_str

    %Dutycycle{
      name: name_str(n),
      comment: "test dutycycle " <> num_str,
      device: dev_str,
      profiles: [
        %Dutycycle.Profile{name: "fast", run_ms: 1, idle_ms: 1},
        %Dutycycle.Profile{name: "high", run_ms: 120_000, idle_ms: 60_000},
        %Dutycycle.Profile{name: "low", run_ms: 20_000, idle_ms: 20_000},
        %Dutycycle.Profile{name: "off", run_ms: 0, idle_ms: 60_000}
      ],
      state: %Dutycycle.State{},
      standalone: true
    }
  end

  test "%Dutycycle{} is defined and a schema" do
    dc = %Dutycycle{}

    assert is_map(dc)
    assert Dutycycle.__schema__(:source) == "dutycycle"
  end

  # test "all dutycycles" do
  #   all_dc = Dutycycle.all()
  #
  #   refute Enum.empty?(all_dc)
  # end

  test "all server names from supervisor" do
    server_names = Dutycycle.Supervisor.known_servers()

    empty = Enum.empty?(server_names)

    atom = if empty, do: nil, else: is_atom(hd(server_names))

    refute empty
    assert atom
  end

  # NEW!
  test "can get all Dutycycle names from server" do
    names = Dutycycle.Server.all(:names)

    binaries = for n <- names, do: is_binary(n)

    all_binary = Enum.count(names) == Enum.count(binaries)

    refute Enum.empty?(names)
    assert all_binary
  end

  # NEW!
  test "can get all Dutycycle names from database" do
    names = Dutycycle.all(:names)

    binaries = for n <- names, is_binary(n), do: n

    all_binary = Enum.count(names) == Enum.count(binaries)

    refute Enum.empty?(names)
    assert all_binary
  end

  # NEW!
  @tag num: 1000
  test "can ping detects not found dutycycle", context do
    rc = Server.ping(name_str(context[:num]))

    assert rc === :not_found
  end

  # NEW!
  @tag num: 4
  test "can ping a dutycycle server", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))

    rc = Server.ping(dc.name)

    assert rc === :pong
  end

  # NEW!
  @tag num: 4
  test "profile handles no active profile", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))

    active1 = Profile.active(dc)
    active2 = Profile.active(dc.profiles)

    assert active1 === :none
    assert active2 === :none
  end

  # NEW!
  @tag num: 4
  test "can get available profiles from server", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))

    profiles = Server.profiles(dc.name)
    profile = for p <- profiles, p.profile === "fast", do: p
    fast = if Enum.empty?(profile), do: false, else: hd(profile) |> Map.get(:active)

    refute Enum.empty?(profiles)
    refute fast
  end

  # NEW!
  @tag num: 4
  test "server returns :none when no active profile", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))

    active = Server.profiles(dc.name, only_active: true)

    assert active === :none
  end

  # NEW!
  @tag num: 5
  test "set state idle", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))
    Profile.activate(dc, "fast")

    dc = Dutycycle.get_by(name: name_str(context[:num]))
    rc = State.set(mode: "idle", dutycycle: dc)

    assert rc === :ok
  end

  test "set state handles bad args" do
    rc1 = State.set(mode: "bad mode")
    rc2 = State.set(dutycycle: %{})

    assert rc1 == :bad_args
    assert rc2 == :bad_args
  end

  # NEW!
  @tag num: 6
  test "set state handles missing active profile", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))

    new_state = State.set(mode: "idle", dutycycle: dc)

    assert new_state === :no_active_profile
  end

  # NEW!
  @tag num: 7
  test "server honors disabled", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))

    rc = Server.activate_profile(dc.name, "high")

    assert rc == :disabled
  end

  # NEW!
  @tag num: 8
  test "server enables a dutycycle", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))

    rc = Server.enable(dc.name)
    enabled = Server.enabled?(dc.name)

    assert rc == :ok
    assert enabled
  end

  # NEW!
  @tag num: 9
  test "server disables a dutycycle", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))

    rc1 = Server.enable(dc.name)
    rc2 = Server.disable(dc.name)
    enabled = Server.enabled?(dc.name)

    assert rc1 == :ok
    assert rc2 == :ok
    refute enabled
  end

  # NEW!
  @tag num: 10
  test "server shuts down when asked", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))

    rc = Server.shutdown(dc.name)

    assert rc == :ok
  end

  # NEW!
  @tag num: 11
  test "ping detects no dutycycle server", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))

    rc1 = Server.shutdown(dc.name)
    rc2 = Server.ping(dc.name)

    assert rc1 == :ok
    assert rc2 == :no_server
  end

  # NEW!
  @tag num: 12
  test "can get available profiles from server with active", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))
    rc1 = Server.enable(dc.name)
    rc2 = Server.activate_profile(dc.name, "fast")

    profiles = Server.profiles(dc.name)
    fast = for p <- profiles, p.profile === "fast", do: p
    active = if Enum.empty?(fast), do: false, else: hd(fast) |> Map.get(:active, false)

    assert rc1 === :ok
    assert rc2 === :ok
    refute Enum.empty?(profiles)
    assert active
  end

  # NEW!
  @tag num: 13
  test "can get only active profile from server", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))
    rc1 = Server.enable(dc.name)
    rc2 = Server.activate_profile(dc.name, "fast")

    active = Server.profiles(dc.name, only_active: true)

    assert rc1 === :ok
    assert rc2 === :ok
    assert active === "fast"
  end

  @tag num: 14
  test "can add a new profile", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))
    p = %Profile{name: "new profile", active: false, run_ms: 1000, idle_ms: 1000}
    np = Server.add_profile(dc.name, p)

    assert is_map(np)
    assert Map.has_key?(np, :id)
  end

  test "all dutycycle ids (with empty opts)" do
    all_dc = Dutycycle.all(:ids, [])

    empty = Enum.empty?(all_dc)
    has_id = if empty, do: false, else: is_integer(hd(all_dc))

    refute empty
    assert has_id
  end

  test "all dutycycle ids (with active: true)" do
    all_dc = Dutycycle.all(:ids, active: true)

    empty = Enum.empty?(all_dc)
    has_id = if empty, do: false, else: is_integer(hd(all_dc))

    refute empty
    assert has_id
  end

  test "get dutycycle by id" do
    id = get_an_id()

    dc = Dutycycle.get_by(id: id)

    assert dc.id === id
  end

  test "dutycycle as a map" do
    dc = shared_dc()

    m = Dutycycle.as_map(dc)

    assert is_map(m)
    assert Map.has_key?(m, :profiles)
    assert Map.has_key?(m, :state)
  end

  test "as_map(nil) returns empty map" do
    m = Dutycycle.as_map(nil)

    assert is_map(m)
  end
end
