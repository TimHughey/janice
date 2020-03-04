/*
    pwm_engine.hpp - Master Control Remote PWM Engine
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

#ifndef mcr_pwm_engine_hpp
#define mcr_pwm_engine_hpp

#include <cstdlib>
#include <string>

#include <driver/gpio.h>
#include <driver/ledc.h>
#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/task.h>
#include <sdkconfig.h>

#include "devs/addr.hpp"
#include "devs/pwm_dev.hpp"
#include "engines/engine.hpp"
#include "misc/hw_config.hpp"
#include "misc/mcr_types.hpp"
#include "protocols/mqtt.hpp"
#include "readings/readings.hpp"

namespace mcr {

typedef struct {
  TickType_t engine;
  TickType_t convert;
  TickType_t discover;
  TickType_t report;
} pwmLastWakeTime_t;

typedef class pwmEngine pwmEngine_t;
class pwmEngine : public mcrEngine<pwmDev_t> {

private:
  pwmEngine();

  bool commandAck(cmdPWM_t &cmd);

public:
  static pwmEngine_t *instance();

  bool shouldStart() { return hwConfig::havePWM(); };

  //
  // Tasks
  //
  void command(void *data);
  void core(void *data);
  void discover(void *data);
  void report(void *data);

  void stop();

private:
  const TickType_t _loop_frequency = pdMS_TO_TICKS(10000);
  const TickType_t _discover_frequency = pdMS_TO_TICKS(59000);
  const TickType_t _report_frequency = pdMS_TO_TICKS(10000);

  pwmLastWakeTime_t _last_wake;

private:
  // generic read device that will call the specific methods
  bool readDevice(pwmDev_t *dev);

  bool configureTimer();
  bool detectDevice(pwmDev_t *dev);

  void printUnhandledDev(pwmDev_t *dev);

  EngineTagMap_t &localTags() {
    static std::unordered_map<string_t, string_t> tag_map = {
        {"engine", "mPWM"},      {"discover", "mPWM_dis"},
        {"convert", "mPWM_cvt"}, {"report", "mPWM_rep"},
        {"command", "mPWM_cmd"}, {"detect", "mPWM_det"}};

    ESP_LOGD(tag_map["engine"].c_str(), "tag_map sizeof=%u", sizeof(tag_map));
    return tag_map;
  }

  ledc_channel_t mapToChannel(uint8_t num);

  const char *tagDetectDev() {
    static const char *tag = nullptr;
    if (tag == nullptr) {
      tag = _tags["detect"].c_str();
    }
    return tag;
  }

  const char *espError(esp_err_t esp_rc) {
    static char catch_all[25] = {0x00};

    bzero(catch_all, sizeof(catch_all));

    switch (esp_rc) {
    case ESP_OK:
      return (const char *)"ESP_OK";
      break;
    case ESP_FAIL:
      return (const char *)"ESP_FAIL";
      break;
    case ESP_ERR_TIMEOUT:
      return (const char *)"ESP_ERROR_TIMEOUT";
      break;
    default:
      snprintf(catch_all, sizeof(catch_all), "err=0x%04x", esp_rc);
      break;
    }

    return catch_all;
  }
};
} // namespace mcr

#endif // pwm_engine_hpp
