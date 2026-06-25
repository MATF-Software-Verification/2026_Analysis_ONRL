#!/bin/bash
# Run from the repo root: bash tools/clang-tidy/run_clang_tidy.sh

set -e
cd "$(dirname "$0")/../../ONRL"

# Run clang-tidy on all .cpp files in src/.
# -checks=...   selects which check categories to enable:
#   bugprone-*             catches likely bugs (e.g. easily swappable parameters)
#   performance-*          catches performance issues (e.g. pass by value instead of reference)
#   modernize-*            suggests modern C++ idioms (e.g. trailing return types)
#   readability-*          catches readability issues (naming, braces, magic numbers, ...)
#   cppcoreguidelines-*    enforces C++ Core Guidelines
#   -cppcoreguidelines-avoid-magic-numbers  disabled because it overlaps with readability-magic-numbers
# -- -I./src    passes -I./src to the underlying compiler so it can find local headers
# 2>&1          merges stderr into stdout so both go into the log
# tee           writes to the log file and also prints to the terminal
clang-tidy src/*.cpp \
    -checks='bugprone-*,performance-*,modernize-*,readability-*,cppcoreguidelines-*,-cppcoreguidelines-avoid-magic-numbers' \
    -- -I./src \
    2>&1 | tee ../tools/clang-tidy/clang-tidy.log

echo "Done. Results written to tools/clang-tidy/clang-tidy.log"
