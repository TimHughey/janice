#!/bin/zsh

SAVE=`pwd`

function run_cmd {
    "$@"
    local rc=$?
    if [ $rc -ne 0 ]; then
        echo "error with $1" >&2
				cd $SAVE
				exit 1
    fi
    return $rc
}

BASE=${HOME}/devel/janice
MCP=${BASE}/mcp
MCR=${BASE}/mcr_esp

[[ ! -x $BASE ]] && exit 1

rm -f $BASE/erl_crash.dump

cd $MCP
[[ ! -f $MCP/mix.exs ]] && exit 1
run_cmd mix clean --only=prod
run_cmd env MIX_ENV=prod mix deps.get
run_cmd env MIX_ENV=prod mix deps.clean --unused
run_cmd env MIX_ENV=prod mix compile

cd $MCP/assets
run_cmd brunch build --production

cd $MCP
run_cmd env MIX_ENV=prod mix phx.digest

cd $MCR
touch components/mcr/include/misc/version.hpp
run_cmd make -j12 deploy

cd $MCP
run_cmd env MIX_ENV=prod mix release --env=prod

release=($HOME/devel/janice/mcp/_build/prod/rel/mcp/releases/0.*(om[1]))

PKG="mcp.tar.gz"
STAGE=/run/janice
if [[ -e $release && -d $STAGE ]]; then
	cp $release/$PKG $STAGE

	if [[ -f $STAGE/$PKG ]]; then
		echo "build complete, release staged in $STAGE"
	fi
fi

cd $SAVE
