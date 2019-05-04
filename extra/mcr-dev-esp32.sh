#!/usr/bin/env zsh

mcr_base=${HOME}/devel/janice/mcr_esp

export ESPPORT=/dev/ttyUSB1

pushd $mcr_base

git pull
make flash && make monitor

popd
