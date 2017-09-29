/*
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

#include "../include/mcr_cmd.hpp"
#include "../include/mcr_engine.hpp"
#include "../include/readings.hpp"

mcrEngine::mcrEngine(mcrMQTT *mqtt) {

  _mqtt = mqtt;
  // debugMode = true;

  // setting  to the discover interval will
  // prevent a delay for first discovery cycle at startup
  _last_discover = _discover_interval_ms;

  _last_report = 0;
  _last_convert = 0;
  _dev_count = 0;
  _state = IDLE;
}

const uint16_t mcrEngine::maxDevices() { return MAX_DEVICES_PER_ENGINE; };
uint16_t mcrEngine::devCount() { return _dev_count; };

bool mcrEngine::init() {
  bool rc = true;

  _pending_ack_q = new Queue(sizeof(mcrCmd_t), 10, FIFO);

  if (_pending_ack_q == nullptr) {
    rc = false;
  }

  return rc;
}

bool mcrEngine::loop() {
  resetLoopRuntime();

  // while (timesliceRemaining()) {

  while (isIdle() && timesliceRemaining() &&
         (pendingCmd() || pendingCmdAcks())) {
    cmd();
    cmdAck();
  }

  if (timesliceRemaining())
    discover();

  if (timesliceRemaining())
    convert();

  if (timesliceRemaining())
    report();

  //   while (timesliceRemaining() && isIdle() &&   // give Cmd and CmdAcks
  //          (pendingCmd() || pendingCmdAcks())) { // a "higher" priority
  //     cmd();                                     // by allowing processing
  //     cmdAck();                                  // of the pending queues
  //   }                                            // for the remainder of
  // }                                              // the timeslice
  //  }
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
  if (needDiscover()) {
    if (isIdle())
      startDiscover();

    if (isDiscoveryActive())
      idle(__PRETTY_FUNCTION__);
  }

  return true;
}

bool mcrEngine::report() {
  bool rc = true;

  if (needReport()) {
    if (isIdle())
      startReport();

    if (isReportActive())
      idle(__PRETTY_FUNCTION__);
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
  return rc;
}

bool mcrEngine::convertTimeout() {
  return (_last_convert > _convert_timeout_ms) ? true : false;
};

time_t mcrEngine::lastConvertTimestamp() { return _last_convert_timestamp; };

bool mcrEngine::cmd() {
  if (isIdle() && pendingCmd()) {
    // startCmd();
    handleCmd();
    // idle(__PRETTY_FUNCTION__);
  }
  return true;
}

bool mcrEngine::cmdAck() {
  bool rc = true;

  if (isIdle() && pendingCmdAcks()) {
    mcrCmd_t cmd;

    if (popPendingCmdAck(&cmd)) {
      handleCmdAck(cmd);
    } else {
      Serial.println();
      Serial.print(__PRETTY_FUNCTION__);
      Serial.println(" popPendingCmdAck() returned false");
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

    log("invoked idle() with state = ");
    log(_state, true);
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
  mcrDev_t *found_dev = nullptr;
  for (uint8_t i = 0; ((i < maxDevices()) && (found_dev == nullptr)); i++) {
    if (dev == _known_devs[i]) {
      found_dev = _known_devs[i];
    }
  }
  return found_dev;
}

bool mcrEngine::mcrEngine::knowDevice(mcrDev_t &dev) {
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

bool mcrEngine::mcrEngine::forgetDevice(mcrDev_t &dev) {
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
mcrDev_t *mcrEngine::getFirstKnownDevice() {
  _next_known_index = 0;
  return getNextKnownDevice();
}

mcrDev_t *mcrEngine::getNextKnownDevice() {
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

bool mcrEngine::pendingCmdAcks() {
  if (_pending_ack_q == nullptr)
    return false;

  return (_pending_ack_q->nbRecs() > 0) ? true : false;
};

bool mcrEngine::popPendingCmdAck(mcrCmd_t *cmd) {
  if (_pending_ack_q == nullptr)
    return false;
  return _pending_ack_q->pop(cmd);
}

bool mcrEngine::pushPendingCmdAck(mcrCmd_t *cmd) {
  bool rc = false;

  rc = _pending_ack_q->push(cmd);

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

void mcrEngine::mcrEngine::printStartDiscover(const char *func_name,
                                              uint8_t indent) {
  logDateTime(func_name);

  log("started, ");
  logElapsed(lastDiscover());
  log(" since last discover", true);
}

void mcrEngine::mcrEngine::printStopDiscover(const char *func_name,
                                             uint8_t indent) {
  logDateTime(func_name);

  if (devCount() == 0)
    log("[WARNING] ");

  log("finished, found ");
  log(devCount());
  log(" devices in ");
  logElapsed(lastDiscoverRunMS(), true);
}

void mcrEngine::mcrEngine::printStartConvert(const char *func_name,
                                             uint8_t indent) {
  logDateTime(func_name);

  log("started, ");
  logElapsed(lastConvert());
  log(" ms since last convert", true);
}

void mcrEngine::mcrEngine::printStopConvert(const char *func_name,
                                            uint8_t indent) {
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
