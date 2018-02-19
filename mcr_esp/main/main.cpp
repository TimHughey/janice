/* mcr ESP32
 */
#include <cstdlib>

#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

#include "engines/ds_engine.hpp"
#include "engines/i2c_engine.hpp"
#include "misc/timestamp_task.hpp"
#include "misc/util.hpp"
#include "misc/version.hpp"
#include "net/mcr_net.hpp"
#include "protocols/mqtt.hpp"

extern "C" {
void app_main(void);
}

static const char *TAG = "mcr_esp";

static mcrNetwork *network = nullptr;
static mcrTimestampTask *timestampTask = nullptr;
static mcrMQTT *mqttTask = nullptr;
static mcrDS *dsEngineTask = nullptr;
static mcrI2c *i2cEngineTask = nullptr;

void app_main() {
  ESP_LOGI(TAG, "%s entered", __PRETTY_FUNCTION__);
  ESP_LOGI(TAG, "portTICK_PERIOD_MS=%u and 10ms=%uticks", portTICK_PERIOD_MS,
           pdMS_TO_TICKS(10));
  ESP_LOGI(TAG, "mcr_rev=%s git_rev=%s", mcrVersion::mcr_stable(),
           mcrVersion::git());

  // must create network first
  network = new mcrNetwork();
  timestampTask = new mcrTimestampTask();
  mqttTask = mcrMQTT::instance();
  dsEngineTask = new mcrDS();
  i2cEngineTask = new mcrI2c();

  // create and start our tasks
  // NOTE: task implementation handles syncronization

  timestampTask->start();
  mqttTask->start();
  dsEngineTask->start();
  i2cEngineTask->start();

  network->start();

  for (;;) {
    vTaskDelay(pdMS_TO_TICKS(5 * 60 * 1000));
  }
}
