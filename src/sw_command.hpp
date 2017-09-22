/*
    sw_command.h - Master Control Remote Switch Command
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

#ifndef switchCommand_h
#define switchCommand_h

#ifdef __cplusplus

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include "mcr_dev.hpp"

class switchCommand {
private:
  mcrDevID _dev_id;
  char _name[30] = {0x00};
  uint8_t _state = 0x00;
  uint8_t _mask = 0x00;

public:
  switchCommand() {
    _name[0] = 0x00;
    _mask = 0x00;
    _state = 0x00;
  };

  switchCommand(const char *name, uint8_t mask, uint8_t state) {
    strcpy(_name, name);

    _mask = mask;
    _state = state;
  };

  char *name() { return _name; };
  uint8_t state() { return _state; };
  uint8_t mask() { return _mask; };
};

#endif // __cplusplus
#endif // sw_command.h
