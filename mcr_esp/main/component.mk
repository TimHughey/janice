#
# "main" pseudo-component makefile.
#
# (Uses default behaviour of compiling all source files in directory, adding 'include' to include path.)
git_rev := $(shell git rev-parse --short HEAD)

CFLAGS += -std=gnu++11 -E -P -v -dD \
  -DMG_ENABLE_SYNC_RESOLVER -DARDUINOJSON_ENABLE_STD_STREAM

CPPFLAGS += -DMG_ENABLE_SYNC_RESOLVER -DGIT_REV=$(git_rev)
CXXFLAGS += -DMG_ENABLE_SYNC_RESOLVER -DGIT_REV=$(git_rev)
