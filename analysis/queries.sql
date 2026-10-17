-- 따릉이 공백률 분석 쿼리 (data/ddareungi.duckdb)
-- 공백률 = 자전거 0대 기록 수 / 전체 기록 수, empty_rate 표는 build_metrics.py가 만든다
-- 여러 대여소를 합칠 때는 기록 수(records)로 가중 평균

-- 1. 시간대별 전체 공백률: 평일과 휴일 비교
SELECT day_type, hour,
       ROUND(SUM(empty_rate * records) / SUM(records) * 100, 1) AS empty_pct
FROM empty_rate
GROUP BY day_type, hour
ORDER BY day_type, hour;

-- 2. 평일 출근 시간(7~9시) 공백률 상위 20개 대여소
SELECT e.station_id, s.name, s.gu,
       ROUND(SUM(e.empty_rate * e.records) / SUM(e.records) * 100, 1) AS empty_pct
FROM empty_rate e
JOIN stations s USING (station_id)
WHERE e.day_type = 'weekday' AND e.hour BETWEEN 7 AND 9
GROUP BY e.station_id, s.name, s.gu
HAVING SUM(e.records) >= 300          -- 기록이 적은 대여소 제외
ORDER BY empty_pct DESC
LIMIT 20;

-- 3. 자치구별 평일 출근 시간 공백률
SELECT s.gu,
       COUNT(DISTINCT e.station_id) AS stations,
       ROUND(SUM(e.empty_rate * e.records) / SUM(e.records) * 100, 1) AS empty_pct
FROM empty_rate e
JOIN stations s USING (station_id)
WHERE e.day_type = 'weekday' AND e.hour BETWEEN 7 AND 9
GROUP BY s.gu
ORDER BY empty_pct DESC;

-- 4. 월별 공백률 (계절 차이)
SELECT strftime(a.date, '%Y-%m') AS year_month,
       ROUND(AVG((a.bikes = 0)::INTEGER) * 100, 1) AS empty_pct
FROM availability a
JOIN station_span sp ON sp.station_id = a.station_id AND a.date BETWEEN sp.first_day AND sp.last_day
JOIN station_month m ON m.station_id = a.station_id AND m.month = strftime(a.date, '%Y-%m')
WHERE m.active
GROUP BY year_month
ORDER BY year_month;

-- 5. 평일 8시 공백률 50% 이상 대여소 중 500m 안에 공백률 10% 미만 대여소가 있는 비율
--    거리: 서울 위도(약 37.5도) 기준 경도 1도 약 88.2km, 위도 1도 약 111km로 근사
WITH h8 AS (
    SELECT e.station_id, e.empty_rate, s.lat, s.lon
    FROM empty_rate e JOIN stations s USING (station_id)
    WHERE e.day_type = 'weekday' AND e.hour = 8
),
busy AS (SELECT * FROM h8 WHERE empty_rate >= 0.5),
pairs AS (
    SELECT DISTINCT b.station_id
    FROM busy b JOIN h8 o
      ON o.station_id <> b.station_id AND o.empty_rate < 0.1
     AND ((o.lon - b.lon) * 88200) ** 2 + ((o.lat - b.lat) * 111000) ** 2 <= 500 ** 2
)
SELECT (SELECT COUNT(*) FROM busy)  AS busy_stations,
       (SELECT COUNT(*) FROM pairs) AS with_alternative;

-- 6. 운영 점검 대상: 대여소 정보(25년 12월 기준)에 등록됐지만 2025년 자전거가 있던 날이 10일 미만인 대여소
--    공백률 계산에서는 운영 중단으로 제외, 운영 측에는 재배치·정비 검토 목록 (원인은 이 데이터로 확인 불가)
WITH bd AS (
    SELECT station_id, COUNT(DISTINCT date) FILTER (WHERE bikes > 0) AS bike_days
    FROM availability
    GROUP BY station_id
)
SELECT s.station_id, s.name, s.gu, s.racks, bd.bike_days
FROM stations s
JOIN bd USING (station_id)
WHERE bd.bike_days < 10
ORDER BY bd.bike_days, s.gu, s.name;
