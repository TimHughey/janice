defmodule MessageSave do
  @moduledoc false

  require Logger
  use GenServer
  use Ecto.Schema
  use Timex

  import Application, only: [get_env: 3]
  import Ecto.Query, only: [from: 2]
  import Repo, only: [one!: 1, insert!: 1]

  import Janice.TimeSupport, only: [list_to_duration: 1, utc_shift: 1]

  alias Timex.Format.Duration.Formatter, as: DurationFormat

  schema "message" do
    field(:direction, :string)
    field(:payload, :string)
    field(:dropped, :boolean)

    timestamps(usec: true)
  end

  def delete(%MessageSave{} = ms), do: delete([ms])

  def delete(list) when is_list(list) do
    res =
      for %MessageSave{} = ms <- list do
        {rc, _} = Repo.delete(ms)
        rc
      end

    [
      deleted: Enum.count(res, fn x -> x == :ok end),
      failed: Enum.count(res, fn x -> x != :ok end)
    ]
  end

  def delete_all(:dangerous) do
    {elapsed, results} =
      Duration.measure(fn ->
        Repo.all(from(m in MessageSave, select: [:id])) |> delete()
      end)

    log_delete([prepend: "delete_all()", elapsed: elapsed] ++ results)
  end

  def message_count do
    from(ms in MessageSave, select: count(ms.id)) |> one!()
  end

  @runtime_opts_msg :runtime_opts_msg
  def runtime_opts, do: GenServer.call(MessageSave, {@runtime_opts_msg})

  @save_msg :save_msg
  def save(direction, payload, dropped \\ false)
      when direction in [:in, :out] do
    GenServer.cast(MessageSave, {@save_msg, direction, payload, dropped})
  end

  @set_save_msg :set_save_msg
  def set_save(val) when is_boolean(val) do
    GenServer.call(MessageSave, {@set_save_msg, val})
  end

  def init(%{autostart: autostart, opts: opts} = s) do
    log = Keyword.get(opts, :log, []) |> Keyword.get(:init, true)

    log &&
      Logger.info(["init() state: ", inspect(s, pretty: true)])

    delete_all = get_in(opts, [:purge, :all_at_startup])

    if autostart and delete_all == true,
      do: {:ok, s, {:continue, {:delete_all}}},
      else: {:ok, s}
  end

  def start_link(args) do
    defs = [
      save: false,
      purge: [all_at_startup: false, older_than: [hours: 12]]
    ]

    args =
      Map.merge(args, %{
        opts: get_env(:mcp, MessageSave, defs)
      })

    GenServer.start_link(MessageSave, args, name: MessageSave)
  end

  def terminate(reason, _state) do
    Logger.info(["terminating with reason ", inspect(reason, pretty: true)])
  end

  def handle_call({@runtime_opts_msg}, _from, %{opts: opts} = s),
    do: {:reply, opts, s}

  def handle_call({@set_save_msg, x}, _from, %{opts: opts} = s),
    do: {:reply, :ok, Map.put(s, :opts, Keyword.put(opts, :save, x))}

  def handle_cast(
        {@save_msg, direction, payload, dropped},
        %{opts: opts} = s
      )
      when is_list(opts) do
    {:noreply,
     save_msg(s, direction, payload, dropped, Keyword.get(opts, :save, true))
     |> purge_msgs(opts)}
  end

  def handle_cast(catchall, s) do
    Logger.warn(["handle_cast(catchall): ", inspect(catchall, pretty: true)])

    {:noreply, s}
  end

  def handle_continue({:delete_all}, s) do
    delete_all(:dangerous)
    {:noreply, s}
  end

  def handle_continue(catchall, s) do
    Logger.warn([
      "handle_continue(catchall): ",
      inspect(catchall, pretty: true)
    ])

    {:noreply, s}
  end

  defp calculate_next_purge(%{} = s, opts) do
    duration = list_to_duration(get_in(opts, [:purge, :older_than]))
    Map.put(s, :next_purge, utc_shift(duration))
  end

  defp log_delete(r) when is_list(r) do
    log =
      get_env(:mcp, MessageSave, purge: [log: false]) |> get_in([:purge, :log])

    prepend = Keyword.get(r, :prepend, "<unspecified>")
    deleted = Keyword.get(r, :deleted, 0)
    failed = Keyword.get(r, :failed, 0)

    if log == true and (deleted > 0 or failed > 0),
      do:
        Logger.info([
          prepend,
          " ",
          Integer.to_string(deleted),
          " messages deleted, ",
          Integer.to_string(failed),
          " failed in ",
          DurationFormat.format(
            Keyword.get(r, :elapsed, Duration.zero()),
            :humanized
          )
        ])

    r
  end

  # if the state contains the key :next_purge than a purge has been done
  # previously so use it decided if a purge should be done now
  defp purge_msgs(%{next_purge: next_purge} = s, opts) when is_list(opts) do
    older_than_opts = get_in(opts, [:purge, :older_than])

    before =
      list_to_duration(older_than_opts) |> Duration.invert() |> utc_shift()

    if Timex.after?(Timex.now(), next_purge) do
      {elapsed, results} =
        Duration.measure(fn ->
          Repo.all(
            from(ms in MessageSave,
              where: ms.inserted_at < ^before,
              select: [:id]
            )
          )
          |> delete()
        end)

      log_delete([prepend: "purge_msgs()", elapsed: elapsed] ++ results)

      calculate_next_purge(s, opts)
    else
      s
    end
  end

  # if the state does not contain the key :next_purge then a purge hasn't
  # occurred yet.  in this case (which should only occur once), calculate
  # and put :next_purge into the state
  defp purge_msgs(%{} = s, opts) when is_list(opts) do
    calculate_next_purge(s, opts)
  end

  defp save_msg(s, direction, payload, dropped, save) do
    if save == true,
      do:
        %MessageSave{
          direction: Atom.to_string(direction),
          payload: payload,
          dropped: dropped
        }
        |> insert!()

    s
  end
end
