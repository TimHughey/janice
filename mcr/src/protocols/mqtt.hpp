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

#include "../include/readings.hpp"

#define mcr_mqtt_version_1 1

// Set the version of MCP Remote
#ifndef mcr_mqtt_version
#define mcr_mqtt_version mcr_mqtt_version_1
#endif

typedef bool (*cmdCallback_t)(JsonObject &root);

typedef enum {
  UNKNOWN,
  NONE,
  TIME_SYNC,
  SET_SWITCH,
  HEARTBEAT
} remoteCommand_t;

typedef class mcrMQTT mcrMQTT_t;
class mcrMQTT {
private:
  IPAddress broker;
  uint16_t port;
  PubSubClient mqtt;
  elapsedMillis _lastLoop;

#ifdef PROD_BUILD
  const char *_user = "mqtt";
  const char *_pass = "mqtt";
  const char *_rpt_feed = "prod/mcr/f/report";
  const char *_cmd_feed = "prod/mcr/f/command";
#else
  const char *_user = "mqtt";
  const char *_pass = "mqtt";
  const char *_rpt_feed = "mcr/f/report";
  const char *_cmd_feed = "mcr/f/command";
#endif

  const int _msg_version = 1;

  uint8_t _min_loop_ms = 10;
  uint8_t _timeslice_ms = 10;

public:
  mcrMQTT();
  mcrMQTT(Client &client, IPAddress broker, uint16_t port);

  bool connect();
  bool loop();
  bool loop(bool fullreport);

  void announceStartup();
  void publish(Reading_t *reading);

  static void registerCmdCallback(cmdCallback_t cmdCallback);

private:
  char *clientId();

  void publish(char *json);

  // callback invoked when a message arrives on any subscribed feed
  static void incomingMsg(char *topic, uint8_t *payload, unsigned int length);

  // command message helpers
  static remoteCommand_t parseCmd(JsonObject &root);
  static bool handleTimeSyncCmd(JsonObject &root);
  static bool handleSetSwitchCmd(JsonObject &root);

  static void setDebug(bool mode);
  static void debugOn();
  static void debugOff();
  static void debug(const char *msg);
  static void debug(const String &msg);
  static void debug2(const String &msg);
  static void debug4(const String &msg);
  static void debug(elapsedMicros e);
};

#endif // __cplusplus
#endif // mcp_mqtt_h
