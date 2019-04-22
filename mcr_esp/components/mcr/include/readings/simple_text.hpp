/*
    simple_text.hpp -- Simple Text (aka Log) Reading
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

#ifndef text_reading_hpp
#define text_reading_hpp

#include <string>

#include <external/ArduinoJson.h>
#include <sys/time.h>
#include <time.h>

#include "readings/reading.hpp"

typedef class textReading textReading_t;
#define MAX_LEN 128

class textReading : public Reading {
private:
  char *_text = nullptr;

public:
  textReading(const char *text = nullptr);
  ~textReading();

  const char *text() { return _text; };

  static uint8_t maxLength() { return MAX_LEN; };

protected:
  virtual void populateJSON(JsonObject &root);
};

#endif // text_reading_hpp
