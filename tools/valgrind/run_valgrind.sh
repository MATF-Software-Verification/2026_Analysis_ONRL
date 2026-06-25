#!/bin/bash
# Run from the repo root: bash tools/valgrind/run_valgrind.sh
# Note: requires the ONRL binary to be built first (see README build instructions).

set -e
cd "$(dirname "$0")/../../ONRL"

# Run the ONRL executable under Valgrind to check for memory leaks.
# --leak-check=full      shows details for every individual leak
# --show-leak-kinds=all  reports all categories: definitely lost, indirectly lost,
#                        possibly lost, and still reachable
# --track-origins=yes    shows where uninitialized values originally come from
# &>                     redirects both stdout and stderr to the log file
valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes \
    ./build/ONRL &>../tools/valgrind/valgrind_log.txt

echo "Done. Results written to tools/valgrind/valgrind_log.txt"
