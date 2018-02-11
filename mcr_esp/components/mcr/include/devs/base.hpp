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

#include <cstdlib>
#include <ios>
#include <sstream>
#include <string>
#include <tuple>

#include <freertos/FreeRTOS.h>
#include <sys/time.h>
#include <time.h>

#include "devs/addr.hpp"
#include "devs/id.hpp"
#include "misc/util.hpp"
#include "readings/readings.hpp"

typedef class mcrDev mcrDev_t;
class mcrDev {
public:
  mcrDev() {} // all values are defaulted in definition of class(es)

  mcrDev(mcrDevAddr_t &addr);
  mcrDev(const mcrDevID_t &id, mcrDevAddr_t &addr);
  // mcrDev(const mcrDev_t &dev); // copy constructor
  virtual ~mcrDev(); // base class will handle deleting the reading, if needed

  // operators
  // mcrDev_t &operator=(mcrDev_t &dev);
  // bool operator==(mcrDevID_t &rhs) const;
  bool operator==(mcrDev_t *rhs) const; // based entirely on mcrDevID

  static uint32_t idMaxLen();
  bool isValid();
  bool isNotValid();

  // updaters
  void justSeen();

  uint8_t firstAddressByte();
  uint8_t lastAddressByte();
  mcrDevAddr_t &addr();
  uint8_t *addrBytes();

  void setID(const mcrDevID_t &new_id);
  const mcrDevID_t &id() const { return _id; };

  // description of device
  void setDescription(const std::string &desc) { _desc = desc; };
  void setDescription(const char *desc) { _desc = desc; };
  const std::string &description() const { return _desc; };

  void setReading(Reading_t *reading);
  Reading_t *reading();

  // metrics functions
  void startRead();
  void startWrite();

  time_t stopRead();
  time_t stopWrite();
  int64_t readUS();
  int64_t writeUS();
  time_t readTimestamp();
  time_t timeCreated();
  time_t secondsSinceLastSeen();

  void crcMismatch();
  void readFailure();
  void writeFailure();

  // int crcMismatchCount();
  // int readErrorCount();
  // int writeErrorCount();

  virtual const std::string debug();
  virtual const std::string to_string(mcrDev_t const &);
  // virtual void debug(char *buff, size_t len);

private:
  mcrDevID_t _id;     // unique identifier of this device
  mcrDevAddr_t _addr; // address of this device
  std::string _desc;

protected:
  static const uint32_t _addr_len = mcrDevAddr::max_addr_len;
  static const uint32_t _id_len = 30;
  static const uint32_t _desc_len = 15; // max length of desciption

  // char _desc[_desc_len + 1] = {0x00}; // desciption of the device
  Reading_t *_reading = nullptr;

  time_t _created_mtime = time(nullptr);
  time_t _last_seen = 0; // mtime of last time this device was discovered

  int64_t _read_start_us;
  int64_t _read_us = 0;

  int64_t _write_start_us;
  int64_t _write_us = 0;

  time_t _read_timestamp = 0;

  int _crc_mismatches = 0;
  int _read_errors = 0;
  int _write_errors = 0;
};

#endif // mcrDev_h
