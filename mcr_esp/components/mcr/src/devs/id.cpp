/*
    id.hpp - Master Control Remote Device ID
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

#include <cstdlib>
#include <ios>
#include <sstream>
#include <string>
#include <tuple>

#include <sys/time.h>
#include <time.h>

#include "devs/addr.hpp"
#include "devs/id.hpp"
#include "misc/mcr_types.hpp"

bool mcrDevID::matchPrefix(const std::string &prefix) {
  return ((_id.substr(0, prefix.length())) == prefix);
}

const std::string mcrDevID::debug() {
  std::ostringstream debug_str;

  debug_str << "mcrDevID(" << _id << ")";

  return debug_str.str();
}
