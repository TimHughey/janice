/*
    engine.hpp - Master Control Remote Dallas Semiconductor
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

#include <cstdlib>
#include <map>
#include <string>

#include <FreeRTOS.h>
#include <System.h>
#include <Task.h>

#include <esp_log.h>
#include <freertos/event_groups.h>

#include "base.hpp"
#include "cmd.hpp"
#include "mcr_types.hpp"
#include "mqtt.hpp"
#include "util.hpp"

#define mcr_engine_version_1 1

// Set the version of MCP Remote
#ifndef mcr_engine_version
#define mcr_engine_version mcr_engine_version_1
#endif

// max devices supported by all mcrEngine
// implementation
// define this prior to the first include of this header
// to increase
#ifndef MAX_DEVICES_PER_ENGINE
#define MAX_DEVICES_PER_ENGINE 30
#endif

typedef struct mcrEngineMetric {
  int64_t start_us = 0;
  int64_t elapsed_us = 0;
  time_t last_time = 0;
} mcrEngineMetric_t;

typedef struct mcrEngineMetrics {
  mcrEngineMetric_t discover;
  mcrEngineMetric_t convert;
  mcrEngineMetric_t report;
  mcrEngineMetric_t switch_cmd;
  mcrEngineMetric_t switch_cmdack;
} mcrEngineMetrics_t;

typedef class mcrEngine mcrEngine_t;

class mcrEngine {
private:
  std::map<mcrDevID, mcrDev *> _dev_map;
  mcrDev_t *_known_devs[MAX_DEVICES_PER_ENGINE] = {0x00};
  uint32_t _dev_count = 0;
  uint32_t _next_known_index = 0;

  // Engine runtime controls
  uint32_t _loop_timeslice_ms = 5;
  uint32_t _discover_interval_ms = 30000;
  uint32_t _convert_interval_ms = 9000;
  uint32_t _report_interval_ms = 11000;
  uint32_t _stats_inverval_ms = 20000;

  uint32_t _discover_timeout_ms = 10000;
  uint32_t _convert_timeout_ms = 3000;
  uint32_t _report_timeout_ms = 10000;

  mcrEngineMetrics_t metrics;

  // Engine runtime tracking by state
  uint32_t _last_convert_ms = 0;
  uint32_t _last_report_ms = 0;
  uint32_t _last_cmd_ms = 0;
  uint32_t _last_ackcmd_ms = 0;
  uint32_t _last_stats_ms = 0;
  time_t _last_convert_timestamp = 0;

public:
  mcrEngine(mcrMQTT *mqtt);

  virtual bool init();
  bool init(void *p);

  static uint32_t maxDevices();

  // functions for handling known devices
  mcrDev_t *findDevice(mcrDev_t &dev);
  bool isDeviceKnown(mcrDevID_t &id);

  // justSeenDevice():
  //    will return true if the device was found
  //    and call justSeen() on the device if found
  mcrDev_t *justSeenDevice(mcrDev_t &dev);

  // addDevice():
  //    will add a device to the known devices
  bool addDevice(mcrDev_t *dev);

  bool knowDevice(mcrDev_t &dev);
  bool forgetDevice(mcrDev_t &dev);

  // yes, yes... this is a poor man's iterator
  mcrDev_t *getFirstKnownDevice();
  mcrDev_t *getNextKnownDevice();
  mcrDev_t *getDevice(mcrDevAddr_t &addr);
  mcrDev_t *getDevice(const mcrDevID_t &id);
  uint32_t numKnownDevices();

protected:
  mcrMQTT *_mqtt = nullptr;

  virtual bool discover();
  virtual bool convert();
  virtual bool report();

  virtual bool cmd();
  virtual bool cmdAck();

  bool publish(Reading_t *reading);

  uint32_t devCount();

  int64_t trackPhase(mcrEngineMetric_t &metric, bool start);

  int64_t trackConvert(bool start = false);
  int64_t convertUS();
  time_t lastConvertTimestamp();

  int64_t trackDiscover(bool start = false);
  int64_t discoverUS();
  time_t lastDiscoverTimestamp();

  int64_t trackReport(bool start = false);
  int64_t reportUS();
  time_t lastReportTimestamp();

  int64_t trackSwitchCmd(bool start = false);
  int64_t switchCmdUS();
  time_t lastSwitchCmdTimestamp();

  void runtimeMetricsReport(const char *lTAG);
};

#endif // mcp_engine_h
