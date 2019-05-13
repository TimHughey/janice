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

mcrRestart::mcrRestart() {}

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

void mcrRestart::restart(const char *text, const char *func,
                         uint32_t reboot_delay_ms) {

  ESP_LOGW("mcrRestart", "%s requested restart [%s]",
           (func == nullptr) ? "<UNKNOWN FUNCTION>" : func,
           (text == nullptr) ? "UNSPECIFIED REASON" : text);

  if (text) {
    textReading_t *rlog = new textReading(text);
    std::unique_ptr<textReading_t> rlog_ptr(rlog);

    mcrMQTT::instance()->publish(rlog);

    // pause to ensure reading has been published
    // FUTURE:  query mcrMQTT to ensure all messages have been sent
    //          rather than wait a hardcoded duration
    vTaskDelay(pdMS_TO_TICKS(1500));
  }

  ESP_LOGW("mcrRestart", "spooling ftl for jump in %dms...", reboot_delay_ms);
  vTaskDelay(pdMS_TO_TICKS(reboot_delay_ms));
  ESP_LOGW("mcrRestart", "JUMP!");

  esp_restart();
}
