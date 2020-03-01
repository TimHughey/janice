#include <cstdlib>
#include <memory>
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
#include "lwip/sys.h"

#include "misc/mcr_nvs.hpp"
#include "misc/mcr_restart.hpp"
#include "misc/status_led.hpp"
#include "net/mcr_net.hpp"

extern "C" {
int setenv(const char *envname, const char *envval, int overwrite);
void tzset(void);
}

using std::unique_ptr;

namespace mcr {

static Net_t *__singleton__ = nullptr;

Net::Net() {
  evg_ = xEventGroupCreate();

  // Characterize and setup ADC for measuring battery millivolts
  adc_chars_ = (esp_adc_cal_characteristics_t *)calloc(
      1, sizeof(esp_adc_cal_characteristics_t));
  adc_cal_ =
      esp_adc_cal_characterize(ADC_UNIT_1, ADC_ATTEN_DB_11, ADC_WIDTH_BIT_12,
                               mcr::Net::vref(), adc_chars_);

  adc1_config_width(ADC_WIDTH_BIT_12);
  adc1_config_channel_atten((adc1_channel_t)battery_adc_, ADC_ATTEN_DB_11);
}

void Net::acquiredIP(void *event_data) {
  wifi_ap_record_t ap;

  tcpip_adapter_get_ip_info(TCPIP_ADAPTER_IF_STA, &ip_info_);
  tcpip_adapter_get_dns_info(TCPIP_ADAPTER_IF_STA, TCPIP_ADAPTER_DNS_MAIN,
                             &primary_dns_);

  uint8_t *dns_ip = (uint8_t *)&(primary_dns_.ip);
  snprintf(dns_str_, sizeof(dns_str_), IPSTR, dns_ip[0], dns_ip[1], dns_ip[2],
           dns_ip[3]);

  esp_err_t ap_rc = esp_wifi_sta_get_ap_info(&ap);
  ESP_LOGI(tagEngine(), "[%s] AP channel(%d,%d) rssi(%ddB)",
           esp_err_to_name(ap_rc), ap.primary, ap.second, ap.rssi);

  ESP_LOGI(tagEngine(), "ready ip(" IPSTR ") dns(%s)", IP2STR(&ip_info_.ip),
           dns_str_);

  xEventGroupSetBits(evg_, ipBit());
}

uint32_t Net::batt_mv() {
  uint32_t batt_raw = 0;
  uint32_t batt_mv = 0;

  // ADC readings can be rather noisy.  so, perform more than one reading
  // then take the average
  for (uint32_t i = 0; i < batt_measurements_; i++) {
    batt_raw += adc1_get_raw((adc1_channel_t)battery_adc_);
  }

  batt_raw /= batt_measurements_;

  // the pin used to measure battery millivolts is connected to a voltage
  // divider so double the voltage
  batt_mv = esp_adc_cal_raw_to_voltage(batt_raw, adc_chars_) * 2;

  return batt_mv;
}

// STATIC!!
void Net::checkError(const char *func, esp_err_t err) {
  const size_t max_msg_len = 256;
  char *msg = new char[max_msg_len];

  vTaskDelay(pdMS_TO_TICKS(1000)); // let things settle

  switch (err) {
  case ESP_OK:
    return;

  case 0x1100FF:
    ESP_LOGE(tagEngine(), "failed to acquire IP address");
    mcrNVS::commitMsg(tagEngine(), "IP address aquisition failure");
    break;

  case 0x1100FE:
    ESP_LOGE(tagEngine(), "SNTP failed");
    mcrNVS::commitMsg(tagEngine(), "SNTP failure");
    break;

  default:
    snprintf(msg, max_msg_len, "[%s] %s", esp_err_to_name(err), func);
    ESP_LOGE(tagEngine(), "%s", msg);
    mcrNVS::commitMsg(tagEngine(), msg);
    break;
  }

  // UNCOMMENT FOR CORE DUMP INSTEAD OF RESTART
  // prevent the compiler from optimzing out this code
  // volatile uint32_t *ptr = (uint32_t *)0x0000000;

  // write to a nullptr to trigger core dump
  // ptr[0] = 0;

  mcrNVS::commitMsg(tagEngine(), msg);
  mcrRestart::instance()->restart(msg, __PRETTY_FUNCTION__, 3000);
}

void Net::connected(void *event_data) {
  xEventGroupSetBits(evg_, connectedBit());
}

void Net::disconnected(void *event_data) {
  wifi_event_sta_disconnected_t *data =
      (wifi_event_sta_disconnected_t *)event_data;

  xEventGroupClearBits(evg_, connectedBit());

  ESP_LOGW(tagEngine(), "wifi DISCONNECT reason(%d)", data->reason);

  if (reconnect_) {
    ESP_LOGI(tagEngine(), "wifi ATTEMPTING connect");
    ::esp_wifi_connect();
  }
}

const char *Net::dnsIP() { return dns_str_; }

// STATIC!!
void Net::ip_events(void *ctx, esp_event_base_t base, int32_t id, void *data) {

  Net_t *net = (Net_t *)ctx;

  if (ctx == nullptr) {
    ESP_LOGE(tagEngine(), "%s ctx==nullptr", __PRETTY_FUNCTION__);
  }

  switch (id) {
  case IP_EVENT_STA_GOT_IP:
    net->acquiredIP(data);
    break;

  default:
    ESP_LOGW(tagEngine(), "%s unhandled event id(0x%02x)", __PRETTY_FUNCTION__,
             id);
    break;
  }
}

// STATIC!!
void Net::wifi_events(void *ctx, esp_event_base_t base, int32_t id,
                      void *data) {

  Net_t *net = (Net_t *)ctx;

  if (ctx == nullptr) {
    ESP_LOGE(tagEngine(), "%s ctx==nullptr", __PRETTY_FUNCTION__);
  }

  switch (id) {
  case WIFI_EVENT_STA_START:
    ::tcpip_adapter_set_hostname(TCPIP_ADAPTER_IF_STA, "mcr");
    ::esp_wifi_connect();
    break;

  case WIFI_EVENT_STA_CONNECTED:
    net->connected(data);
    break;

  case WIFI_EVENT_STA_DISCONNECTED:
    net->disconnected(data);
    break;

  default:
    ESP_LOGW(tagEngine(), "%s unhandled event id(0x%02x)", __PRETTY_FUNCTION__,
             id);
    break;
  }
}

void Net::deinit() {
  instance()->reconnect_ = false;

  auto rc = ::esp_wifi_disconnect();
  ESP_LOGI(tagEngine(), "[%s] esp_wifi_disconnect()", esp_err_to_name(rc));
  vTaskDelay(pdMS_TO_TICKS(500));

  rc = ::esp_wifi_stop();
  ESP_LOGI(tagEngine(), "[%s] esp_wifi_stop()", esp_err_to_name(rc));
  vTaskDelay(pdMS_TO_TICKS(500));

  rc = ::esp_wifi_deinit();
  ESP_LOGI(tagEngine(), "[%s] esp_wifi_deinit()", esp_err_to_name(rc));
  vTaskDelay(pdMS_TO_TICKS(1000));
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

  if (init_rc_ == ESP_OK)
    return;

  ::tcpip_adapter_init();

  rc = ::esp_event_loop_create_default();
  checkError(__PRETTY_FUNCTION__, rc); // never returns if rc != ESP_OK

  wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();

  rc = ::esp_wifi_init(&cfg);
  checkError(__PRETTY_FUNCTION__, rc);

  rc = ::esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_events,
                                    instance());
  checkError(__PRETTY_FUNCTION__, rc);

  rc = ::esp_event_handler_register(IP_EVENT, ESP_EVENT_ANY_ID, &ip_events,
                                    instance());
  checkError(__PRETTY_FUNCTION__, rc);

  rc = ::esp_wifi_set_storage(WIFI_STORAGE_RAM);
  checkError(__PRETTY_FUNCTION__, rc);

  // finally, check the rc.  if any of the API calls above failed
  // the rc represents the error of the specific API.
  checkError(__PRETTY_FUNCTION__, rc);

  init_rc_ = rc;
}

void Net::ensureTimeIsSet() {
  // wait for time to be set
  struct timeval curr_time = {};
  int retry = 0;
  const int total_wait_ms = 30000;
  const int check_wait_ms = 100;
  const int retry_count = total_wait_ms / check_wait_ms;

  ESP_LOGI(tagEngine(), "waiting up to %dms (checking every %dms) for SNTP...",
           total_wait_ms, check_wait_ms);

  // continue to query the system time until seconds since epoch are
  // greater than a known recent time
  while ((curr_time.tv_sec < 1554830134) && (++retry < retry_count)) {
    if ((retry > (retry_count - 5)) || ((retry % 50) == 0)) {
      ESP_LOGW(tagEngine(), "waiting for SNTP... (%d/%d)", retry, retry_count);
    }
    statusLED::instance()->brighter();
    vTaskDelay(pdMS_TO_TICKS(check_wait_ms));
    statusLED::instance()->dimmer();
    gettimeofday(&curr_time, nullptr);
  }

  statusLED::instance()->brighter();

  if (retry == retry_count) {
    ESP_LOGE(tagEngine(), "timeout waiting for SNTP");
    checkError(__PRETTY_FUNCTION__, 0x1100FE);
  } else {
    const auto buf_len = 48;
    unique_ptr<char[]> buf(new char[buf_len]);
    auto str = buf.get();

    unique_ptr<struct tm> time_buf(new struct tm);
    auto timeinfo = time_buf.get();
    time_t now = time(nullptr);

    localtime_r(&now, timeinfo);
    strftime(str, buf_len, "%c %Z", timeinfo);

    xEventGroupSetBits(evg_, timeSetBit());
    ESP_LOGI(tagEngine(), "SNTP complete: %s", str);
  }
}

const string_t &Net::getName() {
  if (instance()->name_.length() == 0) {
    return macAddress();
  }

  return instance()->name_;
}

const string_t &Net::hostID() {
  static string_t _host_id;

  if (_host_id.length() == 0) {
    _host_id = "mcr.";
    _host_id += macAddress();
  }

  return _host_id;
}

const string_t &Net::macAddress() {
  static string_t _mac;

  // must wait for initialization of wifi before providing mac address
  waitForInitialization();

  if (_mac.length() == 0) {
    unique_ptr<char[]> buf(new char[24]);
    uint8_t mac[6] = {};

    esp_wifi_get_mac(WIFI_IF_STA, mac);

    sprintf(buf.get(), "%02x%02x%02x%02x%02x%02x", mac[0], mac[1], mac[2],
            mac[3], mac[4], mac[5]);

    // bytes << std::hex << std::setfill('0');
    // for (int i = 0; i <= 5; i++) {
    //   bytes << std::setw(sizeof(uint8_t) * 2) <<
    //   static_cast<unsigned>(mac[i]);
    // }
    //
    _mac = buf.get();
  }

  return _mac;
};

void Net::setName(const string_t name) {

  instance()->name_ = name;
  ESP_LOGI(tagEngine(), "mcp assigned name [%s]", instance()->name_.c_str());

  tcpip_adapter_set_hostname(TCPIP_ADAPTER_IF_STA, name.c_str());

  // tcpip_adapter_dhcpc_stop(TCPIP_ADAPTER_IF_STA);
  // tcpip_adapter_dhcpc_start(TCPIP_ADAPTER_IF_STA);

  xEventGroupSetBits(instance()->eventGroup(), nameBit());
}

bool Net::start() {
  esp_err_t rc = ESP_OK;
  init();

  rc = ::esp_wifi_set_mode(WIFI_MODE_STA);
  checkError(__PRETTY_FUNCTION__, rc);

  // auto powersave = WIFI_PS_NONE;
  auto powersave = WIFI_PS_MIN_MODEM;

  rc = ::esp_wifi_set_ps(powersave);
  checkError(__PRETTY_FUNCTION__, rc);
  ESP_LOGI(tagEngine(), "[%s] wifi powersave [%d]", esp_err_to_name(rc),
           powersave);

  rc = ::esp_wifi_set_protocol(
      WIFI_IF_STA, WIFI_PROTOCOL_11B | WIFI_PROTOCOL_11G | WIFI_PROTOCOL_11N);
  checkError(__PRETTY_FUNCTION__, rc);

  wifi_config_t cfg;
  ::bzero(&cfg, sizeof(cfg));
  cfg.sta.scan_method = WIFI_ALL_CHANNEL_SCAN;
  cfg.sta.sort_method = WIFI_CONNECT_AP_BY_SIGNAL;
  cfg.sta.bssid_set = 0;
  ::strncpy((char *)cfg.sta.ssid, CONFIG_WIFI_SSID, sizeof(cfg.sta.ssid));
  ::strncpy((char *)cfg.sta.password, CONFIG_WIFI_PASSWORD,
            sizeof(cfg.sta.password));

  rc = ::esp_wifi_set_config(WIFI_IF_STA, &cfg);
  checkError(__PRETTY_FUNCTION__, rc);

  // wifi is initialized so signal to processes waiting they can continue
  xEventGroupSetBits(evg_, initializedBit());

  ::esp_wifi_start();
  statusLED::instance()->brighter();

  ESP_LOGI(tagEngine(), "standing by for IP address...");
  if (waitForIP()) {
    sntp_setoperatingmode(SNTP_OPMODE_POLL);
    sntp_setservername(0, (char *)"ntp1.wisslanding.com");
    sntp_setservername(1, (char *)"ntp2.wisslanding.com");
    sntp_init();

    ensureTimeIsSet();

    // NOTE: once we've reached here the network is connected, ip address
    //       acquired and the time is set -- signal to other tasks
    //       we are ready for normal operations
    xEventGroupSetBits(evg_, (readyBit() | normalOpsBit()));
  } else {
    // reuse checkError for IP address failure
    checkError(__PRETTY_FUNCTION__, 0x1100FF);
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

// wait_ms defaults to UINT32_MAX
bool Net::waitForConnection(uint32_t wait_ms) {
  EventBits_t wait_bit = connectedBit();
  EventGroupHandle_t eg = instance()->eventGroup();
  uint32_t wait_ticks =
      (wait_ms == UINT32_MAX) ? portMAX_DELAY : pdMS_TO_TICKS(wait_ms);
  EventBits_t bits_set;

  // set status LED to 75% while waiting for WiFi
  statusLED::instance()->brighter();
  bits_set = xEventGroupWaitBits(eg, wait_bit, noClearBits(), waitAllBits(),
                                 wait_ticks);

  return (bits_set & wait_bit) ? true : false;
}

// wait_ms defaults to UINT32_MAX
bool Net::waitForInitialization(uint32_t wait_ms) {
  EventBits_t wait_bit = initializedBit();
  EventGroupHandle_t eg = instance()->eventGroup();
  uint32_t wait_ticks =
      (wait_ms == UINT32_MAX) ? portMAX_DELAY : pdMS_TO_TICKS(wait_ms);
  EventBits_t bits_set;

  bits_set = xEventGroupWaitBits(eg, wait_bit, noClearBits(), waitAllBits(),
                                 wait_ticks);

  return (bits_set & wait_bit) ? true : false;
}

// wait_ms defaults to 10 seconds
bool Net::waitForIP(uint32_t wait_ms) {
  EventBits_t wait_bit = ipBit();
  EventGroupHandle_t eg = instance()->eventGroup();
  uint32_t wait_ticks =
      (wait_ms == UINT32_MAX) ? portMAX_DELAY : pdMS_TO_TICKS(wait_ms);
  EventBits_t bits_set;

  bits_set = xEventGroupWaitBits(eg, wait_bit, noClearBits(), waitAllBits(),
                                 wait_ticks);

  return (bits_set & wait_bit) ? true : false;
}

// wait_ms defaults to zero
bool Net::waitForName(uint32_t wait_ms) {
  EventBits_t wait_bit = nameBit();
  EventGroupHandle_t eg = instance()->eventGroup();
  uint32_t wait_ticks =
      (wait_ms == UINT32_MAX) ? portMAX_DELAY : pdMS_TO_TICKS(wait_ms);
  EventBits_t bits_set;

  bits_set = xEventGroupWaitBits(eg, wait_bit, noClearBits(), waitAllBits(),
                                 wait_ticks);

  return (bits_set & wait_bit) ? true : false;
}

// wait_ms defaults to portMAX_DELAY when not passed
bool Net::waitForNormalOps(uint32_t wait_ms) {
  EventBits_t wait_bit = connectedBit() | transportBit() | normalOpsBit();
  EventGroupHandle_t eg = instance()->eventGroup();
  uint32_t wait_ticks =
      (wait_ms == UINT32_MAX) ? portMAX_DELAY : pdMS_TO_TICKS(wait_ms);
  EventBits_t bits_set;

  bits_set = xEventGroupWaitBits(eg, wait_bit, noClearBits(), waitAllBits(),
                                 wait_ticks);

  return (bits_set & wait_bit) ? true : false;
}

bool Net::isTimeSet() {
  EventBits_t wait_bit = timeSetBit();
  EventGroupHandle_t eg = instance()->eventGroup();
  uint32_t wait_ticks = 0;
  EventBits_t bits_set;

  // xEventGroupWaitBits returns the bits set in the event group even if
  // the wait times out (which we want in this case if it's not set)
  bits_set = xEventGroupWaitBits(eg, wait_bit, noClearBits(), waitAllBits(),
                                 wait_ticks);

  return (bits_set & wait_bit) ? true : false;
}

// intended use is to signal to tasks that require WiFi but not
// normalOps
// wait_ms defaults to portMAX_DELAY
bool Net::waitForReady(uint32_t wait_ms) {
  EventBits_t wait_bit = connectedBit() | ipBit() | readyBit();
  EventGroupHandle_t eg = instance()->eventGroup();
  uint32_t wait_ticks =
      (wait_ms == UINT32_MAX) ? portMAX_DELAY : pdMS_TO_TICKS(wait_ms);
  EventBits_t bits_set;

  bits_set = xEventGroupWaitBits(eg, wait_bit, noClearBits(), waitAllBits(),
                                 wait_ticks);

  return (bits_set & wait_bit) ? true : false;
}

// wait_ms defaults to portMAX_DELAY
bool Net::waitForTimeset(uint32_t wait_ms) {
  EventBits_t wait_bit = timeSetBit();
  EventGroupHandle_t eg = instance()->eventGroup();
  uint32_t wait_ticks =
      (wait_ms == UINT32_MAX) ? portMAX_DELAY : pdMS_TO_TICKS(wait_ms);
  EventBits_t bits_set;

  bits_set = xEventGroupWaitBits(eg, wait_bit, noClearBits(), waitAllBits(),
                                 wait_ticks);

  return (bits_set & wait_bit) ? true : false;
}

void Net::setTransportReady(bool val) {
  if (val) {
    xEventGroupSetBits(instance()->eventGroup(), transportBit());
  } else {
    xEventGroupClearBits(instance()->eventGroup(), transportBit());
  }
}
} // namespace mcr
