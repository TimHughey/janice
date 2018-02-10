/*
 * timestamp_task.cpp
 *
 */

#include <cstdlib>
#include <cstring>
#include <ctime>
#include <random>

#include <FreeRTOS.h>
#include <System.h>
#include <Task.h>
#include <WiFi.h>
#include <WiFiEventHandler.h>

#include <freertos/event_groups.h>

#include "cmds/cmd.hpp"
#include "devs/id.hpp"
#include "misc/dev_task.hpp"
#include "net/mcr_net.hpp"
#include "readings/readings.hpp"

static char tTAG[] = "mcrDevTask";

mcrDevTask::mcrDevTask() : Task(tTAG, (6 * 1024), 1) {}

mcrDevTask::~mcrDevTask() {}

void mcrDevTask::run(void *data) {
  std::random_device *r = new std::random_device();
  std::uniform_int_distribution<int> *uniform_dist =
      new std::uniform_int_distribution<int>(0, 255);
  // std::uniform_int_distribution<int> uniform_dist(0, 255);

  size_t prevHeap = System::getFreeHeapSize();
  size_t availHeap = 0;

  ESP_LOGD(tTAG, "started, waiting for network connection...");
  mcrNetwork::waitForConnection();
  ESP_LOGD(tTAG, "connection available, entering task loop");

  _last_wake = xTaskGetTickCount();

  for (;;) {
    const size_t buff_len = 1024;
    char *buffer = new char[buff_len];

    bzero(buffer, buff_len);

    uint32_t states = (*uniform_dist)(*r);
    uint32_t mask = (*uniform_dist)(*r);

    mcrDevID_t dev("fake_dev");
    celsiusReading *reading = new celsiusReading(dev, time(nullptr), 31.3);

    positionsReading *positions =
        new positionsReading(dev, time(nullptr), states, 8);

    mcrCmd *cmd = new mcrCmd(dev, mask, states);

    availHeap = System::getFreeHeapSize();
    ESP_LOGI(tTAG, "after memory alloc  heap=%u delta=%d", availHeap,
             (int)(availHeap - prevHeap));
    prevHeap = availHeap;

    // const std::string &json = reading->json();
    // ESP_LOGI(tTAG, "reading json (len=%u): %s", json.length(), json.c_str());
    //
    // const std::string positions_json = positions->json();
    // ESP_LOGI(tTAG, "positions json (len=%u): %s", positions_json.length(),
    //          positions_json.c_str());

    ESP_LOGI(tTAG, "dev (sizeof=%u) debug: %s", sizeof(mcrDevID_t),
             dev.debug().c_str());

    ESP_LOGI(tTAG, "cmd (sizeof=%u) debug: %s", sizeof(mcrCmd_t),
             cmd->debug().c_str());

    delete reading;
    delete positions;
    delete cmd;
    delete buffer;

    availHeap = System::getFreeHeapSize();
    ESP_LOGI(tTAG, "after memory dealloc heap=%u delta=%d", availHeap,
             (int)(availHeap - prevHeap));
    prevHeap = availHeap;

    vTaskDelayUntil(&_last_wake, _loop_frequency);
  }
}
