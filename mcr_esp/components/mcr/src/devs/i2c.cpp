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

#include <memory>
#include <string>

#include <driver/i2c.h>
#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <sys/time.h>
#include <time.h>

#include "devs/base.hpp"
#include "devs/i2c_dev.hpp"
#include "misc/mcr_types.hpp"
#include "net/mcr_net.hpp"

using mcr::Net;
using std::unique_ptr;

const char *i2cDev::i2cDevDesc(uint8_t addr) {
  switch (addr) {
  case 0x5C:
    return (const char *)"am2315";
    break;

  case 0x44:
    return (const char *)"sht31";
    break;

  case 0x20:
    return (const char *)"mcp23008";
    break;

  case 0x36:
    return (const char *)"soil";
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

  auto const max_id_len = 63;
  unique_ptr<char[]> id(new char[max_id_len + 1]);

  setDescription(i2cDevDesc(firstAddressByte()));

  snprintf(id.get(), max_id_len, "i2c/self.%02x.%s", this->bus(),
           description().c_str());

  setID(id.get());
};

// externalName implementation for i2cDev
// externalName includes the MCR name (instead of self)
const char *i2cDev::externalName() {

  // if _external_name hasn't been set then build it here
  if (_external_name.length() == 0) {
    const auto name_max = 64;
    unique_ptr<char[]> name(new char[name_max + 1]);

    snprintf(name.get(), name_max, "i2c/%s.%02x.%s", Net::getName().c_str(),
             this->bus(), description().c_str());

    _external_name = name.get();
  }

  return _external_name.c_str();
}

uint8_t i2cDev::devAddr() { return firstAddressByte(); };
bool i2cDev::useMultiplexer() { return _use_multiplexer; };
uint8_t i2cDev::bus() const { return _bus; };

uint8_t i2cDev::readAddr() {
  return (firstAddressByte() << 1) | I2C_MASTER_READ;
};

uint8_t i2cDev::writeAddr() {
  return (firstAddressByte() << 1) | I2C_MASTER_WRITE;
};

const unique_ptr<char[]> i2cDev::debug() {
  const auto max_len = 127;
  unique_ptr<char[]> debug_str(new char[max_len + 1]);

  snprintf(debug_str.get(), max_len, "i2cDev(%s bus=%d use_mplex=%s)",
           externalName(), _bus, (_use_multiplexer) ? "true" : "false");

  return move(debug_str);
}
