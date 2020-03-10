/*
    main.cpp - Master Control Remote Main App
    Copyright (C) 2017  Tim Hughey

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    https://www.wisslanding.com
*/

#include <cstdlib>

#include <driver/periph_ctrl.h>
#include <esp_log.h>
#include <esp_spi_flash.h>
// #include <esp_system.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

#include "cmds/ota.hpp"
#include "engines/ds.hpp"
#include "engines/i2c.hpp"
#include "engines/pwm.hpp"
#include "misc/mcr_nvs.hpp"
#include "misc/status_led.hpp"
#include "misc/timestamp_task.hpp"
#include "net/mcr_net.hpp"
#include "protocols/mqtt.hpp"

using namespace mcr;

extern "C" {
void app_main(void);
int setenv(const char *envname, const char *envval, int overwrite);
void tzset(void);
}

extern const uint8_t ca_start[] asm("_binary_ca_pem_start");
extern const uint8_t ca_end[] asm("_binary_ca_pem_end");

static const char *TAG = "mcrESP";

static mcr::Net *network = nullptr;
static TimestampTask *timestampTask = nullptr;
static mcrMQTT *mqttTask = nullptr;
static mcrDS *dsEngineTask = nullptr;
static mcrI2c *i2cEngineTask = nullptr;
static pwmEngine_t *pwmEngineTask = nullptr;

void app_main() {
  // set status LED to 8%% to signal startup and initialization are
  // underway
  statusLED::instance()->dim();

  ESP_LOGI(TAG, "%s entered", __PRETTY_FUNCTION__);
  ESP_LOGI(TAG, "portTICK_PERIOD_MS=%u and 10ms=%u tick%s", portTICK_PERIOD_MS,
           pdMS_TO_TICKS(10), (pdMS_TO_TICKS(10) > 1) ? "s" : "");

  // set timezone to Eastern Standard Time
  // this is done very early to ensure the timezone is available for any
  // functions that need it.
  setenv("TZ", "EST5EDT,M3.2.0/2,M11.1.0", 1);
  tzset();

  mcrNVS::init();
  statusLED::instance()->brighter();

  // must create network first!
  network = mcr::Net::instance(); // singleton
  timestampTask = new TimestampTask();
  mqttTask = mcrMQTT::instance();        // singleton
  dsEngineTask = mcrDS::instance();      // singleton
  i2cEngineTask = mcrI2c::instance();    // singleton
  pwmEngineTask = pwmEngine::instance(); // singleton
  statusLED::instance()->brighter();

  // create and start our tasks
  // NOTE: each task is responsible for required coordination

  timestampTask->start();
  mqttTask->start();
  dsEngineTask->start();
  i2cEngineTask->start();
  pwmEngineTask->start();

  network->start();

  // now that all tasks are started signal to begin watching task stacks
  timestampTask->watchTaskStacks();

  // the main loop is a safety net for overall platform failures
  for (;;) {
    bool boot_complete = false;

    // safety net 1:
    //    wait for the name to be set for 90 seconds, if the name is not
    //    set within in 90 seconds then there's some problem (e.g. mcp or mqtt
    //    are done) so reboot
    if (Net::waitForName(90000) == false) {
      mcrRestart::now();
    }

    // safety net 2:
    //    wait for the transport to be ready for up to 60 seconds (60000ms).
    //    if transport does not become ready then a problem has occurred
    //    after startup (since we wouldn't be here if transport never
    //    became available)
    if (Net::waitForReady(60000) == false) {
      mcrRestart::now();
    }

    // safety net 3:
    //    only after the above two checks succeed mark the ota partition
    //    valid after an ota update
    mcrCmdOTA::markPartitionValid();

    // boot up is successful, process any previously committed NVS messages
    // and record the successful boot
    if (boot_complete == false) {
      ESP_LOGI(TAG, "certificate authority pem available [%d bytes]",
               ca_end - ca_start);

      UBaseType_t stack_high_water = uxTaskGetStackHighWaterMark(nullptr);
      UBaseType_t num_tasks = uxTaskGetNumberOfTasks();

      ESP_LOGI(TAG, "boot complete [stack high water: %d, num of tasks: %d]",
               stack_high_water, num_tasks);

      mcrNVS::processCommittedMsgs();
      mcrNVS::commitMsg("BOOT", "LAST SUCCESSUL BOOT");
    }

    // sleep for 60 seconds
    vTaskDelay(pdMS_TO_TICKS(60 * 1000));
  }
}
