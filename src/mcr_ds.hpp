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
#include "mcr_engine.hpp"
#include "mcr_mqtt.hpp"

#define mcr_ds_version_1 1

// Set the version of MCP Remote
#ifndef mcr_ds_version
#define mcr_ds_version mcr_ds_version_1
#endif

#define W1_PIN 10

// TODO: implement actual types for dev address and id
// typedef struct {
//   byte b[8];
// } dsDevAddr_t;
//
// typedef struct {
//   char n[17];
// } dsDevId_t;

class mcrDS : public mcrEngine {

private:
  OneWire *ds;
  dsDev **_devs;

public:
  mcrDS(mcrMQTT *mqtt);
  bool init();

private:
  dsDev *addDevice(byte *addr, boolean pwr) {
    dsDev *dev = NULL;

    if (devCount() < maxDevices()) {
      dev = new dsDev(addr, pwr);
      _devs[devCount()] = dev;
      mcrEngine::addDevice();
    } else {
      Serial.print("    ");
      Serial.print(__PRETTY_FUNCTION__);
      Serial.println(" attempt to exceed maximum devices");
    }

    return dev;
  };

  void clearKnownDevices() {
    for (uint8_t i = 0; i < devCount(); i++) {
      if (_devs[i] != NULL) {
        delete _devs[i];
        _devs[i] = NULL;
      }
    }

    mcrEngine::clearKnownDevices();
  };

  boolean discover();
  boolean convert();
  boolean deviceReport();

  // specific methods to read devices
  boolean readDS1820(dsDev *dev, Reading **reading);
  boolean readDS2408(dsDev *dev, Reading **reading);
  boolean readDS2406(dsDev *dev, Reading **reading);

  // static method for accepting cmds
  static bool cmdCallback(JsonObject &root);
};

#endif // __cplusplus
#endif // mcr_ds_h
