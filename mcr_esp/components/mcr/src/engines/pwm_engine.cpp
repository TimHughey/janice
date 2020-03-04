/*
      pwm_engine.cpp - Master Control Remote PWM Engine
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

#include "engines/pwm_engine.hpp"
#include "devs/pwm_dev.hpp"
#include "engines/engine.hpp"
#include "net/mcr_net.hpp"

using std::unique_ptr;

namespace mcr {

static pwmEngine_t *__singleton__ = nullptr;
static const string_t engine_name = "mcrPWM";

pwmEngine::pwmEngine() {
  pwmDev::allOff(); // ensure all pins are off at initialization

  setTags(localTags());

  setLoggingLevel(ESP_LOG_INFO);

  EngineTask_t core("core");
  EngineTask_t command("cmd", 12, 3072);
  EngineTask_t discover("dis", 12, 4096);
  EngineTask_t report("rpt", 12, 3072);

  addTask(engine_name, CORE, core);
  addTask(engine_name, COMMAND, command);
  addTask(engine_name, DISCOVER, discover);
  addTask(engine_name, REPORT, report);
}

//
// Tasks
//

void pwmEngine::command(void *data) {
  logSubTaskStart(data);

  _cmd_q = xQueueCreate(_max_queue_depth, sizeof(cmdPWM_t *));
  cmdQueue_t cmd_q = {"pwmEngine", "pwm", _cmd_q};
  mcrCmdQueues::registerQ(cmd_q);

  while (true) {
    BaseType_t queue_rc = pdFALSE;
    cmdPWM_t *cmd = nullptr;

    queue_rc = xQueueReceive(_cmd_q, &cmd, portMAX_DELAY);
    // wrap in a unique_ptr so it is freed when out of scope
    std::unique_ptr<cmdPWM> cmd_ptr(cmd);
    elapsedMicros process_cmd;

    if (queue_rc == pdFALSE) {
      ESP_LOGW(tagCommand(), "[rc=%d] queue receive failed", queue_rc);
      continue;
    }

    // is the command for this mcr?

    const string_t &mcr_name = Net::getName();

    if (cmd->matchExternalDevID(mcr_name) == false) {
      continue;
    } else {
      ESP_LOGI(tagCommand(), "recv'd cmd: %s", cmd->debug().get());
    }

    cmd->translateDevID(mcr_name, "self");

    pwmDev_t *dev = findDevice(cmd->internalDevID());

    if ((dev != nullptr) && dev->isValid()) {
      bool set_rc = false;

      trackSwitchCmd(true);

      // needBus();
      // ESP_LOGV(tagCommand(), "attempting to aquire bux mutex...");
      // elapsedMicros bus_wait;
      // takeBus();

      // if (bus_wait < 500) {
      //   ESP_LOGV(tagCommand(), "acquired bus mutex (%lluus)",
      //            (uint64_t)bus_wait);
      // } else {
      //   ESP_LOGW(tagCommand(), "acquire bus mutex took %0.2fms",
      //            (float)(bus_wait / 1000.0));
      // }

      ESP_LOGI(tagCommand(), "processing cmd for: %s", dev->id().c_str());

      dev->writeStart();
      set_rc = dev->updateDuty(cmd->duty());
      dev->writeStop();

      if (set_rc) {
        commandAck(*cmd);
      }

      trackSwitchCmd(false);

      // clearNeedBus();
      // giveBus();
    } else {
      ESP_LOGW(tagCommand(), "device %s not available",
               (const char *)cmd->internalDevID().c_str());
    }

    if (process_cmd > 100000) { // 100ms
      ESP_LOGW(tagCommand(), "took %0.3fms for %s",
               (float)(process_cmd / 1000.0), cmd->debug().get());
    }
  }
}

bool pwmEngine::commandAck(cmdPWM_t &cmd) {
  bool rc = false;
  pwmDev_t *dev = findDevice(cmd.internalDevID());

  if (dev != nullptr) {
    rc = readDevice(dev);

    if (rc && cmd.ack()) {
      setCmdAck(cmd);
      publish(cmd);
    }
  } else {
    ESP_LOGW(tagCommand(), "unable to find device for cmd ack %s",
             cmd.debug().get());
  }

  float elapsed_ms = (float)(cmd.latency_us() / 1000.0);
  ESP_LOGI(tagCommand(), "cmd took %0.3fms for: %s", elapsed_ms,
           dev->debug().get());

  if (elapsed_ms > 100.0) {
    ESP_LOGW(tagCommand(), "ACK took %0.3fms", elapsed_ms);
  }

  return rc;
}

void pwmEngine::core(void *task_data) {
  bool net_name = false;

  if (configureTimer() == false) {
    return;
  }

  ledc_fade_func_install(0);

  ESP_LOGV(tagEngine(), "waiting for normal ops...");
  Net::waitForNormalOps();

  // wait for up to 30 seconds for name assigned by mcp
  // if the assigned name is not available then device names will use
  // the pwm/mcr.<mac addr>.<bus>.<device> format

  // this is because pwm devices do not have a globally assigned
  // unique identifier (like Maxim / Dallas Semiconductors devices)
  ESP_LOGV(tagEngine(), "waiting for network name...");
  net_name = Net::waitForName();

  if (net_name == false) {
    ESP_LOGW(tagEngine(), "network name not available, using host name");
  }

  ESP_LOGV(tagEngine(), "normal ops, proceeding to task loop");

  saveTaskLastWake(CORE);
  for (;;) {
    // signal to other tasks the dsEngine task is in it's run loop
    // this ensures all other set-up activities are complete before
    engineRunning();

    // do high-level engine actions here (e.g. general housekeeping)
    taskDelayUntil(CORE, _loop_frequency);
  }
}

void pwmEngine::discover(void *data) {
  logSubTaskStart(data);
  saveTaskLastWake(DISCOVER);

  while (waitForEngine()) {

    trackDiscover(true);

    for (uint8_t i = 1; i <= 4; i++) {
      mcrDevAddr_t addr(i);
      pwmDev_t dev(addr);

      if (pwmDev_t *found = (pwmDev_t *)justSeenDevice(dev)) {
        ESP_LOGV(tagDiscover(), "already know %s", found->debug().get());
      } else {
        pwmDev_t *new_dev = new pwmDev(dev);
        ESP_LOGI(tagDiscover(), "new (%p) %s", (void *)new_dev,
                 dev.debug().get());

        new_dev->setMissingSeconds(60);
        new_dev->configureChannel();

        if (new_dev->lastRC() == ESP_OK) {

          addDevice(new_dev);
        } else {
          ESP_LOGE(tagDiscover(), "%s", new_dev->debug().get());
        }
      }
    }

    trackDiscover(false);

    if (numKnownDevices() > 0) {
      devicesAvailable();
    }

    // we want to discover
    saveTaskLastWake(DISCOVER);
    taskDelayUntil(DISCOVER, _discover_frequency);
  }
}

void pwmEngine::report(void *data) {

  logSubTaskStart(data);
  saveTaskLastWake(REPORT);

  while (waitFor(devicesAvailableBit())) {
    if (numKnownDevices() == 0) {
      taskDelayUntil(REPORT, _report_frequency);
      continue;
    }

    Net::waitForNormalOps();

    trackReport(true);

    for_each(beginDevices(), endDevices(),
             [this](std::pair<string_t, pwmDev_t *> item) {
               auto dev = item.second;

               if (dev->available()) {

                 if (readDevice(dev)) {
                   publish(dev);
                   ESP_LOGV(tagReport(), "%s success", dev->debug().get());
                 } else {
                   ESP_LOGE(tagReport(), "%s failed", dev->debug().get());
                 }

               } else {
                 if (dev->missing()) {
                   ESP_LOGW(tagReport(), "device missing: %s",
                            dev->debug().get());
                 }
               }
             });

    trackReport(false);
    reportMetrics();

    taskDelayUntil(REPORT, _report_frequency);
  }
}

bool pwmEngine::configureTimer() {
  esp_err_t timer_rc;

  ledc_timer_config_t ledc_timer = {.speed_mode = LEDC_HIGH_SPEED_MODE,
                                    .duty_resolution = LEDC_TIMER_13_BIT,
                                    .timer_num = LEDC_TIMER_0,
                                    .freq_hz = 5000,
                                    .clk_cfg = LEDC_AUTO_CLK};

  timer_rc = ledc_timer_config(&ledc_timer);

  if (timer_rc == ESP_OK) {
    ESP_LOGI(tagEngine(), "ledc timer configured");
    return true;
  } else {
    ESP_LOGE(tagEngine(), "ledc timer [%s]", esp_err_to_name(timer_rc));
    return false;
  }
}

pwmEngine_t *pwmEngine::instance() {
  if (__singleton__ == nullptr) {
    __singleton__ = new pwmEngine();
  }

  return __singleton__;
}

void pwmEngine::printUnhandledDev(pwmDev_t *dev) {
  ESP_LOGW(tagEngine(), "unhandled dev %s", dev->debug().get());
}

bool pwmEngine::readDevice(pwmDev_t *dev) {
  auto rc = false;

  dev->readStart();
  auto duty = ledc_get_duty(dev->speedMode(), dev->channel());
  dev->readStop();

  if (duty == LEDC_ERR_DUTY) {
    ESP_LOGW(tagEngine(), "error reading duty");
  } else {
    pwmReading_t *reading =
        new pwmReading(dev->externalName(), time(nullptr), dev->dutyMax(),
                       dev->dutyMin(), duty);

    reading->setLogReading();
    dev->setReading(reading);
    rc = true;
  }

  return rc;
}

} // namespace mcr
