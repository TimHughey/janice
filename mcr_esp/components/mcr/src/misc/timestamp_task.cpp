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

#define V_REF 1100
#define ADC1_TEST_CHANNEL (ADC1_CHANNEL_6) // GPIO 34

extern "C" {
int setenv(const char *envname, const char *envval, int overwrite);
void tzset(void);
}

static char tTAG[] = "mcrTimestamp";

mcrTimestampTask::mcrTimestampTask() {
  _engTAG = tTAG;
  _engine_task_name = tTAG;

  _firstHeap = heap_caps_get_free_size(MALLOC_CAP_8BIT);
  _availHeap = heap_caps_get_free_size(MALLOC_CAP_8BIT);
}

mcrTimestampTask::~mcrTimestampTask() {}

const char *mcrTimestampTask::dateTimeString(time_t t) {
  static char buf[64] = {0x00};
  const auto buf_size = sizeof(buf);
  time_t now;
  struct tm timeinfo = {};

  time(&now);
  // Set timezone to Eastern Standard Time and print local time
  setenv("TZ", "EST5EDT,M3.2.0/2,M11.1.0", 1);
  tzset();
  localtime_r(&now, &timeinfo);

  // strftime(buf, buf_size, "%c", &timeinfo);
  strftime(buf, buf_size, "%b-%d %R", &timeinfo);

  return buf;
}

void mcrTimestampTask::run(void *data) {

  ESP_LOGD(tTAG, "started, wait for normal ops...");
  mcr::Net::waitForNormalOps();
  ESP_LOGD(tTAG, "normal ops, entering task loop");

  for (;;) {
    int delta;
    size_t curr_heap = 0;
    // uint32_t voltage = 0;

    _last_wake = xTaskGetTickCount();

    curr_heap = heap_caps_get_free_size(MALLOC_CAP_8BIT);
    delta = curr_heap - _availHeap;
    _availHeap = curr_heap;
    _minHeap = std::min(curr_heap, _minHeap);
    _maxHeap = std::max(curr_heap, _maxHeap);

    // voltage = vref_voltage();

    ESP_LOGI(
        tTAG, "%s %s %s heap=%uk first=%uk min=%uk %sdelta=%d", LOG_RESET_COLOR,
        dateTimeString(), mcr::Net::getName().c_str(), (curr_heap / 1024),
        (_firstHeap / 1024), (_maxHeap / 1024),
        ((delta < 0) ? LOG_COLOR(LOG_COLOR_RED) : LOG_COLOR(LOG_RESET_COLOR)),
        delta);

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
    ramUtilReading_t *reading = new ramUtilReading(curr_heap);
    mqtt->publish(reading);
    delete reading;

    vTaskDelayUntil(&_last_wake, _loop_frequency);
  }
}

// uint32_t mcrTimestampTask::vref_voltage() {
//  esp_adc_cal_characteristics_t characteristics;
//  adc1_config_width(ADC_WIDTH_BIT_12);
//  adc1_config_channel_atten(ADC1_TEST_CHANNEL, ADC_ATTEN_DB_0);
//  esp_adc_cal_get_characteristics(V_REF, ADC_ATTEN_DB_0, ADC_WIDTH_BIT_12,
//                                  &characteristics);
//  return adc1_to_voltage(ADC1_TEST_CHANNEL, &characteristics);
//}
