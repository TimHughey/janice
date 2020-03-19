defmodule MessageSaveTest do
  @moduledoc false

  use ExUnit.Case, async: true

  # import ExUnit.CaptureLog

  @moduletag :message_save
  setup_all do
    :ok
  end

  test "server is recording last forward rc" do
    state = :sys.get_state(MessageSave)

    assert Map.has_key?(state, :last_forward_rc)
    %{last_forward_rc: rc} = state

    assert rc in [{:skipped}, {:ok}]
  end

  test "server is recording last insert rc" do
    state = :sys.get_state(MessageSave)

    assert Map.has_key?(state, :last_insert_msg_rc)

    %{last_insert_msg_rc: {rc, _res}} = state

    assert rc == :ok
  end

  test "can get server current opts" do
    opts = MessageSave.opts()

    assert is_list(opts)
    assert is_boolean(Keyword.get(opts, :save, nil))
    assert is_list(Keyword.get(opts, :save_opts, nil))

    assert is_boolean(Keyword.get(opts, :forward, nil))
    assert is_list(Keyword.get(opts, :forward_opts, nil))
  end

  test "can update server opts" do
    opts = MessageSave.opts()

    assert is_list(opts)
    purge = Keyword.get(opts, :purge, nil)

    assert is_list(purge)

    new_opts =
      Keyword.put(opts, :purge,
        all_at_startup: false,
        older_than: [minutes: 10],
        log: false
      )

    {rc, res} = MessageSave.opts(new_opts)

    assert rc == :ok
    assert is_list(res)

    assert opts == Keyword.get(res, :was, [])
    assert new_opts == Keyword.get(res, :is, [])
  end

  test "can get MessageSave counts" do
    counts = MessageSave.counts()

    assert is_list(counts)
    assert Keyword.get(counts, :forwarded) > 0
    assert is_integer(Keyword.get(counts, :deleted))
    assert Keyword.get(counts, :deleted) > 0
    assert is_integer(Keyword.get(counts, :saved))
  end
end
