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

#include <driver/i2c.h>
#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/task.h>
#include <sdkconfig.h>

#include "devs/addr.hpp"
#include "devs/i2c_dev.hpp"
#include "devs/id.hpp"
#include "engines/engine.hpp"
#include "engines/i2c_engine.hpp"
#include "misc/mcr_types.hpp"
#include "net/mcr_net.hpp"
#include "protocols/mqtt.hpp"
#include "readings/readings.hpp"

mcrI2c::mcrI2c() {
  setTags(localTags());
  setLoggingLevel(ESP_LOG_WARN);
  // setLoggingLevel(tagEngine(), ESP_LOG_INFO);

  _engine_task_name = tagEngine();
  _engine_stack_size = 5 * 1024;
  _engine_priority = 13;

  // TODO: do we need to assign a GPIO to power up the i2c devices?
  // power up the i2c devices
  // pinMode(I2C_PWR_PIN, OUTPUT);
  // digitalWrite(I2C_PWR_PIN, HIGH);
}

bool mcrI2c::crcSHT31(const uint8_t *data) {
  uint8_t crc = 0xFF;

  for (uint32_t j = 2; j; --j) {
    crc ^= *data++;

    for (uint32_t i = 8; i; --i) {
      crc = (crc & 0x80) ? (crc << 1) ^ 0x31 : (crc << 1);
    }
  }

  // data was ++ in the above loop so it is already pointing at the crc
  return (crc == *data);
}

bool mcrI2c::detectDevice(mcrDevAddr_t &addr) {
  bool rc = false;
  i2c_cmd_handle_t cmd = nullptr;
  esp_err_t esp_rc = ESP_FAIL;
  uint8_t sht31_cmd_data[] = {0x30, // soft-reset
                              0xa2};

  ESP_LOGD(tagDetectDev(), "looking for %s", addr.debug().c_str());

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
    ESP_LOGD(tagEngine(), "%s not found (%s)", addr.debug().c_str(),
             espError(esp_rc));
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
          ESP_LOGD(tagDiscover(), "previously seen %s", found->debug().c_str());
        } else { // device was not known, must add
          i2cDev_t *new_dev = new i2cDev(dev);

          ESP_LOGI(tagDiscover(), "new (%p) %s", (void *)&dev,
                   dev.debug().c_str());
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
    ESP_LOGD(tagDetectDev(), "detecting TCA9548A multiplexer (attempt %d/%d)",
             i, max_attempts);

    if (detectDevice(multiplexer_dev)) {
      ESP_LOGD(tagDetectDev(), "found TCA9548A multiplexer");
      _use_multiplexer = true;
    }
  }

  ESP_LOGI(tagDetectDev(), "%s use multiplexer",
           ((_use_multiplexer) ? "will" : "will not"));

  return _use_multiplexer;
}

void mcrI2c::discover(void *task_data) {
  // NOTE: special case due to buggy i2c driver
  //       the normalOpsBit is used to globally signal processes
  //       should pause because a critical operation is underway (e.g. ota
  //       update)
  mcr::Net::waitForNormalOps();

  trackDiscover(true);
  detectMultiplexer();

  if (useMultiplexer()) {
    for (uint32_t bus = 0; (useMultiplexer() && (bus < maxBuses())); bus++) {
      ESP_LOGD(tagDetectDev(), "scanning bus 0x%02x", bus);
      int found = detectDevicesOnBus(bus);
      if (found > 0) {
        ESP_LOGI(tagDiscover(), "found 0x%02x devices on bus=0x%02x", found,
                 bus);
      }
    }
  } else { // multiplexer not available, just search bus 0
    int found = detectDevicesOnBus(0x00);
    if (found > 0) {
      ESP_LOGI(tagDiscover(), "found 0x%02x devices on single bus", found);
    }
  }

  trackDiscover(false);
}

uint32_t mcrI2c::maxBuses() { return _max_buses; }

void mcrI2c::printUnhandledDev(i2cDev_t *dev) {
  ESP_LOGW(tagEngine(), "unhandled dev %s", dev->debug().c_str());
}

bool mcrI2c::useMultiplexer() { return _use_multiplexer; }

bool mcrI2c::readAM2315(i2cDev_t *dev, humidityReading_t **reading, bool wake) {
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
    ESP_LOGW(tagReadAM2315(), "write failed %s %s", dev->debug().c_str(),
             espError(esp_rc));
    dev->stopRead();
    dev->writeFailure();
    return rc;
  }

  delay(100);

  // get the device data
  cmd = i2c_cmd_link_create();
  i2c_master_start(cmd);
  i2c_master_write_byte(cmd, (dev->devAddr() << 1) | I2C_MASTER_READ,
                        ACK_CHECK_EN);
  for (uint32_t i = 0; i < sizeof(buff); i++) {
    i2c_ack_type_t byte_ack =
        (i == (sizeof(buff) - 1)) ? (i2c_ack_type_t)0x01 : (i2c_ack_type_t)0x00;
    i2c_master_read_byte(cmd, &buff[i], byte_ack);
  }
  i2c_master_stop(cmd);

  esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, pdMS_TO_TICKS(3000));
  i2c_cmd_link_delete(cmd);

  if (esp_rc != ESP_OK) {
    ESP_LOGW(tagReadAM2315(), "read failed for %s %s", dev->debug().c_str(),
             espError(esp_rc));
    dev->stopRead();
    dev->readFailure();
    return rc;

  } else {
    ESP_LOGI(tagReadAM2315(), "read of %s successful", dev->debug().c_str());
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
    float rh = (buff[2] * 256) / 10;
    float tc =
        ((((buff[4] & 0x7F) * 256) + buff[5]) / 10) * ((buff[4] >> 7) ? -1 : 1);

    *reading =
        new humidityReading(dev->externalName(), dev->readTimestamp(), tc, rh);

    rc = true;
  } else { // crc did not match
    ESP_LOGW(tagReadAM2315(), "crc mismatch for %s", dev->debug().c_str());
    dev->crcMismatch();
  }
  return rc;
}

bool mcrI2c::readSHT31(i2cDev_t *dev, humidityReading_t **reading) {
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
    ESP_LOGW(tagReadSHT31(), "write failed %s %s", dev->debug().c_str(),
             espError(esp_rc));
    dev->stopRead();
    dev->writeFailure();
    return rc;
  }

  TickType_t last_wake;
  ESP_LOGD(tagReadSHT31(), "delaying %ums for measurement", convert_ms);
  last_wake = xTaskGetTickCount();
  int64_t start_delay = esp_timer_get_time();
  vTaskDelayUntil(&last_wake, pdMS_TO_TICKS(convert_ms));
  int64_t end_delay = esp_timer_get_time();

  ESP_LOGD(tagReadSHT31(), "actual delay was %0.3fms",
           (float)(end_delay - start_delay) / 1000.0);

  cmd = i2c_cmd_link_create();
  i2c_master_start(cmd);
  i2c_master_write_byte(cmd, (dev->devAddr() << 1) | I2C_MASTER_READ,
                        ACK_CHECK_EN);
  for (uint32_t i = 0; i < sizeof(buff); i++) {
    i2c_ack_type_t byte_ack =
        (i == (sizeof(buff) - 1)) ? (i2c_ack_type_t)0x01 : (i2c_ack_type_t)0x00;
    i2c_master_read_byte(cmd, &buff[i], byte_ack);
  }

  i2c_master_stop(cmd);

  esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, pdMS_TO_TICKS(1000));
  i2c_cmd_link_delete(cmd);

  dev->stopRead();

  if (esp_rc != ESP_OK) {
    ESP_LOGW(tagReadSHT31(), "read failed for %s %s", dev->debug().c_str(),
             espError(esp_rc));

    if (convert_ms < 100) {
      convert_ms += 3;
      ESP_LOGD(tagReadSHT31(), "calibrating measurement delay to %ums",
               convert_ms);
    }

    dev->readFailure();
    return rc;
  }

  if (crcSHT31(buff) && crcSHT31(&(buff[3]))) {
    // conversion from SHT31 datasheet
    uint16_t stc = (buff[0] << 8) | buff[1];
    uint16_t srh = (buff[3] << 8) | buff[4];

    float tc = (float)((stc * 175) / 0xffff) - 45;
    float rh = (float)((srh * 100) / 0xffff);

    *reading =
        new humidityReading(dev->externalName(), dev->readTimestamp(), tc, rh);

    rc = true;
  } else { // crc did not match
    ESP_LOGW(tagReadSHT31(), "crc mismatch for %s", dev->debug().c_str());
    dev->crcMismatch();
  }

  return rc;
}

void mcrI2c::report(void *task_data) {
  mcr::Net::waitForName(10000);
  // NOTE: special case due to buggy i2c driver
  //       the normalOpsBit is used to globally signal processes
  //       should pause because a critical operation is underway (e.g. ota
  //       update)
  mcr::Net::waitForNormalOps();

  trackReport(true);

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

    if (rc && (humidity != nullptr)) {
      publish(humidity);
      dev->justSeen();
    }
  }

  trackReport(false);
}

void mcrI2c::run(void *task_data) {

  ESP_LOGI(tagEngine(), "configuring and initializing I2c");

  ESP_LOGI(tagEngine(), "installing i2c driver...");
  i2c_config_t _conf;
  bzero(&_conf, sizeof(_conf));
  _conf.mode = I2C_MODE_MASTER;
  _conf.sda_io_num = (gpio_num_t)23;
  _conf.scl_io_num = (gpio_num_t)22;
  _conf.sda_pullup_en = GPIO_PULLUP_ENABLE;
  _conf.scl_pullup_en = GPIO_PULLUP_ENABLE;
  _conf.master.clk_speed = 100000;

  ESP_ERROR_CHECK(i2c_param_config(I2C_NUM_0, &_conf));
  ESP_ERROR_CHECK(i2c_driver_install(I2C_NUM_0, _conf.mode, 0, 0, 0));
  // vTaskDelay(pdMS_TO_TICKS(200));

  ESP_LOGI(tagEngine(), "i2c driver installed");

  ESP_LOGI(tagEngine(), "waiting for normal ops...");
  mcr::Net::waitForNormalOps();
  delay(pdMS_TO_TICKS(2500));
  ESP_LOGI(tagEngine(), "normal ops, proceeding to task loop");

  _last_wake.engine = xTaskGetTickCount();
  for (;;) {
    discover(nullptr);

    for (int i = 0; i < 6; i++) {
      report(nullptr);

      reportMetrics();

      vTaskDelayUntil(&(_last_wake.engine), _loop_frequency);
      runtimeMetricsReport();
    }
  }
}

bool mcrI2c::selectBus(uint32_t bus) {
  bool rc = true;
  i2c_cmd_handle_t cmd = nullptr;
  mcrDevAddr_t multiplexer_dev(0x70);
  esp_err_t esp_rc = ESP_FAIL;

  _bus_selects++;

  i2c_reset_tx_fifo(I2C_NUM_0);
  i2c_reset_rx_fifo(I2C_NUM_0);

  if (bus >= _max_buses) {
    ESP_LOGW(tagEngine(), "attempt to select bus %d >= %d, bus not changed",
             bus, _max_buses);
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
      _bus_select_errors++;
      ESP_LOGW(tagSelectBus(),
               "unable to select bus %d (selects=%u errors=%u) %s", bus,
               _bus_selects, _bus_select_errors, espError(esp_rc));

      rc = false;
    }
  }

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

  delay(100);
}
