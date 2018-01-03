/*
    engine.hpp - Master Control Remote Dallas Semiconductor
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

#include "../cmds/cmd.hpp"
#include "../devs/base.hpp"
#include "../include/mcr_types.hpp"
#include "../misc/util.hpp"
#include "../protocols/mqtt.hpp"

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
  uint32_t _loop_timeslice_ms = 10;
  uint32_t _discover_interval_ms = 30000;
  uint32_t _convert_interval_ms = 9000;
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

  const static uint16_t maxDevices();

  // functions for handling known devices
  mcrDev_t *findDevice(mcrDev_t &dev);
  bool isDeviceKnown(mcrDevID_t &id);

  // justSeenDevice():
  //    will return true if the device was found
  //    and call justSeen() on the device if found
  bool justSeenDevice(mcrDev_t &dev);

  // addDevice():
  //    will add a device to the known devices
  bool addDevice(mcrDev_t *dev);

  bool knowDevice(mcrDev_t &dev);
  bool forgetDevice(mcrDev_t &dev);

  // yes, yes... this is a poor man's iterator
  mcrDev_t *getFirstKnownDevice();
  mcrDev_t *getNextKnownDevice();
  mcrDev_t *getDevice(mcrDevAddr_t &addr);
  mcrDev_t *getDevice(mcrDevID_t &id);
  const uint8_t numKnownDevices();

  // state helper methods (grouped together for readability)
  bool isDiscoveryActive();
  bool isIdle();
  bool isReportActive();
  bool isConvertActive();
  bool isCmdActive();
  bool isCmdAckActive();

  virtual bool isCmdQueueEmpty() { return true; }
  virtual bool pendingCmd() { return false; }

  bool isCmdAckQueueEmpty();
  bool pendingCmdAcks();
  bool popPendingCmdAck(mcrCmd_t *cmd);
  bool pushPendingCmdAck(mcrCmd_t *cmd);

  // public methods for managing state tracking time metrics
  uint32_t lastDiscover() { return _last_discover; }
  uint32_t lastConvert() { return _last_convert; }
  uint32_t lastReport() { return _last_report; }
  uint32_t lastAckCmd() { return _last_ackcmd; }

  uint32_t lastDiscoverRunMS() { return _last_discover_ms; }
  uint32_t lastConvertRunMS() { return _last_convert_ms; }
  uint32_t lastReportRunMS() { return _last_report_ms; }
  uint32_t lastAckCmdMS() { return _last_ackcmd_ms; }

  void printStartDiscover(const char *func_name = nullptr, uint8_t indent = 2);
  void printStopDiscover(const char *func_name = nullptr, uint8_t indent = 2);
  void printStartConvert(const char *func_name = nullptr, uint8_t indent = 2);
  void printStopConvert(const char *func_name = nullptr, uint8_t indent = 2);
  void printStartReport(const char *func_name = nullptr, uint8_t indent = 2);
  void printStopReport(const char *func_name = nullptr, uint8_t indent = 2);

protected:
  bool specialDebugMode = false;
  bool debugMode = false;
  bool infoMode = false;
  bool noticeMode = false;
  bool discoverLogMode = false;

  virtual bool discover();
  bool needDiscover();
  void startDiscover();

  virtual bool convert();
  bool needConvert();
  void startConvert();
  bool convertTimeout();
  time_t lastConvertTimestamp();

  virtual bool report();
  bool needReport();
  void startReport();

  virtual bool cmd();
  bool needCmd();
  void startCmd();

  virtual bool cmdAck();
  bool needCmdAck();
  void startCmdAck();

  bool publish(Reading_t *reading);
  void idle(const char *func = nullptr);
  void endIdle();

  // subclasses should override these functions and do something useful
  virtual bool handleCmd() { return true; }
  virtual bool handleCmdAck(mcrCmd_t &cmd) { return true; }

  uint16_t devCount();

  void tempDebugOn();
  void tempDebugOff();
  void debugIdle(const char *c, mcrEngineState_t s);

  // timeslice helper methods
  inline bool timesliceRemaining();
  inline bool timesliceExpired();
  void resetLoopRuntime();
  time_t loopRunTime();
};

#endif // __cplusplus
#endif // mcp_engine_h
