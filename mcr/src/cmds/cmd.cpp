/*
    mcr_cmd.cpp - Master Control Remote Switch Command
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

#include <TimeLib.h>

#include "../devs/base.hpp"
#include "../misc/util.hpp"
#include "cmd.hpp"

mcrCmd::mcrCmd(mcrDevID_t &id, uint8_t mask, uint8_t state) {
  _dev_id = id;
  _mask = mask;
  _state = state;
}

mcrCmd::mcrCmd(mcrDevID_t &id, uint8_t mask, uint8_t state, mcrRefID_t &refid) {
  _dev_id = id;
  _mask = mask;
  _state = state;
  _refid = refid;
}

mcrDevID_t &mcrCmd::dev_id() { return _dev_id; }
// mcrDevID_t &name() { return _dev_id; }
// char *name() { return _dev_id; }
uint8_t mcrCmd::state() { return _state; }
uint8_t mcrCmd::mask() { return _mask; }
time_t mcrCmd::latency() { return _latency; }
mcrRefID_t &mcrCmd::refID() { return _refid; }
const uint8_t mcrCmd::size() { return sizeof(mcrCmd); }

void mcrCmd::printLog(bool newline) {
  Serial.print("dev_id=");
  Serial.print(dev_id());
  Serial.print(" ");
  Serial.print("latency=");
  mcrUtil::printElapsedMicros(latency());

  if (newline)
    Serial.println();
}

#endif // __cplusplus
