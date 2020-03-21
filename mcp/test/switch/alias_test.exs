defmodule SwitchAliasTest do
  @moduledoc false

  use ExUnit.Case, async: true

  # import ExUnit.CaptureLog

  alias Janice.TimeSupport
  alias Switch.Alias
  alias Switch.Device

  setup do
    :ok
  end

  setup context do
    num = Map.get(context, :alias_num, 0)
    num_sw_states = Map.get(context, :num_sw_states, 3)
    num_str = ["0x", Integer.to_string(num, 16)] |> IO.iodata_to_binary()
    alias_name = ["swalias_", num_str] |> IO.iodata_to_binary()
    add_alias = Map.get(context, :add_alias, false)
    alias_pio = Map.get(context, :alias_pio, 1)

    host =
      Map.get(
        context,
        :host,
        ["mcr.switch_alias", num_str] |> IO.iodata_to_binary()
      )

    rem_name =
      Map.get(context, :name, ["rem_swalias", num_str] |> IO.iodata_to_binary())

    device =
      Map.get(
        context,
        :device,
        ["ds/swalias", num_str] |> IO.iodata_to_binary()
      )

    states =
      for s <- 0..num_sw_states do
        state = :rand.uniform(2) - 1
        %{pio: s, state: if(state == 0, do: false, else: true)}
      end

    r = %{
      processed: false,
      type: "switch",
      host: host,
      name: rem_name,
      hw: "esp32",
      device: device,
      pio_count: 3,
      states: states,
      vsn: "xxxxx",
      ttl_ms: 30_000,
      dev_latency_us: 1000,
      mtime: TimeSupport.unix_now(:second),
      log: false
    }

    {sd_rc, sd} =
      sd_res =
      if Map.get(context, :insert, true),
        do: Device.upsert(r) |> Map.get(:processed),
        else: nil

    assert sd_rc == :ok
    assert %Device{} = sd

    sa_res =
      add_alias(%{
        add_alias: add_alias,
        sd: {sd_rc, sd},
        name: alias_name,
        pio: 1
      })

    # pio = context[:pio]
    # device_pio = if pio, do: device_pio(n, pio), else: device_pio(n, 0)

    {:ok,
     r: r,
     host: host,
     rem_name: rem_name,
     device: device,
     device_id: Map.get(sd, :id),
     sd: sd_res,
     alias_name: alias_name,
     add_alias: add_alias,
     alias_pio: alias_pio,
     sa: sa_res}
  end

  defp add_alias(%{
         add_alias: true,
         name: name,
         pio: pio,
         sd: {:ok, %Device{id: device_id}}
       }) do
    {rc, sa} =
      sa_rc = Alias.upsert(%{device_id: device_id, name: name, pio: pio})

    assert rc == :ok
    assert %Alias{} = sa

    sa_rc
  end

  defp add_alias(%{add_alias: _, device: _device, sd: _sd}) do
    {:not_added, %Alias{}}
  end

  @moduletag :switch_alias
  setup_all do
    # new_sws = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 99]
    #
    # for s <- new_sws do
    #   create_switch(s, 8, false)
    # end

    :ok
  end

  @tag alias_num: 1
  @tag add_alias: true
  test "can add a new alias", %{
    sa: {sa_rc, sa}
  } do
    assert sa_rc == :ok
    assert %Alias{} = sa
  end
end
