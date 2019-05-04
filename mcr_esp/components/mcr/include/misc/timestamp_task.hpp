
#ifndef _MCR_TIMESTAMP_TASK_H_
#define _MCR_TIMESTAMP_TASK_H_

#include <string>

#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/task.h>
#include <sdkconfig.h>

class mcrTimestampTask {
public:
  mcrTimestampTask();
  ~mcrTimestampTask();
  static const char *dateTimeString(time_t t = 0);

  void run(void *data);
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
  void watchStack(const char *task_name, TaskHandle_t handle) {
    ESP_LOGI(_engTAG, "watch stack requested [%s] [%p]",
             ((task_name == nullptr) ? "nullptr" : task_name), handle);

    _watch_task_name = task_name;
    _watch_task_handle = handle;
  }

private:
  uint32_t vref_voltage();

private:
  const char *_engTAG = nullptr;
  xTaskHandle _engine_task = nullptr;
  void *_engine_task_data;
  std::string _engine_task_name;
  uint16_t _engine_stack_size = 3 * 1024;
  uint16_t _engine_priority = 0;

  size_t _firstHeap = 0;
  size_t _availHeap = 0;
  size_t _minHeap = 520 * 1024;
  size_t _maxHeap = 0;

  TickType_t _last_wake;
  const TickType_t _loop_frequency = pdMS_TO_TICKS(13 * 1000); // 13 seconds
  bool _task_report = false;
  time_t _timestamp_freq_secs = (15 * 60);

  const char *_watch_task_name = nullptr;
  TaskHandle_t _watch_task_handle = nullptr;

  // Task implementation
  void delay(int ms) { ::vTaskDelay(pdMS_TO_TICKS(ms)); }
  static void runEngine(void *task_instance) {
    mcrTimestampTask *task = (mcrTimestampTask *)task_instance;
    task->run(task->_engine_task_data);
  }

  void stop() {
    if (_engine_task == nullptr) {
      return;
    }

    xTaskHandle temp = _engine_task;
    _engine_task = nullptr;
    ::vTaskDelete(temp);
  }
};

#endif /* _MCR_TIMESTAMP_TASK_H_ */
