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
#include <string>

#include <FreeRTOS.h>
#include <System.h>
#include <Task.h>
#include <WiFi.h>
#include <WiFiEventHandler.h>
#include <esp_log.h>
#include <freertos/event_groups.h>
#include <sdkconfig.h>

#include "external/mongoose.h"
#include "protocols/mqtt_in.hpp"
#include "readings/readings.hpp"

typedef struct {
  size_t len = 0;
  std::string *data = nullptr;
} mqttRingbufferEntry_t;

typedef class mcrMQTT mcrMQTT_t;
class mcrMQTT : public Task {
public:
  mcrMQTT(EventGroupHandle_t evg, int bit);
  void announceStartup();
  static char *clientId();
  void connect();
  void incomingMsg(const char *json, const size_t len);
  static mcrMQTT_t *instance();
  void publish(Reading_t *reading);
  void registerCmdQueue(cmdQueue_t &cmd_q);
  void run(void *data);
  void setNotReady() {
    _mqtt_ready = false;
    _connection = nullptr;
  }
  void setReady() { _mqtt_ready = true; };
  bool isReady() { return _mqtt_ready; };

  // configuration info
  const char *cmdFeed() { return _cmd_feed; }
  const char *passwd() { return _passwd; }
  const char *user() { return _user; }

private:
  std::string _endpoint;

  EventGroupHandle_t _ev_group;
  int _wait_bit;

  struct mg_mgr _mgr;
  struct mg_connection *_connection = nullptr;
  uint16_t _msg_id = 0;
  bool _mqtt_ready = false;

  // mg_mgr uses LWIP and the timeout is specified in ms
  int _inbound_msg_ms = CONFIG_MCR_MQTT_INBOUND_MSG_WAIT_MS;
  TickType_t _outbound_msg_ticks =
      pdMS_TO_TICKS(CONFIG_MCR_MQTT_OUTBOUND_MSG_WAIT_MS);

  const size_t _rb_size =
      (sizeof(mqttRingbufferEntry_t) * CONFIG_MCR_MQTT_RINGBUFFER_PENDING_MSGS);
  Ringbuffer *_rb_out = nullptr;
  Ringbuffer *_rb_in = nullptr;

  mcrMQTTin_t *_mqtt_in = nullptr;

  const char *_dns_server = CONFIG_MCR_DNS_SERVER;
  const std::string _host = CONFIG_MCR_MQTT_HOST;
  const int _port = CONFIG_MCR_MQTT_PORT;
  const char *_user = CONFIG_MCR_MQTT_USER;
  const char *_passwd = CONFIG_MCR_MQTT_PASSWD;
  const char *_rpt_feed = CONFIG_MCR_MQTT_RPT_FEED;
  const char *_cmd_feed = CONFIG_MCR_MQTT_CMD_FEED;

  void outboundMsg();
  void publish(std::string *json);
};

#endif // mcp_mqtt_h
