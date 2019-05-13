/*
    cmd_base.hpp - Master Control Command Switch Class
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

#ifndef mcr_cmd_switch_h
#define mcr_cmd_switch_h

#include <bitset>
#include <cstdlib>
#include <memory>
#include <string>

#include <esp_timer.h>
#include <freertos/FreeRTOS.h>
#include <sys/time.h>
#include <time.h>

#include "cmds/cmd_base.hpp"
#include "misc/mcr_types.hpp"

using std::unique_ptr;

typedef std::bitset<8> cmd_bitset_t;

typedef class mcrCmdSwitch mcrCmdSwitch_t;
class mcrCmdSwitch : public mcrCmd {
private:
  std::string _dev_id;
  cmd_bitset_t _mask;
  cmd_bitset_t _state;
  mcrRefID_t _refid;
  bool _ack = true; // default to true if ack is not set

public:
  mcrCmdSwitch(const mcrCmdSwitch_t *cmd)
      : mcrCmd(mcrCmdType::setswitch), _dev_id(cmd->_dev_id), _mask(cmd->_mask),
        _state(cmd->_state), _refid(cmd->_refid), _ack(cmd->_ack){};
  mcrCmdSwitch(JsonDocument &doc);
  mcrCmdSwitch(const std::string &id, cmd_bitset_t mask, cmd_bitset_t state)
      : mcrCmd(mcrCmdType::setswitch), _dev_id(id), _mask(mask),
        _state(state){};

  void ack(bool ack) { _ack = ack; }
  bool ack() { return _ack; }
  const std::string &dev_id() const { return _dev_id; };
  cmd_bitset_t mask() { return _mask; };
  bool IRAM_ATTR matchPrefix(const char *prefix);
  bool IRAM_ATTR process();
  mcrRefID_t &refID() { return _refid; };
  bool IRAM_ATTR sendToQueue(cmdQueue_t &cmd_q);
  size_t size() { return sizeof(mcrCmdSwitch_t); };
  cmd_bitset_t state() { return _state; };

  const unique_ptr<char[]> debug();
};

#endif
