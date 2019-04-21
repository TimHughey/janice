/*
    mcr_restart.hpp -- MCR abstraction for esp_restart()
    Copyright (C) 2019  Tim Hughey

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

#ifndef mcr_restart_hpp
#define mcr_restart_hpp

#include <string>

#include <external/ArduinoJson.h>
#include <sys/time.h>
#include <time.h>

#include <esp_system.h>

#include "readings/readings.hpp"

typedef class mcrRestart mcrRestart_t;
#define DEFAULT_WAIT_TICKS pdMS_TO_TICKS(4000)

class mcrRestart {
private:
  TickType_t _delay_ticks;

public:
  mcrRestart(TickType_t delay_ticks = 0);
  static mcrRestart_t *instance();

  ~mcrRestart();

  void restart(const char *text = nullptr, const char *func = nullptr);
};

#endif // mcr_restart_hpp
