defmodule Web.McpController do
  @moduledoc """
  """
  use Timex
  use Web, :controller

  alias Mcp.DevAlias
  alias Mcp.Sensor
  alias Mcp.Switch

  def index(conn, _params) do
    all_fnames = DevAlias.all(:friendly_names) |> MapSet.new()
    switch_fnames = Switch.all(:friendly_names)
    sensor_fnames = Sensor.all(:friendly_names)

    known_fnames = (switch_fnames ++ sensor_fnames) |> MapSet.new()
    unknown_fnames =
      MapSet.difference(all_fnames, known_fnames) |> Enum.sort()

    # unknown = Enum.map(unknown_fnames, fn(x) -> dev_alias_details(x) end)
    sensors = Enum.map(sensor_fnames, fn(x) -> sensor_details(x) end)
    switches = Enum.map(switch_fnames, fn(x) -> switch_details(x) end)

    render conn, "index.html",
      all_fnames_count: Enum.count(all_fnames),
      switch_fnames: switch_fnames,
      switch_fnames_count: Enum.count(switch_fnames),
      sensor_fnames: sensor_fnames,
      sensor_fnames_count: Enum.count(sensor_fnames),
      unknown_fnames: unknown_fnames,
      unknown_fnames_count: Enum.count(unknown_fnames),
      sensors: sensors,
      switches: switches
  end

  def show(conn, %{"type" => "nodevice"}) do

    all_fnames = DevAlias.all(:friendly_names) |> MapSet.new()
    switch_fnames = Switch.all(:friendly_names)
    sensor_fnames = Sensor.all(:friendly_names)

    known_fnames = (switch_fnames ++ sensor_fnames) |> MapSet.new()
    unknown_fnames =
      MapSet.difference(all_fnames, known_fnames) |> Enum.sort()

    unknown = Enum.map(unknown_fnames, fn(x) -> dev_alias_details(x) end)

    #render conn, "unknown.json", unknown: unknown

    table = ~s(<table class="table device-table" id="noDeviceTable"></table>) <>
            ~s(<bold><th>Alias</th><th>Device</th><th>Description</th>
               <th>Last Seen</th><th>Last Seen At</th></bold>) <>
               Enum.join(unknown, " ")

    text conn, table
  end

  def show(conn, %{"type" => "sensors"}) do
    sensor_fnames = Sensor.all(:friendly_names)

    sensors = Enum.map(sensor_fnames, fn(x) -> sensor_details(x) end)

    table = ~s(<table class="table device-table" id="sensorsTable">
      <bold>
        <th>Alias</th>
        <th>Device</th>
        <th>Type</th>
        <th>Description</th>
        <th>Last Seen</th>
        <th>Reading At</th>
      </bold>) <> Enum.join(sensors, " ")

      text conn, table
  end

  def show(conn, %{"type" => "switches"}) do
    switch_fnames = Switch.all(:friendly_names)

    switches = Enum.map(switch_fnames, fn(x) -> switch_details(x) end)

    table = ~s(<table class="table device-table" id="switchesTable">
      <bold>
      <th>Alias</th>
      <th>Device</th>
      <th>Enabled</th>
      <th>Description</th>
      <th>Dev Latency</th>
      <th>Last Cmd</th>
      <th>Last Seen</th>
      <th>State</th></bold>) <> Enum.join(switches, " ")

    text conn, table
  end

  defp dev_alias_details(fname) do
    a = DevAlias.get_by_friendly_name(fname)
    tz = Timezone.local
    last_seen_secs = humanize_secs(a.last_seen_at)
    last_seen_at = Timezone.convert(a.last_seen_at, tz) |>
                    Timex.format!("{UNIX}")

    ~s(<tr><td>#{a.friendly_name}</td>) <>
    ~s(<td>#{a.device}</td>) <>
    ~s(<td>#{a.description}</td>) <>
    ~s(<td>#{last_seen_secs}</td>) <>
    ~s(<td>#{last_seen_at}<td></tr>)
  end

  defp sensor_details(fname) do
    a = DevAlias.get_by_friendly_name(fname)
    s = Sensor.get(:friendly_name, fname)

    last_seen_secs = Timex.diff(Timex.now(), s.last_seen_at, :seconds)
    tz = Timezone.local
    reading_at = Timezone.convert(s.reading_at, tz) |>
                    Timex.format!("{UNIX}")

    ~s(<tr><td>#{a.friendly_name}</td>) <>
    ~s(<td>#{s.device}</td>) <>
    ~s(<td>#{s.sensor_type}</td>) <>
    ~s(<td>#{a.description}</td>) <>
    ~s(<td>#{humanize_secs(last_seen_secs)}</td>) <>
    ~s(<td>#{reading_at}<td></tr>)
  end

  defp switch_details(fname) do
    a = DevAlias.get_by_friendly_name(fname)
    s = Switch.get(:friendly_name, fname)

    switch_map_details(a, s)
  end

  defp switch_map_details(%DevAlias{} = a, %Switch{} = s) do
    state = Switch.get_state(a.friendly_name)

    ~s(<tr><td>#{a.friendly_name}</td>) <>
    ~s(<td>#{a.device}</td>) <>
    ~s(<td>#{s.enabled}</td>) <>
    ~s(<td>#{a.description}</td>) <>
    ~s(<td>#{humanize_microsecs(s.dev_latency)}</td>) <>
    ~s(<td>#{humanize_secs(s.last_cmd_at)}</td>) <>
    ~s(<td>#{humanize_secs(a.last_seen_at)}</td>) <>
    ~s(<td>#{state}</td></tr>)
  end

  defp switch_map_details(%DevAlias{} = a, _any) do
    %{device: a.device, fname: a.friendly_name, desc: a.description,
      enabled: "?", dev_latency: "?",
      discovered_at: "?",
      last_cmd_secs: "?",
      last_seen_secs: "?",
      last_seen_at: "?",
      state: "?"}
  end

  defp humanize_microsecs(us)
  when is_number(us) and us > 1000 do
    "#{Float.round(us / 1000.0, 2)} ms"
  end

  defp humanize_microsecs(us)
  when is_number(us) do
    "#{us} us"
  end

  defp humanize_microsecs(_), do: "-"

  defp humanize_secs(%DateTime{} = dt) do
    Timex.diff(Timex.now(), dt, :seconds) |> humanize_secs
  end

  # one (1) week: 604_800
  # one (1) day : 86,400
  # one (1) hour: 3_600

  defp humanize_secs(secs)
  when secs >= 604_800 do
    ">1 week"
  end

  defp humanize_secs(secs)
  when secs >= 86_400 do
    ">1 day"
  end

  defp humanize_secs(secs)
  when secs >= 3_600 do
    ">1 hr"
  end

  defp humanize_secs(secs)
  when secs >= 60 do
    ">1 min"
  end

  defp humanize_secs(secs) do
    "#{secs} secs"
  end

end
