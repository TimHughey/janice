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
#define MCR_EMBED_VSN_SHA(a, b)                                                \
  (const char *)"mcr_sha_head=" AS_STRING(a) " mcr_sha_stable=" AS_STRING(b)
#define MCR_HEAD_SHA(s) (const char *)AS_STRING(s)
#define MCR_STABLE_SHA(s) (const char *)AS_STRING(s)
#define AS_STRING(s) #s

static const char novsn[] = "0000000";

class mcrVersion {
private:
public:
  mcrVersion(){};

  static const char *embed_vsn_sha() {
    return MCR_EMBED_VSN_SHA(_MCR_HEAD_SHA, _MCR_STABLE_SHA);
  }

  static const char *git() {
#ifdef _MCR_HEAD_SHA
    // _MCR_HEAD_SHA is set on compiler cmd line
    return MCR_HEAD_SHA(_MCR_HEAD_SHA);
#else
    return novsn;
#endif
  }

  static const char *mcr_stable() {
#ifdef _MCR_STABLE_SHA
    // _MCR_STABLE_SHA is set on compiler cmd line
    return MCR_STABLE_SHA(_MCR_STABLE_SHA);
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
