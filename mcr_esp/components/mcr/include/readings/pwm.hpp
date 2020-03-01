/*
    pwm.hpp - Master Control Remote PWM Reading
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

#ifndef pwm_reading_hpp
#define pwm_reading_hpp

#include <freertos/FreeRTOS.h>
#include <sys/time.h>
#include <time.h>

#include "readings/reading.hpp"

namespace mcr {
typedef class pwmReading pwmReading_t;

class pwmReading : public Reading {
private:
  // actual reading data
  uint32_t duty_max_ = 4095;
  uint32_t duty_min_ = 1;
  uint32_t duty_ = 0;

public:
  pwmReading(const std::string &id, time_t mtime, uint32_t duty_max,
             uint32_t duty_min, uint32_t duty);

protected:
  virtual void populateJSON(JsonDocument &doc);
};

} // namespace mcr
#endif // __cplusplus
