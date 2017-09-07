defmodule OwfsTest do
  @moduledoc :false

  alias Mcp.Owfs
  use ExUnit.Case, async: true

  @test_temperature "ts_basement"
  @test_humidity "hs_mock1"
  @test_switch {"systronix_buzzer", "PIO.A"}

  def has_temperature?(t), do: String.contains?(t.kind, "temperature")
  def has_humidity?(t), do: String.contains?(t.kind, "humidity")

  test "is owfs available?" do
    assert Owfs.available?()
  end

  test "can owfs return the volatile timeout?" do
    assert Owfs.volatile_timeout_ms() > 0
  end

  test "can owfs return a list of sensors?" do
    list =  Owfs.sensors()
    assert Enum.count(list) > 1
  end

  test "can owfs read a sensor with only a temperature?" do
    list = Owfs.read_sensor(@test_temperature)

    temperature = Enum.any?(list, &has_temperature?(&1))
    reading = hd(list)
    val = reading.val

    assert 1 == Enum.count(list) and val > 0.0 and temperature
  end

  test "can owfs read a sensor with humidity and temperature?" do
    list = Owfs.read_sensor(@test_humidity)
    temperature = Enum.any?(list, &has_temperature?(&1))
    humidity = Enum.any?(list, &has_humidity?(&1))

    assert temperature and humidity
  end

  test "can owfs get a switch state?" do
    {sw, pio} = @test_switch
    {res, position} = Owfs.get_switch_position(sw, pio)

    assert :ok == res and is_boolean(position)
  end

  test "can owfs set a switch state?" do
    {sw, pio} = @test_switch
    res = Owfs.switch_set(sw, pio, :true)

    assert :ok == res
  end

  test "hammer test of available" do
    results =
      for _i <- 1..10  do
        Owfs.available?()
      end

    assert Enum.all?(results) and Owfs.available?()
  end

  test "hammer test of switch set" do
    results =
      for _i <- 1..100 do
        {sw, pio} = @test_switch
        Owfs.switch_set(sw, pio, :true)
      end

    assert Enum.all?(results) and Owfs.available?()
  end

  test "are temperature cycles occurring?" do
    cycles =
      for _i <- 1..300 do
        :timer.sleep(10)

        # set a switch while watching to help create a switch cmd queue
        {sw, pio} = @test_switch
        Owfs.switch_set(sw, pio, :true)

        case Owfs.temp_cycle_done?() do
          {:true, _serial}  -> :true
          {_rest, _serial}  -> :false
        end
      end

    avail = Enum.count(cycles, fn(x) -> x == :true end)
    not_avail = Enum.count(cycles, fn(x) -> x == :false end)

    assert avail != not_avail
  end

  test "does the temperature cycle serial change as time passes?" do
    first  = Owfs.temp_cycle_serial_num()
    :timer.sleep(10_000)
    second = Owfs.temp_cycle_serial_num()
    assert first < second
  end

  test "can a latch be read without clearing?" do
    {res, position} = Owfs.get_latch("systronix_buzzer")

    assert res == :ok and is_boolean(position)
  end

  test "can a latch be read and cleared?" do
    {res, position} = Owfs.get_latch("systronix_buzzer", :true)

    assert res == :ok and is_boolean(position)
  end
end
