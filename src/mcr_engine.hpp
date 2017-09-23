/*
    mcpr_engine.h - Master Control Remote Dallas Semiconductor
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

#include "mcr_dev.hpp"
#include "mcr_mqtt.hpp"
#include "mcr_util.hpp"

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

typedef enum {
  IDLE,
  INIT,
  DISCOVER,
  CONVERT,
  REPORT,
  CMD_ACK,
  STATS
} mcrEngineState_t;

class mcrEngine {
private:
  mcrEngineState_t _state = IDLE;
  uint16_t _dev_count = 0;
  Queue *_pending_ack_q = NULL;

  // Engine runtime controls
  ulong _loop_timeslice_ms = 20;
  ulong _discover_interval_ms = 30000;
  ulong _convert_interval_ms = 7000;
  ulong _report_interval_ms = 11000;
  ulong _stats_inverval_ms = 20000;

  ulong _discover_timeout_ms = 10000;
  ulong _convert_timeout_ms = 1000;
  ulong _report_timeout_ms = 10000;

  // Engine state tracking
  elapsedMillis _loop_runtime;
  elapsedMillis _last_idle;
  elapsedMillis _last_discover;
  elapsedMillis _last_convert;
  elapsedMillis _last_report;
  elapsedMillis _last_ackcmd;
  elapsedMillis _last_stats;

  // Engine runtime tracking by state
  ulong _last_idle_ms = 0;
  ulong _last_discover_ms = 0;
  ulong _last_convert_ms = 0;
  time_t _last_convert_timestamp = 0;
  ulong _last_report_ms = 0;
  ulong _last_ackcmd_ms = 0;
  ulong _last_stats_ms = 0;

public:
  mcrEngine(mcrMQTT *mqtt);

  virtual boolean init();
  virtual boolean loop();

  const static uint16_t maxDevices() { return MAX_DEVICES_PER_ENGINE; };

  // state helper methods (grouped together for readability)
  bool isDiscoveryActive() { return _state == DISCOVER ? true : false; }
  bool isIdle() { return (_state == IDLE) ? true : false; }
  bool isReportActive() { return _state == REPORT ? true : false; }
  bool isConvertActive() { return _state == CONVERT ? true : false; }
  bool isCmdAckActive() { return _state == CMD_ACK ? true : false; }

  bool isCmdAckQueueEmpty() {
    if (_pending_ack_q != NULL) {
      return _pending_ack_q->isEmpty();
    }
    return true;
  }

  bool pendingCmdAcks() {
    if (_pending_ack_q == NULL)
      return false;

    return (_pending_ack_q->nbRecs() > 0) ? true : false;
  };

  bool popPendingCmdAck(mcrDevID *id) {
    if (_pending_ack_q == NULL)
      return false;
    return _pending_ack_q->pop(id);
  }

  bool pushPendingCmdAck(char *name) {
    bool rc = false;
    mcrDevID_t id(name);

    rc = pushPendingCmdAck(&id);

    return rc;
  }

  bool pushPendingCmdAck(mcrDevID_t *id) {
    if (_pending_ack_q == NULL)
      return false;

    return _pending_ack_q->push(id);
  }

  // public methods for managing state tracking time metrics
  ulong lastDiscover() { return _last_discover; }
  ulong lastConvert() { return _last_convert; }
  ulong lastReport() { return _last_report; }
  ulong lastAckCmd() { return _last_ackcmd; }

  ulong lastDiscoverRunMS() { return _last_discover_ms; }
  ulong lastConvertRunMS() { return _last_convert_ms; }
  ulong lastReportRunMS() { return _last_report_ms; }
  ulong lastAckCmdMS() { return _last_ackcmd_ms; }

  void printStartDiscover(const char *func_name = NULL, uint8_t indent = 2) {
    mcrUtil::printDateTime(func_name);

    Serial.print("started, ");
    mcrUtil::printElapsed(lastDiscover(), false);
    Serial.println(" ms since last discover");
  }

  void printStopDiscover(const char *func_name = NULL, uint8_t indent = 2) {
    mcrUtil::printDateTime(func_name);

    if (devCount() == 0)
      Serial.print("[WARNING] ");

    Serial.print("finsihed, ");
    Serial.print(devCount());
    Serial.print(" devices discovered in ");
    Serial.print(lastDiscoverRunMS());
    Serial.println("ms");
  }

protected:
  mcrMQTT *mqtt;
  bool debugMode;

  virtual bool discover();
  virtual bool convert();
  virtual bool report();
  virtual bool cmdAck();

  // subclasses should override this function and do something useful
  virtual bool handleCmdAck(mcrDevID &id) { return true; }

  // static const uint8_t max_devices = MAX_DEVICES_PER_ENGINE;
  void addDevice() { _dev_count += 1; };
  uint16_t devCount() { return _dev_count; };
  virtual void clearKnownDevices() { _dev_count = 0; };

  void idle(const char *f) {

    // Serial.println();
    // Serial.print(f);
    // Serial.print(" called idle() _state = ");
    // Serial.print(_state);
    // Serial.println();

    switch (_state) {
    case IDLE:
      // do nothing if already IDLE
      break;

    case INIT:
      _last_idle = 0;
      break;

    case DISCOVER:
      _last_discover_ms = _last_discover;
      //_last_discover = 0;
      _last_idle = 0;
      break;

    case CONVERT:
      _last_convert_ms = _last_convert;
      //_last_convert = 0;
      _last_idle = 0;
      _last_convert_timestamp = now();
      break;

    case REPORT:
      _last_report_ms = _last_report;
      _last_report = 0;
      _last_idle = 0;
      break;

    case CMD_ACK:
      _last_ackcmd_ms = _last_ackcmd;
      _last_ackcmd = 0;
      _last_idle = 0;
      break;

    case STATS:
      _last_stats_ms = _last_stats;
      _last_stats = 0;
      _last_idle = 0;
      break;
    }
    _state = IDLE;
  };

  void debugIdle(const char *c, mcrEngineState_t s) {
    // Serial.println();
    // Serial.print(c);
    // Serial.print(" called and _state != IDLE ");
    // Serial.println();
  }

  void startDiscover() {
    debugIdle(__PRETTY_FUNCTION__, DISCOVER);
    _last_idle_ms = _last_idle;
    _state = DISCOVER;
    _last_discover = 0;
  };

  void startConvert() {
    debugIdle(__PRETTY_FUNCTION__, CONVERT);
    _last_idle_ms = _last_idle;
    _state = CONVERT;
    _last_convert = 0;
  };

  void startReport() {
    debugIdle(__PRETTY_FUNCTION__, REPORT);
    _last_idle_ms = _last_idle;
    _state = REPORT;
    _last_report = 0;
  };

  void startCmdAck() {
    debugIdle(__PRETTY_FUNCTION__, CMD_ACK);
    _last_idle_ms = _last_idle;
    _state = CMD_ACK;
    _last_ackcmd = 0;
  }

  bool convertTimeout() {
    return (_last_convert > _convert_timeout_ms) ? true : false;
  };

  inline time_t lastConvertTimestamp() { return _last_convert_timestamp; };

  bool needDiscover() {
    // case 1: if discover is active we must return true since the
    //          implementation of discover knows when to declare it is finished
    //          by calling idle
    // case 2:  if enough millis have elapsed that it is time to do another
    //          discovery
    if (isDiscoveryActive() || (_last_discover >= _discover_interval_ms))
      return true;

    return false;
  }

  bool needConvert() {
    if (isConvertActive() || (_last_convert >= _convert_interval_ms))
      return true;

    return false;
  }

  bool needReport() {
    if (isReportActive() || (_last_report >= _last_convert))
      return true;

    return false;
  }

  bool needCmdAck() {
    if (isCmdAckActive() || pendingCmdAcks())
      return true;

    return true;
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
