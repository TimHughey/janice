/*
    commonDev.h - Master Control Common Device for Engines
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

#ifndef common_dev_h
#define common_dev_h

#ifdef __cplusplus

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include "reading.hpp"

class commonDev {
protected:
  static const uint8_t _max_addr_len = 8;  // max length of address
  static const uint8_t _max_id_len = 30;   // max length of the id
  static const uint8_t _max_desc_len = 15; // max length of desciption

  uint8_t _addr[_max_addr_len] = {0x00}; // address of the device
  Reading *_reading = NULL;

  char _id[_max_id_len] = {0x00}; // unique identifier of this device
  char _desc[_max_desc_len];      // desciption of the device

public:
  commonDev() {
    memset(_addr, 0x00, _max_addr_len);
    memset(_id, 0x00, _max_id_len);
    strcpy(_id, "new/00000000000000");
  }

  commonDev(Reading *reading) { _reading = reading; };
  commonDev(const commonDev &);

  // base class will handle deleteing the reading, if needed
  ~commonDev() {
    if (_reading != NULL)
      delete _reading;
  }

  // updaters
  void setReading(Reading *reading) {
    if (_reading != NULL)
      delete _reading;
    _reading = reading;
  };

  void setDesc(const char *desc) {
    memset(_desc, 0x00, _max_desc_len);
    strcpy(_desc, desc);
  }

  // operators
  inline int operator==(const commonDev &rhs) { return strcmp(_id, rhs._id); };

  uint8_t firstAddressByte() { return _addr[0]; };
  uint8_t *addr() { return _addr; };
  const char *id() { return _id; };
  const char *desc() { return _desc; };
  static const uint8_t idMaxLen() { return _max_id_len; };
  boolean isValid() { return firstAddressByte() != 0x00 ? true : false; };
};

#endif // __cplusplus
#endif // common_dev_h
