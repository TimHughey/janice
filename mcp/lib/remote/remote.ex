defmodule Remote do
  @moduledoc """
  The Remote module proveides the mapping from a Remote Device (aka MCR) hostname to
  a defined name and records various metadata about the remote device.
  """

  require Logger
  use Timex
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  import Repo, only: [insert!: 1, one: 1, update: 1]

  alias Fact.RunMetric
  alias Fact.StartupAnnouncement

  import Janice.Common.DB, only: [name_regex: 0]
  alias Janice.TimeSupport

  alias Mqtt.Client
  alias Mqtt.SetName

  schema "remote" do
    field(:host, :string)
    field(:name, :string)
    field(:hw, :string)
    field(:firmware_vsn, :string)
    field(:preferred_vsn, :string)
    field(:project_name, :string)
    field(:idf_vsn, :string)
    field(:app_elf_sha256, :string)
    field(:build_date, :string)
    field(:build_time, :string)
    field(:magic_word, :string)
    field(:secure_vsn, :integer)
    field(:last_start_at, :utc_datetime_usec)
    field(:last_seen_at, :utc_datetime_usec)
    field(:metric_at, :utc_datatime_usec, default: null)
    field(:metric_freq_secs, :integer, 60)
    field(:batt_mv, :integer)
    field(:reset_reason, :string)
    field(:bssid, :string)
    field(:ap_rssi, :integer)
    field(:ap_pri_chan, :integer)
    field(:ap_sec_chan, :integer)
    field(:heap_free, :integer)
    field(:heap_min, :integer)
    field(:uptime_us, :integer)

    timestamps()
  end

  # 15 minutes (as millesconds)
  @delete_timeout_ms 15 * 60 * 1000

  def add(%Remote{} = r), do: add([r])

  def add(%{host: host, mtime: mtime} = r) do
    [
      %Remote{
        host: host,
        hw: Map.get(r, :hw, "unknown hw"),
        name: Map.get(r, :name, host),
        firmware_vsn: Map.get(r, :vsn, "not available"),
        project_name: Map.get(r, :proj, "not available"),
        idf_vsn: Map.get(r, :idf, "not available"),
        app_elf_sha256: Map.get(r, :sha, "not available"),
        build_date: Map.get(r, :bdate, "not available"),
        build_time: Map.get(r, :btime, "not available"),
        magic_word: Map.get(r, :mword, "0x000000"),
        secure_vsn: Map.get(r, :svsn, 0),
        last_seen_at: TimeSupport.from_unix(mtime),
        last_start_at: TimeSupport.from_unix(mtime)
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

  def browse do
    sorted = all() |> Enum.sort(fn a, b -> a.name <= b.name end)
    Scribe.console(sorted, data: [:id, :name, :host, :hw, :inserted_at])
  end

  def changeset(rem, params \\ %{})

  def changeset(%Remote{} = rem, params) do
    rem
    |> cast(params, [
      :name,
      :hw,
      :firmware_vsn,
      :project_name,
      :idf_vsn,
      :app_elf_sha256,
      :build_date,
      :build_time,
      :magic_word,
      :secure_vsn,
      :batt_mv,
      :reset_reason,
      :last_start_at,
      :last_seen_at,
      :bssid,
      :ap_rssi,
      :ap_pri_chan,
      :heap_free,
      :heap_min,
      :uptime_us
    ])
    |> validate_required([:name])
    |> validate_format(:name, name_regex())
    |> unique_constraint(:name)
  end

  def changeset(nil, _params), do: %Ecto.Changeset{}

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

  def change_name(host, new_name)
      when is_binary(host) and is_binary(new_name) do
    remote = get_by(host: host)
    check = get_by(name: new_name)

    if is_nil(check) do
      case remote do
        %Remote{} ->
          {res, rem} = changeset(remote, %{name: new_name}) |> update()

          if res == :ok,
            do:
              SetName.new_cmd(rem.host, rem.name)
              |> SetName.json()
              |> Client.publish()

          res

        _nomatch ->
          :not_found
      end
    else
      :name_in_use
    end
  end

  def change_name(_, _), do: {:error, :bad_args}

  def delete(id) when is_integer(id),
    do:
      from(s in Remote, where: s.id == ^id)
      |> Repo.delete_all(timeout: @delete_timeout_ms)

  def delete_all(:dangerous),
    do:
      from(rem in Remote, where: rem.id >= 0)
      |> Repo.delete_all(timeout: @delete_timeout_ms)

  def deprecate(id) when is_integer(id) do
    r = get_by(id: id)

    if is_nil(r) do
      Logger.warn(fn -> "deprecate(#{id}) failed" end)
      {:error, :not_found}
    else
      tobe = "~ #{r.name}-#{Timex.now() |> Timex.format!("{ASN1:UTCtime}")}"

      r
      |> changeset(%{name: tobe})
      |> update()
    end
  end

  def deprecate(:help), do: deprecate()

  def deprecate do
    IO.puts("Usage:")
    IO.puts("\tRemote.deprecate(id)")
  end

  def external_update(%{host: host, mtime: _mtime} = eu) do
    log = Map.get(eu, :log, true)

    result =
      :timer.tc(fn ->
        Logger.debug(fn -> "external_update() handling:" end)

        Logger.debug(fn ->
          "#{inspect(eu, binaries: :as_strings, pretty: true)}"
        end)

        eu |> add() |> send_remote_config(eu)
      end)

    case result do
      {t, {:ok, rem}} ->
        RunMetric.record(
          module: "#{__MODULE__}",
          metric: "external_update",
          # use the local name
          device: rem.name,
          val: t,
          record: false
        )

        :ok

      {_t, {err, details}} ->
        log &&
          Logger.warn(fn ->
            "external update failed host(#{host}) " <>
              "err(#{inspect(err, pretty: true)}) " <>
              "details(#{inspect(details, pretty: true)})"
          end)

        :error
    end
  end

  def external_update(no_match) do
    log = is_map(no_match) and Map.get(no_match, :log, true)

    log &&
      Logger.warn(fn ->
        "external update received a bad map #{inspect(no_match)}"
      end)

    :error
  end

  def get_by(opts) when is_list(opts) do
    filter = Keyword.take(opts, [:id, :host, :name])

    select =
      Keyword.take(opts, [:only]) |> Keyword.get_values(:only) |> List.flatten()

    if Enum.empty?(filter) do
      Logger.warn(fn -> "get_by bad args: #{inspect(opts)}" end)
      []
    else
      rem = from(remote in Remote, where: ^filter) |> one()

      if is_nil(rem) or Enum.empty?(select),
        do: rem,
        else: Map.take(rem, select)
    end
  end

  # header to define default parameter for multiple functions
  def mark_as_seen(host, time, threshold_secs \\ 3)

  def mark_as_seen(host, mtime, threshold_secs)
      when is_binary(host) and is_integer(mtime) do
    case get_by(host: host) do
      nil ->
        host

      rem ->
        mark_as_seen(rem, TimeSupport.from_unix(mtime), threshold_secs)
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

  def ota_update(what, opts \\ []) do
    opts = Keyword.put_new(opts, :log, false)
    update_list = remote_list(what) |> Enum.filter(fn x -> is_map(x) end)

    if Enum.empty?(update_list) do
      Logger.warn(fn -> "can't do ota for: #{inspect(update_list)}" end)
    else
      opts = opts ++ [update_list: update_list]
      OTA.send_cmd(opts)
    end
  end

  # create a list of ota updates for all Remotes
  def remote_list(:all) do
    remotes = all()

    for r <- remotes, do: ota_update_map(r)
  end

  # create a list
  def remote_list(id) when is_integer(id) do
    with %Remote{} = r <- get_by(id: id),
         map <- ota_update_map(r) do
      [map]
    else
      nil ->
        Logger.warn(fn -> "id(#{id}) not found" end)
        [:not_found]
    end
  end

  def remote_list(name) when is_binary(name) do
    q = from(remote in Remote, where: [name: ^name], or_where: [host: ^name])
    rem = one(q)

    # Logger.warn(fn -> "remote_list(name) rem=#{inspect(rem)}" end)

    case rem do
      %Remote{} = r ->
        map = ota_update_map(r)
        [map]

      nil ->
        Logger.warn(fn -> "name(#{name}) not found" end)
        [:not_found]
    end
  end

  def remote_list(list) when is_list(list) do
    make_list = fn list ->
      for l <- list, do: remote_list(l)
    end

    make_list.(list) |> List.flatten()
  end

  def remote_list(anything_else) do
    Logger.warn(fn -> "unsupported: #{inspect(anything_else)}" end)
    [:unsupported]
  end

  defp ota_update_map(%Remote{} = r), do: %{name: r.name, host: r.host}

  def restart(what, opts \\ []) do
    opts = Keyword.put_new(opts, :log, false)
    restart_list = remote_list(what) |> Enum.filter(fn x -> is_map(x) end)

    if Enum.empty?(restart_list) do
      Logger.warn(fn -> "can't do restart for: #{inspect(restart_list)}" end)
    else
      opts = opts ++ [restart_list: restart_list]
      OTA.restart(opts)
    end
  end

  #
  # PRIVATE FUNCTIONS
  #

  # handle boot and startup (depcreated) messages
  defp send_remote_config([%Remote{} = rem], %{type: "boot"} = eu) do
    Logger.debug(fn -> "send_remote_config handling: #{rem.host} #{eu.type}" end)

    # only the feather m0 remote devices need the time
    if eu.hw in ["m0"], do: Client.send_timesync()

    # all devices are sent their name
    SetName.new_cmd(rem.host, rem.name) |> SetName.json() |> Client.publish()

    log = Map.get(eu, :log, true)

    log &&
      Logger.warn(fn ->
        heap_free = (Map.get(eu, :heap_free, 0) / 1024) |> Float.round(1)
        heap_min = (Map.get(eu, :heap_min, 0) / 1024) |> Float.round(1)

        "#{rem.name} BOOT " <>
          "#{Map.get(eu, :reset_reason, "no reset reason")} " <>
          "#{eu.vsn} " <>
          "#{Map.get(eu, :batt_mv, "0")}mv " <>
          "#{Map.get(eu, :ap_rssi, "0")}dB " <>
          "heap(#{heap_min}k,#{heap_free}k) "
      end)

    StartupAnnouncement.record(host: rem.name, vsn: eu.vsn, hw: eu.hw)

    # use the message mtime to update the last start at time
    eu = Map.put_new(eu, :last_start_at, TimeSupport.from_unix(eu.mtime))
    update_from_external(rem, eu)
  end

  defp send_remote_config([%Remote{} = rem], %{type: "remote_runtime"} = eu) do
    # use the message mtime to update the last seen at time
    eu = Map.put_new(eu, :last_seen_at, TimeSupport.from_unix(eu.mtime))
    update_from_external(rem, eu)
  end

  defp send_remote_config(_anything, %{} = eu) do
    log = Map.get(eu, :log, true)

    log &&
      Logger.warn(fn ->
        "attempt to process unknown message type: #{
          Map.get(eu, :type, "unknown")
        }"
      end)

    {:error, "unknown message type"}
  end

  defp update_from_external(%Remote{} = rem, eu) do
    params = %{
      # remote_runtime messages:
      #  :last_start_at is added to map for boot messages when not available
      #   keep existing time
      last_seen_at: Map.get(eu, :last_seen_at, rem.last_seen_at),
      firmware_vsn: Map.get(eu, :vsn, rem.firmware_vsn),
      hw: Map.get(eu, :hw, rem.hw),
      project_name: Map.get(eu, :proj, rem.project_name),
      idf_vsn: Map.get(eu, :idf, rem.idf_vsn),
      app_elf_sha256: Map.get(eu, :sha, rem.app_elf_sha256),
      build_date: Map.get(eu, :bdate, rem.build_date),
      build_time: Map.get(eu, :btime, rem.build_time),
      magic_word: Map.get(eu, :mword, rem.magic_word),
      secure_vsn: Map.get(eu, :svsn, rem.secure_vsn),
      # reset the following metrics when not present
      ap_rssi: Map.get(eu, :ap_rssi, 0),
      ap_pri_chan: Map.get(eu, :ap_pri_chan, 0),
      bssid: Map.get(eu, :bssid, "xx:xx:xx:xx:xx:xx"),
      # ap_sec_chan: Map.get(eu, :ap_sec_chan, 0),
      batt_mv: Map.get(eu, :batt_mv, 0),
      heap_free: Map.get(eu, :heap_free, 0),
      heap_min: Map.get(eu, :heap_min, 0),
      uptime_us: Map.get(eu, :uptime_us, 0),

      # boot messages:
      #  :last_start_at is added to map for boot messages not present
      #   keep existing time
      last_start_at: Map.get(eu, :last_start_at, rem.last_start_at),
      reset_reason: Map.get(eu, :reset_reason, rem.reset_reason)
    }

    changeset(rem, params) |> update()
  end

  defp update_from_external({:error, _}, _), do: {:error, "bad update"}
end
