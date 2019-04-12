/*
     mcpr_mqtt.cpp - Master Control Remote MQTT
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

#include <array>
#include <cstdlib>
#include <sstream>
#include <string>

#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/task.h>

// MCR specific includes
#include "misc/mcr_types.hpp"
#include "misc/version.hpp"
#include "net/mcr_net.hpp"
#include "protocols/mqtt.hpp"
#include "protocols/mqtt_in.hpp"
#include "readings/readings.hpp"

static mcrMQTT *__singleton = nullptr;

// prototype for the event handler
static esp_err_t _event_handler(esp_mqtt_event_handle_t event);

// SINGLETON!  use instance() for object access
mcrMQTT_t *mcrMQTT::instance() {
  if (__singleton == nullptr) {
    __singleton = new mcrMQTT();
  }

  return __singleton;
}

// SINGLETON! constructor is private
mcrMQTT::mcrMQTT() {

  // configure logging for the mqtt client library
  esp_log_level_set("MQTT_CLIENT", ESP_LOG_VERBOSE);
  esp_log_level_set("TRANSPORT_TCP", ESP_LOG_VERBOSE);
  esp_log_level_set("TRANSPORT", ESP_LOG_VERBOSE);
  esp_log_level_set("OUTBOX", ESP_LOG_VERBOSE);

  _rb_in_lowwater = _rb_in_size * .1;
  _rb_in_highwater = _rb_in_size * .9;

  _rb_in = xRingbufferCreate(_rb_in_size, RINGBUF_TYPE_NOSPLIT);

  ESP_LOGI(tagEngine(), "ringb <- size=%u msgs=%d low_water=%u high_water=%u",
           _rb_in_size, (_rb_in_size / sizeof(mqttInMsg_t)), _rb_in_lowwater,
           _rb_in_highwater);
}

void mcrMQTT::announceStartup() {
  uint32_t batt_mv = mcr::Net::instance()->batt_mv();
  startupReading_t startup(batt_mv);

  publish(&startup);
  mcr::Net::statusLED(false);
}

void mcrMQTT::connect(int wait_ms) {
  esp_err_t esp_rc;

  TickType_t last_wake = xTaskGetTickCount();

  mcr::Net::waitForConnection();

  if (wait_ms > 0) {
    vTaskDelayUntil(&last_wake, pdMS_TO_TICKS(wait_ms));
  }

  esp_rc = esp_mqtt_client_start(_client);
  ESP_LOGI(tagEngine(), "[%s] started mqtt client(%p)", esp_err_to_name(esp_rc),
           _client);

  if (_client) {
    ESP_LOGI(tagEngine(), "mqtt client(%p) created to endpoint %s", &_client,
             _mqtt_config.uri);
  }
}

void mcrMQTT::incomingMsg(esp_mqtt_event_handle_t event) {
  // allocate a new string here and deallocate it once processed through MQTTin
  std::string *topic = new std::string(event->topic);

  // copy the incoming data to a vector
  // first argument:  pointer to data
  // second argument: pointer to end of data
  // these arguments define the number of bytes of data to copy to the vector
  std::vector<char> *data =
      new std::vector<char>(event->data, (event->data + event->data_len));
  mqttInMsg_t entry;
  BaseType_t rb_rc;

  entry.topic = topic;
  entry.data = data;

  if ((_ota_start_time) && ((time(nullptr) - _ota_start_time) > 60)) {
    ESP_LOGW(tagEngine(), "detected stalled ota, spooling ftl...");
    vTaskDelay(2000);
    ESP_LOGW(tagEngine(), "JUMP!");
    esp_restart();
  }

  rb_rc = xRingbufferSend(_rb_in, &entry, sizeof(mqttInMsg_t),
                          _inbound_rb_wait_ticks);

  size_t avail_bytes = xRingbufferGetCurFreeSize(_rb_in);

  if ((!_prefer_outbound_ticks) && (avail_bytes < _rb_in_lowwater)) {
    ESP_LOGW(tagEngine(),
             "--> ringbuff overload %04u,%04u,%u (avail,low,total)",
             avail_bytes, _rb_in_lowwater, _rb_in_size);

    _prefer_outbound_ticks = pdMS_TO_TICKS(200);
  }

  if (_prefer_outbound_ticks && (avail_bytes > _rb_in_highwater)) {
    ESP_LOGI(tagEngine(),
             "--> ringbuff drained  %04u,%04u,%u (avail,high,total)",
             avail_bytes, _rb_in_highwater, _rb_in_size);
    vTaskPrioritySet(_task.handle, _task.priority);
    _prefer_outbound_ticks = 0;
  }

  if (rb_rc) {
    ESP_LOGD(tagEngine(),
             "INCOMING msg SENT to ringbuff (topic=%s,len=%u,json_len=%u)",
             topic->c_str(), sizeof(mqttInMsg_t), event->data_len);
  } else {
    ESP_LOGW(tagEngine(), "INCOMING msg(len=%u) FAILED send to ringbuff, JUMP!",
             sizeof(mqttInMsg_t));
    delete data;
    delete topic;
    esp_restart();
  }
}

void mcrMQTT::__otaFinish() {
  ESP_LOGI(tagEngine(), "finish ota, unsubscribe %s", _ota_feed);

  if (_client) {
    esp_mqtt_client_unsubscribe(_client, _ota_feed);
  } else {
    ESP_LOGW(tagEngine(), "can not unsubcribe ota feed, no connection");
  }

  _mqtt_in->restorePriority();
}

void mcrMQTT::__otaPrep() {
  _ota_start_time = time(nullptr);

  ESP_LOGI(tagEngine(), "prep for ota, subscribe %s", _ota_feed);

  if (_client) {
    esp_mqtt_client_subscribe(_client, _ota_feed, 0);
  } else {
    ESP_LOGW(tagEngine(), "can not prep for ota, no connection");
  }

  ESP_LOGI(tagEngine(), "increasing mcrMQTTin task priority");
  _mqtt_in->changePriority(_task.priority);
}

void mcrMQTT::publish(Reading_t *reading) {
  std::string *json = reading->json();

  publish(json);
}

void mcrMQTT::publish(std::string *json) {
  int msg_id;
  int publish_warn_ms = 19999;
  int64_t start_us = esp_timer_get_time();

  msg_id = esp_mqtt_client_publish(_client, _rpt_feed, json->data(),
                                   json->length(), 1, 0);

  int64_t publish_us = esp_timer_get_time() - start_us;
  if (publish_us > publish_warn_ms) {
    ESP_LOGW(tagEngine(), "publish took %0.2fms [msg_id=%d]",
             ((float)publish_us / 1000.0), msg_id);
  } else {
    ESP_LOGD(tagEngine(), "publish took %lluus [msg_id=%d]", publish_us,
             msg_id);
  }

  // be certain to free the json (it was allocated by the caller)
  delete json;
}

void mcrMQTT::run(void *data) {

  _mqtt_in = new mcrMQTTin(_rb_in);
  ESP_LOGI(tagEngine(), "started, created mcrMQTTin task %p", (void *)_mqtt_in);
  _mqtt_in->start();

  // establish the client id
  if (_client_id.length() == 0) {
    _client_id = "esp-" + mcr::Net::macAddress();
  }

  // setup the mqtt client configuration
  // unset values will default to reasonable values
  // any items set will override values configured through menuconfig
  _mqtt_config.event_handle = _event_handler;
  _mqtt_config.uri = _uri;
  _mqtt_config.client_id = _client_id.c_str();
  _mqtt_config.username = _user;
  _mqtt_config.password = _passwd;
  _mqtt_config.task_prio = CONFIG_MCR_MQTT_TASK_PRIORITY;

  _client = esp_mqtt_client_init(&_mqtt_config);
  ESP_LOGI(tagEngine(), "client(%p) initialized", _client);

  ESP_LOGD(tagEngine(), "waiting for time to be set...");
  // mcr::Net::waitForIP(pdMS_TO_TICKS(30000));
  mcr::Net::waitForTimeset();

  connect();

  bool startup_announced = false;

  for (;;) {
    // send the startup announcement once the time is available.
    // this solves a race condition when mqtt connection and subscription
    // to the command feed completes before the time is set.
    // also avoids mcp receiving the announced startup time as epoch
    if ((startup_announced == false) && _mqtt_ready &&
        (mcr::Net::isTimeSet())) {
      announceStartup();
      startup_announced = true;
    }

    vTaskDelay(pdMS_TO_TICKS(1000));
  }
}

void mcrMQTT::subACK(esp_mqtt_event_handle_t event) {
  ESP_LOGI(tagEngine(), "suback msg_id=%d", event->msg_id);

  if (event->msg_id == _cmd_feed_msg_id) {
    ESP_LOGI(tagEngine(), "subscribed to CMD feed");
    _mqtt_ready = true;
    // do not announce startup here to avoid a race condition that results
    // in occasionally using epach as the startup time
    // announceStartup();
  } else if (event->msg_id == _ota_feed_msg_id) {
    ESP_LOGI(tagEngine(), "subscribed to OTA feed");
    _ota_subscribed = true;
  } else {
    ESP_LOGW(tagEngine(), "suback did not match known subscription requests");
  }
}

void mcrMQTT::subscribeCommandFeed() {

  _cmd_feed_msg_id = esp_mqtt_client_subscribe(_client, _cmd_feed, 0);

  ESP_LOGI(tagEngine(), "subscription request: %s [msg_id=%d]", _cmd_feed,
           _cmd_feed_msg_id);
}

static esp_err_t _event_handler(esp_mqtt_event_handle_t event) {

  switch (event->event_id) {
  case MQTT_EVENT_CONNECTED: {
    ESP_LOGI(mcrMQTT::tagEngine(), "CONNECTED event=%p client=%p",
             (void *)event, event->client);

    mcrMQTT::instance()->subscribeCommandFeed();
    break;
  }

  case MQTT_EVENT_SUBSCRIBED:
    mcrMQTT::instance()->subACK(event);
    mcr::Net::setTransportReady(true);
    break;

  case MQTT_EVENT_DATA:
    mcrMQTT::instance()->incomingMsg(event);
    break;

  case MQTT_EVENT_DISCONNECTED:
    // mcrMQTT::instance()->connectionClosed();
    mcr::Net::setTransportReady(false);
    ESP_LOGW(mcrMQTT::tagEngine(), "DISCONNECTED event=%p client=%p",
             (void *)event, event->client);
    break;

  case MQTT_EVENT_PUBLISHED:
    ESP_LOGD(mcrMQTT::tagEngine(), "PUBLISHED msg_id=%d", event->msg_id);
    break;

  case MQTT_EVENT_ERROR:
    ESP_LOGW(mcrMQTT::tagEngine(), "ERROR event=%p client=%p", (void *)event,
             event->client);
    break;

  case MQTT_EVENT_UNSUBSCRIBED:
    ESP_LOGI(mcrMQTT::tagEngine(), "UNSUBCRIBED event=%p", (void *)event);
    break;

  case MQTT_EVENT_BEFORE_CONNECT:
    mcr::Net::setTransportReady(false);
    ESP_LOGI(mcrMQTT::tagEngine(), "BEFORE_CONNECT event=%p", (void *)event);
    break;

  default:
    ESP_LOGW(mcrMQTT::tagEngine(), "unhandled event 0x%04x", event->event_id);
    break;
  }

  return ESP_OK;
}
