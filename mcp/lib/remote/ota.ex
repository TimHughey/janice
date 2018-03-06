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

  def header_bytes, do: [0xD1, 0xD2, 0xD3, 0xD4]

  def restart(host, opts \\ []) when is_binary(host) do
    delay_ms = Keyword.get(opts, :delay_ms, 3000)

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
    delay_ms = Keyword.get(opts, :reboot_delay_ms, 3_000)

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

    task =
      Task.start_link(fn ->
        send_begin(opts)
        :timer.sleep(delay_ms)

        fw = Application.app_dir(:mcp, "priv/mcr_esp.bin")
        {:ok, file} = File.open(fw, [:read])

        transmit_blocks(file, :start, opts)

        :timer.sleep(delay_ms / 2)
        send_end(opts)
        File.close(file)
      end)

    if return_task, do: task, else: :ok
  end

  defp transmit_blocks(_file, :eof, _opts) do
    :ok
  end

  defp transmit_blocks(file, block, opts) when is_list(opts) do
    log = Keyword.get(opts, :log, false)
    # if :start is passed in as the block, get the first block
    data =
      if block == :start,
        do: IO.binread(file, @block_size),
        else: block

    flags =
      if block == :start do
        n = IO.iodata_length(data)
        log && Logger.info(fn -> "first block size=#{n}" end)
        # if :start was passed in then flag this is the first block
        <<0xD1::size(8)>>
      else
        case IO.iodata_length(data) do
          # if the amount of data is equal to a block then we are midstream
          n when n == @block_size ->
            log && Logger.debug(fn -> "stream block" end)
            <<0xD2::size(8)>>

          n ->
            # otherwise this is the final block
            log && Logger.info(fn -> "final block size=#{n}" end)
            <<0xD4::size(8)>>
        end
      end

    # prepend the flags to the data to form the actual message to transmit
    msg = flags <> data

    Client.publish_ota(msg)

    # get the next block and recurse
    next_block = IO.binread(file, @block_size)
    transmit_blocks(file, next_block, opts)
  end
end
