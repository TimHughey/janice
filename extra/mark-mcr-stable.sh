#!/bin/zsh

source ${HOME}/.zshrc
cd ${HOME}/devel/janice

git tag --force mcr-stable
git push --tags --force
