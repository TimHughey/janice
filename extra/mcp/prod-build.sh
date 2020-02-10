#!/usr/bin/env zsh

git rev-parse --show-toplevel 1> /dev/null 2> /dev/null
if [[ $? -ne 0 ]]; then
  echo "Must run from project directory"
  exit 1
fi

base=$(git rev-parse --show-toplevel)

source $base/extra/common/vars.sh

chdir $mcp_base

git pull && env MIX_ENV=prod mix release mcp --overwrite

chdir $save_cwd
