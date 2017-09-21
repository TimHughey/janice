/*
    mcpr_engine.h - Master Control Remote Dallas Semiconductor
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

#ifndef mcr_engine_h
#define mcr_engine_h

#ifdef __cplusplus

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include <OneWire.h>
#include <TimeLib.h>
#include <elapsedMillis.h>

#include "mcr_mqtt.hpp"

#define mcr_engine_version_1 1

// Set the version of MCP Remote
#ifndef mcr_engine_version
#define mcr_engine_version mcr_engine_version_1
#endif

#ifndef MAX_DEVICES_PER_ENGINE
// max devices supported by all mcrEngine
// implementation
#define MAX_DEVICES_PER_ENGINE 30
#endif

#define LOOP_TIMESLICE_MILLIS (time_t)30

#define DISCOVER_INTERVAL_MILLIS (time_t)30000
#define MAX_DISCOVER_RUN_MILLIS (time_t)100

#define CONVERT_INTERVAL_MILLIS (time_t)7000
#define CONVERT_RUN_MILLIS (time_t)20
#define CONVERT_TIMEOUT (time_t)800

#define DEVICE_REPORT_INTERVAL_MILLIS (time_t)11000

class mcrEngine {
public:
  mcrEngine(mcrMQTT *mqtt);

  virtual boolean init();
  virtual boolean loop();

  const static uint16_t maxDevices() { return MAX_DEVICES_PER_ENGINE; };

  boolean isIdle();
  boolean isDiscoveryActive();
  boolean isConvertActive();
  boolean isDeviceReportActive();

  typedef enum {
    IDLE,
    INIT,
    DISCOVER,
    CONVERT,
    DEVICE_REPORT,
    SET_SWITCHES,
    STATS_REPORT
  } state_t;

private:
  uint16_t _dev_count = 0;

protected:
  virtual boolean discover();
  virtual boolean convert();
  virtual boolean deviceReport();

  void addDevice() { _dev_count += 1; };
  uint16_t devCount() { return _dev_count; };
  virtual void clearKnownDevices() { _dev_count = 0; };

  inline void idle() { state = IDLE; }

  // timeslice methoengine
  boolean timesliceRemaining();
  boolean timesliceExpired();

  // state helper methods
  boolean needDiscover();
  boolean needConvert();
  boolean needDeviceReport();

  time_t loopRunTime() { return loop_runtime; };

  mcrMQTT *mqtt;
  boolean debugMode;

  state_t state;
  elapsedMillis last_convert;
  elapsedMillis last_device_report;

  elapsedMillis loop_runtime;
  elapsedMillis last_discover;
  elapsedMillis discover_elapsed;

  unsigned long last_discover_millis;
  unsigned long last_convert_millis;
  unsigned long discover_interval_millis;

  time_t convert_timestamp;
  elapsedMillis convert_elapsed;

  static const uint8_t max_devices = MAX_DEVICES_PER_ENGINE;
};

#endif // __cplusplus
#endif // mcp_engine_h
