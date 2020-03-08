/*
    base.hpp - Master Control Command Base Class
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

#ifndef mcr_cmd_base_h
#define mcr_cmd_base_h

#include <cstdlib>
#include <memory>
#include <string>

#include <external/ArduinoJson.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <sys/time.h>
#include <time.h>

#include "cmds/types.hpp"
#include "misc/elapsedMillis.hpp"
#include "misc/mcr_types.hpp"
#include "net/mcr_net.hpp"

using std::string;
using std::unique_ptr;

namespace mcr {

enum CmdMetrics { CREATE = 0, PARSE = 1 };
typedef enum CmdMetrics CmdMetrics_t;

typedef class mcrCmd mcrCmd_t;
typedef unique_ptr<mcrCmd_t> mcrCmd_t_ptr;
class mcrCmd {
private:
  mcrCmdType_t _type;
  time_t _mtime = time(nullptr);
  string_t _host;

  void populate(JsonDocument &doc);
  void populate(JsonDocument &doc, const char *dev_name_key);

protected:
  // the device name as sent from mcp
  string_t _external_dev_id;
  // some devices have a global unique name (e.g. Dallas Semiconductor) while
  // others don't (e.g. i2c).  this string is provided when translation is
  // necessary.
  string_t _internal_dev_id;
  mcrRefID_t _refid;
  // if this commmand should be ack'ed by publishing by a return msg
  bool _ack = true;

  elapsedMicros _parse_elapsed;
  elapsedMicros _create_elapsed;
  elapsedMicros _latency_us;

  virtual void populateInternalDevice(JsonDocument &doc);
  virtual void translateExternalDeviceID(const char *replacement);

public:
  mcrCmd() = delete; // never create a default cmd
  mcrCmd(const mcrCmd_t *cmd);
  // mcrCmd(JsonDocument &doc, elapsedMicros &parse);
  mcrCmd(JsonDocument &doc,     // common case for cmds that
         elapsedMicros &parse); // do not reference a
  // specific device

  mcrCmd(JsonDocument &doc,         // common case for cmds that
         elapsedMicros &parse,      // do reference a
         const char *dev_name_key); // specific device

  virtual ~mcrCmd(){};

  void ack(bool ack) { _ack = ack; }
  bool ack() { return _ack; }
  const string_t &externalDevID() const { return _external_dev_id; };
  const string_t &internalDevID() const { return _internal_dev_id; };
  bool forThisHost() const;

  const string_t &host() const { return _host; };

  bool matchExternalDevID();
  bool IRAM_ATTR matchPrefix(const char *prefix);
  mcrRefID_t &refID() { return _refid; };
  virtual bool IRAM_ATTR sendToQueue(cmdQueue_t &cmd_q, mcrCmd_t *cmd);

  elapsedMicros &createElapsed() { return _create_elapsed; };
  bool recent() { return ((time(nullptr) - _mtime) <= 60) ? true : false; }
  virtual elapsedMicros &latency_us() { return _latency_us; };
  elapsedMicros &parseElapsed() { return _parse_elapsed; };
  virtual bool process() { return false; };

  virtual size_t size() const { return sizeof(mcrCmd_t); };
  mcrCmdType_t type() { return _type; };

  virtual const unique_ptr<char[]> debug();
};
} // namespace mcr

#endif
