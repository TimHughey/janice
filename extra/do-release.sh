#!/bin/zsh

function run_cmd {
    "$@"
    local rc=$?
    if [ $rc -ne 0 ]; then
        echo "error with $1" >&2
				exit 1
    fi
    return $rc
}

BASE=${HOME}/devel/janice
EXTRA=$BASE/extra

cd $BASE

run_cmd git pull --tags
run_cmd git pull --all
run_cmd $EXTRA/prod-release.sh
run_cmd $EXTRA/install-and-start.sh --clean
