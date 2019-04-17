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

#include <algorithm>
#include <cstdlib>
#include <iomanip>
#include <map>
#include <sstream>
#include <string>
#include <vector>

#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/task.h>
#include <sdkconfig.h>

#include "cmds/cmd_switch.hpp"
#include "devs/base.hpp"
#include "misc/mcr_types.hpp"
#include "protocols/mqtt.hpp"
#include "readings/readings.hpp"

typedef std::map<std::string, std::string> mcrEngineTagMap_t;
typedef std::pair<std::string, std::string> mcrEngineTagItem_t;

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

  xTaskHandle _engine_task = nullptr;

  mcrEngineMetrics_t metrics;

  // Task implementation
  static void runEngine(void *task_instance) {
    mcrEngine *task = (mcrEngine *)task_instance;
    task->run(task->_engine_task_data);
  }

public:
  mcrEngine(){}; // nothing to see here
  virtual ~mcrEngine(){};

  // task methods
  void delay(int ms) { ::vTaskDelay(pdMS_TO_TICKS(ms)); }

  virtual void run(void *data) = 0;

  void start(void *task_data = nullptr) {
    if (_engine_task != nullptr) {
      ESP_LOGW(tagEngine(), "task already running %p", (void *)_engine_task);
    }

    // this (object) is passed as the data to the task creation and is
    // used by the static runEngine method to call the implemented run
    // method
    ::xTaskCreate(&runEngine, _engine_task_name.c_str(), _engine_stack_size,
                  this, _engine_priority, &_engine_task);
  }

  virtual void stop() {
    if (_engine_task == nullptr) {
      return;
    }

    ESP_LOGW(tagEngine(), "task stopping, goodbye");

    xTaskHandle task = _engine_task;
    _engine_task = nullptr;
    ::vTaskDelete(task);
  }

  // FIXME: move to external config
  static uint32_t maxDevices() { return 100; };

  bool any_of_devices(bool (*func)(const DEV &)) {
    return std::any_of(_devices.cbegin(), _devices.cend(), func);
  }

  // functions for handling known devices
  // mcrDev_t *findDevice(mcrDev_t &dev);

  // justSeenDevice():
  //    will return true if the device was found
  //    and call justSeen() on the device if found
  DEV *justSeenDevice(DEV &dev) {
    DEV *found_dev = findDevice(dev.id());

    if (LOG_LOCAL_LEVEL >= ESP_LOG_DEBUG) {
      ESP_LOGD(tagEngine(), "just saw: %s", dev.debug().c_str());
    }

    if (found_dev) {
      if (found_dev->missing()) {
        ESP_LOGW(tagEngine(), "device returned %s", found_dev->debug().c_str());
      }

      found_dev->justSeen();
    }

    return found_dev;
  };

  bool addDevice(DEV *dev) {
    auto rc = false;
    DEV *found = nullptr;

    if (LOG_LOCAL_LEVEL >= ESP_LOG_DEBUG) {
      ESP_LOGD(tagEngine(), "adding: %s", dev->debug().c_str());
    }

    if (numKnownDevices() > maxDevices()) {
      ESP_LOGW(tagEngine(), "attempt to exceed max devices!");
      return rc;
    }

    if ((found = findDevice(dev->id())) == nullptr) {
      dev->justSeen();
      _devices.push_back(dev);
      ESP_LOGI(tagEngine(), "added %s", dev->debug().c_str());
    }

    return (found == nullptr) ? true : false;
  };

  DEV *findDevice(const mcrDevID_t &dev) {
    // DEV *search = nullptr;

    // my first lambda in C++, wow this languge has really evolved
    // since I used it 15+ years ago
    auto found =
        std::find_if(_devices.begin(), _devices.end(),
                     [dev](DEV *search) { return search->id() == dev; });

    if (found != _devices.end()) {
      return *found;
    }

    return nullptr;
  }

  auto beginDevices() -> typename std::vector<DEV *>::iterator {
    return _devices.begin();
  }

  auto endDevices() -> typename std::vector<DEV *>::iterator {
    return _devices.end();
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
  void *_engine_task_data;
  std::string _engine_task_name;
  uint16_t _engine_stack_size = 10000;
  uint16_t _engine_priority = 5;

  mcrEngineTagMap_t _tags;

  DEV *getDeviceByCmd(mcrCmdSwitch_t &cmd) {
    DEV *dev = findDevice(cmd.dev_id());
    return dev;
  };

  DEV *getDeviceByCmd(mcrCmdSwitch_t *cmd) {
    DEV *dev = findDevice(cmd->dev_id());
    return dev;
  };

  bool publish(mcrCmdSwitch_t &cmd) { return publish(cmd.dev_id()); };
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
      mcrMQTT::instance()->publish(reading);
    }

    return rc;
  };

  bool readDevice(mcrCmdSwitch_t &cmd) {
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

  void setCmdAck(mcrCmdSwitch_t &cmd) {
    DEV *dev = findDevice(cmd.dev_id());

    if (dev != nullptr) {
      dev->setReadingCmdAck(cmd.latency(), cmd.refID());
    }
  }

  void setLoggingLevel(const char *tag, esp_log_level_t level) {
    esp_log_level_set(tag, level);
  }

  void setLoggingLevel(esp_log_level_t level) {
    for_each(_tags.begin(), _tags.end(),
             [this, level](std::pair<std::string, std::string> item) {
               ESP_LOGD(_tags["engine"].c_str(),
                        "key=%s tag=%s logging at level=%d", item.first.c_str(),
                        item.second.c_str(), level);
               esp_log_level_set(item.second.c_str(), level);
             });
  }
  void setTags(mcrEngineTagMap_t &map) {
    std::string phase_tag = map["engine"] + " phase";

    _tags = map;
    _tags["phase"] = phase_tag;
  }

  const char *tagCommand() {
    static const char *tag = nullptr;
    if (tag == nullptr) {
      tag = _tags["command"].c_str();
    }
    return tag;
  }

  const char *tagConvert() {
    static const char *tag = nullptr;
    if (tag == nullptr) {
      tag = _tags["convert"].c_str();
    }
    return tag;
  }

  const char *tagDiscover() {
    static const char *tag = nullptr;
    if (tag == nullptr) {
      tag = _tags["discover"].c_str();
    }
    return tag;
  }

  const char *tagEngine() {
    static const char *tag = nullptr;
    if (tag == nullptr) {
      tag = _tags["engine"].c_str();
    }
    return tag;
  }

  const char *tagPhase() {
    static const char *tag = nullptr;
    if (tag == nullptr) {
      tag = _tags["phase"].c_str();
    }
    return tag;
  }

  const char *tagReport() {
    static const char *tag = nullptr;
    if (tag == nullptr) {
      tag = _tags["report"].c_str();
    }
    return tag;
  }

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
    return trackPhase(tagConvert(), metrics.convert, start);
  };

  int64_t trackDiscover(bool start = false) {
    return trackPhase(tagDiscover(), metrics.discover, start);
  };

  int64_t trackReport(bool start = false) {
    return trackPhase(tagReport(), metrics.report, start);
  };

  int64_t trackSwitchCmd(bool start = false) {
    return trackPhase(tagCommand(), metrics.switch_cmd, start);
  };

  int64_t convertUS() { return metrics.convert.elapsed_us; };
  int64_t discoverUS() { return metrics.discover.elapsed_us; };
  int64_t reportUS() { return metrics.report.elapsed_us; };
  int64_t switchCmdUS() { return metrics.switch_cmd.elapsed_us; };

  time_t lastConvertTimestamp() { return metrics.convert.last_time; };
  time_t lastDiscoverTimestamp() { return metrics.discover.last_time; };
  time_t lastReportTimestamp() { return metrics.report.last_time; };
  time_t lastSwitchCmdTimestamp() { return metrics.switch_cmd.last_time; };

  void reportMetrics() {
    mcr::EngineReading reading(tagEngine(), discoverUS(), convertUS(),
                               reportUS(), switchCmdUS());

    if (reading.hasNonZeroValues()) {
      publish(&reading);
      metrics.convert.elapsed_us = 0LL;
      metrics.discover.elapsed_us = 0LL;
      metrics.report.elapsed_us = 0LL;
      metrics.switch_cmd.elapsed_us = 0LL;
    } else {
      ESP_LOGW(tagEngine(), "all metrics are zero");
    }
  }

  void runtimeMetricsReport() {
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

    ESP_LOGI(tagPhase(), "metrics: %s", rep_str.str().c_str());
  };
};

#endif // mcp_engine_h
