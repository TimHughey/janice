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
#include <freertos/queue.h>

// MCR specific includes
#include "cmds/cmd_factory.hpp"
#include "misc/mcr_types.hpp"
#include "net/mcr_net.hpp"
#include "protocols/mqtt_in.hpp"
#include "readings/readings.hpp"

static char TAG[] = "mcrMQTTin";

static mcrMQTTin_t *__singleton = nullptr;

mcrMQTTin::mcrMQTTin(QueueHandle_t q_in) : _q_in(q_in) {

  ESP_LOGI(TAG, "task created, queue(%p)", (void *)_q_in);
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
  mqttInMsg_t msg;
  mcrCmdFactory_t factory;

  // note:  no reason to wait for wifi, normal ops or other event group
  //        bits since mcrMQTTin waits for queue data from other tasks via
  //        MQTT::publish().
  //
  //        said differently, this task will not execute until another task
  //        sends it something through the queue.
  ESP_LOGI(TAG, "started, entering run loop");

  for (;;) {
    BaseType_t q_rc = pdFALSE;

    bzero(&msg, sizeof(mqttInMsg_t)); // just because we like clean memory
    q_rc = xQueueReceive(_q_in, &msg, portMAX_DELAY);

    if (q_rc == pdTRUE) {
      // reminder:  must do a != to test for equality
      if (msg.topic->find("command") != std::string::npos) {
        mcrCmd_t *cmd = factory.fromRaw(msg.data);
        mcrCmd_t_ptr cmd_ptr(cmd);

        if (cmd != nullptr) {
          cmd->process();
        }
      } else {
        ESP_LOGI(TAG, "ignoring topic(%s)", msg.topic->c_str());
      }

      // ok, we're done with the contents of the previously allocated msg
      delete msg.topic;
      delete msg.data;

    } else {
      ESP_LOGW(TAG, "queue received failed");
      continue;
    }
  } // infinite loop to process inbound MQTT messages
}
