#
# Main component makefile.
#
# This Makefile can be left empty. By default, it will take the sources in the
# src/ directory, compile them and link them into lib(subdirectory_name).a
# in the build directory. This behaviour is entirely configurable,
# please read the ESP-IDF documents if you need to do this.

git_rev := $(shell git rev-parse --short HEAD)

COMPONENT_ADD_INCLUDEDIRS := . include ../components
COMPONENT_SRCDIRS := . src/cmds src/devs src/misc src/drivers src/readings src/protocols src/libs src/engines

CPPFLAGS += -DMG_LOCALS -DARDUINOJSON_ENABLE_STD_STREAM -DGIT_REV=$(git_rev)
CFLAGS += -DMG_LOCALS
CXXFLAGS += -DMG_LOCALS

## Uncomment the following line to enable exception handling
CXXFLAGS+= -fexceptions
CXXFLAGS+= -std=c++17
