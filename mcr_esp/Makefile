#
# This is a project Makefile. It is assumed the directory this Makefile resides in is a
# project subdirectory.
#

PROJECT_NAME := mcr_esp
OS = $(shell uname)
PREV_SUFFIX := ".prev"
MCP_PRIV = $(PROJECT_PATH)/../mcp/priv
FIRMWARE = $(MCP_PRIV)/$(PROJECT_NAME).bin

ifeq ($(OS),Darwin)
  INSTALL_OPTS = -B $(PREV_SUFFIX) -b
endif

ifeq ($(OS),Linux)
  INSTALL_OPTS = --suffix=$(PREV_SUFFIX) 
endif

include $(IDF_PATH)/make/project.mk

MCP_PRIV = ../mcp/priv
MCR_BIN_FILE = $(APP_BIN) 

.PHONY : deploy-to-mcp
deploy-to-mcp : $(APP_BIN)
	install $(INSTALL_OPTS) $(MCR_BIN_FILE) $(MCP_PRIV)
	$(info installed $(APP_BIN) with opts $(INSTALL_OPTS) to $(MCP_PRIV)) 
