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

#include "mcr_mqtt.hpp"
#include "mcr_util.hpp"

// feeds to publish and subscribe
const char *MQTT_RPT_FEED = "mcr/f/report";  // published device reports
const char *MQTT_CMD_FEED = "mcr/f/command"; // subscribed command messages
const char *MQTT_MSG_VERSION = "1";

static uint8_t cmd_callback_count = 0;
static cmdCallback_t cmd_callback[10] = {NULL};
static boolean debugMode = false;

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

boolean mcrMQTT::loop(boolean fullreport) {
  elapsedMillis duration;
  boolean rc;

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

boolean mcrMQTT::loop() {
  boolean rc = 0;

  // safety mechanism to all loop() to be called as frequently as desired
  // without creating unnecessary load
  if (lastLoop < MIN_LOOP_INTERVAL_MILLIS) {
    return true;
  }

  if (connect() == 1) {
    rc = mqtt.loop();
  }

  lastLoop = 0;
  return rc;
}

boolean mcrMQTT::connect() {
  int rc;

  if (!mqtt.connected()) {
    rc = mqtt.connect(clientId(), MQTT_USER, MQTT_PASS);
    if (rc == 1) {
      debug("  mcrMQTT connected\r\n");
      mqtt.setCallback(&incomingMsg);
      mqtt.subscribe(MQTT_CMD_FEED);
    } else {
      debug("  mcrMQTT connect failed\r\n");
      mqtt.disconnect();
    }
  } else {
    rc = 1;
  }

  return rc == 1 ? true : false;
}

void mcrMQTT::publish(Reading *reading) {
  elapsedMicros publish_elapsed;
  char *json = NULL;

  if (reading == NULL) {
    Serial.print("    ");
    Serial.print(__PRETTY_FUNCTION__);
    Serial.print(" invoked with reading == NULL\n\r");
    return;
  }

  reading->json();

  String msg = String();

  if ((timeStatus() == timeSet) && mqtt.connected()) {
    if (mqtt.publish(MQTT_RPT_FEED, json)) {
      msg = String("    mcrMQTT::publish(") + String(MQTT_RPT_FEED) + "," +
            String(json) + ")\r\n";
    } else {
      msg = String("    mcrMQTT:publish failed\r\n");
    }
  } else {
    msg = String("    ** mcrMQTT::publish - time not set or MQTT not "
                 "connected, will not publish\r\n");
  }

  debug(msg);

  msg = "    mcrMQTT::publish() took " + String(publish_elapsed) + "us\r\n\r\n";
  debug(msg);
}

char *mcrMQTT::clientId() {
  static char _client_id[16];

  sprintf(_client_id, "fm0-%s", mcrUtil::macAddress());
  return _client_id;
}

void mcrMQTT::incomingMsg(char *topic, uint8_t *payload, unsigned int length) {
  char msg[512];
  elapsedMicros callback_elapsed;
  StaticJsonBuffer<512> jsonBuffer;

  memset(msg, 0x00, 512);
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
  if (cmd == NULL) {
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

void mcrMQTT::setDebug(boolean mode) { debugMode = mode; }
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
void mcrMQTT::debug(elapsedMicros e) {
  if (debugMode) {
    Serial.print(e);
    Serial.print("us");
  }
}
