defmodule MixtankTest do
  @moduledoc """

  """
  use ExUnit.Case, async: false
  # import ExUnit.CaptureLog
  use Timex

  alias Mixtank.Profile
  alias Mixtank.State

  setup do
    :ok
  end

  setup_all do
    _mt = new_mixtank(99) |> Mixtank.add()
    :ok
  end

  def dev_name(n, type) do
    name = "test mt " <> String.pad_leading(Integer.to_string(n), 3, "0") <> " #{type}"

    String.replace(name, " ", "_")
  end

  def fixed_name, do: name_str(99)

  def get_an_id, do: Mixtank.get_by(name: fixed_name()) |> Map.get(:id)

  def name_str(n), do: "test mt " <> String.pad_leading(Integer.to_string(n), 3, "0")

  def shared_mt, do: Mixtank.get_by(name: fixed_name())

  def new_mixtank(n) do
    num_str = String.pad_leading(Integer.to_string(n), 3, "0")
    name_str = "test mt " <> num_str

    %Mixtank{
      name: name_str,
      comment: "test mt",
      enable: false,
      sensor: dev_name(n, "temp"),
      ref_sensor: dev_name(n, "temp ref"),
      pump: dev_name(n, "pump"),
      air: dev_name(n, "air"),
      heater: dev_name(n, "heater"),
      fill: dev_name(n, "rodi fill"),
      replenish: dev_name(n, "rodi replenish"),
      state: %State{},
      profiles: [
        p_minimal(),
        p_fill_overnight(),
        p_fill_daytime(),
        p_mix(),
        p_change()
      ]
    }
  end

  def p_minimal,
    do: %Profile{
      name: "minimal",
      active: false,
      pump: "high",
      air: "high",
      fill: "off",
      replenish: "fast",
      temp_diff: 0
    }

  def p_fill_overnight,
    do: %Profile{
      name: "fill overnight",
      active: false,
      pump: "high",
      air: "off",
      fill: "fast",
      replenish: "fast",
      temp_diff: 0
    }

  def p_fill_daytime,
    do: %Profile{
      name: "fill daytime",
      active: false,
      pump: "high",
      air: "off",
      fill: "slow",
      replenish: "fast",
      temp_diff: 0
    }

  def p_mix,
    do: %Profile{
      name: "mix",
      active: false,
      pump: "high",
      air: "high",
      fill: "off",
      replenish: "fast",
      temp_diff: 0
    }

  def p_change,
    do: %Profile{
      name: "change",
      active: false,
      pump: "high",
      air: "off",
      fill: "off",
      replenish: "off",
      temp_diff: 2
    }

  test "the truth will set you free" do
    assert true === true
  end

  test "%Mixtank is defined and a schema" do
    mt = %Mixtank{}

    assert is_map(mt)
    assert Mixtank.__schema__(:source) == "mixtank"
  end

  test "all mixtanks" do
    all_mt = Mixtank.all()

    refute Enum.empty?(all_mt)
  end

  test "get a mixtank by id" do
    id = get_an_id()

    mt = Mixtank.get_by(id: id)

    assert mt.id === id
  end

  test "active profile name is 'none' when mixtank disabled" do
    mt = new_mixtank(1) |> Mixtank.add()

    profile = Mixtank.active_profile_name(mt.id)

    assert profile === "none"
  end

  test "disable a mixtank by id" do
    mt = new_mixtank(2) |> Mixtank.add()
    rc = Mixtank.disable(id: mt.id)

    assert rc === :ok
  end

  test "Mixtank.disable() handles an non-existant id" do
    rc = Mixtank.disable(id: 1_000_000)

    assert rc === :error
  end

  test "enable a mixtank by id" do
    mt = new_mixtank(3) |> Mixtank.add()
    rc = Mixtank.enable(id: mt.id)

    assert rc === :ok
  end

  test "disabled mixtank returns 'none' as active profile" do
    mt = new_mixtank(4) |> Mixtank.add()

    Mixtank.disable(id: mt.id)
    profile = Mixtank.active_profile_name(mt.id)

    assert profile === "none"
  end
end
