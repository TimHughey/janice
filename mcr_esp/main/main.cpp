/* LwIP SNTP example

   This example code is in the Public Domain (or CC0 licensed, at your option.)

   Unless required by applicable law or agreed to in writing, this
   software is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
   CONDITIONS OF ANY KIND, either express or implied.
*/
#include <cstdlib>
#include <esp_attr.h>
#include <esp_event_loop.h>
#include <esp_log.h>
// #include <esp_sleep.h>
#include <esp_system.h>
#include <esp_wifi.h>
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/task.h>
#include <nvs_flash.h>
#include <string.h>
#include <sys/time.h>
#include <time.h>

#include <System.h>
#include <Task.h>
#include <WiFi.h>
#include <WiFiEventHandler.h>

#include "apps/sntp/sntp.h"
#include "lwip/err.h"

#include "engines/ds_engine.hpp"
#include "engines/i2c_engine.hpp"
#include "misc/dev_task.hpp"
#include "misc/timestamp_task.hpp"
#include "misc/util.hpp"
#include "protocols/mqtt.hpp"

extern "C" {
void app_main(void);
}

// local prototypes to solve linter errors
int setenv(const char *, const char *, int);
void tzset(void);

static const char *TAG = "mcr_esp";

static WiFi wifi;
static mcrTimestampTask *timestampTask = nullptr;
static mcrMQTT *mqttTask = nullptr;
static mcrDS *dsEngineTask = nullptr;
static mcrI2c *i2cEngineTask = nullptr;

static EventGroupHandle_t wifi_event_group;
const int CONNECTED_BIT = BIT0;
const int TIMESET_BIT = BIT1;

class TargetWiFiEventHandler : public WiFiEventHandler {
private:
  EventGroupHandle_t _event_group = nullptr;

public:
  TargetWiFiEventHandler(EventGroupHandle_t event_group) {
    _event_group = event_group;
  }

  esp_err_t staGotIp(system_event_sta_got_ip_t event_sta_got_ip) {
    ESP_LOGI("WiFiEventHandler", "got IP address");
    ESP_LOGI("WiFiEventHandler", "host_id: %s", mcrUtil::hostID());

    // once connected set the wait group bit so other waiting tasks
    // are allowed to run
    xEventGroupSetBits(_event_group, CONNECTED_BIT);

    return ESP_OK;
  }
};

/* Variable holding number of times ESP32 restarted since first boot.
 * It is placed into RTC memory using RTC_DATA_ATTR and
 * maintains its value when ESP32 wakes from deep sleep.
 */
// RTC_DATA_ATTR static int boot_count = 0;

static void obtain_time(void);
static void initialize_sntp(void);
static void initialise_wifi(void);
// static esp_err_t event_handler(void *ctx, system_event_t *event);

void app_main() {
  ESP_LOGI(TAG, "%s entered", __PRETTY_FUNCTION__);

  // NOTE: moved to mcrI2c class
  // ESP_LOGI(TAG, "installing i2c driver...");
  // i2c_config_t _conf;
  // bzero(&_conf, sizeof(_conf));
  // _conf.mode = I2C_MODE_MASTER;
  // _conf.sda_io_num = (gpio_num_t)23;
  // _conf.scl_io_num = (gpio_num_t)22;
  // _conf.sda_pullup_en = GPIO_PULLUP_ENABLE;
  // _conf.scl_pullup_en = GPIO_PULLUP_ENABLE;
  // _conf.master.clk_speed = 100000;
  //
  // ESP_ERROR_CHECK(i2c_param_config(I2C_NUM_0, &_conf));
  // ESP_ERROR_CHECK(i2c_driver_install(I2C_NUM_0, _conf.mode, 0, 0, 0));
  // vTaskDelay(pdMS_TO_TICKS(200));
  //
  // ESP_LOGI(TAG, "i2c driver installed");

  wifi_event_group = xEventGroupCreate();

  // create and start our tasks
  // NOTE: task implementation handles syncronization
  timestampTask = new mcrTimestampTask(wifi_event_group, TIMESET_BIT);
  timestampTask->start();

  mqttTask = new mcrMQTT(wifi_event_group, TIMESET_BIT);
  mqttTask->start();

  // mcrDevTask *devTask = nullptr;
  // devTask = new mcrDevTask(wifi_event_group, CONNECTED_BIT);
  // devTask->start();

  dsEngineTask = new mcrDS(mqttTask, wifi_event_group, TIMESET_BIT);
  dsEngineTask->start();

  i2cEngineTask = new mcrI2c(mqttTask, wifi_event_group, TIMESET_BIT);
  i2cEngineTask->start();

  time_t now;
  struct tm timeinfo;
  time(&now);
  localtime_r(&now, &timeinfo);
  // Is time set? If not, tm_year will be (1970 - 1900).
  if (timeinfo.tm_year < (2016 - 1900)) {
    obtain_time();
    time(&now);
  }
  char strftime_buf[64];

  // Set timezone to UTC

  setenv("TZ", "UTC+0", 1);
  tzset();
  localtime_r(&now, &timeinfo);
  strftime(strftime_buf, sizeof(strftime_buf), "%c", &timeinfo);
  ESP_LOGI(TAG, "The current date/time in UTC is: %s", strftime_buf);
  ESP_LOGI(TAG, "1ms = %uticks", pdMS_TO_TICKS(1));

  for (;;) {
    vTaskDelay(pdMS_TO_TICKS(5 * 60 * 1000));
  }
}

static void obtain_time(void) {
  ESP_ERROR_CHECK(nvs_flash_init());

  initialise_wifi();
  xEventGroupWaitBits(wifi_event_group, CONNECTED_BIT, false, true,
                      portMAX_DELAY);
  initialize_sntp();

  // wait for time to be set
  time_t now = 0;
  struct tm timeinfo = {};
  int retry = 0;
  const int retry_count = 10;
  while (timeinfo.tm_year < (2016 - 1900) && ++retry < retry_count) {
    ESP_LOGI(TAG, "Waiting for system time to be set... (%d/%d)", retry,
             retry_count);
    vTaskDelay(pdMS_TO_TICKS(2000));
    time(&now);
    localtime_r(&now, &timeinfo);
  }

  xEventGroupSetBits(wifi_event_group, TIMESET_BIT);

  // ESP_ERROR_CHECK(esp_wifi_stop());
}

static void initialize_sntp(void) {
  ESP_LOGI(TAG, "Initializing SNTP");
  sntp_setoperatingmode(SNTP_OPMODE_POLL);
  sntp_setservername(0, (char *)"jophiel.wisslanding.com");
  sntp_setservername(1, (char *)"loki.wisslanding.com");
  sntp_init();
}

static void initialise_wifi(void) {
  tcpip_adapter_init();

  // ESP_ERROR_CHECK(esp_event_loop_init(event_handler, NULL));

  TargetWiFiEventHandler *eventHandler =
      new TargetWiFiEventHandler(wifi_event_group);
  wifi.setWifiEventHandler(eventHandler);
  wifi.connectAP(CONFIG_WIFI_SSID, CONFIG_WIFI_PASSWORD);

  // wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
  // ESP_ERROR_CHECK(esp_wifi_init(&cfg));
  ESP_ERROR_CHECK(esp_wifi_set_storage(WIFI_STORAGE_RAM));
  // wifi_config_t wifi_config = {
  //     .sta =
  //         {
  //             .ssid = EXAMPLE_WIFI_SSID,
  //             .password = EXAMPLE_WIFI_PASS,
  //         },
  // };
  // ESP_LOGI(TAG, "Setting WiFi configuration SSID %s...",
  // wifi_config.sta.ssid); ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
  // ESP_ERROR_CHECK(esp_wifi_set_config(ESP_IF_WIFI_STA, &wifi_config));
  // ESP_ERROR_CHECK(esp_wifi_start());
}

// static esp_err_t event_handler(void *ctx, system_event_t *event) {
//   switch (event->event_id) {
//   case SYSTEM_EVENT_STA_START:
//     esp_wifi_connect();
//     break;
//   case SYSTEM_EVENT_STA_GOT_IP:
//     xEventGroupSetBits(wifi_event_group, CONNECTED_BIT);
//     break;
//   case SYSTEM_EVENT_STA_DISCONNECTED:
//     /* This is a workaround as ESP32 WiFi libs don't currently
//        auto-reassociate. */
//     esp_wifi_connect();
//     xEventGroupClearBits(wifi_event_group, CONNECTED_BIT);
//     break;
//   default:
//     break;
//   }
//   return ESP_OK;
// }
