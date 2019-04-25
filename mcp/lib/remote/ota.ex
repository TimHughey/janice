defmodule OTA do
  @moduledoc false

  require Logger

  alias Janice.TimeSupport

  alias Mqtt.Client

  @ota_https "ota.https"
  @restart_cmd "restart"

  def config_url do
    def = [
      url: [
        host: "nohost",
        uri: "nouri",
        fw_file: "nofile.bin"
      ]
    ]

    config = Application.get_env(:mcp, OTA, def)
    host = Kernel.get_in(config, [:url, :host])
    uri = Kernel.get_in(config, [:url, :uri])
    fw_file = Kernel.get_in(config, [:url, :fw_file])

    "https://" <> host <> "/" <> uri <> "/" <> fw_file
  end

  def restart(host, opts \\ []) when is_binary(host) do
    delay_ms = Keyword.get(opts, :delay_ms, 3_000)

    %{}
    |> Map.put(:cmd, @restart_cmd)
    |> Map.put(:mtime, TimeSupport.unix_now(:seconds))
    |> Map.put(:host, host)
    |> Map.put(:reboot_delay_ms, delay_ms)
    |> json()
    |> Client.publish()
  end

  def send(opts) when is_list(opts) do
    log = Keyword.get(opts, :log, true)
    # wrap in a list then flatten to handle when a single host is sent
    update_hosts = [Keyword.get(opts, :update_hosts, [])] |> List.flatten()
    url = Keyword.get(opts, :url, config_url())
    reboot_delay_ms = Keyword.get(opts, :reboot_delay_ms, 0)

    if is_binary(url) do
      log && Logger.info(fn -> "ota url [#{url}]" end)

      # be sure to filter out any :not_found
      for host <- update_hosts, is_binary(host) and host != :not_found do
        log && Logger.info(fn -> "send ota https [#{host}]" end)

        # TODO: design and implement new firmware version handling
        # fw_file_version()

        %{}
        |> Map.put(:cmd, @ota_https)
        |> Map.put(:mtime, TimeSupport.unix_now(:seconds))
        |> Map.put(:host, host)
        |> Map.put(:fw_url, url)
        |> Map.put(:reboot_delay_ms, reboot_delay_ms)
        |> json()
        |> Client.publish()
      end

      :ok
    else
      :bad_opts
    end
  end

  defp json(%{} = c) do
    Jason.encode!(c)
  end
end
