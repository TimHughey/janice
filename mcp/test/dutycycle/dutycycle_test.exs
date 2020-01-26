defmodule DutycycleTest do
  @moduledoc false

  use ExUnit.Case, async: true
  # import ExUnit.CaptureLog

  alias Dutycycle.Profile
  alias Dutycycle.Server
  alias Dutycycle.State
  alias Dutycycle.Supervisor

  setup do
    :ok
  end

  @moduletag :dutycycle
  setup_all do
    ids = 0..24
    new_dcs = Enum.to_list(ids) ++ [99]

    for n <- new_dcs, do: new_dutycycle(n) |> Dutycycle.add()
    :ok
  end

  def name_from_db(num) when is_integer(num) do
    dc = load_dc(name_str(num))
    {dc, dc.name}
  end

  def load_dc(name) when is_binary(name), do: Dutycycle.get_by(name: name)

  def shared_dc, do: Dutycycle.get_by(name: fixed_name())

  def fixed_name, do: name_str(99)

  def get_an_id, do: Dutycycle.get_by(name: fixed_name()) |> Map.get(:id)

  def name_str(n),
    do: "dutycycle" <> String.pad_leading(Integer.to_string(n), 3, "0")

  def new_dutycycle(n) do
    num_str = String.pad_leading(Integer.to_string(n), 3, "0")
    dev_str = "dutycycle_sw" <> num_str

    %Dutycycle{
      name: name_str(n),
      comment: "test dutycycle " <> num_str,
      device: dev_str,
      last_profile: "none",
      stopped: true,
      log: true,
      profiles: [
        %Dutycycle.Profile{name: "fast", run_ms: 3_000, idle_ms: 3_000},
        %Dutycycle.Profile{name: "slow", run_ms: 120_000, idle_ms: 60_000},
        %Dutycycle.Profile{name: "low", run_ms: 20_000, idle_ms: 20_000}
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

    dc = Dutycycle.get_by(id: id)

    assert dc.id === id
  end

  @tag num: 1000
  test "ping detects not found dutycycle", context do
    rc = Server.ping(name_str(context[:num]))

    assert rc === :not_found
  end

  @tag num: 1
  test "can ping a dutycycle server", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))

    rc = Server.ping(dc.name)

    assert rc === :pong
  end

  @tag num: 1
  test "the default active profile is none", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))

    active1 = Profile.active(dc)
    active2 = Profile.active(dc.profiles)

    assert "none" === Profile.name(active1)
    assert "none" === Profile.name(active2)
  end

  @tag num: 1
  test "can get available profiles from server", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))

    profiles = Server.profiles(dc.name)
    profile = for p <- profiles, p.profile === "fast", do: p

    fast =
      if Enum.empty?(profile), do: false, else: hd(profile) |> Map.get(:active)

    refute Enum.empty?(profiles)
    refute fast
  end

  @tag num: 1
  test "can detect non-existant profile", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))

    profile_exists = Profile.exists?(dc, "foobar")

    assert is_nil(profile_exists)
  end

  @tag num: 1
  test "can get a Dutycycle id by name", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))

    id = Dutycycle.lookup_id(name_str(context[:num]))

    assert is_number(id)
    assert id == dc.id
  end

  @tag num: 1
  test "can find a profile", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))

    profile_found = Profile.find(dc, "fast")
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
    assert st1 == st2
  end

  @tag num: 2
  test "can get Dutycycle 'stopped' and it defaults to true", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))

    stopped = Dutycycle.stopped?(dc)

    assert stopped === true
  end

  @tag num: 3
  test "can set Dutycycle 'stopped' to false", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))

    {rc, dc} = Dutycycle.stopped(dc, false)

    stopped = Dutycycle.stopped?(dc)

    assert rc === :ok
    assert stopped === false
  end

  @tag num: 4
  test "can delete an existing Dutycycle ", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))
    rc = Dutycycle.delete(dc)

    assert is_list(rc)
    assert [server: :ok, db: :ok] == rc
  end

  test "can detect an unknown Dutycycle when deleting" do
    dc = %Dutycycle{id: 0}
    rc = Dutycycle.delete(dc)

    assert is_list(rc)
    assert [server: :not_found, db: :not_found] == rc
  end

  @tag num: 5
  test "can get only active profile from server and check it is active",
       context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))

    {rc1, _profile} = Server.activate_profile(dc.name, "fast")

    dc = Dutycycle.reload(dc)

    active = Server.profiles(dc.name, active: true)

    rc2 = Profile.active?(dc, active)

    assert :ok === rc1
    assert Profile.name(active) === "fast"
    assert rc2 === true
  end

  @tag num: 6
  test "can restart a dutycycle server",
       context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))

    {rc, _child} = Server.restart(dc.name)

    assert rc == :ok
  end

  @tag num: 7
  test "can check existance of profile",
       context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))
    does_exist = Profile.exists?(dc, "fast")
    does_not_exist = Profile.exists?(dc, "foobar")

    assert does_exist
    refute does_not_exist
  end

  @tag num: 8
  test "dutycycle server state changes from running to idling",
       context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))

    {rc1, _profile} = Server.activate_profile(dc.name, "fast")

    dc = Dutycycle.reload(dc)

    %State{state: first_state} = Server.dutycycle_state(dc.name)

    Process.sleep(3200)

    %State{state: second_state} = Server.dutycycle_state(dc.name)

    assert :ok === rc1
    assert first_state === "running"
    assert second_state === "idling"
  end

  @tag num: 13
  test "can change properties of an existing profile", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))
    {rc1, _dcn} = Server.activate_profile(dc.name, "fast")

    %{profile: profile, reload: reload} =
      Server.update_profile(name_str(context[:num]), "fast", run_ms: 49_152)

    assert rc1 === :ok
    assert {:ok, %Dutycycle.Profile{}} = profile
    assert reload === true
  end

  @tag num: 13
  test "can handle unknown profile when changing profile properties", context do
    rc =
      Server.update_profile(name_str(context[:num]), "foobar", run_ms: 49_152)

    assert rc === %{profile: {:error, :not_found}, reload: true}
  end

  @tag num: 14
  test "can add a new profile", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))

    p = %Profile{
      name: "new profile",
      active: false,
      run_ms: 1000,
      idle_ms: 1000
    }

    np = Server.add_profile(dc.name, p)

    assert is_map(np)
    assert Map.has_key?(np, :id)
  end

  @tag num: 15
  test "can request reload of Dutycycle", context do
    dc = Dutycycle.get_by(name: name_str(context[:num]))
    rc = Server.reload(dc.name)

    assert is_atom(rc)
    assert rc === :reload_queued
  end

  @tag num: 16
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

  @tag num: 17
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

  @tag num: 18
  test "can change the name when changing profile properties",
       context do
    %{profile: res, reload: reload} =
      Server.update_profile(name_str(context[:num]), "fast",
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

  @tag num: 19
  test "can update properties of an existing profile with human friendly times",
       context do
    %{profile: res, reload: reload} =
      Server.update_profile(name_str(context[:num]), "fast",
        run: {:mins, 11},
        idle: {:hrs, 1}
      )

    {rc, p} = res

    assert :ok === rc
    assert reload
    assert %Dutycycle.Profile{} = p
  end

  @tag num: 21
  test "can stop and resume a known dutycycle",
       context do
    {_dc, name} = name_from_db(context[:num])
    rc1 = Server.activate_profile(name, "slow")

    rc2 = Server.pause(name)
    rc3 = Server.resume(name)

    assert {:ok, _profile} = rc1
    assert {:ok, %Dutycycle{}} = rc2
    assert {:ok, _profile} = rc3
  end

  @tag num: 22
  test "server can update Dutycycle device",
       context do
    name = name_str(context[:num])
    rc = Server.change_device(name, "diff_device")

    assert :ok === rc
  end

  @tag num: 23
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

  @tag num: 24
  test "can delete a Dutycycle by name via server",
       context do
    {_dc, name} = name_from_db(context[:num])

    rc = Server.delete(name)

    assert is_list(rc)
    assert [server: :ok, db: :ok] == rc
  end

  test "server handles resuming an unkown dutycycle" do
    name = "foo"

    rc1 = Server.resume(name)

    assert :not_found === rc1
  end
end
