if Mix.env == :dev do

  import Mcp.DevAlias

  led1_dev = "ds/291d1823000000"
  buzz_dev = "ds/12128521000000"
  temp_probe1_dev = "ds/28ff5733711604"
  temp_probe2_dev = "ds/28ffa442711604"
  rhum_probe1_dev = "i2c/f8f005f73b53.04.am2315"
  rhum_chip01_dev = "i2c/f8f005f73b53.01.sht31"

  led1  = %Mcp.DevAlias{device: "#{led1_dev}:0", friendly_name: "led1",
                    description: "led development"}
  buzz  = %Mcp.DevAlias{device: "#{buzz_dev}:0", friendly_name: "buzzer",
                    description: "buzzer for development"}

  temp_probe1 = %Mcp.DevAlias{device: "#{temp_probe1_dev}",
                    friendly_name: "temp_probe1",
                    description: "temperature probe 1 for development"}
  temp_probe2 = %Mcp.DevAlias{device: "#{temp_probe2_dev}",
                    friendly_name: "temp_probe2",
                    description: "temperature probe 2 for development"}

  rhum_probe1 = %Mcp.DevAlias{device: "#{rhum_probe1_dev}",
                    friendly_name: "rhum_probe1",
                    description: "i2c temperature probe 1 for development"}

  rhum_chip01 = %Mcp.DevAlias{device: "#{rhum_chip01_dev}",
                    friendly_name: "rhum_chip01",
                    description: "i2c temperature chip 1 for development"}

  led1 = add(led1)
  buzz = add(buzz)
  temp1 = add(temp_probe1)
  temp2 = add(temp_probe2)
  rhum1 = add(rhum_probe1)
  rhum2 = add(rhum_chip01)

  {led1, buzz, temp1, temp2, rhum1, rhum2}
end
