/*
     engines/types.hpp - Master Control Remote Engine Types
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

#ifndef engines_types_h
#define engines_types_h

#include <algorithm>
#include <map>
#include <unordered_map>

#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/task.h>
#include <sdkconfig.h>

#include "misc/mcr_types.hpp"

namespace mcr {

typedef void(TaskFunc_t)(void *);

typedef enum { CORE, CONVERT, DISCOVER, REPORT, COMMAND } TaskTypes_t;

// specialize hash for TaskTypes_t as required by C++11 (unnecessary in C++14)
struct TaskTypesHash {
  std::size_t operator()(TaskTypes_t e) const {
    return static_cast<std::size_t>(e);
  }
};

typedef class EngineTask EngineTask_t;
typedef EngineTask_t *EngineTask_ptr_t;

typedef std::unordered_map<TaskTypes_t, EngineTask_t *, TaskTypesHash>
    TaskMap_t;
typedef TaskMap_t *TaskMap_ptr_t;

class EngineTask {
public:
  EngineTask(char const *name, UBaseType_t priority = 1,
             UBaseType_t stacksize = 5120, void *data = nullptr)
      : _name(name), _priority(priority), _stackSize(stacksize), _data(data){};

public:
  string_t _name = "unamed";
  TaskHandle_t _handle = nullptr;
  TickType_t _lastWake = 0;
  UBaseType_t _priority = 1;
  UBaseType_t _stackSize = 5 * 1024;
  void *_data = nullptr;
};

typedef struct EngineMetric {
  int64_t start_us = 0;
  int64_t elapsed_us = 0;
  time_t last_time = 0;
} EngineMetric_t;

typedef struct EngineMetrics {
  EngineMetric_t discover;
  EngineMetric_t convert;
  EngineMetric_t report;
  EngineMetric_t switch_cmd;
  EngineMetric_t switch_cmdack;
} EngineMetrics_t;

typedef std::pair<string_t, EngineMetric_t *> metricEntry_t;
typedef std::map<string_t, EngineMetric_t *> metricMap_t;

typedef struct {
  EventBits_t need_bus;
  EventBits_t engine_running;
  EventBits_t devices_available;
  EventBits_t temp_available;
  EventBits_t temp_sensors_available;
} engineEventBits_t;
} // namespace mcr
#endif // engines_types_h
