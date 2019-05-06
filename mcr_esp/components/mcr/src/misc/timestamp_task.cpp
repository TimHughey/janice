/*
 * timestamp_task.cpp
 *
 */

#include <algorithm>
#include <memory>
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

static char tTAG[] = "mcrStamp";

using std::max;
using std::min;
using std::move;

using mcr::Net;

mcrTimestampTask::mcrTimestampTask() {
  _engTAG = tTAG;
  _engine_task_name = tTAG;

  _firstHeap = heap_caps_get_free_size(MALLOC_CAP_8BIT);
  _availHeap = heap_caps_get_free_size(MALLOC_CAP_8BIT);
}

mcrTimestampTask::~mcrTimestampTask() {}

// NOTE:  Use .get() to access the underlying char array
unique_ptr<char[]> mcrTimestampTask::dateTimeString(time_t t) {

  const auto buf_size = 28;
  unique_ptr<char[]> buf(new char[buf_size + 1]);

  time_t now = time(nullptr);
  struct tm timeinfo = {};

  localtime_r(&now, &timeinfo);

  strftime(buf.get(), buf_size, "%c", &timeinfo);
  // strftime(buf.get(), buf_size, "%b-%d %R", &timeinfo);

  return move(buf);
}

void mcrTimestampTask::run(void *data) {
  // initialize to zero so there is a timestamp report at
  // startup
  time_t last_timestamp = 0;

  for (;;) {
    int delta;
    size_t curr_heap, max_alloc = 0;
    uint32_t batt_mv = Net::instance()->batt_mv();

    ESP_LOGD(tTAG, "standing by for name and normal ops...");
    Net::waitForName(15000);
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

      if (_watch_task_name && _watch_task_handle) {
        UBaseType_t stack_high_water;

        stack_high_water = uxTaskGetStackHighWaterMark(_watch_task_handle);
        _watch_task_stack_min = min(_watch_task_stack_min, stack_high_water);
        _watch_task_stack_max = max(_watch_task_stack_max, stack_high_water);

        ESP_LOGI(_watch_task_name, "stack max(%d) min(%d)",
                 _watch_task_stack_max, _watch_task_stack_min);
      }

      if ((last_timestamp == 0) && (_timestamp_freq_secs > 300)) {
        ESP_LOGI(name, "--> next timestamp report in %0.2f minutes",
                 (float)(_timestamp_freq_secs / 60.0));
      }

      last_timestamp = time(nullptr);
    }

    if (_task_report) {
      const unique_ptr<char[]> tasks(new char[1024]);
      const unique_ptr<char[]> out(new char[1200]);
      vTaskList(tasks.get());
      const char *head1 = "Task          State  Priority   Stack   Num";
      const char *head2 = "------------- -----  --------   -----   ---";
      sprintf(out.get(), "%s\n%s\n%s", head1, head2, tasks.get());

      ESP_LOGW(tTAG, "\n%s", out.get());
    }

    mcrMQTT_t *mqtt = mcrMQTT::instance();

    unique_ptr<ramUtilReading_t> ram(new ramUtilReading(curr_heap));
    mqtt->publish(move(ram));

    // ramUtilReading_t replacement
    unique_ptr<remoteReading_t> remote(new remoteReading(batt_mv));
    mqtt->publish(move(remote));

    vTaskDelayUntil(&_last_wake, _loop_frequency);
  }
}
