\timing on
-- Tutorial Step 6: bounding box again, now indexed
EXPLAIN ANALYZE
SELECT *
FROM locations
WHERE geolocation <@ box '((-74.1,40.6),(-73.7,40.9))';

-- Tutorial Step 7: radius search (Times Square, 0.02 degrees)
EXPLAIN ANALYZE
SELECT *
FROM locations
WHERE geolocation <@ circle '((-73.9855,40.7580), 0.02)';

-- Tutorial Step 8: K-NN nearest-neighbor, top 100
EXPLAIN ANALYZE
SELECT location_id, name, geolocation
FROM locations
ORDER BY geolocation <-> POINT(-73.9855, 40.7580)
LIMIT 100;

-- Tutorial Step 9: polygon containment (midtown Manhattan)
EXPLAIN ANALYZE
SELECT count(*)
FROM locations
WHERE geolocation <@ polygon '((-74.02,40.70),(-73.94,40.70),(-73.94,40.80),(-74.02,40.80))';

-- Tutorial Step 10: is the index being used?
SELECT indexrelid::regclass AS index_name,
       idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE relid = 'locations'::regclass
ORDER BY idx_scan DESC;

-- Tutorial Step 10: table vs index sizes
SELECT
  pg_size_pretty(pg_relation_size('locations'))        AS table_only,
  pg_size_pretty(pg_indexes_size('locations'))         AS indexes_only,
  pg_size_pretty(pg_total_relation_size('locations'))  AS total_with_indexes;

SELECT
  indexrelid::regclass AS index_name,
  pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_index
WHERE indrelid = 'locations'::regclass
ORDER BY pg_relation_size(indexrelid) DESC;
