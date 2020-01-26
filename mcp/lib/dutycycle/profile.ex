defmodule Dutycycle.Profile do
  @moduledoc false

  require Logger
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  import Repo, only: [get_by: 2, one: 1, update: 1]

  import Janice.Common.DB, only: [name_regex: 0]
  import Janice.TimeSupport, only: [ms: 1]

  alias Dutycycle.Profile

  schema "dutycycle_profile" do
    field(:name)
    field(:active, :boolean, default: false)
    field(:run_ms, :integer)
    field(:idle_ms, :integer)
    belongs_to(:dutycycle, Dutycycle)

    timestamps(usec: true)
  end

  def activate(%Dutycycle{} = dc, name) when is_binary(name) do
    with %Profile{name: next_name} = next_profile <- find(dc, name),
         %Profile{name: active_name} = active_profile <- active(dc),
         {:is_same, false} <- {:is_same, next_name === active_name},
         {:ok, _old} <- deactivate(active_profile),
         {:ok, next} <- activate(next_profile) do
      {:ok, next}
    else
      {:is_same, true} ->
        active(dc) |> activate()

      error ->
        Logger.warn(fn -> "activate failed: #{inspect(error, pretty: true)}" end)

        {:activate_profile_failed, error}
    end
  end

  def activate(%Profile{name: "none"} = p), do: {:none, p}
  def activate(name) when name === "none", do: {:none, %Profile{name: "none"}}
  def activate(%Profile{} = p), do: update_profile(p, active: true)

  def active(nil), do: nil

  def active(%Dutycycle{profiles: profiles}), do: active(profiles)

  def active([%Profile{} | _rest] = profiles) do
    active_profiles =
      for %Profile{active: active} = p <- profiles, active === true, do: p

    if Enum.empty?(active_profiles),
      do: %Profile{
        name: "none",
        run_ms: 0,
        idle_ms: 0,
        active: true
      },
      else: hd(active_profiles)
  end

  def active?(%Dutycycle{} = dc, profile) when is_binary(profile) do
    active_name = active(dc) |> name()
    if active_name == profile, do: true, else: false
  end

  def active?(%Dutycycle{} = dc, %Profile{name: name}) do
    active_name = active(dc) |> name()
    if name == active_name, do: true, else: false
  end

  def active?(%Profile{active: active}), do: active

  def add(%Dutycycle{} = d, %Profile{} = p) do
    Ecto.build_assoc(d, :profiles, p) |> Repo.insert!()
  end

  def as_map(list) when is_list(list) do
    for dcp <- list, do: as_map(dcp)
  end

  def as_map(%Dutycycle.Profile{} = dcp) do
    keys = [
      :id,
      :name,
      :active,
      :run_ms,
      :idle_ms,
      :updated_at
    ]

    Map.take(dcp, keys)
  end

  def change_properties(nil, _, _), do: %Dutycycle.Profile{}

  def change_properties(%Dutycycle{} = dc, profile_name, opts)
      when is_binary(profile_name) and is_list(opts) do
    from(
      dp in Dutycycle.Profile,
      where: dp.dutycycle_id == ^dc.id,
      where: dp.name == ^profile_name
    )
    |> one()
    |> change_properties(opts)
  end

  def change_properties(%Profile{} = p, opts) when is_list(opts) do
    opts = convert_change_properties_opts(opts)
    set = Keyword.take(opts, possible_changes()) |> Enum.into(%{})

    cs = changeset(p, set)

    if cs.valid? do
      update(cs)
    else
      {:invalid_changes, cs}
    end
  end

  def change_properties(nil, _opts), do: {:error, :not_found}

  def changeset(profile, params \\ %{}) do
    profile
    |> cast(params, possible_changes())
    |> validate_required(possible_changes())
    |> validate_number(:run_ms, greater_than_or_equal_to: 0)
    |> validate_number(:idle_ms, greater_than_or_equal_to: 0)
    |> validate_format(:name, name_regex())
    |> unique_constraint(:name,
      name: :dutycycle_profile_name_dutycycle_id_index
    )
  end

  def deactivate(%Profile{name: "none"} = p), do: {:ok, p}

  def deactivate(name) when name === "none",
    do: {:ok, %Profile{name: "none"}}

  def deactivate(%Profile{} = p), do: update_profile(p, active: false)

  def exists?(%Dutycycle{profiles: profiles}, name) when is_binary(name) do
    Enum.find_value(profiles, fn p -> name(p) === name end)
  end

  def find(%Dutycycle{profiles: profiles}, name) when is_binary(name) do
    found = Enum.find(profiles, fn p -> name(p) === name end)

    if is_nil(found), do: {:profile_not_found}, else: found
  end

  def name(name) when is_binary(name), do: name
  def name(%Profile{name: name}), do: name

  def none?(%Dutycycle{} = dc), do: active(dc) |> none?()
  def none?(%Profile{name: "none"}), do: true
  def none?(%Profile{}), do: false
  def none?("none"), do: true

  def phase_ms(%Dutycycle.Profile{idle_ms: ms}, :idle), do: ms
  def phase_ms(%Dutycycle.Profile{run_ms: ms}, :run), do: ms

  def update_profile(%Profile{id: id} = p, opts) when is_list(opts) do
    cs = changeset(p, Keyword.take(opts, possible_changes()) |> Enum.into(%{}))

    with {:cs_valid, true} <- {:cs_valid, cs.valid?()},
         {:ok, _profile} <- update(cs),
         %Profile{} = p <- get_by(Profile, id: id) do
      {:ok, p}
    else
      {:cs_valid, false} ->
        {:invalid_changes, cs}

      error ->
        Logger.warn(fn ->
          "update_profiles() failure: #{inspect(error, pretty: true)}"
        end)

        {:failed, error}
    end
  end

  defp possible_changes, do: [:name, :active, :run_ms, :idle_ms]

  defp convert_change_properties_opts(opts) when is_list(opts) do
    for opt <- opts do
      case opt do
        {:run, val} when is_tuple(val) -> {:run_ms, ms(val)}
        {:run, _} -> nil
        {:idle, val} when is_tuple(val) -> {:idle_ms, ms(val)}
        {:idle, _} -> nil
        _anything -> opt
      end
    end
  end
end
