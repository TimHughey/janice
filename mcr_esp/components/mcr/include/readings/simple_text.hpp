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

#include <esp_log.h>
#include <stdarg.h>
#include <sys/time.h>
#include <time.h>

#include "misc/mcr_types.hpp"
#include "readings/reading.hpp"

namespace mcr {
typedef class textReading textReading_t;

typedef std::unique_ptr<textReading_t> textReading_ptr_t;

class textReading : public Reading {
public:
  textReading();
  textReading(const char *text);
  ~textReading();

  char *append() { return _append_text; };
  uint32_t availableBytes() { return _remaining_bytes; };
  char *buff() { return _actual; };

  void consoleInfo(const char *tag);
  void consoleErr(const char *tag);
  void consoleWarn(const char *tag);

  static uint32_t maxLength() { return _max_len; };
  void printf(const char *format, ...);
  void printf(struct tm *timeinfo, const char *format, ...);
  void publish();
  void reuse() {
    _actual[0] = 0x00;
    _remaining_bytes = _max_len;
    _append_text = _actual;
  }
  char *text() { return _actual; };
  void use(size_t bytes) {
    _append_text += bytes;
    _remaining_bytes -= bytes;
  };

private:
  static const uint32_t _max_len = 640;

  char _actual[_max_len + 1];
  char *_append_text = _actual;
  uint32_t _remaining_bytes = _max_len;

  void init() {
    _type = ReadingType_t::TEXT;
    _actual[0] = 0x00; // null terminate the buffer
  }

protected:
  virtual void populateJSON(JsonDocument &doc);
}; // namespace mcr
} // namespace mcr

#endif // text_reading_hpp
