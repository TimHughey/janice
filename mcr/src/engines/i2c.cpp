/*
     mcpr_i2c.cpp - Master Control Remote I2C
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

     AM2315 code was based on Matt Heitzenroder's Arduino library
     with portions of his code inspired by Joehrg Ehrsam's am2315-python-api
     code (http://code.google.com/p/am2315-python-api/) and
     Sopwith's library (http://sopwith.ismellsmoke.net/?p=104).

     https://www.wisslanding.com
 */

// #define VERBOSE 1

#if ARDUINO >= 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

#include <WiFi101.h>
#include <Wire.h>

#include "../devs/base.hpp"
#include "../include/readings.hpp"
#include "../protocols/mqtt.hpp"
#include "i2c.hpp"

mcrI2c::mcrI2c(mcrMQTT_t *mqtt) : mcrEngine(mqtt) {
  // power up the i2c devices
  pinMode(I2C_PWR_PIN, OUTPUT);
  digitalWrite(I2C_PWR_PIN, HIGH);

  // Appears Wire.begin() must be called outside of a
  // constructor
  Wire.begin();
}

bool mcrI2c::init() { return true; }

// mcrI2c::discover()
// this method should be called often to ensure proper operator.
bool mcrI2c::discover() {
  mcrDevAddr_t *addrs = search_addrs();
  static uint8_t addrs_index = 0;
  static uint8_t bus = 0;
  auto rc = true;

  if (needDiscover()) {

    if (isIdle()) {
      printStartDiscover(__PRETTY_FUNCTION__);

      addrs_index = 0; // reset discover control variables
      bus = 0;         // since we are starting discover
      detectMultiplexer();
      startDiscover();
    }

    bool more_buses = useMultiplexer() ? (bus < (maxBuses())) : (bus == 0);

    if (!more_buses) {           // reached the
      idle(__PRETTY_FUNCTION__); // end of the discover cycle
      printStopDiscover(__PRETTY_FUNCTION__);
      return rc;
    }

    mcrDevAddr_t &search_addr = addrs[addrs_index]; // detect the next device
    selectBus(bus);
    if (detectDev(search_addr, false)) {
      i2cDev_t dev(search_addr, useMultiplexer(), bus);

      if (justSeenDevice(dev)) {
        if (infoMode || discoverLogMode) {
          logDateTime(__PRETTY_FUNCTION__);
          log("flagging device as just seen: ");
          dev.debug();
          log(" sizeof(i2cDev_t)=");
          log(sizeof(i2cDev_t), true);
        }
      } else { // device was not known, must addr
        i2cDev_t *new_dev = new i2cDev(dev);
        if (infoMode || discoverLogMode) {
          logDateTime(__PRETTY_FUNCTION__);
          log("adding device: ");
          dev.debug();
          log(" sizeof(i2cDev_t)=");
          log(sizeof(i2cDev_t), true);
        }
        addDevice(new_dev);
      }
    }

    addrs_index += 1; // increment to next search dev

    if (addrs_index >= search_addrs_count()) { // if next dev exceeds
      bus += 1;                                // the count of search devs
      addrs_index = 0;                         // move to next bus

      // if (specialDebugMode) {
      //   logDateTime(__PRETTY_FUNCTION__);
      //   log("finished scanning bus: ");
      //   log((bus - 1), true);
      // }
    } // last bus check
  }   // needDiscover

  return rc;
}

bool mcrI2c::report() {
  bool rc = true;
  mcrDev_t *next_dev = nullptr;
  i2cDev_t *dev = nullptr;

  if (needReport()) {
    if (isIdle()) {
      printStartReport(__PRETTY_FUNCTION__);
      next_dev = getFirstKnownDevice();
      startReport();
    } else {
      next_dev = getNextKnownDevice();
    }

    dev = (i2cDev_t *)next_dev;
    humidityReading_t *humidity = nullptr;

    if (dev) {
      selectBus(dev->bus());

      switch (dev->devAddr()) {
      case 0x5C:
        rc = readAM2315(dev, &humidity);
        dev->setReading(humidity);
        break;

      case 0x44:
        rc = readSHT31(dev, &humidity);
        dev->setReading(humidity);
        break;

      default:
        printUnhandledDev(__PRETTY_FUNCTION__, dev);
        break;
      }

      if (humidity != nullptr) {
        publish(humidity);
      }
    }

    if ((dev == nullptr) && isReportActive()) {
      idle(__PRETTY_FUNCTION__);
      printStopReport(__PRETTY_FUNCTION__);
    }
  }

  return rc;
}

bool mcrI2c::readAM2315(i2cDev_t *dev, humidityReading_t **reading) {
  elapsedMillis read_elapsed;
  static uint8_t error_count = 0;
  auto rc = true;

  uint8_t cmd[] = {0x03, 0x00, 0x04};
  uint8_t buff[] = {
      0x00,       // cmd code
      0x00,       // byte count
      0x00, 0x00, // relh high byte, low byte
      0x00, 0x00, // tempC high byte, low byte
      0x00, 0x00  // CRC high byte, low byte
  };

  memset(buff, 0x00, sizeof(buff));

  dev->startRead();
  // wake up the device from builtin power save mode
  Wire.beginTransmission(dev->devAddr());
  delay(2);
  Wire.endTransmission();

  // get the device data
  Wire.beginTransmission(dev->devAddr());
  Wire.write(cmd, sizeof(cmd));
  Wire.endTransmission();
  delay(10);
  Wire.requestFrom(0x5c, 8);
  dev->stopRead();
  if (debugMode)
    dev->printReadMS(__PRETTY_FUNCTION__);

#ifdef VERBOSE
  Serial.print("    Read Device bytes = ");
#endif

  for (uint8_t i = 0; i < 8; i++) {
    buff[i] = Wire.read();

#ifdef VERBOSE
    Serial.print("0x");
    Serial.print(buff[i], HEX);
    Serial.print(" ");
#endif
  }

#ifdef VERBOSE
  Serial.println();
#endif

  // verify the CRC
  uint16_t crc = buff[7] * 256 + buff[6];
  uint16_t crc_calc = 0xFFFF;

#ifdef VERBOSE
  Serial.print("    crc check: 0x");
  Serial.print(crc, HEX);
#endif

  for (uint8_t i = 0; i < 6; i++) {
    crc_calc = crc_calc ^ buff[i];

    for (uint8_t j = 0; j < 8; j++) {
      if (crc_calc & 0x01) {
        crc_calc = crc_calc >> 1;
        crc_calc = crc_calc ^ 0xA001;
      } else {
        crc_calc = crc_calc >> 1;
      }
    }
  }

  if (crc == crc_calc) {

#ifdef VERBOSE
    Serial.print(" == 0x");
    Serial.println(crc_calc, HEX);
    Serial.print("    read took ");
    Serial.print(read_elapsed);
    Serial.println("ms");
#endif

    float rh = buff[2];
    rh *= 256;
    rh += buff[3];
    rh /= 10;

    float tc = buff[4] & 0x7F;
    tc *= 256;
    tc += buff[5];
    tc /= 10;

    if (buff[4] >> 7)
      tc = -tc;

#ifdef VERBOSE
    String msg = String("    tc=") + tc + " rh=" + rh;
    Serial.println(msg);
#endif

    *reading = new humidityReading(dev->id(), dev->readTimestamp(), tc, rh);
    error_count = 0;
  } else { // crc did not match
    error_count += 1;
    rc = false;

#ifdef VERBOSE
    Serial.print(" != 0x");
    Serial.print(crc_calc, HEX);
    Serial.print(" (took ");
    Serial.print(read_elapsed);
    Serial.println("ms)");
#endif
  }
  return rc;
}

bool mcrI2c::readSHT31(i2cDev_t *dev, humidityReading_t **reading) {
  elapsedMillis read_elapsed;
  static uint8_t error_count = 0;
  auto rc = true;

  uint8_t cmd[] = {0x24, 0x00};
  uint8_t buff[] = {
      0x00, 0x00, // tempC high byte, low byte
      0x00,       // crc8 of temp
      0x00, 0x00, // relh high byte, low byte
      0x00        // crc8 of relh
  };

  memset(buff, 0x00, sizeof(buff));

  dev->startRead();
  Wire.beginTransmission(dev->devAddr());
  Wire.write(cmd, sizeof(cmd));
  Wire.endTransmission(true);

  delay(15);

  Wire.requestFrom(0x44, sizeof(buff));
  dev->stopRead();
  if (debugMode)
    dev->printReadMS(__PRETTY_FUNCTION__);

#ifdef VERBOSE
  Serial.print("    Read Device bytes = ");
#endif

  for (uint8_t i = 0; i < sizeof(buff); i++) {
    buff[i] = Wire.read();

#ifdef VERBOSE
    Serial.print("0x");
    Serial.print(buff[i], HEX);
    Serial.print(" ");
#endif
  }

#ifdef VERBOSE
  Serial.println();
#endif

  uint8_t crc_temp = crcSHT31(buff, 2);
  uint8_t crc_relh = crcSHT31(buff + 3, 2);

#ifdef VERBOSE
  Serial.print("    crc check: 0x");
  Serial.print(crc_temp, HEX);
  Serial.print(crc_relh, HEX);
#endif

  if ((crc_temp == buff[2]) && (crc_relh == buff[5])) {

#ifdef VERBOSE
    Serial.print(" == 0x");
    Serial.print(buff[2], HEX);
    Serial.println(buff[5], HEX);
    Serial.print("    read took ");
    Serial.print(read_elapsed);
    Serial.println("ms");
#endif

    // conversion pulled from SHT31 datasheet
    uint16_t stc = buff[0];
    stc <<= 8;
    stc |= buff[1];

    uint16_t srh = buff[3];
    srh <<= 8;
    srh |= buff[4];

    double raw_tc = stc;
    raw_tc *= 175;
    raw_tc /= 0xFFFF;
    raw_tc = -45 + raw_tc;
    float tc = raw_tc;

    double raw_rh = srh;
    raw_rh *= 100;
    raw_rh /= 0xFFFF;
    float rh = raw_rh;

#ifdef VERBOSE
    String msg = String("    tc=") + tc + " rh=" + rh;
    Serial.println(msg);
#endif

    *reading = new humidityReading(dev->id(), dev->readTimestamp(), tc, rh);

    error_count = 0;
  } else { // crc did not match
    error_count += 1;
    rc = false;

#ifdef VERBOSE
    Serial.print(" != 0x");
    Serial.print(buff[2], HEX);
    Serial.println(buff[5], HEX);
    Serial.println("    read took ");
    Serial.print(read_elapsed);
    Serial.println("ms)");
#endif
  }

  return rc;
}

uint8_t mcrI2c::crcSHT31(const uint8_t *data, uint8_t len) {
  uint8_t crc = 0xFF;

  for (uint8_t j = len; j; --j) {
    crc ^= *data++;

    for (uint8_t i = 8; i; --i) {
      crc = (crc & 0x80) ? (crc << 1) ^ 0x31 : (crc << 1);
    }
  }
  return crc;
}

bool mcrI2c::detectDev(mcrDevAddr_t &addr, bool use_multiplexer, uint8_t bus) {
  bool rc = false;

  Wire.beginTransmission(addr.firstAddressByte());

  // handle special cases where certain i2c devices
  // need additional cmds before releasing the bus
  switch (addr.firstAddressByte()) {
  case 0x70:          // TCA9548B - TI i2c bus multiplexer
    Wire.write(0x00); // select no bus
    break;

  case 0x44:          // SHT-31 humidity sensor
    Wire.write(0x30); // soft-reset
    Wire.write(0xA2);
    break;

  case 0x5C: // AM2315 needs to be woken up
    Wire.endTransmission();
    delay(2);
    Wire.beginTransmission(addr.firstAddressByte());
  }

  // Wire.endTransmission() returns 0 if the
  // device acknowledged it's address
  uint8_t error = Wire.endTransmission(true);

  switch (error) {
  case 0x00:
    rc = true; // device acknowledged the transmission
    break;

  case 0x01:
    // Serial.println("    data too long to fit transmit buffer");
    break;
  case 0x02:
    // Serial.print("    received NACK on transmit of address 0x");
    // Serial.println(addr, HEX);
    break;
  case 0x03:
    // Serial.println("    received NACK on transmit of data");
    break;
  case 0x04:
    // Serial.println("other error");
    break;
  }

  return rc;
}

// utility methods

bool mcrI2c::detectMultiplexer() {
  _use_multiplexer = false;

  if (discoverLogMode || debugMode) {
    logDateTime(__PRETTY_FUNCTION__);
    log("detecting TCA9514B i2c bus multiplexer: ");
  }
  // let's see if there's a multiplexer available
  mcrDevAddr_t multiplexer_dev(0x70);
  if (detectDev(multiplexer_dev)) {
    if (discoverLogMode || debugMode)
      log(" found", true);

    _use_multiplexer = true;
  } else {
    if (discoverLogMode || debugMode)
      log(" not found", true);
  }

  return _use_multiplexer;
}

uint8_t mcrI2c::maxBuses() { return _max_buses; }
bool mcrI2c::useMultiplexer() { return _use_multiplexer; }

void mcrI2c::selectBus(uint8_t bus) {
  if (bus >= _max_buses) {
    logDateTime(__PRETTY_FUNCTION__);
    log("[WARNING] attempt to select bus >= ");
    log(_max_buses);
    log(", selected bus remains unchanged", true);
  }

  if (useMultiplexer() && (bus < _max_buses)) {
    Wire.beginTransmission(0x70);
    Wire.write(0x01 << bus);
    Wire.endTransmission(true);
  }
}

void mcrI2c::printUnhandledDev(const char *func, i2cDev_t *dev) {
  logDateTime(func);

  log("unhandled dev addr: ");
  log(dev->devAddr());
  log(" desc: ");
  log(dev->desc());
  log(" use_multiplexer: ");
  log(dev->useMultiplexer());
  log(" bus: ");
  log(dev->bus(), true);
}
