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
#include "external/mongoose.h"
#include "misc/mcr_types.hpp"
#include "misc/version.hpp"
#include "net/mcr_net.hpp"
#include "protocols/mqtt.hpp"
#include "protocols/mqtt_in.hpp"
#include "readings/readings.hpp"

static mcrMQTT *__singleton = nullptr;

// prototype for the event handler
static void _ev_handler(struct mg_connection *nc, int ev, void *);

// SINGLETON!  use instance() for object access
mcrMQTT_t *mcrMQTT::instance() {
  if (__singleton == nullptr) {
    __singleton = new mcrMQTT();
  }

  return __singleton;
}

// SINGLETON! constructor is private
mcrMQTT::mcrMQTT() {
  // convert the port number to a string
  std::ostringstream endpoint_ss;
  endpoint_ss << _host << ':' << _port;

  // create the endpoint URI
  _endpoint = endpoint_ss.str();

  _rb_in_lowwater = _rb_in_size * .1;
  _rb_in_highwater = _rb_in_size * .9;

  _rb_out = xRingbufferCreate(_rb_out_size, RINGBUF_TYPE_NOSPLIT);
  _rb_in = xRingbufferCreate(_rb_in_size, RINGBUF_TYPE_NOSPLIT);

  ESP_LOGI(tagEngine(), "ringb in  size=%u msgs=%d low_water=%u high_water=%u",
           _rb_in_size, (_rb_in_size / sizeof(mqttInMsg_t)), _rb_in_lowwater,
           _rb_in_highwater);
  ESP_LOGI(tagEngine(), "ringb out size=%u msgs=%d", _rb_out_size,
           (_rb_out_size / sizeof(mqttOutMsg_t)));
}

void mcrMQTT::announceStartup() {
  uint32_t batt_mv = mcr::Net::instance()->batt_mv();
  startupReading_t startup(batt_mv);

  publish(&startup);
  mcr::Net::statusLED(false);
}

void mcrMQTT::connect(int wait_ms) {

  // establish the client id
  if (_client_id.length() == 0) {
    _client_id = "esp-" + mcr::Net::macAddress();
  }

  TickType_t last_wake = xTaskGetTickCount();

  mcr::Net::waitForConnection();

  if (wait_ms > 0) {
    vTaskDelayUntil(&last_wake, pdMS_TO_TICKS(wait_ms));
  }

  _connection = mg_connect(&_mgr, _endpoint.c_str(), _ev_handler);

  if (_connection) {
    ESP_LOGI(tagEngine(), "created pending mongoose connection(%p) for %s",
             _connection, _endpoint.c_str());
  }
}

void mcrMQTT::connectionClosed() {
  ESP_LOGW(tagEngine(), "connection closed");
  _mqtt_ready = false;
  _connection = nullptr;

  connect(5 * 1000); // wait five seconds before reconnect
}

void mcrMQTT::handshake(struct mg_connection *nc) {
  struct mg_send_mqtt_handshake_opts opts;
  bzero(&opts, sizeof(opts));

  opts.user_name = _user;
  opts.password = _passwd;

  mg_set_protocol_mqtt(nc);
  mg_send_mqtt_handshake_opt(nc, _client_id.c_str(), opts);
}

void mcrMQTT::incomingMsg(struct mg_str *in_topic, struct mg_str *in_payload) {
  // allocate a new string here and deallocate it once processed through MQTTin
  std::string *topic = new std::string(in_topic->p, in_topic->len);
  std::vector<char> *data =
      new std::vector<char>(in_payload->p, (in_payload->p + in_payload->len));
  mqttInMsg_t entry;
  BaseType_t rb_rc;

  entry.topic = topic;
  entry.data = data;

  if ((_ota_start_time) && ((time(nullptr) - _ota_start_time) > 60)) {
    ESP_LOGW(tagEngine(), "detected stalled ota, spooling ftl");
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
             topic->c_str(), sizeof(mqttInMsg_t), in_payload->len);
  } else {
    ESP_LOGW(tagEngine(), "INCOMING msg(len=%u) FAILED send to ringbuff, JUMP!",
             sizeof(mqttInMsg_t));
    delete data;
    delete topic;
    esp_restart();
  }
}

void mcrMQTT::__otaFinish() {
  char **unsub = (char **)&_ota_feed; // override const to align with mongoose

  _ota_feed_msg_id = _msg_id++;
  ESP_LOGI(tagEngine(), "finish ota, unsubscribe feed=%s msg_id=%d", _ota_feed,
           _ota_feed_msg_id);
  if (_connection) {
    mg_mqtt_unsubscribe(_connection, unsub, 1, _ota_feed_msg_id);
  } else {
    ESP_LOGW(tagEngine(), "can not unsubcribe ota feed, no connection");
  }

  _mqtt_in->restorePriority();
}

void mcrMQTT::__otaPrep() {
  struct mg_mqtt_topic_expression sub = {.topic = _ota_feed, .qos = 0};

  _ota_start_time = time(nullptr);

  _ota_feed_msg_id = _msg_id++;
  ESP_LOGI(tagEngine(), "prep for ota, subscribe feed=%s msg_id=%d", sub.topic,
           _ota_feed_msg_id);
  if (_connection) {
    mg_mqtt_subscribe(_connection, &sub, 1, _ota_feed_msg_id);
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

void mcrMQTT::outboundMsg() {
  size_t len = 0;
  mqttOutMsg_t *entry = nullptr;

  entry =
      (mqttOutMsg_t *)xRingbufferReceive(_rb_out, &len, _prefer_outbound_ticks);

  while (entry) {
    int64_t start_us = esp_timer_get_time();

    if (len != sizeof(mqttOutMsg_t)) {
      ESP_LOGW(tagEngine(), "skipping ringbuffer msg of wrong length=%u", len);
      vRingbufferReturnItem(_rb_out, entry);
      break;
    }

    const std::string *json = entry->data;
    size_t json_len = entry->len;

    ESP_LOGD(tagEngine(), "send msg(len=%u), payload(len=%u)", len, json_len);
    // ESP_LOGI(tagEngine(), "json: %s", json->c_str());

    mg_mqtt_publish(_connection, _rpt_feed, _msg_id++, MG_MQTT_QOS(1),
                    json->data(), json_len);

    delete json;
    vRingbufferReturnItem(_rb_out, entry);

    int64_t publish_us = esp_timer_get_time() - start_us;
    if (publish_us > 3000) {
      ESP_LOGW(tagOutbound(), "publish msg took %0.2fms",
               ((float)publish_us / 1000.0));
    } else {
      ESP_LOGD(tagOutbound(), "publish msg took %lluus", publish_us);
    }

    entry =
        (mqttOutMsg_t *)xRingbufferReceive(_rb_out, &len, _outbound_msg_ticks);
  }
}

void mcrMQTT::publish(std::string *json) {
  BaseType_t rb_rc = false;
  mqttOutMsg_t entry;

  // setup the entry noting that the actual pointer to the string will
  // be included so be certain to deallocate when it comes out of the ringbuffer
  entry.len = json->length();
  entry.data = json;

  rb_rc = xRingbufferSend(_rb_out, (void *)&entry, sizeof(mqttOutMsg_t), 0);

  if (!rb_rc) {
    ESP_LOGW(tagEngine(),
             "PUBLISH msg(len=%u) FAILED to ringbuffer, msg dropped",
             entry.len);
    delete json;
    esp_restart();
  }
}

void mcrMQTT::run(void *data) {
  struct mg_mgr_init_opts opts = {};

  _mqtt_in = new mcrMQTTin(_rb_in);
  ESP_LOGI(tagEngine(), "started, created mcrMQTTin task %p", (void *)_mqtt_in);
  _mqtt_in->start();

  // wait for network to be ready to ensure dns resolver is available
  ESP_LOGI(tagEngine(), "waiting for network...");
  mcr::Net::waitForReady();

  // mongoose uses it's own dns resolver so set the namserver from dhcp
  opts.nameserver = mcr::Net::instance()->dnsIP();

  mg_mgr_init_opt(&_mgr, NULL, opts);

  connect();

  bool startup_announced = false;

  for (;;) {
    // send the startup announcement once the time is available.
    // this solves a race condition when mqtt connection and subscription
    // to the commend feed completes before the time is set and avoids
    // mcp receiving the announced statup time as epoch
    if ((startup_announced == false) && (mcr::Net::isTimeSet())) {
      announceStartup();
      startup_announced = true;
    }

    // to alternate between prioritizing send and recv:
    //  1. wait here (recv)
    //  2. wait in outboundMsg (send)
    mg_mgr_poll(&_mgr, _inbound_msg_ms);

    if (isReady()) {
      outboundMsg();
    }
  }
}

void mcrMQTT::subACK(struct mg_mqtt_message *msg) {
  ESP_LOGI(tagEngine(), "suback msg_id=%d", msg->message_id);

  if (msg->message_id == _cmd_feed_msg_id) {
    ESP_LOGI(tagEngine(), "subscribed to CMD feed");
    _mqtt_ready = true;
    mcr::Net::setTransportReady();
    // announcing startup here creates a race conditino the results
    // in occasionally using epach as the startup time
    // announceStartup();
  } else if (msg->message_id == _ota_feed_msg_id) {
    ESP_LOGI(tagEngine(), "subscribed to OTA feed");
    _ota_subscribed = true;
  } else {
    ESP_LOGW(tagEngine(), "suback did not match known subscription requests");
  }
}

void mcrMQTT::subscribeCommandFeed(struct mg_connection *nc) {
  struct mg_mqtt_topic_expression sub = {.topic = _cmd_feed, .qos = 0};

  _cmd_feed_msg_id = _msg_id++;
  ESP_LOGI(tagEngine(), "subscribe feed=%s msg_id=%d", sub.topic,
           _cmd_feed_msg_id);
  mg_mqtt_subscribe(nc, &sub, 1, _cmd_feed_msg_id);
}

static void _ev_handler(struct mg_connection *nc, int ev, void *p) {
  struct mg_mqtt_message *msg = (struct mg_mqtt_message *)p;

  switch (ev) {
  case MG_EV_CONNECT: {
    int *status = (int *)p;
    ESP_LOGI(mcrMQTT::tagEngine(), "CONNECT msg=%p err_code=%d err_str=%s",
             (void *)msg, *status, strerror(*status));

    mcrMQTT::instance()->handshake(nc);
    break;
  }

  case MG_EV_MQTT_CONNACK:
    if (msg->connack_ret_code != MG_EV_MQTT_CONNACK_ACCEPTED) {
      ESP_LOGW(mcrMQTT::tagEngine(), "mqtt connection error: %d",
               msg->connack_ret_code);
      return;
    }

    ESP_LOGD(mcrMQTT::tagEngine(), "MG_EV_MQTT_CONNACK rc=%d",
             msg->connack_ret_code);
    mcrMQTT::instance()->subscribeCommandFeed(nc);

    break;

  case MG_EV_MQTT_SUBACK:
    mcrMQTT::instance()->subACK(msg);

    break;

  case MG_EV_MQTT_SUBSCRIBE:
    ESP_LOGI(mcrMQTT::tagEngine(), "subscribe event, payload=%s",
             msg->payload.p);
    break;

  case MG_EV_MQTT_UNSUBACK:
    ESP_LOGI(mcrMQTT::tagEngine(), "unsub ack");
    break;

  case MG_EV_MQTT_PUBLISH:
    mcrMQTT::instance()->incomingMsg(&(msg->topic), &(msg->payload));
    break;

  case MG_EV_MQTT_PINGRESP:
    ESP_LOGD(mcrMQTT::tagEngine(), "ping response");
    break;

  case MG_EV_CLOSE:
    mcrMQTT::instance()->connectionClosed();
    break;

  case MG_EV_POLL:
  case MG_EV_RECV:
  case MG_EV_SEND:
  case MG_EV_MQTT_PUBACK:
    // events to ignore
    break;

  default:
    ESP_LOGW(mcrMQTT::tagEngine(), "unhandled event 0x%04x", ev);
    break;
  }
}
