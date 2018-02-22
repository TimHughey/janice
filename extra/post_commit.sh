#!/bin/zsh

source ${HOME}/.zshrc
cd ${HOME}/devel/mercurial

touch mcr_esp/components/mcr/include/misc/version.hpp
touch mcp/config/config.exs

cd mcr_esp
make -j12 deploy

cd ../mcp
mix compile
