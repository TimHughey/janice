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

  void handshake(struct mg_connection *nc);
  void incomingMsg(struct mg_str *topic, struct mg_str *payload);
  static void otaFinish() { instance()->__otaFinish(); };
  static void otaPrep() { instance()->__otaPrep(); };
  void publish(Reading_t *reading);
  void run(void *data);
  void setSubscribedOTA() { _ota_subscribed = true; };
  void subACK(struct mg_mqtt_message *msg);
  void subscribeCommandFeed(struct mg_connection *nc);
  bool isReady() { return _mqtt_ready; };

  void start(void *task_data = nullptr) {
    if (_task.handle != nullptr) {
      ESP_LOGW(tagEngine(), "there may already be a task running %p",
               (void *)_task.handle);
    }

    // this (object) is passed as the data to the task creation and is
    // used by the static runEngine method to call the run method
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

  static const char *tagEngine() { return "mcrMQTT"; };
  static const char *tagOutbound() { return "mcrMQTT outboundMsg"; };

private:
  mcrMQTT(); // singleton, constructor is private

  std::string _client_id;
  std::string _endpoint;
  mcrTask_t _task = {.handle = nullptr,
                     .data = nullptr,
                     .lastWake = 0,
                     .priority = CONFIG_MCR_MQTT_TASK_PRIORITY,
                     .stackSize = (5 * 1024)};

  struct mg_mgr _mgr;
  struct mg_connection *_connection = nullptr;
  uint16_t _msg_id = 0;
  bool _mqtt_ready = false;
  bool _prefer_outbound_ticks = 0;

  // mg_mgr uses LWIP and the timeout is specified in ms
  int _inbound_msg_ms = CONFIG_MCR_MQTT_INBOUND_MSG_WAIT_MS;
  TickType_t _inbound_rb_wait_ticks =
      pdMS_TO_TICKS(CONFIG_MCR_MQTT_INBOUND_RB_WAIT_MS);
  TickType_t _outbound_msg_ticks =
      pdMS_TO_TICKS(CONFIG_MCR_MQTT_OUTBOUND_MSG_WAIT_MS);

  const size_t _rb_out_size =
      (sizeof(mqttOutMsg_t) * CONFIG_MCR_MQTT_RINGBUFFER_PENDING_MSGS);
  const size_t _rb_in_size =
      (sizeof(mqttInMsg_t) * CONFIG_MCR_MQTT_RINGBUFFER_PENDING_MSGS);
  size_t _rb_in_lowwater = 0;
  size_t _rb_in_highwater = 0;
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
  time_t _ota_start_time = 0;

  void announceStartup();
  void __otaFinish();
  void __otaPrep();
  void outboundMsg();

  void publish(std::string *json);

  // Task implementation
  static void runEngine(void *task_instance) {
    mcrMQTT_t *task = (mcrMQTT_t *)task_instance;
    task->run(task->_task.data);
  }
};

#endif // mcp_mqtt_h
