select EXTRACT(DAY FROM st.inserted_at) as DAY, s.name as NAME, count(st.id) as FAILS
from sensor_temperature st
LEFT JOIN sensor s ON s.id = st.sensor_id
where st.tc = 85 and st.inserted_at >= '2018-06-27'
group by s.name, DAY order by DAY, FAILS desc;
