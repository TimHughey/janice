defmodule Sensor do
  @moduledoc """
    The Sensor module provides the base of a sensor reading.
  """

  require Logger
  use Timex
  use Timex.Ecto.Timestamps
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  import Repo, only: [all: 2, insert!: 1, update: 1, update!: 1, one: 1]

  alias Fact.Fahrenheit
  alias Fact.Celsius
  alias Fact.RelativeHumidity

  schema "sensor" do
    field(:name, :string)
    field(:description, :string)
    field(:device, :string)
    field(:type, :string)
    field(:dev_latency, :integer)
    field(:reading_at, Timex.Ecto.DateTime)
    field(:last_seen_at, Timex.Ecto.DateTime)
    has_one(:temperature, SensorTemperature)
    has_one(:relhum, SensorRelHum)

    timestamps(usec: true)
  end

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

        %Sensor{device: device, name: device, type: type, temperature: temp, relhum: relhum}
        |> insert!()

      %{found: nil, tc: tc, tf: tf, type: type} ->
        temp = %SensorTemperature{tc: tc, tf: tf}

        %Sensor{device: device, name: device, type: type, temperature: temp}
        |> insert!()

      %{found: nil} ->
        type = Map.get(r, :type, nil)
        Logger.warn(fn -> "#{device} unknown type #{type}, defaulting to temp" end)
        %Sensor{device: device, name: device, type: "temp"} |> insert!()
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
      order_by: [asc: s.name],
      preload: [:temperature, :relhum]
    )
    |> all(timeout: 100)
  end

  def change_name(id, to_be, comment \\ "")

  def change_name(id, tobe, comment) when is_integer(id) do
    s = get_by(id: id)

    if not is_nil(s) do
      s
      |> changeset(%{name: tobe, description: comment})
      |> update()
    else
      Logger.warn(fn -> "change name failed" end)
      {:error, :not_found}
    end
  end

  def change_name(asis, tobe, comment)
      when is_binary(asis) and is_binary(tobe) do
    s = get_by(name: asis)

    if is_nil(s),
      do: {:error, :not_found},
      else: changeset(s, %{name: tobe, description: comment})
  end

  def changeset(ss, params \\ %{}) do
    ss
    |> cast(params, [:name, :description])
    |> validate_required([:name])
    |> validate_format(:name, ~r/^[\w]+[\w ]{1,}[\w]$/)
    |> unique_constraint(:name)
  end

  def delete(id) when is_integer(id) do
    from(s in Sensor, where: s.id == ^id) |> Repo.delete_all()
  end

  def delete(name) when is_binary(name) do
    from(s in Sensor, where: s.name == ^name) |> Repo.delete_all()
  end

  def delete_all(:dangerous) do
    from(s in Sensor, where: s.id >= 0) |> Repo.delete_all()
  end

  def external_update(%{device: device, host: host, mtime: mtime, type: type} = r) do
    hostname = Remote.mark_as_seen(host, mtime)
    r = Map.put(r, :hostname, hostname)

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
  def fahrenheit(name) when is_binary(name) do
    get_by(name: name) |> fahrenheit()
  end

  def fahrenheit(opts) when is_list(opts) do
    device = Keyword.get(opts, :device)
    # sen = get_by(opts)

    dt = Timex.now() |> Timex.shift(minutes: -5)

    from(
      t in SensorTemperature,
      join: s in assoc(t, :sensor),
      where: s.device == ^device,
      group_by: t.id,
      order_by: t.inserted_at > ^dt,
      select: avg(t.tf)
    )
    |> Repo.one()
  end

  def fahrenheit(%Sensor{temperature: %SensorTemperature{tf: tf}}), do: tf
  def fahrenheit(%Sensor{} = s), do: Logger.warn(inspect(s))
  def fahrenheit(nil), do: nil

  # def get(name)
  #     when is_binary(name) do
  #   from(
  #     s in Sensor,
  #     where: s.name == ^name,
  #     preload: [:temperature, :relhum]
  #   )
  #   |> one()
  # end
  #
  # def get(device, type)
  #     when is_binary(device) and is_binary(type) do
  #   get_by(device: device, type: type)
  # end

  def get_by(opts) when is_list(opts) do
    filter = Keyword.take(opts, [:id, :device, :name, :type])
    select = Keyword.take(opts, [:only]) |> Keyword.get_values(:only) |> List.flatten()

    if Enum.empty?(filter) do
      Logger.warn(fn -> "get_by bad args: #{inspect(opts)}" end)
      []
    else
      s = from(s in Sensor, where: ^filter, preload: [:temperature, :relhum]) |> one()

      if is_nil(s) or Enum.empty?(select), do: s, else: Map.take(s, select)
    end
  end

  # def get_by_name(name) when is_binary(name) do
  #   from(s in Sensor, where: s.name == ^name) |> one()
  # end

  def relhum(name) when is_binary(name), do: get_by(name: name) |> relhum()
  def relhum(%Sensor{relhum: %SensorRelHum{rh: rh}}), do: rh
  def relhum(_anything), do: nil

  ###
  ### PRIVATE
  ###

  defp record_metrics({%Sensor{type: type} = s, %{hostname: hostname} = r}) do
    cond do
      type === "temp" ->
        Logger.debug(fn ->
          "#{s.name} " <>
            "#{String.pad_leading(Float.to_string(s.temperature.tf), 8)}F " <>
            "#{String.pad_leading(Float.to_string(s.temperature.tc), 8)}C"
        end)

        Fahrenheit.record(
          remote_host: hostname,
          device: s.device,
          name: s.name,
          mtime: r.mtime,
          val: s.temperature.tf
        )

        Celsius.record(
          remote_host: hostname,
          device: s.device,
          name: s.name,
          mtime: r.mtime,
          val: s.temperature.tc
        )

      type === "relhum" ->
        Logger.debug(fn ->
          "#{s.name} " <>
            "#{String.pad_leading(Float.to_string(s.temperature.tf), 8)}F " <>
            "#{String.pad_leading(Float.to_string(s.temperature.tc), 8)}C " <>
            "#{String.pad_leading(Float.to_string(s.relhum.rh), 8)}RH"
        end)

        Fahrenheit.record(
          remote_host: hostname,
          device: s.device,
          name: s.name,
          mtime: r.mtime,
          val: s.temperature.tf
        )

        Celsius.record(
          remote_host: hostname,
          device: r.device,
          name: s.name,
          mtime: r.mtime,
          val: s.temperature.tc
        )

        RelativeHumidity.record(
          remote_host: hostname,
          device: r.device,
          name: s.name,
          mtime: r.mtime,
          val: s.relhum.rh
        )

      true ->
        Logger.warn(fn -> "invalid switch type [#{inspect(type)}]" end)
    end

    {s, r}
  end

  defp record_metrics({%Sensor{} = s, %{} = r}), do: {s, r}

  defp update_reading({%Sensor{type: "temp"} = s, r})
       when is_map(r) do
    {change(s, %{
       last_seen_at: Timex.from_unix(r.mtime),
       reading_at: Timex.now(),
       dev_latency: Map.get(r, :read_us, Timex.diff(r.msg_recv_dt, Timex.from_unix(r.mtime))),
       temperature: update_temperature(s, r)
     })
     |> update!(), r}
  end

  defp update_reading({%Sensor{type: "relhum"} = s, r})
       when is_map(r) do
    {change(s, %{
       last_seen_at: Timex.from_unix(r.mtime),
       reading_at: Timex.now(),
       dev_latency: Map.get(r, :read_us, Timex.diff(r.msg_recv_dt, Timex.from_unix(r.mtime))),
       temperature: update_temperature(s, r),
       relhum: update_relhum(s, r)
     })
     |> update!(), r}
  end

  defp update_relhum(%Sensor{relhum: relhum}, r)
       when is_map(r) do
    change(relhum, %{rh: Float.round(r.rh * 1.0, 2)})
  end

  defp update_temperature(%Sensor{temperature: temp}, r)
       when is_map(r) do
    change(temp, %{tc: Float.round(r.tc * 1.0, 2), tf: Float.round(r.tf * 1.0, 2)})
  end
end
