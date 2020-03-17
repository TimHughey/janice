defmodule Switch do
  @moduledoc """
    The Switches module provides functionality for digital switches.

    Additionally, the Switches module handles the situation where a single
    addressable device has multiple siwtches.  For example, the DS2408 has
    eight PIOs available on each physical device.

    Behind the scenes a switch device id embeds the specific PIO
    for a friendly name.

    For example:
      ds/291d1823000000:1 => ds/<serial num>:<specific pio>
        * In other words, this device id addresses PIO one (of eight total)
          on the physical device with serial 291d1823000000.
        * The first two characters (or any characters before the slash) are
          a mnemonic identifiers for the type of physical device (most often
          the manufacturer or bus type).  In this case, 'ds' signals this is a
          device from Dallas Semiconductors.
  """

  require Logger
  use Ecto.Schema

  import UUID, only: [uuid1: 0]
  import Ecto.Changeset, only: [change: 2]
  import Ecto.Query, only: [from: 2]

  import Repo,
    only: [
      insert: 1,
      insert!: 1,
      one: 1,
      update: 1,
      update!: 1,
      update_all: 2
    ]

  alias Fact.RunMetric
  alias Janice.TimeSupport

  schema "switch" do
    field(:device, :string)
    field(:dev_latency_us, :integer)
    field(:log, :boolean, default: false)
    field(:discovered_at, :utc_datetime_usec)
    field(:last_cmd_at, :utc_datetime_usec)
    field(:last_seen_at, :utc_datetime_usec)

    field(:runtime_metrics, :map,
      null: false,
      default: %{external_update: false, cmd_rt: true}
    )

    has_many(:states, SwitchState)
    has_many(:cmds, SwitchCmd)

    timestamps(usec: true)
  end

  # 15 minutes (as millesconds)
  @delete_timeout_ms 15 * 60 * 1000

  def add([]), do: []

  def add([%Switch{} = sw | rest]) do
    [add(sw)] ++ add(rest)
  end

  def add(%Switch{device: device} = sw) do
    q =
      from(
        sw in Switch,
        where: sw.device == ^device,
        preload: [:states]
      )

    case one(q) do
      nil ->
        ensure_states(sw) |> ensure_cmds() |> insert!()

      found ->
        Logger.warn([
          inspect(sw.device, pretty: true),
          " already exists, skipping add"
        ])

        found
    end
  end

  def add_cmd(name, %Switch{} = sw, %DateTime{} = dt) when is_binary(name) do
    refid = uuid1()

    Ecto.build_assoc(
      sw,
      :cmds,
      refid: refid,
      name: name,
      sent_at: dt
    )
    |> insert!()

    update_last_cmd(sw, dt)

    # return the newly created refid
    refid
  end

  def delete(id) when is_integer(id) do
    from(s in Switch, where: s.id == ^id)
    |> Repo.delete_all(timeout: @delete_timeout_ms)
  end

  def delete(device) when is_binary(device) do
    from(s in Switch, where: s.device == ^device)
    |> Repo.delete_all(timeout: @delete_timeout_ms)
  end

  def delete_all(:dangerous) do
    for sw <- from(sw in Switch, select: [:id]) |> Repo.all() do
      Repo.delete(sw)
    end
  end

  def external_update(%{host: host, device: device, mtime: mtime} = r) do
    result =
      :timer.tc(fn ->
        Remote.mark_as_seen(host, mtime)

        sw = get_by_device(device)

        if sw == nil do
          %Switch{
            device: device,
            states: create_states(r),
            cmds: create_cmds(r)
          }
          |> insert()
        else
          %{r: r, sw: sw}
          |> update_from_reading()
        end
      end)

    case result do
      {t, {:ok, sw}} ->
        RunMetric.record(
          module: "#{__MODULE__}",
          metric: "external_update",
          device: sw.device,
          val: t,
          record: false
          # record: Map.get(r, :runtime_metrics, false)
        )

        :ok

      {_, {_, _}} ->
        Logger.warn([inspect(device, pretty: true), " external update failed "])

        :error
    end
  end

  # REFACTOR
  def external_update(catchall) do
    Logger.warn([
      "external_update() unhandled msg: ",
      inspect(catchall, pretty: true)
    ])

    {:error, :unhandled_msg, catchall}
  end

  def last_seen_at(%Switch{last_seen_at: last_seen_at}), do: last_seen_at

  def pending_cmds(device, opts \\ []) when is_binary(device) do
    sw = get_by(device: device)

    if sw, do: SwitchCmd.pending_cmds(sw, opts), else: nil
  end

  def position(name, opts \\ []) when is_binary(name) and is_list(opts),
    do: SwitchState.position(name, opts) |> SwitchGroup.position(opts)

  def replace(name, replacement)
      when is_binary(name) and is_binary(replacement),
      do: SwitchState.replace(name, replacement)

  ##
  ## Internal / private functions
  ##

  defp create_cmds(%{}) do
    [%SwitchCmd{refid: uuid1(), acked: true, ack_at: TimeSupport.utc_now()}]
  end

  defp create_states(%{device: device, pio_count: pio_count})
       when is_binary(device) and is_integer(pio_count) do
    for pio <- 0..(pio_count - 1) do
      name = "#{device}:#{pio}"
      %SwitchState{name: name, pio: pio}
    end
  end

  defp ensure_cmds(%Switch{cmds: cmds, log: log} = sw) do
    if Ecto.assoc_loaded?(cmds) == false do
      log &&
        Logger.info([
          inspect(sw.device, pretty: true),
          " default acked cmd added"
        ])

      Map.put(sw, :cmds, create_cmds(%{}))
    else
      sw
    end
  end

  defp ensure_states(%Switch{states: states, log: log} = sw) do
    if Ecto.assoc_loaded?(states) == false do
      log &&
        Logger.info([inspect(sw.device, pretty: true), " default states added"])

      Map.put(sw, :states, create_states(%{device: sw.device, pio_count: 2}))
    else
      sw
    end
  end

  def get_by(opts) when is_list(opts) do
    filter = Keyword.take(opts, [:name, :device])

    select =
      Keyword.take(opts, [:only]) |> Keyword.get_values(:only) |> List.flatten()

    if Enum.empty?(filter) do
      Logger.warn(["get_by bad args: ", inspect(opts, pretty: true)])
      []
    else
      sw = from(sw in Switch, where: ^filter) |> one()

      if is_nil(sw) or Enum.empty?(select), do: sw, else: Map.take(sw, select)
    end
  end

  defp get_by_device(device) do
    # last_cmd =
    #   from(sc in SwitchCmd,
    #     group_by: sc.switch_id,
    #     select: %{switch_id: sc.switch_id, last_cmd_id: max(sc.id)})

    from(
      sw in Switch,
      join: states in assoc(sw, :states),
      order_by: [asc: states.pio],
      # join: cmds in subquery(last_cmd), on: cmds.last_cmd_id == sw.id,
      where: sw.device == ^device,
      preload: [states: states]
    )
    |> one()
  end

  defp update_from_reading(%{r: r, sw: sw}) do
    ###
    # NOTE NOTE NOTE
    #  this function assumes that switch states and reading states are sorted
    #  by PIO number!  PIO numbers always start at zero.
    ###

    # NOTE: must ack the command first so the below is able to determine if this
    #       update should be persisted (if the state is different)
    # NOTE: reminder, switch cmds operate at the switch device level,
    #       not individual switch states
    SwitchCmd.ack_if_needed(r)

    # as a sanity check be certain the number of reported states actually
    # matches the switch we intend to update
    case Enum.count(r.states) == Enum.count(sw.states) do
      true ->
        update_states_from_reading(sw, r)

        # always note that we've seen the switch and update the dev latency
        # if it is greater than 0
        opts = %{last_seen_at: TimeSupport.from_unix(r.mtime)}

        dev_latency_us = Map.get(r, :dev_latency_us, 0)

        opts =
          if dev_latency_us > 0,
            do: Map.put(opts, :dev_latency_us, dev_latency_us),
            else: opts

        change(sw, opts) |> update()

      false ->
        Logger.warn([
          inspect(sw.device, pretty: true),
          " number of states in reading does not match "
        ])

        {:error, sw}
    end
  end

  def update_last_cmd(%Switch{} = sw, %DateTime{} = dt) do
    # update the switch device last cmd timestamp
    from(
      s in Switch,
      update: [set: [last_cmd_at: ^dt]],
      where: s.id == ^sw.id
    )
    |> update_all([])
  end

  defp update_states_from_reading(%Switch{log: sw_log} = sw, %{} = r) do
    log = Map.get(r, :log, sw_log)

    for new <- r.states do
      # PIO numbers always start at zero they can be easily used as list index ids
      ss = Enum.at(sw.states, new.pio)

      # we only want to update the switch if the stored state does not match the
      # incoming update.  however, we must also take into account that the stored switch state
      # could be different while there are pending cmds
      if ss.state != new.state do
        pending = SwitchCmd.pending_cmds(sw)

        # if there aren't pending commands and the stored state doesn't match the
        # incoming state then we have a problem.  so, force an update.
        if pending == 0 do
          log &&
            Logger.warn([
              inspect(ss.name, pretty: true),
              " forcing to reported state ",
              inspect(new.state, pretty: true)
            ])

          log &&
            Logger.warn([
              "^^^ hint: the mcr device may have lost power and restarted"
            ])

          # ok, update the switch state -- it truly doesn't match
          change(ss, %{state: new.state}) |> update!()
        end
      end
    end
  end

  # defp possible_changes,
  #   do: [
  #     :name,
  #     :description,
  #     :device,
  #     :host,
  #     :duty,
  #     :duty_max,
  #     :duty_min,
  #     :dev_latency_us,
  #     :log,
  #     :ttl_ms,
  #     :reading_at,
  #     :last_seen_at,
  #     :metric_at,
  #     :metric_freq_secs,
  #     :discovered_at,
  #     :last_cmd_at
  #   ]
end
