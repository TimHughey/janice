/*
    mcr_cmd.h - Master Control Remote Switch Command
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

#ifndef mcr_cmd_h
#define mcr_cmd_h

#include <bitset>
#include <cstdlib>
#include <sstream>
#include <string>

#include <esp_timer.h>
#include <external/ArduinoJson.h>
#include <freertos/FreeRTOS.h>
#include <sys/time.h>
#include <time.h>

#include "devs/base.hpp"
#include "misc/util.hpp"

typedef class mcrCmd mcrCmd_t;
typedef std::bitset<8> cmd_bitset_t;

typedef enum {
  cmdUNKNOWN,
  cmdNONE,
  cmdTIME_SYNC,
  cmdSET_SWITCH,
  cmdHEARTBEAT,
  cmdSET_NAME
} cmdType_t;

class mcrCmd {
private:
  cmdType_t _type;
  mcrDevID_t _dev_id;
  cmd_bitset_t _state;
  cmd_bitset_t _mask;
  int64_t _latency = esp_timer_get_time();
  time_t _mtime = time(nullptr);
  mcrRefID_t _refid; // example: 2d931510-d99f-494a-8c67-87feb05e1594
  bool _ack = false;

  int64_t _parse_us = 0LL;
  int64_t _create_us = 0LL;

public:
  mcrCmd() {}

  mcrCmd(const mcrDevID_t &id, cmd_bitset_t mask, cmd_bitset_t state,
         mcrRefID_t &refid);
  mcrCmd(const mcrDevID_t &id, cmd_bitset_t mask, cmd_bitset_t state);
  mcrCmd(const mcrCmd_t *cmd) {
    ESP_LOGD("mcrCmd", "%s this(%p) --> cmd(%p)", __PRETTY_FUNCTION__,
             (void *)this, (void *)cmd);

    _type = cmd->_type;
    _dev_id = cmd->_dev_id;
    _mask = cmd->_mask;
    _state = cmd->_state;
    _refid = cmd->_refid;
  }

  void ack(bool ack);
  bool ack();

  const mcrDevID_t &dev_id() const;
  time_t latency();
  cmd_bitset_t mask();
  bool matchPrefix(char *prefix);
  mcrRefID_t &refID();
  void set_parse_metrics(int64_t parse_us, int64_t create_us);
  cmd_bitset_t state();

  static void checkTimeSkew(JsonObject &root);
  static mcrCmd_t *createSetSwitch(JsonObject &root, int64_t parse_us);
  static mcrCmd_t *fromJSON(const std::string *json);
  static void handle_set_name_cmd(JsonObject &root);
  static cmdType_t parseCmd(JsonObject &root);
  static size_t size();

  const std::string debug();
};

#endif // mcr_cmd_h
