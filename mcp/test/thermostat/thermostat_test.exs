defmodule ThermostatTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  use JanTest

  import JanTest, only: [create_temp_sensor: 4]

  alias Thermostat.Profile
  alias Thermostat.Server

  setup do
    :ok
  end

  @moduletag :thermostat
  setup_all do
    sw_aliases = make_sw_alias_names("thermostat", 14)

    need_switches(sw_aliases,
      sw_prefix: "thermost_dev",
      test_group: "thermostat"
    )

    new_ths = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 99]
    for n <- new_ths, do: new_thermostat(n) |> Thermostat.add()

    :ok
  end

  def name_str(n),
    do: "thermostat" <> String.pad_leading(Integer.to_string(n), 3, "0")

  def new_thermostat(n) do
    num_str = String.pad_leading(Integer.to_string(n), 3, "0")
    sensor = "thermostat" <> num_str
    follow_sensor = "thermostat_follow" <> num_str

    sw_name = make_sw_alias_name("thermostat", n)

    create_temp_sensor("thermostat", sensor, n, tc: 24.0)
    create_temp_sensor("thermostat_follow", follow_sensor, n, tc: 25.0)

    %Thermostat{
      name: name_str(n),
      description: "test thermostat " <> num_str,
      switch: sw_name,
      sensor: sensor,
      log: false,
      profiles: [
        %Profile{
          name: "follow",
          ref_sensor: follow_sensor
        },
        %Profile{name: "fixed_25", fixed_setpt: 25.0},
        %Profile{
          name: "fixed_26",
          fixed_setpt: 26.0,
          low_offset: -0.6,
          high_offset: 0.4
        }
      ]
    }
  end

  test "%Thermostat{} is defined and a schema" do
    th = %Thermostat{}

    assert is_map(th)
    assert Thermostat.__schema__(:source) == "thermostat"
  end

  test "can get available profiles by thermostat name" do
    profiles = Server.profiles(name_str(0), names: true)

    assert "follow" in profiles
    assert "fixed_25" in profiles
    assert "fixed_26" in profiles
    assert "standby" in profiles
  end

  test "can get full profiles by thermostat name" do
    profiles = Server.profiles(name_str(0))

    assert Enum.all?(profiles, fn x -> %Thermostat.Profile{} = x end)
  end

  test "can ping a server by thermostat name" do
    res = Server.ping(name_str(0))

    assert res === :pong
  end

  test "thermostat server handles non-existent thermostat" do
    rc = Server.ping(name_str(999))

    assert rc == :not_found
  end

  @tag num: 99
  test "can restart a thermostat server",
       context do
    {rc, pid} = Server.restart(name_str(context[:num]))

    assert rc == :ok
    assert is_pid(pid)
  end

  test "can get the state of a new thermostat" do
    state = Server.state(name_str(0))

    assert state in ["new", "started", "off"]
  end

  test "can get all known thermostats" do
    res = Server.all(:thermostats)
    all_maps = Enum.all?(res, fn x -> is_map(x) end)

    assert length(res) >= 15
    assert all_maps
  end

  test "can get all known thermostat names" do
    res = Server.all(:names)

    all_bin = Enum.all?(res, fn x -> is_binary(x) end)

    assert length(res) >= 15
    assert all_bin
  end

  test "temperature control turns on when val < set_pt" do
    m = %{low_offset: 0.4, high_offset: 0.6}
    res = Thermostat.Control.next_state(m, "off", 11.0, 10.0)

    assert res === "on"
  end

  test "temperature control turns off when val > set_pt" do
    m = %{low_offset: 0.4, high_offset: 0.6}
    res = Thermostat.Control.next_state(m, "on", 10.0, 11.0)

    assert res === "off"
  end

  test "temperature control handles nil value and stopped state" do
    res = Thermostat.Control.next_state(%{}, "stopped", nil, nil)

    assert res === "off"
  end

  test "can set state directly on a %Thermostat{}" do
    new_state = "on"
    t = Thermostat.get_by(name: name_str(5))
    prev_state = Thermostat.state(t)

    {rc, t2} = Thermostat.state(t, new_state)

    assert rc == :ok
    refute prev_state === new_state
    assert t2.state === new_state
  end

  test "can activate profile %Thermostat{} and check profile exists" do
    t = Thermostat.get_by(name: name_str(6))

    {rc1, t2} = Thermostat.activate_profile(t, "fixed_26")
    active = Profile.active(t2)

    {rc2, _t3} = Thermostat.activate_profile(t, "bad")

    assert rc1 === :ok
    assert active.name === "fixed_26"
    assert is_list(t2.profiles)
    assert rc2 === :unknown_profile
  end

  test "can add a new %Profile{}" do
    p = %Profile{name: "optimal", fixed_setpt: 27.5}

    rc = Server.add_profile(name_str(8), p)

    assert rc > 0
  end

  test "update profile detects unknown profile" do
    p = %Profile{name: "bad", low_offset: -0.2, high_offset: 0.2}

    rc = Server.update_profile(name_str(9), p)

    assert rc === :unknown_profile
  end

  test "can update known profile" do
    np = %{name: "fixed_25", low_offset: -0.2, high_offset: 0.2}

    rc = Server.update_profile(name_str(10), np)
    t = Thermostat.get_by(name: name_str(10))

    {rc2, t} = Thermostat.activate_profile(t, "fixed_25")

    p = Profile.active(t)

    assert rc === :ok
    assert rc2 === :ok
    assert p.low_offset === -0.2
    assert p.high_offset == 0.2
  end

  test "can update known profile and request reload" do
    np = %{name: "fixed_25", low_offset: -0.2, high_offset: 0.2}

    rc = Server.update_profile(name_str(11), np, reload: true)
    t = Thermostat.get_by(name: name_str(11))

    {rc2, t} = Thermostat.activate_profile(t, "fixed_25")

    p = Profile.active(t)

    assert rc === :ok
    assert rc2 === :ok
    assert p.low_offset === -0.2
    assert p.high_offset == 0.2
  end

  test "can stop a Thermostat" do
    rc = Thermostat.Server.stop(name_str(12))
    state = Thermostat.Server.state(name_str(12))

    assert rc === :ok
    assert state in ["stopped", "off"]
  end

  test "can update a Themostat via the server" do
    {rc, res} = Thermostat.Server.update(name_str(13), switch_check_ms: 200)

    assert rc === :ok
    assert is_map(res)
    assert Map.has_key?(res, :thermostat)
    assert %Thermostat{} = Map.get(res, :thermostat)
  end

  test "can handle bad opts to Thermostat update via server" do
    func = fn ->
      {_rc, _res} = Thermostat.Server.update(name_str(13), switch_check_ms: 0)
    end

    msg = capture_log(func)

    assert msg =~ "must be greater than"
  end

  test "can create default Thermostat" do
    t = %Thermostat{
      name: "defaults",
      switch: "default_sw",
      sensor: "default_sensor",
      description: "default description",
      switch_check_ms: 5000,
      log: true
    }

    rc = Thermostat.add(t)
    alive = Thermostat.Server.ping("defaults")
    profiles = Thermostat.Server.profiles("defaults", names: true)

    assert :ok === rc
    assert :pong === alive
    assert "standby" in profiles
  end

  test "can set Thermostat to standby" do
    rc = Server.standby(name_str(0))

    assert :ok === rc
  end
end
