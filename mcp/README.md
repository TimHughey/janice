# Mercurial

Mercurial provides system for collecting sensor data, controlling switches
and making making data available via a web interface and through a timeseries
database.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `mcp` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:timex, "~> 3.0"},
   {:poison, "~> 3.1", override: true},
   {:instream, "~> 0.16"},
   {:hackney, "~> 1.1"},
   {:poolboy, "~> 1.5"},
   {:httpoison, "~> 0.12"},
   {:postgrex, "~> 0.13"},
   {:ecto, "~> 2.1"},
   {:timex_ecto, "~> 3.1"},
   {:uuid, "~> 1.1"},
   {:hulaaki, "~> 0.1.0"},
   {:phoenix, "~> 1.3.0"},
   {:phoenix_pubsub, "~> 1.0"},
   {:phoenix_ecto, "~> 3.2"},
   {:phoenix_html, "~> 2.10"},
   {:phoenix_live_reload, "~> 1.0", only: :dev},
   {:gettext, "~> 0.11"},
   {:cowboy, "~> 1.0"},
   {:guardian, "~> 1.0"},
   {:ueberauth, "~> 0.4"},
   {:ueberauth_github, "~> 0.4"},
   {:ueberauth_identity, "~> 0.2"},
   {:distillery, "~> 1.0"},
   {:credo, "> 0.0.0", only: [:dev, :test]}]
end
```
