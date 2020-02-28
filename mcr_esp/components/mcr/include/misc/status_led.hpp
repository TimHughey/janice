/*
    mcr_restart.hpp -- MCR abstraction for esp_restart()
    Copyright (C) 2019  Tim Hughey

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

#ifndef status_led_hpp
#define status_led_hpp

#include <sys/time.h>
#include <time.h>

#include <esp_log.h>

#include <driver/gpio.h>
#include <driver/ledc.h>
#include <esp_system.h>

namespace mcr {

typedef class statusLED statusLED_t;

class statusLED {
public:
  static statusLED_t *instance();
  static void duty(uint32_t duty);

  void bright();
  void brighter();
  void dimmer();
  void dim();
  void off();

private:
  statusLED(); // SINGLETON!  constructor is private

  void activate_duty();

private:
  uint32_t duty_ = 128; // initial duty is very dim

  ledc_timer_config_t ledc_timer_ = {.speed_mode = LEDC_HIGH_SPEED_MODE,
                                     .duty_resolution = LEDC_TIMER_13_BIT,
                                     .timer_num = LEDC_TIMER_0,
                                     .freq_hz = 5000,
                                     .clk_cfg = LEDC_AUTO_CLK};

  ledc_channel_config_t ledc_channel_ = {.gpio_num = GPIO_NUM_13,
                                         .speed_mode = LEDC_HIGH_SPEED_MODE,
                                         .channel = LEDC_CHANNEL_0,
                                         .intr_type = LEDC_INTR_DISABLE,
                                         .timer_sel = LEDC_TIMER_0,
                                         .duty = duty_,
                                         .hpoint = 0};
};
} // namespace mcr

#endif
