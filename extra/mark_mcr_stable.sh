#!/bin/zsh

source ${HOME}/.zshrc
cd ${HOME}/devel/mercurial

git tag --force mcr-stable
git push --tags --force
