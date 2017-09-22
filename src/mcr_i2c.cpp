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

mcrI2C::mcrI2C(mcrMQTT *mqtt) : mcrEngine(mqtt) {}

boolean mcrI2C::init() {
  boolean rc = true;

  Serial.println();
  Serial.print(__PRETTY_FUNCTION__);
  Serial.println(" entered");

  mcrEngine::init();

  Serial.print(__PRETTY_FUNCTION__);
  Serial.println(" allocating known_devs");
  known_devs = new i2cDev *[maxDevices()];

  Serial.print(__PRETTY_FUNCTION__);
  Serial.println(" clearing known_devs memory");
  memset(known_devs, 0x00, sizeof(i2cDev *) * maxDevices());

  // power up the i2c devices
  pinMode(I2C_PWR_PIN, OUTPUT);
  digitalWrite(I2C_PWR_PIN, HIGH);

  // Appears Wire.begin() must be called outside of a
  // constructor
  Wire.begin();

  Serial.println();
  Serial.print(__PRETTY_FUNCTION__);
  Serial.println(" exited");

  return rc;
}

// mcrI2C::discover()
// this method should be called often to ensure proper operator.
//
//  1. if the enough millis have elapsed since the last full discovery
//     this method then it will start a new discovery.
//  2. if a discovery cycle is in-progress this method will execute
//     a single search

boolean mcrI2C::discover() {
  i2cDev *devs = search_devs();
  static uint8_t dev_index = 0;
  static uint8_t bus = 0;
  const uint8_t max_buses = 8;
  auto rc = true;

  if (needDiscover()) {
    if (isIdle()) {
      Serial.print("  mcrI2C::discover started, ");
      Serial.print(lastDiscoverRunMS());
      Serial.println("ms since last discover");

      startDisover();

      // set-up static control variables for start of discover
      use_multiplexer = false;
      dev_index = 0;
      bus = 0;

      clearKnownDevices();
    }

    i2cDev *search_dev = &(devs[dev_index]);

    // before searching for any devices let's see if there's
    // a multiplexer available
    if ((use_multiplexer == false) && (dev_index == 0)) {

      // let's see if there's a multiplexer available
      if (detectDev(0x70)) {
#ifdef VERBOSE
        Serial.println("    detected TCA9514B i2c multiplexer");
#endif
        use_multiplexer = true;
        bus = 0;
#ifdef VERBOSE
        Serial.print("    searching i2c bus 0x");
        Serial.println(bus, HEX);
#endif
      }
    }

    // always select the bus if a multiplexer is available
    if ((use_multiplexer == true) && (bus < max_buses)) {
      // we are using a multiplexer so select the bus
      Wire.beginTransmission(0x70);
      Wire.write(0x01 << bus);
      Wire.endTransmission(true);
    }

    // attempt to detect the device
    // noting the bus will already be selected if
    // a multiplexer is being used
    if (detectDev(search_dev->devAddr(), false)) {
      addDevice(search_dev->devAddr(), use_multiplexer, bus);

#ifdef VERBOSE
      Serial.print("    i2c bus 0x");
      Serial.print(bus, HEX);
      Serial.print(" hosts 0x");
      Serial.print(search_dev->addr(), HEX);
      Serial.print(",");
      Serial.print(search_dev->desc());
      Serial.println("");
#endif
    }

    boolean more_buses = (bus < (max_buses - 1));
    boolean more_devs = ((dev_index + 1) < search_devs_count());

    // when we've searched all the possible devices and are using a
    // multiplexer we increment the bus by 1 (to search the next)
    // and reset dev_index to 0 (to search for all devices on the next bus)
    if (use_multiplexer && more_buses && (!more_devs)) {
      bus += 1;
      dev_index = 0;
#ifdef VERBOSE
      Serial.print("    searching i2c bus 0x");
      Serial.println(bus, HEX);
#endif
    } else if (use_multiplexer && more_devs) {
      dev_index += 1;
    }
    // only increment the dev_index if there are more devs to search
    else if (use_multiplexer && more_buses && more_devs) {
      dev_index += 1;
    }
    // if there isn't a multiplexer but there are more search devs
    // increment the dev_index
    else if ((!use_multiplexer) && more_devs) {
      dev_index += 1;
    }
    // discover is complete when:
    //  1. if there isn't a multiplexer and there aren't more
    //     search devs
    //  2. there is a multiplexer and we've searched all buses
    else if (((!use_multiplexer) && (!more_devs)) ||
             (use_multiplexer && (!more_buses))) {

      idle();

      if (devCount() == 0) {
        Serial.print("    [WARNING] no devices found on i2c bus in ");
        Serial.print(lastDiscoverRunMS());
        Serial.println("ms");
        Serial.println();
        // discover_interval_millis = 3000;
      } else {
        Serial.print("  mrcI2c::discover() found ");
        Serial.print(devCount());
        Serial.print(" device(s) in ");
        Serial.print(lastDiscoverRunMS());
        Serial.println("ms");
        Serial.println();
      }
    } else {
      // TODO: remove after testing, shouldn't be needed
      Serial.println("    uh-oh, logic error in mcrI2c::discover()");
    }
  }

  return rc;
}

boolean mcrI2C::report() {
  boolean rc = true;
  static uint8_t dev_index = 0;

  if (needReport()) {
    Reading *reading = NULL;

    startReport();

    if (dev_index < devCount()) {
      i2cDev *dev = known_devs[dev_index];

      if (dev->useMultiplexer()) {
        Wire.beginTransmission(0x70);
        Wire.write(0x01 << dev->bus());
        Wire.endTransmission();
      }

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
    } else {
      dev_index = 0;
      idle();
    }
  }

  return rc;
}

boolean mcrI2C::readAM2315(i2cDev *dev, Reading **reading) {
  elapsedMillis read_elapsed;
  static uint8_t error_count = 0;
  auto rc = true;
  const char *name = dev->id();

  uint8_t cmd[] = {0x03, 0x00, 0x04};
  uint8_t buff[] = {
      0x00,       // cmd code
      0x00,       // byte count
      0x00, 0x00, // relh high byte, low byte
      0x00, 0x00, // tempC high byte, low byte
      0x00, 0x00  // CRC high byte, low byte
  };

  memset(buff, 0x00, sizeof(buff));

  // wake up the device from builtin power save mode
  Wire.beginTransmission(dev->devAddr());
  delay(2);
  Wire.endTransmission();

  time_t reading_ts = now();

  // get the device data
  Wire.beginTransmission(dev->devAddr());
  Wire.write(cmd, sizeof(cmd));
  Wire.endTransmission();
  delay(10);
  Wire.requestFrom(0x5c, 8);

  Serial.print("  AM2315 ");
  Serial.print(name);
  Serial.print(" read in ");
  Serial.print(read_elapsed);
  Serial.println("ms");

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

    *reading = new Reading(dev->id(), reading_ts, tc, rh);
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

  Serial.println();
  return rc;
}

boolean mcrI2C::readSHT31(i2cDev *dev, Reading **reading) {
  elapsedMillis read_elapsed;
  static uint8_t error_count = 0;
  auto rc = true;
  const char *name = dev->id();

  uint8_t cmd[] = {0x24, 0x00};
  uint8_t buff[] = {
      0x00, 0x00, // tempC high byte, low byte
      0x00,       // crc8 of temp
      0x00, 0x00, // relh high byte, low byte
      0x00        // crc8 of relh
  };

  memset(buff, 0x00, sizeof(buff));

  Wire.beginTransmission(dev->devAddr());
  Wire.write(cmd, sizeof(cmd));
  Wire.endTransmission(true);

  delay(15);

  time_t reading_ts = now();
  Wire.requestFrom(0x44, sizeof(buff));

  Serial.print("  SHT-31 ");
  Serial.print(name);
  Serial.print(" read in ");
  Serial.print(read_elapsed);
  Serial.println("ms");

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

    *reading = new Reading(dev->id(), reading_ts, tc, rh);

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

  Serial.println();
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

boolean mcrI2C::detectDev(uint8_t addr, boolean use_multiplexer, uint8_t bus) {
  boolean rc = false;

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
