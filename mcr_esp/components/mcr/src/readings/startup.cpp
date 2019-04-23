/*
    startup_reading.cpp - Master Control Remote Startup Reading
    Copyright (C) 2017  Tim Hughey

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    https://www.wisslanding.com
*/

#include <cstdlib>
#include <ctime>

#include <esp_log.h>
#include <esp_ota_ops.h>

#include "readings/startup.hpp"

startupReading::startupReading(uint32_t batt_mv) : remoteReading(batt_mv) {
  app_desc_ = esp_ota_get_app_description();

  type_ = std::string("boot");
  reset_reason_ = decodeResetReason(esp_reset_reason());

  ESP_LOGI("mcrStartup", "reason [%s]", reset_reason_.c_str());
};

void startupReading::populateJSON(JsonObject &root) {
  char magic_word[] = "0x00000000";
  char sha256[12] = {};

  remoteReading::populateJSON(root);

  snprintf(magic_word, sizeof(magic_word), "0x%ux", app_desc_->magic_word);
  esp_ota_get_app_elf_sha256(sha256, sizeof(sha256));

  root["reset_reason"] = reset_reason_.c_str();
  root["hw"] = "esp32";
  root["mword"] = magic_word;
  root["svsn"] = app_desc_->secure_version;
  root["vsn"] = app_desc_->version;
  root["proj"] = app_desc_->project_name;
  root["btime"] = app_desc_->time;
  root["bdate"] = app_desc_->date;
  root["idf"] = app_desc_->idf_ver;
  root["sha"] = sha256;
};

const std::string &
startupReading::decodeResetReason(esp_reset_reason_t reason) {
  static std::string _reason;

  switch (reason) {
  case ESP_RST_UNKNOWN:
    _reason = "unknown";
    break;

  case ESP_RST_POWERON:
    _reason = "power on";
    break;

  case ESP_RST_EXT:
    _reason = "external pin";
    break;
  case ESP_RST_SW:
    _reason = "esp_restart()";
    break;

  case ESP_RST_PANIC:
    _reason = "software panic";
    break;

  case ESP_RST_INT_WDT:
    _reason = "interrupt watchdog";
    break;

  case ESP_RST_TASK_WDT:
    _reason = "task watchdog";
    break;

  case ESP_RST_WDT:
    _reason = "other watchdog";
    break;

  case ESP_RST_DEEPSLEEP:
    _reason = "exit deep sleep";
    break;

  case ESP_RST_BROWNOUT:
    _reason = "brownout";
    break;

  case ESP_RST_SDIO:
    _reason = "SDIO";

  default:
    _reason = "undefined";
  }

  return _reason;
}
