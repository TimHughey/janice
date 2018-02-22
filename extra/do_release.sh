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

BASE=${HOME}/devel/mercurial
EXTRA=$BASE/extra

cd $BASE

rum_cmd git pull --tags
run_cmd git pull --all
run_cmd $EXTRA/prod-release
run_cmd $EXTRA/install-and-start --clean
