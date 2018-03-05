#!/bin/zsh

source ${HOME}/.zshrc

typeset -A parsed_opts
zparseopts -D -- database+:=parsed_opts -database+:=parsed_opts

database=${(v)parsed_opts}

[ -n $database ] || { echo "usage: $0 --database <new database>" 1>&2; exit 1; } 

influx <<COMMAND_SCRIPT
DROP DATABASE $database ;
CREATE DATABASE $database WITH DURATION 52w REPLICATION 1 SHARD DURATION 7d NAME one_year;
SHOW DATABASES;
SHOW RETENTION POLICIES ON $database;
COMMAND_SCRIPT
