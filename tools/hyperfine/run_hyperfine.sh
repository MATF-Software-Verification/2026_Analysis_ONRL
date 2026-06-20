#!/bin/bash
# Run from the repo root: bash tools/hyperfine/run_hyperfine.sh
# Requires ONRL to be built at least once first (see README build instructions).

set -e

# Benchmark the ONRL build time.
# ONRL is an interactive game that never exits on its own, so benchmarking
# the executable directly is not feasible. Build time is a meaningful
# alternative that measures how long the compiler takes to process the project.
#
# --warmup 1       runs the command once before measuring to warm up disk cache
# --runs 5         number of timed runs to average over
# --export-json    saves the full results (mean, stddev, min, max per run) to a JSON file
hyperfine --warmup 1 --runs 5 \
    'cd ONRL && cmake --build build --clean-first 2>/dev/null' \
    --export-json tools/hyperfine/hyperfine.json \
    2>&1 | tee tools/hyperfine/hyperfine.log

echo "Done. Results written to tools/hyperfine/hyperfine.log and tools/hyperfine/hyperfine.json"
