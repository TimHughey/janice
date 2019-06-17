#include <cstdlib>

#include <driver/adc.h>
#include <driver/gpio.h>
#include <driver/ledc.h>
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
  const char *dnsIP();
  void ensureTimeIsSet();
  bool start();

  static void deinit();
  static EventGroupHandle_t eventGroup();
  static mcrHardwareConfig_t hardwareConfig();
  static const string_t &getName();
  static const string_t &hostID();
  static Net_t *instance();
  static const string_t &macAddress();
  static void setName(const string_t name);
  static void statusLED(bool on);
  static void resumeNormalOps();
  static void suspendNormalOps();
  static bool waitForConnection(uint32_t wait_ms = UINT32_MAX);
  static bool waitForInitialization(uint32_t wait_ms = UINT32_MAX);
  static bool waitForIP(uint32_t wait_ms = 60000);
  static bool waitForName(uint32_t wait_ms = 0);
  static bool waitForNormalOps(uint32_t wait_ms = UINT32_MAX);
  static bool isTimeSet();
  static bool waitForReady(uint32_t wait_ms = UINT32_MAX);
  static bool waitForTimeset(uint32_t wait_ms = UINT32_MAX);
  static void setTransportReady(bool val = true);

  static inline bool clearBits() { return true; };
  static inline bool noClearBits() { return false; };
  static inline bool waitAllBits() { return true; };
  static inline bool waitAnyBits() { return false; };

  static EventBits_t connectedBit() { return BIT0; };
  static EventBits_t ipBit() { return BIT1; };
  static EventBits_t nameBit() { return BIT2; };
  static EventBits_t normalOpsBit() { return BIT3; };
  static EventBits_t readyBit() { return BIT4; };
  static EventBits_t timeSetBit() { return BIT5; };
  static EventBits_t mqttReadyBit() { return BIT6; };
  static EventBits_t initializedBit() { return BIT7; };
  static EventBits_t transportBit() { return BIT8; };

  static const char *tagEngine() { return (const char *)"mcrNet"; };

  uint32_t batt_mv();
  static uint32_t vref() { return 1100; };

private: // member functions
  Net(); // SINGLETON!  constructor is private
  void acquiredIP(void *event_data);

  static void checkError(const char *func, esp_err_t err);
  void connected(void *event_data);
  void disconnected(void *event_data);
  void init();

  // Event Handlers
  static void ip_events(void *ctx, esp_event_base_t base, int32_t id,
                        void *data);
  static void wifi_events(void *ctx, esp_event_base_t base, int32_t id,
                          void *data);

private:
  EventGroupHandle_t evg_;
  esp_err_t init_rc_ = ESP_FAIL;
  tcpip_adapter_ip_info_t ip_info_;
  tcpip_adapter_dns_info_t primary_dns_;
  char dns_str_[16] = {};
  esp_adc_cal_characteristics_t *adc_chars_ = nullptr;
  esp_adc_cal_value_t adc_cal_;
  uint32_t batt_measurements_ = 64; // measurements to avg out noise

  static const adc_channel_t battery_adc_ = ADC_CHANNEL_7;
  static const gpio_num_t led_gpio_ = GPIO_NUM_13;
  const uint64_t hw_gpio_pin_sel_ = (GPIO_SEL_34 | GPIO_SEL_36 | GPIO_SEL_39);
  const gpio_num_t hw_gpio_[3] = {GPIO_NUM_36, GPIO_NUM_39, GPIO_NUM_34};
  mcrHardwareConfig_t hw_conf_ = LEGACY;

  string_t name_;
  bool reconnect_ = true;
};
} // namespace mcr
