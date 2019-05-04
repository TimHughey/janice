/*
 * timestamp_task.cpp
 *
 */

#include <algorithm>
#include <string>

#include "driver/adc.h"
#include "driver/gpio.h"
#include "esp_adc_cal.h"
#include "esp_system.h"
#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/task.h>
#include <sdkconfig.h>
#include <sys/time.h>
#include <time.h>

#include "misc/timestamp_task.hpp"
#include "net/mcr_net.hpp"
#include "protocols/mqtt.hpp"
#include "readings/readings.hpp"

static char tTAG[] = "mcrTimestamp";

mcrTimestampTask::mcrTimestampTask() {
  _engTAG = tTAG;
  _engine_task_name = tTAG;

  _firstHeap = heap_caps_get_free_size(MALLOC_CAP_8BIT);
  _availHeap = heap_caps_get_free_size(MALLOC_CAP_8BIT);
}

mcrTimestampTask::~mcrTimestampTask() {}

const char *mcrTimestampTask::dateTimeString(time_t t) {
  static char buf[20] = {};
  const auto buf_size = sizeof(buf);
  time_t now = time(nullptr);
  struct tm timeinfo = {};

  localtime_r(&now, &timeinfo);

  // strftime(buf, buf_size, "%c", &timeinfo);
  strftime(buf, buf_size, "%b-%d %R", &timeinfo);

  return buf;
}

void mcrTimestampTask::run(void *data) {
  time_t last_timestamp = time(nullptr);

  for (;;) {
    int delta;
    size_t curr_heap, max_alloc = 0;
    uint32_t batt_mv = mcr::Net::instance()->batt_mv();

    ESP_LOGD(tTAG, "wait for name and normal ops...");
    mcr::Net::waitForName(15000);
    mcr::Net::waitForNormalOps();

    _last_wake = xTaskGetTickCount();

    curr_heap = heap_caps_get_free_size(MALLOC_CAP_8BIT);
    delta = curr_heap - _availHeap;
    _availHeap = curr_heap;
    _minHeap = std::min(curr_heap, _minHeap);
    _maxHeap = std::max(curr_heap, _maxHeap);

    max_alloc = heap_caps_get_largest_free_block(MALLOC_CAP_8BIT);

    if ((time(nullptr) - last_timestamp) >= _timestamp_freq_secs) {
      const char *name = mcr::Net::getName().c_str();
      char delta_str[12] = {};

      if (delta < 0) {
        snprintf(delta_str, sizeof(delta_str), "(%05d)", delta * -1);
      } else {
        snprintf(delta_str, sizeof(delta_str), "%05d", delta);
      }

      ESP_LOGI(name, "%s hc=%uk hf=%uk hl=%uk d=%s ma=%uk batt=%dv",
               dateTimeString(), (curr_heap / 1024), (_firstHeap / 1024),
               (_maxHeap / 1024), delta_str, (max_alloc / 1024), batt_mv);
      // ESP_LOGI(name, "%s", dateTimeString());
      last_timestamp = time(nullptr);

      if (_watch_task_name && _watch_task_handle) {
        UBaseType_t stack_high_water;

        stack_high_water = uxTaskGetStackHighWaterMark(_watch_task_handle);
        _watch_task_stack_min =
            std::min(_watch_task_stack_min, stack_high_water);
        _watch_task_stack_max =
            std::max(_watch_task_stack_max, stack_high_water);

        ESP_LOGI(_watch_task_name, "stack max(%d) min(%d)",
                 _watch_task_stack_max, _watch_task_stack_min);
      }
    }

    if (_task_report) {
      char *tasks = new char[1024];
      char *out = new char[1200];
      vTaskList(tasks);
      const char *head1 = "Task          State  Priority   Stack   Num";
      const char *head2 = "------------- -----  --------   -----   ---";
      sprintf(out, "%s\n%s\n%s", head1, head2, tasks);

      ESP_LOGW(tTAG, "\n%s", out);

      delete out;
      delete tasks;
    }

    mcrMQTT_t *mqtt = mcrMQTT::instance();
    // deprecated by remoteReading_t
    ramUtilReading_t *ram = new ramUtilReading(curr_heap);
    mqtt->publish(ram);
    delete ram;

    // ramUtilReading_t replacement
    remoteReading_t *remote = new remoteReading(batt_mv);
    mqtt->publish(remote);
    delete remote;

    vTaskDelayUntil(&_last_wake, _loop_frequency);
  }
}
