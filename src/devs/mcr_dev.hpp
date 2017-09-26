/*
    mcrDev.h - Master Control Common Device for Engines
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

#ifndef mcrDev_h
#define mcrDev_h

#ifdef __cplusplus
#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include "../readings/reading.hpp"
#include "dev_addr.hpp"
#include "dev_id.hpp"

typedef class mcrDev mcrDev_t;
class mcrDev {
private:
  mcrDevID_t _id;     // unique identifier of this device
  mcrDevAddr_t _addr; // address of this device

protected:
  static const uint8_t _addr_len = mcrDevAddr::max_addr_len;
  static const uint8_t _id_len = mcrDevID::max_id_len;
  static const uint8_t _desc_len = 15; // max length of desciption

  char _desc[_desc_len] = {0x00}; // desciption of the device
  Reading_t *_reading = NULL;

  time_t _last_seen = 0; // mtime of last time this device was discovered

  elapsedMillis _read_elapsed;
  time_t _read_ms = 0;

  elapsedMillis _write_elapsed;
  time_t _write_ms = 0;

  time_t _read_timestamp = 0;

  bool debugMode = false;
  bool infoMode = false;
  bool warningMode = false;

public:
  mcrDev() {} // all values are defaulted in definition of class(es)

  mcrDev(mcrDevAddr_t &addr) { // construct a new mcrDev with only an address
    _addr = addr;
  }

  mcrDev(mcrDevID_t &id, mcrDevAddr_t &addr) {
    _id = id; // copy id and addr objects
    _addr = addr;
  }

  // base class will handle deleteing the reading, if needed
  ~mcrDev() {
    if (_reading != NULL)
      delete _reading;
  }

  // operators
  mcrDev_t &operator=(mcrDev_t &dev) {
    memcpy(this, &dev, sizeof(mcrDev_t));
    return *this;
  }
  // rely on the == operator from mcrDevID_t
  inline bool operator==(mcrDev_t &rhs) { return (_id == rhs._id); };
  inline bool operator==(mcrDev_t *rhs) { return (_id == rhs->_id); }

  void justSeen() { _last_seen = now(); }

  void setID(char *id) { _id = id; }

  // updaters
  void setReading(Reading *reading) {
    if (_reading != NULL)
      delete _reading;
    _reading = reading;
  };

  void setDesc(const char *desc) {
    _desc[0] = 0x00;
    strncat(_desc, desc, _desc_len - 1);
  }

  uint8_t firstAddressByte() { return _addr.firstAddressByte(); };
  mcrDevAddr_t &addr() { return _addr; }
  // uint8_t *addr() { return _addr; };
  mcrDevID_t &id() { return _id; };
  const char *desc() { return _desc; };
  Reading_t *reading() { return _reading; }
  static const uint8_t idMaxLen() { return _id_len; };
  bool isValid() { return firstAddressByte() != 0x00 ? true : false; };
  bool isNotValid() { return !isValid(); }

  // metrics functions
  void startRead() { _read_elapsed = 0; }
  time_t stopRead() {
    _read_ms = _read_elapsed;
    _read_elapsed = 0;
    _read_timestamp = now();

    return _read_ms;
  }
  time_t readMS() { return _read_ms; }
  time_t readTimestamp() { return _read_timestamp; }

  void startWrite() { _write_elapsed = 0; }
  time_t stopWrite() {
    _write_ms = _write_elapsed;
    _write_elapsed = 0;

    return _write_ms;
  }
  time_t writeMS() { return _write_ms; }
};

#endif // __cplusplus
#endif // mcrDev_h
