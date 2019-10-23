defmodule Dutycycle.Profile do
  @moduledoc false

  require Logger
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  import Repo, only: [one: 1, update: 1, update_all: 2]

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
    from(
      dp in Dutycycle.Profile,
      where: dp.dutycycle_id == ^dc.id,
      where: dp.active == true,
      update: [set: [active: false]]
    )
    |> update_all([])

    from(
      dp in Dutycycle.Profile,
      where: dp.dutycycle_id == ^dc.id,
      where: dp.name == ^name,
      update: [set: [active: true]]
    )
    |> update_all([])
  end

  def active(nil), do: nil

  def active(%Dutycycle{} = d), do: active(d.profiles)

  def active([%Profile{} | _rest] = profiles) do
    active = for p <- profiles, p.active, do: p

    if Enum.empty?(active), do: :none, else: hd(active)
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
    set = Keyword.take(opts, [:run_ms, :idle_ms, :name]) |> Enum.into(%{})

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
    |> cast(params, [:name, :run_ms, :idle_ms])
    |> validate_required([:name, :run_ms, :idle_ms])
    |> validate_number(:run_ms, greater_than_or_equal_to: 0)
    |> validate_number(:idle_ms, greater_than_or_equal_to: 0)
    |> validate_format(:name, name_regex())
    |> unique_constraint(:name,
      name: :dutycycle_profile_name_dutycycle_id_index
    )
  end

  def name(%Profile{name: name}), do: name

  def phase_ms(%Dutycycle.Profile{idle_ms: ms}, :idle), do: ms
  def phase_ms(%Dutycycle.Profile{run_ms: ms}, :run), do: ms

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
