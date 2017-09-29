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

#include "../include/mcr_dev.hpp"
#include "../include/mcr_util.hpp"
#include "../include/ref_id.hpp"

typedef class mcrCmd mcrCmd_t;

class mcrCmd {
private:
  static const uint8_t _max_len = 30;
  mcrDevID_t _dev_id;
  uint8_t _state = 0x00;
  uint8_t _mask = 0x00;
  elapsedMicros _latency = 0;
  time_t _mtime = now();
  mcrRefID_t _refid; // example: 2d931510-d99f-494a-8c67-87feb05e1594

public:
  mcrCmd() {}

  mcrCmd(mcrDevID_t &id, uint8_t mask, uint8_t state, mcrRefID_t &cmd);
  mcrCmd(mcrDevID_t &id, uint8_t mask, uint8_t state);

  mcrDevID_t &dev_id();
  uint8_t state();
  uint8_t mask();
  time_t latency();
  mcrRefID_t &refID();

  static const uint8_t size();

  void printLog(bool newline = false);
};

#endif // __cplusplus
#endif // mcr_cmd_h
