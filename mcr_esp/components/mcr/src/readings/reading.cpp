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

#include <cstdlib>
#include <cstring>

#include <ArduinoJson.h>
#include <FreeRTOS.h>
#include <System.h>
#include <esp_log.h>
#include <sys/time.h>
#include <time.h>

#include "id.hpp"
#include "reading.hpp"
#include "refid.hpp"
#include "util.hpp"

Reading::Reading(time_t mtime) { _mtime = mtime; }

Reading::Reading(mcrDevID_t &id, time_t mtime) {
  _id = id;
  _mtime = mtime;
}

Reading::~Reading() {
  if (_json != nullptr) {
    ESP_LOGD("Reading", "freeing _json (%p)", (void *)_json);
    delete _json;
  }
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
  root["mtime"] = _mtime;

  if (_id.valid()) {
    root["device"] = _id.asString();
  }

  if (_cmd_ack) {
    root["cmdack"] = _cmd_ack;
    root["latency"] = _latency;
    root["refid"] = (const char *)_refid;
  }
}

char *Reading::json(char *buffer, size_t len) {
  const size_t json_buff_size = 512;
  if (_json) { // prevent memory leaks with repeated calls
    delete _json;
    _json = nullptr;
  }

  DynamicJsonBuffer json_buffer(json_buff_size);
  JsonObject &root = json_buffer.createObject();

  commonJSON(root);
  populateJSON(root);

  if (buffer == nullptr) {
    size_t actual_len = root.measureLength() + 1;
    _json = new char[actual_len];
    root.printTo(_json, actual_len);
    return _json;
  } else {
    root.printTo(_json, len);
    return buffer;
  }
}
