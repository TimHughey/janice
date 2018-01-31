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

#include "../devs/base.hpp"
#include "../misc/refid.hpp"
#include "../misc/util.hpp"

typedef class mcrCmd mcrCmd_t;

class mcrCmd {
private:
  mcrDevID_t _dev_id;
  uint32_t _state = 0x00;
  uint32_t _mask = 0x00;
  elapsedMicros _latency = 0;
  time_t _mtime = now();
  mcrRefID_t _refid; // example: 2d931510-d99f-494a-8c67-87feb05e1594
  bool _ack = true;

public:
  mcrCmd() {}

  mcrCmd(mcrDevID_t &id, uint32_t mask, uint32_t state, mcrRefID_t &cmd);
  mcrCmd(mcrDevID_t &id, uint32_t mask, uint32_t state);

  mcrDevID_t &dev_id();
  uint32_t state();
  uint32_t mask();
  time_t latency();
  mcrRefID_t &refID();
  void ack(bool ack);
  const bool ack();

  static const uint32_t size();

  void debug(bool newline = false);
};

#endif // __cplusplus
#endif // mcr_cmd_h
