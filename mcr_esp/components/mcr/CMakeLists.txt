
set(
  MCR_MISC
    "src/misc/mcr_restart"      "src/misc/mcr_nvs"
    "src/misc/timestamp_task"   "src/misc/status_led"
    "src/misc/hw_config")

set(
  MCR_NET
    "src/net/net")

set(
  MCR_DEVS
    "src/devs/addr"   "src/devs/base"
    "src/devs/ds"     "src/devs/i2c"
    "src/devs/pwm")

set(
  MCR_CMDS
    "src/cmds/base"     "src/cmds/factory"
    "src/cmds/network"  "src/cmds/ota"
    "src/cmds/pwm"      "src/cmds/queues"
    "src/cmds/switch"   "src/cmds/types")

set(
  MCR_ENGINES
    "src/engines/i2c"   "src/engines/ds"
    "src/engines/pwm")

set(
  MCR_READINGS
    "src/readings/celsius"      "src/readings/reading"
    "src/readings/humidity"     "src/readings/soil"
    "src/readings/ramutil"      "src/readings/startup"
    "src/readings/simple_text"  "src/readings/positions"
    "src/readings/remote"       "src/readings/engine"
    "src/readings/pwm")

set(
  MCR_PROTOCOLS
    "src/protocols/mqtt"  "src/protocols/mqtt_in")

set(
  MCR_EXTERNAL_LIBS
    "src/libs/mongoose.c")

set(
  MCR_DRIVERS
    "src/drivers/owb_gpio.c"  "src/drivers/owb_rmt.c"
    "src/drivers/owb.c")

# all the above set() statements build up the sources to register as a
# component for idf to build
idf_component_register(
  SRCS
    ${MCR_MISC} ${MCR_NET} ${MCR_DEVS} ${MCR_CMDS} ${MCR_ENGINES}
    ${MCR_READINGS} ${MCR_PROTOCOLS} ${MCR_EXTERNAL_LIBS} ${MCR_DRIVERS}
  INCLUDE_DIRS
    "include" "include/external"
  REQUIRES
    esp_http_client esp_https_ota nvs_flash app_update esp_adc_cal
  EMBED_FILES
    ca.pem)

# build up the compile options
if(DEFINED ENV{MCR_ENV})
  message(STATUS "Using MCR_ENV=" $ENV{MCR_ENV} " from the env")
else()
  set(ENV{MCR_ENV} "dev")
  message(STATUS "MCR_ENV not set in env, defaulting to MCR_ENV=$ENV{MCR_ENV}")
endif()

set(
  MG_DEFINES
    "-DMG_LOCALS -DMG_ENABLE_HTTP=0")

set(
  ARDUINOJSON_DEFINES
    "-DARDUINOJSON_ENABLE_STD_STREAM -DARDUINOJSON_USE_LONG_LONG")

if(DEFINED ENV{MCR_MQTT_HOST})
  message(STATUS "Using MCR_MQTT_HOST=" $ENV{MCR_MQTT_HOST} " from the env")
  set(
    MCR_DEFINES
      "-DMCR_ENV=$ENV{MCR_ENV} -DMCR_MQTT_HOST=\"$ENV{MCR_MQTT_HOST}\"")
else()
  set(
    MCR_DEFINES
      "-DMCR_ENV=$ENV{MCR_ENV}")
endif()

set(
  COMPILE_DEFINES
    "${MG_DEFINES} ${ARDUINOJSON_DEFINES} ${MCR_DEFINES}")


target_compile_options(${COMPONENT_LIB} PRIVATE -DMG_LOCALS -DMG_ENABLE_HTTP=0
  -DARDUINOJSON_ENABLE_STD_STREAM -DARDUINOJSON_USE_LONG_LONG)
