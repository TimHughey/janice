defmodule DutycycleTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use JanTest

  # import ExUnit.CaptureLog

  alias Dutycycle.Profile
  alias Dutycycle.Server
  alias Dutycycle.State
  alias Dutycycle.Supervisor
  alias Janice.TimeSupport

  @tag alias_prefix: "dutycycle_sw"

  setup do
    :ok
  end

  setup context do
    base_context(context)
  end

  @moduletag :dutycycle
  setup_all do
    need_switches(
      [
        "dutycycle_sw0x0",
        "dutycycle_sw0x1",
        "dutycycle_sw0x2",
        "dutycycle_sw0x3",
        "dutycycle_sw0x4",
        "dutycycle_sw0x5",
        "dutycycle_sw0x6",
        "dutycycle_sw0x7",
        "dutycycle_sw0x8",
        "dutycycle_sw0x9",
        "dutycycle_sw0xa"
      ],
      sw_prefix: "dutcycle_dev",
      test_group: "dutycycle"
    )

    range = 0..10 |> Enum.to_list()

    for n <- range do
      new_dutycycle(n)
    end
    |> Dutycycle.Server.add()

    %Dutycycle{
      name: name_str(50),
      comment: "with an active profile",
      device: "no_device",
      active: true,
      log: true,
      startup_delay_ms: 100,
      profiles: [
        %Dutycycle.Profile{
          name: "slow",
          active: true,
          run_ms: 360_000,
          idle_ms: 360_000
        }
      ],
      state: %Dutycycle.State{}
    }
    |> Dutycycle.Server.add()

    :ok
  end

  def get_an_id, do: Dutycycle.find(name_str(0)) |> Map.get(:id)

  def name_from_db(num) when is_integer(num) do
    dc = load_dc(name_str(num))
    {dc, dc.name}
  end

  def load_dc(name) when is_binary(name), do: Dutycycle.find(name)

  def name_str(n),
    do: "dutycycle" <> String.pad_leading(Integer.to_string(n), 3, "0")

  def new_dutycycle(n) do
    num_str =
      ["0x", Integer.to_string(n, 16)]
      |> IO.iodata_to_binary()

    dev_str =
      ["dutycycle_sw", num_str] |> IO.iodata_to_binary() |> String.downcase()

    %Dutycycle{
      name: name_str(n),
      comment: "test dutycycle " <> num_str,
      device: dev_str,
      active: false,
      log: false,
      profiles: [
        %Dutycycle.Profile{name: "fast", run_ms: 3_000, idle_ms: 3_000},
        %Dutycycle.Profile{name: "very fast", run_ms: 99, idle_ms: 60_000},
        %Dutycycle.Profile{name: "slow", run_ms: 120_000, idle_ms: 60_000},
        %Dutycycle.Profile{name: "very slow", run_ms: 120_000, idle_ms: 60_000},
        %Dutycycle.Profile{name: "infinity", run_ms: 360_000, idle_ms: 360_000}
      ],
      state: %Dutycycle.State{}
    }
  end

  test "%Dutycycle{} is defined and a schema" do
    dc = %Dutycycle{}

    assert is_map(dc)
    assert Dutycycle.__schema__(:source) == "dutycycle"
  end

  test "can ping Dutycycle.Supervisor" do
    assert Supervisor.ping() === :pong
  end

  test "can get server names and pids from supervisor" do
    servers = Dutycycle.Supervisor.known_servers()
    first = List.first(servers)

    {_name, pid} = if is_nil(first), do: {nil, nil}, else: first

    refute Enum.empty?(servers)
    assert is_tuple(first)
    assert is_pid(pid)
  end

  test "can get all Dutycycle names from server" do
    names = Dutycycle.Server.all(:names)

    binaries = for n <- names, do: is_binary(n)

    all_binary = Enum.count(names) == Enum.count(binaries)

    refute Enum.empty?(names)
    assert all_binary
  end

  test "can get all Dutycycle names from database" do
    names = Dutycycle.all(:names)

    binaries = for n <- names, is_binary(n), do: n

    all_binary = Enum.count(names) == Enum.count(binaries)

    refute Enum.empty?(names)
    assert all_binary
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

  test "ping detects a non existance dutycycle server" do
    rc1 = Server.ping("foobar")

    assert rc1 == :not_found
  end

  test "get dutycycle by id" do
    id = get_an_id()

    dc = Dutycycle.find(id)

    assert dc.id === id
  end

  test "can detect an unknown Dutycycle when deleting" do
    dc = %Dutycycle{id: 0}
    rc = Dutycycle.delete(dc)

    assert is_list(rc)
    assert [server: :not_found, db: :not_found] == rc
  end

  test "server handles resuming an unkown dutycycle" do
    name = "foo"

    rc1 = Server.resume(name)

    assert :not_found === rc1
  end

  @tag num: 1000
  test "ping detects not found dutycycle", context do
    rc = Server.ping(name_str(context[:num]))

    assert rc === :not_found
  end

  @tag num: 1
  test "can ping a dutycycle server", context do
    {_dc, name} = name_from_db(context[:num])

    rc = Server.ping(name)

    assert rc === :pong
  end

  @tag num: 1
  test "the default active profile is none", context do
    {%Dutycycle{profiles: profiles} = dc, _name} = name_from_db(context[:num])

    active1 = Profile.active(dc)
    active2 = Profile.active(profiles)

    assert "none" === Profile.name(active1)
    assert "none" === Profile.name(active2)
  end

  @tag num: 1
  test "can get available profiles from server", context do
    {_dc, name} = name_from_db(context[:num])

    profiles = Server.profiles(name)
    profile = for p <- profiles, p.profile === "fast", do: p

    fast =
      if Enum.empty?(profile), do: false, else: hd(profile) |> Map.get(:active)

    refute Enum.empty?(profiles)
    refute fast
  end

  @tag num: 1
  @tag profile: "infinity"
  test "can get a %Profile{} by name via Dutycycle.Server", context do
    test_profile = context[:profile]
    {_dc, name} = name_from_db(context[:num])

    all_profiles = Dutycycle.Server.profiles(name)
    profile = Dutycycle.Server.profiles(name, profile: test_profile)

    assert is_list(all_profiles)
    assert %Profile{} = profile
    assert %Profile{name: ^test_profile} = profile
  end

  @tag num: 1
  test "can find a profile", context do
    {dc, _name} = name_from_db(context[:num])

    profile_found = Profile.find(dc, "infinity")
    profile_not_found = Profile.find(dc, "foobar")

    assert %Profile{} = profile_found
    assert profile_not_found === {:profile_not_found}
  end

  @tag num: 1
  test "can get Dutycycle State (cached and reloaded)", context do
    st1 = Server.dutycycle_state(name_str(context[:num]))
    st2 = Server.dutycycle_state(name_str(context[:num]), reload: true)

    assert is_map(st1)
    assert is_map(st2)
    assert st1.id == st2.id
  end

  @tag num: 1
  test "can delete a Dutycyle profile",
       context do
    {_dc, name} = name_from_db(context[:num])
    rc1 = Server.delete_profile(name, "slow")

    assert {:ok, %Profile{name: "slow"}} = rc1
  end

  @tag num: 1
  test "can check existance of profile",
       context do
    {dc, _name} = name_from_db(context[:num])

    does_exist = Profile.exists?(dc, "infinity")
    does_not_exist = Profile.exists?(dc, "foobar")

    assert does_exist
    refute does_not_exist
  end

  @tag num: 1
  test "can change properties of an existing profile", context do
    %{profile: profile, reload: reload} =
      Server.update_profile(name_str(context[:num]), "fast", run_ms: 49_152)

    assert {:ok, %Dutycycle.Profile{}} = profile
    assert reload === true
  end

  @tag num: 1
  test "can handle unknown profile when changing profile properties", context do
    rc =
      Server.update_profile(name_str(context[:num]), "foobar", run_ms: 49_152)

    assert rc === %{profile: {:error, :not_found}, reload: true}
  end

  @tag num: 1
  test "can add a new profile", context do
    p = %Profile{
      name: "new profile",
      active: false,
      run_ms: 1000,
      idle_ms: 1000
    }

    np = Server.add_profile(name_str(context[:num]), p)

    assert is_map(np)
    assert Map.has_key?(np, :id)
  end

  @tag num: 1
  test "can request reload of Dutycycle", context do
    rc = Server.reload(name_str(context[:num]))

    assert is_atom(rc)
    assert rc === :reload_queued
  end

  @tag num: 1
  test "can handle invalid properties when changing profile properties",
       context do
    %{profile: profile, reload: _} =
      Server.update_profile(name_str(context[:num]), "fast",
        run_ms: -1,
        idle_ms: -1,
        name: "slow"
      )

    {rc, cs} = profile

    assert :invalid_changes === rc
    refute cs.valid?()
  end

  @tag num: 2
  test "can get Dutycycle active", context do
    {dc, _name} = name_from_db(context[:num])

    active1 = Dutycycle.active?(dc)

    assert active1 === false
  end

  @tag num: 3
  test "can delete a Dutycycle by name via server",
       context do
    {_dc, name} = name_from_db(context[:num])

    rc = Server.delete(name)

    assert is_list(rc)
    assert [server: :ok, db: :ok] == rc
  end

  @tag num: 4
  test "can get only active profile from server and check it is active",
       context do
    {dc, name} = name_from_db(context[:num])

    {rc1, _profile} = Server.activate_profile(name, "fast")

    dc = Dutycycle.reload(dc)

    active = Server.profiles(name, active: true)

    rc2 = Profile.active?(dc, active)

    assert :ok === rc1
    assert Profile.name(active) === "fast"
    assert rc2 === true
  end

  @tag num: 5
  test "can restart a dutycycle server",
       context do
    {rc, _child} = Server.restart(name_str(context[:num]))

    assert rc == :ok
  end

  @tag num: 6
  test "dutycycle server state changes from running to idling",
       context do
    {dc, name} = name_from_db(context[:num])
    {rc1, _profile} = Server.activate_profile(name, "very fast")

    dc = Dutycycle.reload(dc)

    %State{state: first_state, started_at: started} =
      Server.dutycycle_state(dc.name)

    Process.sleep(101)
    %State{state: second_state} = Server.dutycycle_state(dc.name)

    assert :ok == rc1
    assert Timex.before?(started, TimeSupport.utc_now())
    assert first_state === "running"
    assert second_state === "idling"
  end

  @tag num: 6
  test "can change the name when changing profile properties",
       context do
    %{profile: res, reload: reload} =
      Server.update_profile(name_str(context[:num]), "slow",
        run_ms: 1,
        idle_ms: 1,
        name: "new_profile"
      )

    {rc, p} = res

    assert :ok === rc
    assert reload
    assert %Dutycycle.Profile{} = p
    assert Dutycycle.Profile.name(p) === "new_profile"
  end

  @tag num: 6
  test "can update properties of an existing profile with human friendly times",
       context do
    %{profile: res, reload: reload} =
      Server.update_profile(name_str(context[:num]), "very slow",
        run: {:mins, 11},
        idle: {:hrs, 1}
      )

    {rc, p} = res

    assert :ok === rc
    assert reload
    assert %Dutycycle.Profile{} = p
  end

  @tag num: 6
  test "server can update Dutycycle device",
       context do
    name = name_str(context[:num])
    rc = Server.change_device(name, "diff_device")

    assert :ok === rc
  end

  @tag num: 7
  test "can halt and resume a known dutycycle",
       context do
    {_dc, name} = name_from_db(context[:num])
    {rc1, res} = Server.activate_profile(name, "slow")

    rc2 = Server.halt(name)
    %Dutycycle{state: %State{started_at: started_at}} = Dutycycle.find(name)
    rc3 = Server.resume(name)

    assert :ok == rc1
    assert is_list(res)
    assert res[:name] == name
    assert res[:active_profile] == "slow"
    assert {:ok, %Dutycycle{}} = rc2
    refute is_nil(started_at)
    # assert {:failed, {:ok, {:position, {:not_found, _}}}, %Dutycycle{}} = rc2
    assert {:ok, _profile} = rc3
  end

  @tag num: 8
  test "can do general updates to Dutycycle",
       context do
    {dc, _name} = name_from_db(context[:num])

    {rc, dc} =
      Dutycycle.update(dc, comment: "new comment", name: "updated name")

    rc2 = Server.ping("updated name")

    assert rc == :ok
    assert %Dutycycle{} = dc
    assert rc2 == :pong
    assert dc.name == "updated name"
    assert dc.comment == "new comment"
  end

  @tag num: 9
  test "can handle duplicate name when changing profile properties",
       context do
    %{profile: profile, reload: _} =
      Server.update_profile(name_str(context[:num]), "fast",
        run_ms: 1,
        idle_ms: 1,
        name: "slow"
      )

    {rc, cs} = profile

    assert :error === rc
    refute cs.valid?()
  end

  @tag num: 10
  test "dutycycle server handles activating the active profile",
       context do
    {dc, name} = name_from_db(context[:num])
    {rc1, _profile} = Server.activate_profile(name, "infinity")

    dc = Dutycycle.reload(dc)

    %State{state: first_state, started_at: started} =
      Server.dutycycle_state(dc.name)

    Process.sleep(100)
    {rc2, _profile} = Server.activate_profile(name, "infinity")
    %State{state: second_state} = Server.dutycycle_state(dc.name)

    assert :ok == rc1
    assert :ok == rc2
    assert Timex.before?(started, TimeSupport.utc_now())
    assert first_state === "running"
    assert second_state === "running"
  end
end
