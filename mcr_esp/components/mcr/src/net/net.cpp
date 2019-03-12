#include <cstdlib>
#include <iomanip>
#include <sstream>
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

#include "lwip/apps/sntp.h"
#include "lwip/err.h"

#include "net/mcr_net.hpp"

namespace mcr {

static Net_t *__singleton__ = nullptr;

Net::Net() { evg_ = xEventGroupCreate(); }

void Net::acquiredIP(system_event_t *event) {
  vTaskDelay(pdMS_TO_TICKS(3000));
  xEventGroupSetBits(evg_, ipBit());
}

// STATIC!!
void Net::checkError(const char *func, esp_err_t err) {
  if (err != ESP_OK) {
    vTaskDelay(pdMS_TO_TICKS(3000)); // let things settle
    ESP_LOGE(tagEngine(), "%s err=%02x, core dump", func, err);

    int *ptr = (int *)0xdead0000;
    *ptr = 0;

    // should never get here
    ESP_LOGE(tagEngine(), "core dump failed");
    vTaskDelay(pdMS_TO_TICKS(3000)); // let things settle
    esp_restart();
  }
}

void Net::connected(system_event_t *event) {
  xEventGroupSetBits(evg_, connectedBit());
}

void Net::disconnected(system_event_t *event) {
  esp_err_t rc = ESP_OK;
  EventBits_t clear_bits =
      connectedBit() | ipBit() | normalOpsBit() | readyBit();

  xEventGroupClearBits(evg_, clear_bits);
  sntp_stop();
  rc = ::esp_wifi_stop();
  checkError(__PRETTY_FUNCTION__, rc);

  start();
}

// STATIC!!
esp_err_t Net::evHandler(void *ctx, system_event_t *event) {
  esp_err_t rc = ESP_OK;
  Net_t *net = (Net_t *)ctx;

  if (ctx == nullptr) {
    ESP_LOGE(tagEngine(), "%s ctx==nullptr", __PRETTY_FUNCTION__);
    return rc;
  }

  switch (event->event_id) {
  case SYSTEM_EVENT_STA_CONNECTED:
    net->connected(event);
    break;

  case SYSTEM_EVENT_STA_GOT_IP:
    net->acquiredIP(event);
    break;

  case SYSTEM_EVENT_STA_LOST_IP:
  case SYSTEM_EVENT_STA_DISCONNECTED:
    net->disconnected(event);
    break;

  case SYSTEM_EVENT_STA_START:
    break;

  default:
    ESP_LOGW(tagEngine(), "%s unhandled event 0x%02x", __PRETTY_FUNCTION__,
             event->event_id);
    break;
  }

  return rc;
}

EventGroupHandle_t Net::eventGroup() { return instance()->evg_; }

Net_t *Net::instance() {
  if (__singleton__ == nullptr) {
    __singleton__ = new Net();
  }

  return __singleton__;
}

void Net::init() {
  esp_err_t rc = ESP_OK;

  if (init_done_)
    return;

  rc = ::esp_event_loop_init(evHandler, instance());

  if (rc == ESP_OK) {
    ::tcpip_adapter_init();
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();

    rc = ::esp_wifi_init(&cfg);
    if (rc == ESP_OK) {
      rc = esp_wifi_set_storage(WIFI_STORAGE_RAM);
    }
  }

  checkError(__PRETTY_FUNCTION__, rc);
}

void Net::ensureTimeIsSet() {
  // wait for time to be set
  time_t now = 0;
  struct tm timeinfo = {};
  int retry = 0;
  const int retry_count = 10;

  ESP_LOGI(tagEngine(), "waiting for time to be set...");
  while (timeinfo.tm_year < (2016 - 1900) && ++retry < retry_count) {
    if (retry > 6) {
      ESP_LOGW(tagEngine(), "waiting for system time to be set... (%d/%d)",
               retry, retry_count);
    }
    vTaskDelay(pdMS_TO_TICKS(1000));
    time(&now);
    localtime_r(&now, &timeinfo);
  }

  if (retry == retry_count) {
    ESP_LOGE(tagEngine(), "timeout while acquiring time");
    checkError(__PRETTY_FUNCTION__, 0xFE);
  } else {
    xEventGroupSetBits(evg_, timesetBit());
  }
}

const std::string &Net::getName() {
  if (instance()->_name.length() == 0) {
    return macAddress();
  }

  return instance()->_name;
}

const std::string &Net::hostID() {
  static std::string _host_id;

  if (_host_id.length() == 0) {
    _host_id = "mcr.";
    _host_id += macAddress();
  }

  return _host_id;
}

const std::string &Net::macAddress() {
  static std::string _mac;

  if (_mac.length() == 0) {
    std::stringstream bytes;
    uint8_t mac[6];

    esp_wifi_get_mac(WIFI_IF_STA, mac);

    bytes << std::hex << std::setfill('0');
    for (int i = 0; i <= 5; i++) {
      bytes << std::setw(sizeof(uint8_t) * 2) << static_cast<unsigned>(mac[i]);
    }

    _mac = bytes.str();
  }

  return _mac;
};

void Net::setName(const std::string name) {

  instance()->_name = name;
  ESP_LOGI(tagEngine(), "network name=%s", instance()->_name.c_str());

  xEventGroupSetBits(instance()->eventGroup(), nameBit());
}

bool Net::start() {
  esp_err_t rc = ESP_OK;
  init();

  rc = ::esp_wifi_set_mode(WIFI_MODE_STA);
  checkError(__PRETTY_FUNCTION__, rc);

  wifi_config_t cfg;
  ::memset(&cfg, 0, sizeof(cfg));
  cfg.sta.scan_method = WIFI_ALL_CHANNEL_SCAN;
  cfg.sta.sort_method = WIFI_CONNECT_AP_BY_SIGNAL;
  cfg.sta.bssid_set = 0;
  ::strncpy((char *)cfg.sta.ssid, CONFIG_WIFI_SSID, sizeof(cfg.sta.ssid));
  ::strncpy((char *)cfg.sta.password, CONFIG_WIFI_PASSWORD,
            sizeof(cfg.sta.password));

  rc = ::esp_wifi_set_config(WIFI_IF_STA, &cfg);
  if (rc == ESP_OK) {
    rc = ::esp_wifi_start();

    if (rc == ESP_OK) {
      rc = ::esp_wifi_connect();
    }
  }
  checkError(__PRETTY_FUNCTION__, rc);

  if (waitForIP()) {
    sntp_setoperatingmode(SNTP_OPMODE_POLL);
    sntp_setservername(0, (char *)"ntp1.wisslanding.com");
    sntp_setservername(1, (char *)"ntp2.wisslanding.com");
    sntp_init();

    ensureTimeIsSet();
    tcpip_adapter_get_ip_info(TCPIP_ADAPTER_IF_STA, &ipInfo_);
    uint8_t *ip = (uint8_t *)&(ipInfo_.ip);
    ESP_LOGI(tagEngine(), "connected, acquired ip address %u.%u.%u.%u", ip[0],
             ip[1], ip[2], ip[3]);

    // NOTE: once we've reached here the network is connected, ip address
    //       acquired and the time is set -- signal to other tasks
    //       we are ready for normal operations
    xEventGroupSetBits(evg_, (readyBit() | normalOpsBit()));
  } else {
    // reuse checkError for IP address failure
    checkError(__PRETTY_FUNCTION__, 0xFF);
  }

  return true;
}

void Net::resumeNormalOps() {
  xEventGroupSetBits(instance()->eventGroup(), Net::normalOpsBit());
}

void Net::suspendNormalOps() {
  ESP_LOGW(tagEngine(), "suspending normal ops");
  xEventGroupClearBits(instance()->eventGroup(), Net::normalOpsBit());
}

bool Net::waitForConnection(int wait_ms) {
  xEventGroupWaitBits(instance()->eventGroup(), connectedBit(), false, true,
                      wait_ms);
  return true;
}

bool Net::waitForIP(int wait_ms) {
  esp_err_t res = ESP_OK;

  res = xEventGroupWaitBits(eventGroup(), ipBit(), false, true,
                            pdMS_TO_TICKS(wait_ms));

  return (res == ESP_OK) ? true : false;
}

bool Net::waitForName(int wait_ms) {
  esp_err_t res = xEventGroupWaitBits(eventGroup(), nameBit(), false, true,
                                      pdMS_TO_TICKS(wait_ms));

  return (res == ESP_OK) ? true : false;
}

bool Net::waitForNormalOps() {
  esp_err_t res = xEventGroupWaitBits(eventGroup(), normalOpsBit(), false, true,
                                      portMAX_DELAY);

  return (res == ESP_OK) ? true : false;
}

bool Net::waitForTimeset() {
  xEventGroupWaitBits(eventGroup(), timesetBit(), false, true, portMAX_DELAY);
  return true;
}
} // namespace mcr
