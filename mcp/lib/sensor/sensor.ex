defmodule Sensor do
  @moduledoc """
    The Sensor module provides the base of a sensor reading.
  """

  require Logger
  use Timex
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  import Repo, only: [all: 2, insert!: 1, update: 1, update!: 1, one: 1]

  import Janice.Common.DB, only: [name_regex: 0]
  alias Janice.TimeSupport

  # alias Fact.Celsius
  alias Fact.Fahrenheit
  alias Fact.RelativeHumidity
  alias Fact.SoilMoisture

  schema "sensor" do
    field(:name, :string)
    field(:description, :string)
    field(:device, :string)
    field(:type, :string)
    field(:dev_latency, :integer)
    field(:reading_at, :utc_datetime_usec)
    field(:last_seen_at, :utc_datetime_usec)
    has_many(:temperature, SensorTemperature)
    has_many(:relhum, SensorRelHum)
    has_many(:soil, SensorSoil)

    timestamps()
  end

  # 15 minutes (as millesconds)
  @delete_timeout_ms 15 * 60 * 1000

  def add([]), do: []

  def add([%Sensor{} = s | rest]) do
    [add(s)] ++ add(rest)
  end

  def add(%Sensor{device: device}, r \\ %{}) when is_map(r) do
    found = get_by(device: device)
    r = Map.put(r, :found, found)

    case r do
      %{found: %Sensor{} = exists} ->
        exists

      %{found: nil, rh: rh, tc: tc, tf: tf, type: type} ->
        relhum = %SensorRelHum{rh: rh}
        temp = %SensorTemperature{tc: tc, tf: tf}

        %Sensor{
          device: device,
          name: device,
          type: type,
          temperature: [temp],
          relhum: [relhum]
        }
        |> insert!()

      %{found: nil, cap: cap, tc: tc, tf: tf, type: type} ->
        soil = %SensorSoil{moisture: cap}
        temp = %SensorTemperature{tc: tc, tf: tf}

        %Sensor{
          device: device,
          name: device,
          type: type,
          temperature: [temp],
          soil: [soil]
        }
        |> insert!()

      %{found: nil, tc: tc, tf: tf, type: type} ->
        temp = %SensorTemperature{tc: tc, tf: tf}

        %Sensor{device: device, name: device, type: type, temperature: [temp]}
        |> insert!()

      %{found: nil} ->
        type = Map.get(r, :type, nil)

        Logger.warn(fn ->
          "#{device} unknown type #{type}, defaulting to unknown"
        end)

        %Sensor{device: device, name: device, type: "unknown"} |> insert!()
    end
  end

  def all(:devices) do
    from(s in Sensor, order_by: [asc: s.device], select: s.device)
    |> all(timeout: 100)
  end

  def all(:names) do
    from(s in Sensor, order_by: [asc: s.name], select: s.name)
    |> all(timeout: 100)
  end

  def all(:everything) do
    from(
      s in Sensor,
      order_by: [asc: s.name]
    )
    |> all(timeout: 100)
  end

  def browse do
    sorted = all(:everything) |> Enum.sort(fn a, b -> a.name <= b.name end)

    Scribe.console(sorted,
      data: [
        {"ID", :id},
        {"Name", :name},
        {"Device", :device},
        {"Last Seen", fn x -> Timex.format!(x.last_seen_at, "{RFC3339z}") end}
      ]
    )
  end

  def celsius(name) when is_binary(name), do: celsius(name: name)

  def celsius(opts) when is_list(opts) do
    temperature(opts) |> normalize_readings() |> Map.get(:tc, nil)
  end

  def celsius(nil), do: nil

  def change_description(id, comment)
      when is_integer(id) and is_binary(comment) do
    s = get_by(id: id)

    if is_nil(s) do
      Logger.warn(fn -> "change description failed" end)
      {:error, :not_found}
    else
      s
      |> changeset(%{description: comment})
      |> update()
    end
  end

  def change_name(id, to_be, comment \\ "")

  def change_name(id, tobe, comment)
      when is_integer(id) and is_binary(tobe) and is_binary(comment) do
    s = get_by(id: id)

    if is_nil(s) do
      Logger.warn(fn -> "change name failed" end)
      {:error, :not_found}
    else
      s
      |> changeset(%{name: tobe, description: comment})
      |> update()
    end
  end

  def change_name(asis, tobe, comment)
      when is_binary(asis) and is_binary(tobe) do
    s = get_by(name: asis)

    if is_nil(s),
      do: {:error, :not_found},
      else: changeset(s, %{name: tobe, description: comment}) |> update()
  end

  def changeset(ss, params \\ %{}) do
    ss
    |> cast(params, [:name, :description])
    |> validate_required([:name])
    |> validate_format(:name, name_regex())
    |> unique_constraint(:name)
  end

  def delete(id) when is_integer(id) do
    from(s in Sensor, where: s.id == ^id)
    |> Repo.delete_all(timeout: @delete_timeout_ms)
  end

  def delete(name) when is_binary(name) do
    from(s in Sensor, where: s.name == ^name)
    |> Repo.delete_all(timeout: @delete_timeout_ms)
  end

  def delete_all(:dangerous) do
    from(s in Sensor, where: s.id >= 0)
    |> Repo.delete_all(timeout: @delete_timeout_ms)
  end

  def deprecate(id) when is_integer(id) do
    s = get_by(id: id)

    if is_nil(s) do
      Logger.warn(fn -> "deprecate(#{id}) failed" end)
      {:error, :not_found}
    else
      tobe = "~ #{s.name}-#{Timex.now() |> Timex.format!("{ASN1:UTCtime}")}"
      comment = "deprecated"

      s
      |> changeset(%{name: tobe, description: comment})
      |> update()
    end
  end

  def deprecate(:help), do: deprecate()

  def deprecate do
    IO.puts("Usage:")
    IO.puts("\tSensor.deprecate(id)")
  end

  def external_update(
        %{device: device, host: host, mtime: mtime, type: type} = r
      ) do
    hostname = Remote.mark_as_seen(host, mtime)
    r = normalize_readings(r) |> Map.put(:hostname, hostname)

    sensor = add(%Sensor{device: device, type: type}, r)

    {sensor, r} |> update_reading() |> record_metrics()
  end

  def external_update(%{} = eu) do
    Logger.warn(fn -> "external_update received a bad map #{inspect(eu)}" end)
    :error
  end

  @doc ~S"""
  Retrieve the fahrenheit temperature reading of a device using it's friendly
  name.  Returns nil if the no friendly name exists.

  """
  def fahrenheit(name) when is_binary(name), do: fahrenheit(name: name)

  def fahrenheit(opts) when is_list(opts),
    do: temperature(opts) |> normalize_readings() |> Map.get(:tf, nil)

  def fahrenheit(nil), do: nil

  def get_by(opts) when is_list(opts) do
    filter = Keyword.take(opts, [:id, :device, :name, :type])

    select =
      Keyword.take(opts, [:only]) |> Keyword.get_values(:only) |> List.flatten()

    if Enum.empty?(filter) do
      Logger.warn(fn -> "get_by bad args: #{inspect(opts)}" end)
      []
    else
      s = from(s in Sensor, where: ^filter) |> one()

      if is_nil(s) or Enum.empty?(select), do: s, else: Map.take(s, select)
    end
  end

  def purge_readings([days: days] = opts) when days < 0 do
    temp = SensorTemperature.purge_readings(opts)
    soil = SensorSoil.purge_readings(opts)
    relhum = SensorRelHum.purge_readings(opts)

    [temp, soil, relhum]
  end

  def purge_readings(_), do: :bad_opts

  def relhum(name) when is_binary(name), do: relhum(name: name)

  def relhum(opts) when is_list(opts) do
    since_secs = Keyword.get(opts, :since_secs, 30) * -1
    sen = get_by(opts)

    if is_nil(sen) do
      nil
    else
      dt = TimeSupport.utc_now() |> Timex.shift(seconds: since_secs)

      query =
        from(
          relhum in SensorRelHum,
          join: s in assoc(relhum, :sensor),
          where: s.id == ^sen.id,
          where: relhum.inserted_at >= ^dt,
          select: avg(relhum.rh)
        )

      if res = Repo.all(query), do: hd(res), else: nil
    end
  end

  def relhum(%Sensor{relhum: %SensorRelHum{rh: rh}}), do: rh
  def relhum(_anything), do: nil

  def soil_moisture(name) when is_binary(name), do: soil_moisture(name: name)

  def soil_moisture(opts) when is_list(opts) do
    since_secs = Keyword.get(opts, :since_secs, 30) * -1
    sen = get_by(opts)

    if is_nil(sen) do
      nil
    else
      dt = TimeSupport.utc_now() |> Timex.shift(seconds: since_secs)

      query =
        from(
          soil in SensorSoil,
          join: s in assoc(soil, :sensor),
          where: s.id == ^sen.id,
          where: soil.inserted_at >= ^dt,
          select: avg(soil.moisture)
        )

      if res = Repo.all(query), do: hd(res), else: nil
    end
  end

  def soil_moisture(%Sensor{soil: %SensorSoil{moisture: moisture}}),
    do: moisture

  def soil_moisture(_anything), do: nil

  def temperature(opts) when is_list(opts) do
    since_secs = Keyword.get(opts, :since_secs, 30) * -1
    sen = get_by(opts)

    if is_nil(sen) do
      nil
    else
      dt = TimeSupport.utc_now() |> Timex.shift(seconds: since_secs)

      query =
        from(
          t in SensorTemperature,
          join: s in assoc(t, :sensor),
          where: s.id == ^sen.id,
          where: t.inserted_at >= ^dt,
          select: %{tf: avg(t.tf), tc: avg(t.tc)}
        )

      if res = Repo.all(query), do: hd(res), else: nil
    end
  end

  ###
  ### PRIVATE
  ###

  defp normalize_readings(nil), do: %{}

  defp normalize_readings(%{tc: nil, tf: nil}), do: %{}

  defp normalize_readings(%{} = r) do
    has_tc = Map.has_key?(r, :tc)
    has_tf = Map.has_key?(r, :tf)

    r =
      if Map.has_key?(r, :rh),
        do: Map.put(r, :rh, Float.round(r.rh * 1.0, 3)),
        else: r

    r = if has_tc, do: Map.put(r, :tc, Float.round(r.tc * 1.0, 3)), else: r
    r = if has_tf, do: Map.put(r, :tf, Float.round(r.tf * 1.0, 3)), else: r

    cond do
      has_tc and has_tf -> r
      has_tc -> Map.put_new(r, :tf, Float.round(r.tc * (9.0 / 5.0) + 32.0, 3))
      has_tf -> Map.put_new(r, :tc, Float.round(r.tf - 32 * (5.0 / 9.0), 3))
      true -> r
    end
  end

  defp record_metrics(
         {%Sensor{type: "temp", name: name} = s,
          %{hostname: hostname, tc: 85.0} = r}
       ) do
    Logger.warn(fn ->
      "dropping invalid temperature for #{inspect(name)} from #{
        inspect(hostname)
      }"
    end)

    {s, r}
  end

  defp record_metrics(
         {%Sensor{type: "temp", device: device, name: name} = s,
          %{hostname: hostname, mtime: mtime, tc: tc, tf: tf} = r}
       ) do
    Logger.debug(fn ->
      "#{name} " <>
        "#{String.pad_leading(Float.to_string(tf), 8)}F " <>
        "#{String.pad_leading(Float.to_string(tc), 8)}C"
    end)

    Fahrenheit.record(
      remote_host: hostname,
      device: device,
      name: name,
      mtime: mtime,
      val: tf
    )

    # Celsius.record(
    #   remote_host: hostname,
    #   device: device,
    #   name: name,
    #   mtime: mtime,
    #   val: tc
    # )

    {s, r}
  end

  defp record_metrics(
         {%Sensor{type: "relhum", device: device, name: name} = s,
          %{hostname: hostname, mtime: mtime, rh: rh, tc: tc, tf: tf} = r}
       ) do
    Logger.debug(fn ->
      "#{name} " <>
        "#{String.pad_leading(Float.to_string(tf), 8)}F " <>
        "#{String.pad_leading(Float.to_string(tc), 8)}C " <>
        "#{String.pad_leading(Float.to_string(rh), 8)}RH"
    end)

    Fahrenheit.record(
      remote_host: hostname,
      device: device,
      name: name,
      mtime: mtime,
      val: tf
    )

    # Celsius.record(
    #   remote_host: hostname,
    #   device: device,
    #   name: name,
    #   mtime: mtime,
    #   val: tc
    # )

    RelativeHumidity.record(
      remote_host: hostname,
      device: device,
      name: name,
      mtime: mtime,
      val: rh
    )

    {s, r}
  end

  defp record_metrics(
         {%Sensor{type: "soil", device: device, name: name} = s,
          %{hostname: hostname, mtime: mtime, cap: cap, tc: tc, tf: tf} = r}
       ) do
    Logger.debug(fn ->
      "#{name} " <>
        "#{String.pad_leading(Float.to_string(tf), 8)}F " <>
        "#{String.pad_leading(Float.to_string(tc), 8)}C " <>
        "#{cap} moisture"
    end)

    Fahrenheit.record(
      remote_host: hostname,
      device: device,
      name: name,
      mtime: mtime,
      val: tf
    )

    # Celsius.record(
    #   remote_host: hostname,
    #   device: device,
    #   name: name,
    #   mtime: mtime,
    #   val: tc
    # )

    SoilMoisture.record(
      remote_host: hostname,
      device: device,
      name: name,
      mtime: mtime,
      val: cap
    )

    {s, r}
  end

  defp record_metrics({%Sensor{name: name} = s, %{} = r}) do
    Logger.warn(fn ->
      "Unable to record metrics for #{name}:\n#{inspect(r, pretty: true)}"
    end)

    {s, r}
  end

  defp update_reading({%Sensor{type: "temp"} = s, r})
       when is_map(r) do
    _temp = update_temperature(s, r)

    {change(s, %{
       last_seen_at: TimeSupport.from_unix(r.mtime),
       reading_at: TimeSupport.utc_now(),
       dev_latency:
         Map.get(
           r,
           :read_us,
           Timex.diff(r.msg_recv_dt, TimeSupport.from_unix(r.mtime))
         )
     })
     |> update!(), r}
  end

  defp update_reading({%Sensor{type: "relhum"} = s, r})
       when is_map(r) do
    _temp = update_temperature(s, r)
    _relhum = update_relhum(s, r)

    {change(s, %{
       last_seen_at: TimeSupport.from_unix(r.mtime),
       reading_at: TimeSupport.utc_now(),
       dev_latency:
         Map.get(
           r,
           :read_us,
           Timex.diff(r.msg_recv_dt, TimeSupport.from_unix(r.mtime))
         )
     })
     |> update!(), r}
  end

  defp update_reading({%Sensor{type: "soil"} = s, %{} = r}) do
    _temp = update_temperature(s, r)
    _moisture = update_moisture(s, r)

    {change(s, %{
       last_seen_at: TimeSupport.from_unix(r.mtime),
       reading_at: TimeSupport.utc_now(),
       dev_latency:
         Map.get(
           r,
           :read_us,
           Timex.diff(r.msg_recv_dt, TimeSupport.from_unix(r.mtime))
         )
     })
     |> update!(), r}
  end

  # handle unknown Sensors by simply passing through
  # useful when bringing new sensors online via mcr
  defp update_reading({%Sensor{} = s, %{} = r}) do
    {s, r}
  end

  #
  # Insert new readings by building associations and inserting
  #

  defp update_moisture(%Sensor{soil: _soil} = sen, r)
       when is_map(r) do
    Ecto.build_assoc(sen, :soil, %{
      moisture: r.cap
    })
    |> insert!()

    {sen, r}
  end

  defp update_relhum(%Sensor{relhum: _relhum} = sen, r)
       when is_map(r) do
    Ecto.build_assoc(sen, :relhum, %{
      rh: r.rh
    })
    |> insert!()

    {sen, r}
  end

  defp update_temperature(%Sensor{temperature: _temp} = sen, r)
       when is_map(r) do
    Ecto.build_assoc(sen, :temperature, %{
      tc: r.tc,
      tf: r.tf
    })
    |> insert!()

    {sen, r}
  end
end
