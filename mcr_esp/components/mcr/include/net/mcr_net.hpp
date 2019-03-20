#include <cstdlib>

#include <driver/adc.h>
#include <driver/gpio.h>
#include <esp_adc_cal.h>
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

#include "misc/mcr_types.hpp"

namespace mcr {

typedef class Net Net_t;
class Net {
public:
  void ensureTimeIsSet();
  static EventGroupHandle_t eventGroup();
  static const std::string &getName();

  static const std::string &hostID();
  static Net_t *instance();
  static const std::string &macAddress();
  static void setName(const std::string name);
  bool start();
  static void resumeNormalOps();
  static void suspendNormalOps();
  static bool waitForConnection(int wait_ms = portMAX_DELAY);
  static bool waitForIP(int wait_ms = pdMS_TO_TICKS(10000));
  static bool waitForName(int wait_ms = 0);
  static bool waitForNormalOps();
  static bool isTimeSet();
  static bool waitForTimeset();

  static EventBits_t connectedBit() { return BIT0; };
  static EventBits_t ipBit() { return BIT1; };
  static EventBits_t nameBit() { return BIT2; };
  static EventBits_t normalOpsBit() { return BIT3; };
  static EventBits_t readyBit() { return BIT4; };
  static EventBits_t timesetBit() { return BIT5; };

  static const char *tagEngine() { return (const char *)"mcrNet"; };

  uint32_t batt_mv();
  static uint32_t vref() { return 1058; };

private: // member functions
  Net(); // SINGLETON!  constructor is private
  void acquiredIP(system_event_t *event);

  static void checkError(const char *func, esp_err_t err);
  void connected(system_event_t *event);
  void disconnected(system_event_t *event);
  void init();
  static esp_err_t evHandler(void *ctx, system_event_t *event);

private:
  EventGroupHandle_t evg_;
  bool init_done_ = false;
  tcpip_adapter_ip_info_t ipInfo_;
  esp_adc_cal_characteristics_t *adc_chars_ = nullptr;
  esp_adc_cal_value_t adc_cal_;
  uint32_t batt_measurements_ = 64; // measurements to avg out noise

  static const adc_channel_t battery_adc_ = ADC_CHANNEL_7;

  std::string _name;
};
} // namespace mcr
