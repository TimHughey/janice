SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
  WHERE pg_stat_activity.datname = 'merc_test'  AND pid <> pg_backend_pid();
