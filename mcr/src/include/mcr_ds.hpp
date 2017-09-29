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

#include "ds_dev.hpp"
#include "mcr_cmd.hpp"
#include "mcr_engine.hpp"
#include "mcr_mqtt.hpp"
#include "readings.hpp"

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

  // dsDev_t *dsDevGetDevice(mcrDevID_t &id);
  dsDev_t *getDeviceByCmd(mcrCmd_t &cmd);
  void setCmdAck(mcrCmd_t &cmd);

  bool discover();
  bool convert();
  bool report();
  bool handleCmd();
  bool handleCmdAck(mcrCmd_t &cmd);

  bool isCmdQueueEmpty();
  bool pendingCmd();

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

  bool setSwitch(mcrCmd &cmd);
  bool setDS2406(mcrCmd &cmd);
  bool setDS2408(mcrCmd &cmd);

  void printInvalidDev(dsDev *dev);

  // static method for accepting cmds
  static bool cmdCallback(JsonObject &root);
};

#endif // __cplusplus
#endif // mcr_ds_h
