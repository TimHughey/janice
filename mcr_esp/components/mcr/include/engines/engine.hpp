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
#include <map>
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

using namespace mcr;

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

typedef struct {
  EventBits_t need_bus;
  EventBits_t engine_running;
  EventBits_t devices_available;
  EventBits_t temp_available;
  EventBits_t temp_sensors_available;
} engineEventBits_t;

template <class DEV> class mcrEngine {

private:
  std::vector<DEV *> _devices;
  uint32_t _dev_count = 0;
  uint32_t _next_known_index = 0;

  xTaskHandle _engine_task = nullptr;
  EventGroupHandle_t _evg;
  SemaphoreHandle_t _bus_mutex = nullptr;

  mcrEngineMetrics_t metrics;
  typedef std::pair<std::string, mcrEngineMetric_t *> metricEntry_t;
  typedef std::map<std::string, mcrEngineMetric_t *> metricMap_t;

  engineEventBits_t _event_bits = {.need_bus = BIT0,
                                   .engine_running = BIT1,
                                   .devices_available = BIT2,
                                   .temp_available = BIT3,
                                   .temp_sensors_available = BIT4};

  // Task implementation
  static void runEngine(void *task_instance) {
    mcrEngine *task = (mcrEngine *)task_instance;

    task->run(task->_engine_task_data);
  }

public:
  mcrEngine() {
    _evg = xEventGroupCreate();
    _bus_mutex = xSemaphoreCreateMutex();
  };
  virtual ~mcrEngine(){};

  // task methods
  xTaskHandle taskHandle() { return _engine_task; }
  void delay(int ms) { ::vTaskDelay(pdMS_TO_TICKS(ms)); }

  virtual void run(void *data) = 0;
  virtual void suspend() {
    ESP_LOGW(tagEngine(), "suspending self(%p)", this->_engine_task);
    vTaskSuspend(this->_engine_task);
  };

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

  void stop() {
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
      ESP_LOGD(tagEngine(), "just saw: %s", dev.debug().get());
    }

    if (found_dev) {
      if (found_dev->missing()) {
        ESP_LOGW(tagEngine(), "device returned %s", found_dev->debug().get());
      }

      found_dev->justSeen();
    }

    return found_dev;
  };

  bool addDevice(DEV *dev) {
    auto rc = false;
    DEV *found = nullptr;

    if (LOG_LOCAL_LEVEL >= ESP_LOG_DEBUG) {
      ESP_LOGD(tagEngine(), "adding: %s", dev->debug().get());
    }

    if (numKnownDevices() > maxDevices()) {
      ESP_LOGW(tagEngine(), "attempt to exceed max devices!");
      return rc;
    }

    if ((found = findDevice(dev->id())) == nullptr) {
      dev->justSeen();
      _devices.push_back(dev);
      ESP_LOGI(tagEngine(), "added %s", dev->debug().get());
    }

    return (found == nullptr) ? true : false;
  };

  DEV *findDevice(const std::string &dev) {

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
  bool isDeviceKnown(const std::string &id) {
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

  // event group bits
  EventBits_t engineBit() { return _event_bits.engine_running; }
  EventBits_t needBusBit() { return _event_bits.need_bus; }
  EventBits_t devicesAvailableBit() { return _event_bits.devices_available; }
  EventBits_t devicesOrTempSensorsBit() {
    return (_event_bits.devices_available | _event_bits.temp_sensors_available);
  }
  EventBits_t tempSensorsAvailableBit() {
    return _event_bits.temp_sensors_available;
  }
  EventBits_t temperatureAvailableBit() { return _event_bits.temp_available; }

  // event group
  void devicesAvailable(bool available) {
    if (available) {
      xEventGroupSetBits(_evg, _event_bits.devices_available);
    } else {
      xEventGroupClearBits(_evg, _event_bits.devices_available);
    }
  }
  void devicesUnavailable() {
    xEventGroupClearBits(_evg, _event_bits.devices_available);
  }

  void engineRunning() { xEventGroupSetBits(_evg, _event_bits.engine_running); }
  bool isBusNeeded() {
    EventBits_t bits = xEventGroupGetBits(_evg);
    return (bits & needBusBit());
  }
  void needBus() { xEventGroupSetBits(_evg, needBusBit()); }
  void releaseBus() { xEventGroupClearBits(_evg, needBusBit()); }
  void tempAvailable() { xEventGroupSetBits(_evg, _event_bits.temp_available); }
  void tempUnavailable() {
    xEventGroupClearBits(_evg, _event_bits.temp_available);
  }
  void temperatureSensors(bool available) {
    if (available) {
      xEventGroupSetBits(_evg, _event_bits.temp_sensors_available);
    } else {
      xEventGroupClearBits(_evg, _event_bits.temp_sensors_available);
    }
  }

  EventBits_t waitFor(EventBits_t bits, TickType_t wait_ticks = portMAX_DELAY,
                      bool clear_bits = false) {

    EventBits_t set_bits = xEventGroupWaitBits(
        _evg, bits,
        (clear_bits ? pdTRUE : pdFALSE), // clear bits (if set while waiting)
        pdTRUE, // wait for all bits, not really needed here
        wait_ticks);

    return (set_bits);
  }

  // semaphore
  void giveBus() { xSemaphoreGive(_bus_mutex); }
  void takeBus(TickType_t wait_ticks = portMAX_DELAY) {
    xSemaphoreTake(_bus_mutex, wait_ticks);
  }

  bool publish(mcrCmdSwitch_t &cmd) { return publish(cmd.dev_id()); };
  bool publish(const std::string &dev_id) {
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
    std::string &dev_id = cmd.dev_id();

    return readDevice(dev_id);
  };

  // virtual bool readDevice(DEV *);

  bool readDevice(const std::string &id) {
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

public:
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
protected:
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
    auto const max_len = 319;

    // allocate from the heap to minimize task stack impact
    unique_ptr<char[]> debug_str(new char[max_len + 1]);
    unique_ptr<metricMap_t> map_ptr(new metricMap_t);

    // get pointers to increase code readability
    char *str = debug_str.get();
    metricMap_t *map = map_ptr.get();

    // null terminate the char array for use as string buffer
    str[0] = 0x00;

    map->insert({"convert", &(metrics.convert)});
    map->insert({"discover", &(metrics.discover)});
    map->insert({"report", &(metrics.report)});
    map->insert({"switch_cmd", &(metrics.switch_cmd)});

    // append stats that are non-zero
    for_each(map->begin(), map->end(), [this, str](metricEntry_t item) {
      std::string &metric = item.first;
      uint64_t val = (item.second)->elapsed_us;

      if (val > 0) {
        auto curr_len = strlen(str);
        char *s = str + curr_len;
        auto max = max_len - curr_len;

        snprintf(s, max, "%s(%0.2lfms) ", metric.c_str(),
                 (float)(val / 1000.0));
      }
    });

    ESP_LOGI(tagPhase(), "metrics %s", str);
  };
};

#endif // mcp_engine_h
