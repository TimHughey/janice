/*
    mcr_restart.cpp - MCR abstraction for esp_restart()
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

#include "misc/mcr_nvs.hpp"
#include "protocols/mqtt.hpp"

static mcrNVS_t *__singleton__ = nullptr;
static const char TAG[] = "mcrNVS";

mcrNVS::mcrNVS() {
  esp_err_t _esp_rc = ESP_OK;
  _esp_rc = nvs_flash_init();

  ESP_LOGI(TAG, "[%s] nvs_flash_init()", esp_err_to_name(_esp_rc));

  switch (_esp_rc) {
  case ESP_ERR_NVS_NO_FREE_PAGES:
    ESP_LOGW(TAG, "nvs no free pages, will erase");
    break;
  case ESP_ERR_NVS_NEW_VERSION_FOUND:
    ESP_LOGW(TAG, "nvs new data version, must erase");
    break;
  default:
    break;
  }

  if ((_esp_rc == ESP_ERR_NVS_NO_FREE_PAGES) ||
      (_esp_rc == ESP_ERR_NVS_NEW_VERSION_FOUND)) {

    // erase and attempt initialization again
    _esp_rc = nvs_flash_erase();
    ESP_LOGW(TAG, "[%s] nvs_flash_erase()", esp_err_to_name(_esp_rc));

    if (_esp_rc == ESP_OK) {
      _esp_rc = nvs_flash_init();

      ESP_LOGW(TAG, "[%s] nvs_init() (second attempt)",
               esp_err_to_name(_esp_rc));
    }
  }

  if (_esp_rc == ESP_OK) {
    _nvs_open_rc = nvs_open(_nvs_namespace, NVS_READWRITE, &_handle);

    if (_nvs_open_rc != ESP_OK) {
      ESP_LOGW(TAG, "[%s] nvs_open()", esp_err_to_name(_esp_rc));
    }
  }

  if (_blob == nullptr) {
    _blob = (mcrNVSMessage_t *)malloc(sizeof(mcrNVSMessage_t));
  }

  if (_time_str == nullptr) {
    _time_str = (char *)malloc(_time_str_max_len);
  }

  zeroBuffers();
}

// STATIC
mcrNVS_t *mcrNVS::init() { return mcrNVS::instance(); }

// STATIC
mcrNVS_t *mcrNVS::instance() {
  if (__singleton__ == nullptr) {
    __singleton__ = new mcrNVS();
  }
  return __singleton__;
}

mcrNVS::~mcrNVS() {
  if (__singleton__) {
    nvs_close(__singleton__->_handle);

    if (__singleton__->_blob != nullptr) {
      free(__singleton__->_blob);
    }

    if (__singleton__->_time_str != nullptr) {
      free(__singleton__->_time_str);
    }

    delete __singleton__;
    __singleton__ = nullptr;
  }
}

// STATIC
esp_err_t mcrNVS::commitMsg(const char *key, const char *msg) {
  return instance()->__commitMsg(key, msg);
}

// PRIVATE
esp_err_t mcrNVS::__commitMsg(const char *key, const char *msg) {
  esp_log_level_set(TAG, ESP_LOG_INFO);

  zeroBuffers();

  if (notOpen()) {
    return _nvs_open_rc;
  }

  _blob->time = time(nullptr);
  strncpy(_blob->msg, msg, MCR_NVS_MSG_MAX_LEN);

  ESP_LOGI(TAG, "attempting nvs_set_blob(%d, %p, %p, %d)", _handle, key, _blob,
           sizeof(mcrNVSMessage_t));

  _esp_rc = nvs_set_blob(_handle, key, _blob, sizeof(mcrNVSMessage_t));

  ESP_LOGI(TAG, "[%s] nvs_set_blob(%d, %p, %p, %d)", esp_err_to_name(_esp_rc),
           _handle, key, _blob, sizeof(mcrNVSMessage_t));

  if (_esp_rc == ESP_OK) {
    _esp_rc = nvs_commit(_handle);
  }

  return _esp_rc;
}

// STATIC
esp_err_t mcrNVS::processCommittedMsgs() {
  return instance()->__processCommittedMsgs();
}

esp_err_t mcrNVS::__processCommittedMsgs() {
  bool need_commit = false;

  zeroBuffers();

  ESP_LOGD(TAG, "entered processCommittedMsgs()");

  if (notOpen()) {
    return _nvs_open_rc;
  }

  for (uint8_t i = 0; strncmp(_possible_keys[i], "END_KEYS", 15) != 0; i++) {
    _msg_len = sizeof(mcrNVSMessage_t);

    ESP_LOGD(TAG, "looking for key(%s)", _possible_keys[i]);
    _esp_rc = nvs_get_blob(_handle, _possible_keys[i], _blob, &_msg_len);

    switch (_esp_rc) {
    case ESP_OK:
      ESP_LOGI(TAG, "found key(%s) time(%lld) msg(%s)", _possible_keys[i],
               (long long)_blob->time, _blob->msg);
      nvs_erase_key(_handle, _possible_keys[i]);
      need_commit = true;
      break;

    case ESP_ERR_NVS_NOT_FOUND:
      ESP_LOGD(TAG, "key(%s) not available", _possible_keys[i]);
      break;

    default:
      ESP_LOGW(TAG, "[%s] while searching for key(%s)",
               esp_err_to_name(_esp_rc), _possible_keys[i]);
    }
  }

  if (need_commit) {
    _esp_rc = nvs_commit(_handle);
  }

  return _esp_rc;
}

bool mcrNVS::notOpen() {
  if (_nvs_open_rc == ESP_OK) {
    return false;
  } else {
    ESP_LOGW(TAG, "[%s] nvs not open", esp_err_to_name(_nvs_open_rc));
    return true;
  }
}

void mcrNVS::zeroBuffers() {
  if (_blob != nullptr)
    bzero(_blob, sizeof(mcrNVSMessage_t));

  if (_time_str != nullptr)
    bzero(_time_str, _time_str_max_len);
}
