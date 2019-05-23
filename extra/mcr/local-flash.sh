#!/usr/bin/env zsh

make -j12 || exit 1 

ttys=(/dev/tty.SLAB*)

pushd ${HOME}/devel/janice/mcr_esp

for tty in $ttys; do
	export ESPPORT=$tty
	make -j6 flash || exit 1
	make monitor
done

popd
