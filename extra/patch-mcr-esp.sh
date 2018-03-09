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
run_cmd make app-clean
run_cmd make -j12

echo "installing to ${priv}"
run_cmd install build/mcr_esp.bin ${priv}

cd ${save_pwd}
