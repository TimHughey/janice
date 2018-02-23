defmodule Sensor do
  @moduledoc """
    The Sensor module provides the base of a sensor reading.
  """

  require Logger
  use Timex
  use Timex.Ecto.Timestamps
  use Ecto.Schema

  # import Application, only: [get_env: 2]
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  import Repo, only: [all: 2, delete_all: 1, insert!: 1, update: 1, update!: 1, one: 1]

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

  def add(%Sensor{name: name} = s) do
    q =
      from(
        s in Sensor,
        where: s.name == ^name,
        preload: [:temperature, :relhum]
      )

    case one(q) do
      nil ->
        ensure_temperature(s) |> ensure_relhum() |> insert!()

      found ->
        Logger.warn(~s/[#{s.name}] already exists, skipping add/)
        found
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
    s = Repo.get(Sensor, id)

    if not is_nil(s) do
      s
      |> changeset(%{name: tobe, description: comment})
      |> update()
    else
      Logger.info(fn -> "change name failed" end)
      {:error, :not_found}
    end
  end

  def change_name(asis, tobe, comment)
      when is_binary(asis) and is_binary(tobe) do
    s = get_by_name(asis)

    if not is_nil(s) do
      s
      |> changeset(%{name: tobe, description: comment})
      |> update()
    else
      {:error, :not_found}
    end
  end

  def changeset(ss, params \\ %{}) do
    ss
    |> cast(params, [:name, :description])
    |> validate_required([:name])
    |> validate_format(:name, ~r/^[\w]+[\w ]{1,}[\w]$/)
    |> unique_constraint(:name)
  end

  def delete(id) when is_integer(id) do
    from(s in Sensor, where: s.id == ^id) |> delete_all()
  end

  def delete(name) when is_binary(name) do
    from(s in Sensor, where: s.name == ^name) |> delete_all()
  end

  @doc ~S"""
  Retrieve the fahrenheit temperature reading of a device using it's friendly
  name.  Returns nil if the no friendly name exists.

  """
  def fahrenheit(name) when is_binary(name), do: get(name) |> fahrenheit()
  def fahrenheit(%Sensor{temperature: %SensorTemperature{tf: tf}}), do: tf
  def fahrenheit(%Sensor{} = s), do: Logger.warn(inspect(s))

  def external_update(%{device: device, host: host, mtime: mtime, type: type} = r) do
    hostname = Remote.mark_as_seen(host, mtime)

    s =
      case get(device, type) do
        nil ->
          Logger.info(fn -> "discovered new sensor [#{device}]" end)

          %Sensor{name: device, device: device, type: type}
          |> ensure_temperature()
          |> ensure_relhum()
          |> insert!()

        s ->
          s
      end

    s = update_reading(s, r)

    # TODO: refactor this to a standalone function
    case type do
      "temp" ->
        Logger.debug(fn ->
          "#{s.name} " <>
            "#{String.pad_leading(Float.to_string(s.temperature.tf), 8)}F " <>
            "#{String.pad_leading(Float.to_string(s.temperature.tc), 8)}C"
        end)

        Fahrenheit.record(
          remote_host: hostname,
          device: r.device,
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

      "relhum" ->
        Logger.debug(fn ->
          "#{s.name} " <>
            "#{String.pad_leading(Float.to_string(s.temperature.tf), 8)}F " <>
            "#{String.pad_leading(Float.to_string(s.temperature.tc), 8)}C " <>
            "#{String.pad_leading(Float.to_string(s.relhum.rh), 8)}RH"
        end)

        Fahrenheit.record(
          remote_host: hostname,
          device: r.device,
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
    end

    s
  end

  def external_update(%{} = eu) do
    Logger.warn(fn -> "external_update received a bad map #{inspect(eu)}" end)
    :error
  end

  def get(name)
      when is_binary(name) do
    from(
      s in Sensor,
      where: s.name == ^name,
      preload: [:temperature, :relhum]
    )
    |> one()
  end

  def get(device, type)
      when is_binary(device) and is_binary(type) do
    q =
      case type do
        "temp" ->
          from(
            s in Sensor,
            join: t in assoc(s, :temperature),
            where: s.device == ^device,
            where: s.type == ^type,
            preload: [temperature: t]
          )

        "relhum" ->
          from(
            s in Sensor,
            join: t in assoc(s, :temperature),
            join: r in assoc(s, :relhum),
            where: s.device == ^device,
            where: s.type == ^type,
            preload: [temperature: t, relhum: r]
          )

        _unknown ->
          Logger.warn(fn -> "unknown type #{type} for [#{device}]" end)

          from(
            s in Sensor,
            where: s.type == ^type,
            where: s.name == ^device,
            or_where: s.device == ^device
          )
      end

    case one(q) do
      nil ->
        Logger.info(fn -> "new #{type} sensor [#{device}]" end)
        %Sensor{name: device, device: device, type: type} |> add()

      s ->
        s
    end
  end

  def get_by_name(name) when is_binary(name) do
    from(s in Sensor, where: s.name == ^name) |> one()
  end

  def relhum(name) when is_binary(name), do: get(name) |> relhum()
  def relhum(%Sensor{relhum: %SensorRelHum{rh: rh}}), do: rh
  def relhum(_anything), do: nil

  ###
  ### PRIVATE
  ###

  defp ensure_relhum(%Sensor{relhum: relhum} = s) do
    if Ecto.assoc_loaded?(relhum),
      do: s,
      else: %{s | relhum: %SensorRelHum{}}
  end

  defp ensure_temperature(%Sensor{temperature: temp} = s) do
    if Ecto.assoc_loaded?(temp),
      do: s,
      else: %{s | temperature: %SensorTemperature{}}
  end

  defp update_reading(%Sensor{type: "temp"} = s, r)
       when is_map(r) do
    change(s, %{
      last_seen_at: Timex.from_unix(r.mtime),
      reading_at: Timex.now(),
      dev_latency: Map.get(r, :read_us, Timex.diff(r.msg_recv_dt, Timex.from_unix(r.mtime))),
      temperature: update_temperature(s, r)
    })
    |> update!()
  end

  defp update_reading(%Sensor{type: "relhum"} = s, r)
       when is_map(r) do
    change(s, %{
      last_seen_at: Timex.from_unix(r.mtime),
      reading_at: Timex.now(),
      dev_latency: Map.get(r, :read_us, Timex.diff(r.msg_recv_dt, Timex.from_unix(r.mtime))),
      temperature: update_temperature(s, r),
      relhum: update_relhum(s, r)
    })
    |> update!()
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
