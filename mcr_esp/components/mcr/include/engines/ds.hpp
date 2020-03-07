/*
    mcrDS - Master Control Remote Dallas Semiconductor
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

#ifndef mcr_ds_engine_hpp
#define mcr_ds_engine_hpp

#include <cstdlib>
#include <map>
#include <string>

#include <driver/gpio.h>
#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/queue.h>
#include <freertos/task.h>
#include <sdkconfig.h>

#include "devs/ds_dev.hpp"
#include "drivers/owb.h"
// #include "drivers/owb_gpio.h"
#include "drivers/owb_rmt.h"
#include "engines/engine.hpp"

namespace mcr {

typedef class mcrDS mcrDS_t;
class mcrDS : public mcrEngine<dsDev_t> {

private:
  mcrDS();

public:
  static mcrDS_t *instance();

  //
  // Tasks
  //
  void command(void *data);
  void convert(void *data);
  void core(void *data);
  void discover(void *data);
  void report(void *data);

  void stop();

protected:
  bool resetBus(bool *present = nullptr);

private:
  uint8_t _pin = CONFIG_MCR_W1_PIN;
  OneWireBus *_ds = nullptr;

  bool _devices_powered = true;
  bool _temp_devices_present = true;

  // delay times
  const TickType_t _loop_frequency =
      pdMS_TO_TICKS(CONFIG_MCR_DS_ENGINE_FREQUENCY_SECS * 1000);
  const TickType_t _convert_frequency =
      pdMS_TO_TICKS(CONFIG_MCR_DS_CONVERT_FREQUENCY_SECS * 1000);
  const TickType_t _discover_frequency =
      pdMS_TO_TICKS(CONFIG_MCR_DS_DISCOVER_FREQUENCY_SECS * 1000);
  const TickType_t _report_frequency =
      pdMS_TO_TICKS(CONFIG_MCR_DS_REPORT_FREQUENCY_SECS * 1000);
  const TickType_t _temp_convert_wait =
      pdMS_TO_TICKS(CONFIG_MCR_DS_TEMP_CONVERT_POLL_MS);
  const uint64_t _max_temp_convert_us =
      (1000 * 1000); // one second in microsecs

  bool checkDevicesPowered();
  bool commandAck(cmdSwitch_t &cmd);

  bool devicesPowered() { return _devices_powered; }

  bool readDevice(dsDev_t *dev);

  // specific methods to read devices
  bool readDS1820(dsDev_t *dev, celsiusReading_t **reading);
  bool readDS2408(dsDev_t *dev, positionsReading_t **reading = nullptr);
  bool readDS2406(dsDev_t *dev, positionsReading_t **reading);
  bool readDS2413(dsDev_t *dev, positionsReading_t **reading);

  bool setDS2406(cmdSwitch_t &cmd, dsDev_t *dev);
  bool setDS2408(cmdSwitch_t &cmd, dsDev_t *dev);
  bool setDS2413(cmdSwitch_t &cmd, dsDev_t *dev);

  // FIXME:  hard code there are always temperature devices
  bool tempDevicesPresent() { return _temp_devices_present; }

  static bool check_crc16(const uint8_t *input, uint16_t len,
                          const uint8_t *inverted_crc, uint16_t crc = 0);
  static uint16_t crc16(const uint8_t *input, uint16_t len, uint16_t crc);

  void printInvalidDev(dsDev_t *dev);

  EngineTagMap_t &localTags() {
    static EngineTagMap_t tag_map = {{"engine", "mcrDS"},
                                     {"discover", "mcrDS discover"},
                                     {"convert", "mcrDS convert"},
                                     {"report", "mcrDS report"},
                                     {"command", "mcrDS command"},
                                     {"readDevice", "DS readDevice"},
                                     {"readDS1820", "mcrDS readDS1820"},
                                     {"readDS2406", "mcrDS readDS2406"},
                                     {"readDS2408", "mcrDS readDS2408"},
                                     {"readDS2413", "mcrDS readDS2413"},
                                     {"setDS2406", "mcrDS setDS2406"},
                                     {"setDS2408", "mcrDS setDS2408"},
                                     {"setDS2413", "mcrDS setDS2413"}};

    return tag_map;
  }

  const char *tagReadDevice() {
    static const char *tag = nullptr;
    if (tag == nullptr) {
      tag = _tags["readDevice"].c_str();
    }
    return tag;
  }

  const char *tagReadDS1820() {
    static const char *tag = nullptr;
    if (tag == nullptr) {
      tag = _tags["readDS1820"].c_str();
    }
    return tag;
  }

  const char *tagReadDS2406() {
    static const char *tag = nullptr;
    if (tag == nullptr) {
      tag = _tags["readDS2406"].c_str();
    }
    return tag;
  }

  const char *tagReadDS2408() {
    static const char *tag = nullptr;
    if (tag == nullptr) {
      tag = _tags["readDS2408"].c_str();
    }
    return tag;
  }

  const char *tagReadDS2413() {
    static const char *tag = nullptr;
    if (tag == nullptr) {
      tag = _tags["readDS2413"].c_str();
    }
    return tag;
  }

  const char *tagSetDS2406() {
    static const char *tag = nullptr;
    if (tag == nullptr) {
      tag = _tags["setDS2406"].c_str();
    }
    return tag;
  }

  const char *tagSetDS2408() {
    static const char *tag = nullptr;
    if (tag == nullptr) {
      tag = _tags["setDS2408"].c_str();
    }
    return tag;
  }

  const char *tagSetDS2413() {
    static const char *tag = nullptr;
    if (tag == nullptr) {
      tag = _tags["setDS2413"].c_str();
    }
    return tag;
  }
};
} // namespace mcr

#endif // mcr_ds_h
