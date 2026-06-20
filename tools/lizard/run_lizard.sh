#!/bin/bash
# Run from the repo root: bash tools/lizard/run_lizard.sh

set -e

# Run lizard on the ONRL source directory.
# Lizard measures cyclomatic complexity (CCN) for each function.
# By default it warns on CCN > 15, function length > 1000 lines, or > 100 parameters.
python3 -m lizard ONRL/src/ 2>&1 | tee tools/lizard/lizard.log

echo "Done. Results written to tools/lizard/lizard.log"
