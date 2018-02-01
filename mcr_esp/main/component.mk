#
# "main" pseudo-component makefile.
#
# (Uses default behaviour of compiling all source files in directory, adding 'include' to include path.)
CFLAGS += -std=gnu++11 -E -P -v -dD -DMG_ENABLE_SYNC_RESOLVER

CPPFLAGS += -DMG_ENABLE_SYNC_RESOLVER
CXXFLAGS += -DMG_ENABLE_SYNC_RESOLVER
