#!/bin/bash
# Run from the repo root: bash tools/cppcheck/run_cppcheck.sh

set -e
cd "$(dirname "$0")/../../ONRL"

# Run cppcheck on the source directory.
# --enable=all   enables all checks: style, performance, portability, etc.
# --inconclusive reports issues that are not 100% certain
# --quiet        only shows warnings/errors, suppresses progress output
# 2>             redirects stderr (where cppcheck writes its output) to the log file
cppcheck --enable=all --inconclusive --quiet src/ 2>../tools/cppcheck/cppcheck.log

echo "Done. Results written to tools/cppcheck/cppcheck.log"
