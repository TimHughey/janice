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

#include <esp_log.h>
#include <external/ArduinoJson.h>
#include <freertos/FreeRTOS.h>
#include <sys/time.h>
#include <time.h>

#include "net/mcr_net.hpp"
#include "readings/reading.hpp"

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

void Reading::commonJSON(JsonObject &root) {
  root["host"] = mcr::Net::hostID();
  root["name"] = mcr::Net::getName();
  root["mtime"] = _mtime;

  if (_id.valid()) {
    root["device"] = _id.asString();
  }

  if (_cmd_ack) {
    root["cmdack"] = _cmd_ack;
    root["latency"] = _latency;
    root["refid"] = _refid;
  }

  if (_crc_mismatches > 0) {
    root["crc_mismatches"] = _crc_mismatches;
  }

  if (_read_errors > 0) {
    root["read_errors"] = _read_errors;
  }

  if (_write_errors > 0) {
    root["write_errors"] = _write_errors;
  }

  if (_read_us > 0) {
    root["read_us"] = _read_us;
  }

  if (_write_us > 0) {
    root["write_us"] = _write_us;
  }
}

std::string *Reading::json(char *buffer, size_t len) {
  std::string *json_string = new std::string;
  json_string->reserve(800);

  DynamicJsonBuffer json_buffer(800);
  JsonObject &root = json_buffer.createObject();

  commonJSON(root);
  populateJSON(root);

  root.printTo(*json_string);

  return json_string;
}

void Reading::setCmdAck(time_t latency, mcrRefID_t &refid) {
  _cmd_ack = true;
  _latency = latency;

  _refid = refid;
}
