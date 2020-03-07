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
#include <map>
#include <memory>
#include <string>
#include <tuple>

#include <freertos/FreeRTOS.h>
#include <sys/time.h>
#include <time.h>

#include "devs/addr.hpp"
#include "misc/elapsedMillis.hpp"
#include "misc/mcr_types.hpp"
#include "readings/readings.hpp"

using std::unique_ptr;

namespace mcr {

typedef class mcrDev mcrDev_t;
class mcrDev {
public:
  mcrDev() {} // all values are defaulted in definition of class(es)

  mcrDev(mcrDevAddr_t &addr);
  mcrDev(const std::string &id, mcrDevAddr_t &addr);
  // mcrDev(const mcrDev_t &dev); // copy constructor
  virtual ~mcrDev(); // base class will handle deleting the reading, if needed

  // operators
  bool operator==(mcrDev_t *rhs) const;

  static uint32_t idMaxLen();
  bool isValid();
  bool isNotValid();

  // updaters
  void justSeen();

  uint8_t firstAddressByte();
  uint8_t lastAddressByte();
  mcrDevAddr_t &addr();
  uint8_t *addrBytes();

  void setID(const std::string &new_id);
  void setID(char *new_id);
  const std::string &id() const { return _id; };

  // description of device
  void setDescription(const std::string &desc) { _desc = desc; };
  void setDescription(const char *desc) { _desc = desc; };
  const std::string &description() const { return _desc; };
  virtual const char *externalName() const { return _id.c_str(); };

  void setReading(Reading_t *reading);
  void setReadingCmdAck(uint32_t latency_us, mcrRefID_t &refid);
  Reading_t *reading();

  // metrics functions
  void readStart();
  uint64_t readStop();
  void writeStart();
  uint64_t writeStop();
  uint64_t readUS();
  uint64_t writeUS();
  time_t readTimestamp();
  time_t timeCreated();
  time_t secondsSinceLastSeen();

  void setMissingSeconds(uint32_t missing_secs) {
    _missing_secs = missing_secs;
  };
  bool available();
  bool missing();

  void crcMismatch();
  void readFailure();
  void writeFailure();

  int readErrors() const { return _read_errors; }
  int writeErrors() const { return _write_errors; }

  // int crcMismatchCount();
  // int readErrorCount();
  // int writeErrorCount();

  virtual const unique_ptr<char[]> debug();
  // virtual const std::string to_string(mcrDev_t const &);
  // virtual void debug(char *buff, size_t len);

private:
  std::string _id;    // unique identifier of this device
  mcrDevAddr_t _addr; // address of this device
  std::string _desc;

  typedef std::pair<std::string, uint32_t> statEntry_t;
  typedef std::map<std::string, uint32_t> statsMap_t;

protected:
  static const uint32_t _addr_len = mcrDevAddr::max_addr_len;
  static const uint32_t _id_len = 30;
  static const uint32_t _desc_len = 15; // max length of desciption

  // char _desc[_desc_len + 1] = {0x00}; // desciption of the device
  Reading_t *_reading = nullptr;

  time_t _created_mtime = time(nullptr);
  time_t _last_seen = 0; // mtime of last time this device was discovered

  elapsedMicros _read_us;
  elapsedMicros _write_us;

  time_t _read_timestamp = 0;

  int _crc_mismatches = 0;
  int _read_errors = 0;
  int _write_errors = 0;
  int _missing_secs = 15;
};
} // namespace mcr

#endif // mcrDev_h
