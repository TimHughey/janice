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

#include <string>

#include <ArduinoJson.h>
#include <FreeRTOS.h>
#include <System.h>
#include <sys/time.h>
#include <time.h>

#include "id.hpp"
#include "refid.hpp"
#include "version.hpp"

typedef class Reading Reading_t;
class Reading {
private:
  // defines which values are populated
  typedef enum { UNDEF, TEMP, RH, SWITCH, SOIL, PH } reading_t;

  // reading metadata (id, measured time and type)
  mcrDevID_t _id;
  time_t _mtime = time(nullptr); // time the reading was measureed
  reading_t _type = UNDEF;
  const char *_version = Version::git();

  // tracking info
  mcrRefID_t _refid;
  bool _cmd_ack = false;
  time_t _latency = 0;

  char *_json = nullptr;

protected:
  virtual void populateJSON(JsonObject &root){};
  void commonJSON(JsonObject &root);

public:
  // default constructor, Reading type undefined
  Reading(){};
  Reading(mcrDevID_t &id, time_t mtime = time(nullptr));
  Reading(time_t mtime = time(nullptr));
  virtual ~Reading();

  void setCmdAck(time_t latency, const char *refid_raw = NULL);
  char *json(char *buffer = nullptr, size_t len = 0);
};

#endif // reading_h
