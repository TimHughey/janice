/*
     mcpr_i2c.cpp - Master Control Remote I2C
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

     AM2315 code was based on Matt Heitzenroder's Arduino library
     with portions of his code inspired by Joehrg Ehrsam's am2315-python-api
     code (http://code.google.com/p/am2315-python-api/) and
     Sopwith's library (http://sopwith.ismellsmoke.net/?p=104).

     https://www.wisslanding.com
 */

// #define VERBOSE 1

#include <cstdlib>
#include <string>

#include <FreeRTOS.h>
#include <System.h>
#include <Task.h>
#include <sdkconfig.h>
// #include <WiFi.h>
// #include <WiFiEventHandler.h>
#include <driver/i2c.h>
#include <esp_log.h>
#include <freertos/event_groups.h>

#include "addr.hpp"
#include "engine.hpp"
#include "i2c_dev.hpp"
#include "i2c_engine.hpp"
#include "id.hpp"
#include "mqtt.hpp"
#include "readings.hpp"
#include "util.hpp"

static const char engTAG[] = "mcrI2c";
static const char disTAG[] = "mcrI2c discover";
static const char detTAG[] = "mrcI2c detectDev";
static const char readAM2315TAG[] = "mcrI2c readAM2315";
static const char readSHT31TAG[] = "mcrI2c readSHT31";
static const char repTAG[] = "mrcI2c report";
static const char selTAG[] = "mrcI2c selectBus";

mcrI2c::mcrI2c(mcrMQTT_t *mqtt, EventGroupHandle_t evg, int bit)
    : Task(engTAG, 5 * 1024, 10) {
  _mqtt = mqtt;
  _ev_group = evg;
  _wait_bit = bit;
  _engTAG = engTAG;

  esp_log_level_t log_level = ESP_LOG_WARN;
  const char *log_tags[] = {disTAG,        detTAG,       repTAG, selTAG,
                            readAM2315TAG, readSHT31TAG, nullptr};

  for (int i = 0; log_tags[i] != nullptr; i++) {
    ESP_LOGI(engTAG, "%s logging at level=%d", log_tags[i], log_level);
    esp_log_level_set(log_tags[i], log_level);
  }

  // TODO: do we need to assign a GPIO to power up the i2c devices?
  // power up the i2c devices
  // pinMode(I2C_PWR_PIN, OUTPUT);
  // digitalWrite(I2C_PWR_PIN, HIGH);
}

uint32_t mcrI2c::crcSHT31(const uint8_t *data, uint32_t len) {
  uint8_t crc = 0xFF;

  for (uint32_t j = len; j; --j) {
    crc ^= *data++;

    for (uint32_t i = 8; i; --i) {
      crc = (crc & 0x80) ? (crc << 1) ^ 0x31 : (crc << 1);
    }
  }
  return crc;
}

bool mcrI2c::detectDevice(mcrDevAddr_t &addr) {
  bool rc = false;
  i2c_cmd_handle_t cmd = nullptr;
  esp_err_t esp_rc = ESP_FAIL;
  uint8_t sht31_cmd_data[] = {0x30, // soft-reset
                              0xa2};

  ESP_LOGD(detTAG, "looking for %s", addr.debug().c_str());

  // handle special cases where certain i2c devices
  // need additional cmds before releasing the bus
  switch (addr.firstAddressByte()) {

  // TCA9548B - TI i2c bus multiplexer
  case 0x70:
    cmd = i2c_cmd_link_create();
    i2c_master_start(cmd);
    i2c_master_write_byte(
        cmd, (addr.firstAddressByte() << 1) | I2C_MASTER_WRITE, ACK_CHECK_EN);
    i2c_master_write_byte(cmd, 0x00, ACK_CHECK_EN); // 0x00 selects no bus
    i2c_master_stop(cmd);

    esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, pdMS_TO_TICKS(1000));
    i2c_cmd_link_delete(cmd);
    break;

  // SHT-31 humidity sensor
  case 0x44:
    cmd = i2c_cmd_link_create();
    i2c_master_start(cmd);
    i2c_master_write_byte(
        cmd, (addr.firstAddressByte() << 1) | I2C_MASTER_WRITE, ACK_CHECK_EN);
    i2c_master_write_byte(cmd, sht31_cmd_data[0], ACK_CHECK_EN);
    i2c_master_write_byte(cmd, sht31_cmd_data[1], ACK_CHECK_EN);
    i2c_master_stop(cmd);

    esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, pdMS_TO_TICKS(1000));
    i2c_cmd_link_delete(cmd);
    break;

  // AM2315 needs to be woken up
  case 0x5C:
    wakeAM2315(addr);

    cmd = i2c_cmd_link_create();
    i2c_master_start(cmd);
    i2c_master_write_byte(
        cmd, (addr.firstAddressByte() << 1) | I2C_MASTER_WRITE, ACK_CHECK_EN);
    i2c_master_stop(cmd);
    esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, pdMS_TO_TICKS(1000));
    i2c_cmd_link_delete(cmd);

    break;
  }

  switch (esp_rc) {
  case ESP_OK:
    rc = true; // device acknowledged the transmission
    break;

  default:
    ESP_LOGD(engTAG, "%s not found (esp_rc=0x%02x)", addr.debug().c_str(),
             esp_rc);
  }

  return rc;
}

int mcrI2c::detectDevicesOnBus(int bus) {
  int found = 0;
  mcrDevAddr_t *addrs = search_addrs();

  for (uint8_t i = 0; addrs[i].isValid(); i++) {
    mcrDevAddr_t &search_addr = addrs[i];

    if (selectBus(bus)) {
      if (detectDevice(search_addr)) {
        found++;
        i2cDev_t dev(search_addr, useMultiplexer(), bus);

        if (i2cDev_t *found = (i2cDev_t *)justSeenDevice(dev)) {
          ESP_LOGD(disTAG, "previously seen %s", found->debug().c_str());
        } else { // device was not known, must add
          i2cDev_t *new_dev = new i2cDev(dev);

          ESP_LOGI(disTAG, "new (%p) %s", (void *)&dev, dev.debug().c_str());
          addDevice(new_dev);
        }
      }
    }
  }

  return found;
}

bool mcrI2c::detectMultiplexer() {
  int max_attempts = 3;
  _use_multiplexer = false;

  // let's see if there's a multiplexer available
  mcrDevAddr_t multiplexer_dev(0x70);

  for (int i = 1; ((i <= 3) && (_use_multiplexer == false)); i++) {
    ESP_LOGD(detTAG, "detecting TCA9548A multiplexer (attempt %d/%d)", i,
             max_attempts);

    if (detectDevice(multiplexer_dev)) {
      ESP_LOGD(detTAG, "found TCA9548A multiplexer");
      _use_multiplexer = true;
    }
  }

  ESP_LOGI(detTAG, "%s use multiplexer",
           ((_use_multiplexer) ? "will" : "will not"));

  return _use_multiplexer;
}

void mcrI2c::discover(void *task_data) {
  trackDiscover(true);
  detectMultiplexer();

  if (useMultiplexer()) {
    for (int bus = 0; (useMultiplexer() && (bus < maxBuses())); bus++) {
      ESP_LOGD(detTAG, "scanning bus 0x%02x", bus);
      int found = detectDevicesOnBus(bus);
      if (found > 0) {
        ESP_LOGI(disTAG, "found 0x%02x devices on bus=0x%02x", found, bus);
      }
    }
  } else { // multiplexer not available, just search bus 0
    int found = detectDevicesOnBus(0x00);
    if (found > 0) {
      ESP_LOGI(disTAG, "found 0x%02x devices on single bus", found);
    }
  }

  trackDiscover(false);
}

uint32_t mcrI2c::maxBuses() { return _max_buses; }

void mcrI2c::printUnhandledDev(i2cDev_t *dev) {
  ESP_LOGW(engTAG, "unhandled dev 0x%02x desc: %s use_mplex: 0x%x bus: 0x%x",
           dev->devAddr(), dev->desc(), dev->useMultiplexer(), dev->bus());
}

bool mcrI2c::useMultiplexer() { return _use_multiplexer; }

bool mcrI2c::readAM2315(i2cDev_t *dev, humidityReading_t **reading, bool wake) {
  static uint32_t error_count = 0;
  auto rc = false;
  i2c_cmd_handle_t cmd = nullptr;
  esp_err_t esp_rc;

  uint8_t buff[] = {
      0x00,       // cmd code
      0x00,       // uint8_t count
      0x00, 0x00, // relh high byte, low byte
      0x00, 0x00, // tempC high byte, low byte
      0x00, 0x00  // CRC high byte, low byte
  };

  dev->startRead();

  if (wake) {
    mcrDevAddr_t dev_addr = dev->devAddr();
    wakeAM2315(dev_addr);
  }

  cmd = i2c_cmd_link_create();
  i2c_master_start(cmd);
  i2c_master_write_byte(cmd, (dev->devAddr() << 1) | I2C_MASTER_WRITE,
                        ACK_CHECK_EN);
  i2c_master_write_byte(cmd, 0x03, ACK_CHECK_EN);
  i2c_master_write_byte(cmd, 0x00, ACK_CHECK_EN);
  i2c_master_write_byte(cmd, 0x04, ACK_CHECK_EN);
  i2c_master_stop(cmd);

  esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, pdMS_TO_TICKS(1000));
  i2c_cmd_link_delete(cmd);

  if (esp_rc != ESP_OK) {
    ESP_LOGW(readAM2315TAG, "write failed (cmd) to %s esp_rc=0x%02x",
             dev->debug().c_str(), esp_rc);
    dev->stopRead();
    return rc;
  }

  delay(pdMS_TO_TICKS(100));

  // get the device data
  cmd = i2c_cmd_link_create();
  i2c_master_start(cmd);
  i2c_master_write_byte(cmd, (dev->devAddr() << 1) | I2C_MASTER_READ,
                        ACK_CHECK_EN);
  for (int i = 0; i < sizeof(buff); i++) {
    i2c_ack_type_t byte_ack =
        (i == (sizeof(buff) - 1)) ? (i2c_ack_type_t)0x01 : (i2c_ack_type_t)0x00;
    i2c_master_read_byte(cmd, &buff[i], byte_ack);
  }
  i2c_master_stop(cmd);

  esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, pdMS_TO_TICKS(3000));
  i2c_cmd_link_delete(cmd);

  if (esp_rc != ESP_OK) {
    ESP_LOGW(readAM2315TAG, "read failed for %s esp_rc=0x%02x",
             dev->debug().c_str(), esp_rc);
    dev->stopRead();
    return rc;
  } else {
    ESP_LOGI(readAM2315TAG, "read of %s successful", dev->debug().c_str());
  }

  dev->stopRead();

  // verify the CRC
  uint16_t crc = buff[7] * 256 + buff[6];
  uint16_t crc_calc = 0xFFFF;

  for (uint32_t i = 0; i < 6; i++) {
    crc_calc = crc_calc ^ buff[i];

    for (uint32_t j = 0; j < 8; j++) {
      if (crc_calc & 0x01) {
        crc_calc = crc_calc >> 1;
        crc_calc = crc_calc ^ 0xA001;
      } else {
        crc_calc = crc_calc >> 1;
      }
    }
  }

  if (crc == crc_calc) {
    float rh = buff[2];
    rh *= 256;
    rh += buff[3];
    rh /= 10;

    float tc = buff[4] & 0x7F;
    tc *= 256;
    tc += buff[5];
    tc /= 10;

    if (buff[4] >> 7)
      tc = -tc;

    // if (reading != nullptr) {
    *reading = new humidityReading(dev->id(), dev->readTimestamp(), tc, rh);
    // }

    error_count = 0;
    rc = true;
  } else { // crc did not match
    ESP_LOGW(readAM2315TAG, "crc mismatch for %s", dev->debug().c_str())
    error_count += 1;
  }
  return rc;
}

bool mcrI2c::readSHT31(i2cDev_t *dev, humidityReading_t **reading) {
  static uint32_t error_count = 0;
  auto rc = false;
  i2c_cmd_handle_t cmd = nullptr;
  esp_err_t esp_rc;
  static uint32_t convert_ms = 20;

  uint8_t buff[] = {
      0x00, 0x00, // tempC high byte, low byte
      0x00,       // crc8 of temp
      0x00, 0x00, // relh high byte, low byte
      0x00        // crc8 of relh
  };

  dev->startRead();

  // get the device data
  cmd = i2c_cmd_link_create();
  i2c_master_start(cmd);
  i2c_master_write_byte(cmd, (dev->devAddr() << 1) | I2C_MASTER_WRITE, 0x01);
  i2c_master_write_byte(cmd, 0x24, 0x01);
  i2c_master_write_byte(cmd, 0x00, 0x01);
  i2c_master_stop(cmd);

  esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, pdMS_TO_TICKS(1000));
  i2c_cmd_link_delete(cmd);

  if (esp_rc != ESP_OK) {
    ESP_LOGW(readSHT31TAG, "write failed (cmd) to %s esp_rc=0x%02x",
             dev->debug().c_str(), esp_rc);
    return rc;
  }

  TickType_t last_wake;
  ESP_LOGD(readSHT31TAG, "delaying %ums for measurement", convert_ms);
  last_wake = xTaskGetTickCount();
  int64_t start_delay = esp_timer_get_time();
  vTaskDelayUntil(&last_wake, pdMS_TO_TICKS(convert_ms));
  int64_t end_delay = esp_timer_get_time();

  ESP_LOGD(readSHT31TAG, "actual delay was %0.3fms",
           (float)(end_delay - start_delay) / 1000.0);

  cmd = i2c_cmd_link_create();
  i2c_master_start(cmd);
  i2c_master_write_byte(cmd, (dev->devAddr() << 1) | I2C_MASTER_READ,
                        ACK_CHECK_EN);
  for (int i = 0; i < sizeof(buff); i++) {
    i2c_ack_type_t byte_ack =
        (i == (sizeof(buff) - 1)) ? (i2c_ack_type_t)0x01 : (i2c_ack_type_t)0x00;
    i2c_master_read_byte(cmd, &buff[i], byte_ack);
  }

  i2c_master_stop(cmd);

  esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, pdMS_TO_TICKS(1000));
  i2c_cmd_link_delete(cmd);

  dev->stopRead();

  if (esp_rc != ESP_OK) {
    ESP_LOGW(readSHT31TAG, "read failed for %s esp_rc=%d", dev->debug().c_str(),
             esp_rc);
    if (convert_ms < 100) {
      convert_ms += 3;
      ESP_LOGD(readSHT31TAG, "calibrating measurement delay to %ums",
               convert_ms);
    } else {
      ESP_LOGI(readSHT31TAG, "read successful for %s", dev->debug().c_str());
    }
    return rc;
  }

  uint8_t crc_temp = crcSHT31(buff, 2);
  uint8_t crc_relh = crcSHT31(buff + 3, 2);

  if ((crc_temp == buff[2]) && (crc_relh == buff[5])) {
    // conversion pulled from SHT31 datasheet
    uint16_t stc = buff[0];
    stc <<= 8;
    stc |= buff[1];

    uint16_t srh = buff[3];
    srh <<= 8;
    srh |= buff[4];

    double raw_tc = stc;
    raw_tc *= 175;
    raw_tc /= 0xFFFF;
    raw_tc = -45 + raw_tc;
    float tc = raw_tc;

    double raw_rh = srh;
    raw_rh *= 100;
    raw_rh /= 0xFFFF;
    float rh = raw_rh;

    *reading = new humidityReading(dev->id(), dev->readTimestamp(), tc, rh);

    error_count = 0;
    rc = true;
  } else { // crc did not match
    ESP_LOGW(readSHT31TAG, "crc mismatch for %s", dev->debug().c_str())
    error_count += 1;
  }

  return rc;
}

void mcrI2c::report(void *task_data) {

  trackReport(true);

  // while (next_dev != nullptr) {
  for (auto it = knownDevices(); moreDevices(it); it++) {
    auto rc = false;
    i2cDev_t *dev = (i2cDev_t *)*it;
    humidityReading_t *humidity = nullptr;

    selectBus(dev->bus());

    switch (dev->devAddr()) {
    case 0x5C:
      rc = readAM2315(dev, &humidity, true);
      dev->setReading(humidity);
      break;

    case 0x44:
      rc = readSHT31(dev, &humidity);
      dev->setReading(humidity);
      break;

    default:
      printUnhandledDev(dev);
      break;
    }

    if ((rc) && (humidity != nullptr)) {
      publish(humidity);
    }

    delay(pdMS_TO_TICKS(200));
  }

  trackReport(false);
}

void mcrI2c::run(void *task_data) {

  ESP_LOGI(engTAG, "configuring and initializing I2c");

  ESP_LOGI(engTAG, "waiting on event_group=%p for bits=0x%x", (void *)_ev_group,
           _wait_bit);
  xEventGroupWaitBits(_ev_group, _wait_bit, false, true, portMAX_DELAY);
  ESP_LOGI(engTAG, "event_group wait complete, proceeding to task loop");

  _last_wake.engine = xTaskGetTickCount();
  delay(pdMS_TO_TICKS(5000));
  for (;;) {
    discover(nullptr);
    delay(pdMS_TO_TICKS(5000));

    for (int i = 0; i < 10; i++) {
      report(nullptr);
      // signal to other tasks the dsEngine task is in it's run loop
      // this ensures all other set-up activities are complete before
      // xEventGroupSetBits(_ds_evg, _event_bits.engine_running);

      // do stuff here

      vTaskDelayUntil(&(_last_wake.engine), _loop_frequency);
      runtimeMetricsReport(engTAG);
    }
  }
}

bool mcrI2c::selectBus(uint32_t bus) {
  bool rc = true;
  i2c_cmd_handle_t cmd = nullptr;
  mcrDevAddr_t multiplexer_dev(0x70);
  esp_err_t esp_rc = ESP_FAIL;

  i2c_reset_tx_fifo(I2C_NUM_0);
  i2c_reset_rx_fifo(I2C_NUM_0);

  if (bus >= _max_buses) {
    ESP_LOGW(engTAG, "attempt to select bus %d >= %d, bus not changed", bus,
             _max_buses);
  }

  if (useMultiplexer() && (bus < _max_buses)) {
    cmd = i2c_cmd_link_create();
    i2c_master_start(cmd);
    i2c_master_write_byte(
        cmd, (multiplexer_dev.firstAddressByte() << 1) | I2C_MASTER_WRITE,
        ACK_CHECK_EN);
    i2c_master_write_byte(cmd, (0x01 << bus),
                          ACK_CHECK_EN); // 0x00 selects no bus
    i2c_master_stop(cmd);

    esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, pdMS_TO_TICKS(1000));
    i2c_cmd_link_delete(cmd);

    if (esp_rc != ESP_OK) {
      ESP_LOGW(selTAG, "unable to select bus %d esp_rc=0x%02x", bus, esp_rc);
      rc = false;
    }
  }

  // slow down the rate of individual cmds to the i2c
  delay(pdMS_TO_TICKS(100));

  return rc;
}

void mcrI2c::wakeAM2315(mcrDevAddr_t &addr) {
  i2c_cmd_handle_t cmd = nullptr;
  uint8_t dev_addr = addr.firstAddressByte();

  cmd = i2c_cmd_link_create();
  i2c_master_start(cmd);
  i2c_master_write_byte(cmd, (dev_addr << 1) | I2C_MASTER_WRITE, ACK_CHECK_EN);
  i2c_master_stop(cmd);
  // ignore the error code here since the device will not answer while
  // waking up
  i2c_master_cmd_begin(I2C_NUM_0, cmd, pdMS_TO_TICKS(1000));
  i2c_cmd_link_delete(cmd);

  delay(pdMS_TO_TICKS(100));
}
