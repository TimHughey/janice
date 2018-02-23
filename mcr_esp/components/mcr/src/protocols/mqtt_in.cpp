/*
    mqtt_out.cpp - Master Control Remote MQTT Outbound Message Task
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

// #define VERBOSE 1

#include <cstdlib>
#include <cstring>
#include <vector>

#include <FreeRTOS.h>
#include <System.h>
#include <Task.h>
#include <WiFi.h>
#include <WiFiEventHandler.h>
#include <esp_log.h>
#include <forward_list>
#include <freertos/event_groups.h>
#include <freertos/ringbuf.h>

// MCR specific includes
#include "cmds/cmd_factory.hpp"
#include "external/mongoose.h"
#include "misc/util.hpp"
#include "misc/version.hpp"
#include "net/mcr_net.hpp"
#include "protocols/mqtt_in.hpp"
#include "readings/readings.hpp"

// static uint32_t cmd_callback_count = 0;
// static cmdCallback_t cmd_callback[10] = {nullptr};
static char tTAG[] = "mcrMQTTin";

static mcrMQTTin_t *__singleton = nullptr;

mcrMQTTin::mcrMQTTin(RingbufHandle_t rb) {
  _rb = rb;

  ESP_LOGI(tTAG, "task created, rb=%p", (void *)rb);
  __singleton = this;
}

mcrMQTTin_t *mcrMQTTin::instance() { return __singleton; }

UBaseType_t mcrMQTTin::changePriority(UBaseType_t priority) {
  vTaskPrioritySet(_task.handle, priority);
  return _task.priority;
}

void mcrMQTTin::restorePriority() {
  vTaskPrioritySet(_task.handle, _task.priority);
}

void mcrMQTTin::run(void *data) {
  size_t msg_len = 0;
  mqttInMsg_t entry;
  void *msg = nullptr;
  mcrCmdFactory_t factory;

  ESP_LOGI(tTAG, "started, entering run loop");

  for (;;) {
    ESP_LOGD(tTAG, "waiting for rb data");
    msg = xRingbufferReceive(_rb, &msg_len, portMAX_DELAY);

    if (msg_len != sizeof(mqttInMsg_t)) {
      ESP_LOGW(tTAG, "rb msg size mistmatch (msg_len=%u)", msg_len);
      continue;
    }

    // _rb->receive returns a pointer to the msg of type mqttInMsg_t
    // make a local copy and return the message to release it
    memcpy(&entry, msg, sizeof(mqttInMsg_t));

    ESP_LOGD(tTAG, "recv msg(len=%u): topic(%s) data(ptr=%p)", msg_len,
             entry.topic->c_str(), (void *)entry.data);

    // done with message, give it back to ringbuffer
    vRingbufferReturnItem(_rb, msg);
    mcrCmd_t *cmd = factory.fromRaw(entry.data);

    if (entry.topic->find("command") != std::string::npos) {
      cmd && cmd->process();
    } else if (entry.topic->find("ota") != std::string::npos) {
      cmd && cmd->process();
    } else {
      ESP_LOGW(tTAG, "unhandled topic=%s", entry.topic->c_str());
    }

    // ok, we're done with the originally allocated inbound msg and the command
    delete cmd;
    delete entry.topic;
    delete entry.data;

    // never returns
  }
}
