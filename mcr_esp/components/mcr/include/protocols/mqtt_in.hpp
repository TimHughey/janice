/*
    mqtt_out.hpp - Master Control Remote MQTT
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

#ifndef mcr_mqtt_in_h
#define mcr_mqtt_in_h

#include <array>
#include <cstdlib>
#include <memory>
#include <string>
#include <vector>

#include <esp_log.h>
#include <esp_ota_ops.h>
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/queue.h>
#include <freertos/task.h>

#include "cmds/factory.hpp"
#include "misc/mcr_types.hpp"
#include "readings/readings.hpp"

namespace mcr {

typedef struct {
  string_t *topic = nullptr;
  rawMsg_t *data = nullptr;
} mqttInMsg_t;

typedef class mcrMQTTin mcrMQTTin_t;
class mcrMQTTin {
private:
  mcrTask_t _task = {.handle = nullptr,
                     .data = nullptr,
                     .lastWake = 0,
                     .priority = CONFIG_MCR_MQTT_INBOUND_TASK_PRIORITY,
                     .stackSize = (5 * 1024)};
  QueueHandle_t _q_in;
  string_t _cmd_feed;
  void *_task_data = nullptr;

  time_t _lastLoop;
  uint16_t _msg_id = 0;

  // Task implementation
  static void runEngine(void *task_instance) {
    mcrMQTTin_t *task = (mcrMQTTin_t *)task_instance;
    task->core(task->_task_data);
  }

public:
  mcrMQTTin(QueueHandle_t q, const char *cmd_feed);
  static mcrMQTTin_t *instance();

  UBaseType_t changePriority(UBaseType_t priority);
  void restorePriority();
  void core(void *data);

  void delay(int ms) { ::vTaskDelay(pdMS_TO_TICKS(ms)); }
  void start(void *task_data = nullptr) {
    if (_task.handle != nullptr) {
      ESP_LOGW(tagEngine(), "there may already be a task running %p",
               (void *)_task.handle);
    }

    // this (object) is passed as the data to the task creation and is
    // used by the static runEngine method to call the implemented run
    // method
    ::xTaskCreate(&runEngine, tagEngine(), _task.stackSize, this,
                  _task.priority, &_task.handle);
  }

  void stop() {
    if (_task.handle == nullptr) {
      return;
    }

    xTaskHandle temp = _task.handle;
    _task.handle = nullptr;
    ::vTaskDelete(temp);
  }

  static const char *tagEngine() { return "mcrMQTTin"; };
};
} // namespace mcr

#endif // mqtt_in_h
