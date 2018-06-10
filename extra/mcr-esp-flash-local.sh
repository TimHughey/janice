#!/bin/zsh

source ${HOME}/.zshrc

ttys=(/dev/tty.SLAB*)

cd ${HOME}/devel/janice/mcr_esp
git pull --tags

for tty in $ttys; do
	env ESPPORT=${tty} make -j6 erase_flash || exit 1
	env ESPPORT=${tty} make -j6 flash || exit 1
done
