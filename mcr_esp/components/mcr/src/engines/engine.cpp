/*
    engine.cpp - Master Control Remote Engine
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
#include <iomanip>
#include <map>
#include <sstream>
#include <string>

#include <FreeRTOS.h>
#include <System.h>
#include <Task.h>
#include <esp_log.h>
#include <freertos/event_groups.h>

#include "cmd.hpp"
#include "engine.hpp"
#include "readings.hpp"
#include "util.hpp"

static const char tTAG[] = "mcrEngine";

mcrEngine::mcrEngine(mcrMQTT *mqtt) { _mqtt = mqtt; }

uint32_t mcrEngine::maxDevices() { return MAX_DEVICES_PER_ENGINE; };
uint32_t mcrEngine::devCount() { return _dev_count; };

bool mcrEngine::init() { return init(nullptr); }
bool mcrEngine::init(void *p) {
  bool rc = true;

  return rc;
}

uint32_t mcrEngine::numKnownDevices() {
  uint32_t dev_count = 0;

  for (uint32_t i = 0; i < maxDevices(); i++) {
    if (_known_devs[i] != nullptr) {
      dev_count = dev_count + 1;
    }
  }

  return dev_count;
}

// mcrEngine::discover()
// this method should be called often to ensure proper operator.
//
//  1. if the enough millis have elapsed since the last full discovery
//     this method then it will start a new discovery.
//  2. if a discovery cycle is in-progress this method will execute
//     a single search
bool mcrEngine::discover() {
  bool rc = true;

  return rc;
}

bool mcrEngine::report() {
  bool rc = true;

  return rc;
}

bool mcrEngine::convert() {
  bool rc = true;

  return rc;
}

bool mcrEngine::cmd() {
  bool rc = true;

  return rc;
}

bool mcrEngine::cmdAck() {
  bool rc = true;

  return rc;
}

bool mcrEngine::publish(Reading_t *reading) {
  auto rc = false;

  if (reading) {
    _mqtt->publish(reading);
  }
  return rc;
}

// functions for handling known devices
mcrDev_t *mcrEngine::findDevice(mcrDev_t &dev) {

  if (LOG_LOCAL_LEVEL >= ESP_LOG_DEBUG) {
    ESP_LOGD(tTAG, "finding %s", dev.debug().c_str());
  }

  return getDevice(dev.id());
}

bool mcrEngine::isDeviceKnown(mcrDevID_t &id) {
  auto rc = false;

  for (uint32_t i = 0; ((i < maxDevices()) && (!rc)); i++) {
    mcrDev_t *dev = _known_devs[i];

    if (dev->id() == id) {
      rc = true;
    }
  }

  return rc;
}

mcrDev_t *mcrEngine::justSeenDevice(mcrDev_t &dev) {
  mcrDev_t *found_dev = nullptr;

  if (LOG_LOCAL_LEVEL >= ESP_LOG_DEBUG) {
    ESP_LOGD(tTAG, "just saw: %s", dev.debug().c_str());
  }

  for (uint32_t i = 0; ((i < maxDevices()) && (found_dev == nullptr)); i++) {
    mcrDev_t *search_dev = _known_devs[i];

    if ((search_dev) && (search_dev->id() == dev.id())) {
      search_dev->justSeen();
      found_dev = search_dev;
    }
  }

  auto search = _dev_map.find(dev.id());
  if (search != _dev_map.end()) {
    auto map_dev = search->second;
  }

  return found_dev;
}

bool mcrEngine::addDevice(mcrDev_t *dev) {
  auto rc = false;

  if (LOG_LOCAL_LEVEL >= ESP_LOG_DEBUG) {
    ESP_LOGD(tTAG, "adding: %s", dev->debug().c_str());
  }

  for (uint32_t i = 0; ((i < maxDevices()) && (!rc)); i++) {
    mcrDev_t *search_dev = _known_devs[i];

    // find the first empty device location and store the new device
    if (search_dev == nullptr) {
      if (LOG_LOCAL_LEVEL >= ESP_LOG_INFO) {
        ESP_LOGD(tTAG, "added %s at slot %d", dev->debug().c_str(), i);
      }

      dev->justSeen();
      _known_devs[i] = dev;
      _dev_count += 1;
      rc = true;
    }
  }

  if (rc == false) {
    ESP_LOGW(tTAG, "attempt to exceed max devices!");
  }

  // auto search = _dev_map.find(*dev);
  // if (search != _dev_map.end()) {
  // }

  return rc;
}

bool mcrEngine::forgetDevice(mcrDev_t &dev) {
  auto rc = true;
  mcrDev_t *found_dev = nullptr;

  for (uint32_t i = 0; ((i < maxDevices()) && (found_dev == nullptr)); i++) {
    if (_known_devs[i] && (dev.id() == _known_devs[i]->id())) {
      found_dev = _known_devs[i];
      delete found_dev;
      _known_devs[i] = nullptr;
    }
  }

  return rc;
}

// yes, yes... this is a poor man's iterator
mcrDev_t *mcrEngine::getFirstKnownDevice() {
  _next_known_index = 0;
  return getNextKnownDevice();
}

mcrDev_t *mcrEngine::getNextKnownDevice() {
  mcrDev_t *found_dev = nullptr;

  if (_next_known_index >= (maxDevices() - 1)) // bail out if we've reached
    return nullptr; // the end of possible known devices

  for (; ((_next_known_index < maxDevices()) && (found_dev == nullptr));
       _next_known_index++) {
    if (_known_devs[_next_known_index] != nullptr) {
      found_dev = _known_devs[_next_known_index];
    }
  }

  return found_dev;
}

mcrDev_t *mcrEngine::getDevice(mcrDevAddr_t &addr) {
  mcrDev_t *found_dev = nullptr;

  for (uint32_t i = 0; ((i < maxDevices()) && (found_dev == nullptr)); i++) {
    if (_known_devs[i] && (addr == _known_devs[i]->addr())) {
      found_dev = _known_devs[i];
    }
  }

  return found_dev;
}

mcrDev_t *mcrEngine::getDevice(const mcrDevID_t &id) {
  mcrDev_t *found_dev = nullptr;

  for (uint32_t i = 0; ((i < maxDevices()) && (found_dev == nullptr)); i++) {
    if (_known_devs[i] && (id == _known_devs[i]->id())) {
      found_dev = _known_devs[i];
    }
  }

  return found_dev;
}

int64_t mcrEngine::trackPhase(mcrEngineMetric_t &phase, bool start) {
  if (start) {
    phase.start_us = esp_timer_get_time();
  } else {
    time_t recent_us = esp_timer_get_time() - phase.start_us;
    phase.elapsed_us = (phase.elapsed_us > 0)
                           ? ((phase.elapsed_us + recent_us) / 2)
                           : recent_us;
    phase.start_us = 0;
    phase.last_time = time(nullptr);
  }

  return phase.elapsed_us;
}

// Runtime metrics
int64_t mcrEngine::trackConvert(bool start) {
  return trackPhase(metrics.convert, start);
}
int64_t mcrEngine::convertUS() { return metrics.convert.elapsed_us; }
time_t mcrEngine::lastConvertTimestamp() { return metrics.convert.last_time; }

int64_t mcrEngine::trackDiscover(bool start) {
  return trackPhase(metrics.discover, start);
}
int64_t mcrEngine::discoverUS() { return metrics.discover.elapsed_us; }
time_t mcrEngine::lastDiscoverTimestamp() { return metrics.discover.last_time; }

int64_t mcrEngine::trackReport(bool start) {
  return trackPhase(metrics.report, start);
}
int64_t mcrEngine::reportUS() { return metrics.report.elapsed_us; }
time_t mcrEngine::lastReportTimestamp() { return metrics.report.last_time; }

int64_t mcrEngine::trackSwitchCmd(bool start) {
  return trackPhase(metrics.switch_cmd, start);
}
int64_t mcrEngine::switchCmdUS() { return metrics.switch_cmd.elapsed_us; }
time_t mcrEngine::lastSwitchCmdTimestamp() {
  return metrics.switch_cmd.last_time;
}

void mcrEngine::runtimeMetricsReport(const char *lTAG) {
  typedef struct {
    const char *tag;
    mcrEngineMetric_t *metric;
  } metricDef_t;

  std::ostringstream rep_str;

  metricDef_t m[] = {{"convert", &(metrics.convert)},
                     {"discover", &(metrics.discover)},
                     {"report", &(metrics.report)},
                     {"switch_cmd", &(metrics.switch_cmd)}};

  for (int i = 0; i < (sizeof(m) / sizeof(metricDef_t)); i++) {
    if (m[i].metric->elapsed_us > 0) {
      rep_str << m[i].tag << "=";
      rep_str << std::fixed << std::setprecision(2)
              << ((float)(m[i].metric->elapsed_us / 1000.0));
      rep_str << "ms ";
    }
  }

  ESP_LOGI(lTAG, "phase metrics: %s", rep_str.str().c_str());
}
