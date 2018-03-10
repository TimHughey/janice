defmodule OTA do
  @moduledoc """
  """

  require Logger
  use Timex

  alias Mqtt.Client

  @boot_factory_next "boot.factory.next"
  @ota_begin_cmd "ota.begin"
  @ota_end_cmd "ota.end"
  @restart_cmd "restart"
  @block_size 2048

  def boot_factory_next(host) when is_binary(host) do
    %{}
    |> Map.put(:vsn, Application.get_env(:mcp, :git_sha))
    |> Map.put(:cmd, @boot_factory_next)
    |> Map.put(:mtime, Timex.now() |> Timex.to_unix())
    |> Map.put(:host, host)
    |> json()
    |> Client.publish()
  end

  def fw_file_version do
    fw = Application.app_dir(:mcp, "priv/mcr_esp.bin")
    {:ok, file} = File.open(fw, [:read])

    block = IO.binread(file, 24 * 1024)
    rx = ~r/mcr_sha_head=(?<head>\w+).mcr_sha_stable=(?<stable>\w+)/x

    vsn = Regex.named_captures(rx, block)

    Logger.debug(fn -> "mcr_esp.bin versions: #{inspect(vsn)}" end)
    File.close(file)

    %{}
    |> Map.put_new(:head, Map.get(vsn, "head", "0000000"))
    |> Map.put_new(:stable, Map.get(vsn, "stable", "0000000"))
  end

  def header_bytes, do: for(t <- [:start, :stream, :last], do: header(t))
  defp header(:start), do: 0xD1
  defp header(:stream), do: 0xD2
  defp header(:last), do: 0xD4

  def restart(host, opts \\ []) when is_binary(host) do
    delay_ms = Keyword.get(opts, :delay_ms, 3_000)

    %{}
    |> Map.put(:vsn, Application.get_env(:mcp, :git_sha))
    |> Map.put(:cmd, @restart_cmd)
    |> Map.put(:mtime, Timex.now() |> Timex.to_unix())
    |> Map.put(:host, host)
    |> Map.put(:delay_ms, delay_ms)
    |> json()
    |> Client.publish()
  end

  defp send_begin(opts) when is_list(opts) do
    log = Keyword.get(opts, :log, true)
    update_hosts = Keyword.get(opts, :update_hosts, [])
    partition = Keyword.get(opts, :partition, "ota")
    delay_ms = Keyword.get(opts, :start_delay_ms, 3_000)

    if is_binary(partition) do
      for host <- update_hosts do
        log && Logger.info(fn -> "sending begin for #{host}" end)

        fw_file_version()
        |> Map.put(:vsn, Application.get_env(:mcp, :git_sha))
        |> Map.put(:cmd, @ota_begin_cmd)
        |> Map.put(:mtime, Timex.now() |> Timex.to_unix())
        |> Map.put(:host, host)
        |> Map.put(:partition, partition)
        |> Map.put(:start_delay_ms, delay_ms)
        |> json()
        |> Client.publish()
      end
    else
      :bad_opts
    end
  end

  defp send_end(opts) when is_list(opts) do
    log = Keyword.get(opts, :log, true)
    delay_ms = Keyword.get(opts, :reboot_delay_ms, 1_000)

    log && Logger.info(fn -> "sending end" end)

    %{}
    |> Map.put(:vsn, Application.get_env(:mcp, :git_sha))
    |> Map.put(:cmd, @ota_end_cmd)
    |> Map.put(:mtime, Timex.now() |> Timex.to_unix())
    |> Map.put(:reboot_delay_ms, delay_ms)
    |> json()
    |> Client.publish()
  end

  defp json(%{} = c) do
    Jason.encode!(c)
  end

  def transmit(opts \\ []) when is_list(opts), do: transmit_blocks(:task, opts)

  defp transmit_blocks(:task, opts) when is_list(opts) do
    delay_ms = Keyword.get(opts, :start_delay_ms, 3_000)
    return_task = Keyword.get(opts, :return_task, false)
    which_file = Keyword.get(opts, :file, :current)

    task =
      Task.start_link(fn ->
        send_begin(opts)
        :timer.sleep(delay_ms)

        def = [firmware_files: [current: "mcr_esp.bin"]]
        config = Application.get_env(:mcp, OTA, def)

        file = Kernel.get_in(config, [:firmware_files, which_file])

        if is_nil(file) do
          Logger.warn(fn -> "no config for firmware file #{inspect(which_file)}" end)
        else
          fw = Application.app_dir(:mcp, "priv/#{file}")
          {:ok, file} = File.open(fw, [:read])

          transmit_blocks(file, :start, opts)

          send_end(opts)
          File.close(file)
        end
      end)

    if return_task, do: task, else: :ok
  end

  defp transmit_blocks(file, :start, opts) do
    log = Keyword.get(opts, :log, false)

    block = IO.binread(file, @block_size)
    n = IO.iodata_length(block)
    msg = <<header(:start)::size(8)>> <> block

    log && Logger.info(fn -> "first block size=#{n}" end)

    Client.publish_ota(msg)

    # get the next block and recurse
    next_block = IO.binread(file, @block_size)
    transmit_blocks(file, next_block, opts)
  end

  # handle eof from IO.binread()
  defp transmit_blocks(_file, :eof, opts) do
    log = Keyword.get(opts, :log, false)

    log && Logger.info(fn -> "last block" end)

    msg = <<header(:last)::size(8)>>
    Client.publish_ota(msg)

    :ok
  end

  defp transmit_blocks(file, block, opts) when is_list(opts) do
    log = Keyword.get(opts, :log, false)

    n = IO.iodata_length(block)
    log && Logger.debug(fn -> "stream block size=#{n}" end)

    msg = <<header(:stream)::size(8)>> <> block

    Client.publish_ota(msg)

    # get the next block and recurse
    next_block = IO.binread(file, @block_size)
    transmit_blocks(file, next_block, opts)
  end
end
