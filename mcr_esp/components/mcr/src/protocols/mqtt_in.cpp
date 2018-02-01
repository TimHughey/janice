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

#include <FreeRTOS.h>
#include <System.h>
#include <Task.h>
#include <WiFi.h>
#include <WiFiEventHandler.h>
#include <esp_log.h>
#include <forward_list>
#include <freertos/event_groups.h>

// MCR specific includes
#include "cmd.hpp"
#include "mongoose.h"
#include "mqtt_in.hpp"
#include "readings.hpp"
#include "util.hpp"
#include "version.hpp"

// static uint32_t cmd_callback_count = 0;
// static cmdCallback_t cmd_callback[10] = {nullptr};
static char tTAG[] = "mcrMQTTin";
static bool debugMode = false;

static mcrMQTTin *__singleton = nullptr;

mcrMQTTin::mcrMQTTin(Ringbuffer *rb) : Task(tTAG, 5 * 1024, 10) {
  _rb = rb;

  ESP_LOGI(tTAG, "task created, rb=%p", (void *)rb);
  __singleton = this;
}

void mcrMQTTin::registerCmdQueue(cmdQueue_t &cmd_q) {
  ESP_LOGI(tTAG, "registering cmd_q id=%s prefix=%s q=%p", cmd_q.id,
           cmd_q.prefix, (void *)cmd_q.q);

  _cmd_queues.push_back(cmd_q);
}

void mcrMQTTin::run(void *data) {
  size_t msg_len = 0;
  size_t json_len = 0;
  char *json = nullptr;
  char *msg = nullptr;
  // const size_t buff_len = 256;
  // char buff[buff_len + 1] = {0x00};

  ESP_LOGI(tTAG, "started, entering run loop");

  for (;;) {
    ESP_LOGD(tTAG, "waiting for ringbuffer data");
    msg = (char *)_rb->receive(&msg_len, portMAX_DELAY);

    memcpy((char *)&json_len, msg, sizeof(size_t));
    json = msg + sizeof(size_t);

    ESP_LOGD(tTAG, "recv msg, payload(msg_len=%u,json_len=%u)", msg_len,
             json_len);

    mcrCmd_t *cmd = mcrCmd::fromJSON(json, json_len);
    _rb->returnItem(msg); // done with message, give it back to ringbuffer

    if (cmd) {
      // bzero(buff, sizeof(buff));
      // cmd->debug(buff, buff_len);
      // ESP_LOGI(tTAG, "%s", buff);

      for (auto cmd_q : _cmd_queues) {
        if (cmd->matchPrefix(cmd_q.prefix)) {
          // make a fresh copy of the cmd before pusing to queue
          // this ensures there's no internally allocated memory
          mcrCmd_t fresh_cmd(*cmd);

          if (xQueueSendToBack(cmd_q.q, (void *)&fresh_cmd, pdMS_TO_TICKS(1)) ==
              pdTRUE) {
            ESP_LOGD(tTAG, "added cmd to queue %s", cmd_q.id);
          } else
            ESP_LOGW(tTAG, "failed to place cmd on queue %s", cmd_q.id);
        }
      }
    }

    // clean-up the parsed cmd and free the space ringbuffer
    delete cmd;
  }
}

void mcrMQTTin::setDebug(bool mode) { debugMode = mode; }
void mcrMQTTin::debugOn() { setDebug(true); }
void mcrMQTTin::debugOff() { setDebug(false); }
