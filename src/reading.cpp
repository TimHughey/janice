/*
    mcpr_mqtt.cpp - Readings used within Master Control Remote
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

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include <ArduinoJson.h>

#include "mcr_util.hpp"
#include "reading.hpp"

#define VERSION ((uint8_t)1)

void Reading::jsonCommon(JsonObject &root) {
  root["version"] = VERSION;
  root["host"] = mcrUtil::hostID();
  root["device"] = _id;
  root["mtime"] = _mtime;
  root["type"] = typeAsString();

  if (_cmd_ack) {
    root["cmdack"] = _cmd_ack;
    root["latency"] = _latency;
    root["cid"] = _cid;
  }
}

char *Reading::json() {
  StaticJsonBuffer<512> jsonBuffer;
  static char buffer[768];
  elapsedMicros json_elapsed;

  memset(buffer, 0x00, sizeof(buffer));

  JsonObject &root = jsonBuffer.createObject();
  jsonCommon(root);

  if (_type == SWITCH) {
    static char pio_id[8][2] = {0x00};
    memset(pio_id, 0x00, sizeof(pio_id));

#ifdef VERBOSE
    logDateTime(__PRETTY_FUNCTION__);
    log("switch: ");
    log("sizeof(pio_id)=");
    log(sizeof(pio_id));
#endif

    JsonArray &pio = root.createNestedArray("pio");

    for (uint8_t i = 0, k = 7; i < _bits; i++, k--) {
      // char  pio_id[] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
      boolean pio_state = (_state & ((uint8_t)0x01 << i));
      JsonObject &item = pio.createNestedObject();

      itoa(i, &(pio_id[i][0]), 10);
      item.set(&(pio_id[i][0]), pio_state);
#ifdef VERBOSE
      log(" pio=");
      log(&(pio_id[i][0]));
      log(",");
      log(pio_state);
#endif
    }
  }

  switch (_type) {
  case UNDEF:
    break;

  case TEMP:
    root["tc"] = _celsius;
    root["tf"] = _celsius * 1.8 + 32.0;
#ifdef VERBOSE
    Serial.print("    Reading creating temperature json: tc=");
    Serial.print(_celsius);
    Serial.print(" ");
#endif
    break;

  case RH:
    root["tc"] = _celsius;
    root["tf"] = _celsius * 1.8 + 32.0;
    root["rh"] = _relhum;
#ifdef VERBOSE
    Serial.print("    Reading creating relhum json: tc=");
    Serial.print(_celsius);
    Serial.print(" rh=");
    Serial.print(_relhum);
    Serial.print(" ");
#endif
    break;

  case SOIL:
    root["soil"] = _soil;
#ifdef VERBOSE
    Serial.print("    Reading creating soil json: soil=");
    Serial.print(_soil);
    Serial.print(" ");
#endif
    break;

  case PH:
    root["ph"] = _ph;
#ifdef VERBOSE
    Serial.print("    Reading creating ph json: ph=");
    Serial.print(_ph);
    Serial.print(" ");
#endif
    break;

  default:
    break;
  }

  root.printTo(buffer, sizeof(buffer));
#ifdef VERBOSE
  log("in ");
  logElapsed(json_elapsed, true);
#endif

  return buffer;
}

const char *Reading::typeAsString() {
  static const char _s1[] = "undef";
  static const char _s2[] = "temp";
  static const char _s3[] = "relh";
  static const char _s4[] = "switch";
  static const char _s5[] = "soil";
  static const char _s6[] = "ph";

  switch (_type) {
  case UNDEF:
    return _s1;
  case TEMP:
    return _s2;
  case RH:
    return _s3;
  case SWITCH:
    return _s4;
  case SOIL:
    return _s5;
  case PH:
    return _s6;
  }

  return _s1;
}
