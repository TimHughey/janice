/*
    cmd_base.hpp - Master Control Command Queues Class
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

#ifndef mcr_cmd_queues_h
#define mcr_cmd_queues_h

#include <cstdlib>
#include <memory>
#include <string>

#include <esp_log.h>
#include <esp_timer.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <sys/time.h>
#include <time.h>

#include "misc/mcr_types.hpp"

using std::unique_ptr;

typedef class mcrCmdQueues mcrCmdQueues_t;
class mcrCmdQueues {
private:
  std::vector<cmdQueue_t> _queues;

  mcrCmdQueues(){}; // SINGLETON!

public:
  void add(cmdQueue_t &cmd_q) { _queues.push_back(cmd_q); };
  static std::vector<cmdQueue_t> &all() { return instance()->queues(); };
  static mcrCmdQueues_t *instance();
  std::vector<cmdQueue_t> &queues() { return _queues; };
  static void registerQ(cmdQueue_t &cmd_q);

  const unique_ptr<char[]> debug();
};

#endif
