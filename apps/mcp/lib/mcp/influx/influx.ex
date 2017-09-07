defmodule Mcp.Influx do
  def license, do: """
     Master Control Program for Wiss Landing
     Copyright (C) 2016  Tim Hughey (thughey)

     This program is free software: you can redistribute it and/or modify
     it under the terms of the GNU General Public License as published by
     the Free Software Foundation, either version 3 of the License, or
     (at your option) any later version.

     This program is distributed in the hope that it will be useful,
     but WITHOUT ANY WARRANTY; without even the implied warranty of
     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
     GNU General Public License for more details.

     You should have received a copy of the GNU General Public License
     along with this program.  If not, see <http://www.gnu.org/licenses/>
     """
  @moduledoc """
    GenServer implementation of posting measurements (and metrics) to InfluxDB
    """

  require Logger
  use Timex
  use Mcp.GenServer

  alias Mcp.{Reading, Duration}
  alias Mcp.Influx.{ServerState, Position}

  @duration "duration"

  def start_link(_args) do
     start_link(Mcp.Influx, config(:name), %ServerState{})
  end

  def init(%ServerState{} = s) do
    {:ok, s}
  end

  def stop, do: GenServer.stop(server_name())

  def post([]), do: :nil
  def post(l) when is_list(l) do
    post(hd(l))
    post(tl(l))
  end

  def post(%Reading{} = r) do
    GenServer.cast(server_name(), {:post, r})
  end

  def post(%Position{} = p) do
    GenServer.cast(server_name(), {:post, p})
  end

  def post(%Duration{} = d) do
    GenServer.cast(server_name(), {:post, d})
  end

  # Internal implementation
  defp post_actual(%ServerState{} = s, %Reading{} = r) do
    name = Reading.name(r)
    kind = Reading.kind(r)
    ts = Reading.read_at_ns(r)
    val = Reading.val(r)
    rus = Reading.read_us(r)

    a = "#{r.kind},sensor=#{name}" |> node_and_env() |> val_and_ts(val, ts)
    b = "metrics,sensor=#{name},kind=#{kind}" |> node_and_env() |>
          readus_and_ts(rus, ts)

    args = [a, b]
    res = :timer.tc(&send_post_to_db/1, [args])
    res = check_post_reply(res)

    ServerState.record_post(s, res)
  end

  defp post_actual(%ServerState{} = s, %Duration{} = d) do
    metric = Duration.metric(d)
    val = Duration.val(d)
    ts = Duration.ts_ns(d)

    z = @duration <> ",loop=#{metric}" |>
        node_and_env() |> val_and_ts(val, ts)

    res = :timer.tc(&send_post_to_db/1, [z])
    res = check_post_reply(res)

    ServerState.record_post(s, res)
  end

  defp post_actual(%ServerState{} = s, %Position{} = p) do
    d = "switch," <> "name=#{p.switch}" <>
        ",node=#{node_id()},env=#{exec_env()} " <>
        "position=#{p.pos} #{p.at_ns}"

    res = :timer.tc(&send_post_to_db/1, [d])
    res = check_post_reply(res)

    ServerState.record_post(s, res)
  end

  defp send_post_to_db(""), do: {:error, :nodata}
  defp send_post_to_db(list) when is_list(list) do
    list |> Enum.join("\n") |> send_post_to_db()
  end
  defp send_post_to_db(body) when is_binary(body) do
    {uri, opts} = build_uri(:write)

    case HTTPoison.post(uri, body, %{}, opts) do
      {:ok, %{headers: headers, status_code: 204}} -> {:ok, headers}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_uri(func) when is_atom(func) do
    host = config(:db_host)
    db = config(:db)
    user = config(:db_user)
    pass = config(:db_pass)
    qry = %{:db => db} |> URI.encode_query()
    opts = [hackney: [basic_auth: {user, pass}, pool: :default]]

    uri =
      case func do
        :write  -> "http://#{host}/write?#{qry}"
        :query  -> "http://#{host}/query?#{qry}"
        _ -> "foobar"
      end

    {uri, opts}
  end

  # post to influx helpers
  defp check_post_reply({elapsed, {:ok, headers}}) do
    %{status: :ok, elapsed: elapsed, headers: headers}
  end
  defp check_post_reply({e, {:error, %HTTPoison.Error{reason: _reason}}} = h) do
    %{status: :failed, elapsed: e, headers: h}
  end
  defp check_post_reply({elapsed, {:error, :nodata}}) do
    %{status: :nodata, elapsed: elapsed, headers: %{}}
  end

  def handle_cast({:post, %Reading{} = r}, %ServerState{} = s) do
    s = post_actual(s, r)
    {:noreply, s}
  end

  def handle_cast({:post, %Position{} = p}, %ServerState{} = s) do
    s = post_actual(s, p)
    {:noreply, s}
  end

  def handle_cast({:post, %Duration{} = d}, %ServerState{} = s) do
    s = post_actual(s, d)
    {:noreply, s}
  end

  # post builder helpers
  defp node_and_env(b), do: b <> ",node=#{node_id()},env=#{exec_env()}"
  defp val_and_ts(b, v, t), do: b <> " value=#{v} #{t}"
  defp readus_and_ts(b, v, t), do: b <> " read_us=#{v} #{t}"

  # configuration helpers
  defp node_id, do: config(:node_id)
  defp exec_env, do: config(:exec_env)

end
