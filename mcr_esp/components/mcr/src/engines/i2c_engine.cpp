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
#include "misc/mcr_nvs.hpp"
#include "misc/mcr_restart.hpp"
#include "misc/mcr_types.hpp"
#include "net/mcr_net.hpp"
#include "protocols/mqtt.hpp"
#include "readings/readings.hpp"

static mcrI2c_t *__singleton__ = nullptr;

mcrI2c::mcrI2c() {
  setTags(localTags());
  setLoggingLevel(ESP_LOG_INFO);
  // setLoggingLevel(tagEngine(), ESP_LOG_INFO);
  // setLoggingLevel(tagDetectDev(), ESP_LOG_INFO);
  // setLoggingLevel(tagDiscover(), ESP_LOG_INFO);
  // setLoggingLevel(tagReport(), ESP_LOG_INFO);
  // setLoggingLevel(tagReadSHT31(), ESP_LOG_INFO);

  _engine_task_name = tagEngine();
  _engine_stack_size = 5 * 1024;
  _engine_priority = CONFIG_MCR_I2C_TASK_CORE_PRIORITY;

  if (mcr::Net::hardwareConfig() == I2C_MULTIPLEXER) {
    gpio_config_t rst_pin_cfg;

    rst_pin_cfg.pin_bit_mask = RST_PIN_SEL;
    rst_pin_cfg.mode = GPIO_MODE_OUTPUT;
    rst_pin_cfg.pull_up_en = GPIO_PULLUP_DISABLE;
    rst_pin_cfg.pull_down_en = GPIO_PULLDOWN_DISABLE;
    rst_pin_cfg.intr_type = GPIO_INTR_DISABLE;

    gpio_config(&rst_pin_cfg);

    gpio_set_level(RST_PIN, 1); // set RST pin high}
  }
}

esp_err_t mcrI2c::busRead(i2cDev_t *dev, uint8_t *buff, uint32_t len,
                          esp_err_t prev_esp_rc) {
  i2c_cmd_handle_t cmd = nullptr;
  esp_err_t esp_rc;

  if (prev_esp_rc != ESP_OK) {
    ESP_LOGD(tagEngine(),
             "aborted bus_read(%s, ...) invoked with prev_esp_rc = %s",
             dev->debug().c_str(), esp_err_to_name(prev_esp_rc));
    return prev_esp_rc;
  }

  int timeout = 0;
  i2c_get_timeout(I2C_NUM_0, &timeout);
  ESP_LOGD(tagEngine(), "i2c timeout: %d", timeout);

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
    ESP_LOGD(tagEngine(), "%s: bus_read(%s, %p, %d, %s)",
             esp_err_to_name(esp_rc), dev->debug().c_str(), buff, len,
             esp_err_to_name(prev_esp_rc));
    dev->readFailure();
  }

  return esp_rc;
}

esp_err_t mcrI2c::busWrite(i2cDev_t *dev, uint8_t *bytes, uint32_t len,
                           esp_err_t prev_esp_rc) {
  i2c_cmd_handle_t cmd = nullptr;
  esp_err_t esp_rc;

  if (prev_esp_rc != ESP_OK) {
    ESP_LOGD(tagEngine(),
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
    ESP_LOGD(tagEngine(), "%s: bus_write(%s, %p, %d, %s)",
             esp_err_to_name(esp_rc), dev->debug().c_str(), bytes, len,
             esp_err_to_name(prev_esp_rc));
    dev->writeFailure();
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

bool mcrI2c::detectDevice(i2cDev_t *dev) {
  bool rc = false;
  // i2c_cmd_handle_t cmd = nullptr;
  esp_err_t esp_rc = ESP_FAIL;
  // uint8_t sht31_cmd_data[] = {0x30, // soft-reset
  //                             0xa2};
  uint8_t detect_cmd[] = {dev->devAddr()};

  ESP_LOGD(tagDetectDev(), "looking for %s", dev->debug().c_str());

  switch (dev->devAddr()) {

  case 0x70: // TCA9548B - TI i2c bus multiplexer
  case 0x44: // SHT-31 humidity sensor
  case 0x20: // MCP23008
  case 0x36: // STEMMA (seesaw based soil moisture sensor)
    esp_rc = busWrite(dev, detect_cmd, sizeof(detect_cmd));
    break;

  case 0x5C: // AM2315
             // special case: device enters sleep after 3s
    if (wakeAM2315(dev)) {
      delay(15);
      esp_rc = busWrite(dev, detect_cmd, sizeof(detect_cmd));
    }

    break;
  }

  if (esp_rc == ESP_OK) {
    rc = true;
  } else {

    ESP_LOGD(tagEngine(), "%s not found (%s)", dev->debug().c_str(),
             espError(esp_rc));
  }

  return rc;
}

bool mcrI2c::detectDevicesOnBus(int bus) {
  bool rc = true;

  mcrDevAddr_t *addrs = search_addrs();

  for (uint8_t i = 0; addrs[i].isValid(); i++) {
    mcrDevAddr_t &search_addr = addrs[i];
    i2cDev_t dev(search_addr, useMultiplexer(), bus);

    if (selectBus(bus)) {
      if (detectDevice(&dev)) {

        if (i2cDev_t *found = (i2cDev_t *)justSeenDevice(dev)) {
          ESP_LOGD(tagDiscover(), "already know %s", found->debug().c_str());
        } else { // device was not known, must add
          i2cDev_t *new_dev = new i2cDev(dev);

          ESP_LOGD(tagDiscover(), "new (%p) %s", (void *)new_dev,
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

  // will be updated below depending on detection
  _use_multiplexer = false;

  switch (mcr::Net::hardwareConfig()) {
  case LEGACY:
    // DEPRECATED as of 2019-03-10
    // support for old hardware that does not use the RST pin
    if (detectDevice(&_multiplexer_dev)) {
      ESP_LOGD(tagDetectDev(), "found TCA9548A multiplexer");
      _use_multiplexer = true;
    }
    break;

  case BASIC:
    _use_multiplexer = false;
    break;

  case I2C_MULTIPLEXER:
    ESP_LOGI(tagDetectDev(), "hardware configured for multiplexer");
    _use_multiplexer = true;
    break;
  }

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
  ESP_LOGI(tagEngine(), "%s i2c_param_config()", esp_err_to_name(esp_err));

  if (esp_err == ESP_OK) {
    esp_err = i2c_driver_install(I2C_NUM_0, _conf.mode, 0, 0, 0);
    ESP_LOGI(tagEngine(), "%s i2c_driver_install()", esp_err_to_name(esp_err));
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
  esp_err_t esp_rc;

  uint8_t request[] = {0x03, 0x00, 0x04};

  uint8_t buff[] = {
      0x00,       // cmd code
      0x00,       // uint8_t count
      0x00, 0x00, // relh high byte, low byte
      0x00, 0x00, // tempC high byte, low byte
      0x00, 0x00  // CRC high byte, low byte
  };

  dev->startRead();
  if (wake) {
    delay(10);
    wakeAM2315(dev);
  }

  delay(10);

  esp_rc = busWrite(dev, request, sizeof(request));

  delay(10);
  esp_rc = busRead(dev, buff, sizeof(buff), esp_rc);

  dev->stopRead();

  if (esp_rc == ESP_OK) {
    dev->justSeen();

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
      float tc = ((((buff[4] & 0x7F) * 256) + buff[5]) / 10) *
                 ((buff[4] >> 7) ? -1 : 1);

      humidityReading_t *reading = new humidityReading(
          dev->externalName(), dev->readTimestamp(), tc, rh);

      dev->setReading(reading);

      rc = true;
    } else { // crc did not match
      ESP_LOGW(tagReadAM2315(), "crc mismatch for %s", dev->debug().c_str());
      dev->crcMismatch();
    }
  }
  return rc;
}

bool mcrI2c::readMCP23008(i2cDev_t *dev) {
  auto rc = false;
  auto positions = 0b00000000;
  esp_err_t esp_rc;

  uint8_t gpio_request[] = {0x09}; // GPIO register
  uint8_t gpio_response[1];        // 8-bits representing gpio positions

  esp_rc =
      requestData(tagReadMCP23008(), dev, gpio_request, sizeof(gpio_request),
                  gpio_response, sizeof(gpio_request));

  if (esp_rc == ESP_OK) {
    dev->justSeen();

    positionsReading_t *reading = new positionsReading(
        dev->externalName(), time(nullptr), positions, (uint8_t)8);

    dev->setReading(reading);
    rc = true;
  }

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
  // ESP_LOGI(tagEngine(), "soil => sw_version=0x%04x tempC=%3.1f
  // moisture=%d",
  //          sw_version, tempC, soil_moisture);

  return rc;
}

bool mcrI2c::readSHT31(i2cDev_t *dev) {
  auto rc = false;
  esp_err_t esp_rc;

  uint8_t request[] = {
      0x2c, // single-shot measurement, with clock stretching
      0x06  // high-repeatability measurement (max duration 15ms)
  };
  uint8_t buff[] = {
      0x00, 0x00, // tempC high byte, low byte
      0x00,       // crc8 of temp
      0x00, 0x00, // relh high byte, low byte
      0x00        // crc8 of relh
  };

  esp_rc = requestData(tagReadSHT31(), dev, request, sizeof(request), buff,
                       sizeof(buff));

  if (esp_rc == ESP_OK) {
    dev->justSeen();

    if (crcSHT31(buff) && crcSHT31(&(buff[3]))) {
      // conversion from SHT31 datasheet
      uint16_t stc = (buff[0] << 8) | buff[1];
      uint16_t srh = (buff[3] << 8) | buff[4];

      float tc = (float)((stc * 175) / 0xffff) - 45;
      float rh = (float)((srh * 100) / 0xffff);

      humidityReading_t *reading = new humidityReading(
          dev->externalName(), dev->readTimestamp(), tc, rh);

      dev->setReading(reading);

      rc = true;
    } else { // crc did not match
      ESP_LOGW(tagReadSHT31(), "crc mismatch for %s", dev->debug().c_str());
      dev->crcMismatch();
    }
  }

  return rc;
}

void mcrI2c::report(void *task_data) {
  mcr::Net::waitForNormalOps();

  trackReport(true);

  for_each(beginDevices(), endDevices(), [this](i2cDev_t *dev) {
    auto rc = false;

    if (dev->available()) {
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

        if (rc) {
          publish(dev);
          ESP_LOGI(tagReport(), "%s success", dev->debug().c_str());
        } else {
          ESP_LOGE(tagReport(), "%s failed", dev->debug().c_str());
          // hardReset();
        }
      }
    } else {
      if (dev->missing()) {
        ESP_LOGW(tagReport(), "device missing: %s", dev->debug().c_str());
      }
    }
  });

  trackReport(false);
}

esp_err_t mcrI2c::requestData(const char *TAG, i2cDev_t *dev, uint8_t *send,
                              uint8_t send_len, uint8_t *recv, uint8_t recv_len,
                              esp_err_t prev_esp_rc, int timeout) {
  i2c_cmd_handle_t cmd = nullptr;
  esp_err_t esp_rc;

  dev->startRead();

  if (prev_esp_rc != ESP_OK) {
    dev->readFailure();
    dev->stopRead();
    return prev_esp_rc;
  }

  int _save_timeout = 0;
  if (timeout > 0) {
    i2c_get_timeout(I2C_NUM_0, &_save_timeout);
    ESP_LOGI(TAG, "saving previous i2c timeout: %d", _save_timeout);
    i2c_set_timeout(I2C_NUM_0, timeout);
  }

  cmd = i2c_cmd_link_create(); // allocate i2c cmd queue
  i2c_master_start(cmd);       // queue i2c START

  i2c_master_write_byte(cmd, dev->writeAddr(),
                        true); // queue the WRITE for device and check for ACK

  i2c_master_write(cmd, send, send_len,
                   I2C_MASTER_ACK); // queue the device command bytes

  // clock stretching is leveraged in the event the device requires time
  // to execute the command (e.g. temperature conversion)
  // use timeout to adjust time to wait for clock, if needed

  // start a new command sequence without sending a stop
  i2c_master_start(cmd);
  i2c_master_write_byte(cmd, dev->readAddr(),
                        true); // queue the READ for device and check for ACK

  i2c_master_read(cmd, recv, recv_len,
                  I2C_MASTER_LAST_NACK); // queue the READ of number of bytes
  i2c_master_stop(cmd);                  // queue i2c STOP

  // execute queued i2c cmd
  esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, _cmd_timeout);
  i2c_cmd_link_delete(cmd);

  if (esp_rc == ESP_OK) {
    // TODO: set to debug for production release
    ESP_LOGD(TAG, "ESP_OK: requestData(%s, %p, %d, %p, %d, %s, %d)",
             dev->debug().c_str(), send, send_len, recv, recv_len,
             esp_err_to_name(prev_esp_rc), timeout);
  } else {
    ESP_LOGE(TAG, "%s: requestData(%s, %p, %d, %p, %d, %s, %d)",
             esp_err_to_name(esp_rc), dev->debug().c_str(), send, send_len,
             recv, recv_len, esp_err_to_name(prev_esp_rc), timeout);
    dev->readFailure();
  }

  // if the timeout was changed restore it
  if (_save_timeout > 0) {
    i2c_set_timeout(I2C_NUM_0, _save_timeout);
  }

  dev->stopRead();

  return esp_rc;
}

void mcrI2c::run(void *task_data) {
  int wait_for_name_ms = 30000;
  bool driver_ready = false;
  bool net_name = false;
  while (!driver_ready) {
    driver_ready = installDriver();
  }

  ESP_LOGI(tagEngine(), "waiting for normal ops...");
  mcr::Net::waitForNormalOps();

  // wait for up to 30 seconds for name assigned by mcp
  // if the assigned name is not available then device names will use
  // the i2.c/mcr.<mac addr>.<bus>.<device> format

  // this is because i2c devices do not have a globally assigned
  // unique identifier (like Maxim / Dallas Semiconductors devices)
  ESP_LOGI(tagEngine(), "waiting up to %dms for network name...",
           wait_for_name_ms);
  net_name = mcr::Net::waitForName(pdMS_TO_TICKS(wait_for_name_ms));

  if (net_name == false) {
    ESP_LOGW(tagEngine(), "network name not available, using host name");
  }

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
  i2cDev_t multiplexer = i2cDev(_multiplexer_dev);
  esp_err_t esp_rc = ESP_FAIL;

  _bus_selects++;

  if (bus >= _max_buses) {
    ESP_LOGW(tagEngine(), "attempt to select bus %d >= %d, bus not changed",
             bus, _max_buses);
    return rc;
  }

  if (useMultiplexer() && (bus < _max_buses)) {
    // the bus is selected by sending a single byte to the multiplexer
    // device with the bit for the bus select
    uint8_t bus_cmd[1] = {(uint8_t)(0x01 << bus)};

    esp_rc = busWrite(&multiplexer, bus_cmd, 1);

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
      const char *msg = "BUS SELECT ERRORS EXCEEDED";
      ESP_LOGE(tagEngine(), "bus select errors exceeded, JUMP!");
      mcrNVS::commitMsg(tagEngine(), msg);
      mcrRestart::instance()->restart(msg, __PRETTY_FUNCTION__, 3000);
    }
  }

  return rc;
}

bool mcrI2c::wakeAM2315(i2cDev_t *dev) {
  uint8_t wake_request[] = {dev->firstAddressByte()};

  // wake up the AM2315 since it (by default) goes into low-power (sleep)
  // mode after 3s

  // NOTE: the AM2315 will not ACK the wake up request so we'll ignore
  // ignore esp error here.  i2c errors will be detected by functions
  // that utilize wakeAM2315()
  busWrite(dev, wake_request, sizeof(wake_request));

  return true;
}
