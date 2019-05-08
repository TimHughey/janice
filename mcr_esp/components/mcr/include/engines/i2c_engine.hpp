/*
    i2c.hpp - Master Control Remote I2C
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

#ifndef mcr_i2c_h
#define mcr_i2c_h

#include <cstdlib>
#include <string>

#include <driver/gpio.h>
#include <driver/i2c.h>
#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/task.h>
#include <sdkconfig.h>

#include "devs/addr.hpp"
#include "devs/i2c_dev.hpp"
#include "engines/engine.hpp"
#include "engines/i2c_engine.hpp"
#include "misc/mcr_types.hpp"
#include "protocols/mqtt.hpp"

namespace mcr {

typedef struct {
  TickType_t engine;
  TickType_t convert;
  TickType_t discover;
  TickType_t report;
} i2cLastWakeTime_t;

// I2C master will check ack from slave*
#define ACK_CHECK_EN (i2c_ack_type_t)0x1
// I2C master will not check ack from slave
#define ACK_CHECK_DIS (i2c_ack_type_t)0x0

#define SDA_PIN ((gpio_num_t)18)
#define SCL_PIN ((gpio_num_t)19)

#define RST_PIN GPIO_NUM_21
#define RST_PIN_SEL GPIO_SEL_21

typedef class mcrI2c mcrI2c_t;
class mcrI2c : public mcrEngine<i2cDev_t> {

private:
  mcrI2c();

public:
  static mcrI2c_t *instance();
  void run(void *data);

private:
  i2c_config_t _conf;
  const TickType_t _loop_frequency =
      pdMS_TO_TICKS(CONFIG_MCR_I2C_ENGINE_FREQUENCY_SECS * 1000);
  static const uint32_t _max_buses = 8;
  bool _use_multiplexer = false;
  i2cLastWakeTime_t _last_wake;

  uint32_t _bus_selects = 0;
  uint32_t _bus_select_errors = 0;
  const TickType_t _cmd_timeout = pdMS_TO_TICKS(1000);

  mcrDevAddr_t _mplex_addr = mcrDevAddr(0x70);
  i2cDev_t _multiplexer_dev = i2cDev(_mplex_addr);
  int _reset_pin_level = 0;

private:
  // array is zero terminated
  mcrDevAddr_t _search_addrs[5] = {{mcrDevAddr(0x44)},
                                   {mcrDevAddr(0x5C)},
                                   {mcrDevAddr(0x20)},
                                   {mcrDevAddr(0x36)},
                                   {mcrDevAddr(0x00)}};
  mcrDevAddr_t *search_addrs() { return _search_addrs; };
  inline uint32_t search_addrs_count() {
    return sizeof(_search_addrs) / sizeof(mcrDevAddr_t);
  };

  void discover(void *task_data);
  void report(void *task_data);

  // specific methods to read devices
  bool readAM2315(i2cDev_t *dev, bool wake = true);
  bool readMCP23008(i2cDev_t *dev);
  bool readSeesawSoil(i2cDev_t *dev);
  bool readSHT31(i2cDev_t *dev);

  // request data by sending command bytes and then reading the result
  // NOTE:  send and recv are executed as a single i2c transaction
  esp_err_t requestData(const char *TAG, i2cDev_t *dev, uint8_t *send,
                        uint8_t send_len, uint8_t *recv, uint8_t recv_len,
                        esp_err_t prev_esp_rc = ESP_OK, int timeout = 0);

  // utility methods
  esp_err_t busRead(i2cDev_t *dev, uint8_t *buff, uint32_t len,
                    esp_err_t prev_esp_rc = ESP_OK);
  esp_err_t busWrite(i2cDev_t *dev, uint8_t *buff, uint32_t len,
                     esp_err_t prev_esp_rc = ESP_OK);
  bool crcSHT31(const uint8_t *data);
  bool detectDevice(i2cDev_t *dev);
  bool detectDevicesOnBus(int bus);

  bool detectMultiplexer(const int max_attempts = 1);
  bool hardReset();
  bool installDriver();
  uint32_t maxBuses();
  bool useMultiplexer();
  bool selectBus(uint32_t bus);
  void printUnhandledDev(i2cDev_t *dev);

  bool wakeAM2315(i2cDev_t *dev);

  EngineTagMap_t &localTags() {
    static std::unordered_map<std::string, std::string> tag_map = {
        {"engine", "mcrI2c"},
        {"discover", "mcrI2c discover"},
        {"convert", "mcrI2c convert"},
        {"report", "mcrI2c report"},
        {"command", "mcrI2c command"},
        {"detect", "mcrI2c detectDev"},
        {"readAM2315", "mcrI2c readAM2315"},
        {"readMCP23008", "mcrI2c readMCP23008"},
        {"readSHT31", "mcrI2c readSHT31"},
        {"selectbus", "mcrI2c selectBus"}};

    ESP_LOGD(tag_map["engine"].c_str(), "tag_map sizeof=%u", sizeof(tag_map));
    return tag_map;
  }

  const char *tagSelectBus() {
    static const char *tag = nullptr;
    if (tag == nullptr) {
      tag = _tags["selectbus"].c_str();
    }
    return tag;
  }

  const char *tagDetectDev() {
    static const char *tag = nullptr;
    if (tag == nullptr) {
      tag = _tags["detect"].c_str();
    }
    return tag;
  }

  const char *tagReadAM2315() {
    static const char *tag = nullptr;
    if (tag == nullptr) {
      tag = _tags["readAM2315"].c_str();
    }
    return tag;
  }

  const char *tagReadMCP23008() {
    static const char *tag = nullptr;
    if (tag == nullptr) {
      tag = _tags["readMCP23008"].c_str();
    }
    return tag;
  }

  const char *tagReadSHT31() {
    static const char *tag = nullptr;
    if (tag == nullptr) {
      tag = _tags["readSHT31"].c_str();
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

#endif // mcr_i2c_h
