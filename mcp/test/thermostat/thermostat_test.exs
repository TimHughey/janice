defmodule ThermostatTest do
  @moduledoc false

  use ExUnit.Case, async: false
  # import ExUnit.CaptureLog
  use Timex

  import JanTest, only: [create_switch: 5, create_temp_sensor: 4, device: 2]

  alias Thermostat.Profile
  alias Thermostat.Server

  setup do
    :ok
  end

  @moduletag :thermostat
  setup_all do
    new_ths = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 99]
    for n <- new_ths, do: new_thermostat(n) |> Thermostat.add()
    :ok
  end

  def name_str(n), do: "thermostat" <> String.pad_leading(Integer.to_string(n), 3, "0")

  def new_thermostat(n) do
    num_str = String.pad_leading(Integer.to_string(n), 3, "0")
    sensor = "thermostat" <> num_str
    follow_sensor = "thermostat_follow" <> num_str

    create_switch("thermostat", "thermostat", n, 2, false)
    sw_name = device("thermostat", n) <> ":0"

    create_temp_sensor("thermostat", sensor, n, tc: 24.0)
    create_temp_sensor("thermostat_follow", follow_sensor, n, tc: 25.0)

    %Thermostat{
      name: name_str(n),
      description: "test thermostat " <> num_str,
      switch: sw_name,
      sensor: sensor,
      owned_by: "none",
      enable: false,
      active_profile: nil,
      profiles: [
        %Profile{name: "follow", ref_sensor: follow_sensor},
        %Profile{name: "fixed_25", fixed_setpt: 25.0},
        %Profile{name: "fixed_26", fixed_setpt: 26.0, low_offset: -0.6, high_offset: 0.4}
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
  end

  test "can get active profile (when not set) by thermostat name" do
    active = Server.profiles(name_str(0), active: true)

    assert active == :none
  end

  test "can get full profiles by thermostat name" do
    profiles = Server.profiles(name_str(0))

    assert Enum.all?(profiles, fn x -> %Thermostat.Profile{} = x end)
  end

  test "can get enabled for a thermostat name" do
    enabled = Server.enabled?(name_str(0))

    refute enabled
  end

  test "can detect no ownership of thermostat" do
    owner = Server.owner(name_str(0))

    assert owner == :none
  end

  test "can ping a server by thermostat name" do
    res = Server.ping(name_str(0))

    assert res === :pong
  end

  test "can take ownership of a thermostat" do
    owner = "new owner"
    r1 = Server.take_ownership(name_str(1), owner)
    r2 = Server.owner(name_str(1))

    assert r1 == :ok
    assert r2 === owner
  end

  test "can release ownership of a thermostat" do
    owner = "new owner 2"
    r1 = Server.take_ownership(name_str(2), owner)
    r2 = Server.owner(name_str(2))
    r3 = Server.release_ownership(name_str(2))
    r4 = Server.owner(name_str(2))

    assert r1 == :ok
    assert r2 === owner
    assert r3 === :ok
    assert r4 == :none
  end

  test "thermostat server handles non-existent thermostat" do
    rc = Server.ping(name_str(999))

    assert rc == :not_found
  end

  test "can get the state of a new thermostat" do
    state = Server.state(name_str(0))

    assert state in ["new", "started"]
  end

  test "can get all known thermostats" do
    res = Server.all(:thermostats)
    all_maps = Enum.all?(res, fn x -> is_map(x) end)

    assert length(res) == 15
    assert all_maps
  end

  test "can get all known thermostat names" do
    res = Server.all(:names)

    all_bin = Enum.all?(res, fn x -> is_binary(x) end)

    assert length(res) == 15
    assert all_bin
  end

  test "can enable a thermostat" do
    res = Server.enable(name_str(3), set: true)
    enabled = Server.enabled?(name_str(3))

    assert res == :ok
    assert enabled
  end

  test "can disable a thermostat" do
    res1 = Server.enable(name_str(4), set: true)
    enabled = Server.enabled?(name_str(4))
    res2 = Server.enable(name_str(4), set: false)
    disabled = Server.enabled?(name_str(4))

    assert res1 == :ok
    assert res2 == :ok
    assert enabled
    assert disabled
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

  test "can set state directly on a %Thermostat{}" do
    new_state = "on"
    t = Thermostat.get_by(name: name_str(5))
    prev_state = Thermostat.state(t)

    {rc, t2} = Thermostat.state(t, new_state)

    assert rc == :ok
    refute prev_state === new_state
    assert t2.state === new_state
  end

  test "can activate profile directly on a %Thermostat{} and check profile exists" do
    t = Thermostat.get_by(name: name_str(6))

    {rc1, t2} = Thermostat.activate_profile(t, "fixed_26")
    active = Profile.active(t2)

    {rc2, _t3} = Thermostat.activate_profile(t, "bad")

    assert rc1 === :ok
    assert active.name === "fixed_26"
    assert is_list(t2.profiles)
    assert rc2 === :unknown_profile
  end

  test "can set a %Thermostat{} to standalone" do
    t = Thermostat.get_by(name: name_str(7))

    {rc1, t2} = Thermostat.standalone(t)
    rc2 = Thermostat.standalone?(t2)

    assert rc1 === :ok
    assert is_list(t2.profiles)
    assert rc2
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
end
