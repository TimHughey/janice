#include <cstdlib>

#include <esp_attr.h>
#include <esp_event_loop.h>
#include <esp_log.h>
// #include <esp_sleep.h>
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

#include "misc/util.hpp"

class mcrNetwork {
private:
  class mcrWiFiEventHandler : public WiFiEventHandler {
  private:
    EventGroupHandle_t _event_group = nullptr;

  public:
    mcrWiFiEventHandler(EventGroupHandle_t event_group) {
      _event_group = event_group;
    }

    esp_err_t staGotIp(system_event_sta_got_ip_t event_sta_got_ip) {
      ESP_LOGI("WiFiEventHandler", "got IP address");
      ESP_LOGI("WiFiEventHandler", "host_id: %s", mcrUtil::hostID().c_str());

      // once connected set the wait group bit so other waiting tasks
      // are allowed to run
      xEventGroupSetBits(_event_group, mcrNetwork::connectedBit());

      return ESP_OK;
    }

    esp_err_t staDisconnected(system_event_sta_disconnected_t info) {
      xEventGroupClearBits(_event_group, mcrNetwork::connectedBit());
      mcrNetwork *net = mcrNetwork::instance();
      net->_wifi.connectAP(CONFIG_WIFI_SSID, CONFIG_WIFI_PASSWORD);

      return ESP_OK;
    }
  };

public:
  mcrNetwork();

  void ensureTimeIsSet();
  static EventGroupHandle_t eventGroup();
  static const std::string &getName();
  static mcrNetwork *instance();
  static void setName(const std::string name);
  bool start();
  static bool waitForConnection();
  static bool waitForName(int wait_ms = 0);
  static bool waitForTimeset();

  static EventBits_t connectedBit();
  static EventBits_t nameBit();
  static EventBits_t timesetBit();

private:
  WiFi _wifi;
  EventGroupHandle_t _evg;
  mcrWiFiEventHandler *_event_handler = nullptr;
  std::string _name;
};
