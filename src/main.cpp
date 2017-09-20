#include <SPI.h>
#include <TimeLib.h>
#include <WiFi101.h>
#include <Wire.h>
#include <elapsedMillis.h>
// #include <Adafruit_SleepyDog.h>
#include <ArduinoJson.h>

#include "mcr_ds.h"
#include "mcr_i2c.h"
#include "mcr_mqtt.h"
#include "mcr_util.h"

// boards 32u4, M0, and 328p
#define LED 13
#define VBAT_PIN A7
// #define AM215_PWR_PIN 12
// #define SOIL_METER_PWR_PIN 11
// #define SOIL_METER_ANALOG_PIN A5

//#if defined(ARDUINO_SAMD_ZERO) && defined(SERIAL_PORT_USBVIRTUAL)
// Required for Serial on Zero based boards
//#define Serial SERIAL_PORT_USBVIRTUAL
//#endif

// prototypes
void printWiFiData();
void printCurrentNet();

// #define ALT_WIFI

#ifdef ALT_WIFI
const char ssid[] = "TravelerVI";
const char pass[] = "425voosgt5ti8";
#else
const char ssid[] = "WissLanding";               //  your network SSID (name)
const char pass[] = "I once was a porch kitty."; // your network password
#endif

int wifiStatus = WL_IDLE_STATUS; // the WiFi radio's status

char mcrID[25];

#define MQTT_SERVER "jophiel.wisslanding.com"
#define MQTT_PORT 1883
#define MQTT_USER "mqtt"
#define MQTT_PASS "mqtt"
#define MQTT_FEED "mqtt/f/feather"

void statusIndicator();

WiFiClient wifi;

#ifdef ALT_WIFI
IPAddress broker(108, 35, 196, 234);
#else
IPAddress broker(192, 168, 2, 4);
#endif

mcrMQTT *mqtt = NULL;
mcrDS *ds = NULL;
mcrI2C *i2c = NULL;

int debugMode = 0;

void setup() {
  WiFi.setPins(8, 7, 4, 2);
  Serial.begin(9600);
  while (!Serial && millis() < 5000) {
    ;
  }

  if (WiFi.status() == WL_NO_SHIELD) {
    Serial.println("setup(): wifi shield not detected.");
  } else {

    Serial.print("setup(): connecting to WPA SSID ");
    Serial.print(ssid);
    Serial.print("...");
    while (wifiStatus != WL_CONNECTED) {
      wifiStatus = WiFi.begin(ssid, pass);

      delay(1);
      Serial.print(".");
    }
  }

  // you're connected now, so print out the data:
  Serial.println();

  printWiFiData();
  printCurrentNet();

  sprintf(mcrID, "mcr-%s", mcrUtil::macAddress());
  Serial.print("mcrID: ");
  Serial.println(mcrID);

  // Watchdog.enable(5000);
  setSyncInterval(120); // setting a high time sync interval since we rely on
                        // updates via MQTT

  Serial.print("setup(): mcrMQTT");
  mqtt = new mcrMQTT(wifi, broker, 1883);
  mqtt->debugOn();
  Serial.println(" created");

  Serial.print("setup(): mcrDS");
  ds = new mcrDS(mqtt);
  Serial.print(" created,");
  ds->init();
  Serial.println(" initialized");

  Serial.print("setup(): mcrI2C");
  i2c = new mcrI2C(mqtt);
  Serial.print(" created, ");
  i2c->init();
  Serial.println("initialized");

  Serial.println("setup(): completed, main loop() beginning...");
}

elapsedMillis loop_duration;
void loop() {
  static elapsedMillis freeMemReport;
  elapsedMillis loop_elapsed;

  mqtt->loop(true);
  ds->loop();
  i2c->loop();

  statusIndicator();

  // Watchdog.reset();

  if (loop_elapsed > 150) {
    Serial.print("\r\n");
    Serial.print("  [WARNING] main loop took ");
    Serial.print(loop_elapsed);
    Serial.println("ms");
  }

  if (freeMemReport > 25000) {
    int percentFree = ((float)mcrUtil::freeRAM() / (float)32000) * 100;
    int freeK = mcrUtil::freeRAM() / 1000;
    Serial.print("  free SRAM = ");
    Serial.print(percentFree);
    Serial.print("% (");
    Serial.print(freeK);
    Serial.print("k of 32k)");
    Serial.println();
    freeMemReport = 0;
  }
}

void printWiFiData() {
  // print your WiFi shield's IP address:
  IPAddress ip = WiFi.localIP();
  Serial.print("IP Address: ");
  Serial.println(ip);

  Serial.println(mcrUtil::macAddress());
}

void printCurrentNet() {
  // print the SSID of the network you're attached to:
  Serial.print("SSID: ");
  Serial.println(WiFi.SSID());

  // print the MAC address of the router you're attached to:
  byte bssid[6];
  WiFi.BSSID(bssid);
  Serial.print("BSSID: ");
  Serial.print(bssid[5], HEX);
  Serial.print(":");
  Serial.print(bssid[4], HEX);
  Serial.print(":");
  Serial.print(bssid[3], HEX);
  Serial.print(":");
  Serial.print(bssid[2], HEX);
  Serial.print(":");
  Serial.print(bssid[1], HEX);
  Serial.print(":");
  Serial.println(bssid[0], HEX);

  // print the received signal strength:
  long rssi = WiFi.RSSI();
  Serial.print("signal strength (RSSI):");
  Serial.println(rssi);

  // print the encryption type:
  byte encryption = WiFi.encryptionType();
  Serial.print("Encryption Type:");
  Serial.println(encryption, HEX);
  Serial.println();
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
