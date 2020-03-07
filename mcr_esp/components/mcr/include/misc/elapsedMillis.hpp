/* Elapsed time types - for easy-to-use measurements of elapsed time
 * http://www.pjrc.com/teensy/
 * Copyright (c) 2011 PJRC.COM, LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#ifndef elapsedMillis_h
#define elapsedMillis_h
#ifdef __cplusplus

#include <cstdint>

#include <esp_log.h>
#include <esp_timer.h>

namespace mcr {

class elapsedMillis {
private:
  uint64_t ms;
  bool _freeze = false;

  inline uint64_t millis() const { return (esp_timer_get_time() / 1000); };

public:
  elapsedMillis(void) { ms = millis(); }
  // elapsedMillis(uint64_t val) { ms = millis() - val; }
  elapsedMillis(const elapsedMillis &orig) { ms = orig.ms; }
  float asSeconds() {
    return (_freeze) ? (float)(ms / 1000.0)
                     : ((float)((millis() - ms) / 1000.0));
  }
  void freeze(uint32_t val = UINT32_MAX) {
    _freeze = true;
    ms = (val == UINT32_MAX) ? (millis() - ms) : val;
  }
  void reset() {
    _freeze = false;
    ms = millis();
  }
  operator uint64_t() const { return (_freeze) ? (ms) : (millis() - ms); }
  elapsedMillis &operator=(const elapsedMillis &rhs) {
    ms = rhs.ms;
    return *this;
  }
  elapsedMillis &operator=(uint64_t val) {
    ms = millis() - val;
    return *this;
  }
  elapsedMillis &operator-=(uint64_t val) {
    ms += val;
    return *this;
  }
  elapsedMillis &operator+=(uint64_t val) {
    ms -= val;
    return *this;
  }
  elapsedMillis operator-(int val) const {
    elapsedMillis r(*this);
    r.ms += val;
    return r;
  }
  elapsedMillis operator-(unsigned int val) const {
    elapsedMillis r(*this);
    r.ms += val;
    return r;
  }
  elapsedMillis operator-(long val) const {
    elapsedMillis r(*this);
    r.ms += val;
    return r;
  }
  elapsedMillis operator-(uint64_t val) const {
    elapsedMillis r(*this);
    r.ms += val;
    return r;
  }
  elapsedMillis operator+(int val) const {
    elapsedMillis r(*this);
    r.ms -= val;
    return r;
  }
  elapsedMillis operator+(unsigned int val) const {
    elapsedMillis r(*this);
    r.ms -= val;
    return r;
  }
  elapsedMillis operator+(long val) const {
    elapsedMillis r(*this);
    r.ms -= val;
    return r;
  }
  elapsedMillis operator+(uint64_t val) const {
    elapsedMillis r(*this);
    r.ms -= val;
    return r;
  }
};

class elapsedMicros {
private:
  uint64_t us;
  bool _freeze = false;

  inline uint64_t micros() const { return (esp_timer_get_time()); };

public:
  elapsedMicros(void) { us = micros(); }
  // elapsedMicros(uint64_t val) { us = micros() - val; }
  elapsedMicros(const elapsedMicros &orig) {
    _freeze = orig._freeze;
    us = orig.us;
  }
  float asSeconds() {
    return (_freeze) ? (float)(us / 1000000.0)
                     : ((float)((micros() - us) / 1000000.0));
  }
  void freeze(uint32_t val = UINT32_MAX) {
    _freeze = true;
    us = (val == UINT32_MAX) ? (micros() - us) : val;
  }
  void reset() {
    _freeze = false;
    us = micros();
  }
  operator uint64_t() const { return (_freeze) ? (us) : (micros() - us); }
  elapsedMicros &operator=(const elapsedMicros &rhs) {
    us = rhs.us;
    _freeze = rhs._freeze;
    return *this;
  }
  elapsedMicros &operator=(uint64_t val) {
    us = micros() - val;
    return *this;
  }
  elapsedMicros &operator-=(uint64_t val) {
    us += val;
    return *this;
  }
  elapsedMicros &operator+=(uint64_t val) {
    us -= val;
    return *this;
  }
  elapsedMicros operator-(int val) const {
    elapsedMicros r(*this);
    r.us += val;
    return r;
  }
  elapsedMicros operator-(unsigned int val) const {
    elapsedMicros r(*this);
    r.us += val;
    return r;
  }
  elapsedMicros operator-(long val) const {
    elapsedMicros r(*this);
    r.us += val;
    return r;
  }
  elapsedMicros operator-(uint64_t val) const {
    elapsedMicros r(*this);
    r.us += val;
    return r;
  }
  elapsedMicros operator+(int val) const {
    elapsedMicros r(*this);
    r.us -= val;
    return r;
  }
  elapsedMicros operator+(unsigned int val) const {
    elapsedMicros r(*this);
    r.us -= val;
    return r;
  }
  elapsedMicros operator+(long val) const {
    elapsedMicros r(*this);
    r.us -= val;
    return r;
  }
  elapsedMicros operator+(uint64_t val) const {
    elapsedMicros r(*this);
    r.us -= val;
    return r;
  }
};

} // namespace mcr

#endif // __cplusplus
#endif // elapsedMillis_h
