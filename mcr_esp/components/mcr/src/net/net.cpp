#include <cstdlib>
#include <string>

#include <esp_attr.h>
#include <esp_event_loop.h>
#include <esp_log.h>
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

#include "net/mcr_net.hpp"

static const char *TAG = "mcrNetwork";
static mcrNetwork *__singleton = nullptr;

mcrNetwork::mcrNetwork() {
  __singleton = this;

  ESP_ERROR_CHECK(nvs_flash_init());

  tcpip_adapter_init();
  _evg = xEventGroupCreate();

  _event_handler = new mcrWiFiEventHandler(_evg);
  _wifi.setWifiEventHandler(_event_handler);
}

EventBits_t mcrNetwork::connectedBit() { return BIT0; }
EventBits_t mcrNetwork::timesetBit() { return BIT1; }

EventGroupHandle_t mcrNetwork::eventGroup() { return __singleton->_evg; }
mcrNetwork *mcrNetwork::instance() { return __singleton; }

void mcrNetwork::ensureTimeIsSet() {
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

  xEventGroupSetBits(_evg, timesetBit());
}

bool mcrNetwork::start() {

  _wifi.connectAP(CONFIG_WIFI_SSID, CONFIG_WIFI_PASSWORD);
  ESP_ERROR_CHECK(esp_wifi_set_storage(WIFI_STORAGE_RAM));

  waitForConnection();

  sntp_setoperatingmode(SNTP_OPMODE_POLL);
  sntp_setservername(0, (char *)"jophiel.wisslanding.com");
  sntp_setservername(1, (char *)"loki.wisslanding.com");
  sntp_init();

  ensureTimeIsSet();

  return true;
}

bool mcrNetwork::waitForConnection() {
  xEventGroupWaitBits(__singleton->eventGroup(), connectedBit(), false, true,
                      portMAX_DELAY);
  return true;
}

bool mcrNetwork::waitForTimeset() {
  xEventGroupWaitBits(__singleton->eventGroup(), timesetBit(), false, true,
                      portMAX_DELAY);
  return true;
}
