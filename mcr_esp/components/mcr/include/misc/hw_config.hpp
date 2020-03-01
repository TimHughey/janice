/*
    hw_config.hpp -- MCR Hardware Configuration Jumpers
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

#ifndef mcr_hw_config_hpp
#define mcr_hw_config_hpp

#include <sys/time.h>
#include <time.h>

#include <esp_log.h>

#include <driver/gpio.h>
#include <driver/ledc.h>
#include <esp_system.h>

#include "misc/mcr_types.hpp"

namespace mcr {

typedef enum hardwareJumpers {
  LEGACY_JUMPER = 0x00,
  BASIC_JUMPER = 0x01,
  I2C_MULTIPLEXER_JUMPER = 0x02,
  PWM_JUMPER = 0x03
} hardwareJumpers_t;

typedef class hwConfig hwConfig_t;

class hwConfig {
public:
  static hwConfig_t *instance();

  static bool legacy() { return instance()->_legacy(); };
  static bool haveMultiplexer() { return instance()->_haveMultiplexer(); };
  static bool havePWM() { return instance()->_havePWM(); };

private:
  hwConfig(); // SINGLETON!  constructor is private

  bool _basic();
  bool _haveMultiplexer() {
    return (hw_jumpers_ == I2C_MULTIPLEXER_JUMPER) ? true : false;
  };
  bool _havePWM() { return (hw_jumpers_ == PWM_JUMPER) ? true : false; };
  bool _legacy() {
    return (hw_jumpers_ == I2C_MULTIPLEXER_JUMPER) ? true : false;
  };

private:
  const uint64_t hw_gpio_pin_sel_ = (GPIO_SEL_34 | GPIO_SEL_36 | GPIO_SEL_39);
  const gpio_num_t hw_gpio_[3] = {GPIO_NUM_36, GPIO_NUM_39, GPIO_NUM_34};
  hardwareJumpers_t hw_jumpers_ = LEGACY_JUMPER;
};
} // namespace mcr

#endif
