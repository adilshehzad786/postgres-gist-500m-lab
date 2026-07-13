# Analysis draft for the PDF (slots marked {{...}} get your 500M numbers)

## What did I learn

The headline number tells most of the story. Before the index, the bounding box
query did a Parallel Seq Scan over every row: {{500M seq scan time}} at 500M.
After `CREATE INDEX ... USING gist`, the same query became a Bitmap Index Scan
at {{500M box time}}. Nothing about the query changed. The access path did.

The part that clicked for me is why the seq scan is unavoidable without the
index. A B-tree can answer "location_id = 123" because integers have a total
order. Points in 2D space do not. You cannot sort coordinates in a way that
keeps nearby points adjacent in one dimension, so the planner has no choice but
to read all 500M rows and test each one against the box. GiST fixes this by
being a tree of bounding boxes instead of a tree of sorted values. If a query
box does not intersect a node's bounding box, the entire subtree is skipped.
That is why box, circle and polygon all hit the same index: they are all
"does this shape intersect these bounding boxes" questions.

K-NN surprised me more than the filters did. `ORDER BY geolocation <-> point
LIMIT 100` did not scan and sort anything. The index walked outward from the
query point and produced rows already in distance order, stopping after 100:
{{500M knn time}}. On a naive plan that is a 500M-row sort. This is the actual
answer to the nearby places problem, not the bounding box.

Operational lessons from doing this at 500M instead of the tutorial's 10M:

- One 500M INSERT is a bad idea. I split the load into 25M batches with a
  COMMIT after each, plus `synchronous_commit=off` and `max_wal_size=16GB`
  for the load window. Total load time: {{500M load time}}.
- The GiST build took {{500M gist build time}}. PostgreSQL has used a sorted
  build for point GiST indexes since v14, which is the only reason this is
  minutes and not hours. SP-GiST has no sorted build and it shows (below).
- `ANALYZE` after the load and after the index build matters. The planner's
  row estimates were garbage until then.
- Small gotcha: `pg_stat_user_indexes` showed idx_scan = 0 right after my
  queries, in the same session. Fresh session showed idx_scan = 4. PostgreSQL
  flushes statistics lazily. Cost me ten confused minutes.
- Disk is the real constraint. Table {{500M table size}}, GiST
  {{500M gist size}}, primary key {{500M pk size}}. The index is roughly the
  same order of magnitude as the data it indexes.

## Geohashing vs spatial indexing

The class covered quadtrees and geohashing for nearby places. The tutorial
covers GiST. I benchmarked all three shapes on the same data to see the
trade-offs instead of taking them on faith. Validation numbers below are from
a 25M-row run (1 vCPU sandbox); relative behavior is what matters.

| | GiST (R-tree) | SP-GiST (quadtree) | B-tree on 0.02 deg grid (geohash idea) |
|---|---|---|---|
| Build time | 68 s | 153 s | 45 s |
| Index size | 1,592 MB | 1,087 MB | 527 MB |
| Box query | 2.5 ms | 4.6 ms | n/a (box maps poorly to cells) |
| Nearby top-100 | 3.8 ms, 100 rows | 5.0 ms, 100 rows | 0.4 ms, **0 rows** |

That last cell is the finding. The grid query is the geohash pattern: compute
the query point's cell, read the cell plus its 8 neighbors (you must, or a
point near a cell edge misses true neighbors), then distance-sort the
candidates. It ran in under half a millisecond and returned nothing, because
at this density nine 0.02 degree cells around Times Square happened to be
empty. I asked for 100 nearest and got 0. GiST and SP-GiST returned exactly
100 every time, because their K-NN walks outward as far as it needs to.

So geohashing is not wrong, it is incomplete. To make the grid correct for
K-NN you have to expand the search ring iteratively until you have K
candidates, which means an unpredictable number of round trips that depends
on local data density. A tree-based spatial index does that expansion
natively, inside one index scan. That is the real difference, and I only
understood it by watching the grid query come back empty.

Where geohashing still wins: it turns a 2D problem into a 1D sortable key,
and that works anywhere a B-tree or a key-value store works. Prefix length =
precision. Points that are near each other share prefixes, which makes
geohash a natural shard key for distributing 500M points across machines,
and it is exactly what Redis GEO does internally. Quadtrees (SP-GiST here)
sit in the middle: adaptive splitting handles skewed real-world data better
than a fixed grid, and the index came out 32 percent smaller than GiST, at
the cost of the slowest build (no sorted build path) and slightly slower
queries.

My conclusion for the nearby places problem: inside PostgreSQL, GiST is the
default answer, and the uniform random data here actually understates its
advantage, since real check-in data is heavily skewed toward cities where
fixed grids degrade. Geohashing earns its place one level up in the system
design, as the partitioning and caching key, not as the index. Also worth
stating: built-in point types measure distance in degrees, not meters. For
production geodesic distance I would use PostGIS geography, same GiST
machinery underneath.
