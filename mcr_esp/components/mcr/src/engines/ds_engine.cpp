/*
       mcpr_ds.cpp - Master Control Remote Dallas Semiconductor
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

#include <bitset>
#include <cstdlib>
#include <cstring>
#include <string>

#include <FreeRTOS.h>
#include <System.h>
#include <Task.h>
#include <cJSON.h>
#include <esp_log.h>
#include <esp_timer.h>
#include <freertos/event_groups.h>
#include <freertos/queue.h>

#include "base.hpp"
#include "cmd.hpp"
#include "ds_dev.hpp"
#include "ds_engine.hpp"
#include "engine.hpp"
#include "mcr_types.hpp"
#include "mqtt.hpp"
#include "owb.h"
#include "owb_gpio.h"
#include "util.hpp"

static const char mTAG[] = "mcrDS";
static const char disTAG[] = "mcrDS discover";
static const char conTAG[] = "mcrDS convert";
static const char repTAG[] = "mcrDS report";
static const char cmdTAG[] = "mcrDS cmd";
static const char ds1820TAG[] = "mcrDS readDS1820";
static const char ds2406TAG[] = "mcrDS readDS2406";
static const char ds2408TAG[] = "mcrDS readDS2408";
static const char setds2406TAG[] = "mcrDS setDS2406";
static const char setds2408TAG[] = "mcrDS setDS2408";

mcrDS::mcrDS(mcrMQTT_t *mqtt, EventGroupHandle_t evg, int bit)
    : mcrEngine(mqtt), Task(mTAG, 3 * 1024, 14) {
  _ev_group = evg;
  _wait_bit = bit;

  esp_log_level_t log_level = ESP_LOG_WARN;
  const char *log_tags[] = {disTAG,    conTAG,    repTAG,    cmdTAG,
                            ds1820TAG, ds2406TAG, ds2408TAG, nullptr};

  for (int i = 0; log_tags[i] != nullptr; i++) {
    ESP_LOGI(mTAG, "%s logging at level=%d", log_tags[i], log_level);
    esp_log_level_set(log_tags[i], log_level);
  }
}

bool mcrDS::checkDevicesPowered() {
  bool rc = false;
  bool present = false;
  owb_status owb_s;
  uint8_t read_pwr_cmd[] = {0xcc, 0xb4};
  uint8_t pwr = 0x00;

  owb_s = owb_reset(ds, &present);

  owb_s = owb_write_bytes(ds, read_pwr_cmd, sizeof(read_pwr_cmd));
  owb_s = owb_read_byte(ds, &pwr);

  if ((owb_s == OWB_STATUS_OK) && pwr) {
    ESP_LOGI(disTAG, "all devices are powered");
    rc = true;
  } else {
    ESP_LOGW(disTAG, "at least one device is not powered (or err owb_s=%d)",
             owb_s);
  }

  // reest the bus since this can be used in the middle of other actions
  owb_s = owb_reset(ds, &present);

  return rc;
}

void mcrDS::command(void *task_data) {
  // no setup required before jumping into task loop

  for (;;) {
    BaseType_t queue_rc = pdFALSE;
    mcrCmd_t *cmd = nullptr;

    queue_rc = xQueueReceive(_cmd_q, &cmd, portMAX_DELAY);

    if (queue_rc != pdTRUE) {
      ESP_LOGW(cmdTAG, "queue receive failed rc=%d", queue_rc);
      continue;
    }

    ESP_LOGD(cmdTAG, "processing %s", cmd->debug().c_str());

    dsDev_t *dev = (dsDev_t *)getDeviceByCmd(*cmd);

    if (dev == nullptr) {
      ESP_LOGD(cmdTAG, "device %s not available", (const char *)cmd->dev_id());
    }

    if (dev) {
      bool set_rc = false;

      ESP_LOGI(cmdTAG, "phase started");
      trackSwitchCmd(true);

      ESP_LOGD(cmdTAG, "attempting to aquire bux mutex...");
      xSemaphoreTake(_bus_mutex, portMAX_DELAY);
      ESP_LOGD(cmdTAG, "acquired bus mutex");

      if (dev->isDS2406())
        set_rc = setDS2406(*cmd, dev);

      if (dev->isDS2408())
        set_rc = setDS2408(*cmd, dev);

      if ((set_rc) && commandAck(*cmd)) {
        ESP_LOGD(cmdTAG, "cmd and ack complete %s",
                 (const char *)cmd->dev_id());
      } else {
        ESP_LOGW(cmdTAG, "cmd and/or ack failed for %s",
                 (const char *)cmd->dev_id());
      }

      trackSwitchCmd(false);
      xSemaphoreGive(_bus_mutex);

      ESP_LOGD(cmdTAG, "released bus mutex");
      ESP_LOGI(cmdTAG, "phase took %lldms", switchCmdUS() / 1000);
    }

    delete cmd;
  }
}

bool mcrDS::commandAck(mcrCmd_t &cmd) {
  bool rc = true;

  rc = readDevice(cmd);
  if (rc == true) {
    setCmdAck(cmd);
    ESP_LOGI(cmdTAG, "completed cmd: %s", cmd.debug().c_str());
    publishDevice(cmd);
  }

  return rc;
}

void mcrDS::convert(void *task_data) {
  bool temp_convert_done = false;
  bool present = false;
  uint8_t data = 0x00;

  owb_status owb_s;
  uint8_t temp_convert_cmd[] = {0xcc, 0x44};

  // ensure the temp available bit is cleared at task startup
  xEventGroupClearBits(_ds_evg, _event_bits.temp_available);
  _last_wake.convert = xTaskGetTickCount(); // init last wake time

  for (;;) {
    // wait here for the signal there are devices available
    xEventGroupWaitBits(_ds_evg, _event_bits.devices_available,
                        pdFALSE, // don't clear the bit after waiting
                        pdTRUE,  // wait for all bits, not really needed here
                        portMAX_DELAY);

    // use event bits to signal when there are temperatures available
    // start by clearing the bit to signal there isn't a temperature available
    xEventGroupClearBits(_ds_evg, _event_bits.temp_available);

    if (!devicesPowered() && !tempDevicesPresent()) {
      ESP_LOGW(conTAG, "devices not powered or no temperature devices present");
      vTaskDelayUntil(&(_last_wake.convert), _convert_frequency);
      continue;
    }

    ESP_LOGI(conTAG, "phase started");
    xSemaphoreTake(_bus_mutex, portMAX_DELAY);

    owb_s = owb_reset(ds, &present);

    if (!present) {
      ESP_LOGW(conTAG, "no devices present");
      xSemaphoreGive(_bus_mutex);
      vTaskDelayUntil(&(_last_wake.convert), _convert_frequency);
      continue;
    }

    trackConvert(true);

    owb_s = owb_reset(ds, &present);
    owb_s = owb_write_bytes(ds, temp_convert_cmd, sizeof(temp_convert_cmd));
    owb_s = owb_read_byte(ds, &data);

    // we cheat a bit here and only check the owb status of the read
    if ((owb_s != OWB_STATUS_OK) || (data != 0x00)) {
      trackConvert(false);
      ESP_LOGW(conTAG, "owb error owb_s=%d data=0x%x", owb_s, data);
      xSemaphoreGive(_bus_mutex);
      vTaskDelayUntil(&(_last_wake.convert), _convert_frequency);
      continue;
    }

    ESP_LOGD(conTAG, "in-progress");

    delay(pdMS_TO_TICKS(450)); // will take at least this long

    while ((owb_s == 0) && (data == 0x00)) {
      delay(_temp_convert_wait);
      owb_s = owb_read_byte(ds, &data);
      temp_convert_done = true;
    }

    trackConvert(false);

    xSemaphoreGive(_bus_mutex);

    // signal to other tasks that temperatures are now available
    if (temp_convert_done) {
      xEventGroupSetBits(_ds_evg, _event_bits.temp_available);
    }

    ESP_LOGI(conTAG, "phase took %lldms", convertUS() / 1000);
    vTaskDelayUntil(&(_last_wake.convert), _convert_frequency);
  }
}

void mcrDS::discover(void *task_data) {
  xEventGroupWaitBits(_ds_evg, _event_bits.engine_running,
                      pdFALSE, // don't clear the bit after waiting
                      pdTRUE,  // wait for all bits, not really needed here
                      portMAX_DELAY);

  // ensure the devices available bit is cleared on task startup
  xEventGroupClearBits(_ds_evg, _event_bits.devices_available);

  _last_wake.discover = xTaskGetTickCount();

  // there is no reason to wait for anything before doing the first
  // discover -- let's take advantage of other startup items to get this
  // out of the way

  for (;;) {
    owb_status owb_s;
    bool present = false;
    bool found = false;
    auto device_found = false;
    OneWireBus_SearchState search_state;
    bzero(&search_state, sizeof(OneWireBus_SearchState));

    ESP_LOGI(disTAG, "phase started");

    xSemaphoreTake(_bus_mutex, portMAX_DELAY);

    owb_s = owb_reset(ds, &present);

    if (!present) {
      ESP_LOGW(disTAG, "no devices present");
      xSemaphoreGive(_bus_mutex);
      vTaskDelayUntil(&(_last_wake.discover), _discover_frequency);
      continue;
    }

    trackDiscover(true);

    owb_s = owb_search_first(ds, &search_state, &found);

    if (owb_s != OWB_STATUS_OK) {
      ESP_LOGW(disTAG, "search first failed owb_s=%d", owb_s);
      xSemaphoreGive(_bus_mutex);
      vTaskDelayUntil(&(_last_wake.discover), _discover_frequency);
      continue;
    }

    while ((owb_s == OWB_STATUS_OK) && found) {
      device_found = true;

      mcrDevAddr_t found_addr(search_state.rom_code.bytes, 8);
      dsDev_t dev(found_addr, true);

      if (justSeenDevice(dev)) {
        ESP_LOGD(disTAG, "previously seen %s", dev.debug().c_str());
      } else {
        dsDev_t *new_dev = new dsDev(dev);
        // ESP_LOGI(disTAG, "new (%p) %s", (void *)new_dev, (char *)dev.id());
        ESP_LOGI(disTAG, "new (%p) %s", (void *)new_dev, dev.debug().c_str());
        addDevice(new_dev);
      }

      owb_s = owb_search_next(ds, &search_state, &found);

      if (owb_s != OWB_STATUS_OK) {
        ESP_LOGW(disTAG, "search next failed owb_s=%d", owb_s);
      }
    }

    // TODO: create specific logic to detect pwr status of each family code
    // ds->reset();
    // ds->select(addr);
    // ds->write(0xB4); // Read Power Supply
    // uint8_t pwr = ds->read_bit();

    _devices_powered = checkDevicesPowered();

    trackDiscover(false);

    xSemaphoreGive(_bus_mutex);

    if (device_found) {
      // signal other tasks that there are, in fact, devices available
      xEventGroupSetBits(_ds_evg, _event_bits.devices_available);
    }

    ESP_LOGI(disTAG, "phase took %lldms", discoverUS() / 1000);
    vTaskDelayUntil(&(_last_wake.discover), _discover_frequency);
  }
}

// publish a device
bool mcrDS::publishDevice(mcrCmd_t &cmd) {
  mcrDevID_t &dev_id = cmd.dev_id();

  return publishDevice(dev_id);
}

bool mcrDS::publishDevice(mcrDevID_t &id) {
  return publishDevice((dsDev_t *)getDevice(id));
}

bool mcrDS::publishDevice(dsDev_t *dev) {
  bool rc = true;

  Reading_t *reading = dev->reading();

  if (reading != nullptr) {
    publish(reading);
  }
  return rc;
}

void mcrDS::report(void *task_data) {
  bool rc = true;
  mcrDev_t *next_dev = nullptr;
  dsDev_t *dev = nullptr;

  for (;;) {
    // let's wait here for the engine running bit
    // important to ensure we don't start reporting before the rest of the
    // system is fully available (e.g. wifi, mqtt)
    xEventGroupWaitBits(_ds_evg, _event_bits.engine_running,
                        pdFALSE, // don't clear the bit
                        pdTRUE,  // wait for all bits, not really needed here
                        portMAX_DELAY);

    // let's wait here for the temperature available bit
    // once we see it then clear it to ensure we don't run again until
    // it's available again
    xEventGroupWaitBits(_ds_evg, _event_bits.temp_available,
                        pdTRUE, // clear the bit after waiting
                        pdTRUE, // wait for all bits, not really needed here
                        portMAX_DELAY);

    next_dev = getFirstKnownDevice();
    ESP_LOGI(repTAG, "phase started");

    trackReport(true);

    while (next_dev != nullptr) {
      dev = (dsDev_t *)next_dev;

      xSemaphoreTake(_bus_mutex, portMAX_DELAY);
      rc = readDevice(dev->id());

      if (rc)
        publishDevice(dev);

      xSemaphoreGive(_bus_mutex);

      // if (LOG_LOCAL_LEVEL >= ESP_LOG_DEBUG) {
      //   ESP_LOGD(repTAG, "%s", dev->debug());
      // }

      next_dev = getNextKnownDevice();
    }

    trackReport(false);

    ESP_LOGI(repTAG, "phase took %lldms", reportUS() / 1000);
  }
}

bool mcrDS::readDevice(mcrCmd_t &cmd) {
  mcrDevID_t &dev_id = cmd.dev_id();

  return readDevice(dev_id);
}

bool mcrDS::readDevice(const mcrDevID_t &id) {
  return readDevice((dsDev_t *)getDevice(id));
}

bool mcrDS::readDevice(dsDev_t *dev) {
  celsiusReading_t *celsius = nullptr;
  positionsReading_t *positions = nullptr;
  auto rc = true;

  if ((dev == nullptr) || (dev->isNotValid())) {
    printInvalidDev(dev);
    return false;
  }

  switch (dev->family()) {
  case 0x10: // DS1820 (temperature sensors)
  case 0x22:
  case 0x28:
    dev->startRead();
    rc = readDS1820(dev, &celsius);
    dev->stopRead();
    dev->setReading(celsius);
    break;

  case 0x29: // DS2408 (8-channel switch)
    rc = readDS2408(dev, &positions);
    dev->setReading(positions);
    break;

  case 0x12: // DS2406 (2-channel switch with 1k EPROM)
    rc = readDS2406(dev, &positions);
    dev->setReading(positions);
    break;

  default:
    ESP_LOGW(mTAG, "unknown family %d", dev->family());
  }

  return rc;
}

// specific device scratchpad methods
bool mcrDS::readDS1820(dsDev *dev, celsiusReading_t **reading) {
  bool present = false;
  owb_status owb_s;
  uint8_t data[9] = {0x00};
  bool type_s = false;
  bool rc = false;

  owb_s = owb_reset(ds, &present);

  if (owb_s != OWB_STATUS_OK) {
    ESP_LOGW(ds1820TAG, "no devices present");
    return rc;
  }

  switch (dev->family()) {
  case 0x10:
    type_s = true;
    break;
  default:
    type_s = false;
  }

  dev->startRead();
  uint8_t cmd[] = {0x55, // match rom_code
                   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // rom
                   0xbe}; // read scratchpad

  dev->copyAddrToCmd(cmd);

  owb_s = owb_write_bytes(ds, cmd, sizeof(cmd));

  if (owb_s != OWB_STATUS_OK) {
    ESP_LOGW(ds1820TAG, "failed to send read scratchpad owb_s=%d", owb_s);
    return rc;
  }

  owb_s = owb_read_bytes(ds, data, sizeof(data));
  owb_reset(ds, &present);

  if (owb_s != OWB_STATUS_OK) {
    ESP_LOGW(ds1820TAG, "failed to read scratchpad owb_s=%d", owb_s);
    return rc;
  }

  // Convert the data to actual temperature
  // because the result is a 16 bit signed integer, it should
  // be stored to an "int16_t" type, which is always 16 bits
  // even when compiled on a 32 bit processor.
  int16_t raw = (data[1] << 8) | data[0];
  if (type_s) {
    raw = raw << 3; // 9 bit resolution default
    if (data[7] == 0x10) {
      // "count remain" gives full 12 bit resolution
      raw = (raw & 0xFFF0) + 12 - data[6];
    }
  } else {
    uint32_t cfg = (data[4] & 0x60);
    // at lower res, the low bits are undefined, so let's zero them
    if (cfg == 0x00)
      raw = raw & ~7; // 9 bit resolution, 93.75 ms
    else if (cfg == 0x20)
      raw = raw & ~3; // 10 bit res, 187.5 ms
    else if (cfg == 0x40)
      raw = raw & ~1; // 11 bit res, 375 ms
    //// default is 12 bit resolution, 750 ms conversion time
  }
  float celsius = (float)raw / 16.0;

  rc = true;
  *reading = new celsiusReading(dev->id(), lastConvertTimestamp(), celsius);

  return rc;
}

bool mcrDS::readDS2406(dsDev *dev, positionsReading_t **reading) {
  bool present = false;
  owb_status owb_s;
  bool rc = false;

  owb_s = owb_reset(ds, &present);

  if (owb_s != OWB_STATUS_OK) {
    ESP_LOGW(ds2406TAG, "no devices present");
    return rc;
  }

  uint8_t cmd[] = {0x55, // match rom_code
                   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // rom
                   0xaa,        // read status cmd
                   0x00, 0x00}; // address (start at beginning)

  uint8_t buff[] = {0x00, 0x00, 0x00, 0x00, 0x00, // byte 0-4: EPROM bitmaps
                    0x00, // byte 5: EPROM Factory Test Byte
                    0x00, // byte 6: Don't care (always reads 0x00)
                    0x00, // byte 7: SRAM (channel flip-flops, power, etc.)
                    0x00, 0x00}; // byte 8-9: CRC16

  dev->startRead();
  dev->copyAddrToCmd(cmd);

  owb_s = owb_write_bytes(ds, cmd, sizeof(cmd));

  if (owb_s != OWB_STATUS_OK) {
    dev->stopRead();
    ESP_LOGW(ds2406TAG, "failed to send read cmd owb_s=%d", owb_s);
    return rc;
  }

  // fill buffer with bytes from DS2406, skipping the first byte
  // since the first byte is included in the CRC16
  owb_s = owb_read_bytes(ds, buff, sizeof(buff));
  dev->stopRead();

  if (owb_s != OWB_STATUS_OK) {
    ESP_LOGW(ds2406TAG, "failed to read cmd results owb_s=%d", owb_s);
    return rc;
  }

  owb_s = owb_reset(ds, &present);

  uint32_t raw = buff[sizeof(buff) - 3];

  uint32_t positions = 0x00;  // translate raw status to 0b000000xx
  if ((raw & 0x20) == 0x00) { // to represent PIO.A as bit 0
    positions = 0x01;         // and PIO.B as bit 1
  }                           // reminder to invert the bits since the device
                              // represents on/off opposite of true/false
  if ((raw & 0x40) == 0x00) {
    positions = (positions | 0x02);
  }

  rc = true;
  *reading =
      new positionsReading(dev->id(), time(nullptr), positions, (uint8_t)2);

  return rc;
}

bool mcrDS::readDS2408(dsDev *dev, positionsReading_t **reading) {
  bool present = false;
  owb_status owb_s;
  bool rc = false;

  owb_s = owb_reset(ds, &present);

  if (owb_s != OWB_STATUS_OK) {
    ESP_LOGW(ds2408TAG, "no devices present");
    return rc;
  }
  // byte data[12]
  uint8_t dev_cmd[] = {
      0x55,                                           // byte 0: match ROM
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // byte 1-8: rom
      0xf5,                   // byte 9: channel access read cmd
      0x00, 0x00, 0x00, 0x00, // bytes 10-41: channel state data
      0x00, 0x00, 0x00, 0x00, // channel state data
      0x00, 0x00, 0x00, 0x00, // channel state data
      0x00, 0x00, 0x00, 0x00, // channel state data
      0x00, 0x00, 0x00, 0x00, // channel state data
      0x00, 0x00, 0x00, 0x00, // channel state data
      0x00, 0x00, 0x00, 0x00, // channel state data
      0x00, 0x00, 0x00, 0x00, // channel state data
      0x00, 0x00};            // bytes 42-43: CRC16

  dev->startRead();
  dev->copyAddrToCmd(dev_cmd);

  // send bytes through the Channel State Data device command
  owb_s = owb_write_bytes(ds, dev_cmd, 10);

  if (owb_s != OWB_STATUS_OK) {
    dev->stopRead();
    ESP_LOGW(ds2408TAG, "failed to send read cmd owb_s=%d", owb_s);
    return rc;
  }

  // read 32 bytes of channel state data + 16 bits of CRC
  // into the dev_cmd
  owb_s = owb_read_bytes(ds, (dev_cmd + 10), 34);
  dev->stopRead();

  ESP_LOGD(ds2408TAG, "dev_cmd after read start of buffer dump");
  ESP_LOG_BUFFER_HEX_LEVEL(ds2408TAG, dev_cmd, sizeof(dev_cmd), ESP_LOG_DEBUG);
  ESP_LOGD(ds2408TAG, "dev_cmd after read end of buffer dump");

  if (owb_s != OWB_STATUS_OK) {

    ESP_LOGW(ds2408TAG, "failed to read cmd results owb_s=%d", owb_s);
    return rc;
  }

  owb_s = owb_reset(ds, &present);

  // compute the crc16 over the Channel Access command through channel state
  // data (excluding the crc16 bytes)
  uint16_t crc16 =
      check_crc16((dev_cmd + 9), 33, &(dev_cmd[sizeof(dev_cmd) - 2]));

  if (!crc16) {
    ESP_LOGW(ds2408TAG, "crc FAILED (0x%02x) for %s", crc16,
             dev->debug().c_str());
    return rc;
  }

  // negate positions since device sees on/off opposite of true/false
  // uint32_t positions = (~buff[sizeof(buff) - 3]) & 0xFF; // constrain to
  // 8bits
  uint32_t positions =
      ~(dev_cmd[sizeof(dev_cmd) - 3]) & 0xFF; // constrain to 8bits

  if (reading != nullptr) {
    *reading =
        new positionsReading(dev->id(), time(nullptr), positions, (uint32_t)8);
  }
  rc = true;

  return rc;
}

void mcrDS::run(void *data) {
  owb_rmt_driver_info *rmt_driver = new owb_rmt_driver_info;
  ds = owb_rmt_initialize(rmt_driver, W1_PIN, RMT_CHANNEL_0, RMT_CHANNEL_1);

  _bus_mutex = xSemaphoreCreateMutex();
  _cmd_q = xQueueCreate(_max_queue_len, sizeof(mcrCmd_t *));
  _ds_evg = xEventGroupCreate();

  // the command task will wait for the queue which is fed by MQTTin
  xTaskCreate(&runCommand, "mcrDScmd", (3 * 1024), this, _task_pri.cmd,
              &(_tasks.cmd));

  // the convert task will wait for the devices available bit
  xTaskCreate(&runConvert, "mcrDScon", (3 * 1024), this, _task_pri.convert,
              &(_tasks.convert));

  // the discover task will immediate start, no reason to wait
  xTaskCreate(&runDiscover, "mcrDSdis", (3 * 1024), this, _task_pri.discover,
              &(_tasks.discover));

  // the report task will wait for the temperature available bit
  // FIXME: this should be smarter and discern the difference between
  //        temperature devices and switch devices
  //        ** until this is done there will never be a report if temperature
  //        devices are not on the bus **
  xTaskCreate(&runReport, "mcrDSrep", (4 * 1024), this, _task_pri.report,
              &(_tasks.report));

  owb_use_crc(ds, true);

  ESP_LOGI(mTAG,
           "created ow_rmt=%p bus_mutex=%p cmd_q=%p ds_evg=%p cmd_task=%p "
           "convert_task=%p discover_task=%p report_task=%p",
           ds, (void *)_bus_mutex, (void *)_cmd_q, (void *)_ds_evg,
           (void *)_tasks.cmd, (void *)_tasks.convert, (void *)_tasks.discover,
           (void *)_tasks.report);

  cmdQueue_t cmd_q = {"mcrDS", "ds", _cmd_q};
  _mqtt->registerCmdQueue(cmd_q);

  ESP_LOGI(mTAG, "waiting on event_group=%p for bits=0x%x", (void *)_ev_group,
           _wait_bit);
  xEventGroupWaitBits(_ev_group, _wait_bit, false, true, portMAX_DELAY);
  ESP_LOGI(mTAG, "event_group wait complete, proceeding to task loop");

  _last_wake.engine = xTaskGetTickCount();

  // adjust the engine task priority as we enter into the main run loop
  vTaskPrioritySet(nullptr, _task_pri.engine);

  for (;;) {
    // signal to other tasks the dsEngine task is in it's run loop
    // this ensures all other set-up activities are complete before
    xEventGroupSetBits(_ds_evg, _event_bits.engine_running);

    // do stuff here

    vTaskDelayUntil(&(_last_wake.engine), _loop_frequency);
    runtimeMetricsReport(mTAG);
  }
}

void mcrDS::runCommand(void *task_data) {
  mcrDS *instance = (mcrDS *)task_data;
  instance->command(instance->_handle_cmd_task_data);
  ::vTaskDelete(instance->_tasks.cmd);
}

void mcrDS::runConvert(void *task_data) {
  mcrDS *instance = (mcrDS *)task_data;
  instance->convert(instance->_task_data.convert);
  ::vTaskDelete(instance->_tasks.convert);
}

void mcrDS::runDiscover(void *task_data) {
  mcrDS *instance = (mcrDS *)task_data;
  instance->discover(instance->_task_data.discover);
  ::vTaskDelete(instance->_tasks.discover);
}

void mcrDS::runReport(void *task_data) {
  mcrDS *instance = (mcrDS *)task_data;
  instance->report(instance->_task_data.report);
  ::vTaskDelete(instance->_tasks.report);
}

bool mcrDS::setDS2406(mcrCmd_t &cmd, dsDev_t *dev) {
  bool present = false;
  owb_status owb_s;
  bool rc = false;

  owb_s = owb_reset(ds, &present);

  if (owb_s != OWB_STATUS_OK) {
    ESP_LOGW(setds2406TAG, "no devices present");
    return rc;
  }

  positionsReading_t *reading = (positionsReading_t *)dev->reading();
  uint32_t mask = cmd.mask().to_ulong();
  uint32_t tobe_state = cmd.state().to_ulong();
  uint32_t asis_state = reading->state();

  bool pio_a = (mask & 0x01) ? (tobe_state & 0x01) : (asis_state & 0x01);
  bool pio_b = (mask & 0x02) ? (tobe_state & 0x02) : (asis_state & 0x02);

  uint32_t new_state = (!pio_a << 5) | (!pio_b << 6) | 0xf;

  uint8_t dev_cmd[] = {
      0x55,                                           // byte 0: match rom_code
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // byte 1-8: rom
      0x55,                                           // byte 9: write status
      0x07, 0x00, // byte:10-11: address of status byte
      0x00,       // byte 12: status byte to send (populated below)
      0x00, 0x00  // byte 13-14: crc16
  };

  size_t dev_cmd_size = sizeof(dev_cmd);
  int crc16_idx = dev_cmd_size - 2;
  dev_cmd[12] = new_state;

  dev->startWrite();
  dev->copyAddrToCmd(dev_cmd);

  // send the device the command excluding the crc16 bytes
  owb_s = owb_write_bytes(ds, dev_cmd, dev_cmd_size - 2);

  if (owb_s != OWB_STATUS_OK) {
    dev->stopWrite();
    ESP_LOGW(setds2406TAG, "failed to send read cmd owb_s=%d", owb_s);
    return rc;
  }

  // device sends back the crc16 of the transmittd data (all bytes)
  // so, read just the two crc16 bytes into the dev_cmd
  owb_s = owb_read_bytes(ds, (dev_cmd + crc16_idx), 2);

  if (owb_s != OWB_STATUS_OK) {
    dev->stopWrite();
    ESP_LOGW(setds2406TAG, "failed to read cmd results owb_s=%d", owb_s);
    return rc;
  }

  dev->stopWrite();

  bool crc_good = check_crc16((dev_cmd + 9), 4, &dev_cmd[crc16_idx]);

  if (crc_good) {
    owb_s =
        owb_write_byte(ds, 0xff); // writing 0xFF will copy scratchpad to status

    if (owb_s != OWB_STATUS_OK) {
      ESP_LOGW(setds2406TAG, "failed to copy scratchpad to status owb_s=%d",
               owb_s);
      return rc;
    }

    owb_s = owb_reset(ds, &present);
    rc = true;
  } else {
    ESP_LOGW(setds2406TAG, "crc16 failure");
  }

  return rc;
}

bool mcrDS::setDS2408(mcrCmd_t &cmd, dsDev_t *dev) {
  bool present = false;
  owb_status owb_s;
  bool rc = false;

  owb_s = owb_reset(ds, &present);

  if (owb_s != OWB_STATUS_OK) {
    ESP_LOGW(setds2408TAG, "no devices present");
    return rc;
  }

  // read the device to ensure we have the current state
  // important because setting the new state relies, in part, on the existing
  // state for the pios not changing
  if (readDevice(dev) == false) {
    ESP_LOGW(setds2408TAG, "read before set failed for %s",
             dev->debug().c_str());
    return rc;
  }

  positionsReading_t *reading = (positionsReading_t *)dev->reading();

  uint32_t mask = cmd.mask().to_ulong();
  uint32_t changes = cmd.state().to_ulong();
  uint32_t asis_state = reading->state();
  uint32_t new_state = 0x00;
  // uint32_t report_state = 0x00;

  // use XOR tricks to apply the state changes to the as_is state using the
  // mask computed
  new_state = asis_state ^ ((asis_state ^ changes) & mask);

  // now negate the new_state since the device actually represents
  // on = 0
  // off = 1

  // report_state = new_state;
  new_state = (~new_state) & 0xFF; // constrain to 8-bits

  dev->startWrite();
  owb_s = owb_reset(ds, &present);

  if (owb_s != OWB_STATUS_OK) {
    ESP_LOGW(setds2408TAG, "no devices present");
    return rc;
  }

  uint8_t dev_cmd[] = {0x55, // byte 0: match rom_code
                       0x00, // byte 1-8: rom
                       0x00,
                       0x00,
                       0x00,
                       0x00,
                       0x00,
                       0x00,
                       0x00,
                       0x5a,                 // byte 9: actual device cmd
                       (uint8_t)new_state,   // byte10 : new state
                       (uint8_t)~new_state}; // byte11: inverted state

  dev->startWrite();
  dev->copyAddrToCmd(dev_cmd);
  owb_s = owb_write_bytes(ds, dev_cmd, sizeof(dev_cmd));

  if (owb_s != OWB_STATUS_OK) {
    ESP_LOGW(setds2408TAG, "device cmd failed for %s owb_s=%d",
             dev->debug().c_str(), owb_s);
    dev->stopWrite();
    return rc;
  }

  uint8_t check[2] = {0x00};
  owb_s = owb_read_bytes(ds, check, sizeof(check));

  if (owb_s != OWB_STATUS_OK) {
    ESP_LOGW(setds2408TAG, "read of check bytes failed for %s owb_s=%d",
             dev->debug().c_str(), owb_s);
    dev->stopWrite();
    return rc;
  }

  owb_s = owb_reset(ds, &present);
  dev->stopWrite();

  // check what the device returned to determine success or failure
  // byte 0 = 0xAA is a success, byte 1 = new_state
  // this might be a bit of a hack however let's accept success if either
  // the check byte is 0xAA *OR* the reported dev_state == new_state
  // this handles the occasional situation where there is a single dropped
  // bit in either (but hopefully not both)
  uint32_t dev_state = check[1];
  if ((check[0] == 0xaa) || (dev_state == (new_state & 0xff))) {
    cmd_bitset_t b0 = check[0];
    cmd_bitset_t b1 = check[1];
    ESP_LOGI(setds2408TAG, "check[0]=0b%s check[1]=0b%s CONFIRMED for %s",
             b0.to_string().c_str(), b1.to_string().c_str(),
             dev->debug().c_str());
    rc = true;
  } else {
    ESP_LOGW(setds2408TAG, "check FAILED for %s check[0]=0x%x check[1]=0x%x",
             dev->debug().c_str(), check[0], check[1]);
  }

  return rc;
}

dsDev_t *mcrDS::getDeviceByCmd(mcrCmd_t *cmd) {
  mcrDev_t *dev = mcrEngine::getDevice(cmd->dev_id());
  return (dsDev_t *)dev;
}

dsDev_t *mcrDS::getDeviceByCmd(mcrCmd_t &cmd) {
  mcrDev_t *dev = mcrEngine::getDevice(cmd.dev_id());
  return (dsDev_t *)dev;
}

void mcrDS::setCmdAck(mcrCmd_t &cmd) {
  mcrDevID_t &dev_id = cmd.dev_id();
  dsDev_t *dev = nullptr;

  dev = (dsDev_t *)mcrEngine::getDevice(dev_id);
  if (dev != nullptr) {
    dev->setReadingCmdAck(cmd.latency(), cmd.refID());
  }
}

bool mcrDS::check_crc16(const uint8_t *input, uint16_t len,
                        const uint8_t *inverted_crc, uint16_t crc) {
  crc = ~crc16(input, len, crc);
  return (crc & 0xFF) == inverted_crc[0] && (crc >> 8) == inverted_crc[1];
}

uint16_t mcrDS::crc16(const uint8_t *input, uint16_t len, uint16_t crc) {
  static const uint8_t oddparity[16] = {0, 1, 1, 0, 1, 0, 0, 1,
                                        1, 0, 0, 1, 0, 1, 1, 0};

  for (uint16_t i = 0; i < len; i++) {
    // Even though we're just copying a byte from the input,
    // we'll be doing 16-bit computation with it.
    uint16_t cdata = input[i];
    cdata = (cdata ^ crc) & 0xff;
    crc >>= 8;

    if (oddparity[cdata & 0x0F] ^ oddparity[cdata >> 4])
      crc ^= 0xC001;

    cdata <<= 6;
    crc ^= cdata;
    cdata <<= 1;
    crc ^= cdata;
  }

  return crc;
}

void mcrDS::printInvalidDev(dsDev *dev) {
  if (dev == nullptr) {
    ESP_LOGW(mTAG, "%s dev == nullptr", __PRETTY_FUNCTION__);
    return;
  }

  ESP_LOGW(mTAG, "%s dev id=%s", __PRETTY_FUNCTION__, (const char *)dev->id());
}
