/*
    mcr_engine.hpp - Master Control Remote Dallas Semiconductor
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

#ifndef mcr_engine_h
#define mcr_engine_h

#ifdef __cplusplus

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include <OneWire.h>
#include <TimeLib.h>
#include <cppQueue.h>
#include <elapsedMillis.h>

#include "../devs/mcr_dev.hpp"
#include "../misc/mcr_util.hpp"
#include "../protocols/mcr_mqtt.hpp"
#include "../types/mcr_cmd.hpp"
#include "../types/mcr_type.hpp"

#define mcr_engine_version_1 1

// Set the version of MCP Remote
#ifndef mcr_engine_version
#define mcr_engine_version mcr_engine_version_1
#endif

// max devices supported by all mcrEngine
// implementation
// define this prior to the first include of this header
// to increase
#ifndef MAX_DEVICES_PER_ENGINE
#define MAX_DEVICES_PER_ENGINE 30
#endif

typedef class mcrEngine mcrEngine_t;

class mcrEngine {
private:
  mcrMQTT_t *_mqtt;
  mcrEngineState_t _state = IDLE;
  mcrDev_t *_known_devs[MAX_DEVICES_PER_ENGINE] = {0x00};
  uint16_t _dev_count = 0;
  Queue *_pending_ack_q = nullptr;
  bool _savedDebugMode = false;
  uint8_t _next_known_index = 0;

  // Engine runtime controls
  uint32_t _loop_timeslice_ms = 50;
  uint32_t _discover_interval_ms = 30000;
  uint32_t _convert_interval_ms = 7000;
  uint32_t _report_interval_ms = 11000;
  uint32_t _stats_inverval_ms = 20000;

  uint32_t _discover_timeout_ms = 10000;
  uint32_t _convert_timeout_ms = 3000;
  uint32_t _report_timeout_ms = 10000;

  // Engine state tracking
  elapsedMillis _loop_runtime;
  elapsedMillis _last_idle;
  elapsedMillis _last_discover;
  elapsedMillis _last_convert;
  elapsedMillis _last_report;
  elapsedMillis _last_cmd;
  elapsedMillis _last_ackcmd;
  elapsedMillis _last_stats;

  // Engine runtime tracking by state
  uint32_t _last_idle_ms = 0;
  uint32_t _last_discover_ms = 0;
  uint32_t _last_convert_ms = 0;
  uint32_t _last_report_ms = 0;
  uint32_t _last_cmd_ms = 0;
  uint32_t _last_ackcmd_ms = 0;
  uint32_t _last_stats_ms = 0;
  time_t _last_convert_timestamp = 0;

public:
  mcrEngine(mcrMQTT *mqtt);

  virtual boolean init();
  virtual boolean loop();

  const static uint16_t maxDevices() { return MAX_DEVICES_PER_ENGINE; };

  // functions for handling known devices
  mcrDev_t *findDevice(mcrDev_t &dev) {
    mcrDev_t *found_dev = nullptr;
    for (uint8_t i = 0; ((i < maxDevices()) && (found_dev == nullptr)); i++) {
      if (dev == _known_devs[i]) {
        found_dev = _known_devs[i];
      }
    }
    return found_dev;
  }

  bool knowDevice(mcrDev_t &dev) {
    auto rc = true;
    mcrDev_t *found_dev = findDevice(dev);

    if (found_dev) { // if we already know this device then flag it as seen
      found_dev->justSeen();
    } else {
      if (devCount() < maxDevices()) {             // make sure we have a slot
        _known_devs[devCount()] = new mcrDev(dev); // create (copy) device
        _dev_count += 1;
      } else { // log a warning if no slots available
        logDateTime(__PRETTY_FUNCTION__);
        log("[WARNING] attempt to exceed supported max devices", true);
        rc = false;
      }
    }
    return rc;
  }

  bool forgetDevice(mcrDev_t &dev) {
    auto rc = true;
    mcrDev_t *found_dev = nullptr;

    for (uint8_t i = 0; ((i < maxDevices()) && (found_dev == nullptr)); i++) {
      if (_known_devs[i] && dev == _known_devs[i]) {
        found_dev = _known_devs[i];
        delete found_dev;
        _known_devs[i] = nullptr;
      }
    }

    return rc;
  }

  // yes, yes... this is a poor man's iterator
  mcrDev_t *getFirstKnownDevice() {
    _next_known_index = 0;
    return getNextKnownDevice();
  }

  mcrDev_t *getNextKnownDevice() {
    mcrDev_t *found_dev = nullptr;

    for (; ((_next_known_index < maxDevices()) && (found_dev == nullptr));
         _next_known_index++) {
      if (_known_devs[_next_known_index] != nullptr) {
        found_dev = _known_devs[_next_known_index];
        _next_known_index += 1;
      }
    }

    return found_dev;
  }

  mcrDev_t *getDevice(mcrDevAddr_t &addr) {
    mcrDev_t *found_dev = nullptr;

    for (uint8_t i = 0; ((i < maxDevices()) && (found_dev == nullptr)); i++) {
      if (_known_devs[i] && (addr == _known_devs[i]->addr())) {
        found_dev = _known_devs[i];
      }
    }

    return found_dev;
  }

  mcrDev_t *getDevice(mcrDevID_t &id) {
    mcrDev_t *found_dev = nullptr;

    // if (debugMode) {
    //  logDateTime(__PRETTY_FUNCTION__);
    //  log("searching: ");
    //  }

    for (uint8_t i = 0; ((i < maxDevices()) && (found_dev == nullptr)); i++) {
      //  log(i);
      //  log(" ");
      if (_known_devs[i] && (id == _known_devs[i]->id())) {
        //  log("found ");
        // log(_known_devs[i]->id());
        //  log(" ", true);
        found_dev = _known_devs[i];
      }
    }

    return found_dev;
  }

  // mcrDev_t *getDevice(mcrCmd_t &cmd) {
  //   mcrDev_t *found_dev = nullptr;
  //
  //   for (uint8_t i = 0; ((i < maxDevices()) && (found_dev == nullptr)); i++)
  //   {
  //     if (cmd.dev_id() == _known_devs[i]->id()) {
  //       found_dev = _known_devs[i];
  //     }
  //   }
  //   return found_dev;
  // }

  // state helper methods (grouped together for readability)
  bool isDiscoveryActive() { return _state == DISCOVER ? true : false; }
  bool isIdle() { return (_state == IDLE) ? true : false; }
  bool isReportActive() { return _state == REPORT ? true : false; }
  bool isConvertActive() { return _state == CONVERT ? true : false; }
  bool isCmdActive() { return _state == CMD ? true : false; }
  bool isCmdAckActive() { return _state == CMD_ACK ? true : false; }

  virtual bool isCmdQueueEmpty() { return true; }
  virtual bool pendingCmd() { return false; }

  bool isCmdAckQueueEmpty() {
    if (_pending_ack_q != nullptr) {
      return _pending_ack_q->isEmpty();
    }
    return true;
  }

  bool pendingCmdAcks() {
    if (_pending_ack_q == nullptr)
      return false;

    return (_pending_ack_q->nbRecs() > 0) ? true : false;
  };

  bool popPendingCmdAck(mcrCmd_t *cmd) {
    if (_pending_ack_q == nullptr)
      return false;
    return _pending_ack_q->pop(cmd);
  }

  bool pushPendingCmdAck(mcrCmd_t *cmd) {
    bool rc = false;

    rc = _pending_ack_q->push(cmd);

    return rc;
  }

  // public methods for managing state tracking time metrics
  uint32_t lastDiscover() { return _last_discover; }
  uint32_t lastConvert() { return _last_convert; }
  uint32_t lastReport() { return _last_report; }
  uint32_t lastAckCmd() { return _last_ackcmd; }

  uint32_t lastDiscoverRunMS() { return _last_discover_ms; }
  uint32_t lastConvertRunMS() { return _last_convert_ms; }
  uint32_t lastReportRunMS() { return _last_report_ms; }
  uint32_t lastAckCmdMS() { return _last_ackcmd_ms; }

  void printStartDiscover(const char *func_name = nullptr, uint8_t indent = 2) {
    logDateTime(func_name);

    log("started, ");
    logElapsed(lastDiscover());
    log(" since last discover", true);
  }

  void printStopDiscover(const char *func_name = nullptr, uint8_t indent = 2) {
    logDateTime(func_name);

    if (devCount() == 0)
      log("[WARNING] ");

    log("finished, found ");
    log(devCount());
    log(" devices in ");
    logElapsed(lastDiscoverRunMS(), true);
  }

  void printStartConvert(const char *func_name = nullptr, uint8_t indent = 2) {
    logDateTime(func_name);

    log("started, ");
    logElapsed(lastConvert());
    log(" ms since last convert", true);
  }

  void printStopConvert(const char *func_name = nullptr, uint8_t indent = 2) {
    logDateTime(func_name);

    if (convertTimeout())
      log("[WARNING] ");

    log("finished, took ");

    if (convertTimeout()) {
      logElapsed(lastConvert());
      log(" *TIMEOUT*", true);
    } else {
      logElapsed(lastConvertRunMS(), true);
    }
  }

protected:
  bool debugMode = false;
  bool infoMode = false;
  bool noticeMode = false;

  virtual bool discover();
  virtual bool convert();
  virtual bool report();
  virtual bool cmd();
  virtual bool cmdAck();

  bool publish(Reading_t *reading) {
    auto rc = false;

    if (reading) {
      _mqtt->publish(reading);
    }
    return rc;
  }
  void idle(const char *func = nullptr);

  // subclasses should override these functions and do something useful
  virtual bool handleCmd() { return true; }
  virtual bool handleCmdAck(mcrCmd_t &cmd) { return true; }

  uint16_t devCount() { return _dev_count; };
  // virtual void clearKnownDevices() { _dev_count = 0; };
  // void addDevice() { _dev_count += 1; };

  void tempDebugOn() {
    _savedDebugMode = debugMode;
    debugMode = true;
  }

  void tempDebugOff() { debugMode = _savedDebugMode; }

  void debugIdle(const char *c, mcrEngineState_t s) {
    // Serial.println();
    // Serial.print(c);
    // Serial.print(" called and _state != IDLE ");
    // Serial.println();
  }

  void endIdle() { _last_idle_ms = _last_idle; }

  void startDiscover() {
    debugIdle(__PRETTY_FUNCTION__, DISCOVER);
    endIdle();
    _state = DISCOVER;
    _last_discover = 0;
  };

  void startConvert() {
    debugIdle(__PRETTY_FUNCTION__, CONVERT);
    endIdle();
    _state = CONVERT;
    _last_convert = 0;
  };

  void startReport() {
    debugIdle(__PRETTY_FUNCTION__, REPORT);
    endIdle();
    _state = REPORT;
    _last_report = 0;
  };

  void startCmd() {
    debugIdle(__PRETTY_FUNCTION__, CMD);
    endIdle();
    _state = CMD;
    _last_cmd = 0;
  }

  void startCmdAck() {
    debugIdle(__PRETTY_FUNCTION__, CMD_ACK);
    endIdle();
    _state = CMD_ACK;
    _last_ackcmd = 0;
  }

  bool convertTimeout() {
    return (_last_convert > _convert_timeout_ms) ? true : false;
  };

  inline time_t lastConvertTimestamp() { return _last_convert_timestamp; };

  bool needDiscover() {
    // case 1: if discover is active we must return true since the
    //          implementation of discover knows when to declare it is
    //          finished by calling idle
    // case 2:  if enough millis have elapsed that it is time to do another
    //          discovery
    if (isDiscoveryActive() || (_last_discover > _discover_interval_ms))
      return true;

    return false;
  }

  bool needConvert() {
    if (isConvertActive() || (_last_convert > _convert_interval_ms))
      return true;

    return false;
  }

  bool needReport() {
    if (isReportActive() || (_last_report > _last_convert))
      return true;

    return false;
  }

  bool needCmd() {
    if (isCmdActive() || pendingCmd())
      return true;

    return false;
  }

  bool needCmdAck() {
    if (isCmdAckActive() || pendingCmdAcks())
      return true;

    return false;
  }

  // timeslice helper methods
  inline bool timesliceRemaining() {
    return (_loop_runtime <= _loop_timeslice_ms) ? true : false;
  }

  inline bool timesliceExpired() {
    return (_loop_runtime > _loop_timeslice_ms) ? true : false;
  }

  void resetLoopRuntime() { _loop_runtime = 0; }
  time_t loopRunTime() { return _loop_runtime; };
};

#endif // __cplusplus
#endif // mcp_engine_h
