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

#include "mcr_engine.hpp"
#include "reading.hpp"

mcrEngine::mcrEngine(mcrMQTT *mqtt) {

  this->mqtt = mqtt;
  debugMode = false;

  // setting  to the discover interval will
  // prevent a delay for first discovery cycle at startup
  _last_discover = _discover_interval_ms;

  _last_report = 0;
  _last_convert = 0;
  _dev_count = 0;
  _state = IDLE;
}

bool mcrEngine::init() {
  bool rc = true;

  _pending_ack_q = new Queue(sizeof(mcrDevID), 10, FIFO);

  if (_pending_ack_q == NULL) {
    rc = false;
  }

  return rc;
}

bool mcrEngine::loop() {
  resetLoopRuntime();

  // while (timesliceRemaining()) {

  if (timesliceRemaining())
    cmd();

  if (timesliceRemaining())
    cmdAck();

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
  boolean rc = true;

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
  boolean rc = true;

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
    mcrDevID id;

    if (popPendingCmdAck(&id)) {
      handleCmdAck(id);
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
  case IDLE: // specifying this case to avoid compiler warning
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
