/*
    mcpr_mqtt.h - Master Control Remote MQTT
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

#ifndef mcr_mqtt_h
#define mcr_mqtt_h

#include <cstdlib>
#include <cstring>

#include <FreeRTOS.h>
#include <System.h>
#include <Task.h>
#include <WiFi.h>
#include <WiFiEventHandler.h>
#include <esp_log.h>
#include <freertos/event_groups.h>

#include "mongoose.h"
#include "mqtt_in.hpp"
#include "readings.hpp"
#include "sdkconfig.h"

#define mcr_mqtt_version_1 1

// Set the version of MCP Remote
#ifndef mcr_mqtt_version
#define mcr_mqtt_version mcr_mqtt_version_1
#endif

#define MQTT_READY_BIT BIT7

typedef class mcrMQTT mcrMQTT_t;
class mcrMQTT : public Task {
private:
  const char *_address = "jophiel.wisslanding.com:1883";

  EventGroupHandle_t _ev_group;
  int _wait_bit;

  struct mg_mgr _mgr;
  struct mg_connection *_connection = nullptr;
  time_t _lastLoop;
  uint16_t _msg_id = 0;

  const size_t _rb_size = (sizeof(size_t) + 512) * 20;
  Ringbuffer *_rb_out = nullptr;
  Ringbuffer *_rb_in = nullptr;
  mcrMQTTin *_mqtt_in = nullptr;

  // const char *_user = CONFIG_MCR_MQTT_USER;
  // const char *_pass = CONFIG_MCR_MQTT_PASSWD;
  const char *_rpt_feed = "prod/mcr/f/report";
  const char *_cmd_feed = "prod/mcr/f/command";

  // const int _msg_version = 1;

public:
  mcrMQTT(EventGroupHandle_t evg, int bit);
  static mcrMQTT_t *instance();

  void registerCmdQueue(cmdQueue_t &cmd_q);
  void run(void *data);

  void announceStartup();
  void incomingMsg(const char *json, const size_t len);
  void publish(Reading_t *reading);

  void setReady();

  static char *clientId();

  // static void registerCmdCallback(cmdCallback_t cmdCallback);

private:
  void outboundMsg();
  void publish(char *json);

  // callback invoked when a message arrives on any subscribed feed
  // static void incomingMsg(char *topic, byte *payload, unsigned int length);

  // command message helpers
  // static remoteCommand_t parseCmd(JsonObject &root);
  // static bool handleTimeSyncCmd(JsonObject &root);
  // static bool handleSetSwitchCmd(JsonObject &root);

  static void setDebug(bool mode);
  static void debugOn();
  static void debugOff();
};

#endif // mcp_mqtt_h
