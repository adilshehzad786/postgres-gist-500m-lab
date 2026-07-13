\timing on
-- Tutorial Step 5: GiST index on geolocation
CREATE INDEX idx_locations_gist ON locations USING gist (geolocation);

-- Tutorial: ANALYZE after creating the index
ANALYZE locations;
