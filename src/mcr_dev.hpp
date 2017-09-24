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

#include "reading.hpp"

class mcrDevID {
private:
  static const uint8_t _max_len = 30;
  char _id[_max_len];

public:
  mcrDevID() { memset(_id, 0x00, _max_len); };
  mcrDevID(char *id) { this->initAndCopy(id); };

  static const uint8_t max_len() { return _max_len; };

  // allow a mcrDevID to be assigned to a regular char *
  operator char *() { return _id; };

  // the == operator replicates the return vales from a standard strcmp
  bool operator==(char *rhs) { return (strncmp(_id, rhs, _max_len)); };
  mcrDevID &operator=(char *id) {
    this->initAndCopy(id);
    return *this;
  };

private:
  void initAndCopy(char *id) {
    _id[0] = 0x00;
    strncat(_id, id, _max_len - 1);
  }
};

typedef class mcrDevID mcrDevID_t;

class mcrDev {
protected:
  static const uint8_t _addr_len = 8;  // max length of address
  static const uint8_t _id_len = 30;   // max length of the id
  static const uint8_t _desc_len = 15; // max length of desciption

  uint8_t _addr[_addr_len] = {0x00}; // address of the device
  Reading *_reading = NULL;

  char _id[_id_len] = {0x00}; // unique identifier of this device
  char _desc[_desc_len];      // desciption of the device

  elapsedMillis _read_elapsed;
  time_t _read_ms = 0;

  elapsedMillis _write_elapsed;
  time_t _write_ms = 0;

  time_t _read_timestamp = 0;

public:
  mcrDev() {
    memset(_addr, 0x00, _addr_len);
    memset(_id, 0x00, _id_len);
    strcpy(_id, "new/00000000000000");
  }

  mcrDev(Reading *reading) { _reading = reading; };
  mcrDev(const mcrDev &);

  // base class will handle deleteing the reading, if needed
  ~mcrDev() {
    if (_reading != NULL)
      delete _reading;
  }

  // operators
  // although the == operator uses strcmp to check for equality the
  // value returns is boolean
  inline int operator==(const mcrDev &rhs) {
    if (strcmp(_id, rhs._id) == 0)
      return true;

    return false;
  };

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

  uint8_t firstAddressByte() { return _addr[0]; };
  uint8_t *addr() { return _addr; };
  const char *id() { return _id; };
  const char *desc() { return _desc; };
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

typedef class mcrDev mcrDev_t;

#endif // __cplusplus
#endif // mcrDev_h
