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

#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/ringbuf.h>
#include <freertos/task.h>
#include <sdkconfig.h>

#include "external/mongoose.h"
#include "protocols/mqtt_in.hpp"
#include "readings/readings.hpp"

typedef struct {
  size_t len = 0;
  std::string *data = nullptr;
} mqttOutMsg_t;

typedef class mcrMQTT mcrMQTT_t;
class mcrMQTT {
public:
  static mcrMQTT_t *instance(); // singleton, use instance() for object

  void connect(int wait_ms = 0);
  void connectionClosed();
  void finishOTA();
  void handshake(struct mg_connection *nc);
  void incomingMsg(struct mg_str *topic, struct mg_str *payload);
  void prepForOTA();
  void publish(Reading_t *reading);
  void registerCmdQueue(cmdQueue_t &cmd_q);
  void run(void *data);
  void setSubscribedOTA() { _ota_subscribed = true; };
  void subACK(struct mg_mqtt_message *msg);
  void subscribeCommandFeed(struct mg_connection *nc);
  bool isReady() { return _mqtt_ready; };

  void start(void *task_data = nullptr) {
    if (_mqtt_task != nullptr) {
      ESP_LOGW(tagEngine(), "there may already be a task running %p",
               (void *)_mqtt_task);
    }

    // this (object) is passed as the data to the task creation and is
    // used by the static runEngine method to call the run method
    ::xTaskCreate(&runEngine, tagEngine(), 5 * 1024, this, 15, &_mqtt_task);
  }

  void stop() {
    if (_mqtt_task == nullptr) {
      return;
    }

    xTaskHandle temp = _mqtt_task;
    _mqtt_task = nullptr;
    ::vTaskDelete(temp);
  }

  static const char *tagEngine() { return "mcrMQTT"; };
  static const char *tagOutbound() { return "mcrMQTT outboundMsg"; };

private:
  mcrMQTT(); // singleton, constructor is private

  std::string _client_id;
  std::string _endpoint;
  xTaskHandle _mqtt_task = nullptr;
  void *_task_data = nullptr;

  struct mg_mgr _mgr;
  struct mg_connection *_connection = nullptr;
  uint16_t _msg_id = 0;
  bool _mqtt_ready = false;

  // mg_mgr uses LWIP and the timeout is specified in ms
  int _inbound_msg_ms = CONFIG_MCR_MQTT_INBOUND_MSG_WAIT_MS;
  TickType_t _outbound_msg_ticks =
      pdMS_TO_TICKS(CONFIG_MCR_MQTT_OUTBOUND_MSG_WAIT_MS);

  const size_t _rb_out_size =
      (sizeof(mqttOutMsg_t) * CONFIG_MCR_MQTT_RINGBUFFER_PENDING_MSGS);
  const size_t _rb_in_size =
      (sizeof(mqttInMsg_t) * CONFIG_MCR_MQTT_RINGBUFFER_PENDING_MSGS);
  RingbufHandle_t _rb_out = nullptr;
  RingbufHandle_t _rb_in = nullptr;

  mcrMQTTin_t *_mqtt_in = nullptr;

  const char *_dns_server = CONFIG_MCR_DNS_SERVER;
  const std::string _host = CONFIG_MCR_MQTT_HOST;
  const int _port = CONFIG_MCR_MQTT_PORT;
  const char *_user = CONFIG_MCR_MQTT_USER;
  const char *_passwd = CONFIG_MCR_MQTT_PASSWD;
  const char *_rpt_feed = CONFIG_MCR_MQTT_RPT_FEED;

  const char *_cmd_feed = CONFIG_MCR_MQTT_CMD_FEED;
  uint16_t _cmd_feed_msg_id = 0;

  const char *_ota_feed = CONFIG_MCR_MQTT_OTA_FEED;
  uint16_t _ota_feed_msg_id = 0;
  bool _ota_subscribed = false;

  void announceStartup();
  void outboundMsg();
  void publish(std::string *json);

  // Task implementation
  static void runEngine(void *task_instance) {
    mcrMQTT_t *task = (mcrMQTT_t *)task_instance;
    task->run(task->_task_data);
  }
};

#endif // mcp_mqtt_h
