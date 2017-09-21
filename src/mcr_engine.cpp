/*
    mcpr_engine.cpp - Master Control Remote Engine
    Copyright (C) 2017  Tim Hughey

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

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include <OneWire.h>

#include "mcr_engine.hpp"
#include "reading.hpp"

mcrEngine::mcrEngine(mcrMQTT *mqtt) {

  this->mqtt = mqtt;
  this->debugMode = false;

  // setting last_discover to the discover interval will
  // prevent a delay for first discovery cycle at startup
  last_discover = DISCOVER_INTERVAL_MILLIS;

  discover_interval_millis = DISCOVER_INTERVAL_MILLIS;
  last_device_report = 0;
  last_convert = 0;
  _dev_count = 0;
  state = IDLE;
}

boolean mcrEngine::init() {
  boolean rc = true;

  return rc;
}

boolean mcrEngine::loop() {
  // reset the overall loop runtime
  // this is used across methods to constrain mcrEngine::loop
  // within the time slice defined to prevent unacceptable
  // delays in the overall loop
  loop_runtime = 0;

  // while (timesliceRemaining()) {
  discover();
  convert();
  deviceReport();
  //}

  //  if (state != IDLE) {
  //    Serial.print("  mcrEngine::loop end state = ");
  //    Serial.println(state);
  //  }

  return true;
}

// mcrEngine::discover()
// this method should be called often to ensure proper operator.
//
//  1. if the enough millis have elapsed since the last full discovery
//     this method then it will start a new discovery.
//  2. if a discovery cycle is in-progress this method will execute
//     a single search

boolean mcrEngine::discover() {
  auto rc = true;

  if (needDiscover()) {
    if (isIdle()) {
      state = DISCOVER;
      discover_elapsed = 0;
    } else {
      state = IDLE;
      last_discover_millis = discover_elapsed;
      last_discover = 0;
    }
  }

  return rc;
}

boolean mcrEngine::deviceReport() {
  boolean rc = true;

  if (needDeviceReport()) {
    last_device_report = 0;
  }

  return rc;
}

// mcrEngine::temp_convert()
// this method should be called often to ensure proper operator.
//
//  1. if enough millis have elapsed since the last temperature
//     conversion then a new one will be started if mcrEngine is
//     idle
//  2. if a temperature conversion is in-progress this method will
//     do a single check to determine if conversion is finished

boolean mcrEngine::convert() {
  boolean rc = true;

  if (needConvert()) {
    // start a temperature conversion if one isn't already in-progress
    // TODO - only handles powered devices as of 2017-09-11
    if (isIdle()) {
      // reset the temperature conversion elapsed millis
      convert_elapsed = 0;

      state = CONVERT;
    } else {
      state = IDLE;
      last_convert = 0;
      convert_timestamp = now();
    }
  }
  return rc;
}

boolean mcrEngine::needDiscover() {
  boolean rc = false;

  if (timesliceExpired()) {
    return false;
  }

  if (isDiscoveryActive()) {
    rc = true;
  } else if (isIdle() && (last_discover >= discover_interval_millis)) {
    rc = true;
  }

  return rc;
}

boolean mcrEngine::needDeviceReport() {
  boolean rc = false;

  if (timesliceExpired()) {
    return false;
  }

  if (isDeviceReportActive()) {
    rc = true;
  } else if (isIdle() && (last_device_report >= last_convert)) {
    rc = true;
  }

  return rc;
}

boolean mcrEngine::needConvert() {
  boolean rc = false;

  if (timesliceExpired()) {
    return false;
  }

  if (isConvertActive()) {
    rc = true;
  } else if (isIdle() && (last_convert >= CONVERT_INTERVAL_MILLIS)) {
    rc = true;
  }

  return rc;
}

// timeslice helper methods
boolean mcrEngine::timesliceRemaining() {
  return (loop_runtime <= LOOP_TIMESLICE_MILLIS) ? true : false;
}

boolean mcrEngine::timesliceExpired() {
  return (loop_runtime > LOOP_TIMESLICE_MILLIS) ? true : false;
}

// state helper methods (grouped together for readability)
boolean mcrEngine::isDiscoveryActive() {
  return state == DISCOVER ? true : false;
}

boolean mcrEngine::isIdle() { return state == IDLE ? true : false; }

boolean mcrEngine::isDeviceReportActive() {
  return state == DEVICE_REPORT ? true : false;
}

boolean mcrEngine::isConvertActive() { return state == CONVERT ? true : false; }
