uint8_t /*
     mcpr_engine.cpp - Master Control Remote Engine
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

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include <OneWire.h>

#include "../cmds/cmd.hpp"
#include "../include/readings.hpp"
#include "../misc/util.hpp"
#include "engine.hpp"

// FIXME: For some unknown reason new Queue results in a hang
//        so, as a workaround, we will statically allocate a single queue.
//        This implies that only one instantied class of mcrEngine can handle
//        command acks
// static Queue queue = Queue(sizeof(mcrCmd_t), 10, FIFO);

mcrEngine::mcrEngine(mcrMQTT *mqtt) {

  _mqtt = mqtt;
  // setting to the discover interval will
  // prevent a delay for first discovery cycle at startup
  _last_discover = _discover_interval_ms;

  _last_report = 0;
  _last_convert = 0;
  _dev_count = 0;
  _state = IDLE;
}

const uint8_t mcrEngine::maxDevices() { return MAX_DEVICES_PER_ENGINE; };
uint8_t mcrEngine::devCount() { return _dev_count; };

bool mcrEngine::init() { return init(nullptr); }
bool mcrEngine::init(Queue *cmd_q, Queue *ack_q) {
  bool rc = true;

  _cmd_q = cmd_q;
  _ack_q = ack_q;

  return rc;
}

const uint8_t mcrEngine::numKnownDevices() {
  uint8_t dev_count = 0;

  for (uint8_t i = 0; i < maxDevices(); i++) {
    if (_known_devs[i] != nullptr) {
      dev_count = dev_count + 1;
    }
  }

  return dev_count;
}

bool mcrEngine::loop() {
  resetLoopRuntime();

  cmdAck();
  cmd();

  discover();
  convert();
  report();

  return true;
}

// mcrEngine::discover()
// this method should be called often to ensure proper operator.
//
//  1. if the enough millis have elapsed since the last full discovery
//     this method then it will start a new discovery.
//  2. if a discovery cycle is in-progress this method will execute
//     a single search

bool mcrEngine::discover() {
  if (timesliceRemaining()) {
    if (needDiscover()) {
      if (isIdle())
        startDiscover();

      if (isDiscoveryActive())
        idle(__PRETTY_FUNCTION__);
    }
  }

  return true;
}

bool mcrEngine::report() {
  bool rc = true;

  if (timesliceRemaining()) {
    if (needReport()) {
      if (isIdle())
        startReport();

      if (isReportActive())
        idle(__PRETTY_FUNCTION__);
    }
  }

  return rc;
}

// mcrEngine::temp_convert()
// this method should be called often to ensure proper operator.
//
//  1. if enough millis have elapsed since the last temperature
//     conversion then a new one will be started if mcrEngine is
//     idle
//  2. if a temperature conversion is in-progress this method will
//     do a single check to determine if conversion is finished

bool mcrEngine::convert() {
  bool rc = true;

  if (timesliceRemaining()) {
    if (needConvert()) {
      // start a temperature conversion if one isn't already in-progress
      // TODO - only handles powered devices as of 2017-09-11
      if (isIdle()) {
        startConvert();
      } else {
        if (isConvertActive())
          idle(__PRETTY_FUNCTION__);
      }
    }
  }
  return rc;
}

bool mcrEngine::convertTimeout() {
  return (_last_convert > _convert_timeout_ms) ? true : false;
};

time_t mcrEngine::lastConvertTimestamp() { return _last_convert_timestamp; };

bool mcrEngine::cmd() {
  if (timesliceRemaining() && isIdle() && pendingCmd()) {
    handleCmd();
  }
  return true;
}

bool mcrEngine::cmdAck() {
  bool rc = true;

  if (timesliceRemaining() && isIdle() && pendingCmdAcks()) {
    mcrCmd_t cmd;

    if (popPendingCmdAck(&cmd)) {
      handleCmdAck(cmd);
    } else {
      logDateTime(__PRETTY_FUNCTION__);
      log("[WARNING] popPendingCmdAck() returned false", true);
    }
  }
  return rc;
}

void mcrEngine::idle(const char *func) {

  if (debugMode) {
    if (func)
      logDateTime(func);
    else
      logDateTime(__PRETTY_FUNCTION__);

    log("invoked idle() with state ");
    log(stateAsString(_state), true);
  }

  switch (_state) {
  case IDLE: // specifying this case to avoid mcrEngine::mcrEngine::compiler
             // warning
    break;

  case INIT:
    break;

  case DISCOVER:
    _last_discover_ms = _last_discover;
    break;

  case CONVERT:
    _last_convert_ms = _last_convert;
    _last_convert_timestamp = now();
    break;

  case REPORT:
    _last_report_ms = _last_report;
    _last_report = 0;
    break;

  case CMD:
    _last_cmd_ms = _last_cmd;
    _last_cmd = 0;
    break;

  case CMD_ACK:
    _last_ackcmd_ms = _last_ackcmd;
    _last_ackcmd = 0;
    break;

  case STATS:
    _last_stats_ms = _last_stats;
    _last_stats = 0;
    break;
  }

  if (_state != IDLE)
    _last_idle = 0;

  _state = IDLE;
};

bool mcrEngine::publish(Reading_t *reading) {
  auto rc = false;

  if (reading) {
    _mqtt->publish(reading);
  }
  return rc;
}

// functions for handling known devices
mcrDev_t *mcrEngine::findDevice(mcrDev_t &dev) {
  if (debugMode) {
    logDateTime(__PRETTY_FUNCTION__);
    log("finding ");
    dev.debug(true);
  }

  return getDevice(dev.id());
}

bool mcrEngine::isDeviceKnown(mcrDevID_t &id) {
  auto rc = false;

  for (uint8_t i = 0; ((i < maxDevices()) && (!rc)); i++) {
    mcrDev_t *dev = _known_devs[i];

    if (dev->id() == id) {
      rc = true;
    }
  }

  return rc;
}

bool mcrEngine::justSeenDevice(mcrDev_t &dev) {
  auto rc = false;

  if (debugMode) {
    logDateTime(__PRETTY_FUNCTION__);
    dev.debug(true);
  }

  for (uint8_t i = 0; ((i < maxDevices()) && (!rc)); i++) {
    mcrDev_t *search_dev = _known_devs[i];

    if ((search_dev) && (search_dev->id() == dev.id())) {
      search_dev->justSeen();
      rc = true;
    }
  }

  return rc;
}

bool mcrEngine::addDevice(mcrDev_t *dev) {
  auto rc = false;

  if (infoMode) {
    logDateTime(__PRETTY_FUNCTION__);
    log("adding ");
    dev->debug(true);
  }

  for (uint8_t i = 0; ((i < maxDevices()) && (!rc)); i++) {
    mcrDev_t *search_dev = _known_devs[i];

    // find the first empty device location and store the new device
    if (search_dev == nullptr) {
      if (debugMode) {
        logDateTime(__PRETTY_FUNCTION__);
        log("added ");
        dev->debug();
        log(" at slot ");
        log(i, true);
      }

      dev->justSeen();
      _known_devs[i] = dev;
      _dev_count += 1;
      rc = true;
    }
  }

  if (rc == false) {
    logDateTime(__PRETTY_FUNCTION__);
    log("[WARNING] attempt to exceed max devices", true);
  }

  return rc;
}

bool mcrEngine::forgetDevice(mcrDev_t &dev) {
  auto rc = true;
  mcrDev_t *found_dev = nullptr;

  for (uint8_t i = 0; ((i < maxDevices()) && (found_dev == nullptr)); i++) {
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

  for (uint8_t i = 0; ((i < maxDevices()) && (found_dev == nullptr)); i++) {
    if (_known_devs[i] && (addr == _known_devs[i]->addr())) {
      found_dev = _known_devs[i];
    }
  }

  return found_dev;
}

mcrDev_t *mcrEngine::getDevice(mcrDevID_t &id) {
  mcrDev_t *found_dev = nullptr;

  if (debugMode) {
    logDateTime(__PRETTY_FUNCTION__);
    log("looking up ");
    id.debug(true);
  }

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

  if (debugMode && found_dev == nullptr) {
    logDateTime(__PRETTY_FUNCTION__);
    id.debug(false);
    log(" not known", true);
  }

  return found_dev;
}

bool mcrEngine::needDiscover() {
  // case 1: if discover is active we must return true since the
  //          implementation of discover knows when to declare it is
  //          finished by calling idle
  // case 2:  if enough millis have elapsed that it is time to do another
  //          discovery
  if (isDiscoveryActive() || (_last_discover > _discover_interval_ms))
    return true;

  return false;
}

bool mcrEngine::needConvert() {

  if (isConvertActive() || (_last_convert > _convert_interval_ms))
    return true;

  return false;
}

bool mcrEngine::needReport() {
  if (isReportActive() || (_last_report > _last_convert))
    return true;

  return false;
}

bool mcrEngine::needCmd() {
  if (isCmdActive() || pendingCmd())
    return true;

  return false;
}

bool mcrEngine::needCmdAck() {
  if (isCmdAckActive() || pendingCmdAcks())
    return true;

  return false;
}

// timeslice helper methods
inline bool mcrEngine::timesliceRemaining() {
  return (_loop_runtime <= _loop_timeslice_ms) ? true : false;
}

inline bool mcrEngine::timesliceExpired() {
  return (_loop_runtime > _loop_timeslice_ms) ? true : false;
}

void mcrEngine::resetLoopRuntime() { _loop_runtime = 0; }
time_t mcrEngine::loopRunTime() { return _loop_runtime; };

// state helper methods (grouped together for readability)
bool mcrEngine::isDiscoveryActive() {
  return _state == DISCOVER ? true : false;
}
bool mcrEngine::isIdle() { return (_state == IDLE) ? true : false; }
bool mcrEngine::isReportActive() { return _state == REPORT ? true : false; }
bool mcrEngine::isConvertActive() { return _state == CONVERT ? true : false; }
bool mcrEngine::isCmdActive() { return _state == CMD ? true : false; }
bool mcrEngine::isCmdAckActive() { return _state == CMD_ACK ? true : false; }

bool mcrEngine::areCmdQueuesEmpty() {
  if ((_cmd_q == nullptr) || (_ack_q == nullptr))
    return true;

  return (_cmd_q->isEmpty() && _ack_q->isEmpty());
}

bool mcrEngine::isCmdQueueEmpty() {
  if (_cmd_q == nullptr)
    return true;
  return _cmd_q->isEmpty();
}

bool mcrEngine::pendingCmd() {
  if (_cmd_q == nullptr)
    return false;

  return !(_cmd_q->isEmpty());
}

int mcrEngine::pendingCmdRecs() {
  if (_cmd_q == nullptr)
    return 0;

  return _cmd_q->nbRecs();
}

bool mcrEngine::popCmd(mcrCmd_t *cmd) {
  bool rc = false;

  if (_cmd_q == nullptr)
    return false;

  if (debugMode || cmdLogMode) {
    logDateTime(__PRETTY_FUNCTION__);
    log("CMD qdepth: ");
    log(_cmd_q->nbRecs());
  }

  rc = _cmd_q->pop(cmd);

  if (debugMode || cmdLogMode) {
    log(" popped: ");
    cmd->debug(true);
  }

  return rc;
}

bool mcrEngine::pushCmd(mcrCmd_t *cmd) {
  bool rc = false;

  if (_cmd_q != nullptr) {
    rc = _cmd_q->push(cmd);

    if (debugMode || cmdLogMode) {
      logDateTime(__PRETTY_FUNCTION__);
      log("CMD qdepth: ");
      log(_cmd_q->nbRecs());
      log(" pushed ");

      cmd->debug(true);
    }
  }

  return rc;
}

bool mcrEngine::pendingCmdAcks() {
  if (_ack_q == nullptr)
    return false;

  return (_ack_q->nbRecs() > 0) ? true : false;
};

bool mcrEngine::popPendingCmdAck(mcrCmd_t *cmd) {
  bool rc = false;

  if (_ack_q == nullptr)
    return false;

  int recs = _ack_q->nbRecs();

  if (recs > 0) {
    rc = _ack_q->pop(cmd);

    if (debugMode || cmdLogMode) {
      logDateTime(__PRETTY_FUNCTION__);
      log("CMDACK qdepth: ");
      log(recs);
      log(" popped: ");
      cmd->debug(true);
    }
  }

  return rc;
}

bool mcrEngine::pushPendingCmdAck(mcrCmd_t *cmd) {
  bool rc = false;

  if (_ack_q != nullptr) {

    if (debugMode || cmdLogMode) {
      logDateTime(__PRETTY_FUNCTION__);
      log("CMDACK pushed: ");
      cmd->debug(true);
    }

    rc = _ack_q->push(cmd);
  } else {
    logDateTime(__PRETTY_FUNCTION__);
    log("[WARNING] attempt to push cmd_ack to null queue", true);
  }

  return rc;
}

void mcrEngine::tempDebugOn() {
  _savedDebugMode = debugMode;
  debugMode = true;
}

void mcrEngine::endIdle() { _last_idle_ms = _last_idle; }

void mcrEngine::startDiscover() {
  debugIdle(__PRETTY_FUNCTION__, DISCOVER);
  endIdle();
  _state = DISCOVER;
  _last_discover = 0;
};

void mcrEngine::startConvert() {
  debugIdle(__PRETTY_FUNCTION__, CONVERT);
  endIdle();
  _state = CONVERT;
  _last_convert = 0;
};

void mcrEngine::startReport() {
  debugIdle(__PRETTY_FUNCTION__, REPORT);
  endIdle();
  _state = REPORT;
  _last_report = 0;
};

void mcrEngine::startCmd() {
  debugIdle(__PRETTY_FUNCTION__, CMD);
  endIdle();
  _state = CMD;
  _last_cmd = 0;
}

void mcrEngine::startCmdAck() {
  debugIdle(__PRETTY_FUNCTION__, CMD_ACK);
  endIdle();
  _state = CMD_ACK;
  _last_ackcmd = 0;
}

void mcrEngine::tempDebugOff() { debugMode = _savedDebugMode; }

void mcrEngine::debugIdle(const char *c, mcrEngineState_t s) {
  // Serial.println();
  // Serial.print(c);
  // Serial.print(" called and _state != IDLE ");
  // Serial.println();
}

void mcrEngine::printStartDiscover(const char *func_name, uint8_t indent) {

  if (infoMode || debugMode) {
    logDateTime(func_name);

    log("started, ");
    logElapsed(lastDiscover());
    log(" since last discover", true);
  }
}

void mcrEngine::printStopDiscover(const char *func_name, uint8_t indent) {
  if (infoMode || debugMode) {
    logDateTime(func_name);

    log("finished, found ");

    if (devCount() == 0)
      log("** ZERO **");
    else
      log(devCount());

    log(" devices in ");
    logElapsed(lastDiscoverRunMS(), true);
  }
}

void mcrEngine::printStartConvert(const char *func_name, uint8_t indent) {
  if (infoMode || debugMode) {
    logDateTime(func_name);

    log("started, ");
    logElapsed(lastConvert());
    log(" ms since last convert", true);
  }
}

void mcrEngine::printStopConvert(const char *func_name, uint8_t indent) {
  if (infoMode || debugMode) {
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
}

void mcrEngine::printStartReport(const char *func_name, uint8_t indent) {
  if (infoMode || debugMode) {
    logDateTime(func_name);

    log("started, ");
    logElapsed(lastReport());
    log(" ms since last report", true);
  }
}

void mcrEngine::printStopReport(const char *func_name, uint8_t indent) {
  if (infoMode || debugMode) {
    logDateTime(func_name);

    log("finished, took ");
    logElapsed(lastReportRunMS(), true);
  }
}

const char *mcrEngine::stateAsString(mcrEngineState_t state) {
  switch (state) {
  case INIT:
    return (const char *)"INIT";
  case IDLE:
    return (const char *)"IDLE";
  case DISCOVER:
    return (const char *)"DISCOVER";
  case CONVERT:
    return (const char *)"CONVERT";
  case REPORT:
    return (const char *)"REPORT";
  case CMD:
    return (const char *)"CMD";
  case CMD_ACK:
    return (const char *)"CMD_ACK";
  case STATS:
    return (const char *)"STATS";
  default:
    return (const char *)"UNKNOWN";
  }
}
