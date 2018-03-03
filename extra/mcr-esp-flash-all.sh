#!/bin/zsh


cd ${HOME}/devel/janice && git pull


ssh loki "cd ${HOME}/devel/janice && git pull && ./extra/mcr-esp-flash-local.sh"
ssh odin "cd ${HOME}/devel/janice && git pull && ./extra/mcr-esp-flash-local.sh"
./extra/mcr-esp-flash-local
