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

// #include <cstdlib>
// #include <cstring>
#include <iomanip>
#include <sstream>
#include <string>

#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <sys/time.h>
#include <time.h>

#include "devs/base.hpp"
#include "devs/i2c_dev.hpp"
#include "misc/mcr_types.hpp"
#include "net/mcr_net.hpp"

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
  std::stringstream id_ss;

  setDescription(i2cDevDesc(firstAddressByte()));

  //      example id: i2c/f8f005f73b53.04.am2315
  //    format of id: i2c/mac_address.bus.desc
  id_ss << "i2c/self.";
  id_ss << std::setw(sizeof(uint8_t) * 2) << std::setfill('0') << std::hex
        << static_cast<unsigned>(this->bus());
  id_ss << "." << description();

  mcrDevID_t new_id = mcrDevID(id_ss.str().c_str());
  setID(new_id);
};

const mcrDevID_t &i2cDev::externalName() {
  std::stringstream ext_id;

  ext_id << "i2c/" << mcr::Net::getName() << ".";
  ext_id << std::setw(sizeof(uint8_t) * 2) << std::setfill('0') << std::hex
         << static_cast<unsigned>(this->bus());
  ext_id << "." << description();

  _external_name = mcrDevID(ext_id.str().c_str());
  return _external_name;
}

uint8_t i2cDev::devAddr() { return firstAddressByte(); };
bool i2cDev::useMultiplexer() { return _use_multiplexer; };
uint8_t i2cDev::bus() { return _bus; };

const std::string i2cDev::debug() {
  mcrDevID_t ext_name = externalName();
  std::ostringstream debug_str;
  std::stringstream bus_str;
  std::stringstream mplex_str;

  bus_str << (int)_bus;
  mplex_str << ((_use_multiplexer) ? "true" : "false");

  debug_str << "i2cDev(" << ext_name << " bus=" << bus_str.str()
            << " use_mplex=" << mplex_str.str() << ")";

  return debug_str.str();
}
