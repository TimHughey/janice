defmodule MixtankManagerTest do
  @moduledoc """

  """
  use ExUnit.Case, async: true
  # import ExUnit.CaptureLog
  use Timex

  import JanTest

  setup do
    :ok
  end

  setup_all do
    new_mixtank(99) |> Mixtank.add()
    # :timer.sleep(1000)

    # on_exit(fn ->
    #   mt = Mixtank.get_by(name: MixtankManagerTest.mt_name(99))
    #   Mixtank.delete(mt.id)
    # end)

    :ok
  end

  def base_ext(num),
    do: %{
      host: mt_host(num),
      name: mt_name(num),
      hw: "esp32",
      vsn: preferred_vsn(),
      mtime: Timex.now() |> Timex.to_unix(),
      log: false
    }

  def dc_name(n, sub), do: "#{mt_name(n)}_#{sub}"

  def new_dutycycle(n, sub_name) do
    dc_name = "#{mt_name(n)}_#{sub_name}"

    pio = Enum.find_index(subsystems(), fn x -> x === sub_name end)
    dev_str = switch_pio(n, sub_name, pio)

    %Dutycycle{
      name: dc_name,
      comment: "mt manager " <> mt_name(n),
      device: dev_str,
      profiles: [
        %Dutycycle.Profile{name: "high", run_ms: 120_000, idle_ms: 60_000},
        %Dutycycle.Profile{name: "low", run_ms: 20_000, idle_ms: 20_000},
        %Dutycycle.Profile{name: "off", run_ms: 0, idle_ms: 60_000},
        %Dutycycle.Profile{name: "on", run_ms: 60_000, idle_ms: 0}
      ],
      state: %Dutycycle.State{},
      standalone: false
    }
  end

  def new_mixtank(n) do
    # setup the switches we'll need
    for sub <- subsystems(), do: switch_ext_msg(n, sub)

    # setup the temperature sensors we'll need
    temp_ext_msg(n, "temp")
    temp_ext_msg(n, "ref")
    :timer.sleep(1000)

    # setup the necessary dutycycles
    for sub <- subsystems(), do: new_dutycycle(n, sub) |> Dutycycle.add()

    %Mixtank{
      name: mt_name(n),
      comment: "mt manager",
      enable: false,
      sensor: temp_sensor(n, "temp"),
      ref_sensor: temp_sensor(n, "ref"),
      pump: dc_name(n, "pump"),
      air: dc_name(n, "air"),
      heater: dc_name(n, "heater"),
      fill: dc_name(n, "fill"),
      replenish: dc_name(n, "replenish"),
      state: %Mixtank.State{},
      profiles: [
        MixtankTest.p_minimal(),
        MixtankTest.p_fill_overnight(),
        MixtankTest.p_fill_daytime(),
        MixtankTest.p_mix(),
        MixtankTest.p_change()
      ]
    }
  end

  def num(n), do: String.pad_leading(Integer.to_string(n), 3, "0")
  def pios(n, pos), do: for(i <- 0..(n - 1), do: %{pio: i, state: pos})
  def preferred_vsn, do: "b4edefc"

  def random_float do
    a = :rand.uniform(25)
    b = :rand.uniform(100)

    a + b * 0.1
  end

  def shared_mt, do: Mixtank.get_by(name: mt_name(99))
  def subsystems, do: ["pump", "air", "heater", "fill", "replenish"]
  def switch(n, type), do: "ds/mixtank" <> num(n) <> "_#{type}"

  def switch_ext(n, type, num_pios, pos) do
    base = base_ext(n)

    sw = %{
      type: "switch",
      device: switch(n, type),
      pio_count: num_pios,
      states: pios(8, pos)
    }

    Map.merge(base, sw)
  end

  def switch_ext_msg(n, type) do
    switch_ext(n, type, 8, false) |> Jason.encode!() |> Mqtt.InboundMessage.process()
    :timer.sleep(200)
  end

  def switch_pio(n, type, pio), do: switch(n, type) <> ":#{pio}"

  def temp_ext(n, type, val \\ 0.0) do
    base = base_ext(n)
    tc = if val > 0.0, do: val, else: random_float()
    tf = tc * (9.0 / 5.0) + 32.0

    sensor = %{
      type: "temp",
      device: temp_sensor(n, type),
      tc: tc,
      tf: tf
    }

    Map.merge(base, sensor)
  end

  def temp_ext_msg(n, type, val \\ 0.0) do
    temp_ext(n, type, val) |> Jason.encode!() |> Mqtt.InboundMessage.process()
    :timer.sleep(200)
  end

  def temp_sensor(n, type), do: "ds/#{mt_name(n)}_#{type}"

  test "can start task and await response" do
    num = 0
    opts = [:force, true]
    new_mixtank(num) |> Mixtank.add()
    mt = Mixtank.get_by(name: mt_name(num))

    task = Task.async(Mixtank.TempTask, :run, [mt, opts])
    rc = Task.await(task)

    active_profile = Dutycycle.active_profile_name(name: dc_name(num, "heater"))
    # profile_good = active_profile in ["on", "off"]

    assert %Task{} = task
    assert rc == {:ok}
    refute active_profile === "none"
  end

  test "temp convert turns heater on and off" do
    num = 1
    opts = [force: true]
    new_mixtank(num) |> Mixtank.add()
    mt = Mixtank.get_by(name: mt_name(num))

    # set the ref temperature high and the tank temp low
    temp_ext_msg(num, "ref", 100.0)
    temp_ext_msg(num, "temp", 0)

    # let the messages process
    # #:timer.sleep(500)

    task = Task.async(Mixtank.TempTask, :run, [mt, opts])
    rc = Task.await(task)

    # # :timer.sleep(500)

    active_profile = Dutycycle.active_profile_name(name: dc_name(num, "heater"))
    profile_good = active_profile === "on"

    assert %Task{} = task
    assert rc == {:ok} or is_nil(rc)
    assert profile_good
  end

  test "temp convert turns off heater" do
    num = 2
    opts = [force: true]
    new_mixtank(num) |> Mixtank.add()
    mt = Mixtank.get_by(name: mt_name(num))

    # set the ref temperature high and the tank temp low
    temp_ext_msg(num, "ref", 0.0)
    temp_ext_msg(num, "temp", 100.0)

    # let the messages process
    # # :timer.sleep(500)

    task = Task.async(Mixtank.TempTask, :run, [mt, opts])
    rc = Task.await(task)

    # # :timer.sleep(500)

    active_profile = Dutycycle.active_profile_name(name: dc_name(num, "heater"))

    assert %Task{} = task
    assert rc == {:ok} or is_nil(rc)
    assert active_profile === "off"
  end
end
