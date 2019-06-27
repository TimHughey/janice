/*
 * timestamp_task.cpp
 *
 */

#include <algorithm>
#include <memory>
#include <string>

#include "esp_system.h"
#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/task.h>
#include <sdkconfig.h>
#include <sys/time.h>
#include <time.h>

#include "misc/mcr_restart.hpp"
#include "misc/timestamp_task.hpp"
#include "net/mcr_net.hpp"
#include "protocols/mqtt.hpp"
#include "readings/readings.hpp"

static char tTAG[] = "mcrStamp";

using std::max;
using std::min;
using std::move;

namespace mcr {

TimestampTask::TimestampTask() {
  _engTAG = tTAG;
  _engine_task_name = tTAG;

  _firstHeap = heap_caps_get_free_size(MALLOC_CAP_8BIT);
  _availHeap = heap_caps_get_free_size(MALLOC_CAP_8BIT);
}

TimestampTask::~TimestampTask() {}

// NOTE:  Use .get() to access the underlying char array
unique_ptr<char[]> TimestampTask::dateTimeString(time_t t) {

  const auto buf_size = 28;
  unique_ptr<char[]> buf(new char[buf_size + 1]);

  time_t now = time(nullptr);
  struct tm timeinfo = {};

  localtime_r(&now, &timeinfo);
  strftime(buf.get(), buf_size, "%c", &timeinfo);
  // strftime(buf.get(), buf_size, "%b-%d %R", &timeinfo);

  return move(buf);
}

void TimestampTask::core(void *data) {
  // initialize to zero so there is a timestamp report at
  // startup
  time_t last_timestamp = 0;

  for (;;) {
    int delta;
    size_t curr_heap, max_alloc = 0;
    uint32_t batt_mv = Net::instance()->batt_mv();

    ESP_LOGD(tTAG, "standing by for name and normal ops...");
    Net::waitForName(60000);
    Net::waitForNormalOps();

    _last_wake = xTaskGetTickCount();

    curr_heap = heap_caps_get_free_size(MALLOC_CAP_8BIT);
    delta = _availHeap - curr_heap;
    _availHeap = curr_heap;
    _minHeap = min(curr_heap, _minHeap);
    _maxHeap = max(curr_heap, _maxHeap);

    max_alloc = heap_caps_get_largest_free_block(MALLOC_CAP_8BIT);

    if ((time(nullptr) - last_timestamp) >= _timestamp_freq_secs) {
      const char *name = Net::getName().c_str();
      char delta_str[12] = {};

      if (delta < 0) {
        snprintf(delta_str, sizeof(delta_str), "(%05d)", delta * -1);
      } else {
        snprintf(delta_str, sizeof(delta_str), "%05d", delta);
      }

      ESP_LOGI(name, "%s hc=%uk hf=%uk hl=%uk d=%s ma=%uk batt=%0.2fv",
               dateTimeString().get(), (curr_heap / 1024), (_firstHeap / 1024),
               (_maxHeap / 1024), delta_str, (max_alloc / 1024),
               (float)(batt_mv / 1024.0));

      // reportTaskStacks();

      if ((last_timestamp == 0) && (_timestamp_freq_secs > 300)) {
        ESP_LOGI(name, "--> next timestamp report in %0.2f minutes",
                 (float)(_timestamp_freq_secs / 60.0));
      }

      last_timestamp = time(nullptr);
    }

    if (max_alloc < (75 * 1024)) {
      mcrRestart::instance()->restart("heap fragmentation", __PRETTY_FUNCTION__,
                                      3000);
    }

    if (Net::waitForReady(0) == true) {
      ramUtilReading_t_ptr ram(new ramUtilReading());
      ram->publish();

      // ramUtilReading_t replacement
      remoteReading_ptr_t remote(new remoteReading(batt_mv));
      remote->publish();
    }

    vTaskDelayUntil(&_last_wake, _loop_frequency);
  }
}

void TimestampTask::reportTaskStacks() {
  if (_task_map.size() == 0)
    return;

  textReading *rlog = new textReading();
  textReading_ptr_t rlog_ptr(rlog);

  for_each(_task_map.begin(), _task_map.end(), [rlog](TaskMapItem_t item) {
    string_t name = item.first;
    TaskStat_ptr_t stat = item.second;

    if (stat->stack_high_water > 1024) {
      rlog->printf("%s(%d) ", name.c_str(), stat->stack_high_water);
    }
  });

  rlog->consoleInfo(tTAG);
  rlog->publish();

  updateTaskData();
}

void TimestampTask::updateTaskData() {
  for_each(_task_map.begin(), _task_map.end(), [this](TaskMapItem_t item) {
    auto stat = item.second;

    stat->stack_high_water = uxTaskGetStackHighWaterMark(stat->handle);
  });
}

void TimestampTask::watchTaskStacks() {
  uint32_t num_tasks = uxTaskGetNumberOfTasks();
  _task_map.reserve(num_tasks);

  TaskStatus_t *buff = new TaskStatus_t[num_tasks];
  unique_ptr<TaskStatus_t> buff_ptr(buff);
  uint32_t run_time;

  uxTaskGetSystemState(buff, num_tasks, &run_time);

  for (uint32_t i = 0; i < num_tasks; i++) {
    TaskStatus_t task = buff[i];

    if (task.pcTaskName != nullptr) {
      string_t name = task.pcTaskName;

      TaskStat_ptr_t stat = new TaskStat_t;

      stat->handle = task.xHandle;
      stat->stack_high_water = task.usStackHighWaterMark;

      _task_map[name] = stat;
    }
  }
}
} // namespace mcr
