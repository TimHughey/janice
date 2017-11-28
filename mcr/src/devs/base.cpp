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

#ifdef __cplusplus
#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include "../include/readings.hpp"
#include "../misc/util.hpp"
#include "addr.hpp"
#include "base.hpp"
#include "id.hpp"

mcrDev::mcrDev(
    mcrDevAddr_t &addr) { // construct a new mcrDev with only an address
  _addr = addr;
}

mcrDev::mcrDev(mcrDevID_t &id, mcrDevAddr_t &addr) {
  _id = id; // copy id and addr objects
  _addr = addr;
}

// base class will handle deleteing the reading, if needed
mcrDev::~mcrDev() {
  if (_reading != nullptr)
    delete _reading;
}

// operators
// mcrDev_t &mcrDev::operator=(mcrDev_t &dev) {
//  memcpy(this, dev, sizeof(mcrDev_t));
//  return *this;
//}
// rely on the == operator from mcrDevID_t
bool mcrDev::operator==(mcrDevID_t &rhs) { return (_id == rhs); };
// bool mcrDev::operator==(mcrDev_t *rhs) { return (_id == rhs->_id); }

void mcrDev::justSeen() { _last_seen = now(); }

void mcrDev::setID(char *id) { _id = id; }

// updaters
void mcrDev::setReading(Reading_t *reading) {
  if (_reading != nullptr) {
    delete _reading;
  }

  _reading = reading;
};

void mcrDev::setDesc(const char *desc) {
  _desc[0] = 0x00;
  strncat(_desc, desc, _desc_len - 1);
}

uint8_t mcrDev::firstAddressByte() { return _addr.firstAddressByte(); };
mcrDevAddr_t &mcrDev::addr() { return _addr; }
// uint8_t *addr() { return _addr; };
mcrDevID_t &mcrDev::id() { return _id; };
const char *mcrDev::desc() { return _desc; };
Reading_t *mcrDev::reading() { return _reading; }
const uint8_t mcrDev::idMaxLen() { return _id_len; };
bool mcrDev::isValid() { return firstAddressByte() != 0x00 ? true : false; };
bool mcrDev::isNotValid() { return !isValid(); }

// metrics functions
void mcrDev::startRead() { _read_elapsed = 0; }
time_t mcrDev::stopRead() {
  _read_ms = _read_elapsed;
  _read_elapsed = 0;
  _read_timestamp = now();

  return _read_ms;
}
time_t mcrDev::readMS() { return _read_ms; }
time_t mcrDev::readTimestamp() { return _read_timestamp; }
time_t mcrDev::timeCreated() { return _created_mtime; }
time_t mcrDev::secondsSinceLastSeen() { return (now() - _last_seen); }

void mcrDev::startWrite() { _write_elapsed = 0; }
time_t mcrDev::stopWrite() {
  _write_ms = _write_elapsed;
  _write_elapsed = 0;

  return _write_ms;
}
time_t mcrDev::writeMS() { return _write_ms; }

void mcrDev::debug(bool newline) {
  log("mcrDev_t id: ");
  log(id());
  log(" ");
  addr().debug(newline);
}

#endif // __cplusplus
