
#ifndef _MCR_DEV_TASK_H_
#define _MCR_DEV_TASK_H_

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

class mcrDevTask : public Task {
public:
  mcrDevTask();
  ~mcrDevTask();

  void run(void *data);

private:
  TickType_t _last_wake;
  const TickType_t _loop_frequency = pdMS_TO_TICKS(5 * 60 * 1000);
};

#endif /* _MCR_TIMESTAMP_TASK_H_ */
