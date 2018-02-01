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
#include <cstring>

#include <FreeRTOS.h>
#include <System.h>
#include <Task.h>

#include <driver/gpio.h>
#include <esp_log.h>
#include <freertos/event_groups.h>
#include <freertos/queue.h>

#include "base.hpp"
#include "cmd.hpp"
#include "ds_dev.hpp"
#include "engine.hpp"
#include "mcr_types.hpp"
#include "mqtt.hpp"
#include "owb.h"
#include "owb_rmt.h"
#include "util.hpp"

#define mcr_ds_version_1 1

// Set the version of MCP Remote
#ifndef mcr_ds_version
#define mcr_ds_version mcr_ds_version_1
#endif

#define W1_PIN 14

typedef struct {
  TickType_t engine;
  TickType_t convert;
  TickType_t discover;
  TickType_t report;
} dsLastWakeTime_t;

typedef struct {
  void *cmd;
  void *convert;
  void *discover;
  void *report;
} dsTaskData_t;

typedef struct {
  TaskHandle_t cmd;
  TaskHandle_t convert;
  TaskHandle_t discover;
  TaskHandle_t report;
} dsTasks_t;

typedef struct {
  UBaseType_t engine;
  UBaseType_t cmd;
  UBaseType_t convert;
  UBaseType_t discover;
  UBaseType_t report;
} dsTaskPriority_t;

typedef struct {
  EventBits_t need_bus;
  EventBits_t engine_running;
  EventBits_t devices_available;
  EventBits_t temp_available;
} dsEventBits_t;

typedef class mcrDS mcrDS_t;
class mcrDS : public mcrEngine, public Task {

public:
  mcrDS(mcrMQTT *mqtt, EventGroupHandle_t evg, int bit);
  void run(void *data);

private:
  OneWireBus *ds = nullptr;
  EventGroupHandle_t _ev_group;
  int _wait_bit;
  EventGroupHandle_t _ds_evg;
  dsEventBits_t _event_bits = {.need_bus = BIT0,
                               .engine_running = BIT1,
                               .devices_available = BIT2,
                               .temp_available = BIT3};

  SemaphoreHandle_t _bus_mutex = nullptr;
  const int _max_queue_len = 30;
  QueueHandle_t _cmd_q = nullptr;
  dsLastWakeTime_t _last_wake;

  dsTaskPriority_t _task_pri = {
      .engine = 1, .cmd = 14, .convert = 13, .discover = 12, .report = 13};
  dsTaskData_t _task_data;
  dsTasks_t _tasks;

  bool _devices_powered = true;
  bool _temp_devices_present = true;

  // task data
  void *_handle_cmd_task_data = nullptr;

  // delay times
  const TickType_t _loop_frequency = pdMS_TO_TICKS(1000);
  const TickType_t _convert_frequency = pdMS_TO_TICKS(7 * 1000);
  const TickType_t _discover_frequency = pdMS_TO_TICKS(30 * 1000);
  const TickType_t _temp_convert_wait = pdMS_TO_TICKS(5);

  // static entry point to tasks
  static void runConvert(void *data);
  static void runDiscover(void *data);
  static void runCommand(void *data);
  static void runReport(void *data);

  // dsDev_t *dsDevGetDevice(mcrDevID_t &id);
  dsDev_t *getDeviceByCmd(mcrCmd_t &cmd);
  dsDev_t *getDeviceByCmd(mcrCmd_t *cmd);
  void setCmdAck(mcrCmd_t &cmd);

  // tasks
  void discover(void *data);
  void convert(void *data);
  void report(void *data);
  void command(void *data);

  bool checkDevicesPowered();
  bool commandAck(mcrCmd_t &cmd);

  bool devicesPowered() { return _devices_powered; }

  // accept a mcrCmd_t as input to reportDevice
  bool readDevice(mcrCmd_t &cmd);
  bool readDevice(mcrDevID_t &id);
  bool readDevice(dsDev_t *dev);

  // publish a device
  bool publishDevice(mcrCmd_t &cmd);
  bool publishDevice(mcrDevID_t &id);
  bool publishDevice(dsDev_t *dev);

  // specific methods to read devices
  bool readDS1820(dsDev *dev, celsiusReading_t **reading);
  bool readDS2408(dsDev *dev, positionsReading_t **reading = nullptr);
  bool readDS2406(dsDev *dev, positionsReading_t **reading);

  bool setDS2406(mcrCmd_t &cmd, dsDev_t *dev);
  bool setDS2408(mcrCmd_t &cmd, dsDev_t *dev);

  // FIXME:  hard code there are always temperature devices
  bool tempDevicesPresent() { return _temp_devices_present; }

  static bool check_crc16(const uint8_t *input, uint16_t len,
                          const uint8_t *inverted_crc, uint16_t crc = 0);
  static uint16_t crc16(const uint8_t *input, uint16_t len, uint16_t crc);

  void printInvalidDev(dsDev *dev);
};

#endif // mcr_ds_h
