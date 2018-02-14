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

#include <cstdlib>
#include <sstream>
#include <string>

#include <FreeRTOS.h>
#include <System.h>
#include <Task.h>
#include <WiFi.h>
#include <WiFiEventHandler.h>
#include <esp_log.h>
#include <freertos/event_groups.h>

// MCR specific includes
#include "external/mongoose.h"
#include "misc/util.hpp"
#include "misc/version.hpp"
#include "net/mcr_net.hpp"
#include "protocols/mqtt.hpp"
#include "protocols/mqtt_in.hpp"
#include "readings/readings.hpp"

static char tTAG[] = "mcrMQTT";
static char outboundTAG[] = "mcrMQTT outboundMsg";

static mcrMQTT *__singleton = nullptr;

// prototype for the event handler
static void _ev_handler(struct mg_connection *nc, int ev, void *);

static struct mg_mqtt_topic_expression s_topic_expr = {NULL, 0};

mcrMQTT::mcrMQTT() : Task(tTAG, 5 * 1024, 15) {
  // convert the port number to a string
  std::ostringstream endpoint_ss;
  endpoint_ss << _host << ':' << _port;

  // create the endpoint URI
  _endpoint = endpoint_ss.str();

  _rb_out = new Ringbuffer(_rb_size);
  _rb_in = new Ringbuffer(_rb_size);

  ESP_LOGI(tTAG, "created ringbuffers size=%u in=%p out=%p", _rb_size, _rb_out,
           _rb_in);

  __singleton = this;
}

void mcrMQTT::announceStartup() {
  startupReading_t reading(time(nullptr));

  publish(&reading);
}

void mcrMQTT::connect(int wait_ms) {
  TickType_t last_wake = xTaskGetTickCount();

  // struct mg_mgr_init_opts opts;
  //
  // bzero(&opts, sizeof(opts));
  // opts.nameserver = _dns_server;
  //
  // mg_mgr_init_opt(&_mgr, NULL, opts);

  if (wait_ms > 0) {
    vTaskDelayUntil(&last_wake, pdMS_TO_TICKS(wait_ms));
  }

  _connection = mg_connect(&_mgr, _endpoint.c_str(), _ev_handler);

  if (_connection) {
    ESP_LOGI(tTAG, "mongoose connection created to endpoint %s (%p)",
             _endpoint.c_str(), (void *)_connection);
  }
}

const char *mcrMQTT::clientId() {
  static std::string client_id;

  if (client_id.length() == 0) {
    client_id = "esp-";
    client_id += mcrUtil::macAddress();
  }

  return client_id.c_str();
}

void mcrMQTT::incomingMsg(const char *data, const size_t len) {
  // allocate a new string here and deallocate it once processed through MQTTin
  std::string *json = new std::string((const char *)data, len);
  bool rb_rc = false;

  rb_rc = _rb_in->send(&json, sizeof(json), pdMS_TO_TICKS(100));

  if (rb_rc) {
    ESP_LOGD(tTAG,
             "INCOMING msg sent to ringbuffer (ptr=%p,len=%u,json_len=%u)",
             (void *)json, sizeof(json), len);
  } else {
    ESP_LOGW(tTAG,
             "INCOMING msg(len=%u) FAILED send to ringbuffer, msg dropped",
             sizeof(json));
    delete json;
  }
}

mcrMQTT_t *mcrMQTT::instance() { return __singleton; }

void mcrMQTT::outboundMsg() {
  size_t len = 0;
  mqttRingbufferEntry_t *entry = nullptr;

  entry = (mqttRingbufferEntry_t *)_rb_out->receive(&len, 0);

  while (entry) {
    int64_t start_us = esp_timer_get_time();

    if (len != sizeof(mqttRingbufferEntry_t)) {
      ESP_LOGW(tTAG, "skipping ringbuffer entry of wrong length=%u", len);
      _rb_out->returnItem(entry);
      break;
    }

    const std::string *json = entry->data;
    size_t json_len = entry->len;

    ESP_LOGD(tTAG, "send msg(len=%u), payload(len=%u)", len, json_len);

    mg_mqtt_publish(_connection, _rpt_feed, _msg_id++, MG_MQTT_QOS(0),
                    json->data(), json_len);

    delete json;
    _rb_out->returnItem(entry);

    int64_t publish_us = esp_timer_get_time() - start_us;
    if (publish_us > 1500) {
      ESP_LOGW(outboundTAG, "publish msg took %0.2fms",
               ((float)publish_us / 1000.0));
    } else {
      ESP_LOGD(outboundTAG, "publish msg took %lluus", publish_us);
    }

    entry =
        (mqttRingbufferEntry_t *)_rb_out->receive(&len, _outbound_msg_ticks);
  }
}

void mcrMQTT::publish(Reading_t *reading) {
  std::string *json = reading->json();

  publish(json);
}

void mcrMQTT::publish(std::string *json) {
  bool rb_rc = false;
  mqttRingbufferEntry_t entry;

  // setup the entry noting that the actual pointer to the string will
  // be included so be certain to deallocate when it comes out of the ringbuffer
  entry.len = json->length();
  entry.data = json;

  rb_rc = _rb_out->send((void *)&entry, sizeof(mqttRingbufferEntry_t), 0);

  if (!rb_rc) {
    ESP_LOGW(tTAG, "PUBLISH msg(len=%u) FAILED to ringbuffer, msg dropped",
             entry.len);
    delete json;
  }
}

void mcrMQTT::registerCmdQueue(cmdQueue_t &cmd_q) {
  _mqtt_in->registerCmdQueue(cmd_q);
}

void mcrMQTT::run(void *data) {
  struct mg_mgr_init_opts opts;

  _mqtt_in = new mcrMQTTin(_rb_in);
  ESP_LOGI(tTAG, "started, created mcrMQTTin task %p", (void *)_mqtt_in);
  _mqtt_in->start();

  ESP_LOGD(tTAG, "waiting for network connection...");
  mcrNetwork::waitForConnection();

  bzero(&opts, sizeof(opts));
  opts.nameserver = _dns_server;

  mg_mgr_init_opt(&_mgr, NULL, opts);

  connect();

  ESP_LOGD(tTAG, "waiting for time to be set...");
  mcrNetwork::waitForTimeset();

  for (;;) {
    // we wait here AND we wait in outboundMsg -- this alternates between
    // prioritizing inbound and outbound messages
    mg_mgr_poll(&_mgr, _inbound_msg_ms);

    if (isReady()) {
      outboundMsg();
    }
  }
}

static void _ev_handler(struct mg_connection *nc, int ev, void *p) {
  struct mg_mqtt_message *msg = (struct mg_mqtt_message *)p;
  (void)nc;

  switch (ev) {
  case MG_EV_CONNECT: {
    int *status = (int *)p;
    ESP_LOGI(tTAG, "CONNECT msg=%p err_code=%d err_str=%s", (void *)msg,
             *status, strerror(*status));
    struct mg_send_mqtt_handshake_opts opts;
    bzero(&opts, sizeof(opts));

    opts.user_name = __singleton->user();
    opts.password = __singleton->passwd();

    mg_set_protocol_mqtt(nc);
    mg_send_mqtt_handshake_opt(nc, mcrMQTT::clientId(), opts);
    break;
  }
  case MG_EV_MQTT_CONNACK:
    if (msg->connack_ret_code != MG_EV_MQTT_CONNACK_ACCEPTED) {
      ESP_LOGW(tTAG, "got mqtt connection error: %d", msg->connack_ret_code);
      return;
    }

    ESP_LOGI(tTAG, "MG_EV_MQTT_CONNACK rc=%d", msg->connack_ret_code);

    s_topic_expr.topic = __singleton->cmdFeed();

    ESP_LOGI(tTAG, "subscribing to [%s]", s_topic_expr.topic);
    mg_mqtt_subscribe(nc, &s_topic_expr, 1, 42);
    break;

  case MG_EV_MQTT_SUBACK:
    ESP_LOGI(tTAG, "subscription ack'ed");
    __singleton->setReady();
    __singleton->announceStartup();

    break;

  case MG_EV_MQTT_SUBSCRIBE:
    ESP_LOGI(tTAG, "subscribe event, payload=%s", msg->payload.p);
    break;

  case MG_EV_MQTT_PUBLISH:
    mcrMQTT_t *instance;

    instance = mcrMQTT::instance();
    instance->incomingMsg(msg->payload.p, msg->payload.len);
    break;

  case MG_EV_MQTT_PINGRESP:
    ESP_LOGD(tTAG, "ping response");
    break;

  case MG_EV_CLOSE:
    ESP_LOGW(tTAG, "connection closed");
    __singleton->setNotReady();
    __singleton->connect(5 * 1000); // wait five seconds before reconnecting
    break;

  case MG_EV_POLL:
  case MG_EV_RECV:
  case MG_EV_SEND:
    // events to ignore
    break;

  default:
    ESP_LOGW(tTAG, "unhandled event %d", ev);
    break;
  }
}
