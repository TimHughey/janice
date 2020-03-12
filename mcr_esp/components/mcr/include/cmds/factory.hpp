/*
    factory.hpp - Master Control Command Factory Class
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
#include <string>
#include <vector>

#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <sys/time.h>
#include <time.h>

#include "cmds/base.hpp"
#include "cmds/network.hpp"
#include "cmds/ota.hpp"
#include "cmds/pwm.hpp"
#include "cmds/switch.hpp"
#include "cmds/types.hpp"
#include "external/ArduinoJson.hpp"
#include "misc/mcr_types.hpp"

namespace mcr {

typedef class mcrCmdFactory mcrCmdFactory_t;
class mcrCmdFactory {
private:
  mcrCmd_t *manufacture(JsonDocument &doc, elapsedMicros &parse_elapsed);

public:
  mcrCmdFactory();

  mcrCmd_t *fromRaw(JsonDocument &doc, rawMsg_t *raw);
};

} // namespace mcr

#endif
