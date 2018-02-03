/*
    engine.cpp - Master Control Remote Engine
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

#include <map>

#include <FreeRTOS.h>
#include <System.h>
#include <Task.h>
#include <esp_log.h>
#include <freertos/event_groups.h>

#include "cmd.hpp"
#include "engine.hpp"
#include "readings.hpp"
#include "util.hpp"

static const char tTAG[] = "mcrEngine";

// mcrEngine::mcrEngine<mcrDevID_t, T>(mcrMQTT *mqtt) { _mqtt = mqtt; }
