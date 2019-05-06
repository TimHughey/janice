/*
    cmd_base.hpp - Master Control Command Base Class
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

#ifndef mcr_cmd_base_h
#define mcr_cmd_base_h

#include <cstdlib>
#include <memory>
#include <string>

#include <esp_timer.h>
#include <external/ArduinoJson.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <sys/time.h>
#include <time.h>

#include "cmds/cmd_types.hpp"
#include "misc/mcr_types.hpp"

using std::unique_ptr;
using namespace mcr;

typedef class mcrCmd mcrCmd_t;
class mcrCmd {
private:
  mcrCmdType_t _type;
  time_t _mtime = time(nullptr);

  void populate(JsonDocument &doc);

protected:
  uint64_t _parse_us = 0LL;
  uint64_t _create_us = 0LL;
  uint64_t _latency = esp_timer_get_time();

public:
  mcrCmd(mcrCmdType_t type);
  mcrCmd(JsonDocument &doc);
  mcrCmd(mcrCmdType_t type, JsonDocument &doc);
  virtual ~mcrCmd(){};

  virtual time_t latency();
  virtual bool process() { return false; };
  void recordCreateMetric(int64_t create_us) { _create_us = create_us; };
  void recordParseMetric(int64_t parse_us) { _parse_us = parse_us; };
  virtual bool sendToQueue(cmdQueue_t &cmd_q) { return false; };
  virtual size_t size() { return sizeof(mcrCmd_t); };
  mcrCmdType_t type() { return _type; };

  virtual const unique_ptr<char[]> debug();
};

#endif
