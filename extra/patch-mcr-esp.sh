#!/bin/zsh

save_cwd=$(pwd)
host=$(hostname)

[[ $host -ne "jophiel" ]] && echo "please run only from jophiel" && exit 255

function run_cmd {
    "$@"
    local rc=$?
    if [ $rc -ne 0 ]; then
        echo "error with $1" >&2
				exit 1
    fi
    return $rc
}

base=${HOME}/devel/janice
mcr=${base}/mcr_esp
mcp=(/usr/local/janice/lib/mcp*(om[1]))
priv=${mcp}/priv

cd $base
run_cmd git pull --tags

cd $mcr
echo -n "clean build of mcr_esp..."
run_cmd make app-clean 1>/dev/null
run_cmd make -j9 1>/dev/null
echo " done"

echo -n "installing to ${priv}..."
run_cmd install --suffix=.prev build/mcr_esp.bin ${priv}
echo " done"

cd ${save_pwd}
