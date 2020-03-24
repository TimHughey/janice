defmodule JanitorTest do
  @moduledoc false

  use ExUnit.Case, async: true

  use Janitor

  # import ExUnit.CaptureLog

  # alias Dutycycle.Profile
  # alias Dutycycle.Server
  # alias Dutycycle.State
  # alias Dutycycle.Supervisor
  # alias Janice.TimeSupport

  setup do
    :ok
  end

  @moduletag :janitor
  setup_all do
    # range = 0..10 |> Enum.to_list()
    #
    # for n <- range do
    #   new_dutycycle(n)
    # end
    # |> Dutycycle.Server.add()
    #
    # %Dutycycle{
    #   name: name_str(50),
    #   comment: "with an active profile",
    #   device: "no_device",
    #   active: true,
    #   log: false,
    #   startup_delay_ms: 100,
    #   profiles: [
    #     %Dutycycle.Profile{
    #       name: "slow",
    #       active: true,
    #       run_ms: 360_000,
    #       idle_ms: 360_000
    #     }
    #   ],
    #   state: %Dutycycle.State{}
    # }
    # |> Dutycycle.Server.add()

    :ok
  end

  test "can get Janitor counts" do
    res = Janitor.counts()

    assert is_list(res)
    assert Keyword.has_key?(res, :orphan_count)
    assert is_integer(Keyword.get(res, :orphan_count))
  end

  test "can get Janitor opts" do
    opts = Janitor.opts()

    assert is_list(opts)
    assert Keyword.has_key?(opts, :switch_cmds)
    assert Keyword.has_key?(opts, :log)
    assert Keyword.has_key?(opts, :metrics_frequency)
    assert Keyword.has_key?(opts, :orphan_acks)
  end

  test "the truth will set you free" do
    assert true
  end
end
