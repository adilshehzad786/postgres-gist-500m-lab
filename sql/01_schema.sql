\timing on
SELECT version();

-- Tutorial Step 1: locations table (point geometry)
DROP TABLE IF EXISTS locations;
CREATE TABLE locations (
    location_id  BIGSERIAL PRIMARY KEY,
    name         TEXT,
    geolocation  POINT          -- (x, y) = (longitude, latitude)
);
