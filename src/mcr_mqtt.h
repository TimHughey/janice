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

#ifdef __cplusplus

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include <ArduinoJson.h>
#include <Client.h>
#include <PubSubClient.h>
#include <TimeLib.h>
#include <WiFi101.h>
#include <elapsedMillis.h>

#include "reading.h"

#define mcr_mqtt_version_1 1

// Set the version of MCP Remote
#ifndef mcr_mqtt_version
#define mcr_mqtt_version mcr_mqtt_version_1
#endif

#define MIN_LOOP_INTERVAL_MILLIS 10

#define MQTT_SERVER "jophiel.wisslanding.com"
#define MQTT_PORT 1883
#define MQTT_USER "mqtt"
#define MQTT_PASS "mqtt"

typedef bool (*cmdCallback_t)(JsonObject &root);

class mcrMQTT {
private:
  IPAddress broker;
  uint16_t port;
  PubSubClient mqtt;
  elapsedMillis lastLoop;
  boolean debugMode;

public:
  mcrMQTT();
  mcrMQTT(Client &client, IPAddress broker, uint16_t port);

  boolean init();
  boolean loop();
  boolean loop(boolean fullreport);

  void publish(Reading *reading);
  void publish(float temp, float rh, int soil_val, time_t readtime,
               time_t loop_duration);
  void setDebug(boolean mode);
  void debugOn();
  void debugOff();

  static void registerCmdCallback(cmdCallback_t cmdCallback);

private:
  boolean connect();
  char *clientId();

  void debug(const char *msg);
  void debug(const String &msg);
  static void callback(char *topic, uint8_t *payload, unsigned int length);
};

#endif // __cplusplus
#endif // mcp_mqtt_h
