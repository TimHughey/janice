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
  import Repo, only: [insert: 1, insert!: 1, one: 1, update: 1]

  alias Fact.RunMetric
  alias Fact.StartupAnnouncement

  alias Mqtt.Client

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

  def add(list) when is_list(list) do
    for %Remote{} = r <- list do
      q =
        from(
          remote in Remote,
          where: remote.host == ^r.host
        )

      case one(q) do
        nil ->
          insert!(r)

        found ->
          Logger.warn(fn -> ~s/[#{r.host}] already exists, skipping add/ end)
          found
      end
    end
  end

  def add(no_match) do
    Logger.warn(fn -> "attempt to add non %Remote{} #{inspect(no_match)}" end)
    no_match
  end

  def external_update(%{host: host, vsn: vsn, mtime: mtime, hw: hw} = eu) do
    result =
      :timer.tc(fn ->
        rem = get_by_host(host)

        if rem == nil do
          %Remote{
            host: host,
            name: host,
            hw: hw,
            firmware_vsn: vsn,
            last_seen_at: Timex.from_unix(mtime),
            last_start_at: Timex.from_unix(mtime)
          }
          |> insert()
        else
          rem |> update_from_external(eu)
        end
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

      # TODO: extract the actual error from the update
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

  defp get_by_host(host) do
    from(remote in Remote, where: remote.host == ^host) |> one()
  end

  defp update_from_external(rem, eu) do
    Logger.warn(fn -> "#{rem.name} started (host=#{rem.host},hw=#{eu.hw},vsn=#{eu.vsn})" end)

    StartupAnnouncement.record(host: rem.name, vsn: eu.vsn, hw: eu.hw)

    # only the feather m0 remote devices need the time
    if eu.hw in ["m0"], do: Client.send_timesync()

    opts = [
      last_start_at: Timex.from_unix(eu.mtime),
      last_seen_at: Timex.from_unix(eu.mtime),
      firmware_vsn: eu.vsn,
      hw: eu.hw
    ]

    change(rem, opts) |> update()
  end
end
