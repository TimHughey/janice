#!/usr/bin/env zsh

janice=${HOME}/devel/janice
extra=${janice}/extra
mcr_base=${janice}/mcr_esp
tracker=${extra}/mcr/firmware-size-tracker.txt

pushd $mcr_base

# the first make ensures everything is compiled
idf.py size 1>/dev/null || exit 1

# the second make records the clean output
echo ">>>" >> ${tracker}
git log -1 1>>${tracker}
idf.py size 1>>${tracker}
echo "<<<" >> ${tracker}

popd
