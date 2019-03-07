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
#include <driver/periph_ctrl.h>
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

static mcrI2c_t *__singleton__ = nullptr;

mcrI2c::mcrI2c() {
  setTags(localTags());
  setLoggingLevel(ESP_LOG_WARN);
  setLoggingLevel(tagEngine(), ESP_LOG_INFO);
  setLoggingLevel(tagDetectDev(), ESP_LOG_INFO);
  setLoggingLevel(tagDiscover(), ESP_LOG_INFO);
  setLoggingLevel(tagReport(), ESP_LOG_INFO);

  _engine_task_name = tagEngine();
  _engine_stack_size = 5 * 1024;
  _engine_priority = CONFIG_MCR_I2C_TASK_CORE_PRIORITY;
}

esp_err_t mcrI2c::busRead(i2cDev_t *dev, uint8_t *buff, uint32_t len,
                          esp_err_t prev_esp_rc) {
  i2c_cmd_handle_t cmd = nullptr;
  esp_err_t esp_rc;

  if (prev_esp_rc != ESP_OK) {
    ESP_LOGE(tagEngine(),
             "aborted bus_read(%s, ...) invoked with prev_esp_rc = %s",
             dev->debug().c_str(), esp_err_to_name(prev_esp_rc));
    return prev_esp_rc;
  }

  cmd = i2c_cmd_link_create(); // allocate i2c cmd queue
  i2c_master_start(cmd);       // queue i2c START

  i2c_master_write_byte(cmd, dev->readAddr(),
                        true); // queue the READ for device and check for ACK

  i2c_master_read(cmd, buff, len,
                  I2C_MASTER_LAST_NACK); // queue the READ of number of bytes
  i2c_master_stop(cmd);                  // queue i2c STOP

  // execute queued i2c cmd
  esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, _cmd_timeout);
  i2c_cmd_link_delete(cmd);

  if (esp_rc == ESP_OK) {
    // TODO: set to debug for production release
    ESP_LOGD(tagEngine(), "ESP_OK: bus_read(%s, %p, %d, %s)",
             dev->debug().c_str(), buff, len, esp_err_to_name(prev_esp_rc));
  } else {
    ESP_LOGE(tagEngine(), "%s: bus_read(%s, %p, %d, %s)",
             esp_err_to_name(esp_rc), dev->debug().c_str(), buff, len,
             esp_err_to_name(prev_esp_rc));
  }

  return esp_rc;
}

esp_err_t mcrI2c::busWrite(i2cDev_t *dev, uint8_t *bytes, uint32_t len,
                           esp_err_t prev_esp_rc) {
  i2c_cmd_handle_t cmd = nullptr;
  esp_err_t esp_rc;

  if (prev_esp_rc != ESP_OK) {
    ESP_LOGE(tagEngine(),
             "aborted bus_write(%s, ...) invoked with prev_esp_rc = %s",
             dev->debug().c_str(), esp_err_to_name(prev_esp_rc));
    return prev_esp_rc;
  }

  cmd = i2c_cmd_link_create(); // allocate i2c cmd queue
  i2c_master_start(cmd);       // queue i2c START

  i2c_master_write_byte(cmd, dev->writeAddr(),
                        true); // queue the device address (with WRITE)
                               // and check for ACK
  i2c_master_write(cmd, bytes, len,
                   true); // queue bytes to send (with ACK check)
  i2c_master_stop(cmd);   // queue i2c STOP

  // execute queued i2c cmd
  esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, _cmd_timeout);
  i2c_cmd_link_delete(cmd);

  if (esp_rc == ESP_OK) {
    ESP_LOGD(tagEngine(), "ESP_OK: bus_write(%s, %p, %d, %s)",
             dev->debug().c_str(), bytes, len, esp_err_to_name(prev_esp_rc));
  } else {
    ESP_LOGE(tagEngine(), "%s: bus_write(%s, %p, %d, %s)",
             esp_err_to_name(esp_rc), dev->debug().c_str(), bytes, len,
             esp_err_to_name(prev_esp_rc));
  }

  return esp_rc;
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

  ESP_LOGI(tagDetectDev(), "looking for %s", addr.debug().c_str());

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

    esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, pdMS_TO_TICKS(100));
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

    esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, pdMS_TO_TICKS(100));
    i2c_cmd_link_delete(cmd);

    break;

  // AM2315 needs to be woken up
  case 0x5C:
    if (wakeAM2315(addr)) {

      cmd = i2c_cmd_link_create();
      i2c_master_start(cmd);
      i2c_master_write_byte(
          cmd, (addr.firstAddressByte() << 1) | I2C_MASTER_WRITE, ACK_CHECK_EN);
      i2c_master_stop(cmd);
      esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, pdMS_TO_TICKS(100));
      i2c_cmd_link_delete(cmd);
    } else {
      esp_rc = ESP_FAIL;
    }

    break;

  case 0x20:
    cmd = i2c_cmd_link_create();

    i2c_master_start(cmd);
    i2c_master_write_byte(
        cmd, (addr.firstAddressByte() << 1) | I2C_MASTER_WRITE, ACK_CHECK_EN);
    i2c_master_stop(cmd);

    esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, pdMS_TO_TICKS(100));
    i2c_cmd_link_delete(cmd);

    break;

  case 0x36:
    cmd = i2c_cmd_link_create();

    i2c_master_start(cmd);
    i2c_master_write_byte(
        cmd, (addr.firstAddressByte() << 1) | I2C_MASTER_WRITE, ACK_CHECK_EN);
    i2c_master_stop(cmd);

    esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, pdMS_TO_TICKS(100));
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

bool mcrI2c::detectDevicesOnBus(int bus) {
  bool rc = true;

  mcrDevAddr_t *addrs = search_addrs();

  for (uint8_t i = 0; addrs[i].isValid(); i++) {
    mcrDevAddr_t &search_addr = addrs[i];

    if (selectBus(bus)) {
      if (detectDevice(search_addr)) {
        i2cDev_t dev(search_addr, useMultiplexer(), bus);

        if (i2cDev_t *found = (i2cDev_t *)justSeenDevice(dev)) {
          ESP_LOGD(tagDiscover(), "already know %s", found->debug().c_str());
        } else { // device was not known, must add
          i2cDev_t *new_dev = new i2cDev(dev);

          ESP_LOGI(tagDiscover(), "new (%p) %s", (void *)new_dev,
                   dev.debug().c_str());
          addDevice(new_dev);
        }
      }
    } else {
      ESP_LOGW(tagDiscover(),
               "bus select failed, aborting detectDevicesOnBus()");
      rc = false;
      break;
    }
  }

  return rc;
}

bool mcrI2c::detectMultiplexer(const int max_attempts) {
  _use_multiplexer = false;

  // let's see if there's a multiplexer available
  mcrDevAddr_t multiplexer_dev(0x70);

  for (int i = 1; ((i <= max_attempts) && (_use_multiplexer == false)); i++) {
    ESP_LOGD(tagDetectDev(), "detecting TCA9548A (attempt %d/%d)", i,
             max_attempts);

    if (detectDevice(multiplexer_dev)) {
      ESP_LOGD(tagDetectDev(), "found TCA9548A");
      _use_multiplexer = true;
    }
  }

  ESP_LOGI(tagDetectDev(), "%s use multiplexer",
           ((_use_multiplexer) ? "will" : "will not"));

  return _use_multiplexer;
}

void mcrI2c::discover(void *task_data) {
  bool detect_rc = true;

  trackDiscover(true);
  detectMultiplexer();

  if (useMultiplexer()) {
    for (uint32_t bus = 0; (detect_rc && (bus < maxBuses())); bus++) {
      ESP_LOGD(tagDetectDev(), "scanning bus %#02x", bus);
      detect_rc = detectDevicesOnBus(bus);
    }
  } else { // multiplexer not available, just search bus 0
    detect_rc = detectDevicesOnBus(0x00);
  }

  trackDiscover(false);

  delay(50); // pause, report is next
}

bool mcrI2c::hardReset() {
  esp_err_t rc;

  ESP_LOGE(tagEngine(), "hard reset of i2c peripheral");

  delay(1000);

  rc = i2c_driver_delete(I2C_NUM_0);
  ESP_LOGI(tagEngine(), "i2c_driver_delete() == %s", espError(rc));

  periph_module_disable(PERIPH_I2C0_MODULE);
  periph_module_enable(PERIPH_I2C0_MODULE);

  return installDriver();
}

bool mcrI2c::installDriver() {
  esp_err_t esp_err = 0;

  bzero(&_conf, sizeof(_conf));

  _conf.mode = I2C_MODE_MASTER;
  _conf.sda_io_num = (gpio_num_t)23;
  _conf.scl_io_num = (gpio_num_t)22;
  _conf.sda_pullup_en = GPIO_PULLUP_ENABLE;
  _conf.scl_pullup_en = GPIO_PULLUP_ENABLE;
  _conf.master.clk_speed = 100000;

  esp_err = i2c_param_config(I2C_NUM_0, &_conf);
  ESP_LOGI(tagEngine(), "i2c_param_config() == %s", espError(esp_err));

  if (esp_err == ESP_OK) {
    esp_err = i2c_driver_install(I2C_NUM_0, _conf.mode, 0, 0, 0);
    ESP_LOGI(tagEngine(), "i2c_driver_install() == %s", espError(esp_err));
  }

  delay(1000);

  return (esp_err == ESP_OK) ? true : false;
}

mcrI2c_t *mcrI2c::instance() {
  if (__singleton__ == nullptr) {
    __singleton__ = new mcrI2c();
  }

  return __singleton__;
}

uint32_t mcrI2c::maxBuses() { return _max_buses; }

void mcrI2c::printUnhandledDev(i2cDev_t *dev) {
  ESP_LOGW(tagEngine(), "unhandled dev %s", dev->debug().c_str());
}

bool mcrI2c::useMultiplexer() { return _use_multiplexer; }

bool mcrI2c::readAM2315(i2cDev_t *dev, bool wake) {
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
    bool woken = wakeAM2315(dev_addr);

    if (!woken) {
      return rc;
    }
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

  delay(100);

  if (esp_rc != ESP_OK) {
    ESP_LOGW(tagReadAM2315(), "write failed %s %s", dev->debug().c_str(),
             espError(esp_rc));
    dev->stopRead();
    dev->writeFailure();
    return rc;
  }

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

  esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, pdMS_TO_TICKS(1000));
  i2c_cmd_link_delete(cmd);

  delay(100);

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

    humidityReading_t *reading =
        new humidityReading(dev->externalName(), dev->readTimestamp(), tc, rh);

    dev->setReading(reading);

    rc = true;
  } else { // crc did not match
    ESP_LOGW(tagReadAM2315(), "crc mismatch for %s", dev->debug().c_str());
    dev->crcMismatch();
  }
  return rc;
}

bool mcrI2c::readMCP23008(i2cDev_t *dev) {
  auto rc = true;
  auto positions = 0b00000000;

  positionsReading_t *reading = new positionsReading(
      dev->externalName(), time(nullptr), positions, (uint8_t)8);

  dev->justSeen();
  dev->setReading(reading);

  return rc;
}

bool mcrI2c::readSeesawSoil(i2cDev_t *dev) {
  auto rc = false;
  esp_err_t esp_rc;
  float tempC = 0.0;
  int soil_moisture;
  // int sw_version;

  // seesaw data queries are two bytes that describe:
  //   1. module
  //   2. register
  // NOTE: array is ONLY for the transmit since the response varies
  //       by module and register
  uint8_t data_request[] = {0x00,  // MSB: module
                            0x00}; // LSB: register

  // seesaw responses to data queries vary in length.  this buffer will be
  // reused for all queries so it must be the max of all response lengths
  //   1. capacitance - 16bit integer (two bytes)
  //   2. temperature - 32bit float (four bytes)
  uint8_t buff[] = {
      0x00, 0x00, // capactive: (int)16bit, temperature: (float)32 bits
      0x00, 0x00  // capactive: not used, temperature: (float)32 bits
  };

  // address i2c device
  // write request to read module and register
  //  temperture: SEESAW_STATUS_BASE, SEEWSAW_STATUS_TEMP  (4 bytes)
  //     consider other status: SEESAW_STATUS_HW_ID, *VERSION, *OPTIONS
  //  capacitance:  SEESAW_TOUCH_BASE, SEESAW_TOUCH_CHANNEL_OFFSET (2 bytes)
  // delay (maybe?)
  // write request to read bytes of the register

  dev->startRead();

  // first, request and receive the onboard temperature
  data_request[0] = 0x00; // SEESAW_STATUS_BASE
  data_request[1] = 0x04; // SEESAW_STATUS_TEMP
  esp_rc = busWrite(dev, data_request, 2);
  delay(20);
  esp_rc = busRead(dev, buff, 4, esp_rc);

  // conversion copied from AdaFruit Seesaw library
  tempC = (1.0 / (1UL << 16)) *
          (float)(((uint32_t)buff[0] << 24) | ((uint32_t)buff[1] << 16) |
                  ((uint32_t)buff[2] << 8) | (uint32_t)buff[3]);

  // second, request and receive the touch capacitance (soil moisture)
  data_request[0] = 0x0f; // SEESAW_TOUCH_BASE
  data_request[1] = 0x10; // SEESAW_TOUCH_CHANNEL_OFFSET

  esp_rc = busWrite(dev, data_request, 2);
  delay(20);
  esp_rc = busRead(dev, buff, 2, esp_rc);

  soil_moisture = ((uint16_t)buff[0] << 8) | buff[1];

  // third, request and receive the board version
  // data_request[0] = 0x00; // SEESAW_STATUS_BASE
  // data_request[1] = 0x02; // SEESAW_STATUS_VERSION
  //
  // esp_rc = bus_write(dev, data_request, 2);
  // esp_rc = bus_read(dev, buff, 4, esp_rc);
  //
  // sw_version = ((uint32_t)buff[0] << 24) | ((uint32_t)buff[1] << 16) |
  //              ((uint32_t)buff[2] << 8) | (uint32_t)buff[3];

  dev->stopRead();

  if (esp_rc == ESP_OK) {
    dev->justSeen();

    soilReading_t *reading = new soilReading(
        dev->externalName(), dev->readTimestamp(), tempC, soil_moisture);

    dev->setReading(reading);
    rc = true;
  }
  // ESP_LOGI(tagEngine(), "soil => sw_version=0x%04x tempC=%3.1f moisture=%d",
  //          sw_version, tempC, soil_moisture);

  return rc;
}

bool mcrI2c::readSHT31(i2cDev_t *dev) {
  auto rc = false;
  i2c_cmd_handle_t cmd = nullptr;
  esp_err_t esp_rc;

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
  i2c_master_write_byte(cmd, (dev->devAddr() << 1) | I2C_MASTER_WRITE,
                        ACK_CHECK_EN);
  i2c_master_write_byte(cmd, 0x24, 0x01);
  i2c_master_write_byte(cmd, 0x00, 0x01);
  i2c_master_stop(cmd);

  esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, pdMS_TO_TICKS(1000));
  i2c_cmd_link_delete(cmd);

  delay(20);

  if (esp_rc != ESP_OK) {
    ESP_LOGW(tagReadSHT31(), "write failed %s %s", dev->debug().c_str(),
             espError(esp_rc));
    dev->stopRead();
    dev->writeFailure();
    return rc;
  }

  cmd = i2c_cmd_link_create();
  i2c_master_start(cmd);
  i2c_master_write_byte(cmd, (dev->devAddr() << 1) | I2C_MASTER_READ,
                        ACK_CHECK_EN);

  i2c_master_read(cmd, buff, sizeof(buff), I2C_MASTER_LAST_NACK);
  i2c_master_stop(cmd);

  esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, pdMS_TO_TICKS(1000));
  i2c_cmd_link_delete(cmd);

  // delay(20);

  dev->stopRead();

  if (esp_rc != ESP_OK) {
    ESP_LOGW(tagReadSHT31(), "read failed for %s %s", dev->debug().c_str(),
             espError(esp_rc));

    dev->readFailure();
    return rc;
  }

  if (crcSHT31(buff) && crcSHT31(&(buff[3]))) {
    // conversion from SHT31 datasheet
    uint16_t stc = (buff[0] << 8) | buff[1];
    uint16_t srh = (buff[3] << 8) | buff[4];

    float tc = (float)((stc * 175) / 0xffff) - 45;
    float rh = (float)((srh * 100) / 0xffff);

    dev->justSeen();

    humidityReading_t *reading =
        new humidityReading(dev->externalName(), dev->readTimestamp(), tc, rh);

    dev->setReading(reading);

    rc = true;
  } else { // crc did not match
    ESP_LOGW(tagReadSHT31(), "crc mismatch for %s", dev->debug().c_str());
    dev->crcMismatch();
  }

  return rc;
}

void mcrI2c::report(void *task_data) {
  mcr::Net::waitForName(10000);

  trackReport(true);

  for (auto it = knownDevices(); moreDevices(it); it++) {
    auto rc = false;
    i2cDev_t *dev = (i2cDev_t *)*it;

    if (selectBus(dev->bus())) {
      switch (dev->devAddr()) {
      case 0x5C:
        rc = readAM2315(dev);
        break;

      case 0x44:
        rc = readSHT31(dev);
        break;

      case 0x20:
        rc = readMCP23008(dev);
        break;

      case 0x36: // Seesaw Soil Probe
        rc = readSeesawSoil(dev);
        break;

      default:
        printUnhandledDev(dev);
        rc = true;
        break;
      }
    }

    if (rc) {
      publish(dev);
      ESP_LOGI(tagReport(), "%s success", dev->debug().c_str());
    } else {
      ESP_LOGE(tagReport(), "%s failed", dev->debug().c_str());
      hardReset();
    }
  }

  trackReport(false);
}

void mcrI2c::run(void *task_data) {

  // vTaskDelay(pdMS_TO_TICKS(200));
  bool driver_ready = false;
  while (!driver_ready) {
    driver_ready = installDriver();
  }

  ESP_LOGI(tagEngine(), "waiting for normal ops...");
  mcr::Net::waitForNormalOps();
  ESP_LOGI(tagEngine(), "normal ops, proceeding to task loop");

  _last_wake.engine = xTaskGetTickCount();
  for (;;) {
    discover(nullptr);

    for (int i = 0; i < 6; i++) {
      report(nullptr);

      runtimeMetricsReport();
      reportMetrics();

      vTaskDelayUntil(&(_last_wake.engine), _loop_frequency);
    }
  }
}

bool mcrI2c::selectBus(uint32_t bus) {
  bool rc = true; // default return is success, failures detected inline
  i2c_cmd_handle_t cmd = nullptr;
  mcrDevAddr_t multiplexer_dev(0x70);
  esp_err_t esp_rc = ESP_FAIL;

  _bus_selects++;

  // i2c_reset_tx_fifo(I2C_NUM_0);
  // i2c_reset_rx_fifo(I2C_NUM_0);

  if (bus >= _max_buses) {
    ESP_LOGW(tagEngine(), "attempt to select bus %d >= %d, bus not changed",
             bus, _max_buses);
    return rc;
  }

  if (useMultiplexer() && (bus < _max_buses)) {
    cmd = i2c_cmd_link_create();
    i2c_master_start(cmd);
    i2c_master_write_byte(
        cmd, (multiplexer_dev.firstAddressByte() << 1) | I2C_MASTER_WRITE,
        ACK_CHECK_EN);
    i2c_master_write_byte(cmd, (0x01 << bus), ACK_CHECK_EN);
    i2c_master_stop(cmd);

    // delay(100);

    esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, pdMS_TO_TICKS(1000));
    i2c_cmd_link_delete(cmd);

    // delay(100);

    if (esp_rc == ESP_OK) {
      rc = true;
    } else {
      _bus_select_errors++;
      ESP_LOGW(tagSelectBus(),
               "unable to select bus %d (selects=%u errors=%u) %s", bus,
               _bus_selects, _bus_select_errors, espError(esp_rc));
      rc = false;
    }

    if (_bus_select_errors > 50) {
      ESP_LOGE(tagEngine(), "bus select errors exceeded, JUMP!");
      delay(5000);
      esp_restart();
    }
  }

  return rc;
}

bool mcrI2c::wakeAM2315(mcrDevAddr_t &addr) {
  esp_err_t esp_err;
  i2c_cmd_handle_t cmd = nullptr;
  uint8_t dev_addr = addr.firstAddressByte();

  cmd = i2c_cmd_link_create();
  i2c_master_start(cmd);
  i2c_master_write_byte(cmd, (dev_addr << 1) | I2C_MASTER_WRITE,
                        I2C_MASTER_NACK);
  i2c_master_stop(cmd);
  // ignore the error code here since the device will not answer while
  // waking up
  esp_err = i2c_master_cmd_begin(I2C_NUM_0, cmd, pdMS_TO_TICKS(1000));
  delay(100);
  i2c_cmd_link_delete(cmd);

  return (esp_err == ESP_OK) ? true : false;
}
