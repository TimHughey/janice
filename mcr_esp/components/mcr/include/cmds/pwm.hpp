/*
    cmd_pwm.hpp - Master Control Remote Command PWM Class
    Copyright (C) 2020  Tim Hughey

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

#ifndef mcr_cmd_pwm_hpp
#define mcr_cmd_pwm_hpp

#include <cstdlib>
#include <memory>
#include <string>

#include <freertos/FreeRTOS.h>
#include <sys/time.h>
#include <time.h>

#include "cmds/base.hpp"
#include "misc/elapsedMillis.hpp"
#include "misc/mcr_types.hpp"

using std::unique_ptr;

namespace mcr {

typedef class cmdPWM cmdPWM_t;
class cmdPWM : public mcrCmd {
private:
  uint32_t _duty;

public:
  cmdPWM(const cmdPWM_t *cmd) : mcrCmd{cmd}, _duty(cmd->_duty){};

  cmdPWM(JsonDocument &doc, elapsedMicros &parse);
  cmdPWM(const string_t &id, uint32_t duty)
      : mcrCmd(mcrCmdType::pwm), _duty(duty) {
    _external_dev_id = id;
    _internal_dev_id = id;
  };

  uint32_t duty() { return _duty; };

  bool IRAM_ATTR process();

  size_t size() { return sizeof(cmdPWM_t); };

  const unique_ptr<char[]> debug();
};
} // namespace mcr

#endif
