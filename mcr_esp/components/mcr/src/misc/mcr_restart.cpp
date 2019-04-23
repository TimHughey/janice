/*
    mcr_restart.cpp - MCR abstraction for esp_restart()
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

#include <string>

#include <sys/time.h>
#include <time.h>

#include "misc/mcr_restart.hpp"
#include "protocols/mqtt.hpp"

static mcrRestart_t *__singleton__ = nullptr;

mcrRestart::mcrRestart(TickType_t delay_ticks) : _delay_ticks(delay_ticks) {}

// STATIC
mcrRestart_t *mcrRestart::instance() {
  if (__singleton__) {
    return __singleton__;

  } else {

    __singleton__ = new mcrRestart();
    return __singleton__;
  }
}

mcrRestart::~mcrRestart() {
  if (__singleton__) {
    delete __singleton__;
    __singleton__ = nullptr;
  }
}

void mcrRestart::restart(const char *text, const char *func) {
  if (text) {
    textReading_t reading(text);

    mcrMQTT::instance()->publish(reading);

    // override the delay specified if publishing a text reading
    _delay_ticks = std::max(_delay_ticks, DEFAULT_WAIT_TICKS);
  }
  ESP_LOGW("mcrRestart", "%s requested restart [%s]",
           (func == nullptr) ? "<UNKNOWN FUNCTION>" : func,
           (text == nullptr) ? "UNSPECIFIED REASON" : text);

  ESP_LOGW("mcrRestart", "spooling ftl for jump in %d ticks...", _delay_ticks);
  vTaskDelay(_delay_ticks);
  ESP_LOGW("mcrRestart", "JUMP!");

  esp_restart();
}
