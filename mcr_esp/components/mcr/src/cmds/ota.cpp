
#include <esp_http_client.h>
#include <esp_https_ota.h>
#include <esp_ota_ops.h>
#include <esp_partition.h>
#include <esp_spi_flash.h>

#include "cmds/ota.hpp"
#include "misc/elapsedMillis.hpp"
#include "misc/mcr_restart.hpp"
#include "net/mcr_net.hpp"
#include "protocols/mqtt.hpp"

namespace mcr {

static const char *TAG = "mcrCmdOTA";
static const char *k_host = "host";
static const char *k_reboot_delay_ms = "reboot_delay_ms";
static const char *k_fw_url = "fw_url";

static bool _ota_in_progress = false;

extern const uint8_t ca_start[] asm("_binary_ca_pem_start");
extern const uint8_t ca_end[] asm("_binary_ca_pem_end");

mcrCmdOTA::mcrCmdOTA(mcrCmdType_t type, JsonDocument &doc, elapsedMicros &e)
    : mcrCmd(type, doc, e) {
  if (doc.isNull() == false) {
    _host = doc[k_host] | "no_host";
    _fw_url = doc[k_fw_url] | "none";
    _reboot_delay_ms = doc[k_reboot_delay_ms] | 0;
  }
}

void mcrCmdOTA::doUpdate() {
  const esp_partition_t *run_part = esp_ota_get_running_partition();
  esp_http_client_config_t config = {};
  config.url = _fw_url.c_str();
  config.cert_pem = (char *)ca_start;
  config.event_handler = mcrCmdOTA::httpEventHandler;
  config.timeout_ms = 1000;

  if (_ota_in_progress) {
    ESP_LOGW(TAG, "ota in-progress, ignoring spurious begin");
    return;
  } else {
    textReading_t *rlog = new textReading_t;
    textReading_ptr_t rlog_ptr(rlog);

    rlog->printf("OTA begin part(run) name(%-8s) addr(0x%x)", run_part->label,
                 run_part->address);
    rlog->publish();
    ESP_LOGI(TAG, "%s", rlog->text());
  }

  _ota_in_progress = true;

  mcrMQTT::otaPrep();

  textReading_t *rlog = new textReading_t;
  textReading_ptr_t rlog_ptr(rlog);

  ramUtilReading_t_ptr ram(new ramUtilReading_t);
  ram->publish();

  // track the time it takes to perform ota
  elapsedMicros ota_elapsed;
  esp_err_t esp_rc = esp_https_ota(&config);

  rlog->printf("[%s] OTA elapsed(%0.2fs)", esp_err_to_name(esp_rc),
               ota_elapsed.asSeconds());

  ram->publish();

  if (esp_rc == ESP_OK) {
    ESP_LOGI(TAG, "%s", rlog->text());

  } else {
    ESP_LOGE(TAG, "%s", rlog->text());
  }

  mcrRestart::instance()->restart(rlog->text(), __PRETTY_FUNCTION__,
                                  reboot_delay_ms());
}

bool mcrCmdOTA::process() {
  using mcr::Net;

  bool this_host = (_host.compare(Net::hostID()) == 0) ? true : false;

  if (this_host == false) {
    ESP_LOGD(TAG, "OTA command not for us, ignoring.");
    return true;
  }

  // 1. if _raw is nullptr then this is a cmd (not a data block)
  // 2. check this command is addressed to this host
  switch (type()) {

  case mcrCmdType::otaHTTPS:
    ESP_LOGI(TAG, "OTA via HTTPS requested");
    doUpdate();
    break;

  case mcrCmdType::restart:
    mcrRestart::instance()->restart("restart requested", __PRETTY_FUNCTION__,
                                    reboot_delay_ms());
    break;

  default:
    ESP_LOGW(TAG, "unknown ota command, ignoring");
    break;
  };

  return true;
}

const unique_ptr<char[]> mcrCmdOTA::debug() {
  unique_ptr<char[]> debug_str(new char[strlen(TAG) + 1]);

  strcpy(debug_str.get(), TAG);

  return move(debug_str);
}

//
// STATIC!
//
esp_err_t mcrCmdOTA::httpEventHandler(esp_http_client_event_t *evt) {
  switch (evt->event_id) {
  case HTTP_EVENT_ERROR:
    // ESP_LOGD(TAG, "HTTP_EVENT_ERROR");
    break;
  case HTTP_EVENT_ON_CONNECTED:
    // ESP_LOGD(TAG, "HTTP_EVENT_ON_CONNECTED");
    break;
  case HTTP_EVENT_HEADER_SENT:
    // ESP_LOGD(TAG, "HTTP_EVENT_HEADER_SENT");
    break;
  case HTTP_EVENT_ON_HEADER:
    ESP_LOGI(TAG, "OTA HTTPS HEADER: key(%s), value(%s)", evt->header_key,
             evt->header_value);
    break;
  case HTTP_EVENT_ON_DATA:
    // ESP_LOGD(TAG, "HTTP_EVENT_ON_DATA, len=%d", evt->data_len);
    break;
  case HTTP_EVENT_ON_FINISH:
    // ESP_LOGD(TAG, "HTTP_EVENT_ON_FINISH");
    break;
  case HTTP_EVENT_DISCONNECTED:
    // ESP_LOGD(TAG, "HTTP_EVENT_DISCONNECTED");
    break;
  }
  return ESP_OK;
}
} // namespace mcr
