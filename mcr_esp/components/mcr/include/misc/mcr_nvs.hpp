/*
    mcr_nvs.hpp -- MCR abstraction for ESP32 NVS
    Copyright (C) 2019  Tim Hughey

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

#ifndef mcr_nvs_hpp
#define mcr_nvs_hpp

#include <string>

#include <sys/time.h>
#include <time.h>

#include <esp_system.h>
#include <nvs.h>
#include <nvs_flash.h>

#define MCR_NVS_MSG_MAX_LEN 256

namespace mcr {

typedef struct {
  time_t time = 0;
  char msg[MCR_NVS_MSG_MAX_LEN] = {};
} mcrNVSMessage_t;

typedef class mcrNVS mcrNVS_t;

class mcrNVS {
private:
  // to minimize the impact on the stack of individual tasks we
  // allocate from the heap and use member variables.
  // this does have the potential downside of heap fragmentation.
  // this approach should be monitored to ensure it is meeting the goal.
  const char *_nvs_namespace = "mcr";
  nvs_handle _handle;
  esp_err_t _esp_rc = ESP_OK;
  esp_err_t _nvs_open_rc = ESP_FAIL;

  mcrNVSMessage_t *_blob = nullptr;
  struct tm _timeinfo = {};
  char *_time_str = nullptr;
  size_t _time_str_max_len = 25;
  size_t _msg_len = 0;

  const char *_possible_keys[7] = {"BOOT",    "mcrNet",  "mcrNet-connection",
                                   "mcrI2c",  "mcrMQTT", "hostname",
                                   "END_KEYS"};

  bool _committed_msgs_processed = false;

  mcrNVS();
  ~mcrNVS();

  bool notOpen();
  void publishMsg(const char *key, mcrNVSMessage_t *msg);
  void zeroBuffers();

  // we use the double underscore prefix that implement publicly
  // available static functions
  esp_err_t __commitMsg(const char *key, const char *msg);
  esp_err_t __processCommittedMsgs();

public:
  static mcrNVS_t *init();
  static mcrNVS *instance();

  static esp_err_t commitMsg(const char *key, const char *msg);
  static esp_err_t processCommittedMsgs();
  // static esp_err_t processCommittedMsgs();
};
} // namespace mcr

#endif // mcr_nvs_hpp
