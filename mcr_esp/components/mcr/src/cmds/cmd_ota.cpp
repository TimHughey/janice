
#include <esp_ota_ops.h>
#include <esp_partition.h>
#include <esp_spi_flash.h>

#include "cmds/cmd_ota.hpp"
#include "net/mcr_net.hpp"
#include "protocols/mqtt.hpp"

static const char *TAG = "mcrCmdOTA";
static const char *k_host = "host";
static const char *k_head = "head";
static const char *k_stable = "stable";
static const char *k_delay_ms = "delay_ms";
static const char *k_part = "partition";

static esp_ota_handle_t _ota_update = 0;
static const esp_partition_t *_update_part = nullptr;
static esp_err_t _ota_err = ESP_OK;
static size_t _ota_size = 0;
static uint64_t _ota_first_block = 0;
static uint64_t _ota_last_block = 0;
static uint64_t _ota_total_us = 0;

mcrCmdOTA::mcrCmdOTA(mcrCmdType_t type, JsonObject &root) : mcrCmd(type, root) {
  if (root.success()) {
    _host = root[k_host] | "no_host";
    _head = root[k_head] | "0000000";
    _stable = root[k_stable] | "0000000";
    _delay_ms = root[k_delay_ms] | 0;
    _partition = root[k_part] | "ota";
  }
}

void mcrCmdOTA::begin() {
  const esp_partition_t *boot_part = esp_ota_get_boot_partition();
  const esp_partition_t *run_part = esp_ota_get_running_partition();

  if (_ota_update != 0) {
    ESP_LOGW(TAG, "ota already in-progress, ignoring spurious begin");
    return;
  }

  mcr::Net::suspendNormalOps();

  mcrMQTT::otaPrep();

  if (_partition.compare("ota") == 0) {
    _update_part = esp_ota_get_next_update_partition(nullptr);
  } else {
    const esp_partition_t *part = nullptr;
    part = esp_partition_find_first(ESP_PARTITION_TYPE_APP,
                                    ESP_PARTITION_SUBTYPE_APP_FACTORY,
                                    _partition.c_str());

    if (part == nullptr) {
      ESP_LOGW(TAG, "part %s not found, won't begin ota", _partition.c_str());
    } else {
      _update_part = part;
    }
  }

  ESP_LOGI(TAG, "( boot ) part: name=%-8s addr=0x%x", boot_part->label,
           boot_part->address);
  ESP_LOGI(TAG, "( run  ) part: name=%-8s addr=0x%x", run_part->label,
           run_part->address);
  ESP_LOGI(TAG, "(update) part: name=%-8s addr=0x%x", _update_part->label,
           _update_part->address);

  _ota_err = esp_ota_begin(_update_part, OTA_SIZE_UNKNOWN, &_ota_update);
  if (_ota_err != ESP_OK) {
    ESP_LOGE(TAG, "esp_ota_begin failed, error=0x%02x", _ota_err);
  }
}

void mcrCmdOTA::bootFactoryNext() {
  esp_err_t err = ESP_OK;
  const esp_partition_t *part = nullptr;

  part = esp_partition_find_first(ESP_PARTITION_TYPE_APP,
                                  ESP_PARTITION_SUBTYPE_APP_FACTORY, nullptr);

  if (part && ((err = esp_ota_set_boot_partition(part)) == ESP_OK)) {
    ESP_LOGI(TAG, "next boot part label=%-8s addr=0x%x", part->label,
             part->address);
  } else {
    ESP_LOGE(TAG, "unable to set factory boot err=0x%02x", err);
  }
}

void mcrCmdOTA::end() {

  if (_ota_update == 0) {
    ESP_LOGW(TAG, "ota not in-progress, ignoring spurious end");
    return;
  }

  mcrMQTT::otaFinish();

  if (_ota_err != ESP_OK) {
    ESP_LOGE(TAG, "error 0x%02x during OTA update", _ota_err);
    return;
  }

  ESP_LOGI(TAG, "finalize ota (size=%uk,elapsed_ms=%llums)", (_ota_size / 1024),
           (_ota_total_us / 1000));

  if (_ota_err == ESP_OK) {
    ESP_LOGI(TAG, "next boot part label=%-8s addr=0x%x", _update_part->label,
             _update_part->address);
    ESP_LOGI(TAG, "will restart in 5s");
    vTaskDelay(pdMS_TO_TICKS(5000));
    ESP_LOGI(TAG, "JUMP!");
    esp_restart();
  }

  if (_ota_err != ESP_OK) {
    ESP_LOGE(TAG, "error 0x%02x while setting boot part", _ota_err);
  }

  _ota_update = 0; // flag that the ota_update is not in-progress
}

bool mcrCmdOTA::process() {
  bool this_host = (_host.compare(mcr::Net::hostID()) == 0) ? true : false;

  // 1. if _raw is nullptr then this is a cmd (not a data block)
  // 2. check this command is addressed to this host
  if (_raw == nullptr) {
    switch (type()) {

    case mcrCmdType::bootfactorynext:
      if (this_host) {
        bootFactoryNext();
      }
      break;

    case mcrCmdType::otabegin:
      if (this_host) {
        ESP_LOGI(TAG, "preparing for ota in %dms", _delay_ms);
        begin();
      }
      break;

    case mcrCmdType::otaend:
      end();
      break;

    case mcrCmdType::restart:
      if (this_host) {
        ESP_LOGI(TAG, "JUMP!");
        vTaskDelay(pdMS_TO_TICKS(_delay_ms));
        esp_restart();
      }
      break;

    default:
      break;
    };
  } else { // raw data block
    processBlock();
  }

  return true;
}

void mcrCmdOTA::processBlock() {
  char flags = _raw->at(0);
  size_t len = _raw->size();
  size_t block_size = len - 1;
  const void *ota_data = (_raw->data() + 1); // skip flag byte

  // safety check, if _ota_update isn't set then something is wrong
  if (_ota_update == 0)
    return;

  switch (type()) {
  case mcrCmdType::otabegin:
    ESP_LOGI(TAG, "ota first block received");
    _ota_size = block_size;
    _ota_first_block = esp_timer_get_time();

    _ota_err = esp_ota_write(_ota_update, ota_data, len - 1);
    break;

  case mcrCmdType::otacontinue:
    _ota_size += block_size;
    _ota_err = esp_ota_write(_ota_update, ota_data, len - 1);
    break;

  case mcrCmdType::otaend:
    _ota_size += block_size;
    _ota_err = esp_ota_write(_ota_update, ota_data, len - 1);
    _ota_last_block = esp_timer_get_time();
    _ota_total_us = _ota_last_block - _ota_first_block;

    if (_ota_err == ESP_OK) {
      _ota_err = esp_ota_end(_ota_update);

      if (_ota_err == ESP_OK) {
        _ota_err = esp_ota_set_boot_partition(_update_part);
      }
    }

    ESP_LOGI(TAG, "ota last block processed");
    break;

  default:
    ESP_LOGW(TAG, "unknown flag (0x%02x) on ota block", flags);
  }
}

const std::string mcrCmdOTA::debug() { return std::string(TAG); };
