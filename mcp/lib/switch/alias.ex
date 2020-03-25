defmodule Switch.Alias do
  @moduledoc false

  require Logger
  use Ecto.Schema

  import Ecto.Changeset,
    only: [
      cast: 3,
      cast_embed: 3,
      validate_required: 2,
      validate_format: 3,
      validate_number: 3,
      unique_constraint: 3
    ]

  import Janice.Common.DB, only: [name_regex: 0]

  # alias Janice.TimeSupport
  alias Switch.{Alias, Device}

  @timestamps_opts [type: :utc_datetime_usec]

  schema "switch_alias" do
    field(:name, :string)
    field(:device_id, :integer)
    field(:description, :string, default: "<none>")
    field(:pio, :integer)
    field(:invert_state, :boolean, default: false)
    field(:ttl_ms, :integer, default: 60_000)

    embeds_one :log_opts, LogOpts do
      field(:log, :boolean, default: false)
      field(:external_update, :boolean, default: false)
      field(:cmd_rt, :boolean, default: false)
      field(:dev_latency, :boolean, default: false)
    end

    belongs_to(:device, Switch.Device,
      source: :device_id,
      references: :id,
      foreign_key: :device_id,
      define_field: false
    )

    timestamps()
  end

  def create(%Device{id: id}, name, pio, opts \\ [])
      when is_binary(name) and is_integer(pio) and pio >= 0 and is_list(opts) do
    #
    # grab keys of interest for the schema (if they exist) and populate the
    # required parameters from the function call
    #
    Keyword.take(opts, [:description, :invert_state, :ttl_ms])
    |> Enum.into(%{})
    |> Map.merge(%{device_id: id, name: name, pio: pio, device_checked: true})
    |> upsert()
  end

  def find(x, opts \\ [preload: true])

  def find(id, opts) when is_integer(id) and is_list(opts),
    do: Repo.get_by(__MODULE__, id: id) |> preload(opts)

  def find(name, opts) when is_binary(name) and is_list(opts),
    do: Repo.get_by(__MODULE__, name: name) |> preload(opts)

  def position(name, opts \\ [])

  def position(name, opts) when is_binary(name) and is_list(opts) do
    sa = find(name)

    if is_nil(sa), do: {:not_found, name}, else: position(sa, opts)
  end

  def position(%Alias{pio: pio, device: %Device{} = sd} = sa, opts)
      when is_list(opts) do
    lazy = Keyword.get(opts, :lazy, true)
    position = Keyword.get(opts, :position, nil)
    cmd_map = %{pio: pio, state: position, initial_opts: opts}

    with {:ok, curr_position} <- Device.pio_state(sd, pio),
         # if the position opt was passed then an update is requested
         {:position, {:opt, true}} <-
           {:position, {:opt, is_boolean(position)}},

         # the most typical scenario... lazy is true and current position
         # does not match the requsted position
         {:lazy, true, false} <-
           {:lazy, lazy, position == curr_position} do
      # the requested position does not match the current posiion so
      # call Device.record_cmd/2 to publish the cmd to the mcr remote
      Device.record_cmd(sd, sa, cmd_map: cmd_map)
    else
      {:position, {:opt, false}} ->
        # position change not included in opts, just return current position
        Device.pio_state(sd, pio, opts)

      {:lazy, true, true} ->
        # requested lazy and requested position matches current position
        # nothing to do here... just return the position
        Device.pio_state(sd, pio, opts)

      {:lazy, _lazy_or_not, _true_or_false} ->
        # regardless if lazy or not the current position does not match
        # the requested position so change the position
        Device.record_cmd(sd, sa, cmd_map: cmd_map)
    end
    |> invert_position_if_needed(sa)
  end

  def preload(sa, opts \\ [preload: true])

  def preload(%Alias{} = sa, opts) when is_list(opts) do
    if Keyword.get(opts, :preload, false),
      do: Repo.preload(sa, [:device]),
      else: sa
  end

  def preload(anything, _opts), do: anything

  def rename(name, opts) when is_binary(name) and is_list(opts) do
    sa = find(name, opts)

    if is_nil(sa),
      do: {:not_found, name},
      else: rename(sa, opts)
  end

  def rename(%Alias{log_opts: log_opts} = x, opts) when is_list(opts) do
    name = Keyword.get(opts, :name)

    changes =
      Keyword.take(opts, [
        :name,
        :description,
        :ttl_ms,
        :invert_state,
        :log_opts
      ])
      |> Enum.into(%{})

    changes =
      if Map.has_key?(changes, :log_opts) do
        x = Map.get(changes, :log_opts) |> Enum.into(%{})
        new_log_opts = Map.merge(Map.from_struct(log_opts), x)
        %{changes | log_opts: new_log_opts}
      else
        changes
      end

    with {:args, true} <- {:args, is_binary(name)},
         cs <- changeset(x, changes),
         {cs, true} <- {cs, cs.valid?},
         {:ok, sa} <- Repo.update(cs, returning: true) do
      {:ok, sa}
    else
      {:args, false} -> {:bad_args, opts}
      {%Ecto.Changeset{} = cs, false} -> {:invalid_changes, cs}
      error -> error
    end
  end

  def update(name, opts) when is_binary(name) and is_list(opts) do
    sa = find(name, opts)

    if is_nil(sa),
      do: {:not_found, name},
      else: rename(sa, [name: name] ++ opts)
  end

  # upsert/1 confirms the minimum keys required and if the device to alias
  # exists
  def upsert(%{name: _, device_id: _, pio: _} = m) do
    upsert(%Alias{}, Map.put(m, :device_checked, true))
  end

  def upsert(catchall) do
    Logger.warn(["upsert/1 bad args: ", inspect(catchall, pretty: true)])
    {:bad_args, catchall}
  end

  # Alias.upsert/2 will update (or insert) an %Alias{} using the map passed in
  def upsert(
        %Alias{} = x,
        %{device_checked: true, name: _, device_id: _, pio: _pio} = params
      ) do
    cs = changeset(x, Map.take(params, possible_changes()))

    replace_cols = [
      :description,
      :device_id,
      :pio,
      :invert_state,
      :ttl_ms,
      :updated_at
    ]

    with {:cs_valid, true} <- {:cs_valid, cs.valid?()},
         # the keys on_conflict: and conflict_target: indicate the insert
         # is an "upsert"
         {:ok, %Alias{id: _id} = x} <-
           Repo.insert(cs,
             on_conflict: {:replace, replace_cols},
             returning: true,
             conflict_target: [:name]
           ) do
      {:ok, x}
    else
      {:cs_valid, false} ->
        {:invalid_changes, cs}

      {:error, rc} ->
        {:error, rc}

      error ->
        error
    end
    |> check_result(x, __ENV__)
  end

  def upsert(
        %Alias{},
        %{
          device_checked: false,
          name: _,
          device: device,
          device_id: _device_id,
          pio: pio
        }
      ),
      do: {:device_not_found, {device, pio}}

  #
  # PRIVATE
  #

  defp caller(%{function: {func, arity}}),
    do: [Atom.to_string(func), "/", Integer.to_string(arity)]

  defp changeset(x, params) when is_list(params) do
    changeset(x, Enum.into(params, %{}))
  end

  defp changeset(x, params) when is_map(params) do
    x
    |> ensure_log_opts()
    |> cast(params, cast_changes())
    |> cast_embed(:log_opts,
      with: &log_opts_changeset/2,
      required: true
    )
    |> validate_required(possible_changes())
    |> validate_format(:name, name_regex())
    |> validate_number(:pio,
      greater_than_or_equal_to: 0
    )
    |> validate_number(:ttl_ms,
      greater_than_or_equal_to: 0
    )
    |> unique_constraint(:name, [:name])
  end

  defp check_result(res, x, env) do
    case res do
      # all is well, simply return the res
      {:ok, %Alias{}} ->
        true

      {:invalid_changes, cs} ->
        Logger.warn([
          caller(env),
          " invalid changes: ",
          inspect(cs, pretty: true)
        ])

      {:error, rc} ->
        Logger.warn([
          caller(env),
          " failed rc: ",
          inspect(rc, pretty: true),
          " for: ",
          inspect(x, pretty: true)
        ])

      true ->
        Logger.warn([
          caller(env),
          " error: ",
          inspect(res, pretty: true),
          " for: ",
          inspect(x, pretty: true)
        ])
    end

    res
  end

  defp ensure_log_opts(%Alias{log_opts: rtm} = x) do
    if is_nil(rtm),
      do: Map.put(x, :log_opts, %Alias.LogOpts{}),
      else: x
  end

  #
  # Invert Position (if required)

  # handle the scenario of pure or paritial success
  defp invert_position_if_needed(
         {rc, position},
         %Alias{
           invert_state: true
         }
       )
       when rc in [:ok, :ttl_expired],
       do: not position

  # handle error or unsuccesful position results by simply passing
  # through the result
  defp invert_position_if_needed(result, _sa),
    do: result

  # defp invert_position_if_needed(position, %SwitchState{
  #        invert_state: true
  #      })
  #      when is_boolean(position),
  #      do: not position
  #
  # defp invert_position_if_needed(position, %SwitchState{
  #        invert_state: false
  #      })
  #      when is_boolean(position),
  #      do: position

  #
  # Changeset Functions
  #

  defp log_opts_changeset(schema, params) when is_list(params) do
    log_opts_changeset(schema, Enum.into(params, %{}))
  end

  defp log_opts_changeset(schema, params) when is_map(params) do
    schema
    |> cast(params, [:log, :external_update, :cmd_rt, :dev_latency])
  end

  #
  # Changeset Lists
  #

  defp cast_changes,
    do: [
      :name,
      :description,
      :device_id,
      :pio,
      :invert_state,
      :ttl_ms
    ]

  defp possible_changes,
    do: [
      :name,
      :description,
      :device_id,
      :pio,
      :invert_state,
      :ttl_ms
    ]
end
