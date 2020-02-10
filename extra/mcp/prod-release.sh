#!/usr/bin/env zsh

git rev-parse --show-toplevel 1> /dev/null 2> /dev/null
if [[ $? -ne 0 ]]; then
  echo "Must run from project directory"
  exit 1
fi

base=$(git rev-parse --show-toplevel)

source $base/extra/common/vars.sh

cd $janice_extra/mcp

./prod-build.sh && ./prod-install.sh && ./tail-log.sh

cd $save_cwd
