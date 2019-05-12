/*
    simple_text.cpp - Simple Text (aka Log) Reading
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
#include <string>

#include <sys/time.h>
#include <time.h>

#include "readings/simple_text.hpp"

namespace mcr {
textReading::textReading(const char *text) {

  _type = ReadingType_t::TEXT;

  if (text == nullptr) {
    _text = nullptr;
  } else {
    _text = strndup(text, maxLength());
  }
}

textReading::textReading(msg_buff_t &buff) {
  _do_free = false;
  _text = buff.get();
}

textReading::~textReading() {
  if ((_do_free) && (_text != nullptr))
    free(_text);
}

void textReading::populateJSON(JsonDocument &doc) {
  doc["text"] = _text;
  doc["log"] = true;
}
} // namespace mcr
