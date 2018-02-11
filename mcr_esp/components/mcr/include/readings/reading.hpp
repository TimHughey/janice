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

#include <external/ArduinoJson.h>
#include <freertos/FreeRTOS.h>
#include <sys/time.h>
#include <time.h>

#include "cmds/refid.hpp"
#include "devs/id.hpp"
#include "misc/util.hpp"
#include "misc/version.hpp"

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

  int64_t _read_us = 0;
  int64_t _write_us = 0;
  int _crc_mismatches = 0;
  int _read_errors = 0;
  int _write_errors = 0;

  char *_json = nullptr;

protected:
  void commonJSON(JsonObject &root);
  virtual void populateJSON(JsonObject &root){};

public:
  // default constructor, Reading type undefined
  Reading(){};
  Reading(const mcrDevID_t &id, time_t mtime = time(nullptr));
  Reading(time_t mtime = time(nullptr));
  virtual ~Reading();

  std::string *json(char *buffer = nullptr, size_t len = 0);
  void setCmdAck(time_t latency, mcrRefID_t &refid);

  void setCRCMismatches(int crc_mismatches) {
    _crc_mismatches = crc_mismatches;
  }
  void setReadErrors(int read_errors) { _read_errors = read_errors; }
  void setReadUS(int64_t read_us) { _read_us = read_us; }
  void setWriteErrors(int write_errors) { _write_errors = write_errors; }
  void setWriteUS(int64_t write_us) { _write_us = write_us; }
};

#endif // reading_h
