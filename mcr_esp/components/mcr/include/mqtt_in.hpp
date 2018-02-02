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

#include <cstdlib>
#include <string>
#include <vector>

#include <FreeRTOS.h>
#include <System.h>
#include <Task.h>
#include <esp_log.h>
#include <freertos/event_groups.h>
#include <freertos/queue.h>

#include "mongoose.h"
#include "readings.hpp"

#define mcr_mqtt_version_1 1

// Set the version of MCP Remote
#ifndef mcr_mqtt_version
#define mcr_mqtt_version mcr_mqtt_version_1
#endif

typedef struct {
  char id[16];
  char prefix[5];
  QueueHandle_t q;
} cmdQueue_t;

typedef class mcrMQTTin mcrMQTTin_t;
class mcrMQTTin : public Task {
public:
  mcrMQTTin(Ringbuffer *rb);

  void registerCmdQueue(cmdQueue_t &cmd_q);
  void run(void *data);

private:
  Ringbuffer *_rb;

  struct mg_mgr _mgr;
  struct mg_connection *_connection = nullptr;
  time_t _lastLoop;
  uint16_t _msg_id = 0;
  std::vector<cmdQueue_t> _cmd_queues;

  // const char *_user = CONFIG_MCR_MQTT_USER;
  // const char *_pass = CONFIG_MCR_MQTT_PASSWD;
  const char *_rpt_feed = "prod/mcr/f/report";
  // const char *_cmd_feed = "prod/mcr/f/command";

  void handleMsg(char *json);
};

#endif // mqtt_in_h
