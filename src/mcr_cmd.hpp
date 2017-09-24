/*
    mcr_cmd.h - Master Control Remote Switch Command
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

#ifndef mcr_cmd_h
#define mcr_cmd_h

#ifdef __cplusplus

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include <TimeLib.h>

#include "mcr_dev.hpp"

class mcrCmd {
private:
  static const uint8_t _max_len = 30;
  mcrDevID _dev_id;
  uint8_t _state = 0x00;
  uint8_t _mask = 0x00;
  elapsedMicros _latency = 0;
  time_t _mtime = now();

public:
  mcrCmd() {}

  mcrCmd(const char *name, uint8_t mask, uint8_t state) {
    _dev_id = name;
    _mask = mask;
    _state = state;
    _latency = 0;
    _mtime = now();
  };

  mcrDevID_t &dev_id() { return _dev_id; }
  mcrDevID_t &name() { return _dev_id; }
  // char *name() { return _dev_id; }
  uint8_t state() { return _state; }
  uint8_t mask() { return _mask; }
  time_t latency() { return _latency; }

  static const uint8_t size() { return sizeof(mcrCmd); }
};

typedef class mcrCmd mcrCmd_t;

#endif // __cplusplus
#endif // mcr_cmd_h
