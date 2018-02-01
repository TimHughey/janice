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
#include <cstring>

#include "sdkconfig.h"
#include <FreeRTOS.h>
#include <System.h>
#include <Task.h>
#include <WiFi.h>
#include <WiFiEventHandler.h>
#include <cJSON.h>
#include <driver/i2c.h>
#include <esp_log.h>
#include <freertos/event_groups.h>
#include <gpio.h>

#include "addr.hpp"
#include "engine.hpp"
#include "i2c_dev.hpp"
#include "i2c_engine.hpp"
#include "id.hpp"
#include "mongoose.h"
#include "mqtt.hpp"
#include "readings.hpp"
#include "util.hpp"

#define mcr_i2c_version_1 1

typedef struct {
  TickType_t engine;
  TickType_t convert;
  TickType_t discover;
  TickType_t report;
} i2cLastWakeTime_t;

// Set the version of MCP Remote
#ifndef mcr_i2c_version
#define mcr_i2c_version mcr_i2c_version_1
#endif

// I2C master will check ack from slave*
#define ACK_CHECK_EN (i2c_ack_type_t)0x1
// I2C master will not check ack from slave
#define ACK_CHECK_DIS (i2c_ack_type_t)0x0
// I2C ack value
#define ACK_VAL (i2c_ack_type_t)0x0
// I2C nack value
#define NACK_VAL (i2c_ack_type_t)0x1

#define SDA_PIN (gpio_num_t)18
#define SCL_PIN (gpio_num_t)19
#define I2C_PWR_PIN (gpio_num_t)12
#define MAX_DEV_NAME 20

typedef class mcrI2c mcrI2c_t;
class mcrI2c : public mcrEngine, public Task {
private:
  static const uint32_t _max_buses = 8;
  bool _use_multiplexer = false;
  EventGroupHandle_t _ev_group;
  int _wait_bit;
  i2cLastWakeTime_t _last_wake;

  const TickType_t _loop_frequency = pdMS_TO_TICKS(10000);

public:
  mcrI2c(mcrMQTT *mqtt, EventGroupHandle_t evg, int bit);
  void run(void *data);

private:
  mcrDevAddr_t _search_addrs[3] = {mcrDevAddr(0x44), mcrDevAddr(0x5C),
                                   mcrDevAddr(0x00)};
  mcrDevAddr_t *search_addrs() { return _search_addrs; };
  inline uint32_t search_addrs_count() {
    return sizeof(_search_addrs) / sizeof(mcrDevAddr_t);
  };

  void discover(void *task_data);
  void report(void *task_data);

  // specific methods to read devices
  bool readAM2315(i2cDev_t *dev, humidityReading_t **reading, bool wake = true);
  bool readSHT31(i2cDev_t *dev, humidityReading_t **reading);

  // utility methods
  uint32_t crcSHT31(const uint8_t *data, uint32_t len);
  bool detectDevice(mcrDevAddr_t &addr);
  bool detectDevicesOnBus(int bus);

  bool detectMultiplexer();
  uint32_t maxBuses();
  bool useMultiplexer();
  void selectBus(uint32_t bus);
  void printUnhandledDev(i2cDev_t *dev);
  void wakeAM2315(mcrDevAddr_t &addr);
};

#endif // mcr_i2c_h
