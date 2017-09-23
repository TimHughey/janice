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

#include "mcr_cmd.hpp"
#include "mcr_ds.hpp"
#include "mcr_engine.hpp"
#include "reading.hpp"

// this must be a global (at least to this file) due to the MQTT callback
// is a static
Queue cmd_queue(sizeof(mcrCmd), 25, FIFO); // Instantiate queue

mcrDS::mcrDS(mcrMQTT *mqtt) : mcrEngine(mqtt) {
  ds = new OneWire(W1_PIN);
  _devs = new dsDev *[maxDevices()];

  memset(_devs, 0x00, sizeof(dsDev *) * maxDevices());
}

bool mcrDS::init() {
  mcrMQTT::registerCmdCallback(&cmdCallback);
  mcrEngine::init();
  return true;
}

bool mcrDS::loop() {
  int nbrecs = cmd_queue.nbRecs();

  if ((nbrecs > 0) && isIdle()) {
#ifdef VERBOSE
    Serial.print("  ");
    Serial.print(__PRETTY_FUNCTION__);
    Serial.print(" cmds in queue = ");
    Serial.println(nbrecs);
#endif

    mcrCmd cmd;
    cmd_queue.pop(&cmd);

#ifdef VERBSOE
    Serial.print("  ");
    Serial.print(__PRETTY_FUNCTION__);
    Serial.print(" popped: name=");
    Serial.print(cmd.name());
    Serial.print(" new_state: ");
    Serial.println(cmd.state());
#endif

    if (setSwitch(cmd)) {
      pushPendingCmdAck(cmd.name());
    }
  }

  // must call the base case to ensure remaining work is done
  return mcrEngine::loop();
}

// mcrDS::discover()
// this method should be called often to ensure proper operator.
//
//  1. if the enough millis have elapsed since the last full discovery
//     this method then it will start a new discovery.
//  2. if a discovery cycle is in-progress this method will execute
//     a single search

bool mcrDS::discover() {
  byte addr[8];
  auto rc = true;

  if (needDiscover()) {
    if (isIdle()) {
      Serial.print("  ");
      Serial.print(__PRETTY_FUNCTION__);
      Serial.print(" started, ");
      Serial.print(lastDiscover());
      Serial.println("ms since last discover");

      startDiscover();
      ds->reset_search();
      clearKnownDevices();
    }

    if (ds->search(addr)) {
      // confirm addr we received is legit
      if (OneWire::crc8(addr, 7) == addr[7]) {

        // TODO: move to own method and implement family code
        // specific logic
        // check if chip is powered
        ds->reset();
        ds->select(addr);
        ds->write(0xB4); // Read Power Supply
        byte pwr = ds->read_bit();

        addDevice(addr, pwr);
#ifdef VERBOSE
        Serial.print("  mcrDS::discover() found dev ");
        // Serial.print(deviceID(addr));
        Serial.println();
#endif
      } else { // crc check failed
        // crc check failed -- report back to caller
        rc = false;
      }
    } else { // search did not find a device
      idle(__PRETTY_FUNCTION__);

      if (devCount() == 0) {
        Serial.println("  WARNING: no devices found on bus.");
        // discover_interval_millis = 3000;
      } else {
        // discover_interval_millis = DISCOVER_INTERVAL_MILLIS;
      }
      Serial.print("  ");
      Serial.print(__PRETTY_FUNCTION__);
      Serial.print(" found ");
      Serial.print(devCount());
      Serial.print(" device(s) in ");
      Serial.print(lastDiscoverRunMS());
      Serial.println("ms");
      Serial.println();
    }
  }

  return rc;
}

bool mcrDS::report() {
  bool rc = true;
  static uint8_t dev_index = 0;

  if (isIdle() && needReport()) {
    startReport();
    dev_index = 0;
  }

  if (isReportActive()) {
    dsDev *dev = _devs[dev_index];
    Reading *reading = NULL;

    if ((dev != NULL) && (dev->isValid())) {
      switch (dev->family()) {
      case 0x10: // DS1820 (temperature sensors)
      case 0x22:
      case 0x28:
        rc = readDS1820(dev, &reading);
        dev->setReading(reading);
        break;

      case 0x29: // DS2408 (8-channel switch)
        rc = readDS2408(dev, &reading);
        dev->setReading(reading);
        break;

      case 0x12: // DS2406 (2-channel switch with 1k EPROM)
        rc = readDS2406(dev, &reading);
        dev->setReading(reading);
        break;
      }

      if (reading != NULL) {
        mqtt->publish(reading);
      }
    }

    dev_index += 1; // increment to dev_index for next loop invocation

    if (dev_index == (maxDevices() - 1)) {
      idle(__PRETTY_FUNCTION__);
    }
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
#ifdef VERBOSE
      Serial.print("  mcrDS::convert() initiated, ");
      Serial.print(lastConvert());
      Serial.println("ms since last convert");
#endif

      ds->reset();
      ds->skip();         // address all devices
      ds->write(0x44, 1); // start conversion
      delay(5);           // give the sensors an opportunity to start conversion
      startConvert();
    }

    // bus is held low during temp convert
    // so if the bus reads high then temp convert is complete
    if (isConvertActive() && (ds->read_bit() > 0x00)) {
      // note:  there will be some extra millis recorded due to
      //        time slicing and execution of other methods in between
      //        checks.  in other words, the elapsed millis for temp
      //        convert will not be precise.
      idle(__PRETTY_FUNCTION__);

#ifdef VERBOSE
      Serial.print("  mcrDS::convert() took ");
      Serial.print(lastConvertRunMS());
      Serial.println("ms");
      Serial.println();
#endif

    } else if (convertTimeout()) {
      Serial.println("  WARNING: mcrDS::convert() time out");
      idle(__PRETTY_FUNCTION__);
    }
  }

  return rc;
}

bool mcrDS::handleCmdAck(mcrDevID &id) {
  bool rc = true;

#ifdef VERBOSE
  Serial.print("  ");
  Serial.print(__PRETTY_FUNCTION__);
  Serial.print(" handling CmdAck for: ");
  Serial.print(id);
  Serial.println();
#endif

  return rc;
}

// specific device scratchpad methods
bool mcrDS::readDS1820(dsDev *dev, Reading **reading) {
  byte data[9];
  bool type_s = false;
  bool rc = true;

  memset(data, 0x00, sizeof(data));

  switch (dev->family()) {
  case 0x10:
    type_s = true;
    break;
  default:
    type_s = false;
  }

  byte present = ds->reset();

  if (present > 0x00) {
    elapsedMillis read_elapsed;

    ds->select(dev->addr());
    ds->write(0xBE); // Read Scratchpad

    for (uint8_t i = 0; i < 9; i++) { // we need 9 bytes
      data[i] = ds->read();
    }

    Serial.print("  DS1820 ");
    Serial.print(dev->id());
    Serial.print(" read in ");
    Serial.print(read_elapsed);
    Serial.println("ms");
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

      *reading = new Reading(dev->id(), lastConvertTimestamp(), celsius);
    } else {

#ifdef VERBOSE
      Serial.println("  bad");
#endif

      rc = false;
    }
  } else {
    Serial.print("  DS18x20 ");
    Serial.print(dev->id());
    Serial.println(" presence failed.");
    rc = false;
  }

  return rc;
}

bool mcrDS::readDS2406(dsDev *dev, Reading **reading) {
  bool rc = true;

  byte present = ds->reset();

  if (present > 0x00) {
    elapsedMillis read_state_elapsed;
    uint8_t buff[] = {
        0xAA,                         // byte 0:     Read Status
        0x00, 0x00,                   // byte 1-2:   Address (start a beginning)
        0x00, 0x00, 0x00, 0x00, 0x00, // byte 3-7:   EPROM Bitmaps
        0x00,                         // byte 8:     EPROM Factory Test Byte
        0x00,        // byte 9:     Don't care (always reads 0x00)
        0x00,        // byte 10:    SRAM (channel flip-flops, power, etc.)
        0x00, 0x00}; // byte 11-12: CRC16

    ds->select(dev->addr());
    ds->write_bytes(buff, 3); // Read Status cmd and two address bytes

    // fill buffer with bytes from DS2406, skipping the first byte
    // since the first byte is included in the CRC16
    ds->read_bytes(buff + 3, sizeof(buff) - 3);
    ds->reset();

    Serial.print("  DS2406 ");
    Serial.print(dev->id());
    Serial.print(" read in ");
    Serial.print(read_state_elapsed);
    Serial.println("ms");

#ifdef VERBOSE
    Serial.print("    Read Status + received bytes = ");
    for (uint8_t i = 0; i < sizeof(buff); i++) {
      Serial.print(buff[i], HEX);
      Serial.print(" ");
    }
    Serial.println();

    Serial.print("    Read Status CRC16 = ");
#endif

    if (OneWire::check_crc16(buff, (sizeof(buff) - 2),
                             &buff[sizeof(buff) - 2])) {
      uint8_t raw_status = 0x00;

      raw_status = buff[sizeof(buff) - 3];

      uint8_t positions = 0x00;

      // translate raw status to 0b000000xx
      // to represent PIO.A as bit 0 and PIO.B as bit 1
      if ((raw_status & 0x20) == 0) {
        positions = 0x01;
      }

      if ((raw_status & 0x40) == 0) {
        positions = (positions | 0x02);
      }

#ifdef VERBOSE
      Serial.println("good");
#endif

      *reading = new Reading(dev->id(), now(), positions, (uint8_t)2);

    } else {

#ifdef VERBOSE
      Serial.println("bad");
#endif

      rc = false;
    }

    // temporary test of changing state
    // bool pio_a = !(state & 0x01);
    // bool pio_b = !(state & 0x02);
    bool pio_a = false;
    bool pio_b = false;
    uint8_t new_state = (!pio_a << 5) | (!pio_b << 6) | 0xf;

#ifdef VERBOSE
    Serial.print("    testing write, new state = 0x");
    Serial.print(new_state, HEX);
    Serial.println();
#endif

    uint8_t buff2[]{0x55,        // byte 0:     Write Status
                    0x07, 0x00,  // byte 1-2:   Address of Status byte
                    0x00,        // byte 3-7:   Status byte to send
                    0x00, 0x00}; // byte 11-12: CRC16

    buff2[3] = new_state;

    ds->reset();
    ds->select(dev->addr());
    ds->write_bytes(buff2, sizeof(buff2) - 2);
    ds->read_bytes(buff2 + 4, sizeof(buff2) - 4);

#ifdef VERBOSE
    Serial.print("    Write Status CRC16 = ");
#endif

    if (OneWire::check_crc16(buff2, (sizeof(buff2) - 2),
                             &buff2[sizeof(buff2) - 2])) {
#ifdef VERBOSE
      Serial.print("good");
      Serial.println();
#endif

      ds->write(0xFF, 1); // writing 0xFF will copy scratchpad to status
      ds->reset();
    } else {
#ifdef VERBOSE
      Serial.print("bad");
      Serial.println();
#endif
    }
  } else {
    Serial.print("  DS2406 ");
    Serial.print(dev->id());
    Serial.println(" presence failed.");
    rc = false;
  }

  return rc;
}

bool mcrDS::readDS2408(dsDev *dev, Reading **reading) {
  bool rc = true;
  // byte data[12]

  byte present = ds->reset();

  if (present > 0x00) {
    elapsedMillis read_state_elapsed;
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

    ds->select(dev->addr());
    ds->write_bytes(buff, 1);

    // read 32 bytes of channel state data + 16 bits of CRC
    ds->read_bytes(buff + 1, sizeof(buff) - 1);
    ds->reset();

    Serial.print("  DS2408 ");
    Serial.print(dev->id());
    Serial.print(" read in ");
    Serial.print(read_state_elapsed);
    Serial.println("ms");

#ifdef VERBOSE
    Serial.print("  DS2408 Channel-Access Read + received bytes = ");
    for (uint8_t i = 0; i < sizeof(buff); i++) {
      Serial.print(buff[i], HEX);
      Serial.print(" ");
    }
    Serial.println();

    Serial.print("    Channel-Access Read CRC16 = ");
#endif

    if (OneWire::check_crc16(buff, (sizeof(buff) - 2),
                             &buff[sizeof(buff) - 2])) {
      uint8_t positions = buff[sizeof(buff) - 3];

#ifdef VERBOSE
      Serial.println("good");
#endif

      if (reading != NULL) {
        *reading = new Reading(dev->id(), now(), positions, (uint8_t)8);
      }
    } else {
#ifdef VERBOSE
      Serial.println("bad");
#endif
      rc = false;
    }
  } else {
    Serial.print("  DS2408 ");
    Serial.print(dev->id());
    Serial.println(" presence failed.");
    rc = false;
  }

  return rc;
}

bool mcrDS::setSwitch(mcrCmd &cmd) {
  bool rc = true;

  // mcrDevID id = cmd.name();
  dsDev *dev = getDevice(cmd.name());

  if (dev == NULL) {
    return false;
  }

  if (dev->isDS2406())
    rc = setDS2406(cmd);

  if (dev->isDS2408())
    rc = setDS2408(cmd);

  return rc;
}

bool mcrDS::setDS2406(mcrCmd &cmd) {
  bool rc = true;

  return rc;
}

bool mcrDS::setDS2408(mcrCmd &cmd) {
  bool rc = true;
  // mcrDevID id = cmd.name();
  dsDev *dev = getDevice(cmd.name());

  if (dev == NULL) {
    return false;
  }
  Reading *reading = dev->reading();

  uint8_t mask = cmd.mask();
  uint8_t tobe_state = 0x00;
  uint8_t asis_state = 0x00;
  uint8_t new_state = 0x00;

  // by applying the negated mask (what to change) to the requested state
  // we end up with ony the bits that should be set in the new state
  // since the actual device uses 0 for on and 1 for off
  tobe_state = ~cmd.state() & mask;

  // by applying the negated mask to the current state we get the
  // bits that should be kept
  asis_state = reading->state() & ~mask;

  // now, the new state is simply the OR of the tobe and asis states
  new_state = asis_state | tobe_state;

  ds->reset();
  ds->select(dev->addr());
  ds->write(0x5A, 1);
  ds->write(new_state, 1);
  ds->write(~new_state, 1);

  uint8_t check[2];
  check[0] = ds->read();
  check[1] = ds->read();

  // check what the device returned to determine success or failure
  if (check[0] == 0xAA) {
// #define VERBOSE
#ifdef VERBOSE
    Serial.print("    ");
    Serial.println("received 0xAA, success");
    Serial.print("    ");
#endif

  } else {
    Serial.println("    set device failure");
    rc = false;
  }

  return rc;
}
bool mcrDS::cmdCallback(JsonObject &root) {

  // json format of pio state key/value pairs
  // {"pio":[{"1":false}]}
  const char *sw = root["switch"];
  const JsonVariant &variant = root.get<JsonVariant>("pio");
  const JsonArray &pio = variant.as<JsonArray>();
  uint8_t mask = 0x00;
  uint8_t state = 0x00;

  // iterate through the array of pio values
  for (auto value : pio) {
    // get a reference to the object from the array
    const JsonObject &object = value.as<JsonObject>();

    // use ArduionJson ability to iterate through the key/value pairs
    for (auto kv : object) {
      uint8_t bit = atoi(kv.key);
      const bool position = kv.value.as<bool>();

      // set the mask with each bit that should be adjusted
      mask |= (0x01 << bit);

      // set the tobe state with the values those bits should be
      if (position) {
        state |= (0x01 << bit);
      }
    }
  }
  mcrCmd cmd(sw, mask, state);
  cmd_queue.push(&cmd);

#ifdef VERBOSE
  uint8_t pio_count = root["pio_count"];
  Serial.print("  mcrDS::cmdCallback() invoked for switch: ");
  Serial.print(sw);
  Serial.print(" pio_count=");
  Serial.print(pio_count);
  Serial.print(" requested_state=");
  Serial.print(state, HEX);
  Serial.println();
#endif

  return true;
}
