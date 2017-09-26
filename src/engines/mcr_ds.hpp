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

#ifndef mcr_ds_h
#define mcr_ds_h

#ifdef __cplusplus

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include <ArduinoJson.h>
#include <OneWire.h>
#include <TimeLib.h>
#include <elapsedMillis.h>

#include "../devs/ds_dev.hpp"
#include "../protocols/mcr_mqtt.hpp"
#include "../types/mcr_cmd.hpp"
#include "mcr_engine.hpp"

#define mcr_ds_version_1 1

// Set the version of MCP Remote
#ifndef mcr_ds_version
#define mcr_ds_version mcr_ds_version_1
#endif

#define W1_PIN 10

typedef class mcrDS mcrDS_t;
class mcrDS : public mcrEngine {

public:
  mcrDS(mcrMQTT *mqtt);
  bool init();

private:
  OneWire *ds;

  dsDev_t *getDevice(mcrDevID_t &id) {
    mcrDev_t *dev = mcrEngine::getDevice(id);
    return (dsDev_t *)dev;
  }

  dsDev_t *getDevice(mcrCmd_t &cmd) {
    if (debugMode) {
      logDateTime(__PRETTY_FUNCTION__);
      log("looking for dev_id=");
      log(cmd.dev_id(), true);
    }

    mcrDev_t *dev = mcrEngine::getDevice(cmd.dev_id());
    return (dsDev_t *)dev;
  }

  void setCmdAck(mcrCmd_t &cmd) {
    mcrDevID_t &dev_id = cmd.dev_id();
    dsDev_t *dev = nullptr;

    dev = (dsDev_t *)mcrEngine::getDevice(dev_id);
    if (dev != nullptr) {
      dev->setReadingCmdAck(cmd.latency(), cmd.cid());
    }
  }

  bool discover();
  bool convert();
  bool report();
  bool handleCmd();
  bool handleCmdAck(mcrCmd_t &cmd);

  bool isCmdQueueEmpty();
  bool pendingCmd();

  // accept a mcrCmd_t as input to reportDevice
  bool readDevice(mcrCmd_t &cmd) {
    mcrDevID_t &dev_id = cmd.dev_id();

    return readDevice(dev_id);
  }
  bool readDevice(mcrDevID_t &id) { return readDevice(getDevice(id)); }
  bool readDevice(dsDev_t *dev);

  // publish a device
  bool publishDevice(mcrCmd_t &cmd) {
    mcrDevID_t &dev_id = cmd.dev_id();

    return publishDevice(dev_id);
  }

  bool publishDevice(mcrDevID_t &id) { return publishDevice(getDevice(id)); }
  bool publishDevice(dsDev_t *dev);

  // specific methods to read devices
  bool readDS1820(dsDev *dev, Reading **reading);
  bool readDS2408(dsDev *dev, Reading **reading = nullptr);
  bool readDS2406(dsDev *dev, Reading **reading);

  bool setSwitch(mcrCmd &cmd);
  bool setDS2406(mcrCmd &cmd);
  bool setDS2408(mcrCmd &cmd);

  void printInvalidDev(dsDev *dev) {
    logDateTime(__PRETTY_FUNCTION__);
    log("[WARNING] device ");
    if (dev == NULL) {
      log("is NULL", true);
    } else {
      log(dev->id());
      log(" crc8 is ");
      switch (dev->isValid()) {
      case true:
        log("valid", true);
        break;
      case false:
        log("invalid", true);
      }
    }
  }

  // static method for accepting cmds
  static bool cmdCallback(JsonObject &root);
};

#endif // __cplusplus
#endif // mcr_ds_h
