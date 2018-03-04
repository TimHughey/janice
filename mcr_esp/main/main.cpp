/* mcr ESP32
 */
#include <cstdlib>

#include <driver/periph_ctrl.h>
#include <esp_log.h>
#include <esp_spi_flash.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

#include "engines/ds_engine.hpp"
#include "engines/i2c_engine.hpp"
#include "misc/timestamp_task.hpp"
#include "misc/version.hpp"
#include "net/mcr_net.hpp"
#include "protocols/mqtt.hpp"

extern "C" {
void app_main(void);
}

static const char *embed_vsn_sha = mcrVersion::embed_vsn_sha();
static const char *TAG = "mcr_esp";

static mcr::Net *network = nullptr;
static mcrTimestampTask *timestampTask = nullptr;
static mcrMQTT *mqttTask = nullptr;
static mcrDS *dsEngineTask = nullptr;
static mcrI2c *i2cEngineTask = nullptr;

void app_main() {
  ESP_LOGI(TAG, "%s entered", __PRETTY_FUNCTION__);
  ESP_LOGI(TAG, "portTICK_PERIOD_MS=%u and 10ms=%u ticks", portTICK_PERIOD_MS,
           pdMS_TO_TICKS(10));
  ESP_LOGI(TAG, "%s", embed_vsn_sha);

  // periph_module_disable(PERIPH_I2C0_MODULE);
  // periph_module_enable(PERIPH_I2C0_MODULE);

  spi_flash_init();

  esp_err_t nvs_rc = ESP_OK;
  nvs_rc = nvs_flash_init();

  if (nvs_rc == ESP_ERR_NVS_NO_FREE_PAGES) {
    ESP_LOGW(TAG, "nvs no free pages, erasing");
    nvs_rc = nvs_flash_erase();
  }

  if (nvs_rc == ESP_OK) {
    ESP_LOGI(TAG, "nvs initialized");
  }

  // must create network first
  network = mcr::Net::instance(); // singleton, get the instance to create
  timestampTask = new mcrTimestampTask();
  mqttTask = mcrMQTT::instance(); // singleton, get the instance to create
  dsEngineTask = new mcrDS();
  i2cEngineTask = new mcrI2c();

  // create and start our tasks
  // NOTE: each task implementation handles syncronization

  timestampTask->start();
  mqttTask->start();
  dsEngineTask->start();
  i2cEngineTask->start();

  network->start();

  for (;;) {
    vTaskDelay(pdMS_TO_TICKS(5 * 60 * 1000));
  }
}
