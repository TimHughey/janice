#include <Adafruit_SleepyDog.h>
#include <ArduinoJson.h>
#include <SPI.h>
#include <TimeLib.h>
#include <WiFi101.h>
#include <Wire.h>
#include <elapsedMillis.h>

#include "engines/ds.hpp"
#include "engines/i2c.hpp"
#include "misc/util.hpp"
#include "protocols/mqtt.hpp"
#include "readings/ramutil.hpp"

// boards 32u4, M0, and 328p
#define LED 13
#define VBAT_PIN A7
// #define SOIL_METER_PWR_PIN 11
// #define SOIL_METER_ANALOG_PIN A5

#if defined(ARDUINO_SAMD_ZERO) && defined(SERIAL_PORT_USBVIRTUAL)
// Required for Serial on Zero based boards
#define Serial SERIAL_PORT_USBVIRTUAL
#endif

#ifdef WATCHDOG_TIMEOUT
#define USE_WATCHDOG
#endif

#ifdef ALT_WIFI
const char ssid[] = "";
const char pass[] = "";
#else
const char ssid[] = "WissLanding";               //  your network SSID (name)
const char pass[] = "I once was a porch kitty."; // your network password
#endif

int wifiStatus = WL_IDLE_STATUS; // the WiFi radio's status

#define MQTT_SERVER "jophiel.wisslanding.com"
#define MQTT_PORT 1883

void statusIndicator();

WiFiClient wifi;

#ifdef ALT_WIFI
IPAddress broker(108, 35, 196, 234);
#else
IPAddress broker(192, 168, 2, 4);
#endif

mcrMQTT_t *mqtt = nullptr;
mcrDS_t *ds = nullptr;
mcrI2c_t *i2c = nullptr;

int debugMode = 0;

void setup() {
  WiFi.setPins(8, 7, 4, 2);
  Serial.begin(115200);
  while (!Serial && (millis() < 15000)) {
    ;
  }

  logDateTime(__PRETTY_FUNCTION__);
  log("serial initialized", true);

  if (WiFi.status() == WL_NO_SHIELD) {
    logDateTime(__PRETTY_FUNCTION__);
    log("wifi shield not detected");
  } else {
    logDateTime(__PRETTY_FUNCTION__);
    log("connecting to WPA SSID ");
    log(ssid);
    log("(firmware: ");
    log(WiFi.firmwareVersion());
    log(")...");

    while (wifiStatus != WL_CONNECTED) {
      wifiStatus = WiFi.begin(ssid, pass);

      delayMicroseconds(100);
      log(".");
    }
  }

  log(" ", true);

  mcrUtil::printNet(__PRETTY_FUNCTION__);

  logDateTime(__PRETTY_FUNCTION__);
  log("mcrID: ");
  log(mcrUtil::hostID(), true);

  logDateTime(__PRETTY_FUNCTION__);
  log("build_env: ");
  log(Version::env());
  log("git HEAD=");
  log(Version::git());
  log(" mcr_stable=");
  log(Version::mcr_stable(), true);

  logDateTime(__PRETTY_FUNCTION__);

  setSyncInterval(120); // setting a high time sync interval since we rely on
  // updates via MQTT

  logDateTime(__PRETTY_FUNCTION__);
  log("mcrMQTT");
  mqtt = new mcrMQTT(wifi, broker, MQTT_PORT);
  log(" created, ");
  mqtt->connect();
  log("connected, ");
  mqtt->announceStartup();
  log("announced startup", true);

  logDateTime(__PRETTY_FUNCTION__);
  log("mcrDS");
  ds = new mcrDS(mqtt);
  log(" created,");
  ds->init();
  log(" initialized", true);

  logDateTime(__PRETTY_FUNCTION__);
  log("mcrI2C");
  i2c = new mcrI2c(mqtt);
  log(" created, ");
  i2c->init();
  log("initialized", true);

  mcrUtil::printFreeMem(__PRETTY_FUNCTION__, 0);
  logDateTime(__PRETTY_FUNCTION__);
  log("completed, transition to main::loop()", true);

#ifdef USE_WATCHDOG
  Watchdog.enable(WATCHDOG_TIMEOUT);
#endif
}

elapsedMillis loop_duration;
void loop() {
  static bool first_entry = true;
  static const time_t _loop_run_warning = (150 * 1000); // 150ms
  static elapsedMillis report_stats;
  elapsedMicros loop_elapsed;

  if (first_entry) {
    logDateTime(__PRETTY_FUNCTION__);
    log("first invocation", true);
    first_entry = false;
  }

  mqtt->loop();

  ds->loop();
  mqtt->loop();

  i2c->loop();
  mqtt->loop();

  statusIndicator();
  mcrUtil::printFreeMem(__PRETTY_FUNCTION__, 15);

// if WiFi is connected then reset the Watchdog
// otherwise the watchdog will provide for an auto restart
#ifdef USE_WATCHDOG
  if (WiFi.status() == WL_CONNECTED) {
    Watchdog.reset();
  }
#endif

  if (loop_elapsed > (_loop_run_warning)) {
    logDateTime(__PRETTY_FUNCTION__);
    log("[WARNING] elapsed time ");
    logElapsedMicros(loop_elapsed, true);
  }

  if (report_stats > 10000) {
    ramUtilReading_t free_ram(mcrUtil::freeRAM());
    mqtt->publish(&free_ram);

    report_stats = 0;
  }
}

void statusIndicator() {
  static boolean led_state = true;
  static elapsedMillis statusMillis = 0;
  uint8_t flash_rate = 100;

  if (ds->isConvertActive() == true) {
    flash_rate = 35;
  }

  if (statusMillis >= flash_rate) {
    if (led_state) {
      digitalWrite(LED, HIGH);
    } else {
      digitalWrite(LED, LOW);
    }

    led_state = !led_state;
    statusMillis = 0;
  }
}
