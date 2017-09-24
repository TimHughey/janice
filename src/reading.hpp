/*
    reading.h - Readings used within Master Control Remote
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

#ifndef reading_h
#define reading_h

#ifdef __cplusplus

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include <ArduinoJson.h>
#include <TimeLib.h>
#include <WiFi101.h>
#include <elapsedMillis.h>

class Reading {
private:
  // defines which values are populated
  typedef enum { UNDEF, TEMP, RH, SWITCH, SOIL, PH } reading_t;

  // id and metadata for the reading
  char _id[30];
  time_t _mtime;
  reading_t _type;

  // actual reading data
  float _celsius;
  float _relhum;
  float _soil;
  float _ph;
  uint8_t _state;
  uint8_t _bits;
  bool _cmd_ack = false;
  time_t _latency = 0;

  void jsonCommon(JsonObject &root);
  const char *typeAsString();

public:
  // undefined reading
  Reading() {
    strcpy(_id, "no_id");
    _mtime = now();
    _type = UNDEF;
  }
  Reading(char *id) {
    strcpy(_id, id);
    _mtime = now();
    _type = UNDEF;
  }
  Reading(char *id, time_t mtime) {
    strcpy(_id, id);
    _mtime = mtime;
    _type = UNDEF;
  }

  // temperature only
  // Reading(char *id, float celsius) {
  //  strcpy(_id, id);
  //  _mtime = now();
  //  _type = TEMP;
  //  _celsius = celsius;
  //  }
  Reading(const char *id, time_t mtime, float celsius) {
    strcpy(_id, id);
    _mtime = mtime;
    _type = TEMP;
    _celsius = celsius;
  }

  // relative humidity
  // Reading(const char *id, float celsius, float relhum) {
  //  strcpy(_id, id);
  //  _mtime = now();
  //  _type = RH;
  //  _celsius = celsius;
  //  _relhum = relhum;
  //  }

  Reading(const char *id, time_t mtime, float celsius, float relhum) {
    strcpy(_id, id);
    _mtime = mtime;
    _type = RH;
    _celsius = celsius;
    _relhum = relhum;
  }

  // switch states
  Reading(const char *id, time_t mtime, uint8_t state, uint8_t bits) {
    strcpy(_id, id);
    _mtime = mtime;
    _type = SWITCH;
    _state = state;
    _bits = bits;
  }

  void setCmdAck(time_t latency) {
    _cmd_ack = true;
    _latency = latency;
  }

  uint8_t state() { return _state; };
  char *json();
};

typedef class Reading Reading_t;

#endif // __cplusplus
#endif // reading_h
