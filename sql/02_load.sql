\timing on
-- Tutorial Step 2, scaled. The tutorial does one INSERT of 10M rows.
-- At 500M a single statement is one huge transaction (WAL spike, no progress
-- feedback, nothing survives an interrupt), so this loads in batches and
-- COMMITs after each one. Same data distribution as the tutorial:
-- longitude [-180,180], latitude [-90,90], name = 'Location_' || n.

CREATE OR REPLACE PROCEDURE load_locations(total bigint, batch bigint)
LANGUAGE plpgsql AS $proc$
DECLARE
  lo   bigint := 1;
  hi   bigint;
  t0   timestamptz;
  secs numeric;
BEGIN
  WHILE lo <= total LOOP
    hi := least(lo + batch - 1, total);
    t0 := clock_timestamp();

    INSERT INTO locations (name, geolocation)
    SELECT
      'Location_' || g,
      POINT( -180 + random()*360,     -- lon
             -90  + random()*180 )    -- lat
    FROM generate_series(lo, hi) AS g;

    secs := extract(epoch from clock_timestamp() - t0);
    RAISE NOTICE '[%] loaded % / % rows  (batch: %s, ~% rows/s)',
      to_char(clock_timestamp(),'HH24:MI:SS'),
      hi, total,
      round(secs, 1),
      round((hi - lo + 1) / greatest(secs, 0.001))::bigint;

    COMMIT;
    lo := hi + 1;
  END LOOP;
END
$proc$;

CALL load_locations(:scale, :batch);
