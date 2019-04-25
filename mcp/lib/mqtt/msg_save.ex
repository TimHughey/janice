defmodule MessageSave do
  @moduledoc false

  require Logger
  use GenServer
  use Ecto.Schema

  import Application, only: [get_env: 3]
  import Process, only: [send_after: 3]
  import Ecto.Query, only: [from: 2]
  import Repo, only: [one!: 1, insert!: 1]

  alias Janice.TimeSupport

  schema "message" do
    field(:direction, :string)
    field(:payload, :string)
    field(:dropped, :boolean)

    timestamps(usec: true)
  end

  def delete_all(:dangerous), do: from(m in MessageSave, where: m.id > 0) |> Repo.delete_all()

  def message_count do
    from(ms in MessageSave, select: count(ms.id)) |> one!()
  end

  @runtime_opts_msg :runtime_opts_msg
  def runtime_opts, do: GenServer.call(MessageSave, {@runtime_opts_msg})

  @save_msg :save_msg
  def save(direction, payload, dropped \\ false) when direction in [:in, :out] do
    GenServer.cast(MessageSave, {@save_msg, direction, payload, dropped})
  end

  @set_save_msg :set_save_msg
  def set_save(val) when is_boolean(val) do
    GenServer.call(MessageSave, {@set_save_msg, val})
  end

  @startup_msg {:startup}
  def init(s) when is_map(s) do
    if s.autostart, do: send_after(self(), @startup_msg, 0)
    Logger.info(fn -> "init()" end)

    {:ok, s}
  end

  def start_link(args) do
    defs = [save: false, delete: [all_at_startup: false, older_than_hrs: 12]]
    opts = get_env(:mcp, MessageSave, defs)

    if get_in(opts, [:delete, :all_at_startup]), do: delete_all(:dangerous)

    s = Map.put(args, :opts, opts)
    GenServer.start_link(MessageSave, s, name: MessageSave)
  end

  def terminate(reason, _state) do
    Logger.info(fn -> "terminating with reason #{inspect(reason)}" end)
  end

  def handle_call({@runtime_opts_msg}, _from, s) do
    {:reply, s.opts, s}
  end

  def handle_call({@set_save_msg, val}, _from, s) do
    new_opts = Map.put(s.opts, :save, val)
    s = Map.put(s, :opts, new_opts)
    {:reply, :ok, s}
  end

  def handle_cast({@save_msg, direction, payload, dropped}, %{opts: [:save]} = s) do
    %MessageSave{direction: Atom.to_string(direction), payload: payload, dropped: dropped}
    |> insert!()

    older_than_hrs = get_in(s.opts, [:delete, :older_than_hrs]) * -1

    older_dt = TimeSupport.utc_now() |> Timex.shift(hours: older_than_hrs)

    from(ms in MessageSave, where: ms.inserted_at < ^older_dt)
    |> Repo.delete_all()

    {:noreply, s}
  end

  def handle_cast({@save_msg, _direction, _payload, _dropped}, %{opts: _opts} = s) do
    {:noreply, s}
  end

  def handle_info(@startup_msg, s) do
    opts = Map.get(s, :opts)
    Logger.info(fn -> "startup(), opts: #{inspect(opts)}" end)

    {:noreply, s}
  end
end
