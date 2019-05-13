#!/usr/bin/env zsh

mcr_base=${HOME}/devel/janice/mcr_esp

export ESPPORT=/dev/ttyUSB1

pushd $mcr_base

MAKEOPTS=$(portageq envvar MAKEOPTS)

git pull
make ${MAKEOPTS} flash && make monitor

popd
