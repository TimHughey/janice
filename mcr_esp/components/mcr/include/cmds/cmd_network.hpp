/*
    cmd_base.hpp - Master Control Command Network Class
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

#ifndef mcr_cmd_network_h
#define mcr_cmd_network_h

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
#include "misc/mcr_types.hpp"

typedef class mcrCmdNetwork mcrCmdNetwork_t;
class mcrCmdNetwork : public mcrCmd {
private:
  std::string _host;
  std::string _name;

public:
  mcrCmdNetwork(JsonObject &root);
  ~mcrCmdNetwork(){};

  bool process();
  virtual size_t size() { return sizeof(mcrCmdNetwork_t); };
  const std::string debug();
};

#endif
