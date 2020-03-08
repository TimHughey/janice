/*
    network.hpp - Master Control Command Network Class
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

#ifndef mcr_cmd_network_hpp
#define mcr_cmd_network_hpp

#include "cmds/base.hpp"

using std::unique_ptr;

namespace mcr {

typedef class mcrCmdNetwork mcrCmdNetwork_t;
class mcrCmdNetwork : public mcrCmd {
private:
  string_t _name;

public:
  mcrCmdNetwork(JsonDocument &doc, elapsedMicros &e);
  mcrCmdNetwork(mcrCmd *cmd) : mcrCmd(cmd) { _name = this->_name; };
  ~mcrCmdNetwork(){};

  bool process();
  size_t size() const { return sizeof(mcrCmdNetwork_t); };
  const unique_ptr<char[]> debug();
};

} // namespace mcr

#endif
