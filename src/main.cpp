#include <SPI.h>
#include <TimeLib.h>
#include <WiFi101.h>
#include <Wire.h>
#include <elapsedMillis.h>
// #include <Adafruit_SleepyDog.h>
#include <ArduinoJson.h>

#include "mcr_ds.hpp"
#include "mcr_i2c.hpp"
#include "mcr_mqtt.hpp"
#include "mcr_util.hpp"

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
void printFreeMem(uint8_t secs);
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
  Serial.begin(115200);
  while (!Serial && millis() < 5000) {
    ;
  }

  if (WiFi.status() == WL_NO_SHIELD) {
    Serial.println("main::setup(): wifi shield not detected.");
  } else {

    Serial.print("main::setup(): connecting to WPA SSID ");
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

  Serial.print("main::setup(): mcrMQTT");
  mqtt = new mcrMQTT(wifi, broker, MQTT_PORT);
  Serial.print(" created, ");
  mqtt->connect();
  Serial.println("connected");

  Serial.print("main::setup(): mcrDS");
  ds = new mcrDS(mqtt);
  Serial.print(" created,");
  ds->init();
  Serial.println(" initialized");

  Serial.print("main::setup(): mcrI2C");
  i2c = new mcrI2C(mqtt);
  Serial.print(" created, ");
  i2c->init();
  Serial.println("initialized");

  mqtt->announceStartup();

  Serial.println("main::setup(): completed, transition to main::loop()");
}

elapsedMillis loop_duration;
void loop() {
  elapsedMillis loop_elapsed;

  mqtt->loop();
  ds->loop();
  i2c->loop();

  statusIndicator();
  printFreeMem(15);

  // Watchdog.reset();

  if (loop_elapsed > 150) {
    Serial.print("\r\n");
    Serial.print("  [WARNING] main loop took ");
    Serial.print(loop_elapsed);
    Serial.println("ms");
  }
}

void printWiFiData() {
  // print your WiFi shield's IP address:
  IPAddress ip = WiFi.localIP();
  Serial.print("IP address: ");
  Serial.println(ip);

  Serial.print("MAC address: ");
  Serial.println(mcrUtil::macAddress());
}

void printFreeMem(uint8_t secs) {
  static int first_free = 0;
  static int prev_free = 0;
  static elapsedMillis freeMemReport;
  int delta = prev_free - mcrUtil::freeRAM();
  int delta_since_first = first_free - mcrUtil::freeRAM();

  if (first_free == 0) {
    first_free = mcrUtil::freeRAM();
    delta_since_first = 0;
  }

  if (freeMemReport > (secs * 1000)) {
    char _dt[30] = {0x00};
    time_t t = now() - (4 * 60 * 60); // rough conversion to EDT
    int percentFree = ((float)mcrUtil::freeRAM() / (float)32000) * 100;
    int freeK = mcrUtil::freeRAM() / 1000;

    sprintf(_dt, "%02d/%02d/%02d %02d:%02d:%02d ", month(t), day(t), year(t),
            hour(t), minute(t), second(t));

    Serial.println();
    Serial.print(_dt);
    Serial.print(" ");
    Serial.print(__PRETTY_FUNCTION__);
    Serial.print(" free SRAM: ");
    Serial.print(percentFree);
    Serial.print("% (");
    Serial.print(freeK);
    Serial.print("k of 32k) delta: ");
    Serial.print(delta);
    Serial.print(" delta since first report: ");
    Serial.print(delta_since_first);
    Serial.println();
    Serial.println();

    freeMemReport = 0;
    prev_free = mcrUtil::freeRAM();
  }
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
