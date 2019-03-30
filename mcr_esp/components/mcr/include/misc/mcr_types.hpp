/*
    engine.hpp - Master Control Remote Dallas Semiconductor
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

#ifndef mcr_type_hpp
#define mcr_type_hpp

#include <string>
#include <vector>

#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <freertos/task.h>
#include <sdkconfig.h>

typedef struct {
  TaskHandle_t handle;
  void *data;
  TickType_t lastWake;
  UBaseType_t priority;
  UBaseType_t stackSize;
} mcrTask_t;

typedef std::string mcrRefID_t;

typedef struct {
  char id[16];
  char prefix[5];
  QueueHandle_t q;
} cmdQueue_t;

typedef enum mcrHardwareConfig {
  LEGACY = 0x00,
  BASIC,
  I2C_MULTIPLEXER
} mcrHardwareConfig_t;

typedef std::vector<char> mcrRawMsg_t;

#endif // mcr_type_h
