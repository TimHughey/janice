defmodule Thermostat.Profile do
  @moduledoc """
  """

  require Logger
  use Timex
  use Timex.Ecto.Timestamps
  use Ecto.Schema

  # import Repo, only: [one: 1, update_all: 2]
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

    timestamps(usec: true)
  end

  def active(%Thermostat{} = t) do
    if is_nil(t.active_profile), do: :none, else: find_profile(t)
  end

  def add(%Thermostat{} = t, %Profile{} = p) do
    Ecto.build_assoc(t, :profiles, p) |> Repo.insert!()
  end

  def check_ms(%Profile{} = p), do: p.check_ms

  def find_profile(%Thermostat{active_profile: active_profile, profiles: profiles}) do
    found = for p <- profiles, active_profile === p.name, do: p

    if is_list(found), do: hd(found), else: :none
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
      Sensor.celsius(name: profile.ref_sensor, since_secs: 90)
    end
  end
end
