/*
    version.h - Master Control Remote Version
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

#ifndef _mcr_version_h
#define _mcr_version_h

// below defines are used to stringify the value passed in as a define from
// the compiler cmd line
#define GIT_VERSION(s) (const char *)AS_STRING(s)
#define MCR_VERSION(s) (const char *)AS_STRING(s)
#define AS_STRING(s) #s

static const char novsn[] = "0000000";

class mcrVersion {
private:
public:
  mcrVersion(){};
  static const char *git() {
#ifdef GIT_REV
    return GIT_VERSION(GIT_REV); // GIT_REV is set on compiler cmd line
#else
    return novsn;
#endif
  }

  static const char *mcr_stable() {
#ifdef MCR_REV
    return MCR_VERSION(MCR_REV); // MCR_REV is set on compiler cmd line
#else
    return novsn;
#endif
  }

  static const char *env() {
#ifdef PROD_BUILD
    return (const char *)"prod";
#else
    return (const char *)"non-prod";
#endif
  }

  static bool prod() {
#ifdef PROD_BUILD
    return (const bool)true;
#else
    return (const bool)false;
#endif
  }
};

#endif // version_h
