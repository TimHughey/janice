/*
     mcrDev.cpp - Master Control Common Device for Engines
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

#include <cstdlib>
#include <cstring>
#include <ios>
#include <string>
#include <tuple>

#include <FreeRTOS.h>
#include <System.h>
#include <esp_log.h>
#include <esp_timer.h>
#include <sys/time.h>
#include <time.h>

#include "addr.hpp"
#include "base.hpp"
#include "id.hpp"
#include "readings.hpp"
#include "util.hpp"

// construct a new mcrDev with only an address
mcrDev::mcrDev(mcrDevAddr_t &addr) { _addr = addr; }

mcrDev::mcrDev(mcrDevID_t &id, mcrDevAddr_t &addr) {
  _id = id; // copy id and addr objects
  _addr = addr;
}

// base class will handle deleteing the reading, if needed
mcrDev::~mcrDev() {
  if (_reading)
    delete _reading;
}

// operators
// mcrDev_t &mcrDev::operator=(mcrDev_t &dev) {
//  memcpy(this, dev, sizeof(mcrDev_t));
//  return *this;
//}
// rely on the == operator from mcrDevID_t
bool mcrDev::operator==(mcrDevID_t &rhs) {
  return std::tie(_id, _addr) == std::tie(_id, _addr);
};
// bool mcrDev::operator==(mcrDev_t *rhs) { return (_id == rhs->_id); }

void mcrDev::justSeen() { _last_seen = time(nullptr); }

// void mcrDev::setID(char *id) { _id = id; }
void mcrDev::setID(mcrDevID_t &new_id) { _id = new_id; }

// updaters
void mcrDev::setReading(Reading_t *reading) {
  if (_reading != nullptr) {
    delete _reading;
    _reading = nullptr;
  }

  _reading = reading;
};

void mcrDev::setDesc(const char *desc) {
  _desc[0] = 0x00;
  strncat(_desc, desc, _desc_len);
}

uint8_t mcrDev::firstAddressByte() { return _addr.firstAddressByte(); };
mcrDevAddr_t &mcrDev::addr() { return _addr; }
uint8_t *mcrDev::addrBytes() { return (uint8_t *)_addr; }
mcrDevID_t &mcrDev::id() { return _id; };
const char *mcrDev::desc() { return _desc; };
Reading_t *mcrDev::reading() { return _reading; }
uint32_t mcrDev::idMaxLen() { return _id_len; };
bool mcrDev::isValid() { return firstAddressByte() != 0x00 ? true : false; };
bool mcrDev::isNotValid() { return !isValid(); }

// metrics functions
void mcrDev::startRead() { _read_start_us = esp_timer_get_time(); }
time_t mcrDev::stopRead() {
  _read_us = esp_timer_get_time() - _read_start_us;
  _read_timestamp = time(nullptr);

  return _read_us;
}
int64_t mcrDev::readUS() { return _read_us; }
time_t mcrDev::readTimestamp() { return _read_timestamp; }
time_t mcrDev::timeCreated() { return _created_mtime; }
time_t mcrDev::secondsSinceLastSeen() { return (time(nullptr) - _last_seen); }

void mcrDev::startWrite() { _write_start_us = esp_timer_get_time(); }
time_t mcrDev::stopWrite() {
  _write_us = _write_start_us;
  _write_us = 0;

  return _write_us;
}
int64_t mcrDev::writeUS() { return _write_us; }

const std::string mcrDev::debug() {
  std::ostringstream debug_str;

  debug_str << "mcrDev(" << _addr.debug() << " id=" << (char *)id()
            << " desc=" << (char *)desc() << " rus=" << readUS()
            << " wus=" << writeUS() << " reading=" << (void *)_reading << ")";

  return debug_str.str();
}

const std::string mcrDev::to_string(mcrDev_t const &) { return debug(); }

// void mcrDev::debug(char *buff, size_t len) {
//   strncat(buff, debug().c_str(), len);
// }
