/*
    id.hpp - Master Control Remote Device ID
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

#ifndef dev_id_hpp
#define dev_id_hpp

#include <string>
#include <tuple>
#include <utility>

#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <sys/time.h>
#include <time.h>

typedef class mcrDevID mcrDevID_t;

class mcrDevID {
private:
  std::string _id;

public:
  mcrDevID(){};
  mcrDevID(const mcrDevID &obj) {
    ESP_LOGD("mcrDevID", "%s _id(%p) = obj(%p)._id(%p)%s", __PRETTY_FUNCTION__,
             (void *)&_id, (void *)&obj, (void *)&(obj._id), obj._id.c_str());
    _id = obj._id;
  };
  mcrDevID(const char *id) {
    ESP_LOGD("mcrDevID", "%s _id(%p)=id(%p)%s", __PRETTY_FUNCTION__,
             (void *)&_id, (void *)&id, id);
    _id = id;
  };
  mcrDevID(const std::string &id) {
    ESP_LOGD("mcrDevID", "%s _id(%p)=id(%p)%s", __PRETTY_FUNCTION__,
             (void *)&_id, (void *)&id, id.c_str());
    _id = id;
  };

  // support type casting from mcrDevID_t to a plain ole char array
  inline operator const char *() const { return _id.c_str(); };
  inline operator const std::string() { return _id; }

  mcrDevID &operator=(const mcrDevID &other) // copy assignment
  {
    if (this != &other) { // self-assignment check expected
      _id = other._id;
    }
    return *this;
  }

  // mcrDevID &operator=(mcrDevID &&other) noexcept // move assignment
  // {
  //   // no-op on self-move-assignment (delete[]/size=0 also ok)
  //   if (this != &other) {
  //     _id = other._id;
  //     other._id = std::string(); // leave moved-from in valid state
  //   }
  //   return *this;
  // }

  // copy/move constructor is called to construct arg
  // mcrDevID &operator=(mcrDevID arg) noexcept {
  //   std::string c = arg._id;
  //   arg._id = _id;
  //   _id = c;
  //
  //   return *this;
  // } // destructor of arg is called to release the resources formerly held by
  // *this

  // NOTE:  the == ooperator will compare the actual id and not the pointers
  inline bool operator==(const mcrDevID_t &rhs) const {
    bool rc = _id == rhs._id;

    ESP_LOGD("mcrDevID", "%s %s == %s", ((rc) ? "TRUE" : "FALSE"), _id.c_str(),
             rhs._id.c_str());

    return rc;
  };

  // allow comparsions of a mcrDevID to a plain ole char string array
  bool operator==(const char *rhs) const {
    std::string rhs_str(rhs);
    bool rc = _id == rhs_str;

    ESP_LOGD("mcrDevID", "%s %s == %s", ((rc) ? "TRUE" : "FALSE"), _id.c_str(),
             rhs_str.c_str());

    return rc;
  };

  // bool operator==(const mcrDevID &rhs) {
  //   bool rc = _id == rhs._id;
  //
  //   ESP_LOGI("mcrDevID", "rc=%d when comparing %s to %s", rc, _id.c_str(),
  //            rhs._id.c_str());
  //
  //   return rc;
  // }

  inline bool operator<(const mcrDevID_t &dev_id) const {
    bool rc = dev_id._id < _id;

    ESP_LOGD("mcrDevID", "%s %s < %s", ((rc) ? "TRUE" : "FALSE"),
             dev_id._id.c_str(), _id.c_str());
    return rc;
  }

  // copy constructor
  // mcrDevID_t &operator=(mcrDevID_t dev_id);
  // mcrDevID_t &operator=(const char *id);

  bool valid() { return !(_id.empty()); }

  bool matchPrefix(const std::string &prefix);

  const char *asString() { return _id.c_str(); }
  const std::string debug();
};

#endif // mcrDev_h
