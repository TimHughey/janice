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

#include "mcr_i2c.hpp"
#include "mcr_mqtt.hpp"
#include "reading.hpp"

mcrI2C::mcrI2C(mcrMQTT *mqtt) : mcrEngine(mqtt) {
  known_devs = new i2cDev *[maxDevices()];

  memset(known_devs, 0x00, sizeof(i2cDev *) * maxDevices());

  // power up the i2c devices
  pinMode(I2C_PWR_PIN, OUTPUT);
  digitalWrite(I2C_PWR_PIN, HIGH);

  // Appears Wire.begin() must be called outside of a
  // constructor
  Wire.begin();
}

bool mcrI2C::init() { return true; }

// mcrI2C::discover()
// this method should be called often to ensure proper operator.
bool mcrI2C::discover() {
  i2cDev *devs = search_devs();
  static uint8_t dev_index = 0;
  static uint8_t bus = 0;
  auto rc = true;

  if (needDiscover()) {
    if (isIdle()) {
      printStartDiscover(__PRETTY_FUNCTION__);

      dev_index = 0; // reset discover control variables
      bus = 0;       // since we are starting discover

      clearKnownDevices();
      detectMultiplexer();
      startDiscover();
    }

    bool more_buses = useMultiplexer() ? (bus < (maxBuses())) : (bus == 0);
    // bool more_devs = ((dev_index) < search_devs_count());

    if (isDiscoveryActive())

      if (!more_buses) {           // reached the
        idle(__PRETTY_FUNCTION__); // end of the discover cycle
        printStopDiscover(__PRETTY_FUNCTION__);
        return rc;
      }

    i2cDev *search_dev = &(devs[dev_index]); // detect the next device
    selectBus(bus);
    if (detectDev(search_dev->devAddr(), false)) {
      addDevice(search_dev->devAddr(), useMultiplexer(), bus);
    }

    dev_index += 1; // increment to next search dev

    if (dev_index >= search_devs_count()) { // if next dev exceeds
      bus += 1;                             // the count of search devs
      dev_index = 0;                        // move to next bus
    }
  } // needDiscover

  return rc;
}

bool mcrI2C::report() {
  bool rc = true;
  static uint8_t dev_index = 0;

  if (needReport()) {
    if (isIdle()) {
      dev_index = 0;
      startReport();
    }

    Reading *reading = NULL;

    if (dev_index < devCount()) {
      i2cDev *dev = known_devs[dev_index];

      selectBus(dev->bus());

      switch (dev->devAddr()) {
      case 0x5C:
        rc = readAM2315(dev, &reading);
        dev->setReading(reading);
        break;

      case 0x44:
        rc = readSHT31(dev, &reading);
        dev->setReading(reading);
        break;

      default:
        Serial.print("  mcrI2C::deviceReport unhandled dev addr: ");
        Serial.print(dev->devAddr());
        Serial.print(" desc: ");
        Serial.print(dev->desc());
        Serial.print(" use_multiplexer: ");
        Serial.print(dev->useMultiplexer());
        Serial.print(" bus: ");
        Serial.print(dev->bus());
        Serial.println();
        break;
      }

      if (reading != NULL) {
        mqtt->publish(reading);
      }

      dev_index += 1;
    }

    if (isReportActive() && (dev_index >= devCount())) {
      idle(__PRETTY_FUNCTION__);
    }
  }

  return rc;
}

bool mcrI2C::readAM2315(i2cDev *dev, Reading **reading) {
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

    *reading = new Reading(dev->id(), dev->readTimestamp(), tc, rh);
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

bool mcrI2C::readSHT31(i2cDev *dev, Reading **reading) {
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

    *reading = new Reading(dev->id(), dev->readTimestamp(), tc, rh);

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

uint8_t mcrI2C::crcSHT31(const uint8_t *data, uint8_t len) {
  uint8_t crc = 0xFF;

  for (uint8_t j = len; j; --j) {
    crc ^= *data++;

    for (uint8_t i = 8; i; --i) {
      crc = (crc & 0x80) ? (crc << 1) ^ 0x31 : (crc << 1);
    }
  }
  return crc;
}

bool mcrI2C::detectDev(uint8_t addr, bool use_multiplexer, uint8_t bus) {
  bool rc = false;

  Wire.beginTransmission(addr);

  // handle special cases where certain i2c devices
  // need additional cmds before releasing the bus
  switch (addr) {
  case 0x70:          // TCA9548B - TI i2c bus multiplexer
    Wire.write(0x00); // select no bus
    break;

  case 0x44:          // SHT-31 humidity sensor
    Wire.write(0x30); // soft-reset
    Wire.write(0xA2);
    break;

  case 0x5C: // AM2315 needs to be woken up
    Wire.endTransmission(true);
    delay(2);
    Wire.beginTransmission(addr);
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
