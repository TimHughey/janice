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

// #include <cstdlib>
// #include <cstring>
#include <sstream>
#include <string>

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

Reading::Reading(const mcrDevID_t &id, time_t mtime) {
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

std::string *Reading::json(char *buffer, size_t len) {
  std::string *json_string = new std::string;

  DynamicJsonBuffer json_buffer(512);
  JsonObject &root = json_buffer.createObject();

  commonJSON(root);
  populateJSON(root);

  root.printTo(*json_string);

  return json_string;
}
