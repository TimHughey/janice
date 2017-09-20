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

#include "mcr_mqtt.h"
#include "mcr_util.h"

// feeds to publish and subscribe
const char *MQTT_RPT_FEED = "mcr/f/report";   // published device reports
const char *MQTT_CMD_FEED = "mcr/f/command";  // subscribed command messages
const char *MQTT_TIME_FEED = "/util/f/mtime"; // DEPRECATED!
const char *MQTT_CFG_FEED = "mcr/f/config";   // subscribed config messages
const char *MQTT_HEARTBEAT_FEED =
    "mcr/f/heartbeat/master"; // subscribed heartbeat messages

const char *MQTT_CMD_TIMESYNC = "timesync";
const char *MQTT_MSG_VERSION = "1";

static uint8_t cmd_callback_count = 0;
static cmdCallback_t cmdCallback[10] = {NULL};

mcrMQTT::mcrMQTT() {
  this->mqtt = PubSubClient();
  this->lastLoop = 0;
  this->debugMode = false;
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
      mqtt.setCallback(&callback);
      mqtt.subscribe(MQTT_TIME_FEED);
      mqtt.subscribe(MQTT_CMD_FEED);
      mqtt.subscribe(MQTT_CFG_FEED);
      mqtt.subscribe(MQTT_HEARTBEAT_FEED);
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
  char *json = reading->json();

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

void mcrMQTT::callback(char *topic, uint8_t *payload, unsigned int length) {
  char msg[512];
  elapsedMicros callback_elapsed;
  StaticJsonBuffer<512> jsonBuffer;

  memset(msg, 0x00, 512);
  memcpy(msg, (char *)payload, length);

  if ((length > 0) && (msg[0] == '{')) {

    Serial.print("  mcrMQTT::callback(");
    Serial.print(topic);
    Serial.print(",");
    Serial.print(msg);
    Serial.print(",");
    Serial.print(length);
    Serial.print(")\r\n");

    JsonObject &root = jsonBuffer.parseObject(msg);

    if (root.success()) {
#ifdef VERBOSE
      Serial.print("  mcrMQTT::callback() parse of JSON successful\r\n");
#endif

      const char *cmd = root["cmd"];

      if ((cmd) && (strcmp(cmd, MQTT_CMD_TIMESYNC) == 0)) {
        const char *mtime_str = root["mtime"];

#ifdef VERBOSE
        Serial.print("  mcrMQTT::callback() received cmd = timesync\r\n");
#endif

        if (mtime_str) {
          time_t mtime = atol(mtime_str);

          if ((now() != mtime) || (timeStatus() != timeSet)) {
            setTime(mtime);
            randomSeed(mtime);
#ifdef VERBOSE
            Serial.println("  Local time set via timesync cmd");
#endif
          }
        } else {
#ifdef VERBOSE
          Serial.print("  [WARNING] Timesync cmd did not include mtime");
#endif
        }
      } else if ((cmd) && (strcmp(cmd, "setswitch") == 0)) {
        cmdCallback_t cb = cmdCallback[0];

        if (cb != NULL) {
          cb(root);
        }
      }
    } else {
#ifdef VERBOSE
      Serial.print("  mcrMQTT::callback() parse of JSON failed\r\n");
#endif
    }

  } else if (length > 0) {
    Serial.println("  [DEPRECATED] mcrMQTT::callback() received non-JSON msg");
  }

  Serial.print("  mcrMQTT::callback() took ");
  Serial.print(callback_elapsed);
  Serial.println("us");
  Serial.println();
}

void mcrMQTT::registerCmdCallback(cmdCallback_t callback) {
  cmdCallback[cmd_callback_count] = callback;

  cmd_callback_count += 1;
}
