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

#include <esp_log.h>
#include <forward_list>
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/ringbuf.h>

// MCR specific includes
#include "cmds/cmd_factory.hpp"
#include "misc/mcr_types.hpp"
#include "net/mcr_net.hpp"
#include "protocols/mqtt_in.hpp"
#include "readings/readings.hpp"

static char TAG[] = "mcrMQTTin";

static mcrMQTTin_t *__singleton = nullptr;

mcrMQTTin::mcrMQTTin(RingbufHandle_t rb) {
  _rb = rb;

  ESP_LOGI(TAG, "task created, inbound ringbuff=%p", (void *)rb);
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

  // note:  no reason to wait for wifi, normal ops or other event group
  //        bits since mcrMQTTin waits on ringbuffer data from other tasks
  //        that do wait for event group bits.
  //
  //        said differently, this task will not execute until another task
  //        sends it something through the ringbuffer.
  ESP_LOGI(TAG, "started, entering run loop");

  for (;;) {
    // ESP_LOGD(TAG, "wait indefinitly for rb data");
    msg = xRingbufferReceive(_rb, &msg_len, portMAX_DELAY);

    if (msg_len != sizeof(mqttInMsg_t)) {
      ESP_LOGW(TAG, "dropping msg of wrong size (msg_len(%u) != %u)", msg_len,
               sizeof(msg_len));

      // even though the msg_len is wrong we still return the msg to
      // the ringbuffer to free resources (see notes below)
      vRingbufferReturnItem(_rb, msg);
      continue;
    }

    // _rb->receive returns a pointer to the msg of type mqttInMsg_t
    // make a local copy so the message in the ringbuffer can be released
    memcpy(&entry, msg, sizeof(mqttInMsg_t));

    // done with message. quickly return to ringbuffer to release resources
    // for the msg to make space for more messages. note entry.[topic,data]
    // were allocated elsewhere (not stored in the ringbuffer) and must be
    // released seperately.
    // for clarity, the ringbuffer entry only contains pointers for efficiency
    vRingbufferReturnItem(_rb, msg);

    // ESP_LOGD(TAG, "recv msg(len=%u): topic(%s) data(ptr=%p)", msg_len,
    //         entry.topic->c_str(), (void *)entry.data);

    // reminder:  must do a != to test for
    if (entry.topic->find("command") != std::string::npos) {
      mcrCmd_t *cmd = factory.fromRaw(entry.data);
      mcrCmd_t_ptr cmd_ptr(cmd);

      if (cmd != nullptr) {
        cmd->process();
      }
    } else {
      ESP_LOGI(TAG, "ignoring topic(%s)", entry.topic->c_str());
    }

    // ok, we're done with the contents of the previously allocated msg
    delete entry.topic;
    delete entry.data;

    // infinite loop to process inbound MQTT messages
  }
}
