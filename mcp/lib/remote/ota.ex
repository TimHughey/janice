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

    Enum.join(["https:/", host, uri, fw_file], "/")
  end

  def ota_url(opts) when is_list(opts) do
    if Keyword.has_key?(opts, :url), do: opts, else: opts ++ [url: config_url()]
  end

  def restart(false, opts) when is_list(opts), do: {:restart_bad_opts, opts}

  def restart(true, opts) when is_list(opts) do
    log = Keyword.get(opts, :log, true)

    # be sure to filter out any :not_found
    results =
      for %{host: host, name: name} <- Keyword.get(opts, :restart_list) do
        log && Logger.info(["send restart to: ", inspect(host, pretty: true)])

        {rc, _ref} =
          %{
            cmd: @restart_cmd,
            mtime: TimeSupport.unix_now(:second),
            host: host,
            name: name,
            reboot_delay_ms: Keyword.get(opts, :reboot_delay_ms, 0)
          }
          |> json()
          |> Client.publish()

        {name, host, rc}
      end

    log && Logger.info(["sent restart to: ", inspect(results, pretty: true)])
    results
  end

  def restart(opts) when is_list(opts) do
    restart(restart_opts_valid?(opts), opts)
  end

  def restart(anything) do
    Logger.warn(["restart bad args: ", inspect(anything, pretty: true)])
    {:bad_opts, anything}
  end

  def restart_opts_valid?(opts) do
    restart_list = Keyword.get(opts, :restart_list, [])

    cond do
      Enum.empty?(restart_list) -> false
      not is_map(hd(restart_list)) -> false
      true -> true
    end
  end

  def send_cmd(false, opts) when is_list(opts), do: {:send_bad_opts, opts}

  def send_cmd(true, opts) when is_list(opts) do
    log = Keyword.get(opts, :log, true)

    # be sure to filter out any :not_found
    results =
      for %{host: host, name: name} <- Keyword.get(opts, :update_list) do
        log && Logger.info(["send ota https to: ", inspect(host, pretty: true)])

        # TODO: design and implement new firmware version handling
        # fw_file_version()

        {rc, _ref} =
          %{
            cmd: @ota_https,
            mtime: TimeSupport.unix_now(:second),
            host: host,
            name: name,
            fw_url: Keyword.get(opts, :url),
            reboot_delay_ms: Keyword.get(opts, :reboot_delay_ms, 0)
          }
          |> json()
          |> Client.publish()

        {name, host, rc}
      end

    log && Logger.info(["sent ota https to: ", inspect(results, pretty: true)])

    results
  end

  def send_cmd(opts) when is_list(opts) do
    opts = ota_url(opts)
    send_cmd(send_opts_valid?(opts), opts)
  end

  def send_cmd(anything) do
    Logger.warn(["send bad args: ", inspect(anything, pretty: true)])
    {:bad_opts, anything}
  end

  def send_opts_valid?(opts) do
    update_list = Keyword.get(opts, :update_list, [])

    cond do
      Enum.empty?(update_list) -> false
      not is_map(hd(update_list)) -> false
      true -> true
    end
  end

  defp json(%{} = c) do
    Jason.encode!(c)
  end
end
