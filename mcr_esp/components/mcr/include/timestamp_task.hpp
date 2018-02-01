
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
  EventGroupHandle_t ev_group;
  int wait_bit;

  TickType_t _last_wake;
  const TickType_t _loop_frequency = pdMS_TO_TICKS(1 * 60 * 1000);
  bool _task_report = false;
};

#endif /* _MCR_TIMESTAMP_TASK_H_ */
