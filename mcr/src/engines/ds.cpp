/*
     mcpr_ds.cpp - Master Control Remote Dallas Semiconductor
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

// #define VERBOSE 1

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include <ArduinoJson.h>
#include <OneWire.h>
#include <cppQueue.h>

#include "../cmds/cmd.hpp"
#include "../include/readings.hpp"
#include "ds.hpp"
#include "engine.hpp"

static Queue cmd_queue(sizeof(mcrCmd_t), 25, FIFO); // Instantiate queue
static Queue ack_queue(sizeof(mcrCmd_t), 25, FIFO);

mcrDS::mcrDS(mcrMQTT *mqtt) : mcrEngine(mqtt) { ds = new OneWire(W1_PIN); }

bool mcrDS::init() {
  cmdLogMode = true;

  mcrMQTT::registerCmdCallback(&cmdCallback);
  mcrEngine::init(&cmd_queue, &ack_queue);
  return true;
}

// mcrDS::discover()
// this method should be called often to ensure proper operator.
//
//  1. if the enough millis have elapsed since the last full discovery
//     this method then it will start a new discovery.
//  2. if a discovery cycle is in-progress this method will execute
//     a single search

bool mcrDS::discover() {
  uint8_t addr[8];
  auto rc = true;

  if (needDiscover()) {
    if (isIdle()) {
      printStartDiscover(__PRETTY_FUNCTION__);

      ds->reset_search();
      startDiscover();
    }

    if (ds->search(addr)) {
      // confirm addr we received is legit
      if (OneWire::crc8(addr, 7) == addr[7]) {
        mcrDevAddr_t found_addr(addr, 8);

        if (debugMode) {
          logDateTime(__PRETTY_FUNCTION__);
          log("discovered ");
          found_addr.debug(true);
        }

        // TODO: move to own method and implement family code
        // specific logic
        // check if chip is powered
        // ds->reset();
        // ds->select(addr);
        // ds->write(0xB4); // Read Power Supply
        // uint8_t pwr = ds->read_bit();

        dsDev_t dev(found_addr, true);

        if (justSeenDevice(dev)) {
          if (infoMode || discoverLogMode) {
            logDateTime(__PRETTY_FUNCTION__);
            log("just saw: ");
            dev.debug(true);
            // log(" sizeof(dsDev_t)=");
            // log(sizeof(dsDev_t), true);
          }
        } else { // device was not known, must addr
          dsDev_t *new_dev = new dsDev(dev);

          if (infoMode || discoverLogMode) {
            logDateTime(__PRETTY_FUNCTION__);
            log("adding device: ");
            dev.debug();
            log(" sizeof(dsDev_t)=");
            log(sizeof(dsDev_t), true);
          }

          addDevice(new_dev);
        }
      } else { // crc check failed
        // crc check failed -- report back to caller
        rc = false;
      }
    } else { // search did not find a device
      idle(__PRETTY_FUNCTION__);
      printStopDiscover(__PRETTY_FUNCTION__);
    }
  }

  return rc;
}

bool mcrDS::report() {
  bool rc = true;
  mcrDev_t *next_dev = nullptr;
  dsDev_t *dev = nullptr;

  if (needReport()) {
    if (isIdle()) {
      printStartReport(__PRETTY_FUNCTION__);
      next_dev = getFirstKnownDevice();
      startReport();
    } else {
      next_dev = getNextKnownDevice();
    }

    dev = (dsDev_t *)next_dev;

    if (isReportActive()) {
      if (dev != nullptr) {
        rc = readDevice(dev->id());

        if (rc)
          publishDevice(dev);
      }

      if (dev == nullptr) {
        idle(__PRETTY_FUNCTION__);
        printStopReport(__PRETTY_FUNCTION__);
      }
    }
  }

  return rc;
}

bool mcrDS::readDevice(dsDev_t *dev) {
  celsiusReading_t *celsius = nullptr;
  positionsReading_t *positions = nullptr;
  auto rc = true;

  if ((dev == nullptr) || (dev->isNotValid())) {
    printInvalidDev(dev);
    return false;
  }

  switch (dev->family()) {
  case 0x10: // DS1820 (temperature sensors)
  case 0x22:
  case 0x28:
    rc = readDS1820(dev, &celsius);
    dev->setReading(celsius);
    break;

  case 0x29: // DS2408 (8-channel switch)
    rc = readDS2408(dev, &positions);
    dev->setReading(positions);
    break;

  case 0x12: // DS2406 (2-channel switch with 1k EPROM)
    rc = readDS2406(dev, &positions);
    dev->setReading(positions);
    break;
  }

  return rc;
}

// publish a device
bool mcrDS::publishDevice(mcrCmd_t &cmd) {
  mcrDevID_t &dev_id = cmd.dev_id();

  return publishDevice(dev_id);
}

bool mcrDS::publishDevice(mcrDevID_t &id) {
  return publishDevice((dsDev_t *)getDevice(id));
}

bool mcrDS::publishDevice(dsDev_t *dev) {
  bool rc = true;

  Reading_t *reading = dev->reading();

  if (reading != nullptr) {
    publish(reading);
  }
  return rc;
}
// mcrDS::temp_convert()
// this method should be called often to ensure proper operator.
//
//  1. if enough millis have elapsed since the last temperature
//     conversion then a new one will be started if mcrDS is
//     idle
//  2. if a temperature conversion is in-progress this method will
//     do a single check to determine if conversion is finished

bool mcrDS::convert() {
  bool rc = true;

  if (needConvert()) {
    // start a temperature conversion if one isn't already in-progress
    // TODO only handles powered devices as of 2017-09-11
    if (isIdle()) {
      if (numKnownDevices() > 0) { // only do a convert if there are devices
        ds->reset();
        ds->skip();         // address all devices
        ds->write(0x44, 1); // start conversion
        delay(1); // give the sensors an opportunity to start conversion
      }

      printStartConvert(__PRETTY_FUNCTION__);
      startConvert();
    }

    // temperature devices how the bus low during the convert
    if (isConvertActive()) {
      bool finished = false;

      if (ds->read_bit() > 0x00) { // bus is high means convert finished
        finished = true;
      } else if (convertTimeout()) { // has the max convert time elapsed?
        finished = true;
      } else if (numKnownDevices() == 0) { // there are no known devices
        finished = true;
      }

      if (finished) {
        idle(__PRETTY_FUNCTION__);
        printStopConvert(__PRETTY_FUNCTION__);
      }
    }
  }
  return rc;
}

bool mcrDS::handleCmd() {
  bool rc = false;

  if (pendingCmd()) {
    mcrCmd_t cmd;
    rc = popCmd(&cmd);

    if (setSwitch(cmd)) {
      if (debugMode) {
        logDateTime(__PRETTY_FUNCTION__);
        log("setSwitch() complete");
        logContinued();
        cmd.debug(true);
      }

      pushPendingCmdAck(&cmd);
    } else {
      if (debugMode) {
        logDateTime(__PRETTY_FUNCTION__);
        log("setSwitch() failed, quietly dropping");
        logContinued();
        cmd.debug(true);
      }
    }
  }

  return rc;
}

bool mcrDS::handleCmdAck(mcrCmd_t &cmd) {
  bool rc = true;

  if (debugMode) {
    logDateTime(__PRETTY_FUNCTION__);
    log("handling CmdAck");
    logContinued();
    cmd.debug(true);
  }

  rc = readDevice(cmd);
  if (rc == true) {
    setCmdAck(cmd);
    publishDevice(cmd);
  }

  return rc;
}

bool mcrDS::readDevice(mcrCmd_t &cmd) {
  mcrDevID_t &dev_id = cmd.dev_id();

  return readDevice(dev_id);
}

bool mcrDS::readDevice(mcrDevID_t &id) {
  return readDevice((dsDev_t *)getDevice(id));
}

// specific device scratchpad methods
bool mcrDS::readDS1820(dsDev *dev, celsiusReading_t **reading) {
  byte data[9] = {0x00};
  bool type_s = false;
  bool rc = true;

  if (ds->reset() == 0x00) {
    dev->logPresenceFailed(__PRETTY_FUNCTION__);
    return false;
  };

  switch (dev->family()) {
  case 0x10:
    type_s = true;
    break;
  default:
    type_s = false;
  }

  dev->startRead();
  ds->select(dev->addr());
  ds->write(0xBE); // Read Scratchpad

  for (uint8_t i = 0; i < 9; i++) { // we need 9 bytes
    data[i] = ds->read();
  }
  ds->reset();
  dev->stopRead();
  if (debugMode)
    dev->printReadMS(__PRETTY_FUNCTION__);

#ifdef VERBOSE
  Serial.print("    Read Scratchpad + received bytes = ");
  for (uint8_t i = 0; i < sizeof(data); i++) {
    Serial.print("0x");
    Serial.print(data[i], HEX);
    Serial.print(" ");
  }
  Serial.println();

  Serial.print("    Read Scratchpad CRC8 = ");
#endif
  if (OneWire::crc8(data, 8) == data[8]) {

#ifdef VERBOSE
    Serial.println("good");
#endif

    // Convert the data to actual temperature
    // because the result is a 16 bit signed integer, it should
    // be stored to an "int16_t" type, which is always 16 bits
    // even when compiled on a 32 bit processor.
    int16_t raw = (data[1] << 8) | data[0];
    if (type_s) {
      raw = raw << 3; // 9 bit resolution default
      if (data[7] == 0x10) {
        // "count remain" gives full 12 bit resolution
        raw = (raw & 0xFFF0) + 12 - data[6];
      }
    } else {
      byte cfg = (data[4] & 0x60);
      // at lower res, the low bits are undefined, so let's zero them
      if (cfg == 0x00)
        raw = raw & ~7; // 9 bit resolution, 93.75 ms
      else if (cfg == 0x20)
        raw = raw & ~3; // 10 bit res, 187.5 ms
      else if (cfg == 0x40)
        raw = raw & ~1; // 11 bit res, 375 ms
      //// default is 12 bit resolution, 750 ms conversion time
    }
    float celsius = (float)raw / 16.0;

    *reading = new celsiusReading(dev->id(), lastConvertTimestamp(), celsius);
  } else {

#ifdef VERBOSE
    Serial.println("  bad");
#endif

    rc = false;
  }

  return rc;
}

bool mcrDS::readDS2406(dsDev *dev, positionsReading_t **reading) {
  bool rc = true;

  if (ds->reset() == 0x00) {
    dev->logPresenceFailed(__PRETTY_FUNCTION__);
    return false;
  };

  uint8_t buff[] = {0xAA,       // byte 0:     Read Status
                    0x00, 0x00, // byte 1-2:   Address (start a beginning)
                    0x00, 0x00, 0x00, 0x00, 0x00, // byte 3-7:   EPROM Bitmaps
                    0x00, // byte 8:     EPROM Factory Test Byte
                    0x00, // byte 9:     Don't care (always reads 0x00)
                    0x00, // byte 10:    SRAM (channel flip-flops, power, etc.)
                    0x00, 0x00}; // byte 11-12: CRC16

  dev->startRead();
  ds->select(dev->addr());
  ds->write_bytes(buff, 3); // Read Status cmd and two address bytes

  // fill buffer with bytes from DS2406, skipping the first byte
  // since the first byte is included in the CRC16
  ds->read_bytes(buff + 3, sizeof(buff) - 3);
  ds->reset();
  dev->stopRead();
  if (debugMode)
    dev->printReadMS(__PRETTY_FUNCTION__);

#ifdef VERBOSE
  Serial.print("    Read Status + received bytes = ");
  for (uint8_t i = 0; i < sizeof(buff); i++) {
    Serial.print(buff[i], HEX);
    Serial.print(" ");
  }
  Serial.println();

  Serial.print("    Read Status CRC16 = ");
#endif

  if (OneWire::check_crc16(buff, (sizeof(buff) - 2), &buff[sizeof(buff) - 2])) {
    uint8_t raw = buff[sizeof(buff) - 3];

    uint8_t positions = 0x00;   // translate raw status to 0b000000xx
    if ((raw & 0x20) == 0x00) { // to represent PIO.A as bit 0
      positions = 0x01;         // and PIO.B as bit 1
    }                           // reminder to invert the bits since the device
                                // represents on/off opposite of true/false
    if ((raw & 0x40) == 0x00) {
      positions = (positions | 0x02);
    }

#ifdef VERBOSE
    Serial.println("good");
#endif
    *reading = new positionsReading(dev->id(), now(), positions, (uint8_t)2);
  } else {
#ifdef VERBOSE
    Serial.println("bad");
#endif
    rc = false;
  }

  return rc;
}

bool mcrDS::readDS2408(dsDev *dev, positionsReading_t **reading) {
  bool rc = true;
  // byte data[12]

  if (ds->reset() == 0x00) {
    dev->logPresenceFailed(__PRETTY_FUNCTION__);
    return false;
  };

  uint8_t buff[] = {0xF5, // byte 0:      Channel-Access Read 0xF5
                    0x00, 0x00, 0x00, 0x00, // bytes 1-4:   channel state data
                    0x00, 0x00, 0x00, 0x00, // bytes 5-8:   channel state data
                    0x00, 0x00, 0x00, 0x00, // bytes 9-12:  channel state data
                    0x00, 0x00, 0x00, 0x00, // bytes 13-16: channel state data
                    0x00, 0x00, 0x00, 0x00, // bytes 17-20: channel state data
                    0x00, 0x00, 0x00, 0x00, // bytes 21-24: channel state data
                    0x00, 0x00, 0x00, 0x00, // bytes 25-28: channel state data
                    0x00, 0x00, 0x00, 0x00, // bytes 29-32: channel state data
                    0x00, 0x00};            // bytes 33-34: CRC16

  dev->startRead();
  ds->select(dev->addr());
  ds->write_bytes(buff, 1);

  // read 32 bytes of channel state data + 16 bits of CRC
  ds->read_bytes(buff + 1, sizeof(buff) - 1);
  ds->reset();
  dev->stopRead();
  if (debugMode)
    dev->printReadMS(__PRETTY_FUNCTION__);

#ifdef VERBOSE
  Serial.print("  DS2408 Channel-Access Read + received bytes = ");
  for (uint8_t i = 0; i < sizeof(buff); i++) {
    Serial.print(buff[i], HEX);
    Serial.print(" ");
  }
  Serial.println();

  Serial.print("    Channel-Access Read CRC16 = ");
#endif

  if (OneWire::check_crc16(buff, (sizeof(buff) - 2), &buff[sizeof(buff) - 2])) {
    // negate positions since device sees on/off opposite of true/false
    uint8_t positions = ~buff[sizeof(buff) - 3];

#ifdef VERBOSE
    Serial.println("good");
#endif

    if (reading != nullptr) {
      *reading = new positionsReading(dev->id(), now(), positions, (uint8_t)8);
    }
  } else {
#ifdef VERBOSE
    Serial.println("bad");
#endif
    rc = false;
  }

  return rc;
}

bool mcrDS::setSwitch(mcrCmd_t &cmd) {
  bool rc = true;

  // mcrDevID id = cmd.name();
  dsDev_t *dev = (dsDev_t *)getDeviceByCmd(cmd);

  if (dev == nullptr) {
    logDateTime(__PRETTY_FUNCTION__);
    log("could not find: ");
    logContinued();
    cmd.debug(true);

    return false;
  }

  if (dev->isDS2406())
    rc = setDS2406(cmd);

  if (dev->isDS2408())
    rc = setDS2408(cmd);

  return rc;
}

bool mcrDS::setDS2406(mcrCmd_t &cmd) {
  bool rc = true;
  // mcrDevID id = cmd.name();
  dsDev_t *dev = (dsDev_t *)getDeviceByCmd(cmd);

  if (dev == nullptr) {
    logDateTime(__PRETTY_FUNCTION__);
    log("could not find device for ");
    logContinued();
    cmd.debug(true);

    return false;
  }

  if (ds->reset() == 0x00) {
    dev->logPresenceFailed(__PRETTY_FUNCTION__);
    return false;
  };

  positionsReading_t *reading = (positionsReading_t *)dev->reading();
  uint8_t mask = cmd.mask();
  uint8_t tobe_state = cmd.state();
  uint8_t asis_state = reading->state();

  bool pio_a = (mask & 0x01) ? (tobe_state & 0x01) : (asis_state & 0x01);
  bool pio_b = (mask & 0x02) ? (tobe_state & 0x02) : (asis_state & 0x02);

  uint8_t new_state = (!pio_a << 5) | (!pio_b << 6) | 0xf;

  uint8_t buff[] = {0x55,        // byte 0:     Write Status
                    0x07, 0x00,  // byte 1-2:   Address of Status byte
                    0x00,        // byte 3-7:   Status byte to send
                    0x00, 0x00}; // byte 11-12: CRC16

  buff[3] = new_state;

  ds->reset();
  dev->startWrite();
  ds->select(dev->addr());
  ds->write_bytes(buff, sizeof(buff) - 2);
  ds->read_bytes(buff + 4, sizeof(buff) - 4);

#ifdef VERBOSE
  Serial.print("    Write Status CRC16 = ");
#endif

  if (OneWire::check_crc16(buff, (sizeof(buff) - 2), &buff[sizeof(buff) - 2])) {
#ifdef VERBOSE
    Serial.print("good");
    Serial.println();
#endif

    ds->write(0xFF, 1); // writing 0xFF will copy scratchpad to status
    ds->reset();
    dev->stopWrite();
    if (debugMode)
      dev->printWriteMS(__PRETTY_FUNCTION__);
  } else {
#ifdef VERBOSE
    Serial.print("bad");
    Serial.println();
#endif
    rc = false;
  }
  return rc;
}

bool mcrDS::setDS2408(mcrCmd &cmd) {
  bool rc = true;
  dsDev_t *dev = (dsDev_t *)getDeviceByCmd(cmd);

  if (dev == nullptr) {
    logDateTime(__PRETTY_FUNCTION__);
    log("could not find device for ");
    logContinued();
    cmd.debug(true);

    return false;
  }

  if (ds->reset() == 0x00) {
    dev->logPresenceFailed(__PRETTY_FUNCTION__);
    return false;
  };

  // read the device to ensure we have the current state
  // important because setting the new state relies, in part, on the existing
  // state for the pios not changing
  if (readDevice(dev) == false) {
    logDateTime(__PRETTY_FUNCTION__);
    log("read before set failed ");
    dev->debug(true);

    return false;
  }

  positionsReading_t *reading = (positionsReading_t *)dev->reading();

  uint8_t mask = cmd.mask();
  uint8_t changes = cmd.state();
  uint8_t asis_state = reading->state();
  uint8_t new_state = 0x00;
  uint8_t report_state = 0x00;

  // use XOR tricks to apply the state changes to the as_is state using the
  // mask computed
  new_state = asis_state ^ ((asis_state ^ changes) & mask);

  // now negate the new_state since the device actually represents
  // on = 0
  // off = 1

  report_state = new_state;
  new_state = ~new_state;

  ds->reset();
  dev->startWrite();
  ds->select(dev->addr());
  ds->write(0x5A, 1);
  ds->write(new_state, 1);  // state to set on the device
  ds->write(~new_state, 1); // send the negated as a check

  uint8_t check[3] = {0x00};
  ds->read_bytes(check, 2);
  ds->reset();
  dev->stopWrite();
  if (debugMode)
    dev->printWriteMS(__PRETTY_FUNCTION__);

  // check what the device returned to determine success or failure
  // byte 0 = 0xAA is a success, byte 1 = new_state
  if ((check[0] == 0xAA) && (check[1] == new_state)) {
    if (cmdLogMode) {
      uint8_t dev_state = check[1];

      logDateTime(__PRETTY_FUNCTION__);
      log("SUCCESS");

      logContinued();
      dev->debug();

      logContinued();
      log("asis: ");
      logAsBinary(asis_state);
      log("  new: ");
      logAsBinary(report_state);
      log("  dev state: ");
      logAsBinary(dev_state, true);
    }
  } else {
    uint8_t dev_state = check[1];

    logDateTime(__PRETTY_FUNCTION__);
    log("FAILED");

    logContinued();
    dev->debug();

    logContinued();
    log("asis: ");
    logAsBinary(asis_state);
    log("  new: ");
    logAsBinary(report_state);
    logContinued();
    log("check[0]: ");
    logAsHex(check[0]);
    log("  check[1]: ");
    logAsBinary(dev_state, true);

    rc = false;
  }

  return rc;
}

bool mcrDS::cmdCallback(JsonObject &root) {
  bool rc = false;

  // json format of states command:
  // {"version":1,
  //   "switch":"ds/29463408000000",
  //   "states":[{"state":false,"pio":3}],
  //   "refid":"0fc4417c-f1bb-11e7-86bd-6cf049e7139f",
  //   "mtime":1515117138,
  //   "cmd":"set.switch"}
  const char *switch_id = root["switch"];
  mcrRefID_t refid = (const char *)root["refid"];
  mcrDevID_t sw(switch_id);
  const JsonVariant &variant = root.get<JsonVariant>("states");
  const JsonArray &states = variant.as<JsonArray>();
  uint8_t mask = 0x00;
  uint8_t tobe_state = 0x00;

  // logDateTime(__PRETTY_FUNCTION__);
  // log("invoked for ");
  // sw.debug(true);

  // iterate through the array of new states
  for (auto element : states) {
    // get a reference to the object from the array
    const JsonObject &requested_state = element.as<JsonObject>();

    const uint8_t bit = atoi(requested_state["pio"]);
    const bool state = requested_state["state"].as<bool>();

    // set the mask with each bit that should be adjusted
    mask |= (0x01 << bit);

    // set the tobe state with the values those bits should be
    // if the new_state is true (on) then set the bit,
    // otherwise leave it unset
    if (state) {
      tobe_state |= (0x01 << bit);
    }
  }

  // since this is a static member function to comply with the implementation
  // of the MQTT client the cmd will pushed directly to the cmd_queue
  mcrCmd_t cmd(sw, mask, tobe_state, refid);
  rc = cmd_queue.push(&cmd);

  // logDateTime(__PRETTY_FUNCTION__);
  // log("pushed ");
  // logContinued();
  // cmd.debug(true);

  return rc;
}

// dsDev_t *mcrDS::dsDevgetDevice(mcrDevID_t &id) {
//   mcrDev_t *dev = mcrEngine::getDevice(id);
//   return (dsDev_t *)dev;
// }
//
dsDev_t *mcrDS::getDeviceByCmd(mcrCmd_t &cmd) {
  if (debugMode) {
    logDateTime(__PRETTY_FUNCTION__);
    log("looking for dev_id=");
    log(cmd.dev_id(), true);
  }

  mcrDev_t *dev = mcrEngine::getDevice(cmd.dev_id());
  return (dsDev_t *)dev;
}

void mcrDS::setCmdAck(mcrCmd_t &cmd) {
  mcrDevID_t &dev_id = cmd.dev_id();
  dsDev_t *dev = nullptr;

  dev = (dsDev_t *)mcrEngine::getDevice(dev_id);
  if (dev != nullptr) {
    dev->setReadingCmdAck(cmd.latency(), cmd.refID());
  }
}

void mcrDS::printInvalidDev(dsDev *dev) {
  logDateTime(__PRETTY_FUNCTION__);
  log("[WARNING] device ");
  if (dev == NULL) {
    log("is NULL", true);
  } else {
    log(dev->id());
    log(" crc8 is ");
    switch (dev->isValid()) {
    case true:
      log("valid", true);
      break;
    case false:
      log("invalid", true);
    }
  }
}
