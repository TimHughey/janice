#
# "main" pseudo-component makefile.
#
# (Uses default behaviour of compiling all source files in directory, adding 'include' to include path.)
git_head_sha := $(shell git rev-parse --short HEAD)
mcr_stable_sha := $(shell git rev-parse --short mcr_stable)

CFLAGS += -std=gnu++11 -E -P -v -dD \
  -DMG_ENABLE_SYNC_RESOLVER -DARDUINOJSON_ENABLE_STD_STREAM

CPPFLAGS += -DMG_ENABLE_SYNC_RESOLVER -D_MCR_HEAD_SHA=$(git_head_sha) -D_MCR_STABLE_SHA=$(mcr_stable_sha)
CXXFLAGS += -DMG_ENABLE_SYNC_RESOLVER
