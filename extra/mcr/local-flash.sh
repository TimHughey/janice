#!/usr/bin/env zsh

ttys=(/dev/tty.SLAB*)

pushd ${HOME}/devel/janice/mcr_esp

for tty in $ttys; do
	export ESPPORT=$tty
	make -j6 flash || exit 1
	make monitor
done

popd
