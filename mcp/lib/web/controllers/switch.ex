defmodule Web.SwitchController do
  @moduledoc """
  """
  require Logger
  use Timex
  use Web, :controller

  def index(conn, _params) do
    all_ss = SwitchState.all(:everything)
    last_cmds = SwitchCmd.last_cmds(100)

    data =
      for ss <- all_ss do
        cmd = SwitchCmd.get_rt_latency(last_cmds, ss.name)

        %{
          id: ss.id,
          name: ss.name,
          device: ss.switch.device,
          enabled: ss.switch.enabled,
          description: ss.description,
          dev_latency: ss.switch.dev_latency,
          rt_latency: cmd.rt_latency,
          last_cmd_secs: humanize_secs(cmd.sent_at),
          last_seen_secs: humanize_secs(ss.switch.last_seen_at),
          state: ss.state
        }
      end

    resp = %{data: data, items: Enum.count(data), mtime: Timex.local() |> Timex.to_unix()}

    json(conn, resp)
  end

  def delete(conn, %{"id" => device}) do
    Logger.info(fn -> ~s(DELETE #{conn.request_path}) end)

    {rows, _} = Switch.delete(device)

    json(conn, %{rows: rows})
  end

  def update(%{method: "PATCH"} = conn, %{"id" => id, "name" => new_name} = _params) do
    Logger.info(fn -> ~s(#{conn.method} #{conn.request_path}) end)

    SwitchState.change_name(String.to_integer(id), new_name, "changed via web")

    json(conn, %{name: new_name})
  end

  def update(%{method: "PATCH"} = conn, %{"id" => id, "toggle" => "true"} = _params) do
    Logger.info(fn -> ~s(#{conn.method} #{conn.request_path}) end)

    new_state = SwitchState.toggle(String.to_integer(id))

    json(conn, %{state: new_state})
  end

  defp humanize_secs(nil), do: 0

  defp humanize_secs(%DateTime{} = dt) do
    # |> humanize_secs
    Timex.diff(Timex.now(), dt, :seconds)
  end
end
