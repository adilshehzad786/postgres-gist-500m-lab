#!/usr/bin/env bash
# Week 3 GiST lab runner. Every step's full output lands in results/*.txt
# (queries echoed + EXPLAIN ANALYZE plans + wall-clock stamps) — that's the
# evidence appendix for the PDF.
#
# Usage (from the folder with docker-compose.yml):
#   ./run_all.sh                                  # full 500M assignment run
#   SCALE=25000000 BATCH=5000000 ./run_all.sh     # smaller validation run
#   RUN_EXTENSION=1 ./run_all.sh                  # + quadtree/geohash comparison
#
# Against a non-docker Postgres:
#   PSQL="psql -U postgres -d nearby -v ON_ERROR_STOP=1" SQLDIR=sql ./run_all.sh
set -euo pipefail

SCALE="${SCALE:-500000000}"
BATCH="${BATCH:-25000000}"
RUN_EXTENSION="${RUN_EXTENSION:-0}"
SQLDIR="${SQLDIR:-/sql}"
PSQL="${PSQL:-docker compose exec -T postgres psql -U postgres -d nearby -v ON_ERROR_STOP=1}"

mkdir -p results
stamp() { date '+%Y-%m-%d %H:%M:%S'; }

run() {
  local name="$1"; shift
  local out="results/${name}.txt"
  echo "== ${name} started $(stamp)" | tee "${out}"
  # -e echoes each SQL statement before its output -> self-documenting evidence
  ${PSQL} -e "$@" 2>&1 | tee -a "${out}"
  echo "== ${name} finished $(stamp)" | tee -a "${out}"
  echo
}

echo "scale=${SCALE} batch=${BATCH} extension=${RUN_EXTENSION}"
T0=$(date +%s)

run 01_schema      -f "${SQLDIR}/01_schema.sql"
run 02_load        -v scale="${SCALE}" -v batch="${BATCH}" -f "${SQLDIR}/02_load.sql"
run 03_before_gist -f "${SQLDIR}/03_before_gist.sql"
run 04_build_gist  -f "${SQLDIR}/04_build_gist.sql"
run 05_after_gist  -f "${SQLDIR}/05_after_gist.sql"

if [ "${RUN_EXTENSION}" = "1" ]; then
  run 06_extension -f "${SQLDIR}/06_extension.sql"
fi

echo "All done $(stamp) — total wall time $((($(date +%s)-T0)/60)) min. Evidence in results/"
