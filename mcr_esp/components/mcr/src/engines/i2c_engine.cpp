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
#include "engines/engine.hpp"
#include "engines/i2c_engine.hpp"
#include "misc/mcr_nvs.hpp"
#include "misc/mcr_restart.hpp"
#include "misc/mcr_types.hpp"
#include "net/mcr_net.hpp"
#include "protocols/mqtt.hpp"
#include "readings/readings.hpp"

namespace mcr {

static mcrI2c_t *__singleton__ = nullptr;
static const string_t engine_name = "mcrI2c";

mcrI2c::mcrI2c() {
  setTags(localTags());
  // setLoggingLevel(ESP_LOG_DEBUG);
  // setLoggingLevel(ESP_LOG_DEBUG);
  setLoggingLevel(ESP_LOG_INFO);
  // setLoggingLevel(ESP_LOG_WARN);
  // setLoggingLevel(tagEngine(), ESP_LOG_INFO);
  // setLoggingLevel(tagDetectDev(), ESP_LOG_INFO);
  // setLoggingLevel(tagDiscover(), ESP_LOG_INFO);
  // setLoggingLevel(tagReport(), ESP_LOG_INFO);
  // setLoggingLevel(tagReadSHT31(), ESP_LOG_INFO);

  EngineTask_t core("core");
  EngineTask_t command("cmd", CONFIG_MCR_I2C_COMMAND_TASK_PRIORITY, 3072);
  EngineTask_t discover("dis", CONFIG_MCR_I2C_DISCOVER_TASK_PRIORITY, 4096);
  EngineTask_t report("rpt", CONFIG_MCR_I2C_REPORT_TASK_PRIORITY, 3072);

  addTask(engine_name, CORE, core);
  addTask(engine_name, COMMAND, command);
  addTask(engine_name, DISCOVER, discover);
  addTask(engine_name, REPORT, report);

  gpio_config_t rst_pin_cfg;

  rst_pin_cfg.pin_bit_mask = RST_PIN_SEL;
  rst_pin_cfg.mode = GPIO_MODE_OUTPUT;
  rst_pin_cfg.pull_up_en = GPIO_PULLUP_DISABLE;
  rst_pin_cfg.pull_down_en = GPIO_PULLDOWN_DISABLE;
  rst_pin_cfg.intr_type = GPIO_INTR_DISABLE;

  gpio_config(&rst_pin_cfg);
}

//
// Tasks
//

void mcrI2c::command(void *data) {
  logSubTaskStart(data);

  _cmd_q = xQueueCreate(_max_queue_depth, sizeof(CmdSwitch_t *));
  cmdQueue_t cmd_q = {"mcrI2c", "i2c", _cmd_q};
  mcrCmdQueues::registerQ(cmd_q);

  while (true) {
    BaseType_t queue_rc = pdFALSE;
    CmdSwitch_t *cmd = nullptr;

    queue_rc = xQueueReceive(_cmd_q, &cmd, portMAX_DELAY);
    // wrap in a unique_ptr so it is freed when out of scope
    std::unique_ptr<CmdSwitch> cmd_ptr(cmd);
    elapsedMicros process_cmd;

    if (queue_rc == pdFALSE) {
      ESP_LOGW(tagCommand(), "[rc=%d] queue receive failed", queue_rc);
      continue;
    }

    ESP_LOGD(tagCommand(), "processing %s", cmd->debug().get());

    // is the command for this mcr?

    const string_t &mcr_name = Net::getName();

    if (cmd->matchExternalDevID(mcr_name) == false) {
      continue;
    }

    cmd->translateDevID(mcr_name, "self");

    i2cDev_t *dev = findDevice(cmd->internalDevID());

    if ((dev != nullptr) && dev->isValid()) {
      bool set_rc = false;

      trackSwitchCmd(true);

      needBus();
      ESP_LOGV(tagCommand(), "attempting to aquire bux mutex...");
      elapsedMicros bus_wait;
      takeBus();

      if (bus_wait < 500) {
        ESP_LOGV(tagCommand(), "acquired bus mutex (%lluus)",
                 (uint64_t)bus_wait);
      } else {
        ESP_LOGW(tagCommand(), "acquire bus mutex took %0.2fms",
                 (float)(bus_wait / 1000.0));
      }

      // the device write time is the total duration of all processing
      // of the write -- not just the duration on the bus
      dev->startWrite();

      ESP_LOGI(tagCommand(), "received cmd for %s", dev->id().c_str());
      set_rc = setMCP23008(*cmd, dev);

      if (set_rc) {
        commandAck(*cmd);
      }

      trackSwitchCmd(false);

      clearNeedBus();
      giveBus();

      ESP_LOGV(tagCommand(), "released bus mutex");
    } else {
      ESP_LOGW(tagCommand(), "device %s not available",
               (const char *)cmd->internalDevID().c_str());
    }

    if (process_cmd > 100000) { // 100ms
      ESP_LOGW(tagCommand(), "took %0.3fms for %s",
               (float)(process_cmd / 1000.0), cmd->debug().get());
    }
  }
}

bool mcrI2c::commandAck(CmdSwitch_t &cmd) {
  bool rc = true;
  elapsedMicros elapsed;
  i2cDev_t *dev = findDevice(cmd.internalDevID());

  if (dev != nullptr) {
    rc = readDevice(dev);

    if (rc && cmd.ack()) {
      setCmdAck(cmd);
      publish(cmd);
    }
  } else {
    ESP_LOGW(tagCommand(), "unable to find device for cmd ack %s",
             cmd.debug().get());
  }

  ESP_LOGI(tagCommand(), "completed cmd: %s", cmd.debug().get());

  if (elapsed > 100000) { // 100ms
    float elapsed_ms = (float)(elapsed / 1000.0);
    ESP_LOGW(tagCommand(), "ACK took %0.3fms", elapsed_ms);
  }

  return rc;
}

void mcrI2c::core(void *task_data) {
  bool driver_ready = false;
  bool net_name = false;

  while (!driver_ready) {
    driver_ready = installDriver();
    delay(1000); // prevent busy loop if i2c driver fails to install
  }

  pinReset();

  ESP_LOGV(tagEngine(), "waiting for normal ops...");
  Net::waitForNormalOps();

  // wait for up to 30 seconds for name assigned by mcp
  // if the assigned name is not available then device names will use
  // the i2.c/mcr.<mac addr>.<bus>.<device> format

  // this is because i2c devices do not have a globally assigned
  // unique identifier (like Maxim / Dallas Semiconductors devices)
  ESP_LOGV(tagEngine(), "waiting for network name...");
  net_name = Net::waitForName();

  if (net_name == false) {
    ESP_LOGW(tagEngine(), "network name not available, using host name");
  }

  ESP_LOGV(tagEngine(), "normal ops, proceeding to task loop");

  saveTaskLastWake(CORE);
  for (;;) {
    // signal to other tasks the dsEngine task is in it's run loop
    // this ensures all other set-up activities are complete before
    engineRunning();

    // do high-level engine actions here (e.g. general housekeeping)
    taskDelayUntil(CORE, _loop_frequency);
  }
}

void mcrI2c::discover(void *data) {
  logSubTaskStart(data);
  saveTaskLastWake(DISCOVER);
  bool detect_rc = true;

  while (waitForEngine()) {

    takeBus();
    trackDiscover(true);
    detectMultiplexer();

    if (useMultiplexer()) {
      for (uint32_t bus = 0; (detect_rc && (bus < maxBuses())); bus++) {
        ESP_LOGV(tagDetectDev(), "scanning bus %#02x", bus);
        detect_rc = detectDevicesOnBus(bus);
      }
    } else { // multiplexer not available, just search bus 0
      detect_rc = detectDevicesOnBus(0x00);
    }

    giveBus();

    // signal to other tasks if there are devices available
    // after delaying a bit (to improve i2c bus stability)
    delay(100);
    trackDiscover(false);

    if (numKnownDevices() > 0) {
      devicesAvailable();
    }

    // we want to discover
    saveTaskLastWake(DISCOVER);
    taskDelayUntil(DISCOVER, _discover_frequency);
  }
}

void mcrI2c::report(void *data) {

  logSubTaskStart(data);
  saveTaskLastWake(REPORT);

  while (waitFor(devicesAvailableBit())) {
    if (numKnownDevices() == 0) {
      taskDelayUntil(REPORT, _report_frequency);
      continue;
    }

    Net::waitForNormalOps();

    trackReport(true);

    for_each(beginDevices(), endDevices(),
             [this](std::pair<string_t, i2cDev_t *> item) {
               auto dev = item.second;

               if (dev->available()) {
                 takeBus();

                 if (readDevice(dev)) {
                   publish(dev);
                   ESP_LOGV(tagReport(), "%s success", dev->debug().get());
                 } else {
                   ESP_LOGE(tagReport(), "%s failed", dev->debug().get());
                   // hardReset();
                 }

                 giveBus();

               } else {
                 if (dev->missing()) {
                   ESP_LOGW(tagReport(), "device missing: %s",
                            dev->debug().get());
                 }
               }
             });

    trackReport(false);
    reportMetrics();

    taskDelayUntil(REPORT, _report_frequency);
  }
}

esp_err_t mcrI2c::busRead(i2cDev_t *dev, uint8_t *buff, uint32_t len,
                          esp_err_t prev_esp_rc) {
  i2c_cmd_handle_t cmd = nullptr;
  esp_err_t esp_rc;

  if (prev_esp_rc != ESP_OK) {
    ESP_LOGV(tagEngine(),
             "aborted bus_read(%s, ...) invoked with prev_esp_rc = %s",
             dev->debug().get(), esp_err_to_name(prev_esp_rc));
    return prev_esp_rc;
  }

  int timeout = 0;
  i2c_get_timeout(I2C_NUM_0, &timeout);
  ESP_LOGV(tagEngine(), "i2c timeout: %d", timeout);

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
    ESP_LOGV(tagEngine(), "ESP_OK: bus_read(%s, %p, %d, %s)",
             dev->debug().get(), buff, len, esp_err_to_name(prev_esp_rc));
  } else {
    ESP_LOGD(tagEngine(), "%s: bus_read(%s, %p, %d, %s)",
             esp_err_to_name(esp_rc), dev->debug().get(), buff, len,
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
    ESP_LOGV(tagEngine(),
             "aborted bus_write(%s, ...) invoked with prev_esp_rc = %s",
             dev->debug().get(), esp_err_to_name(prev_esp_rc));
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
    ESP_LOGV(tagEngine(), "ESP_OK: bus_write(%s, %p, %d, %s)",
             dev->debug().get(), bytes, len, esp_err_to_name(prev_esp_rc));
  } else {
    ESP_LOGD(tagEngine(), "%s: bus_write(%s, %p, %d, %s)",
             esp_err_to_name(esp_rc), dev->debug().get(), bytes, len,
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

  ESP_LOGV(tagDetectDev(), "looking for %s", dev->debug().get());

  switch (dev->devAddr()) {

  case 0x70: // TCA9548B - TI i2c bus multiplexer
  case 0x44: // SHT-31 humidity sensor
  case 0x20: // MCP23008 0x20 - 0x27
  case 0x21:
  case 0x22:
  case 0x23:
  case 0x24:
  case 0x25:
  case 0x26:
  case 0x27:
  case 0x36: // STEMMA (seesaw based soil moisture sensor)
    esp_rc = busWrite(dev, detect_cmd, sizeof(detect_cmd));
    break;
  }

  if (esp_rc == ESP_OK) {
    rc = true;
  } else {

    ESP_LOGD(tagEngine(), "%s not found (%s)", dev->debug().get(),
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
          ESP_LOGV(tagDiscover(), "already know %s", found->debug().get());
        } else { // device was not known, must add
          i2cDev_t *new_dev = new i2cDev(dev);

          ESP_LOGI(tagDiscover(), "new (%p) %s", (void *)new_dev,
                   dev.debug().get());
          addDevice(new_dev);
        }

        devicesAvailable();
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
      ESP_LOGV(tagDetectDev(), "found TCA9548A multiplexer");
      _use_multiplexer = true;
    }
    break;

  case BASIC:
    _use_multiplexer = false;
    break;

  case I2C_MULTIPLEXER:
    ESP_LOGD(tagDetectDev(), "hardware configured for multiplexer");
    _use_multiplexer = true;
    break;
  }

  return _use_multiplexer;
}

bool mcrI2c::hardReset() {
  esp_err_t rc;

  ESP_LOGE(tagEngine(), "hard reset of i2c peripheral");

  delay(1000);

  rc = i2c_driver_delete(I2C_NUM_0);
  ESP_LOGV(tagEngine(), "i2c_driver_delete() == %s", espError(rc));

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
  ESP_LOGV(tagEngine(), "%s i2c_param_config()", esp_err_to_name(esp_err));

  if (esp_err == ESP_OK) {
    esp_err = i2c_driver_install(I2C_NUM_0, _conf.mode, 0, 0, 0);
    ESP_LOGV(tagEngine(), "%s i2c_driver_install()", esp_err_to_name(esp_err));
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
bool mcrI2c::pinReset() {

  ESP_LOGI(tagEngine(), "pulling reset pin low");
  gpio_set_level(RST_PIN, 0); // pull the pin low to reset i2c devices
  delay(1000);                // give plenty of time for all devices to reset
  gpio_set_level(RST_PIN, 1); // bring all devices online
  ESP_LOGI(tagEngine(), "pulling reset pin high");

  return true;
}

void mcrI2c::printUnhandledDev(i2cDev_t *dev) {
  ESP_LOGW(tagEngine(), "unhandled dev %s", dev->debug().get());
}

bool mcrI2c::useMultiplexer() { return _use_multiplexer; }

bool mcrI2c::readDevice(i2cDev_t *dev) {
  auto rc = false;

  if (selectBus(dev->bus())) {
    switch (dev->devAddr()) {

    case 0x44:
      rc = readSHT31(dev);
      break;

    case 0x20: // MCP23008 can be user configured to 0x20 + three bits
    case 0x21:
    case 0x22:
    case 0x23:
    case 0x24:
    case 0x25:
    case 0x26:
    case 0x27:
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

  return rc;
}

bool mcrI2c::readMCP23008(i2cDev_t *dev) {
  auto rc = false;
  auto positions = 0b00000000;
  esp_err_t esp_rc;

  RawData_t request{0x00}; // IODIR Register (address 0x00)

  // register       register      register          register
  // 0x00 - IODIR   0x01 - IPOL   0x02 - GPINTEN    0x03 - DEFVAL
  // 0x04 - INTCON  0x05 - IOCON  0x06 - GPPU       0x07 - INTF
  // 0x08 - INTCAP  0x09 - GPIO   0x0a - OLAT

  // at POR the MCP2x008 operates in sequential mode where continued reads
  // automatically increment the address (register).  we read all registers
  // (12 bytes) in one shot.
  RawData_t all_registers;
  all_registers.resize(12); // 12 bytes (0x00-0x0a)

  esp_rc = requestData(tagReadMCP23008(), dev, request.data(), request.size(),
                       all_registers.data(), all_registers.capacity());

  if (esp_rc == ESP_OK) {
    // GPIO register is little endian so no conversion is required
    positions = all_registers[0x0a]; // OLAT register (address 0x0a)

    dev->storeRawData(all_registers);

    dev->justSeen();

    positionsReading_t *reading = new positionsReading(
        dev->externalName(), time(nullptr), positions, (uint8_t)8);

    reading->setLogReading();
    dev->setReading(reading);
    rc = true;
  } else {
    ESP_LOGW(tagReadMCP23008(), "[%s] %s read", esp_err_to_name(esp_rc),
             dev->id().c_str());
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
      ESP_LOGW(tagReadSHT31(), "crc mismatch for %s", dev->debug().get());
      dev->crcMismatch();
    }
  }

  return rc;
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
    ESP_LOGV(TAG, "saving previous i2c timeout: %d", _save_timeout);
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

  if ((recv != nullptr) && (recv_len > 0)) {
    // start a new command sequence without sending a stop
    i2c_master_start(cmd);
    i2c_master_write_byte(cmd, dev->readAddr(),
                          true); // queue the READ for device and check for ACK

    i2c_master_read(cmd, recv, recv_len,
                    I2C_MASTER_LAST_NACK); // queue the READ of number of bytes
    i2c_master_stop(cmd);                  // queue i2c STOP
  }

  // execute queued i2c cmd
  esp_rc = i2c_master_cmd_begin(I2C_NUM_0, cmd, _cmd_timeout);
  i2c_cmd_link_delete(cmd);

  if (esp_rc == ESP_OK) {
    // TODO: set to debug for production release
    ESP_LOGV(TAG, "ESP_OK: requestData(%s, %p, %d, %p, %d, %s, %d)",
             dev->debug().get(), send, send_len, recv, recv_len,
             esp_err_to_name(prev_esp_rc), timeout);
  } else {
    ESP_LOGE(TAG, "%s: requestData(%s, %p, %d, %p, %d, %s, %d)",
             esp_err_to_name(esp_rc), dev->debug().get(), send, send_len, recv,
             recv_len, esp_err_to_name(prev_esp_rc), timeout);
    dev->readFailure();
  }

  // if the timeout was changed restore it
  if (_save_timeout > 0) {
    i2c_set_timeout(I2C_NUM_0, _save_timeout);
  }

  dev->stopRead();

  return esp_rc;
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
      mcrRestart::instance()->restart(msg, __PRETTY_FUNCTION__, 0);
    }
  }

  return rc;
}

bool mcrI2c::setMCP23008(CmdSwitch_t &cmd, i2cDev_t *dev) {
  bool rc = false;
  auto esp_rc = ESP_OK;

  textReading *rlog = new textReading_t;
  textReading_ptr_t rlog_ptr(rlog);
  RawData_t tx_data;

  tx_data.reserve(12);

  // read the device to ensure we have the current state
  // important because setting the new state relies, in part, on the existing
  // state for the pios not changing
  if (readDevice(dev) == false) {
    rlog->reuse();
    rlog->printf("%s SET FAILED read before set", dev->debug().get());
    rlog->publish();
    rlog->consoleWarn(tagSetMCP23008());

    return rc;
  }

  positionsReading_t *reading = (positionsReading_t *)dev->reading();

  // if register 0x00 (IODIR) is not 0x00 (IODIR isn't output) then
  // set it to output
  if (dev->rawData().at(0) > 0x00) {
    tx_data.insert(tx_data.end(), {0x00, 0x00});
    esp_rc = requestData(tagSetMCP23008(), dev, tx_data.data(), tx_data.size(),
                         nullptr, 0, esp_rc);
  }

  auto mask = cmd.mask().to_ulong();
  auto changes = cmd.state().to_ulong();
  auto asis_state = reading->state();
  auto new_state = 0x00;

  // XOR the new state against the as_is state using the mask
  // it is critical that we use the recently read state to avoid
  // overwriting the device state that MCP is not aware of
  new_state = asis_state ^ ((asis_state ^ changes) & mask);

  // to set the GPIO we will write to two registers:
  // a. IODIR (0x00) - setting all GPIOs to output (0b00000000)
  // b. OLAT (0x0a)  - the new state
  tx_data.clear();
  tx_data.insert(tx_data.end(), {0x0a, (uint8_t)(new_state & 0xff)});

  esp_rc = requestData(tagSetMCP23008(), dev, tx_data.data(), tx_data.size(),
                       nullptr, 0, esp_rc);

  if (esp_rc != ESP_OK) {
    rlog->reuse();
    rlog->printf("%s SET FAILED cmd esp_rc(%s)", dev->debug().get(),
                 esp_err_to_name(esp_rc));
    rlog->publish();
    rlog->consoleWarn(tagSetMCP23008());

    return rc;
  }

  rc = true;
  rlog->publish();

  return rc;
}

} // namespace mcr
