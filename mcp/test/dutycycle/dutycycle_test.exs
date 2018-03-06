defmodule DutycycleTest do
  @moduledoc """

  """

  use ExUnit.Case, async: false
  # import ExUnit.CaptureLog
  use Timex

  setup do
    :ok
  end

  @moduletag :dutycycle
  setup_all do
    new_dcs = [0, 1, 2, 3, 99]
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

  test "all dutycycles" do
    all_dc = Dutycycle.all()

    refute Enum.empty?(all_dc)
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

  test "activate a profile" do
    dc = Dutycycle.get_by(name: name_str(0))

    {count, _} = Dutycycle.activate_profile(dc.name, "off")

    assert count === 1
  end

  test "get available profile names" do
    dc = Dutycycle.get_by(name: name_str(1))

    profiles = Dutycycle.available_profiles(dc.name)

    assert Enum.count(profiles) === 3
  end

  test "get dutycycle with only active profile" do
    profile = "off"
    dc = Dutycycle.get_by(name: name_str(2))

    {count, _} = Dutycycle.activate_profile(dc.name, profile)

    active_dc = Dutycycle.active_profile(dc.name)
    active_name = active_dc.profiles |> hd() |> Map.get(:name)

    assert count === 1
    assert active_name === profile
  end

  test "get dutycycle active profile name" do
    dc = shared_dc()

    active = Dutycycle.active_profile_name(id: dc.id)

    assert is_binary(active)
  end
end
