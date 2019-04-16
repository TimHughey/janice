#
# Main component makefile.
#
# This Makefile can be left empty. By default, it will take the sources in the
# src/ directory, compile them and link them into lib(subdirectory_name).a
# in the build directory. This behaviour is entirely configurable,
# please read the ESP-IDF documents if you need to do this.

git_head_sha := $(shell git rev-parse --short HEAD)
mcr_stable_sha := $(shell git rev-parse --short mcr-stable)

COMPONENT_EMBED_TXTFILES := ca.pem
COMPONENT_ADD_INCLUDEDIRS := . include include/external ../components
COMPONENT_SRCDIRS := . src/cmds src/devs src/net src/misc src/drivers src/readings src/protocols src/libs src/engines

CPPFLAGS += -DMG_LOCALS \
  -DARDUINOJSON_ENABLE_STD_STREAM \
	-DARDUINOJSON_USE_LONG_LONG \
	-D_MCR_HEAD_SHA=$(git_head_sha) \
	-D_MCR_STABLE_SHA=$(mcr_stable_sha)

CFLAGS += -DMG_LOCALS
CXXFLAGS += -DMG_LOCALS

## Uncomment the following line to enable exception handling
CXXFLAGS+= -fexceptions
CXXFLAGS+= -std=c++17
