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
#include <cstring>

#include <FreeRTOS.h>
#include <System.h>
#include <Task.h>
#include <WiFi.h>
#include <WiFiEventHandler.h>
#include <esp_log.h>
#include <freertos/event_groups.h>

// MCR specific includes
#include "mongoose.h"
#include "mqtt.hpp"
#include "mqtt_in.hpp"
#include "readings.hpp"
#include "util.hpp"
#include "version.hpp"

// static uint32_t cmd_callback_count = 0;
// static cmdCallback_t cmd_callback[10] = {nullptr};
static char tTAG[] = "mcrMQTT";
static bool debugMode = false;

static mcrMQTT *__singleton = nullptr;

static struct mg_mqtt_topic_expression s_topic_expr = {NULL, 0};

static void ev_handler(struct mg_connection *nc, int ev, void *p) {
  struct mg_mqtt_message *msg = (struct mg_mqtt_message *)p;
  (void)nc;

  switch (ev) {
  case MG_EV_CONNECT: {
    int *status = (int *)p;
    ESP_LOGI(tTAG, "CONNECT msg=%p err_code=%d err_str=%s", (void *)msg,
             *status, strerror(*status));
    struct mg_send_mqtt_handshake_opts opts;
    bzero(&opts, sizeof(opts));

    opts.user_name = "mqtt";
    opts.password = "mqtt";

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

    s_topic_expr.topic = "prod/mcr/f/command";

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

mcrMQTT::mcrMQTT(EventGroupHandle_t evg, int bit) : Task(tTAG, 5 * 1024, 15) {
  _ev_group = evg;
  _wait_bit = bit;
  _lastLoop = 0;

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

mcrMQTT_t *mcrMQTT::instance() { return __singleton; }

void mcrMQTT::publish(Reading_t *reading) {
  char *json = reading->json();

  publish(json);
}

void mcrMQTT::registerCmdQueue(cmdQueue_t &cmd_q) {
  _mqtt_in->registerCmdQueue(cmd_q);
}

void mcrMQTT::run(void *data) {
  struct mg_mgr_init_opts opts;
  _mqtt_in = new mcrMQTTin(_rb_in);
  ESP_LOGI(tTAG, "started, created mcrMQTTin task %p", (void *)_mqtt_in);
  _mqtt_in->start();

  ESP_LOGD(tTAG, "waiting on event_group=%p for bits=0x%x", (void *)_ev_group,
           _wait_bit);
  xEventGroupWaitBits(_ev_group, _wait_bit, false, true, portMAX_DELAY);
  ESP_LOGD(tTAG, "event_group wait complete, starting mongoose");

  bzero(&opts, sizeof(opts));
  opts.nameserver = (const char *)"192.168.2.4";

  mg_mgr_init_opt(&_mgr, NULL, opts);

  _connection = mg_connect(&_mgr, _address, ev_handler);

  if (_connection) {
    ESP_LOGI(tTAG, "mongoose connection created %p", (void *)_connection);
  }

  for (;;) {
    mg_mgr_poll(&_mgr, 1000);

    // only try to send outbound messages if mqtt is ready
    EventBits_t check = xEventGroupWaitBits(_ev_group, MQTT_READY_BIT,
                                            pdFALSE, // don't clear
                                            pdTRUE,  // wait for all bits
                                            0);

    if ((check & MQTT_READY_BIT) == MQTT_READY_BIT) {
      outboundMsg();
    }
  }
}

// internal private publish that takes the json and sends via MQTT

void mcrMQTT::incomingMsg(const char *json, const size_t len) {
  const size_t buff_len = sizeof(size_t) + len + 1;
  char *buff = new char[buff_len];
  bool rb_rc = false;

  bzero(buff, buff_len); // this ensures the json string is null term'ed

  // create the composite entry to send to the ringbuffer
  //  1. the length of the message
  //  2. the message itself
  *((size_t *)buff) = len;
  // memcpy(buff, &len, sizeof(size_t));
  memcpy(buff + sizeof(size_t), json, len);
  rb_rc = _rb_in->send(buff, buff_len, pdMS_TO_TICKS(3));

  if (rb_rc) {
    ESP_LOGD(tTAG, "sent INCOMING to ringbuffer msg (json_len=%u,buff_len=%u)",
             len, buff_len);
  } else {
    ESP_LOGW(tTAG, "failed sending INCOMING msg to ringbuffer len=%u",
             buff_len);
  }

  delete buff;
}

void mcrMQTT::outboundMsg() {
  size_t msg_len = 0;
  size_t json_len = 0;
  char *json = nullptr;
  char *msg = nullptr;

  msg = (char *)_rb_out->receive(&msg_len, 0);
  while (msg) {
    json_len = *((size_t *)msg);
    // memcpy((size_t *)&json_len, msg, sizeof(size_t));
    json = msg + sizeof(size_t);

    ESP_LOGD(tTAG, "send msg(len=%u), payload(len=%u)", msg_len, json_len);

    mg_mqtt_publish(_connection, _rpt_feed, _msg_id++, MG_MQTT_QOS(0), json,
                    (json_len - 1)); // don't send string terminator!

    _rb_out->returnItem(msg);

    msg = (char *)_rb_out->receive(&msg_len, 0);
  }
}

void mcrMQTT::publish(char *json) {
  const size_t len = strlen(json) + 1; // null terminator
  const size_t buff_len = sizeof(size_t) + len + 1;
  char *buff = new char[buff_len];
  bool rb_rc = false;

  memcpy(buff, &len, sizeof(size_t));
  memcpy(buff + sizeof(size_t), json, len);

  rb_rc = _rb_out->send((void *)buff, buff_len, 0);

  if (!rb_rc) {
    ESP_LOGW(tTAG, "failed send PUBLISH msg to ringbuffer len=%u", buff_len);
  }

  delete buff;
}

char *mcrMQTT::clientId() {
  const size_t len = 16;
  static char client_id[len + 1] = {0x00};

  if (client_id[0] == 0x00) {
    snprintf(client_id, len, "fm0-%s", mcrUtil::macAddress());
  }

  return client_id;
}

void mcrMQTT::setReady() { xEventGroupSetBits(_ev_group, MQTT_READY_BIT); }
void mcrMQTT::setDebug(bool mode) { debugMode = mode; }
void mcrMQTT::debugOn() { setDebug(true); }
void mcrMQTT::debugOff() { setDebug(false); }
