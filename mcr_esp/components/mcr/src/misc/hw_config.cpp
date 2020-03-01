/*
    hw_config.cpp -- MCR Hardware Configuration Jumpers
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

#include "misc/hw_config.hpp"

namespace mcr {
static const char *TAG = "hwConfig";
static hwConfig_t *__singleton__ = nullptr;

hwConfig::hwConfig() {
  // setup hardware configuration jumpers
  gpio_config_t hw_conf_gpio;
  hw_conf_gpio.intr_type = GPIO_INTR_DISABLE;
  hw_conf_gpio.mode = GPIO_MODE_INPUT;
  hw_conf_gpio.pin_bit_mask = hw_gpio_pin_sel_;
  hw_conf_gpio.pull_down_en = GPIO_PULLDOWN_DISABLE;
  hw_conf_gpio.pull_up_en = GPIO_PULLUP_DISABLE;
  gpio_config(&hw_conf_gpio);

  uint8_t pins = 0;
  for (auto conf_bit = 0; conf_bit < 3; conf_bit++) {
    int level = gpio_get_level(hw_gpio_[conf_bit]);
    pins |= level << conf_bit;
  }

  hw_jumpers_ = (hardwareJumpers_t)pins;

  ESP_LOGI(TAG, "hardware jumpers [0x%02x]", hw_jumpers_);
}

// STATIC
hwConfig_t *hwConfig::instance() {
  if (__singleton__ == nullptr) {
    __singleton__ = new hwConfig();
  }

  return __singleton__;
}
} // namespace mcr
