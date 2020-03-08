/*
    switch.hpp - Master Control Command Switch Class
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

#ifndef mcr_cmd_switch_hpp
#define mcr_cmd_switch_hpp

#include "cmds/base.hpp"

using std::unique_ptr;

namespace mcr {

typedef std::bitset<8> cmd_bitset_t;

typedef class cmdSwitch cmdSwitch_t;
class cmdSwitch : public mcrCmd {
private:
  cmd_bitset_t _mask;
  cmd_bitset_t _state;

public:
  // DERIVED CLASS copy from a pointer to a cmdSwitch_t
  // NOTE:  the BASE CLASS is leveraged for base class members
  //        and is called (mcrCmd{cmd}) before setting the DERIVED class
  //        members via the initialization list
  cmdSwitch(const cmdSwitch_t *cmd)
      : mcrCmd{cmd}, _mask(cmd->_mask), _state(cmd->_state){};

  cmdSwitch(JsonDocument &doc, elapsedMicros &parse);
  // cmdSwitch(const string_t &id, cmd_bitset_t mask, cmd_bitset_t state)
  //     : mcrCmd(mcrCmdType::setswitch), _mask(mask), _state(state) {
  //   _external_dev_id = id;
  //   _internal_dev_id = id;
  // };

  cmd_bitset_t mask() { return _mask; };
  bool process();
  size_t size() const { return sizeof(cmdSwitch_t); };
  cmd_bitset_t state() { return _state; };

  const unique_ptr<char[]> debug();
};
} // namespace mcr

#endif
