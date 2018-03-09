#!/bin/zsh

git fetch --tags
git diff --raw --name-only develop origin/develop
