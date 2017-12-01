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

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include "../include/readings.hpp"
#include "../misc/util.hpp"
#include "mqtt.hpp"

static uint8_t cmd_callback_count = 0;
static cmdCallback_t cmd_callback[10] = {nullptr};
static bool debugMode = false;

mcrMQTT::mcrMQTT() {
  this->mqtt = PubSubClient();
  this->lastLoop = 0;
}

mcrMQTT::mcrMQTT(Client &client, IPAddress broker, uint16_t port) {
  this->broker = broker;
  this->port = port;

  mqtt.setClient(client);
  mqtt.setServer(this->broker, this->port);
  mqtt.setClient(client);
}

bool mcrMQTT::loop(bool fullreport) {
  elapsedMillis duration;
  bool rc;

  rc = loop();

  String msg = String();
  if (duration > 5) {
    if (debugMode) {
      msg = String("  mcrMQTT Loop elapsed millis =");
    }

    msg += " " + String(duration) + " ";

    if (fullreport) {
      msg += "\r\n";
    }

    debug(msg);
  }

  return rc;
}

bool mcrMQTT::loop() {
  elapsedMillis timeslice;
  bool rc = false;

  // safety mechanism to all loop() to be called as frequently as desired
  // without creating unnecessary load
  // if (lastLoop < _min_loop_ms) {
  //  return true;
  //}

  // while (timeslice < _timeslice_ms) {
  if (connect() == 1) {
    rc = mqtt.loop();
  }

  lastLoop = 0;
  return rc;
}

void mcrMQTT::announceStartup() {
  const int json_buffer_max = 512;
  const int json_max = 1024;

  // since this is a one-time only action we'll use the stack
  StaticJsonBuffer<json_buffer_max> jsonBuffer;
  char buffer[json_max] = {0x00};

  JsonObject &root = jsonBuffer.createObject();
  root["host"] = mcrUtil::hostID();
  root["type"] = "startup";
  root["mtime"] = millis();

#ifdef GIT_REV
#define STRING(s) #s
  root["version"] = STRING(GIT_REV);
#else
  root["version"] = "undef";
#endif

  root.printTo(buffer, json_max);
  publish(buffer);
}

void mcrMQTT::publish(Reading_t *reading) {
  elapsedMicros eus;

  if (reading == nullptr) {
    Serial.print("    ");
    Serial.print(__PRETTY_FUNCTION__);
    Serial.print(" invoked with reading == nullptr\n\r");
    return;
  }

  if (timeStatus() != timeSet) {
    debug2(__PRETTY_FUNCTION__);
    debug(" time not set, skipping publish\r\n");
    return;
  }

  if (!mqtt.connected()) {
    debug2(__PRETTY_FUNCTION__);
    debug(" MQTT not connected, skipping publish\r\n");
    return;
  }

  char *json = reading->json();

  debug2(__PRETTY_FUNCTION__);
  debug("\r\n");
  debug4(json);
  debug("\r\n");

  publish(json);

  debug2(__PRETTY_FUNCTION__);
  debug(" took ");
  debug(eus);
  debug("\r\n");
}

bool mcrMQTT::connect() {
  int rc;

  if (!mqtt.connected()) {
    rc = mqtt.connect(clientId(), _user, _pass);
    if (rc == 1) {
      debug2(__PRETTY_FUNCTION__);
      debug(" success\r\n");
      mqtt.setCallback(&incomingMsg);
      mqtt.subscribe(_cmd_feed);
    } else {
      debug2(__PRETTY_FUNCTION__);
      debug(" failed\r\n");
      mqtt.disconnect();
    }
  } else {
    rc = 1;
  }

  return rc == 1 ? true : false;
}

void mcrMQTT::publish(char *json) {
  elapsedMicros eus;

  if (mqtt.connected()) {
    if (mqtt.publish(_rpt_feed, json)) {
      debug2(__PRETTY_FUNCTION__);
      debug("  ");
      debug(json);
      debug("\r\n");
    } else {
      debug2(__PRETTY_FUNCTION__);
      debug(" failed\r\n");
    }
  } else {
    debug2(__PRETTY_FUNCTION__);
    debug(" MQTT not connected, skipping publish\r\n");
    return;
  }

  debug2(__PRETTY_FUNCTION__);
  debug(" took ");
  debug(eus);
  debug("\r\n");
}

char *mcrMQTT::clientId() {
  static char _client_id[16];

  sprintf(_client_id, "fm0-%s", mcrUtil::macAddress());
  return _client_id;
}

void mcrMQTT::incomingMsg(char *topic, uint8_t *payload, unsigned int length) {
  static char msg[1024] = {0x00};
  elapsedMicros callback_elapsed;
  StaticJsonBuffer<1024> jsonBuffer;

  if (debugMode) {
    Serial.println("  mcrMQTT::incomingMsg() begin");
  }

  // memset(msg, 0x00, sizeof(msg));
  memcpy(msg, (char *)payload, length);

  if (length == 0) {
    debug("  mcrMQTT::callback() received zero length message\r\n");
    return;
  }

  if (msg[0] != '{') {
    debug("  mcrMQTT::callback() received non-JSON message\r\n");
    return;
  }

  if (debugMode) {
    Serial.print("  mcrMQTT::callback(");
    Serial.print(topic);
    Serial.print(",");
    Serial.print(msg);
    Serial.print(",");
    Serial.print(length);
    Serial.print(")\r\n");
  }

  JsonObject &root = jsonBuffer.parseObject(msg);

  if (!root.success()) { // bail if json parse failed
    debug("  mcrMQTT::callback() parse of JSON failed\r\n");
    return;
  }

  remoteCommand_t cmd = parseCmd(root);
  const char *cmd_str = root["cmd"];

  switch (cmd) {
  case TIME_SYNC:
    handleTimeSyncCmd(root);
    break;

  case SET_SWITCH:
    handleSetSwitchCmd(root);
    break;

  case HEARTBEAT:
    debug("  mcrMQTT::callback() received heartbeat");
    break;

  case UNKNOWN:
    debug("  mcrMQTT::callback() unhandled command: ");
    debug(cmd_str);
    debug("\r\n");

  case NONE:
    debug("  mcrMQTT::callback() json did not contain a command\r\n");
    return;
  }

  if (debugMode) {
    Serial.print("  mcrMQTT::callback() took ");
    Serial.print(callback_elapsed);
    Serial.println("us");
    Serial.println();
  }
}

void mcrMQTT::registerCmdCallback(cmdCallback_t callback) {
  cmd_callback[cmd_callback_count] = callback;

  cmd_callback_count += 1;
}

bool mcrMQTT::handleTimeSyncCmd(JsonObject &root) {
  const char *mtime_str = root["mtime"];
  bool rc = true;

  debug("  mcrMQTT::callback() received cmd time.sync\r\n");

  if (mtime_str) {
    time_t mtime = atol(mtime_str);

    if ((now() != mtime) || (timeStatus() != timeSet)) {
      setTime(mtime);
      randomSeed(mtime);

      debug("  mcrMQTT::handleTimeSyncCmd() local time set \r\n");
    }
  } else {
    rc = false;
    debug("  [WARNING] Timesync cmd did not include mtime\r\n");
  }

  return rc;
}

bool mcrMQTT::handleSetSwitchCmd(JsonObject &root) {
  bool rc = true;

  for (uint8_t i = 0; i < cmd_callback_count; i++) {
    cmd_callback[i](root);
  }

  return rc;
}

remoteCommand_t mcrMQTT::parseCmd(JsonObject &root) {
  const char *cmd = root["cmd"];
  if (cmd == nullptr) {
    return NONE;
  }

  if (strcmp("time.sync", cmd) == 0)
    return TIME_SYNC;

  if (strcmp("set.switch", cmd) == 0)
    return SET_SWITCH;

  if (strcmp("heartbeat", cmd) == 0)
    return HEARTBEAT;

  return UNKNOWN;
}

void mcrMQTT::setDebug(bool mode) { debugMode = mode; }
void mcrMQTT::debugOn() { setDebug(true); }
void mcrMQTT::debugOff() { setDebug(false); }
void mcrMQTT::debug(const char *msg) {
  if (debugMode) {
    Serial.print(msg);
  }
}
void mcrMQTT::debug(const String &msg) {
  if (debugMode) {
    Serial.print(msg);
  }
}
void mcrMQTT::debug2(const String &msg) {
  if (debugMode) {
  }
  String indent = "  " + msg;
  debug(indent);
}
void mcrMQTT::debug4(const String &msg) {
  if (debugMode) {
  }
  String indent = "    " + msg;
  debug(indent);
}
void mcrMQTT::debug(elapsedMicros e) {
  if (debugMode) {
    Serial.print(e);
    Serial.print("us");
  }
}
