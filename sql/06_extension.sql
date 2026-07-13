\timing on
-- ============================================================================
-- EXTENSION beyond the tutorial: same workload, two alternative structures.
--
--   A) SP-GiST  = the quadtree from class, built into PostgreSQL
--   B) B-tree on a fixed lat/lon grid = the geohash idea without PostGIS
--      (truncating a geohash IS bucketing points into fixed cells; a 2-column
--       integer grid key is the same mechanism, minus base32 encoding)
--
-- Disk-safe sequencing: only one big spatial index exists at a time.
-- ============================================================================

-- ---------- A) Quadtree via SP-GiST ----------
DROP INDEX IF EXISTS idx_locations_gist;

CREATE INDEX idx_locations_spgist ON locations USING spgist (geolocation);
ANALYZE locations;

-- same bounding box as the tutorial
EXPLAIN ANALYZE
SELECT * FROM locations
WHERE geolocation <@ box '((-74.1,40.6),(-73.7,40.9))';

-- same K-NN as the tutorial
EXPLAIN ANALYZE
SELECT location_id, name, geolocation
FROM locations
ORDER BY geolocation <-> POINT(-73.9855, 40.7580)
LIMIT 100;

SELECT pg_size_pretty(pg_relation_size('idx_locations_spgist')) AS spgist_size;

DROP INDEX idx_locations_spgist;

-- ---------- B) Geohash-style fixed grid on a plain B-tree ----------
-- 0.02-degree cells (~2.2 km of latitude), same scale as the tutorial's circle.
CREATE INDEX idx_locations_grid ON locations (
  (floor((geolocation[1] +  90) / 0.02)::int),   -- lat cell
  (floor((geolocation[0] + 180) / 0.02)::int)    -- lon cell
);
ANALYZE locations;

-- "Nearby Times Square" the geohash way:
--   1) candidate cells = the point's cell plus its 8 neighbors
--      (a query point near a cell edge would otherwise miss true neighbors --
--       this is the geohash boundary problem from class)
--   2) exact distance sort on the candidates only
EXPLAIN ANALYZE
SELECT location_id, name, geolocation
FROM locations
WHERE floor((geolocation[1] +  90) / 0.02)::int
      BETWEEN floor((40.7580 +  90) / 0.02)::int - 1
          AND floor((40.7580 +  90) / 0.02)::int + 1
  AND floor((geolocation[0] + 180) / 0.02)::int
      BETWEEN floor((-73.9855 + 180) / 0.02)::int - 1
          AND floor((-73.9855 + 180) / 0.02)::int + 1
ORDER BY geolocation <-> POINT(-73.9855, 40.7580)
LIMIT 100;

SELECT pg_size_pretty(pg_relation_size('idx_locations_grid')) AS grid_btree_size;

DROP INDEX idx_locations_grid;

-- ---------- restore the tutorial's final state ----------
CREATE INDEX idx_locations_gist ON locations USING gist (geolocation);
ANALYZE locations;
