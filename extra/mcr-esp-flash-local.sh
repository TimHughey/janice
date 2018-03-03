#!/bin/zsh

source ${HOME}/.zshrc

ttys=(/dev/ttyUSB*)

cd ${HOME}/devel/janice/mcr_esp
git pull --tags
git pull

for tty in $ttys; do
	env ESPPORT=${tty} make -j6 erase_flash || exit 1
	env ESPPORT=${tty} make -j6 flash || exit 1
done
