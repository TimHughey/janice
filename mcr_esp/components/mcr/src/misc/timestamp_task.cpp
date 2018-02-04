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
#include <FreeRTOS.h>
#include <System.h>
#include <Task.h>
#include <WiFi.h>
#include <WiFiEventHandler.h>
#include <esp_log.h>
#include <freertos/event_groups.h>

#include "mqtt.hpp"
#include "ramutil.hpp"
#include "timestamp_task.hpp"
#include "util.hpp"

#define V_REF 1100
#define ADC1_TEST_CHANNEL (ADC1_CHANNEL_6) // GPIO 34

static char tTAG[] = "mcrTimestamp";

mcrTimestampTask::mcrTimestampTask(EventGroupHandle_t evg, int bit)
    : Task(tTAG, 4 * 1024, 0) {
  ev_group = evg;
  wait_bit = bit;

  _firstHeap = System::getFreeHeapSize();
  _availHeap = System::getFreeHeapSize();
}

mcrTimestampTask::~mcrTimestampTask() {}

void mcrTimestampTask::run(void *data) {

  ESP_LOGD(tTAG, "started, waiting on %p for bits=0x%x", (void *)ev_group,
           wait_bit);
  xEventGroupWaitBits(ev_group, wait_bit, false, true, portMAX_DELAY);
  ESP_LOGD(tTAG, "bits set, entering task loop");

  _last_wake = xTaskGetTickCount();

  for (;;) {
    int delta;
    size_t curr_heap = 0;
    // uint32_t voltage = 0;

    curr_heap = System::getFreeHeapSize();
    delta = curr_heap - _availHeap;
    _availHeap = curr_heap;
    _minHeap = std::min(curr_heap, _minHeap);
    _maxHeap = std::max(curr_heap, _maxHeap);

    // voltage = vref_voltage();

    ESP_LOGI(
        tTAG, "%s %s heap=%uk first=%uk min=%uk max=%uk %sdelta=%d",
        LOG_RESET_COLOR, mcrUtil::dateTimeString(), (curr_heap / 1024),
        (_firstHeap / 1024), (_minHeap / 1024), (_maxHeap / 1024),
        ((delta < 0) ? LOG_COLOR(LOG_COLOR_RED) : LOG_COLOR(LOG_COLOR_GREEN)),
        delta);

    if (_task_report) {
      char *buff = new char[1024];
      vTaskList(buff);

      printf("\nTask          State  Priority   Stack   Num");
      printf("\n------------- -----  --------   -----   ---");
      printf("\n%s\n", buff);

      delete buff;
    }

    mcrMQTT_t *mqtt = mcrMQTT::instance();
    ramUtilReading_t *reading = new ramUtilReading(curr_heap);
    mqtt->publish(reading);
    delete reading;

    vTaskDelayUntil(&_last_wake, _loop_frequency);
  }
}

uint32_t mcrTimestampTask::vref_voltage() {
  esp_adc_cal_characteristics_t characteristics;
  adc1_config_width(ADC_WIDTH_BIT_12);
  adc1_config_channel_atten(ADC1_TEST_CHANNEL, ADC_ATTEN_DB_0);
  esp_adc_cal_get_characteristics(V_REF, ADC_ATTEN_DB_0, ADC_WIDTH_BIT_12,
                                  &characteristics);
  return adc1_to_voltage(ADC1_TEST_CHANNEL, &characteristics);
}
