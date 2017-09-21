/*
    mcpr_ds.h - Master Control Remote Dallas Semiconductor
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

class dsDev {
private:
  byte _rom[8] = {0x00,             // byte 0: 8-bit famly code
                  0x00, 0x00, 0x00, // byte 1-3: 48-bit serial number
                  0x00, 0x00, 0x00, // byte 4-6: 48-bit serial number
                  0x00};            // byte 7: 8-bit crc
  boolean _power = false;
  Reading *_reading = NULL;
  //                 00000000001111111
  //       byte num: 01234567890123456
  // format of name: ds/01020304050607
  //      total len: 18 bytes (id + string terminator)
  char _id[18] = {0x00};

public:
  dsDev() {
    memset(_rom, 0x00, 8);
    _power = false;
    _reading = NULL;
    strcpy(_id, "ds/unknown");
  };

  dsDev(byte *rom, boolean power, Reading *reading = NULL) {
    memcpy(this->_rom, rom, 8);
    _power = power;
    _reading = reading;

    memset(_id, 0x00, sizeof(_id));
    sprintf(_id, "ds/%02x%02x%02x%02x%02x%02x%02x",
            _rom[0],                    // byte 0: family code
            _rom[1], _rom[2], _rom[3],  // byte 1-3: serial number
            _rom[4], _rom[5], _rom[6]); // byte 4-6: serial number
  };

  // do not allow copy constructor
  dsDev(const dsDev &);

  // destructor necessary because of possibly embedded reading
  ~dsDev() {
    if (_reading != NULL)
      delete _reading;
  };

  // updaters
  void setReading(Reading *reading) {
    if (_reading != NULL)
      delete _reading;
    _reading = reading;
  };

  // operators
  inline bool operator==(const dsDev &rhs) {
    return (memcmp(_rom, rhs._rom, 8) == 0) ? true : false;
  };

  byte family() { return _rom[0]; };
  byte *addr() { return _rom; };
  byte crc() { return _rom[7]; };
  char *id() { return _id; };
  boolean isPowered() { return _power; };
  boolean isValid() { return _rom[0] != 0x00 ? true : false; };

  static byte *parseId(char *name) {
    static byte _addr[7] = {0x00};

    //                 00000000001111111
    //       byte num: 01234567890123456
    // format of name: ds/01020304050607
    //      total len: 18 bytes (id + string terminator)
    if ((name[0] == 'd') && (name[1] == 's') && (name[2] == '/') &&
        (name[17] == 0x00)) {
      for (uint8_t i = 3, j = 0; i < 17; i = i + 2, j++) {
        char digit[3] = {name[i], name[i + 1], 0x00};
        _addr[j] = (byte)(atoi(digit) & 0xFF);
      }
    }

    return _addr;
  };

  static bool validAddress(byte *addr) {
    return (addr[0] != 0x00) ? true : false;
  }
};

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
#endif // mcp_ds_h
