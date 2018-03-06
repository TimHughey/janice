defmodule Remote do
  @moduledoc """
  The Remote module proveides the mapping from a Remote Device (aka MCR) hostname to
  a defined name and records various metadata about the remote device.
  """

  require Logger
  use Timex
  use Timex.Ecto.Timestamps
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  import Repo, only: [insert!: 1, one: 1, update: 1]

  alias Fact.RunMetric
  alias Fact.StartupAnnouncement

  alias Mqtt.Client
  alias Mqtt.SetName

  schema "remote" do
    field(:host, :string)
    field(:name, :string)
    field(:hw, :string)
    field(:firmware_vsn, :string)
    field(:preferred_vsn, :string)
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
      case get_by(host: r.host) do
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

  def all do
    from(
      rem in Remote,
      select: rem
    )
    |> Repo.all()
  end

  def at_preferred_vsn?(%Remote{firmware_vsn: current} = r) do
    fw_file_vsn = OTA.fw_file_version()

    preferred =
      case r.preferred_vsn do
        "head" ->
          Map.get(fw_file_vsn, :head)

        "stable" ->
          Map.get(fw_file_vsn, :stable)

        _ ->
          Logger.warn(fn -> "#{r.name} has a bad preferred vsn #{r.preferred_vsn}" end)
          "0000000"
      end

    case current do
      ^preferred -> true
      _ -> false
    end
  end

  def changeset(ss, params \\ %{}) do
    ss
    |> cast(params, [:name, :preferred_vsn])
    |> validate_required([:name])
    |> validate_inclusion(:preferred_vsn, ["head", "stable"])
    |> validate_format(:name, ~r/^[\w]+[\w ]{1,}[\w]$/)
    |> unique_constraint(:name)
  end

  def change_name(id, new_name) when is_integer(id) and is_binary(new_name) do
    remote = Repo.get(Remote, id)

    if remote do
      case change_name(remote.host, new_name) do
        :ok -> new_name
        failed -> failed
      end
    else
      :not_found
    end
  end

  def change_name(host, new_name) when is_binary(host) and is_binary(new_name) do
    remote = get_by(host: host)
    check = get_by(name: new_name)

    if is_nil(check) do
      case remote do
        %Remote{} ->
          new_name = String.replace(new_name, " ", "_")
          {res, rem} = changeset(remote, %{name: new_name}) |> update()

          if res == :ok,
            do: SetName.new_cmd(rem.host, rem.name) |> SetName.json() |> Client.publish()

          res

        _nomatch ->
          :not_found
      end
    else
      :name_in_use
    end
  end

  def change_name(_, _), do: {:error, :bad_args}

  def change_vsn_preference(id, preference) when is_integer(id) and is_binary(preference) do
    {res, rem} = Repo.get(Remote, id) |> changeset(%{preferred_vsn: preference}) |> update()
    if res == :ok, do: rem.preferred_vsn, else: res
  end

  def delete(id) when is_integer(id),
    do: from(s in Remote, where: s.id == ^id) |> Repo.delete_all()

  def delete_all(:dangerous),
    do:
      from(rem in Remote, where: rem.id >= 0)
      |> Repo.delete_all()

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
    log = is_map(no_match) and Map.get(no_match, :log, true)
    log && Logger.warn(fn -> "external update received a bad map #{inspect(no_match)}" end)
    :error
  end

  def get_by(opts) when is_list(opts) do
    filter = Keyword.take(opts, [:id, :host, :name])
    select = Keyword.take(opts, [:only]) |> Keyword.get_values(:only) |> List.flatten()

    if Enum.empty?(filter) do
      Logger.warn(fn -> "get_by bad args: #{inspect(opts)}" end)
      []
    else
      rem = from(remote in Remote, where: ^filter) |> one()

      if is_nil(rem) or Enum.empty?(select), do: rem, else: Map.take(rem, select)
    end
  end

  # header to define default parameter for multiple functions
  def mark_as_seen(host, time, threshold_secs \\ 10)

  def mark_as_seen(host, mtime, threshold_secs)
      when is_binary(host) and is_integer(mtime) do
    case get_by(host: host) do
      nil -> host
      rem -> mark_as_seen(rem, Timex.from_unix(mtime), threshold_secs)
    end
  end

  def mark_as_seen(%Remote{} = rem, %DateTime{} = dt, threshold_secs) do
    # only update last seen if more than threshold_secs different
    # this is to avoid high rates of updates when a device hosts many sensors
    if Timex.diff(dt, rem.last_seen_at, :seconds) >= threshold_secs do
      opts = [last_seen_at: dt]
      {res, updated} = change(rem, opts) |> update()
      if res == :ok, do: updated.name, else: rem.name
    else
      rem.name
    end
  end

  def mark_as_seen(nil, _, _), do: nil

  # ota_update() header
  def ota_update(id, opts \\ [])

  def ota_update(:all, opts) when is_list(opts), do: all() |> ota_update(opts)

  def ota_update(id, opts)
      when is_integer(id) do
    rem = Repo.get(Remote, id)
    ota_update([rem], opts)
  end

  def ota_update(list, opts) when is_list(list) and is_list(opts) do
    delay_ms = Keyword.get(opts, :start_delay_ms, 10000)
    reboot_delay_ms = Keyword.get(opts, :reboot_delay_ms, 3000)
    force = Keyword.get(opts, :force, false)
    log = Keyword.get(opts, :log, false)

    update_hosts =
      for %Remote{host: host, name: name} = r <- list do
        at_vsn = at_preferred_vsn?(r)

        if at_vsn == false or force == true do
          log && Logger.warn(fn -> "#{name} needs update" end)
          host
        else
          false
        end
      end

    if Enum.empty?(update_hosts) do
      :none_needed
    else
      opts =
        opts ++
          [update_hosts: update_hosts, start_delay_ms: delay_ms, reboot_delay_ms: reboot_delay_ms]

      OTA.transmit(opts)
      :ok
    end
  end

  def ota_update_single(name, opts \\ []) when is_binary(name) do
    log = Keyword.get(opts, :log, true)
    r = get_by(name: name)

    if is_nil(r) do
      log && Logger.warn(fn -> "#{name} not found, can't trigger ota" end)
      :not_found
    else
      ota_update([r], opts)
    end
  end

  def restart(id, opts \\ []) when is_integer(id) do
    log = Keyword.get(opts, :log, true)
    r = get_by(id: id)

    if is_nil(r) do
      log && Logger.warn(fn -> "remote id #{id} not found, can't trigger restart" end)
      :not_found
    else
      OTA.restart(r.host, opts)
      :ok
    end
  end

  def vsn_preference(opts) do
    case get_by(opts) do
      %Remote{preferred_vsn: vsn} -> vsn
      _notfound -> "not_found"
    end
  end

  #
  # PRIVATE FUNCTIONS
  #

  defp update_from_external([%Remote{} = rem], eu) do
    # only the feather m0 remote devices need the time
    if eu.hw in ["m0"], do: Client.send_timesync()

    # all devices are sent their name
    SetName.new_cmd(rem.host, rem.name) |> SetName.json() |> Client.publish()

    log = Map.get(eu, :log, true)

    log &&
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
