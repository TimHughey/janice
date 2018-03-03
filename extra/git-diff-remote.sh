#!/bin/zsh

git fetch --all
git diff --raw --name-only develop origin/develop
