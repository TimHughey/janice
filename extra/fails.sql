SELECT
  EXTRACT(DAY FROM st.inserted_at) AS DAY,
  s.name AS NAME,
  COUNT(st.id) AS FAILS
FROM
  sensor_temperature st
LEFT JOIN sensor s ON s.id = st.sensor_id
WHERE
  st.tc = 85 AND
  st.inserted_at >= DATE_TRUNC('day', now())
GROUP BY
  s.name, DAY
ORDER BY
  DAY, FAILS desc;
