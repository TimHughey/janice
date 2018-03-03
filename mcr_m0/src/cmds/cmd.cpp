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

mcrCmd::mcrCmd(mcrDevID_t &id, uint32_t mask, uint32_t state) {
  _dev_id = id;
  _mask = mask;
  _state = state;
}

mcrCmd::mcrCmd(mcrDevID_t &id, uint32_t mask, uint32_t state,
               mcrRefID_t &refid) {
  _dev_id = id;
  _mask = mask;
  _state = state;
  _refid = refid;
}

mcrDevID_t &mcrCmd::dev_id() { return _dev_id; }
uint32_t mcrCmd::state() { return _state; }
uint32_t mcrCmd::mask() { return _mask; }
time_t mcrCmd::latency() { return _latency; }
mcrRefID_t &mcrCmd::refID() { return _refid; }
const uint32_t mcrCmd::size() { return sizeof(mcrCmd_t); }
void mcrCmd::ack(bool ack) { _ack = ack; }
const bool mcrCmd::ack() { return _ack; }

void mcrCmd::debug(bool newline) {
  log("mcrCmd_t:: ");
  _dev_id.debug();
  log(" mask: ");
  logAsBinary(_mask);
  log(" state: ");
  logAsBinary(_state);
  (_ack) ? log(" ACK") : log(" NOACK");
  log(" latency: ");
  logElapsedMicros(latency(), newline);
}

#endif // __cplusplus
