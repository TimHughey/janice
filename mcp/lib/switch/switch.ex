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
  use Timex
  use Timex.Ecto.Timestamps
  use Ecto.Schema

  # import Application, only: [get_env: 2]
  import UUID, only: [uuid1: 0]
  import Ecto.Changeset, only: [change: 2]
  import Ecto.Query, only: [from: 2]
  import Repo, only: [all: 2, delete_all: 1, insert: 1, insert!: 1, one: 1, update: 1, update!: 1]

  alias Fact.RunMetric

  schema "switch" do
    field(:device, :string)
    field(:enabled, :boolean, default: true)
    field(:dev_latency, :integer)
    field(:discovered_at, Timex.Ecto.DateTime)
    field(:last_cmd_at, Timex.Ecto.DateTime)
    field(:last_seen_at, Timex.Ecto.DateTime)
    has_many(:states, SwitchState)
    has_many(:cmds, SwitchCmd)

    timestamps(usec: true)
  end

  def add([]), do: []

  def add([%Switch{} = sw | rest]) do
    [add(sw)] ++ add(rest)
  end

  def add(%Switch{device: device} = sw) do
    last_cmds =
      from(
        sc in SwitchCmd,
        group_by: sc.switch_id,
        select: %{switch_id: sc.switch_id, last_cmd_id: max(sc.id)}
      )

    q =
      from(
        sw in Switch,
        join: cmds in subquery(last_cmds),
        on: cmds.last_cmd_id == sw.id,
        join: states in assoc(sw, :states),
        where: sw.device == ^device,
        preload: [:states, :cmds]
      )

    case one(q) do
      nil ->
        ensure_states(sw) |> ensure_cmds() |> insert!()

      found ->
        Logger.warn(~s/[#{sw.device} already exists, skipping add]/)
        found
    end
  end

  def all(:everything) do
    last_cmds =
      from(
        sc in SwitchCmd,
        group_by: sc.switch_id,
        select: %{switch_id: sc.switch_id, last_cmd_id: max(sc.id)}
      )

    from(
      sw in Switch,
      join: cmds in subquery(last_cmds),
      on: cmds.last_cmd_id == sw.id,
      join: states in assoc(sw, :states),
      preload: [:states, :cmds]
    )
    |> all(timeout: 100)
  end

  def all(:devices) do
    from(sw in Switch, select: sw.device)
    |> all(timeout: 100)
  end

  def all(:names) do
    from(ss in SwitchState, order_by: [asc: ss.name], select: ss.name)
    |> all(timeout: 100)
  end

  def delete(id) when is_integer(id) do
    from(s in Switch, where: s.id == ^id)
    |> delete_all()
  end

  def delete(device) when is_binary(device) do
    from(s in Switch, where: s.device == ^device)
    |> delete_all()
  end

  def external_update(%{device: device} = r) do
    # Logger.metadata(switch_device: device)

    result =
      :timer.tc(fn ->
        sw = get_by_device(device)

        if sw == nil do
          %Switch{device: device, states: create_states(r), cmds: create_cmds(r)}
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
          val: t
        )

        :ok

      {_, {_, _}} ->
        Logger.warn(fn ->
          "external update failed for [#{device}]"
        end)

        :error
    end
  end

  # FLAGGED FOR REMOVAL
  # def states_updated(name, id) when is_integer(id) do
  # now = Timex.now()
  #
  # from(sw in Switch,
  #       update: [set: [last_cmd_at: ^now]],
  #       where: sw.id == ^id) |> update_all([])
  # end

  ##
  ## Internal / private functions
  ##

  defp create_cmds(%{}) do
    [%SwitchCmd{refid: uuid1(), acked: true, ack_at: Timex.now()}]
  end

  defp create_states(%{device: device, pio_count: pio_count})
       when is_binary(device) and is_integer(pio_count) do
    for pio <- 0..(pio_count - 1) do
      name = "#{device}:#{pio}"
      %SwitchState{name: name, pio: pio}
    end
  end

  defp ensure_cmds(%Switch{cmds: cmds} = sw) do
    if Ecto.assoc_loaded?(cmds) == false do
      Logger.info(fn -> "default acked cmd added for switch [#{sw.device}]" end)
      Map.put(sw, :cmds, create_cmds(%{}))
    else
      sw
    end
  end

  defp ensure_states(%Switch{states: states} = sw) do
    if Ecto.assoc_loaded?(states) == false do
      Logger.info(fn -> "default states added for switch [#{sw.device}]" end)
      Map.put(sw, :states, create_states(%{device: sw.device, pio_count: 2}))
    else
      sw
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
    # NOTE:  reminder, switch cmds operate a the switch device level, not individual
    #        switch states
    SwitchCmd.ack_if_needed(r)

    # as a sanity check be certain the number of reported states actually
    # matches the switch we intend to update
    case Enum.count(r.states) == Enum.count(sw.states) do
      true ->
        update_states_from_reading(sw, r)

        # always note that we've seen the switch and update the dev latency
        # if it is greater than 0
        opts = %{last_seen_at: Timex.from_unix(r.mtime)}

        opts =
          if r.latency > 0,
            do: Map.put(opts, :dev_latency, r.latency),
            else: opts

        change(sw, opts) |> update()

      false ->
        Logger.warn(fn ->
          "number of states in reading does not match switch [#{sw.device}]"
        end)

        {:error, sw}
    end
  end

  defp update_states_from_reading(%Switch{} = sw, %{} = r) do
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
          Logger.warn(fn ->
            "[#{ss.name}] forcing to reported state=#{inspect(new.state)}"
          end)

          Logger.warn(fn ->
            "^^^ hint: the mcr device may have lost power and restarted"
          end)

          # ok, update the switch state -- it truly doesn't match
          change(ss, %{state: new.state}) |> update!()
        end
      end
    end
  end
end
