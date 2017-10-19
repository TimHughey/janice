/*
    reading.cpp - Readings used within Master Control Remote
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
#endif

#include <ArduinoJson.h>
#include <TimeLib.h>
#include <WiFi101.h>
#include <elapsedMillis.h>

#include "../devs/id.hpp"
#include "../misc/util.hpp"
#include "../misc/refid.hpp"
#include "reading.hpp"

Reading::Reading(time_t mtime) { _mtime = mtime; }

Reading::Reading(mcrDevID_t &id, time_t mtime) {
  _id = id;
  _mtime = mtime;
}

void Reading::setCmdAck(time_t latency, const char *refid_raw) {
  _cmd_ack = true;
  _latency = latency;

  if (refid_raw)
    _refid = refid_raw;
}

void Reading::commonJSON(JsonObject &root) {
  root["version"] = _version;
  root["host"] = mcrUtil::hostID();
  root["device"] = _id.asString();
  root["mtime"] = _mtime;
  // root["type"] = typeAsString();

  if (_cmd_ack) {
    root["cmdack"] = _cmd_ack;
    root["latency"] = _latency;
    root["refid"] = (const char *)_refid;
  }
}

char *Reading::json() {
  // static class variables for conversion to JOSN
  // this implies that a single JSON conversion can be done at any time
  // and the converted JSON must be used or copied before the next
  StaticJsonBuffer<1024> _jsonBuffer;
  static char _buffer[2048] = {0x00};

  // yes, i bit paranoid to always clear every buffer before use
  // memset(_buffer, 0x00, sizeof(_buffer));

  JsonObject &root = _jsonBuffer.createObject();
  commonJSON(root);
  populateJSON(root);

  root.printTo(_buffer, sizeof(_buffer));

  return _buffer;
}
