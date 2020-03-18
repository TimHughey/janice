defmodule Janice.Common.DB do
  @moduledoc false
  use Timex

  defmacro __using__([]) do
    quote do
      import Janice.Common.DB, only: [deprecated_name: 1, name_regex: 0]

      # @behaviour Janice.Common.DB

      def find(x), do: Janice.Common.DB.find(__MODULE__, x)
    end
  end

  def find(mod, id) when is_integer(id),
    do: Repo.get_by(mod, id: id)

  def find(mod, name) when is_binary(name),
    do: Repo.get_by(mod, name: name)

  def deprecated_name(name) when is_binary(name),
    do: "~ #{name}-#{Timex.now() |> Timex.format!("{ASN1:UTCtime}")}"

  # validate name:
  #  -starts with a ~ or alpha char
  #  -contains a mix of:
  #      alpha numeric, slash (/), dash (-), underscore (_), colon (:) and
  #      spaces
  #  -ends with an alpha char
  def name_regex, do: ~r'^[\\~\w]+[\w\\ \\/\\:\\.\\_\\-]{1,}[\w]$'

  # parse_device/1:
  #  -starts with alpha char
  #  -contains a mix of alpha, numeric, slash (/), underscore (_),
  #     period (.) and colon(:)
  #  -ends with digit(s)
  #  -captures prefix, name and pio
  #
  #  Example:  pwm/dev-beta.00.mcp23008:0
  def parse_device, do: ~r'^([a-zA-z]+)\\/([\w\\.\\-_]+)\\:(\d+)$'
end
