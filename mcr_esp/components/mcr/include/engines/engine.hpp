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
#include <unordered_map>

#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <sdkconfig.h>

#include "cmds/cmd_queues.hpp"
#include "cmds/cmd_switch.hpp"
#include "devs/base.hpp"
#include "engines/types.hpp"
#include "misc/elapsedMillis.hpp"
#include "misc/mcr_types.hpp"
#include "protocols/mqtt.hpp"
#include "readings/readings.hpp"

namespace mcr {

template <class DEV> class mcrEngine {
private:
  TaskMap_t _task_map;

  typedef std::unordered_map<string_t, DEV *> DeviceMap_t;
  DeviceMap_t _devices;

  EventGroupHandle_t _evg;
  SemaphoreHandle_t _bus_mutex = nullptr;

  EngineMetrics_t metrics;

  engineEventBits_t _event_bits = {.need_bus = BIT0,
                                   .engine_running = BIT1,
                                   .devices_available = BIT2,
                                   .temp_available = BIT3,
                                   .temp_sensors_available = BIT4};

  //
  // Core Task Implementation
  //
  // to satisify C++ requiremeents we must wrap the object member function
  // in a static function
  static void runCore(void *task_instance) {
    mcrEngine *task = (mcrEngine *)task_instance;
    auto task_map = task->taskMap();
    auto *data = task_map[CORE]->_data;

    task->core(data);
  }

  //
  // Engine Sub Tasks
  //
  static void runConvert(void *task_instance) {
    mcrEngine *task = (mcrEngine *)task_instance;
    auto task_map = task->taskMap();
    auto *data = task_map[CONVERT];

    task->convert(data);
  }

  static void runDiscover(void *task_instance) {
    mcrEngine *task = (mcrEngine *)task_instance;
    auto task_map = task->taskMap();
    auto *data = task_map[DISCOVER];

    task->discover(data);
  }

  static void runReport(void *task_instance) {
    mcrEngine *task = (mcrEngine *)task_instance;
    auto task_map = task->taskMap();
    auto *data = task_map[REPORT];

    task->report(data);
  }

  static void runCommand(void *task_instance) {
    mcrEngine *task = (mcrEngine *)task_instance;
    auto task_map = task->taskMap();
    auto *data = task_map[COMMAND];

    task->command(data);
  }

  //
  // Default Do Nothing Task Implementation
  //
  void doNothing() {
    while (true) {
      vTaskDelay(pdMS_TO_TICKS(60 * 1000));
    }
  }

public:
  mcrEngine() {
    _evg = xEventGroupCreate();
    _bus_mutex = xSemaphoreCreateMutex();

    metrics.report.elapsed.freeze(0);
    metrics.discover.elapsed.freeze(0);
    metrics.convert.elapsed.freeze(0);
    metrics.switch_cmd.elapsed.freeze(0);
  };

  virtual ~mcrEngine(){};

  // task methods
  void addTask(const string_t &engine_name, TaskTypes_t task_type,
               EngineTask_t &task) {

    EngineTask_ptr_t new_task = new EngineTask(task);
    // when the task name is 'core' then set it to the engine name
    // otherwise prepend the engine name
    if (new_task->_name.find("core") != std::string::npos) {
      new_task->_name = engine_name;
    } else {
      new_task->_name.insert(0, engine_name);
    }

    _task_map[task_type] = new_task;
  }

  void saveTaskLastWake(TaskTypes_t tt) {
    auto task = _task_map[tt];
    task->_lastWake = xTaskGetTickCount();
  }

  void taskDelayUntil(TaskTypes_t tt, TickType_t ticks) {
    auto task = _task_map[tt];

    ::vTaskDelayUntil(&(task->_lastWake), ticks);
  }

  const TaskMap_t &taskMap() { return _task_map; }

  xTaskHandle taskHandle() {
    auto task = _task_map[CORE];

    return task->_handle;
  }

  void delay(int ms) { ::vTaskDelay(pdMS_TO_TICKS(ms)); }

  virtual void core(void *data) = 0; // pure virtual, subclass must implement
  virtual void suspend() {

    for_each(_task_map.begin(), _task_map.end(), [this](TaskMapItem_t item) {
      auto subtask = item.second;

      ESP_LOGW(tagEngine(), "suspending subtask %s(%p)", subtask->_name.c_str(),
               subtask->_handle);
      ::vTaskSuspend(subtask->_handle);
    });

    auto coretask = _task_map[CORE];
    ESP_LOGW(tagEngine(), "suspending engine %s (%p)", coretask->_name.c_str(),
             coretask->_handle);
    vTaskSuspend(coretask->_handle);
  };

  // determines if the engine should start or not.  the default is years.
  // subclasses can implement their own check.  if this method returns false
  // no tasks are created and start() quietly returns
  virtual bool shouldStart() { return true; };

  void start(void *task_data = nullptr) {
    // first things first...  check that the engine should start.  subclasses
    // can implement their own
    if (shouldStart() == false) {
      return;
    }

    // we make an assumption that the 'core' task was added
    auto task = _task_map[CORE];

    if (task->_handle != nullptr) {
      ESP_LOGW(tagEngine(), "task already running %p", (void *)task->_handle);
    }

    // this (object) is passed as the data to the task creation and is
    // used by the static runCore method to call the implemented run
    // method
    ::xTaskCreate(&runCore, task->_name.c_str(), task->_stackSize, this,
                  task->_priority, &task->_handle);
    ESP_LOGI(task->_name.c_str(), "core(%p) priority(%d) stack(%d)",
             task->_handle, task->_priority, task->_stackSize);

    // now start any sub-tasks added
    for_each(_task_map.begin(), _task_map.end(), [this](TaskMapItem_t item) {
      auto sub_type = item.first;
      auto subtask = item.second;
      TaskFunc_t *run_subtask;

      switch (sub_type) {
      case CORE:
        // core is already started, skip it
        subtask = nullptr;

        break;
      case CONVERT:
        run_subtask = &runConvert;

        break;
      case DISCOVER:
        run_subtask = &runDiscover;

        break;
      case COMMAND:
        run_subtask = &runCommand;

        break;
      case REPORT:
        run_subtask = &runReport;

        break;
      default:
        subtask = nullptr;
      }

      if (subtask != nullptr) {
        ::xTaskCreate(run_subtask, subtask->_name.c_str(), subtask->_stackSize,
                      this, subtask->_priority, &subtask->_handle);

        ESP_LOGD(tagEngine(), "subtask %s priority(%d) stack(%d) handle(%p)",
                 subtask->_name.c_str(), subtask->_priority,
                 subtask->_stackSize, subtask->_handle);
      }
    });
  }

  void stop() {
    auto task = _task_map[CORE];
    if (task->_handle == nullptr) {
      return;
    }

    ESP_LOGW(tagEngine(), "task stopping, goodbye");

    xTaskHandle handle = task->_handle;
    task->_handle = nullptr;
    ::vTaskDelete(handle);
  }

  // FIXME: move to external config
  static uint32_t maxDevices() { return 100; };

  bool any_of_devices(bool (*func)(const DEV &)) {
    return std::any_of(_devices.cbegin(), _devices.cend(), func);
  }

  // justSeenDevice():
  //    will return true and call justSeen() If the device was found
  DEV *justSeenDevice(DEV &dev) {
    auto *found_dev = findDevice(dev.id());

    if (LOG_LOCAL_LEVEL >= ESP_LOG_DEBUG) {
      ESP_LOGV(tagEngine(), "just saw: %s", dev.debug().get());
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

    if (numKnownDevices() > maxDevices()) {
      ESP_LOGW(tagEngine(), "attempt to exceed max devices!");
      return rc;
    }

    if ((found = findDevice(dev->id())) == nullptr) {
      dev->justSeen();
      // _devices.push_back(dev);
      _devices[dev->id()] = dev;
      ESP_LOGV(tagEngine(), "added %s", dev->debug().get());
    }

    return (found == nullptr) ? true : false;
  };

  DEV *findDevice(const string_t &dev) {
    // my first lambda in C++, wow this languge has really evolved
    // since I used it 15+ years ago
    // auto found =
    //     std::find_if(_devices.begin(), _devices.end(),
    //                  [dev](DEV *search) { return search->id() == dev; });

    auto found = _devices.find(dev);

    if (found != _devices.end()) {
      return found->second;
    }

    return nullptr;
  }

  auto beginDevices() -> typename DeviceMap_t::iterator {
    return _devices.begin();
  }

  auto endDevices() -> typename DeviceMap_t::iterator { return _devices.end(); }

  auto knownDevices() -> typename DeviceMap_t::iterator {
    return _devices.begin();
  }
  bool endOfDevices(typename DeviceMap_t::iterator it) {
    return it == _devices.end();
  };

  bool moreDevices(typename DeviceMap_t::iterator it) {
    return it != _devices.end();
  };

  uint32_t numKnownDevices() { return _devices.size(); };
  bool isDeviceKnown(const string_t &id) {
    bool rc = false;

    rc = (findDevice(id) == nullptr ? false : true);
    return rc;
  };

protected:
  typedef std::unordered_map<string_t, string_t> EngineTagMap_t;
  EngineTagMap_t _tags;

  virtual void convert(void *data) { doNothing(); };
  virtual void command(void *data) { doNothing(); };
  virtual void discover(void *data) { doNothing(); };
  virtual void report(void *data) { doNothing(); };

  void logSubTaskStart(void *task_info) {
    logSubTaskStart((EngineTask_ptr_t)task_info);
  }

  void logSubTaskStart(EngineTask_ptr_t task_info) {
    ESP_LOGI(task_info->_name.c_str(),
             "subtask(%p) running, priority(%d) stack(%d)", task_info->_handle,
             task_info->_priority, task_info->_stackSize);
  }

  DEV *getDeviceByCmd(mcrCmd_t &cmd) {
    DEV *dev = findDevice(cmd.internalDevID());
    return dev;
  };

  DEV *getDeviceByCmd(mcrCmd_t *cmd) {
    DEV *dev = findDevice(cmd->internalDevID());
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
  void devicesAvailable(bool available = true) {
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
  void clearNeedBus() { xEventGroupClearBits(_evg, needBusBit()); }
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

  bool waitForEngine() {
    EventBits_t b = engineBit();
    EventBits_t sb;

    sb = xEventGroupWaitBits(_evg, b, // bit to wait for
                             pdFALSE, // don't clear bit
                             pdTRUE,  // wait for all bits
                             portMAX_DELAY);

    return (sb & b);
  }

  // semaphore
  void giveBus() { xSemaphoreGive(_bus_mutex); }
  bool takeBus(TickType_t wait_ticks = portMAX_DELAY) {
    // the bus will be in an indeterminate state if we do acquire it so
    // call resetBus(). said differently, we could have taken the bus
    // in the middle of some other operation (e.g. discover, device read)
    if ((xSemaphoreTake(_bus_mutex, wait_ticks) == pdTRUE) && resetBus()) {
      return true;
    }

    return false;
  }

  bool publish(mcrCmd_t &cmd) { return publish(cmd.internalDevID()); };
  bool publish(const string_t &dev_id) {
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

  virtual bool resetBus(bool *additional_status = nullptr) { return true; }

  void setCmdAck(mcrCmd_t &cmd) {
    DEV *dev = findDevice(cmd.internalDevID());

    if (dev != nullptr) {
      dev->setReadingCmdAck(cmd.latency(), cmd.refID());
    } else {
      ESP_LOGW(tagEngine(), "device %s not found while setting cmd ack",
               cmd.internalDevID().c_str());
    }
  }

  void setLoggingLevel(const char *tag, esp_log_level_t level) {
    esp_log_level_set(tag, level);
  }

  const char *logLevelAsText(esp_log_level_t level) {
    const char *text;

    switch (level) {
    case ESP_LOG_NONE:
      text = "none";
      break;
    case ESP_LOG_DEBUG:
      text = "debug";
      break;
    case ESP_LOG_INFO:
      text = "info";
      break;
    case ESP_LOG_WARN:
      text = "warning";
      break;
    case ESP_LOG_ERROR:
      text = "error";
      break;
    case ESP_LOG_VERBOSE:
      text = "verbose";
      break;
    default:
      text = "unknown";
    }

    return text;
  }

  // definition of an entry in the EngineTagMap:
  //  key:    identifier (e.g. 'engine', 'discover')
  //  entry:  text displayed by ESP_LOG* when logging level matches
  typedef std::pair<string_t, string_t> EngineTagItem_t;
  void setLoggingLevel(esp_log_level_t level) {
    for_each(_tags.begin(), _tags.end(), [this, level](EngineTagItem_t item) {
      string_t &key = item.first;
      string_t &tag_text = item.second;

      ESP_LOGI(_tags["engine"].c_str(), "key(%s) tag(%s) %s logging",
               key.c_str(), tag_text.c_str(), logLevelAsText(level));
      esp_log_level_set(tag_text.c_str(), level);
    });

    elapsedMicros find;
    const char *tag = _tags["engine"].c_str();

    auto elapsed = (uint64_t)find;
    auto load = _tags.load_factor();
    auto buckets = _tags.bucket_count();

    ESP_LOGV(tag,
             "_tags us(%llu) sizeof(%zu) size(%u) load(%0.2f) "
             "buckets(%u)",
             elapsed, sizeof(_tags), _tags.size(), load, buckets);
  }

  void setTags(EngineTagMap_t &map) { _tags = map; }

  //
  // Command Queue
  //
protected:
  const int _max_queue_depth = CONFIG_MCR_CMD_Q_MAX_DEPTH;
  QueueHandle_t _cmd_q = nullptr;

public:
  const char *tagCommand() { return tagGeneric("command"); }

  const char *tagConvert() { return tagGeneric("convert"); }

  const char *tagDiscover() { return tagGeneric("discover"); }

  const char *tagGeneric(const char *tag) { return _tags[tag].c_str(); }

  const char *tagEngine() { return tagGeneric("engine"); }

  const char *tagPhase() { return tagGeneric("phase"); }

  const char *tagReport() { return tagGeneric("report"); }

  // misc metrics tracking
protected:
  void trackPhase(const char *lTAG, EngineMetric_t &phase, bool start) {
    if (start) {
      phase.elapsed.reset();
    } else {
      ESP_LOGD(lTAG, "phase ended, took %0.1fms",
               (float)((uint64_t)phase.elapsed / 1000.0));
      phase.elapsed.freeze();
      phase.last_time = time(nullptr);
    }
  };

  void trackConvert(bool start = false) {
    trackPhase(tagConvert(), metrics.convert, start);
  };

  void trackDiscover(bool start = false) {
    trackPhase(tagDiscover(), metrics.discover, start);
  };

  void trackReport(bool start = false) {
    trackPhase(tagReport(), metrics.report, start);
  };

  void trackSwitchCmd(bool start = false) {
    trackPhase(tagCommand(), metrics.switch_cmd, start);
  };

  time_t lastConvertTimestamp() { return metrics.convert.last_time; };
  time_t lastDiscoverTimestamp() { return metrics.discover.last_time; };
  time_t lastReportTimestamp() { return metrics.report.last_time; };
  time_t lastSwitchCmdTimestamp() { return metrics.switch_cmd.last_time; };

  void reportMetrics() {
    EngineReading reading(tagEngine(), metrics.discover.elapsed,
                          metrics.convert.elapsed, metrics.report.elapsed,
                          metrics.switch_cmd.elapsed);

    if (reading.hasNonZeroValues()) {
      publish(&reading);
    }
  }
};
} // namespace mcr

#endif // mcp_engine_h
