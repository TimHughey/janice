
#ifndef _MCR_TIMESTAMP_TASK_H_
#define _MCR_TIMESTAMP_TASK_H_

#include <string>

#include <FreeRTOS.h>
#include <System.h>
#include <Task.h>
#include <WiFi.h>
#include <WiFiEventHandler.h>

#include <esp_log.h>
#include <freertos/event_groups.h>

#include "Task.h"
#include "sdkconfig.h"

class mcrTimestampTask : public Task {
public:
  mcrTimestampTask(EventGroupHandle_t evg, int bit);
  ~mcrTimestampTask();

  void run(void *data);

private:
  uint32_t vref_voltage();

private:
  EventGroupHandle_t ev_group;
  int wait_bit;

  size_t _firstHeap = 0;
  size_t _availHeap = 0;
  size_t _minHeap = 520 * 1024;
  size_t _maxHeap = 0;

  TickType_t _last_wake;
  const TickType_t _loop_frequency = pdMS_TO_TICKS(1 * 60 * 1000);
  bool _task_report = false;
};

#endif /* _MCR_TIMESTAMP_TASK_H_ */
