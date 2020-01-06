defmodule Thermostat.Profile do
  @moduledoc false

  require Logger
  use Ecto.Schema

  import Ecto.Changeset, only: [change: 2]
  # import Repo, only: [one: 1, update!: 1]
  # import Ecto.Query, only: [from: 2]

  alias Thermostat.Profile

  schema "thermostat_profile" do
    field(:name)
    field(:low_offset, :float)
    field(:high_offset, :float)
    field(:check_ms, :integer)

    field(:ref_sensor)
    field(:ref_offset, :float)

    field(:fixed_setpt, :float)

    belongs_to(:thermostat, Thermostat)

    timestamps()
  end

  def active(%Thermostat{} = t) do
    if is_nil(t.active_profile), do: :none, else: find_profile(t)
  end

  def add(%Thermostat{} = t, %Profile{} = p) do
    Ecto.build_assoc(t, :profiles, p) |> Repo.insert!()
  end

  def check_ms(%Profile{} = p), do: p.check_ms

  def ensure_standby_profile_exists(%Thermostat{} = t) do
    if known?(t, "standby") do
      t
    else
      Ecto.build_assoc(t, :profiles, name: "standby") |> Repo.insert!()
      Repo.preload(t, :profiles)
    end
  end

  def find_profile(%Thermostat{
        active_profile: active_profile,
        profiles: profiles
      }) do
    found = for p <- profiles, active_profile === p.name, do: p

    if is_list(found), do: hd(found), else: :none
  end

  def get_profile(%Thermostat{profiles: profiles}, name) when is_binary(name) do
    found = for p <- profiles, p.name === name, do: p

    if is_list(found) and not Enum.empty?(found),
      do: hd(found),
      else: :unknown_profile
  end

  def known?(%Thermostat{} = t, profile) when is_binary(profile) do
    known = for p <- t.profiles, do: p.name
    profile in known
  end

  def names(%Thermostat{} = t), do: for(p <- t.profiles, do: p.name)

  def set_point(%Thermostat{} = t) do
    active(t) |> set_point()
  end

  def set_point(%Profile{} = profile) do
    if is_nil(profile.ref_sensor) do
      profile.fixed_setpt
    else
      Sensor.fahrenheit(name: profile.ref_sensor, since_secs: 90)
    end
  end

  def update(%Thermostat{} = t, %{name: name} = data, _opts)
      when is_map(data) do
    profile = get_profile(t, name)

    if profile == :unknown_profile do
      {profile, t}
    else
      {rc, _p} = change(profile, data) |> Repo.update()

      if rc === :ok, do: {rc, Thermostat.get_by(id: t.id)}, else: {rc, t}
    end
  end
end
