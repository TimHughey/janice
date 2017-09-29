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

#include "dev_addr.hpp"
#include "dev_id.hpp"
#include "readings.hpp"

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

  mcrDev(mcrDevAddr_t &addr);
  mcrDev(mcrDevID_t &id, mcrDevAddr_t &addr);
  virtual ~mcrDev(); // base class will handle deleteing the reading, if needed

  // operators
  // mcrDev_t &operator=(mcrDev_t &dev);
  bool operator==(mcrDevID_t &rhs); // rely on the == operator from mcrDevID_t
  // bool operator==(mcrDev_t *rhs);

  // updaters
  void justSeen();
  void setID(char *id);
  void setReading(Reading_t *reading);
  void setDesc(const char *desc);

  uint8_t firstAddressByte();
  mcrDevAddr_t &addr();
  mcrDevID_t &id();
  const char *desc();
  Reading_t *reading();
  static const uint8_t idMaxLen();
  bool isValid();
  bool isNotValid();

  // metrics functions
  void startRead();
  time_t stopRead();
  time_t readMS();
  time_t readTimestamp();

  void startWrite();
  time_t stopWrite();
  time_t writeMS();

  virtual void debug(bool newline = false);
};

#endif // __cplusplus
#endif // mcrDev_h
