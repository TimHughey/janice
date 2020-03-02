/*
    pwm_dev.hpp - Master Control Remote PWM Device
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

#ifndef pwm_dev_hpp
#define pwm_dev_hpp

#include <memory>
#include <string>

#include <driver/gpio.h>
#include <driver/ledc.h>

#include "devs/base.hpp"

using std::unique_ptr;

namespace mcr {

typedef class pwmDev pwmDev_t;

#define PWM_GPIO_PIN_SEL (GPIO_SEL_32 | GPIO_SEL_15 | GPIO_SEL_33 | GPIO_SEL_27)

class pwmDev : public mcrDev {
public:
  pwmDev() {}
  static const char *pwmDevDesc(mcrDevAddr_t &addr);
  static void allOff();

private:
  string_t external_name_; // name used to report externally
  static const uint32_t pwm_max_addr_len_ = 1;
  static const uint32_t pwm_max_id_len_ = 40;
  static const uint32_t duty_max_ = 4095;
  static const uint32_t duty_min_ = 0;

  const gpio_num_t pins_[4] = {GPIO_NUM_32, GPIO_NUM_15, GPIO_NUM_33,
                               GPIO_NUM_27};

  ledc_channel_config_t ledc_channel_ = {.gpio_num = GPIO_NUM_32,
                                         .speed_mode = LEDC_HIGH_SPEED_MODE,
                                         .channel = LEDC_CHANNEL_0,
                                         .intr_type = LEDC_INTR_DISABLE,
                                         .timer_sel = LEDC_TIMER_0,
                                         .duty = duty_,
                                         .hpoint = 0};

  gpio_num_t gpio_pin_;
  uint32_t duty_ = 2048;
  esp_err_t last_rc_ = ESP_OK;

public:
  pwmDev(mcrDevAddr_t &num, ledc_channel_t channel);
  uint8_t devAddr();

  void configureChannel();
  ledc_channel_t channel() { return ledc_channel_.channel; };
  ledc_mode_t speed_mode() { return ledc_channel_.speed_mode; };
  uint32_t duty_max() { return duty_max_; };
  uint32_t duty_min() { return duty_min_; };
  gpio_num_t gpio_pin() { return gpio_pin_; };

  const char *externalName();
  esp_err_t lastRC() { return last_rc_; };

  const gpio_num_t *pins() { return pins_; }

  // info / debug functions
  const unique_ptr<char[]> debug();
};
} // namespace mcr

#endif // pwm_dev_hpp
