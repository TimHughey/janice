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

  def counts, do: :sys.get_state(MessageSave) |> Map.get(:counts, [])

  def delete(%MessageSave{} = ms), do: delete([ms])

  def delete(list) when is_list(list) do
    for %MessageSave{} = ms <- list do
      GenServer.cast(MessageSave, %{action: :delete, msg: ms})
    end
  end

  def delete_all(:dangerous) do
    {elapsed, results} =
      Duration.measure(fn ->
        Repo.all(from(m in MessageSave, select: [:id])) |> delete()
      end)

    log_delete(prepend: "delete_all()", elapsed: elapsed, deleted: results)
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

  def last_saved_msg(opts \\ []) when is_list(opts) do
    limit = Keyword.get(opts, :limit, 1)
    only_decoded = Keyword.get(opts, :only_decoded, true)
    payload_type = Keyword.get(opts, :payload_type, :msgpack)

    msgs =
      from(ms in MessageSave, order_by: [desc: ms.inserted_at], limit: ^limit)
      |> Repo.all()

    cond do
      Enum.empty?(msgs) ->
        [msg: nil, decoded: nil]

      only_decoded ->
        for x <- msgs, do: Reading.decode(Map.get(x, payload_type))

      true ->
        for x <- msgs,
            do: %{msg: x, decoded: Reading.decode(Map.get(x, :msgpack))}
    end
  end

  def message_count do
    from(ms in MessageSave, select: count(ms.id)) |> one!()
  end

  def opts, do: :sys.get_state(MessageSave) |> Map.get(:opts, [])

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
      save: false,
      purge: [all_at_startup: false, older_than: [hours: 12]],
      forward: []
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
    new_opts = DeepMerge.deep_merge(opts, new_opts)

    {:reply, {:ok, [was: opts, is: new_opts]}, %{s | opts: new_opts}}
  end

  def handle_cast(%{action: :save_msg} = msg, %{opts: opts} = s) do
    inflight =
      msg
      |> Map.put(:save, Keyword.get(opts, :save, false))
      |> Map.put(:forward, length(Keyword.get(opts, :forward, [])) > 0)
      |> Map.put(:opts, opts)

    #
    # Logger.info([
    #   ":save_msg msg: ",
    #   inspect(msg, pretty: true),
    #   " inflight: ",
    #   inspect(inflight, pretty: true),
    #   " s: ",
    #   inspect(s, pretty: true)
    # ])

    {:noreply,
     Map.put(s, :inflight, inflight)
     |> save_msg()
     |> forward_msg()
     |> purge_msgs()}
  end

  def handle_cast(
        %{action: :delete, msg: %MessageSave{} = ms},
        %{opts: _opts} = s
      ) do
    # function to check the result of Repo.delete/1 and increment the
    # delete counted if successful
    inc_if_ok = fn
      {:ok, _res} -> increment_counts(s, [:deleted])
      {_rc, _res} -> s
    end

    {:noreply, inc_if_ok.(Repo.delete(ms))}
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

  defp calculate_next_purge(%{opts: opts} = s) do
    duration = list_to_duration(get_in(opts, [:purge, :older_than]))
    Map.put(s, :next_purge, utc_shift(duration))
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

  defp increment_counts(%{counts: counts} = state, inc_list)
       when is_list(counts) and is_list(inc_list) do
    to_increment = Keyword.take(counts, inc_list)

    inc_fn = fn
      {k, _v}, acc ->
        Keyword.put(acc, k, Keyword.get(acc, k, 0) + 1)
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

  defp log_delete(r) when is_list(r) do
    log =
      get_env(:mcp, MessageSave, purge: [log: false]) |> get_in([:purge, :log])

    prepend = Keyword.get(r, :prepend, "<unspecified>")
    deleted = Keyword.get(r, :deleted, []) |> length()

    if log == true and deleted > 0,
      do:
        Logger.info([
          prepend,
          " queued ",
          Integer.to_string(deleted),
          " messages for delete in ",
          DurationFormat.format(
            Keyword.get(r, :elapsed, Duration.zero()),
            :humanized
          )
        ])

    r
  end

  # if the state contains the key :next_purge than a purge has been done
  # previously so use it decided if a purge should be done now
  defp purge_msgs(%{next_purge: next_purge, opts: opts} = s) do
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

      log_delete(prepend: "purge_msgs()", elapsed: elapsed, deleted: results)

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
    with {:ok, msg_map} <- Reading.decode(payload),
         {host} when is_binary(host) <- {Map.get(msg_map, :host)} do
      %{s | inflight: Map.put(inflight, :src_host, host)}
    else
      _anything ->
        %{s | inflight: Map.put(inflight, :src_host, "<unknown>")}
    end
    |> Map.put(:msgpack, payload)
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
