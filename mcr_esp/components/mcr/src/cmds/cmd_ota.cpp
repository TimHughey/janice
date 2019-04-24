
#include <esp_http_client.h>
#include <esp_https_ota.h>
#include <esp_ota_ops.h>
#include <esp_partition.h>
#include <esp_spi_flash.h>

#include "cmds/cmd_ota.hpp"
#include "engines/ds_engine.hpp"
#include "engines/i2c_engine.hpp"
#include "misc/mcr_restart.hpp"
#include "net/mcr_net.hpp"
#include "protocols/mqtt.hpp"

static const char *TAG = "mcrCmdOTA";
static const char *k_host = "host";
static const char *k_head = "head";
static const char *k_stable = "stable";
static const char *k_delay_ms = "delay_ms";
static const char *k_part = "partition";
static const char *k_start_delay_ms = "start_delay_ms";
static const char *k_reboot_delay_ms = "reboot_delay_ms";
static const char *k_fw_url = "fw_url";

static bool _ota_in_progress = false;
static esp_err_t _ota_err = ESP_OK;
static float _ota_elapsed_sec = 0.0;

static char _shared_msg[128];

extern const uint8_t ca_start[] asm("_binary_ca_pem_start");
extern const uint8_t ca_end[] asm("_binary_ca_pem_end");

mcrCmdOTA::mcrCmdOTA(mcrCmdType_t type, JsonDocument &doc) : mcrCmd(type, doc) {
  if (doc.isNull() == false) {
    _host = doc[k_host] | "no_host";
    _head = doc[k_head] | "0000000";
    _stable = doc[k_stable] | "0000000";
    _partition = doc[k_part] | "ota";
    _fw_url = doc[k_fw_url] | "none";
    _delay_ms = doc[k_delay_ms] | 0;
    _start_delay_ms = doc[k_start_delay_ms] | 0;
    _reboot_delay_ms = doc[k_reboot_delay_ms] | 0;
  }
}

void mcrCmdOTA::begin() {
  const esp_partition_t *run_part = esp_ota_get_running_partition();
  esp_http_client_config_t config = {};
  config.url = _fw_url.c_str();
  config.cert_pem = (char *)ca_start;
  config.event_handler = mcrCmdOTA::httpEventHandler;
  config.timeout_ms = 1000;

  if (_ota_in_progress) {
    ESP_LOGI(TAG, "ota in-progress, ignoring spurious begin");
    return;
  }

  _ota_in_progress = true;
  mcrI2c::instance()->suspend();
  mcrDS::instance()->suspend();
  mcr::Net::suspendNormalOps();

  mcrMQTT::otaPrep();

  uint64_t ota_start_us = esp_timer_get_time();

  ESP_LOGI(TAG, "part(run) name(%-8s) addr(0x%x)", run_part->label,
           run_part->address);

  esp_err_t esp_rc = esp_https_ota(&config);
  _ota_elapsed_sec = (float)((esp_timer_get_time() - ota_start_us) / 1000000.0);

  if (esp_rc == ESP_OK) {
    snprintf(_shared_msg, sizeof(_shared_msg), "[%s] OTA elapsed(%0.2fs)",
             esp_err_to_name(esp_rc), _ota_elapsed_sec);

    ESP_LOGI(TAG, "%s", _shared_msg);

    mcrRestart::instance()->restart(_shared_msg, __PRETTY_FUNCTION__);
  } else {
    snprintf(_shared_msg, sizeof(_shared_msg), "[%s] OTA elapsed(%0.2fs)",
             esp_err_to_name(esp_rc), _ota_elapsed_sec);
    ESP_LOGE(TAG, "%s", _shared_msg);

    mcrRestart::instance()->restart(_shared_msg, __PRETTY_FUNCTION__);
  }
}

void mcrCmdOTA::end() {
  if (_ota_in_progress == false) {
    ESP_LOGI(TAG, "ota not in-progress, ignoring end");
    return;
  }

  mcrMQTT::otaFinish();

  if (_ota_err == ESP_OK) {
    mcrRestart::instance()->restart("ota success", __PRETTY_FUNCTION__);
  }

  _ota_in_progress = false;
}

bool mcrCmdOTA::process() {
  bool this_host = (_host.compare(mcr::Net::hostID()) == 0) ? true : false;

  if (this_host == false) {
    ESP_LOGI(TAG, "OTA command not for us, ignoring.");
    return true;
  }

  // 1. if _raw is nullptr then this is a cmd (not a data block)
  // 2. check this command is addressed to this host
  switch (type()) {

  case mcrCmdType::otaHTTPS:
    ESP_LOGI(TAG, "OTA via HTTPS requested");
    begin();
    break;

  case mcrCmdType::bootPartitionNext:
    ESP_LOGW(TAG, "boot.next no longer supported");
    break;

  case mcrCmdType::otabegin:
    ESP_LOGW(TAG, "ota.begin no longer supported");
    break;

  case mcrCmdType::otaend:
    ESP_LOGW(TAG, "ota.end no longer supported");
    break;

  case mcrCmdType::restart:
    mcrRestart::instance()->restart("mcp requested restart",
                                    __PRETTY_FUNCTION__);
    break;

  default:
    break;
  };

  return true;
}

const std::string mcrCmdOTA::debug() { return std::string(TAG); };

//
// STATIC!
//
esp_err_t mcrCmdOTA::httpEventHandler(esp_http_client_event_t *evt) {
  switch (evt->event_id) {
  case HTTP_EVENT_ERROR:
    ESP_LOGI(TAG, "HTTP_EVENT_ERROR");
    break;
  case HTTP_EVENT_ON_CONNECTED:
    ESP_LOGI(TAG, "HTTP_EVENT_ON_CONNECTED");
    break;
  case HTTP_EVENT_HEADER_SENT:
    ESP_LOGI(TAG, "HTTP_EVENT_HEADER_SENT");
    break;
  case HTTP_EVENT_ON_HEADER:
    ESP_LOGI(TAG, "HTTP_EVENT_ON_HEADER, key=%s, value=%s", evt->header_key,
             evt->header_value);
    break;
  case HTTP_EVENT_ON_DATA:
    ESP_LOGD(TAG, "HTTP_EVENT_ON_DATA, len=%d", evt->data_len);
    break;
  case HTTP_EVENT_ON_FINISH:
    ESP_LOGI(TAG, "HTTP_EVENT_ON_FINISH");
    break;
  case HTTP_EVENT_DISCONNECTED:
    ESP_LOGI(TAG, "HTTP_EVENT_DISCONNECTED");
    break;
  }
  return ESP_OK;
}
