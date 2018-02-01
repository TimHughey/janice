/*
 * timestamp_task.cpp
 *
 */

#include <string>

#include <FreeRTOS.h>
#include <System.h>
#include <Task.h>
#include <WiFi.h>
#include <WiFiEventHandler.h>

#include <esp_log.h>
#include <freertos/event_groups.h>

#include "timestamp_task.hpp"
#include "util.hpp"

static char tTAG[] = "mcrTimestamp";

mcrTimestampTask::mcrTimestampTask(EventGroupHandle_t evg, int bit)
    : Task(tTAG, 4 * 1024, 0) {
  ev_group = evg;
  wait_bit = bit;
}

mcrTimestampTask::~mcrTimestampTask() {}

void mcrTimestampTask::run(void *data) {
  size_t prevHeap = System::getFreeHeapSize();
  size_t availHeap = 0;

  ESP_LOGD(tTAG, "started, waiting on event_group=%p for bits=0x%x",
           (void *)ev_group, wait_bit);
  xEventGroupWaitBits(ev_group, wait_bit, false, true, portMAX_DELAY);
  ESP_LOGD(tTAG, "event_group wait complete, entering task loop");

  _last_wake = xTaskGetTickCount();

  for (;;) {
    int delta;

    availHeap = System::getFreeHeapSize();
    delta = availHeap - prevHeap;
    prevHeap = availHeap;

    ESP_LOGI(tTAG, "%s heap: %u delta: %d", mcrUtil::dateTimeString(),
             availHeap, delta);

    if (_task_report) {
      char *buff = new char[1024];
      vTaskList(buff);

      printf("\nTask          State  Priority   Stack   Num");
      printf("\n------------- -----  --------   -----   ---");
      printf("\n%s\n", buff);

      delete buff;
    }

    vTaskDelayUntil(&_last_wake, _loop_frequency);
  }
}
