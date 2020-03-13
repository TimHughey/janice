defmodule MessageSave do
  @moduledoc false

  require Logger
  use GenServer
  use Ecto.Schema
  use Timex

  import Application, only: [get_env: 3]

  import Ecto.Changeset,
    only: [
      cast: 3,
      validate_required: 2
    ]

  import Ecto.Query, only: [from: 2]
  import Repo, only: [one!: 1]

  import Janice.TimeSupport, only: [list_to_duration: 1, utc_shift: 1]

  alias Mqtt.Reading
  alias Timex.Format.Duration.Formatter, as: DurationFormat

  schema "message" do
    field(:direction, :string, null: false)
    field(:src_host, :string, null: false, default: " ")
    field(:msgpack, :binary, null: false)
    field(:json, :string, null: false, default: " ")
    field(:dropped, :boolean, null: false, default: false)
    field(:keep_for_testing, :boolean, null: false, default: false)

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

  def enable(val \\ :current)
      when is_boolean(val) or val in [:current, :toggle] do
    GenServer.call(MessageSave, {:enable, val})
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

  def init(%{autostart: autostart, opts: opts} = s) do
    log = Keyword.get(opts, :log, []) |> Keyword.get(:init, true)

    log &&
      Logger.info(["init() state: ", inspect(s, pretty: true)])

    delete_all = get_in(opts, [:purge, :all_at_startup])

    if autostart and delete_all == true,
      do: {:ok, s, {:continue, {:delete_all}}},
      else: {:ok, s}
  end

  def last_saved_msg do
    msg =
      from(ms in MessageSave, order_by: [desc: ms.inserted_at], limit: 1)
      |> Repo.all()
      |> hd()

    if is_nil(msg),
      do: [msg: nil, decoded: nil],
      else: [msg: msg, decoded: Reading.decode(Map.get(msg, :msgpack))]
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

  def handle_call({:enable, x}, _from, %{opts: opts} = s) do
    was = Keyword.get(opts, :save)

    case x do
      :current ->
        {:reply, {:ok, is: was}, s}

      :toggle ->
        is = not was

        {:reply, {:ok, was: was, is: is},
         Map.put(s, :opts, Keyword.put(opts, :save, is))}

      x when is_boolean(x) ->
        is = x

        {:reply, {:ok, was: was, is: is},
         Map.put(s, :opts, Keyword.put(opts, :save, is))}

      catchall ->
        {:reply, {:bad_arg, catchall}, s}
    end
  end

  def handle_cast(
        {@save_msg, direction, payload, dropped},
        %{opts: opts} = s
      )
      when is_list(opts) do
    opts = [dropped: dropped] ++ opts

    s =
      save_msg(s, direction, payload, opts)
      |> purge_msgs(opts)

    {:noreply, s}
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

  defp changes_possible,
    do: [:direction, :dropped, :json, :msgpack, :keep_for_testing, :src_host]

  defp changes_required,
    do: [:direction]

  defp changeset(x, params) when is_list(params),
    do: changeset(x, Enum.into(params, %{}))

  defp changeset(x, params) when is_map(params) do
    x
    |> cast(params, changes_possible())
    |> validate_required(changes_required())
  end

  defp insert_msg(s, %MessageSave{} = msg_save, opts) do
    cs = changeset(msg_save, opts)

    with {:cs_valid, true} <- {:cs_valid, cs.valid?()},
         {:ok, %MessageSave{id: _id}} = rc <- Repo.insert(cs) do
      Map.put(s, :last_msg_rc, rc)
    else
      {:cs_valid, false} ->
        Logger.warn(["save_msg() invalid changes: ", inspect(cs, pretty: true)])
        Map.put(s, :last_msg_rc, {:invalid_changes, cs})

      error ->
        Logger.warn(["save_msg() error: ", inspect(error, pretty: true)])
        Map.put(s, :last_msg_rc, {:error, error})
    end
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

  # should this message be saved?
  defp save_msg(s, direction, payload, opts) when is_list(opts) do
    if Keyword.get(opts, :save, false),
      do: save_msg(s, direction, payload, true, opts),
      else: s
  end

  # save JSON messages
  defp save_msg(
         s,
         direction,
         <<0x7B::utf8, _rest::binary>> = payload,
         true = _save,
         opts
       ) do
    opts = [direction: Atom.to_string(direction), json: payload] ++ opts

    insert_msg(s, %MessageSave{}, opts)
  end

  # save MsgPack messages
  defp save_msg(
         s,
         :in = direction,
         <<first_byte::size(1), _rest::bitstring>> = payload,
         true = _save,
         opts
       )
       # first byte isn't null and not '{'
       when first_byte > 0x00 and first_byte != 0x7B do
    opts =
      [direction: Atom.to_string(direction), msgpack: payload] ++
        opts

    with {:ok, msg_map} <- Reading.decode(payload),
         {:host, true, host} <-
           {:host, Map.has_key?(msg_map, :host), Map.get(msg_map, :host, false)} do
      opts = [src_host: host] ++ opts
      insert_msg(s, %MessageSave{}, opts)
    else
      _anything ->
        opts = [src_host: "<unknown>"] ++ opts
        insert_msg(s, %MessageSave{}, opts)
    end
  end

  defp save_msg(
         s,
         :out = direction,
         [first_byte | _rest] = payload,
         true = _save,
         opts
       )
       # first byte isn't null and not '{'
       when first_byte > 0x00 and first_byte != 0x7B do
    opts =
      [
        direction: Atom.to_string(direction),
        msgpack: IO.iodata_to_binary(payload),
        src_host: "<mcp>"
      ] ++ opts

    insert_msg(s, %MessageSave{}, opts)
  end

  defp save_msg(s, direction, payload, _save, _opts) do
    Logger.warn([
      "save_msg() dropping: ",
      inspect(direction),
      " ",
      inspect(payload, pretty: true)
    ])

    s
  end
end
