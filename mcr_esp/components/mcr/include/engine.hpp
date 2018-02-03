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
#include <iomanip>
#include <sstream>
#include <string>
#include <vector>

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

template <class DEV> class mcrEngine {

private:
  std::vector<DEV *> _devices;
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
  mcrEngine(){}; // nothing to see here

  static uint32_t maxDevices() { return MAX_DEVICES_PER_ENGINE; };

  // functions for handling known devices
  // mcrDev_t *findDevice(mcrDev_t &dev);

  // justSeenDevice():
  //    will return true if the device was found
  //    and call justSeen() on the device if found
  DEV *justSeenDevice(DEV &dev) {
    DEV *found_dev = findDevice(dev.id());

    if (LOG_LOCAL_LEVEL >= ESP_LOG_DEBUG) {
      ESP_LOGD(_engTAG, "just saw: %s", dev.debug().c_str());
    }

    if (found_dev != nullptr) {
      found_dev->justSeen();
    }

    return found_dev;
  };

  bool addDevice(DEV *dev) {
    auto rc = false;
    DEV *found = nullptr;

    if (LOG_LOCAL_LEVEL >= ESP_LOG_DEBUG) {
      ESP_LOGD(_engTAG, "adding: %s", dev->debug().c_str());
    }

    if (numKnownDevices() > maxDevices()) {
      ESP_LOGW(_engTAG, "attempt to exceed max devices!");
      return rc;
    }

    if ((found = findDevice(dev->id())) == nullptr) {
      _devices.push_back(dev);
      ESP_LOGI(_engTAG, "added (%p) %s", (void *)dev, dev->debug().c_str());
    }

    return (found == nullptr) ? true : false;
  };

  DEV *findDevice(const mcrDevID_t &dev) {
    DEV *found = nullptr;

    for (auto search : _devices) {
      if (search->id() == dev) {
        found = search;
        break;
      }
    }

    return found;
  }

  auto knownDevices() -> typename std::vector<DEV *>::iterator {
    return _devices.begin();
  }
  bool endOfDevices(typename std::vector<DEV *>::iterator it) {
    return it == _devices.end();
  };

  bool moreDevices(typename std::vector<DEV *>::iterator it) {
    return it != _devices.end();
  };

  uint32_t numKnownDevices() { return _devices.size(); };
  bool isDeviceKnown(const mcrDevID_t &id) {
    bool rc = false;

    rc = (findDevice(id) == nullptr ? false : true);
    return rc;
  };

protected:
  mcrMQTT_t *_mqtt = nullptr;
  const char *_engTAG;
  const char *_conTAG;
  const char *_cmdTAG;
  const char *_disTAG;
  const char *_repTAG;

  // virtual bool discover();
  // virtual bool convert();
  // virtual bool report();
  //
  // virtual bool cmd();
  // virtual bool cmdAck();

  DEV *getDeviceByCmd(mcrCmd_t &cmd) {
    DEV *dev = findDevice(cmd.dev_id());
    return dev;
  };

  DEV *getDeviceByCmd(mcrCmd_t *cmd) {
    DEV *dev = findDevice(cmd->dev_id());
    return dev;
  };

  bool publish(mcrCmd_t &cmd) { return publish(cmd.dev_id()); };
  bool publish(const mcrDevID_t &dev_id) {
    DEV *search = findDevice(dev_id);

    if (search != nullptr) {
      return publish(search);
    }

    return false;
  };

  bool publish(DEV *dev) {
    bool rc = true;

    if (dev != nullptr) {
      Reading_t *reading = dev->reading();

      if (reading != nullptr) {
        publish(reading);
        rc = true;
      }
    }
    return rc;
  };

  bool publish(Reading_t *reading) {
    auto rc = false;

    if (reading) {
      _mqtt->publish(reading);
    }

    return rc;
  };

  bool readDevice(mcrCmd_t &cmd) {
    mcrDevID_t &dev_id = cmd.dev_id();

    return readDevice(dev_id);
  };

  // virtual bool readDevice(DEV *);

  bool readDevice(const mcrDevID_t &id) {
    DEV *dev = findDevice(id);

    if (dev != nullptr) {
      readDevice(dev);
    }

    return (dev == nullptr) ? false : true;
  }

  void setCmdAck(mcrCmd_t &cmd) {
    DEV *dev = findDevice(cmd.dev_id());

    if (dev != nullptr) {
      dev->setReadingCmdAck(cmd.latency(), cmd.refID());
    }
  };

  // misc metrics tracking

  int64_t trackPhase(const char *lTAG, mcrEngineMetric_t &phase, bool start) {
    if (start) {
      phase.start_us = esp_timer_get_time();
      ESP_LOGI(lTAG, "phase started");
    } else {
      time_t recent_us = esp_timer_get_time() - phase.start_us;
      phase.elapsed_us = (phase.elapsed_us > 0)
                             ? ((phase.elapsed_us + recent_us) / 2)
                             : recent_us;
      phase.start_us = 0;
      phase.last_time = time(nullptr);
      ESP_LOGI(lTAG, "phase ended, took %lldms", phase.elapsed_us / 1000);
    }

    return phase.elapsed_us;
  };

  int64_t trackConvert(bool start = false) {
    return trackPhase(_conTAG, metrics.convert, start);
  };

  int64_t trackDiscover(bool start = false) {
    return trackPhase(_disTAG, metrics.discover, start);
  };

  int64_t trackReport(bool start = false) {
    return trackPhase(_repTAG, metrics.report, start);
  };

  int64_t trackSwitchCmd(bool start = false) {
    return trackPhase(_cmdTAG, metrics.switch_cmd, start);
  };

  int64_t convertUS() { return metrics.convert.elapsed_us; };
  int64_t discoverUS() { return metrics.discover.elapsed_us; };
  int64_t reportUS() { return metrics.report.elapsed_us; };
  int64_t switchCmdUS() { return metrics.switch_cmd.elapsed_us; };

  time_t lastConvertTimestamp() { return metrics.convert.last_time; };
  time_t lastDiscoverTimestamp() { return metrics.discover.last_time; };
  time_t lastReportTimestamp() { return metrics.report.last_time; };
  time_t lastSwitchCmdTimestamp() { return metrics.switch_cmd.last_time; };

  void runtimeMetricsReport(const char *lTAG) {
    typedef struct {
      const char *tag;
      mcrEngineMetric_t *metric;
    } metricDef_t;

    std::ostringstream rep_str;

    metricDef_t m[] = {{"convert", &(metrics.convert)},
                       {"discover", &(metrics.discover)},
                       {"report", &(metrics.report)},
                       {"switch_cmd", &(metrics.switch_cmd)}};

    for (int i = 0; i < (sizeof(m) / sizeof(metricDef_t)); i++) {
      if (m[i].metric->elapsed_us > 0) {
        rep_str << m[i].tag << "=";
        rep_str << std::fixed << std::setprecision(2)
                << ((float)(m[i].metric->elapsed_us / 1000.0));
        rep_str << "ms ";
      }
    }

    ESP_LOGI(lTAG, "phase metrics: %s", rep_str.str().c_str());
  };
};

#endif // mcp_engine_h
