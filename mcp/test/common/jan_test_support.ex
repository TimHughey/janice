defmodule JanTest do
  @moduledoc false

  alias Janice.TimeSupport

  import Ecto.Query, only: [from: 2]

  defmacro __using__(_opts) do
    quote do
      # switch command ack (from mcr remote) include the key cmdack
      def ack_msg(%{
            device: device,
            host: host,
            name: rem_name,
            refid: refid,
            states: states,
            type: msg_type
          }) do
        %{
          processed: false,
          cmdack: true,
          dev_latency_us: :rand.uniform(5000) + 10_000,
          device: device,
          host: host,
          mtime: TimeSupport.unix_now(:second),
          latency_us: :rand.uniform(20_000) + 10_000,
          name: rem_name,
          pio_count: length(states),
          read_us: :rand.uniform(3000) + 10_000,
          refid: refid,
          states: [%{pio: 0, state: false}, %{pio: 1, state: true}],
          type: msg_type,
          write_us: :rand.uniform(1000) + 10_000,
          msg_recv_dt: TimeSupport.utc_now(),
          log: false
        }
      end

      def base_context(context) do
        alias Switch.{Alias, Device}

        base =
          unquote(__CALLER__.module) |> Atom.to_string() |> String.downcase()

        num = Map.get(context, :alias_num, 0)
        num_sw_states = Map.get(context, :num_sw_states, 3)
        alias_prefix = Map.get(context, :alias_prefix, "base")
        num_str = ["0x", Integer.to_string(num, 16)] |> IO.iodata_to_binary()
        alias_name = [alias_prefix, num_str] |> IO.iodata_to_binary()
        add_alias = Map.get(context, :add_alias, false)
        alias_pio = Map.get(context, :alias_pio, 1)

        host = Map.get(context, :host, random_mcr())

        rem_name =
          Map.get(
            context,
            :name,
            ["rem_swalias", num_str] |> IO.iodata_to_binary()
          )

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
            pio: alias_pio
          })

        {pos_rc, initial_pos} = Device.pio_state(sd, alias_pio)

        assert pos_rc in [:ok, :ttl_expired]

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
         initial_pos: initial_pos,
         sa: sa_res}
      end

      defp add_alias(%{
             add_alias: true,
             name: name,
             pio: pio,
             sd: {:ok, %Switch.Device{id: device_id}}
           }) do
        {rc, sa} =
          sa_rc =
          Switch.Alias.upsert(%{device_id: device_id, name: name, pio: pio})

        assert rc == :ok
        assert %Switch.Alias{} = sa

        sa_rc
      end

      defp add_alias(%{add_alias: _}) do
        {:not_added, %Switch.Alias{}}
      end

      # command msgs to remotes (mcr) do NOT include key cmdack
      # rather they include:
      #   1. cmd:   "set.switch"
      #   2. ack:   boolean (true = respond with cmdack: true)
      #   3. refid: the UUID of this command
      #
      # NOTE: although not required as of 2020-03-22, the this test does
      #       include host: <mcr id> and name: <mcr name> for future enhancements
      def cmd_msg(%{
            device: switch,
            host: host,
            name: rem_name,
            refid: refid,
            states: states
          }) do
        import TimeSupport, only: [unix_now: 1]

        %{
          cmd: "set.switch",
          mtime: unix_now(:second),
          switch: switch,
          states: states,
          refid: refid,
          ack: true,
          host: host,
          name: rem_name
        }
      end

      def dev_num_str(n, opts \\ [iodata: false]) when is_integer(n) do
        str_list = [
          "0x",
          Integer.to_string(n, 16) |> String.pad_leading(3, "0")
        ]

        if Keyword.get(opts, :iodata, false),
          do: IO.iodata_to_binary(str_list),
          else: str_list
      end

      def make_sw_alias_name(prefix, num \\ 0)
          when is_binary(prefix) and is_integer(num) and num >= 0 do
        [prefix, "_", dev_num_str(num, iodata: true)] |> IO.iodata_to_binary()
      end

      def make_sw_alias_names(prefix, count \\ 1)
          when is_binary(prefix) and is_integer(count) and count >= 1 do
        names =
          for x <- 0..count do
            make_sw_alias_name(prefix, x)
          end

        if length(names) == 1, do: hd(names), else: names
      end

      def need_switches(list, opts \\ [])
          when is_list(list) and is_list(opts) do
        unique_num = Keyword.get(opts, :unique_num, 1)
        num_str = Integer.to_string(unique_num, 16) |> String.downcase()
        test_grp = Keyword.get(opts, :test_group, "base")
        sw_prefix = Keyword.get(opts, :sw_prefix, "base_sw")
        rem_name = Keyword.get(opts, :rem_name, "rem_base")
        pio_count = Enum.count(list)

        device = [sw_prefix, "0x", num_str] |> IO.iodata_to_binary()

        msg =
          remote_msg(rem_name: rem_name, device: device, pio_count: pio_count)

        {sd_rc, sd} = Switch.Device.upsert(msg) |> Map.get(:processed)

        assert sd_rc == :ok

        for x <- 1..pio_count do
          pio = x - 1
          name = Enum.at(list, pio, "beyond")

          {rc, sa} =
            Switch.Device.dev_alias(device, create: true, name: name, pio: pio)

          assert rc == :ok
          Map.get(sa, :name)
        end
      end

      defp random_mac() do
        # mcr.30 ae a4 f2 c2 10
        bytes = for b <- 1..6, do: :rand.uniform(249) + 5

        for b <- bytes, do: Integer.to_string(b, 16) |> String.downcase()
      end

      defp random_mcr(), do: ["mcr.", random_mac()] |> IO.iodata_to_binary()

      defp remote_msg(opts) when is_list(opts) do
        rem_name = Keyword.get(opts, :rem_name, "remote_base")
        device = Keyword.get(opts, :device, "base_dev")
        pio_count = Keyword.get(opts, :pio_count, 1)

        %{
          processed: false,
          type: "switch",
          host: random_mcr(),
          name: rem_name,
          hw: "esp32",
          device: device,
          pio_count: pio_count,
          states:
            for s <- 1..pio_count do
              %{pio: s - 1, state: false}
            end,
          vsn: "xxxxx",
          ttl_ms: 30_000,
          dev_latency_us: 1000,
          mtime: TimeSupport.unix_now(:second),
          log: false
        }
      end

      def simulate_cmd_ack(
            %{device: _device, host: _host, rem_name: name} = r,
            %{
              refid: refid,
              pio: pio,
              position: position
            }
          ) do
        alias Switch.Device

        # simulate the ack from the mcr device:
        #  1. grab required keys from the reading in the context
        #  2. add remaining required keys
        #  3. create the ack_msg
        #  4. send to Device.upsert/1 for processing
        base_map = Map.take(r, [:device, :host]) |> Map.put(:name, name)

        msg =
          Map.merge(base_map, %{
            refid: refid,
            states: [%{pio: pio, state: position}],
            type: "switch"
          })
          |> ack_msg()

        %{processed: {rc, res}} = Device.upsert(msg)

        assert rc == :ok
        {rc, res}
      end
    end
  end

  def delete_all(mods) when is_list(mods) do
    for mod <- mods do
      from(x in mod, where: x.id > 0) |> Repo.delete_all()
    end
  end

  def base_ext(name, num),
    do: %{
      host: host(name, num),
      name: name(name, num),
      hw: "esp32",
      vsn: preferred_vsn(),
      mtime: TimeSupport.unix_now(:second),
      msg_recv_dt: TimeSupport.utc_now(),
      log: false
    }

  def device(name, n), do: "ds/#{name}#{num_str(n)}"
  def host(name, n), do: "mcr.#{name}#{num_str(n)}"

  def mt_host(n), do: host("mixtank", n)
  def mt_name(n), do: name("mixtank", n)

  def name(prefix, n), do: [prefix, num_str(n)] |> IO.iodata_to_binary()
  def num_str(n), do: String.pad_leading(Integer.to_string(n), 3, "0")
  def preferred_vsn, do: "b4edefc"

  def random_float do
    a = :rand.uniform(25)
    b = :rand.uniform(100)

    a + b * 0.1
  end

  ####
  #### SENSORS
  ####

  def relhum_ext(num) do
    base = base_ext("sensor", num)

    sensor = %{
      type: "relhum",
      device: device("relhum", num),
      rh: random_float(),
      tc: random_float(),
      tf: random_float()
    }

    Map.merge(base, sensor)
  end

  def relhum_dev(n), do: device("relhum", n + 50)

  def relhum_ext_msg(n) do
    # all relative humidity senors start at 50 for test purposes
    # also avoids conflicts with temperature sensors
    n = n + 50

    relhum_ext(n)
    |> Msgpax.pack!(iodata: false)
    |> send()
  end

  def relhum_name(n), do: name("relhum", n + 50)

  defp send(msg) do
    %{payload: msg, topic: "test/mcr/f/report", direction: :in}
    |> Mqtt.Inbound.process(async: false)
  end

  def sen_dev(n), do: device("sensor", n)
  def sen_host(n), do: host("sensor", n)
  def sen_name(n), do: name("sensor", n)

  def soil_ext(num, opts \\ []) do
    tc = Keyword.get(opts, :tc, random_float())
    cap = Keyword.get(opts, :cap, :rand.uniform(600))
    base = base_ext("sensor", num)

    sensor = %{
      type: "soil",
      device: device("sensor", num),
      tc: tc,
      tf: tc,
      cap: cap
    }

    Map.merge(base, sensor)
  end

  def soil_ext_msg(n, opts \\ []) do
    soil_ext(n, opts)
    |> Msgpax.pack!(iodata: false)
    |> send()
  end

  def temp_ext(num, opts \\ []) do
    tc = Keyword.get(opts, :tc, random_float())
    base = base_ext("sensor", num)

    sensor = %{
      type: "temp",
      device: device("sensor", num),
      tc: tc,
      tf: tc
    }

    Map.merge(base, sensor)
  end

  def temp_ext_msg(n, opts \\ []) do
    temp_ext(n, opts)
    |> Msgpax.pack!(iodata: false)
    |> send()
  end

  def create_temp_sensor(sub, name, num, opts \\ []) do
    tc = opts[:tc] || random_float()
    base = base_ext(sub, num)

    sensor = %{type: "temp", device: name, tc: tc}

    Map.merge(base, sensor)
    |> Msgpax.pack!(iodata: false)
    |> send()
  end

  ####
  #### SWITCHES
  ####

  def create_switch(num, num_pios, pos) when is_integer(num) do
    switch_ext("switch", num, num_pios, pos) |> Switch.Device.upsert()
  end

  def create_switch(sub, name, num, num_pios, pos) when is_binary(name) do
    %{
      processed: false,
      host: sub,
      name: name,
      hw: "esp32",
      device: device(sub, num),
      pio_count: num_pios,
      states: pios(num_pios, pos),
      vsn: preferred_vsn(),
      mtime: TimeSupport.unix_now(:second),
      log: false
    }
    |> Switch.Device.upsert()
  end

  def sw_state_name(name, num, pio), do: device(name, num) <> ":#{pio}"

  def device_pio(num, pio), do: device("switch", num) <> ":#{pio}"
  def pios(num, pos), do: for(n <- 0..(num - 1), do: %{pio: n, state: pos})

  def switch_ext(name, num, num_pios, pos),
    do: %{
      processed: false,
      host: host(name, num),
      name: name("switch", num),
      hw: "esp32",
      device: device(name, num),
      pio_count: num_pios,
      states: pios(num_pios, pos),
      vsn: preferred_vsn(),
      mtime: TimeSupport.unix_now(:second),
      log: false,
      dev_latency_us: :rand.uniform(1024) + 3000
    }
end
