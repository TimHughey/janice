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
#include <memory>
#include <string>

#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/task.h>

// MCR specific includes
#include "external/mongoose.h"
#include "misc/mcr_nvs.hpp"
#include "misc/mcr_types.hpp"
#include "net/mcr_net.hpp"
#include "protocols/mqtt.hpp"
#include "protocols/mqtt_in.hpp"
#include "readings/readings.hpp"

using std::unique_ptr;
namespace mcr {

static mcrMQTT *__singleton = nullptr;

// SINGLETON!  use instance() for object access
mcrMQTT_t *mcrMQTT::instance() {
  if (__singleton == nullptr) {
    __singleton = new mcrMQTT();
  }

  return __singleton;
}

// SINGLETON! constructor is private
mcrMQTT::mcrMQTT() {

  // create the endpoint URI
  const auto max_endpoint = 127;
  unique_ptr<char[]> endpoint(new char[max_endpoint + 1]);
  snprintf(endpoint.get(), max_endpoint, "%s:%d", _host.c_str(), _port);
  _endpoint = endpoint.get();

  _q_out = xQueueCreate(_q_out_len, sizeof(mqttOutMsg_t *));
  _q_in = xQueueCreate(_q_in_len, sizeof(mqttInMsg_t *));

  ESP_LOGI(tagEngine(), "queue IN  len(%d) msg_size(%u) total_size(%u)",
           _q_in_len, sizeof(mqttInMsg_t), (sizeof(mqttInMsg_t) * _q_in_len));
  ESP_LOGI(tagEngine(), "queue OUT len(%d) msg_size(%u) total_size(%u)",
           _q_out_len, sizeof(mqttOutMsg_t),
           (sizeof(mqttOutMsg_t) * _q_out_len));
}

void mcrMQTT::announceStartup() {
  uint32_t batt_mv = Net::instance()->batt_mv();
  startupReading_t startup(batt_mv);

  publish(&startup);
  Net::statusLED(false);
}

void mcrMQTT::connect(int wait_ms) {

  // establish the client id
  if (_client_id.length() == 0) {
    _client_id = "esp-" + Net::macAddress();
  }

  TickType_t last_wake = xTaskGetTickCount();

  if (wait_ms > 0) {
    vTaskDelayUntil(&last_wake, pdMS_TO_TICKS(wait_ms));
  }

  Net::waitForReady();

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
  mqttInMsg_t *entry = new mqttInMsg_t;
  auto *topic = new std::string(in_topic->p, in_topic->len);
  auto *data =
      new std::vector<char>(in_payload->p, (in_payload->p + in_payload->len));

  BaseType_t q_rc;

  entry->topic = topic;
  entry->data = data;

  // ESP_LOGI(tagEngine(), "entry(%p) topic(%p) data(%p)", entry, entry->topic,
  //          entry->data);

  // queue send takes a pointer to what should be copied to the queue
  // using the size defined when the queue was created
  q_rc = xQueueSendToBack(_q_in, (void *)&entry, _inbound_rb_wait_ticks);

  if (q_rc) {
    ESP_LOGV(tagEngine(),
             "INCOMING msg SENT to QUEUE (topic=%s,len=%u,json_len=%u)",
             topic->c_str(), sizeof(mqttInMsg_t), in_payload->len);
  } else {
    delete data;
    delete topic;

    char *msg = (char *)calloc(sizeof(char), 128);
    sprintf(msg, "RECEIVE msg FAILED (len=%u)", in_payload->len);
    ESP_LOGW(tagEngine(), "%s", msg);

    // we only commit the failure to NVS and directly call esp_restart()
    // since mcrMQTT is broken
    mcrNVS::commitMsg(tagEngine(), msg);
    free(msg);

    esp_restart();
  }
}

void mcrMQTT::__otaPrep() {
  ESP_LOGI(tagEngine(), "increasing mcrMQTTin task priority");
  _mqtt_in->changePriority(_task.priority + 1);
}

void mcrMQTT::publish(Reading_t *reading) {
  auto *json = reading->json();

  publish(json);
}

void mcrMQTT::publish(Reading_t &reading) {
  auto *json = reading.json();

  publish(json);
}

void mcrMQTT::publish(Reading_ptr_t reading) {
  auto *json = reading->json();

  publish(json);
}

void mcrMQTT::outboundMsg() {
  size_t len = 0;
  mqttOutMsg_t *entry;
  auto q_rc = pdFALSE;

  q_rc = xQueueReceive(_q_out, &entry, _outbound_msg_ticks);

  while (q_rc == pdTRUE) {
    elapsedMicros publish_elapse;

    const auto *json = entry->data;
    size_t json_len = entry->len;

    ESP_LOGV(tagEngine(), "send msg(len=%u), payload(len=%u)", len, json_len);

    mg_mqtt_publish(_connection, _rpt_feed, _msg_id++, MG_MQTT_QOS(1),
                    json->data(), json_len);

    delete json;
    delete entry;

    int64_t publish_us = publish_elapse;
    if (publish_us > 3000) {
      ESP_LOGW(tagOutbound(), "publish msg took %0.2fms",
               ((float)publish_us / 1000.0));
    } else {
      ESP_LOGV(tagOutbound(), "publish msg took %lluus", publish_us);
    }

    q_rc = xQueueReceive(_q_out, &entry, pdMS_TO_TICKS(20));
  }
}

void mcrMQTT::publish(string_t *json) {
  auto q_rc = pdFALSE;
  mqttOutMsg_t *entry = new mqttOutMsg_t;

  // setup the entry noting that the actual pointer to the string will
  // be included so be certain to deallocate when it comes out of the
  // ringbuffer
  entry->len = json->length();
  entry->data = json;

  // queue send takes a pointer to what should be copied to the queue
  // using the size defined when the queue was created
  q_rc = xQueueSendToBack(_q_out, (void *)&entry, pdMS_TO_TICKS(50));

  if (q_rc == pdFALSE) {
    delete entry;
    delete json;

    std::unique_ptr<char[]> msg(new char[128]);
    auto space_avail = uxQueueSpacesAvailable(_q_out);

    sprintf(msg.get(), "PUBLISH msg FAILED space_avail(%d)", space_avail);

    ESP_LOGW(tagEngine(), "%s", msg.get());

    // we only commit the failure to NVS and directly call esp_restart()
    // since mcrMQTT is broken
    mcrNVS::commitMsg(tagEngine(), msg.get());

    esp_restart();
  }
}

void mcrMQTT::core(void *data) {
  struct mg_mgr_init_opts opts = {};

  esp_log_level_set(tagEngine(), ESP_LOG_INFO);

  _mqtt_in = new mcrMQTTin(_q_in);
  ESP_LOGI(tagEngine(), "started, created mcrMQTTin task %p", (void *)_mqtt_in);
  _mqtt_in->start();

  // wait for network to be ready to ensure dns resolver is available
  ESP_LOGI(tagEngine(), "waiting for network...");
  Net::waitForReady();

  // mongoose uses it's own dns resolver so set the namserver from dhcp
  opts.nameserver = Net::instance()->dnsIP();

  mg_mgr_init_opt(&_mgr, NULL, opts);

  connect();

  bool startup_announced = false;

  for (;;) {
    // send the startup announcement once the time is available.
    // this solves a race condition when mqtt connection and subscription
    // to the commend feed completes before the time is set and avoids
    // mcp receiving the announced statup time as epoch
    if ((startup_announced == false) && (Net::isTimeSet())) {
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
  ESP_LOGV(tagEngine(), "suback msg_id=%d", msg->message_id);

  if (msg->message_id == _cmd_feed_msg_id) {
    ESP_LOGI(tagEngine(), "subscribed to CMD feed");
    _mqtt_ready = true;
    Net::setTransportReady();
    // NOTE: do not announce startup here.  doing so creates a race condition
    // that results in occasionally using epoch as the startup time

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

// STATIC
void mcrMQTT::_ev_handler(struct mg_connection *nc, int ev, void *p) {
  auto *msg = (struct mg_mqtt_message *)p;

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

    ESP_LOGV(mcrMQTT::tagEngine(), "MG_EV_MQTT_CONNACK rc=%d",
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
    if (msg->qos == 1) {
      mg_mqtt_puback(mcrMQTT::instance()->_connection, msg->message_id);
    }

    mcrMQTT::instance()->incomingMsg(&(msg->topic), &(msg->payload));
    break;

  case MG_EV_MQTT_PINGRESP:
    ESP_LOGV(mcrMQTT::tagEngine(), "ping response");
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
} // namespace mcr
