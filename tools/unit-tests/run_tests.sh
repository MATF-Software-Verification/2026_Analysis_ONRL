#!/bin/bash
# Run from the repo root: bash tools/unit-tests/run_tests.sh

set -e
cd "$(dirname "$0")"

# Compile the test binary with coverage instrumentation.
# --coverage enables both -fprofile-arcs (generate .gcda at runtime)
# and -ftest-coverage (generate .gcno at compile time).
g++ -std=c++20 --coverage -g \
    test_console.cpp \
    test_util.cpp \
    ../../ONRL/src/console.cpp \
    ../../ONRL/src/util.cpp \
    -o runTests \
    -lgtest -lgtest_main -lpthread \
    -lsfml-graphics -lsfml-window -lsfml-system

# Run the tests (also writes .gcda coverage data files).
./runTests

# Collect coverage data from the .gcda files into a single .info file.
# --ignore-errors mismatch is needed for lcov 2.x which is stricter
# about line number mismatches in gcov data.
lcov --capture --directory . --output-file coverage.info --ignore-errors mismatch

# Generate an HTML report from the .info file.
genhtml coverage.info --output-directory coverage_report
