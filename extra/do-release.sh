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

base=${HOME}/devel/janice
extra=$base/extra
mcp_releases=${base}/mcp/_build/prod/rel/mcp/releases


cd $base
run_cmd git fetch --all
run_cmd git pull --all
run_cmd $extra/prod-release.sh
run_cmd $extra/install-and-start.sh --clean
run_cmd find $mcp_releases -maxdepth 1 -mtime 3 -print
