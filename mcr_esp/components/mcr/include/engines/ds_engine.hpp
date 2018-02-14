/*
    mcr_ds.h - Master Control Remote Dallas Semiconductor
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

#ifndef mcr_ds_engine_h
#define mcr_ds_engine_h

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

#include "cmds/cmd.hpp"
#include "devs/ds_dev.hpp"
#include "drivers/owb.h"
#include "drivers/owb_rmt.h"
#include "engines/engine.hpp"
#include "misc/util.hpp"
#include "protocols/mqtt.hpp"

#define mcr_ds_version_1 1

// Set the version of MCP Remote
#ifndef mcr_ds_version
#define mcr_ds_version mcr_ds_version_1
#endif

#define W1_PIN 14

typedef struct {
  EventBits_t need_bus;
  EventBits_t engine_running;
  EventBits_t devices_available;
  EventBits_t temp_available;
  EventBits_t temp_sensors_available;
} dsEventBits_t;

typedef class mcrDS mcrDS_t;
class mcrDS : public mcrEngine<dsDev_t> {

public:
  mcrDS();
  void run(void *data);

private:
  OneWireBus *ds = nullptr;
  EventGroupHandle_t _ds_evg;
  dsEventBits_t _event_bits = {.need_bus = BIT0,
                               .engine_running = BIT1,
                               .devices_available = BIT2,
                               .temp_available = BIT3,
                               .temp_sensors_available = BIT4};

  SemaphoreHandle_t _bus_mutex = nullptr;
  const int _max_queue_len = 30;
  QueueHandle_t _cmd_q = nullptr;
  mcrTask_t _engineTask = {.handle = nullptr,
                           .data = nullptr,
                           .lastWake = 0,
                           .priority = 1,
                           .stackSize = (2 * 1024)};

  mcrTask_t _cmdTask = {.handle = nullptr,
                        .data = nullptr,
                        .lastWake = 0,
                        .priority = 14,
                        .stackSize = (3 * 1024)};
  mcrTask_t _convertTask = {.handle = nullptr,
                            .data = nullptr,
                            .lastWake = 0,
                            .priority = 13,
                            .stackSize = (3 * 1024)};

  mcrTask_t _discoverTask = {.handle = nullptr,
                             .data = nullptr,
                             .lastWake = 0,
                             .priority = 12,
                             .stackSize = (4 * 1024)};

  mcrTask_t _reportTask = {.handle = nullptr,
                           .data = nullptr,
                           .lastWake = 0,
                           .priority = 13,
                           .stackSize = (3 * 1024)};

  bool _devices_powered = true;
  bool _temp_devices_present = true;

  // task data
  void *_handle_cmd_task_data = nullptr;

  // delay times
  const TickType_t _loop_frequency = pdMS_TO_TICKS(30 * 1000);
  const TickType_t _convert_frequency = pdMS_TO_TICKS(7 * 1000);
  const TickType_t _discover_frequency = pdMS_TO_TICKS(30 * 1000);
  const TickType_t _report_frequency = pdMS_TO_TICKS(7 * 1000);
  const TickType_t _temp_convert_wait = pdMS_TO_TICKS(50);
  const uint64_t _max_temp_convert_us =
      (1000 * 1000); // one second in microsecs

  // static entry point to tasks
  static void runConvert(void *data);
  static void runDiscover(void *data);
  static void runCommand(void *data);
  static void runReport(void *data);

  // tasks
  void discover(void *data);
  void convert(void *data);
  void report(void *data);
  void command(void *data);

  bool checkDevicesPowered();
  bool commandAck(mcrCmd_t &cmd);

  bool devicesPowered() { return _devices_powered; }

  // accept a mcrCmd_t as input to reportDevice
  // bool readDevice(mcrCmd_t &cmd);
  // bool readDevice(const mcrDevID_t &id);
  bool readDevice(dsDev_t *dev);

  // specific methods to read devices
  bool readDS1820(dsDev_t *dev, celsiusReading_t **reading);
  bool readDS2408(dsDev_t *dev, positionsReading_t **reading = nullptr);
  bool readDS2406(dsDev_t *dev, positionsReading_t **reading);

  bool setDS2406(mcrCmd_t &cmd, dsDev_t *dev);
  bool setDS2408(mcrCmd_t &cmd, dsDev_t *dev);

  // FIXME:  hard code there are always temperature devices
  bool tempDevicesPresent() { return _temp_devices_present; }

  static bool check_crc16(const uint8_t *input, uint16_t len,
                          const uint8_t *inverted_crc, uint16_t crc = 0);
  static uint16_t crc16(const uint8_t *input, uint16_t len, uint16_t crc);

  void printInvalidDev(dsDev_t *dev);

  mcrEngineTagMap_t &localTags() {
    static std::map<std::string, std::string> tag_map = {
        {"engine", "mcrDS"},
        {"discover", "mcrDS discover"},
        {"convert", "mcrDS convert"},
        {"report", "mcrDS report"},
        {"command", "mcrDS command"},
        {"readDS1820", "mcrDS readDS1820"},
        {"readDS2406", "mcrDS readDS2406"},
        {"readDS2408", "mcrDS readDS2408"},
        {"setDS2406", "mcrDS setDS2406"},
        {"setDS2408", "mcrDS setDS2408"}};

    ESP_LOGI(tag_map["engine"].c_str(), "tag_map sizeof=%u", sizeof(tag_map));
    return tag_map;
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
};

#endif // mcr_ds_h
