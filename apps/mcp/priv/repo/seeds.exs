if Mix.env == :dev do

  import Mcp.DevAlias

  led1_dev = "ds/291d1823000000"
  buzz_dev = "ds/12128521000000"

  led1  = %Mcp.DevAlias{device: "#{led1_dev}:0", friendly_name: "led1",
                    description: "led created for development"}
  buzz  = %Mcp.DevAlias{device: "#{buzz_dev}:0", friendly_name: "buzzer",
                    description: "buzzer created for development"}

  led1 = add(led1)
  buzz = add(buzz)

  {led1, buzz}
end
