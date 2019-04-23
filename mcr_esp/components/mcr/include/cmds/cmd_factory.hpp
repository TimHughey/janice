/*
    cmd_base.hpp - Master Control Command Factory Class
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

#ifndef mcr_cmd_factory_h
#define mcr_cmd_factory_h

#include <cstdlib>
#include <sstream>
#include <string>
#include <vector>

#include <esp_timer.h>
#include <freertos/FreeRTOS.h>
#include <sys/time.h>
#include <time.h>

#include "cmds/cmd_base.hpp"
#include "cmds/cmd_network.hpp"
#include "cmds/cmd_ota.hpp"
#include "cmds/cmd_switch.hpp"
#include "cmds/cmd_types.hpp"
#include "misc/mcr_types.hpp"

typedef class mcrCmdFactory mcrCmdFactory_t;
class mcrCmdFactory {
private:
  mcrCmd_t *fromJSON(mcrRawMsg_t *raw);
  mcrCmd_t *fromOTA(mcrRawMsg_t *raw);

public:
  mcrCmdFactory(){};

  mcrCmd_t *fromRaw(mcrRawMsg_t *raw);
};

#endif
