defmodule JanTest do
  @moduledoc """

  """

  def host(name, n), do: "mcr.#{name}#{num_str(n)}"

  def mt_host(n), do: host("mixtank", n)
  def mt_name(n), do: name("mixtank", n)

  def name(prefix, n), do: "#{prefix}#{num_str(n)}"

  def num_str(n), do: String.pad_leading(Integer.to_string(n), 3, "0")
end
