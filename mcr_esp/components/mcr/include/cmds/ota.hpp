/*
    ota.hpp - Master Control Command OTA Class
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

#ifndef mcr_cmd_ota_h
#define mcr_cmd_ota_h

#include <esp_http_client.h>
#include <esp_https_ota.h>
#include <esp_ota_ops.h>
#include <esp_partition.h>
#include <esp_spi_flash.h>

#include "cmds/base.hpp"

using std::unique_ptr;

namespace mcr {

typedef class mcrCmdOTA mcrCmdOTA_t;
class mcrCmdOTA : public mcrCmd {
private:
  rawMsg_t *_raw = nullptr;
  string_t _head;
  string_t _stable;
  string_t _partition;
  string_t _fw_url;
  int _delay_ms = 0;
  int _start_delay_ms = 0;
  int _reboot_delay_ms = 0;

  void doUpdate();

  static esp_err_t httpEventHandler(esp_http_client_event_t *evt);

public:
  mcrCmdOTA(JsonDocument &doc, elapsedMicros &parse);
  ~mcrCmdOTA(){};

  static void markPartitionValid();

  bool process();
  uint32_t reboot_delay_ms() { return _reboot_delay_ms; };
  size_t size() const { return sizeof(mcrCmdOTA_t); };

  const unique_ptr<char[]> debug();
};

} // namespace mcr

#endif
