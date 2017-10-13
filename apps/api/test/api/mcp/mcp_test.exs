defmodule Api.McpTest do
  use Api.DataCase

  alias Api.Mcp

  describe "ids" do
    alias Api.Mcp.Switch

    @valid_attrs %{id: 42}
    @update_attrs %{id: 43}
    @invalid_attrs %{id: nil}

    def switch_fixture(attrs \\ %{}) do
      {:ok, switch} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Mcp.create_switch()

      switch
    end

    test "list_ids/0 returns all ids" do
      switch = switch_fixture()
      assert Mcp.list_ids() == [switch]
    end

    test "get_switch!/1 returns the switch with given id" do
      switch = switch_fixture()
      assert Mcp.get_switch!(switch.id) == switch
    end

    test "create_switch/1 with valid data creates a switch" do
      assert {:ok, %Switch{} = switch} = Mcp.create_switch(@valid_attrs)
      assert switch.id == 42
    end

    test "create_switch/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Mcp.create_switch(@invalid_attrs)
    end

    test "update_switch/2 with valid data updates the switch" do
      switch = switch_fixture()
      assert {:ok, switch} = Mcp.update_switch(switch, @update_attrs)
      assert %Switch{} = switch
      assert switch.id == 43
    end

    test "update_switch/2 with invalid data returns error changeset" do
      switch = switch_fixture()
      assert {:error, %Ecto.Changeset{}} = Mcp.update_switch(switch, @invalid_attrs)
      assert switch == Mcp.get_switch!(switch.id)
    end

    test "delete_switch/1 deletes the switch" do
      switch = switch_fixture()
      assert {:ok, %Switch{}} = Mcp.delete_switch(switch)
      assert_raise Ecto.NoResultsError, fn -> Mcp.get_switch!(switch.id) end
    end

    test "change_switch/1 returns a switch changeset" do
      switch = switch_fixture()
      assert %Ecto.Changeset{} = Mcp.change_switch(switch)
    end
  end

  describe "switches" do
    alias Api.Mcp.Switch

    @valid_attrs %{id: 42}
    @update_attrs %{id: 43}
    @invalid_attrs %{id: nil}

    def switch_fixture(attrs \\ %{}) do
      {:ok, switch} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Mcp.create_switch()

      switch
    end

    test "list_switches/0 returns all switches" do
      switch = switch_fixture()
      assert Mcp.list_switches() == [switch]
    end

    test "get_switch!/1 returns the switch with given id" do
      switch = switch_fixture()
      assert Mcp.get_switch!(switch.id) == switch
    end

    test "create_switch/1 with valid data creates a switch" do
      assert {:ok, %Switch{} = switch} = Mcp.create_switch(@valid_attrs)
      assert switch.id == 42
    end

    test "create_switch/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Mcp.create_switch(@invalid_attrs)
    end

    test "update_switch/2 with valid data updates the switch" do
      switch = switch_fixture()
      assert {:ok, switch} = Mcp.update_switch(switch, @update_attrs)
      assert %Switch{} = switch
      assert switch.id == 43
    end

    test "update_switch/2 with invalid data returns error changeset" do
      switch = switch_fixture()
      assert {:error, %Ecto.Changeset{}} = Mcp.update_switch(switch, @invalid_attrs)
      assert switch == Mcp.get_switch!(switch.id)
    end

    test "delete_switch/1 deletes the switch" do
      switch = switch_fixture()
      assert {:ok, %Switch{}} = Mcp.delete_switch(switch)
      assert_raise Ecto.NoResultsError, fn -> Mcp.get_switch!(switch.id) end
    end

    test "change_switch/1 returns a switch changeset" do
      switch = switch_fixture()
      assert %Ecto.Changeset{} = Mcp.change_switch(switch)
    end
  end
end
