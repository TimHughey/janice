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

#include <FreeRTOS.h>
#include <System.h>
#include <sys/time.h>
#include <time.h>

typedef class mcrDevID mcrDevID_t;

class mcrDevID {
private:
  std::string _id;

public:
  mcrDevID(){};
  mcrDevID(const mcrDevID &obj) { _id = obj._id; };
  mcrDevID(const char *id) { _id = id; };
  mcrDevID(const std::string &id) { _id = id; };

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
  inline bool operator==(mcrDevID_t &rhs) { return (_id == rhs._id); };

  // allow comparsions of a mcrDevID to a plain ole char string array
  bool operator==(char *rhs) {
    std::string rhs_str(rhs);

    return _id == rhs_str;
  };

  inline bool operator<(const mcrDevID_t &dev_id) const {
    return (dev_id._id < _id);
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
