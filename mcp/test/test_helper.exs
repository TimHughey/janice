autostart = %{autostart: true}

{:ok, _mqtt_pid} = Mqtt.Client.start_link(autostart)
{:ok, _fact_pid} = Fact.Supervisor.start_link(autostart)

Switch.delete_all(:dangerous)
Remote.delete_all(:dangerous)

ExUnit.start()
