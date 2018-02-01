/*
    mcr_cmd.cpp - Master Control Remote Switch Command
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

#include <bitset>
#include <cstdlib>
#include <cstring>
#include <sstream>
#include <string>

#include <ArduinoJson.h>
#include <FreeRTOS.h>
#include <System.h>
#include <esp_log.h>
#include <esp_timer.h>
#include <sys/time.h>
#include <time.h>

#include "base.hpp"
#include "cmd.hpp"
#include "util.hpp"

mcrCmd::mcrCmd(mcrDevID_t &id, cmd_bitset_t mask, cmd_bitset_t state) {
  _type = cmdSET_SWITCH;
  _dev_id = id;
  _mask = mask;
  _state = state;
}

mcrCmd::mcrCmd(mcrDevID_t &id, cmd_bitset_t mask, cmd_bitset_t state,
               mcrRefID_t &refid) {
  _type = cmdSET_SWITCH;
  _dev_id = id;
  _mask = mask;
  _state = state;
  _refid = refid;
}

mcrCmd::~mcrCmd() {}

mcrDevID_t &mcrCmd::dev_id() { return _dev_id; }

cmd_bitset_t mcrCmd::state() { return _state; }

cmd_bitset_t mcrCmd::mask() { return _mask; }

bool mcrCmd::matchPrefix(char *prefix) {
  if (strncmp(prefix, (char *)_dev_id, strlen(prefix)) == 0)
    return true;

  return false;
}

time_t mcrCmd::latency() { return _latency; }

mcrRefID_t &mcrCmd::refID() { return _refid; }

size_t mcrCmd::size() { return sizeof(mcrCmd_t); }

void mcrCmd::ack(bool ack) { _ack = ack; }

bool mcrCmd::ack() { return _ack; }

mcrCmd_t *mcrCmd::createSetSwitch(JsonObject &root, int64_t parse_us) {
  // json format of states command:
  // {"version":1,
  //   "switch":"ds/29463408000000",
  //   "states":[{"state":false,"pio":3}],
  //   "refid":"0fc4417c-f1bb-11e7-86bd-6cf049e7139f",
  //   "mtime":1515117138,
  //   "cmd":"set.switch"}
  int64_t create_start = esp_timer_get_time();
  const char *switch_id = root["switch"];
  mcrRefID_t refid = (const char *)root["refid"];
  mcrDevID_t sw(switch_id);
  const JsonVariant &variant = root.get<JsonVariant>("states");
  const JsonArray &states = variant.as<JsonArray>();
  const JsonVariant ack_flag = root["ack"];
  uint32_t mask = 0x00;
  uint32_t tobe_state = 0x00;

  // logDateTime(__PRETTY_FUNCTION__);
  // log("invoked for ");
  // sw.debug(true);

  // iterate through the array of new states
  for (auto element : states) {
    // get a reference to the object from the array
    const JsonObject &requested_state = element.as<JsonObject>();

    const uint32_t bit = atoi(requested_state["pio"]);
    const bool state = requested_state["state"].as<bool>();

    // set the mask with each bit that should be adjusted
    mask |= (0x01 << bit);

    // set the tobe state with the values those bits should be
    // if the new_state is true (on) then set the bit,
    // otherwise leave it unset
    if (state) {
      tobe_state |= (0x01 << bit);
    }
  }

  mcrCmd_t *cmd = new mcrCmd(sw, mask, tobe_state, refid);

  // set the ack flag if it's in the json; if not defaults to true
  if (ack_flag.success()) {
    cmd->ack(ack_flag.as<bool>());
  }

  int64_t create_us = esp_timer_get_time() - create_start;
  cmd->set_parse_metrics(parse_us, create_us);

  return cmd;
}

// {"version":1,"switch":"ds/12328621000000",
// "states":[{"state":false,"pio":1}],
// "refid":"0eb82430-0320-11e8-94b6-6cf049e7139f",
// "mtime":1517029685,"cmd":"set.switch"}

mcrCmd_t *mcrCmd::fromJSON(char *payload, size_t length) {
  static char msg[1024] = {0x00};
  StaticJsonBuffer<1024> jsonBuffer;
  mcrCmd_t *cmd = nullptr;

  // memset(msg, 0x00, sizeof(msg));
  memcpy(msg, (char *)payload, length);

  if ((length == 0) || (msg[0] != '{')) {
    ESP_LOGW("mcrCmd", "improper JSON: %s", msg);
    return nullptr;
  }

  int64_t parse_start = esp_timer_get_time();
  JsonObject &root = jsonBuffer.parseObject(msg);
  int64_t parse_us = esp_timer_get_time() - parse_start;

  if (!root.success()) { // bail if json parse failed
    ESP_LOGW("mcrCmd", "parse of JSON failed");
    return nullptr;
  }

  cmdType_t cmd_type = parseCmd(root);
  const char *cmd_str = root["cmd"];

  switch (cmd_type) {
  case cmdTIME_SYNC:
    ESP_LOGD("mcrCmd", "%s unncessary for ESP32 (parse=%lldus)", cmd_str,
             parse_us);
    break;

  case cmdSET_SWITCH:
    cmd = createSetSwitch(root, parse_us);
    break;

  case cmdHEARTBEAT:
    break;

  case cmdUNKNOWN:
    ESP_LOGW("mcrCmd", "unhandled command [%s]", cmd_str);
    break;

  case cmdNONE:
    ESP_LOGW("mcrCmd", "json did not command cmd key");
    break;
  }

  return cmd;
}

cmdType_t mcrCmd::parseCmd(JsonObject &root) {
  const char *cmd = root["cmd"];
  if (cmd == nullptr) {
    return cmdNONE;
  }

  if (strcmp("time.sync", cmd) == 0)
    return cmdTIME_SYNC;

  if (strcmp("set.switch", cmd) == 0)
    return cmdSET_SWITCH;

  if (strcmp("heartbeat", cmd) == 0)
    return cmdHEARTBEAT;

  return cmdUNKNOWN;
}

void mcrCmd::set_parse_metrics(int64_t parse_us, int64_t create_us) {
  _parse_us = parse_us;
  _create_us = create_us;
}

const std::string mcrCmd::debug() {
  std::ostringstream debug_str;

  debug_str << "mcrCmd(" << _dev_id << " mask=0b" << _mask << " state=0b"
            << _state << ((_ack) ? " ACK" : "")
            << " latency=" << (_latency / 1000.0) << "ms"
            << " parse=" << (_parse_us / 1000.0) << "ms"
            << " create=" << (_create_us / 1000.0) << "ms"
            << ")";

  return debug_str.str();
}
