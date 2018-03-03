#!/bin/zsh

DB="$1"

psql --host=jophiel --echo-all --file=- ${DB} << EOF
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
  WHERE pg_stat_activity.datname = '${DB}'  AND pid <> pg_backend_pid();
EOF
