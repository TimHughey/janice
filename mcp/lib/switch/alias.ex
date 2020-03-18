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

  import Ecto.Query, only: [from: 2]
  import Janice.Common.DB, only: [name_regex: 0]

  # alias Janice.TimeSupport
  alias __MODULE__
  alias Switch.Device

  @timestamps_opts [type: :utc_datetime_usec]

  schema "switch_alias" do
    field(:name, :string)
    field(:description, :string, default: "<none>")
    field(:device, :string)
    field(:pio, :integer)
    field(:invert_state, :boolean, default: false)
    field(:ttl_ms, :integer, default: 60_000)

    embeds_one :log_opts, LogOpts do
      field(:log, :boolean, default: false)
      field(:external_update, :boolean, default: false)
      field(:cmd_rt, :boolean, default: false)
      field(:dev_latency, :boolean, default: false)
    end

    timestamps()
  end

  def delete_all(:dangerous) do
    for x <- from(y in __MODULE__, select: [:id]) |> Repo.all() do
      Repo.delete(x)
    end
  end

  def find(id) when is_integer(id),
    do: Repo.get_by(__MODULE__, id: id)

  def find(name) when is_binary(name),
    do: Repo.get_by(__MODULE__, name: name)

  def find_by_device(device) when is_binary(device),
    do: Repo.get_by(__MODULE__, device: device)

  def upsert(l) when is_list(l), do: upsert(Enum.into(l, %{}))

  # upsert/1 confirms the minimum keys required and if the device to alias
  # exists
  def upsert(%{name: _, device: device, pio: pio} = m) do
    upsert(%Alias{}, Map.put(m, :device_checked, Device.exists?(device, pio)))
  end

  def upsert(catchall) do
    Logger.warn(["upsert/1 bad args: ", inspect(catchall, pretty: true)])
    {:bad_args, catchall}
  end

  # Alias.upsert/2 will update (or insert) an %Alias{} using the map passed in
  def upsert(
        %Alias{} = x,
        %{device_checked: true, name: _, device: _, pio: _pio} = params
      ) do
    cs = changeset(x, Map.take(params, possible_changes()))

    replace_cols = [
      :description,
      :device,
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
        %{device_checked: false, name: _, device: device, pio: pio}
      ),
      do: {:device_not_found, {device, pio}}

  #
  # PRIVATE
  #

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
    |> validate_format(:device, name_regex())
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

  defp caller(%{function: {func, arity}}),
    do: [Atom.to_string(func), "/", Integer.to_string(arity)]

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
      :device,
      :pio,
      :invert_state,
      :ttl_ms
    ]

  defp possible_changes,
    do: [
      :name,
      :description,
      :device,
      :pio,
      :invert_state,
      :ttl_ms
    ]
end
