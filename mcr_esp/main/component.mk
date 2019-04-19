#
# "main" pseudo-component makefile.
#
# (Uses default behaviour of compiling all source files in directory, adding 'include' to include path.)


CFLAGS += -std=gnu++11 -E -P -v -dD \
  -DMG_ENABLE_SYNC_RESOLVER -DARDUINOJSON_ENABLE_STD_STREAM -DMG_ENABLE_HTTP=0

CPPFLAGS += -DMG_ENABLE_SYNC_RESOLVER -DMG_ENABLE_HTTP=0
CXXFLAGS += -DMG_ENABLE_SYNC_RESOLVER -DMG_ENABLE_HTTP=0
