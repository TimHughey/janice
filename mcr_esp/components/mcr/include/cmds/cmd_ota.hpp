/*
    cmd_base.hpp - Master Control Command OTA Class
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

#ifndef mcr_cmd_ota_h
#define mcr_cmd_ota_h

#include <cstdlib>
#include <sstream>
#include <string>

#include <esp_timer.h>
#include <external/ArduinoJson.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <sys/time.h>
#include <time.h>

#include "cmds/cmd_base.hpp"
#include "cmds/cmd_types.hpp"
#include "misc/util.hpp"
#include "misc/version.hpp"

typedef class mcrCmdOTA mcrCmdOTA_t;
class mcrCmdOTA : public mcrCmdBase {
private:
  mcrRawMsg_t *_raw = nullptr;
  std::string _host;
  std::string _head;
  std::string _stable;
  std::string _partition;
  int _delay_ms = 0;

  void begin();
  void bootFactoryNext();
  void end();
  void processBlock();

public:
  mcrCmdOTA(mcrCmdType_t type, JsonObject &root);
  mcrCmdOTA(mcrCmdType_t type, mcrRawMsg_t *raw)
      : mcrCmdBase(type), _raw(raw){};
  ~mcrCmdOTA(){};

  bool process();

  const std::string debug();
};

#endif
