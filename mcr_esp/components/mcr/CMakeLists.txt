idf_component_register(SRCS "src/misc/mcr_restart" "src/misc/mcr_nvs" "src/misc/timestamp_task" "src/misc/status_led" "src/misc/hw_config" "src/net/net" "src/devs/i2c" "src/devs/ds" "src/devs/addr" "src/devs/base" "src/devs/pwm" "src/cmds/switch" "src/cmds/types" "src/cmds/network" "src/cmds/queues" "src/cmds/factory" "src/cmds/base" "src/cmds/ota" "src/cmds/pwm" "src/engines/i2c" "src/engines/ds" "src/engines/pwm" "src/readings/celsius" "src/readings/reading" "src/readings/humidity" "src/readings/soil" "src/readings/ramutil" "src/readings/startup" "src/readings/simple_text" "src/readings/positions" "src/readings/remote" "src/readings/engine" "src/readings/pwm" "src/protocols/mqtt" "src/protocols/mqtt_in" "src/libs/mongoose.c" "src/drivers/owb_gpio.c" "src/drivers/owb_rmt.c" "src/drivers/owb.c"
                       INCLUDE_DIRS "include" "include/external"
                       REQUIRES esp_http_client esp_https_ota nvs_flash app_update esp_adc_cal
                       EMBED_FILES ca.pem)

target_compile_options(${COMPONENT_LIB} PRIVATE -DMG_LOCALS -DMG_ENABLE_HTTP=0 -DARDUINOJSON_ENABLE_STD_STREAM -DARDUINOJSON_USE_LONG_LONG)
