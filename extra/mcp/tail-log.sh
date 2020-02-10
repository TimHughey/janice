#!/usr/bin/env zsh

jan_base=/usr/local/janice
jan_bin=${jan_base}/bin
mcp=${jan_bin}/mcp

print -n "waiting for mcp to start... "

until $mcp pid 1>/dev/null 2>/dev/null; do
  sleep 1
done

print "done."

mcp_pid=$($mcp pid)

print "tailing janice log file. (use CTRL+C to stop)"

exec tail --lines=100 --pid=${mcp_pid} -f $jan_base/tmp/log/erlang.*(om[1])
