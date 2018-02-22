#
# This is a project Makefile. It is assumed the directory this Makefile resides in is a
# project subdirectory.
#

PROJECT_NAME := mcr_esp

include $(IDF_PATH)/make/project.mk

#.PHONY: deploy
deploy: all
	install -b build/mcr_esp.bin ../mcp/priv
