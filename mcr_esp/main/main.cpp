/* mcr ESP32
 */
#include <cstdlib>

#include <driver/periph_ctrl.h>
#include <esp_log.h>
#include <esp_spi_flash.h>
#include <esp_system.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

#include "engines/ds_engine.hpp"
#include "engines/i2c_engine.hpp"
#include "misc/mcr_nvs.hpp"
#include "misc/timestamp_task.hpp"
#include "net/mcr_net.hpp"
#include "protocols/mqtt.hpp"

extern "C" {
void app_main(void);
int setenv(const char *envname, const char *envval, int overwrite);
void tzset(void);
}

extern const uint8_t ca_start[] asm("_binary_ca_pem_start");
extern const uint8_t ca_end[] asm("_binary_ca_pem_end");

static const char *TAG = "mcrESP";

static mcr::Net *network = nullptr;
static mcrTimestampTask *timestampTask = nullptr;
static mcrMQTT *mqttTask = nullptr;
static mcrDS *dsEngineTask = nullptr;
static mcrI2c *i2cEngineTask = nullptr;

void app_main() {
  ESP_LOGI(TAG, "%s entered", __PRETTY_FUNCTION__);
  ESP_LOGI(TAG, "portTICK_PERIOD_MS=%u and 10ms=%u tick%s", portTICK_PERIOD_MS,
           pdMS_TO_TICKS(10), (pdMS_TO_TICKS(10) > 1) ? "s" : "");

  // set timezone to Eastern Standard Time
  // this is done very early to ensure the timezone is available for any
  // functions that need it.
  setenv("TZ", "EST5EDT,M3.2.0/2,M11.1.0", 1);
  tzset();

  // ensure all peripherals have been completely reset
  // important after OTA and if an internal error occured that forced a restart
  // periph_module_disable(PERIPH_WIFI_MODULE);
  // periph_module_disable(PERIPH_I2C0_MODULE);
  // periph_module_disable(PERIPH_RMT_MODULE);
  //
  // periph_module_enable(PERIPH_WIFI_MODULE);
  // periph_module_enable(PERIPH_I2C0_MODULE);
  // periph_module_enable(PERIPH_RMT_MODULE);

  mcrNVS::init();

  // must create network first!
  network = mcr::Net::instance(); // singleton
  timestampTask = new mcrTimestampTask();
  mqttTask = mcrMQTT::instance();     // singleton
  dsEngineTask = mcrDS::instance();   // singleton
  i2cEngineTask = mcrI2c::instance(); // singleton

  // create and start our tasks
  // NOTE: each task is responsible for required coordination

  timestampTask->start();
  mqttTask->start();
  dsEngineTask->start();
  i2cEngineTask->start();

  network->start();

  // request TimestampTask to watch the stack high water mark for a task
  timestampTask->watchStack(mqttTask->tagEngine(), mqttTask->taskHandle());

  network->waitForNormalOps();
  mcr::Net::waitForName(30000);

  const esp_partition_t *run_part = esp_ota_get_running_partition();
  esp_ota_img_states_t ota_state;
  if (esp_ota_get_state_partition(run_part, &ota_state) == ESP_OK) {
    if (ota_state == ESP_OTA_IMG_PENDING_VERIFY) {
      esp_err_t mark_valid_rc = esp_ota_mark_app_valid_cancel_rollback();

      if (mark_valid_rc == ESP_OK) {
        ESP_LOGI(TAG, "[%s] ota partition marked as valid",
                 esp_err_to_name(mark_valid_rc));
      } else {
        ESP_LOGW(TAG, "[%s] failed to mark app partition as valid",
                 esp_err_to_name(mark_valid_rc));
      }
    }
  }

  UBaseType_t stack_high_water = uxTaskGetStackHighWaterMark(nullptr);
  UBaseType_t num_tasks = uxTaskGetNumberOfTasks();

  ESP_LOGI(TAG, "boot complete [stack high water: %d, num of tasks: %d]",
           stack_high_water, num_tasks);

  ESP_LOGI(TAG, "certificate authority pem available [%d bytes]",
           ca_end - ca_start);

  mcrNVS::processCommittedMsgs();
  mcrNVS::commitMsg("BOOT", "LAST SUCCESSUL BOOT");

  for (;;) {
    // just sleep
    vTaskDelay(pdMS_TO_TICKS(15 * 60 * 1000));
  }
}
