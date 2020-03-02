defmodule PulseWidth do
  @moduledoc """
    The Sensor module provides the base of a sensor reading.
  """

  require Logger
  use Timex
  use Ecto.Schema

  import Ecto.Changeset
  # import Ecto.Query, only: [from: 2]
  import Repo, only: [get!: 2, get_by: 2, insert: 2, update: 1]

  import Janice.Common.DB, only: [name_regex: 0]
  alias Janice.TimeSupport

  schema "pwm" do
    field(:name, :string)
    field(:description, :string)
    field(:device, :string)
    field(:host, :string)
    field(:duty, :integer)
    field(:duty_max, :integer)
    field(:duty_min, :integer)
    field(:dev_latency_ms, :integer)
    field(:log, :boolean, default: false)
    field(:ttl_ms, :integer, default: 60_000)
    field(:reading_at, :utc_datetime_usec)
    field(:last_seen_at, :utc_datetime_usec)
    field(:metric_at, :utc_datetime_usec, default: nil)
    field(:metric_freq_secs, :integer, default: 60)
    field(:discovered_at, :utc_datetime_usec)
    field(:last_cmd_at, :utc_datetime_usec)

    timestamps(usec: true)
  end

  def add(%{
        device: device,
        duty: duty,
        duty_max: duty_max,
        duty_min: duty_min,
        host: host,
        mtime: mtime
      }),
      do:
        [
          %PulseWidth{
            name: device,
            device: device,
            host: host,
            duty: duty,
            duty_max: duty_max,
            duty_min: duty_min,
            reading_at: TimeSupport.from_unix(mtime),
            last_seen_at: TimeSupport.from_unix(mtime),
            discovered_at: TimeSupport.from_unix(mtime)
          }
        ]
        |> add()

  def add(list) when is_list(list) do
    for %PulseWidth{} = p <- list do
      add(p)
    end
  end

  def add(%PulseWidth{name: _name, device: _device} = p) do
    cs = changeset(p, Map.take(p, possible_changes()))

    with {:cs_valid, true} <- {:cs_valid, cs.valid?()},
         {:ok, %PulseWidth{id: id}} <-
           insert(cs,
             on_conflict: :replace_all,
             conflict_target: :device
           ),
         %PulseWidth{} = p <- find(id) do
      p
    else
      {:cs_valid, false} ->
        Logger.warn([
          "add() invalid changes: ",
          inspect(cs, pretty: true)
        ])

        {:invalid_changes, cs}

      {:error, rc} ->
        Logger.warn([
          "add() failed to insert: ",
          inspect(p, pretty: true),
          " rc: ",
          inspect(rc, pretty: true)
        ])

      error ->
        Logger.warn(["add() failure: ", inspect(error, pretty: true)])

        {:failed, error}
    end
  end

  # when processing an external update the reading map will contain
  # the actual %PulseWidth{} struct when it has been found (already exists)
  # in this case perform the appropriate updates
  def external_update(
        %PulseWidth{} = p,
        %{
          duty: _duty,
          duty_max: _duty_max,
          duty_min: _duty_min,
          host: _host,
          mtime: mtime,
          msg_recv_dt: msg_recv_at
        } = r
      ) do
    changes =
      Map.take(p, external_changes())
      |> Map.merge(%{
        last_seen_at: msg_recv_at,
        reading_at: TimeSupport.from_unix(mtime)
      })

    with cs <- changeset(p, changes),
         {cs, :cs_valid, true} <- {cs, :cs_valid, cs.valid?()},
         {:ok, %PulseWidth{} = p} <- update(cs) do
      p
    else
      {cs, :cs_valid, false} ->
        Logger.warn(["invalid changes: ", inspect(cs, pretty: true)])
        {:invalid_changes, cs}

      error ->
        Logger.warn([
          "external_update() failed: ",
          inspect(error, pretty: true),
          " for reading: ",
          inspect(r, pretty: true)
        ])

        {:error, error}
    end
  end

  # when processing an external update and pulse_width is nil this is a
  # previously unknown %PulseWidth{}
  def external_update(nil, %{} = r) do
    add(r)
  end

  # this is the entry point for a raw incoming message before attempting to
  # find the matching %PulseWidth{} struct from the database
  def external_update(%{device: device} = r) do
    find_by_device(device) |> external_update(r)
  end

  def external_update(catchall),
    do:
      Logger.warn([
        "external_update() unhandled msg: ",
        inspect(catchall, pretty: true)
      ])

  def find(id) when is_integer(id),
    do: get_by(__MODULE__, id: id)

  def find(name) when is_binary(name),
    do: get_by(__MODULE__, name: name)

  def find_by_device(device) when is_binary(device),
    do: get_by(__MODULE__, device: device)

  def reload(%PulseWidth{id: id}), do: reload(id)

  def reload(id) when is_number(id), do: get!(__MODULE__, id)

  defp changeset(dc, params) when is_list(params),
    do: changeset(dc, Enum.into(params, %{}))

  defp changeset(dc, params) when is_map(params) do
    dc
    |> cast(params, possible_changes())
    |> validate_required(required_changes())
    |> validate_format(:name, name_regex())
    |> validate_number(:duty, greater_than_equal_to: 0, less_than: 4096)
    |> validate_number(:duty_min,
      greater_than_equal_to: 0,
      less_than: 4096
    )
    |> validate_number(:duty_max,
      greater_than_equal_to: 0,
      less_than: 4096
    )
    |> unique_constraint(:name, name: :pwm_name_index)
    |> unique_constraint(:device, name: :pwm_device_index)
  end

  # everything EXCEPT for t%PulseWidth{name: _} can be updated based on the
  # message from the Remote device
  defp external_changes,
    do: [
      :host,
      :duty,
      :duty_max,
      :duty_min,
      :dev_latency_ms
    ]

  defp possible_changes,
    do: [
      :name,
      :description,
      :device,
      :host,
      :duty,
      :duty_max,
      :duty_min,
      :dev_latency_ms,
      :log,
      :ttl_ms,
      :reading_at,
      :last_seen_at,
      :metric_at,
      :metric_freq_secs,
      :discovered_at,
      :last_cmd_at
    ]

  defp required_changes,
    do: [
      :name,
      :device,
      :host,
      :duty,
      :duty_max,
      :duty_min
    ]
end
