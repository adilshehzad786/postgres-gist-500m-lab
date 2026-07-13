\timing on
-- Tutorial Step 3: ANALYZE after bulk load
ANALYZE locations;

-- Assignment evidence: prove the row count
SELECT count(*) AS total_rows FROM locations;
SELECT pg_size_pretty(pg_total_relation_size('locations')) AS table_plus_pk_size;

-- Tutorial Step 4: baseline bounding-box query (NYC), NO spatial index yet
EXPLAIN ANALYZE
SELECT *
FROM locations
WHERE geolocation <@ box '((-74.1,40.6),(-73.7,40.9))';
