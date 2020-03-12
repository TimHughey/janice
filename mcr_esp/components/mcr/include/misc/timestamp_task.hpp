
#ifndef _MCR_TIMESTAMP_TASK_H_
#define _MCR_TIMESTAMP_TASK_H_

#include <memory>
#include <string>
#include <unordered_map>

#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/task.h>

#include "misc/mcr_types.hpp"

using std::unique_ptr;
using std::unordered_map;

namespace mcr {
class TimestampTask {

public:
  TimestampTask();
  ~TimestampTask();
  static unique_ptr<char[]> dateTimeString(time_t t = 0);

  void core(void *data);
  void start(void *task_data = nullptr) {
    if (_engine_task != nullptr) {
      ESP_LOGW(_engTAG, "there may already be a task running %p",
               (void *)_engine_task);
    }

    // this (object) is passed as the data to the task creation and is
    // used by the static runEngine method to call the implemented run
    // method
    ::xTaskCreate(&runEngine, _engine_task_name.c_str(), _engine_stack_size,
                  this, _engine_priority, &_engine_task);
  }

  void watchTaskStacks();

private:
  uint32_t vref_voltage();

private:
  const char *_engTAG = nullptr;
  xTaskHandle _engine_task = nullptr;
  void *_engine_task_data;
  std::string _engine_task_name;
  uint16_t _engine_stack_size = 2048;
  uint16_t _engine_priority = 0;

  size_t _firstHeap = 0;
  size_t _availHeap = 0;
  size_t _minHeap = UINT32_MAX;
  size_t _maxHeap = 0;

  TickType_t _last_wake;
  const TickType_t _loop_frequency = pdMS_TO_TICKS(3000);
  time_t _timestamp_freq_secs = (6 * 60 * 60); // six (6) hours

  typedef struct {
    xTaskHandle handle;
    uint32_t stack_high_water;
    uint32_t stack_depth = 0;
    bool mcr_task = false;
  } TaskStat_t;

  typedef TaskStat_t *TaskStat_ptr_t;

  typedef std::pair<string_t, TaskStat_ptr_t> TaskMapItem_t;

  // key(task name) entry(task stack high water)
  unordered_map<string_t, TaskStat_ptr_t> _task_map;
  bool _tasks_ongoing_report = false;

  // Task implementation
  void delay(int ms) { ::vTaskDelay(pdMS_TO_TICKS(ms)); }
  static void runEngine(void *task_instance) {
    TimestampTask *task = (TimestampTask *)task_instance;
    task->core(task->_engine_task_data);
  }

  void reportTaskStacks();
  void updateTaskData();

  void stop() {
    if (_engine_task == nullptr) {
      return;
    }

    xTaskHandle temp = _engine_task;
    _engine_task = nullptr;
    ::vTaskDelete(temp);
  }
};
} // namespace mcr

#endif /* _MCR_TIMESTAMP_TASK_H_ */
