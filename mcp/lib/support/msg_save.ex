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

  import Janice.TimeSupport,
    only: [duration: 1, humanize_duration: 1, utc_shift: 1]

  alias Mqtt.Reading

  schema "message" do
    field(:direction, :string, null: false)
    field(:src_host, :string, null: false, default: " ")
    field(:msgpack, :binary, null: false)
    field(:json, :string, null: false, default: " ")
    field(:dropped, :boolean, null: false, default: false)
    field(:keep_for_testing, :boolean, null: false, default: false)

    timestamps(usec: true)
  end

  def counts, do: :sys.get_state(MessageSave) |> Map.get(:counts, [])

  def delete(%MessageSave{} = ms), do: delete([ms])

  def delete(list) when is_list(list) do
    Janitor.empty_trash(list, mod: __MODULE__)
  end

  def delete_all(:dangerous) do
    Repo.all(from(m in MessageSave, select: [:id])) |> delete()
  end

  def init(%{opts: opts} = s) do
    log = Keyword.get(opts, :log, []) |> Keyword.get(:init, true)

    log &&
      Logger.info(["init() state: ", inspect(s, pretty: true)])

    delete_all = get_in(opts, [:purge, :all_at_startup])

    if Map.get(s, :autostart, true) and delete_all == true,
      do: {:ok, s, {:continue, {:delete_all}}},
      else: {:ok, s}
  end

  def last_saved_msg(opts \\ []) when is_list(opts) do
    limit = Keyword.get(opts, :limit, 1)
    only_decoded = Keyword.get(opts, :only_decoded, true)

    msgs =
      from(ms in MessageSave, order_by: [desc: ms.inserted_at], limit: ^limit)
      |> Repo.all()

    cond do
      Enum.empty?(msgs) ->
        [msg: nil, decoded: nil]

      only_decoded ->
        for x <- decode_msgs(msgs) do
          Map.get(x, :decoded, %{})
        end

      true ->
        decode_msgs(msgs)
    end
  end

  def message_count do
    from(ms in MessageSave, select: count(ms.id)) |> one!()
  end

  def opts, do: :sys.get_state(__MODULE__) |> Map.get(:opts, [])

  def opts(new_opts) when is_list(new_opts) do
    GenServer.call(MessageSave, %{
      action: :update_opts,
      opts: new_opts
    })
  end

  def save(%{direction: direction, payload: _} = msg)
      when direction in [:in, :out] do
    GenServer.cast(MessageSave, Map.put(msg, :action, :save_msg))

    msg
  end

  def start_link(args) do
    defs = [
      forward: false,
      forward_opts: [in: [feed: {"dev/mcr/f/report", 0}]],
      save: false,
      save_opts: [],
      purge: [all_at_startup: false, older_than: [hours: 12]]
    ]

    args =
      Map.merge(args, %{
        opts: get_env(:mcp, MessageSave, defs),
        inflight: %{},
        counts: [deleted: 0, saved: 0, forwarded: 0]
      })

    GenServer.start_link(MessageSave, args, name: MessageSave)
  end

  def terminate(reason, _state) do
    Logger.info(["terminating with reason ", inspect(reason, pretty: true)])
  end

  def handle_call(
        %{action: :update_opts, opts: new_opts},
        _from,
        %{opts: opts} = s
      ) do
    keys_to_return = Keyword.keys(new_opts)
    new_opts = DeepMerge.deep_merge(opts, new_opts)

    was_rc = Keyword.take(opts, keys_to_return)
    is_rc = Keyword.take(new_opts, keys_to_return)

    {:reply, {:ok, [was: was_rc, is: is_rc]}, %{s | opts: new_opts}}
  end

  def handle_cast(%{action: :save_msg} = msg, %{opts: opts} = s) do
    inflight =
      msg
      |> Map.put(:save, Keyword.get(opts, :save, false))
      |> Map.put(:forward, Keyword.get(opts, :forward, false))
      |> Map.put(:opts, opts)

    {:noreply,
     Map.put(s, :inflight, inflight)
     |> save_msg()
     |> forward_msg()
     |> purge_msgs()}
  end

  # handle msessages that Janitor sends after emptying trash (delete)
  def handle_cast({:trash, _mod, elapsed, results}, %{opts: opts} = s) do
    log = get_in(opts, [:purge, :log]) && true
    count = length(results)
    plural = if count > 1, do: "s", else: ""

    log && count > 0 &&
      Logger.info([
        "purged ",
        inspect(count),
        " message",
        plural,
        " in ",
        humanize_duration(elapsed)
      ])

    {:noreply, increment_counts(s, [:deleted], length(results))}
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

  def handle_info(catchall, %{} = s) do
    Logger.info(["handle_info(catchall): ", inspect(catchall, pretty: true)])

    {:noreply, s}
  end

  defp calculate_next_purge(%{opts: opts} = s) do
    Map.put(
      s,
      :next_purge,
      get_in(opts, [:purge, :older_than]) |> duration() |> utc_shift()
    )
  end

  defp changes_possible,
    do: [:direction, :dropped, :json, :msgpack, :keep_for_testing, :src_host]

  defp changes_required,
    do: [:direction]

  defp changeset(x, params) when is_list(params),
    do: changeset(x, Enum.into(params, %{}))

  defp changeset(x, %{direction: direction} = params) do
    params = Map.put(params, :direction, Atom.to_string(direction))

    x
    |> cast(params, changes_possible())
    |> validate_required(changes_required())
  end

  def decode_msgs([%MessageSave{} | _rest] = msgs) do
    for %MessageSave{msgpack: msg} <- msgs do
      {rc, map} = Msgpax.unpack(msg)

      if rc == :ok,
        do: %{msg: msg, decoded: Reading.atomize_keys(map)},
        else: %{msg: msg, decoded: %{}}
    end
  end

  def decode_msgs(_anything), do: []

  defp forward_msg(
         %{inflight: %{forward: true, direction: :in, opts: _opts} = inflight} =
           s
       ) do
    Map.put(s, :last_forward_rc, Mqtt.Client.forward(inflight))
    |> increment_counts([:forwarded])
  end

  # forward_msg/1:
  #  -forward criteria did not match
  #  -simply pass through the state
  defp forward_msg(%{inflight: _inflight} = s) do
    Map.put(s, :last_forward_rc, {:skipped})
  end

  defp increment_counts(%{counts: counts} = state, inc_list, count \\ 1)
       when is_list(counts) and is_list(inc_list) and is_integer(count) do
    to_increment = Keyword.take(counts, inc_list)

    inc_fn = fn
      {k, _v}, acc ->
        Keyword.put(acc, k, Keyword.get(acc, k, 0) + count)
    end

    new_counts = Enum.reduce(to_increment, counts, inc_fn)

    Map.put(state, :counts, Keyword.merge(counts, new_counts))
  end

  defp insert_msg(%{inflight: inflight} = s) do
    cs = changeset(%MessageSave{}, inflight)

    with {:cs_valid, true} <- {:cs_valid, cs.valid?()},
         {:ok, %MessageSave{id: _id}} = rc <- Repo.insert(cs) do
      Map.put(s, :last_insert_msg_rc, rc) |> increment_counts([:saved])
    else
      {:cs_valid, false} ->
        Logger.warn([
          "insert_msg() invalid changes: ",
          inspect(cs, pretty: true)
        ])

        Map.put(s, :last_insert_msg_rc, {:invalid_changes, cs})

      error ->
        Logger.warn(["insert_msg() error: ", inspect(error, pretty: true)])
        Map.put(s, :last_insert_msg_rc, {:error, error})
    end
  end

  # if the state contains the key :next_purge than a purge has been done
  # previously so use it decided if a purge should be done now
  defp purge_msgs(%{next_purge: next_purge, opts: opts} = s) do
    older_than_opts = get_in(opts, [:purge, :older_than])

    before = duration(older_than_opts) |> Duration.invert() |> utc_shift()

    if Timex.after?(Timex.now(), next_purge) do
      Repo.all(
        from(ms in MessageSave,
          where: ms.inserted_at < ^before,
          select: [:id]
        )
      )
      |> delete()

      calculate_next_purge(s)
    else
      s
    end
  end

  # if the state does not contain the key :next_purge then a purge hasn't
  # occurred yet.  in this case (which should only occur once), calculate
  # and put :next_purge into the state
  defp purge_msgs(%{opts: _opts} = s) do
    calculate_next_purge(s)
  end

  # save JSON messages
  defp save_msg(
         %{
           inflight:
             %{
               direction: direction,
               payload: <<0x7B::utf8, _rest::binary>> = payload,
               save: true,
               opts: _opts
             } = inflight
         } = s
       )
       when direction == :in do
    # populate the json key of inflight with the payload
    %{s | inflight: Map.put(inflight, :json, payload)}
    |> insert_msg()
  end

  # save MsgPack messages
  defp save_msg(
         %{
           inflight:
             %{
               direction: direction,
               payload: <<first_byte::size(1), _rest::bitstring>> = payload,
               save: true,
               opts: _opts
             } = inflight
         } = s
       )
       # first byte isn't null and not '{'
       when direction == :in and first_byte > 0x00 and first_byte != 0x7B do
    inflight = Map.put(inflight, :msgpack, payload)

    with {:ok, msg_map} <- Reading.decode(payload),
         host when is_binary(host) <-
           Map.get(msg_map, :host, "<undefined>"),
         inflight <- Map.put(inflight, :src_host, host) do
      Map.put(s, :inflight, inflight)
    else
      _anything ->
        inflight = Map.put(inflight, :src_host, "<bad msg>")
        Map.put(s, :inflight, inflight)
    end
    |> insert_msg()
  end

  defp save_msg(
         %{
           inflight:
             %{
               direction: direction,
               payload: [first_byte | _rest] = payload,
               save: true,
               opts: _opts
             } = inflight
         } = s
       )
       # first byte isn't null and not '{'
       when direction == :out and first_byte > 0x00 and first_byte != 0x7B do
    %{
      s
      | inflight:
          Map.merge(inflight, %{
            msgpack: IO.iodata_to_binary(payload),
            src_host: "<mcp>"
          })
    }
    |> insert_msg()
  end

  # save is false, quietly just return the state
  defp save_msg(%{inflight: %{save: false}} = s), do: s

  defp save_msg(%{inflight: inflight} = s) do
    Logger.warn([
      "save_msg() dropping: ",
      inspect(inflight, pretty: true)
    ])

    s
  end
end
