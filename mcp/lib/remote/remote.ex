defmodule Remote do
  @moduledoc """
  The Remote module proveides the mapping from a Remote Device (aka MCR) hostname to
  a defined name and records various metadata about the remote device.
  """

  require Logger
  use Timex
  use Timex.Ecto.Timestamps
  use Ecto.Schema

  import Ecto.Changeset, only: [change: 2]
  import Ecto.Query, only: [from: 2]
  import Repo, only: [insert!: 1, one: 1, update: 1]

  alias Fact.RunMetric
  alias Fact.StartupAnnouncement

  alias Mqtt.Client
  alias Mqtt.SetName
  alias Mqtt.OTA

  schema "remote" do
    field(:host, :string)
    field(:name, :string)
    field(:hw, :string)
    field(:firmware_vsn, :string)
    field(:last_start_at, Timex.Ecto.DateTime)
    field(:last_seen_at, Timex.Ecto.DateTime)

    timestamps(usec: true)
  end

  def add(%Remote{} = r), do: add([r])

  def add(%{host: host, hw: hw, vsn: vsn, mtime: mtime}) do
    [
      %Remote{
        host: host,
        name: host,
        hw: hw,
        firmware_vsn: vsn,
        last_seen_at: Timex.from_unix(mtime),
        last_start_at: Timex.from_unix(mtime)
      }
    ]
    |> add()
  end

  def add(list) when is_list(list) do
    for %Remote{} = r <- list do
      case get_by_host(r.host) do
        nil ->
          insert!(r)

        found ->
          Logger.debug(fn -> ~s/[#{r.host}] already exists, skipping add/ end)
          found
      end
    end
  end

  def add(no_match) do
    Logger.warn(fn -> "attempt to add non %Remote{} #{inspect(no_match)}" end)
    no_match
  end

  def change_name(host, new_name) when is_binary(host) and is_binary(new_name) do
    case get_by_host(host) do
      nil ->
        :error

      found ->
        {res, rem} = change(found, name: new_name) |> update()

        if res == :ok,
          do: SetName.new_cmd(rem.host, rem.name) |> SetName.json() |> Client.publish()

        res
    end
  end

  def external_update(%{host: host, vsn: _vsn, mtime: _mtime, hw: _hw} = eu) do
    result =
      :timer.tc(fn ->
        eu |> add() |> update_from_external(eu)
      end)

    case result do
      {t, {:ok, rem}} ->
        RunMetric.record(
          module: "#{__MODULE__}",
          metric: "external_update",
          # use the local name
          device: rem.name,
          val: t
        )

        :ok

      # TODO: extract the actual error from update
      {_t, {_, _}} ->
        Logger.warn(fn ->
          "external update failed for [#{host}]"
        end)

        :error
    end
  end

  def external_update(no_match) do
    Logger.warn(fn -> "external update received a bad map #{inspect(no_match)}" end)
    :error
  end

  def get_by_host(host) do
    from(remote in Remote, where: remote.host == ^host) |> one()
  end

  def get_name_by_host(host) do
    case get_by_host(host) do
      nil -> host
      rem -> rem.name
    end
  end

  def mark_as_seen(host, mtime) when is_binary(host) do
    case get_by_host(host) do
      nil -> host
      rem -> mark_as_seen(rem, Timex.from_unix(mtime))
    end
  end

  def mark_as_seen(%Remote{} = rem, %DateTime{} = dt) do
    # only update last seen if more than 30 seconds different
    # this is to avoid high rates of updates when a device hosts many sensors
    if Timex.diff(dt, rem.last_seen_at, :seconds) > 10 do
      opts = [last_seen_at: dt]
      {res, updated} = change(rem, opts) |> update()
      if res == :ok, do: updated.name, else: rem.name
    else
      rem.name
    end
  end

  def ota_begin do
    OTA.send_begin()
  end

  def ota_end do
    OTA.send_end()
  end

  defp update_from_external([%Remote{} = rem], eu) do
    # only the feather m0 remote devices need the time
    if eu.hw in ["m0"], do: Client.send_timesync()

    # all devices are sent their name
    SetName.new_cmd(rem.host, rem.name) |> SetName.json() |> Client.publish()

    Logger.warn(fn -> "#{rem.name} started (host=#{rem.host},hw=#{eu.hw},vsn=#{eu.vsn})" end)

    StartupAnnouncement.record(host: rem.name, vsn: eu.vsn, hw: eu.hw)

    opts = [
      last_start_at: Timex.from_unix(eu.mtime),
      last_seen_at: Timex.from_unix(eu.mtime),
      firmware_vsn: eu.vsn,
      hw: eu.hw
    ]

    change(rem, opts) |> update()
  end

  defp update_from_external({:error, _}, _), do: {:error, "bad update"}
end
