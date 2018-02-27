autostart = %{autostart: true}

{:ok, mqtt_pid} = Mqtt.Client.start_link(autostart)
{:ok, fact_pid} = Fact.Supervisor.start_link(autostart)

Process.unlink(mqtt_pid)

ExUnit.start()
