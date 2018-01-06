/*
    mcr_i2c.cpp - Master Control Remote I2C
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
#include "base.hpp"
#include "i2c.hpp"

const char *i2cDev::i2cDevDesc(uint8_t addr) {
  switch (addr) {
  case 0x5C:
    return (const char *)"am2315";
    break;

  case 0x44:
    return (const char *)"sht31";
    break;

  default:
    return (const char *)"unknown";
    break;
  }
}

// construct a new i2cDev with a known address and compute the id
i2cDev::i2cDev(mcrDevAddr_t &addr, bool use_multiplexer, uint8_t bus)
    : mcrDev(addr) {
  _use_multiplexer = use_multiplexer;
  _bus = bus;
  char buff[_id_len] = {0x00};

  setDesc(i2cDevDesc(firstAddressByte()));

  //                 0000000000111111111122222222223
  //       byte num: 0123456789012345678901234567890
  //      example id: i2c/f8f005f73b53.04.am2315
  //    format of id: i2c/mac_address/bus/desc
  //        max len: 30 bytes (id + string terminator)
  sprintf(buff, "i2c/%s.%02x.%s", mcrUtil::macAddress(), this->bus(), desc());

  mcrDevID_t new_id = mcrDevID(buff);
  setID(new_id);
};

uint8_t i2cDev::devAddr() { return firstAddressByte(); };
bool i2cDev::useMultiplexer() { return _use_multiplexer; };
uint8_t i2cDev::bus() { return _bus; };

// info / debugg functions
void i2cDev::printReadMS(const char *func, uint8_t indent) {
  mcrUtil::printDateTime(func);
  Serial.print(desc());
  Serial.print(" ");
  Serial.print((char *)id());
  Serial.print(" read took ");
  Serial.print(readMS());
  Serial.println("ms");
}

#endif // __cplusplus
