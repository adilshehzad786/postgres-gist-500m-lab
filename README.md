# Week 3 — 500M-point GiST lab (PostgreSQL 17 + pgAdmin in Docker)

Reproduces the jramcloud1 GiST tutorial at 500M rows and extends it with a
quadtree (SP-GiST) and a geohash-style grid B-tree comparison.

**Please make sure you have 120 GB free storage also using a high CPU compute.**

## Prerequisites

- Docker Desktop running (WSL2 backend on Windows)
- **~120 GB free** on the drive that backs Docker's storage.
  Rough footprint at 500M: table ~36 GB, primary key ~11 GB, GiST ~32 GB,
  WAL up to 16 GB. Check with `docker system df` / free space on C:.
- Give the Docker VM at least 16 GB RAM (Docker Desktop → Settings → Resources).
- ~1.5–2.5 hours wall time. Almost all of it is waiting.

## Run it

```bash
cd gist-500m-lab
docker compose up -d            # postgres:17 + pgadmin
docker compose ps               # both healthy? screenshot this
./run_all.sh                    # full 500M pipeline, evidence lands in results/
```

Smaller shakedown first if you want to sanity-check the pipeline (~5 min):

```bash
SCALE=10000000 BATCH=5000000 ./run_all.sh
```

Then re-run at full scale (the schema step drops and recreates the table).

Optional extension run (quadtree + geohash comparison). Heads-up: SP-GiST has
no fast sorted build, so at 500M this can add 1.5–3 hours by itself:

```bash
RUN_EXTENSION=1 ./run_all.sh    # or run sql/06_extension.sql on its own later
```

## Rough step timings at 500M (i9 laptop, NVMe, 32 GB)

| Step | Expect |
|---|---|
| 02 load (20 × 25M batches) | 10–20 min |
| 03 ANALYZE + baseline seq scan | 2–4 min (the scan itself: tens of seconds) |
| 04 GiST build | 15–30 min |
| 05 indexed queries | milliseconds each |
| 06 extension (optional) | 1.5–3 h, dominated by the SP-GiST build |

## pgAdmin

- http://localhost:5050 — login `admin@lab.local` / `admin`
- Add server: host `postgres`, port `5432`, user/pass `postgres`, db `nearby`

## Screenshot checklist (these become the PDF snapshots)

1. `docker compose ps` or Docker Desktop showing `pg17-gist-lab` + `pgadmin-gist-lab`
2. pgAdmin Query Tool: `SELECT count(*) FROM locations;` → 500,000,000
3. Before-GiST box query plan — Parallel Seq Scan, execution time in seconds
   (from `results/03_before_gist.txt`, or re-run the EXPLAIN ANALYZE in pgAdmin)
4. `CREATE INDEX ... USING gist` timing line from `results/04_build_gist.txt`
5. After-GiST box query plan — Bitmap Index Scan, tens of ms
6. K-NN plan — Index Scan with `Order By: geolocation <-> point`, low ms
7. The three size/stat query outputs from step 10

Note: if you re-run a query inside pgAdmin for a prettier screenshot, the
number will differ a bit from `results/*.txt` (warm cache, GUI overhead).
That's normal — say so in the PDF instead of hiding it.


