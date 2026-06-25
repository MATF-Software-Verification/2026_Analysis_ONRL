# Project Analysis Report — ONRL

**Author:** Bojan Velickovic, 1070/2024  
**Project:** ONRL (One Night RogueLike)  
**Source:** https://github.com/nullspeaker/ONRL, main branch  
**Commit analyzed:** `12efcde267c00f120b9b16ad7800fe117dd44d9c`

---

## 1. Project Overview

ONRL is an incomplete hobby roguelike game written in C++20 using the SFML multimedia library for graphics and window management. The project was developed over a single weekend and then abandoned. Despite being unfinished, the core functionality is working: the game renders a procedurally generated cave map using Binary Space Partitioning (BSP) and cellular automata, supports player movement, and simulates enemy AI. Missing features include combat, items, and a UI.

The codebase consists of 10 source files across approximately 700 non-comment lines of code:

| File | Purpose |
|---|---|
| `main.cpp` | Game loop, input handling, rendering |
| `console.cpp/h` | SFML-backed glyph console renderer |
| `map.cpp/h` | Map generation and pathfinding |
| `unit.cpp/h` | Player and enemy entity logic |
| `util.cpp/h` | Logging, error handling, math utilities |
| `colors.h` | Color constants |

The project was forked to add two missing `#include` directives (`<cstdint>` and `<string>`) required due to a C++ version mismatch, and to remap movement controls from `hjkl` to `wasd`.

---

## 2. Analysis

### 2.1 Cppcheck

Cppcheck is a static analysis tool that checks C++ source code for bugs, style issues, and performance problems without needing to compile the code.

**Missing include warnings** — Cppcheck reports that it cannot find SFML headers and standard library headers such as `<iostream>`, `<optional>`, and `<cstdint>`. These can be safely ignored: Cppcheck does not need to resolve library headers to perform its analysis, and the project compiles correctly with cmake.

**Genuine findings:**

- `map.cpp:110-111` — **Redundant condition**: the code checks `if (neighbors[i] < 4)` and then `else if (neighbors[i] >= 4)`. The second condition is the logical opposite of the first and therefore always true when reached. This is dead code — the `else if` should simply be `else`.

- `map.cpp:165` and `map.cpp:174` — **Unsigned comparison against zero**: the conditions `x >= 0` and `y >= 0` are always true because `x` and `y` are `uint32_t` (unsigned). These checks have no effect and suggest the developer was thinking of the variables as signed integers.

- `unit.cpp:6` — **Unsigned less-than-zero check**: `if (x < 0 || y < 0 ...)` where `x` and `y` are unsigned. Same issue as above — the checks are always false and the boundary condition they were meant to catch is never triggered.

- `map.cpp:108-109` — **Unused variables**: `uint32_t x = i%w` and `uint32_t y = i/w` are computed inside `CA_count_neighbors` but never used. This is leftover code from a refactor.

- `console.cpp:130` and `main.cpp:18` — **Unused functions**: `Console::set_region` and `get_random_unoccupied_tile` are defined but never called from the game code. `set_region` is exercised by the unit tests, but `get_random_unoccupied_tile` is genuinely dead code.

- `console.cpp:104` and `map.cpp:265` — **Argument name mismatch**: the parameter name in the function declaration differs from the name in the definition (`g` vs `glyph`, `xy` vs `pos`). This is a minor inconsistency that makes the code harder to read.

- `console.cpp:130` and `util.cpp:6` — **Parameters passed by value**: `set_region` takes a `std::vector` by value and `log` takes a `std::string` by value, both of which cause unnecessary copies. These should be passed by `const` reference.

---

### 2.2 Clang-tidy

Clang-tidy is a linter built on top of the Clang compiler infrastructure. It provides a wider range of checks than Cppcheck, including modernization suggestions and Core Guidelines enforcement.

**Errors** — Clang-tidy reports errors for missing SFML headers and for `std::source_location` not being found. These are not real errors: SFML is built by cmake into a separate directory not visible to clang-tidy, and `std::source_location` requires C++20 which clang-tidy was not invoked with the right flags to detect. The project compiles and runs correctly.

**Warnings (104 total):**

- **bugprone-narrowing-conversions** — `util::distance` in `util.cpp:16` performs a narrowing conversion from `double` to `float`. The underlying cause is that `std::pow` and `std::sqrt` return `double`, but the function returns `float`. More importantly, the function uses unsigned integer subtraction (`a.x - b.x`) which will silently underflow if `a.x < b.x`, producing a very large number instead of the expected negative difference. This is a real bug: `distance({0,0}, {3,4})` would return a large incorrect value while `distance({3,4}, {0,0})` returns the correct 5.0.

- **bugprone-easily-swappable-parameters** — Several functions have adjacent parameters of the same type, for example `set_glyph(uint32_t x, uint32_t y, ...)` and `BSP_recurse_region(...)`. Calling these with swapped arguments would compile silently but produce incorrect behavior.

- **performance-unnecessary-value-param** — Confirms the cppcheck finding: multiple functions take `std::string` or `std::vector` by value when they should use `const` references.

- **readability-identifier-length** — Single-character parameter names (`x`, `y`, `a`, `b`) are flagged throughout the codebase. While short names are acceptable for coordinates, the tool reports them as below the minimum recommended length of 3 characters.

- **readability-magic-numbers** — Hardcoded numeric literals appear throughout `map.cpp` and `main.cpp` (map dimensions, BSP split thresholds, entity counts). These would be clearer as named constants.

- **readability-braces-around-statements** — Several single-line `if` bodies omit curly braces, which is a common source of bugs when code is modified later.

- **modernize-use-trailing-return-type** — Several free functions use the traditional `returnType functionName()` syntax rather than the C++20 trailing return type syntax `auto functionName() -> returnType`. This is a style preference, not a bug.

- **cppcoreguidelines-avoid-c-arrays** and **cppcoreguidelines-pro-bounds-pointer-arithmetic** — Raw C-style arrays and pointer arithmetic appear in parts of the code where `std::array` and iterators would be safer alternatives.

---

### 2.3 Valgrind

Valgrind is a dynamic analysis tool that instruments a running program to detect memory errors and leaks. The ONRL executable was run under Valgrind until the window was manually closed.

**Leak summary:**
```
definitely lost:   184 bytes in 1 blocks
indirectly lost:   1,825 bytes in 2 blocks
possibly lost:     0 bytes in 0 blocks
still reachable:   74,869 bytes in 558 blocks
suppressed:        0 bytes in 0 blocks
```

**Still reachable (74,869 bytes)** — This memory was allocated during the program's lifetime and was still reachable (i.e. a pointer to it still existed) when the program exited. The largest contributor is the `gfx::Console` constructor which allocates the SFML window and font resources. GUI applications commonly leave this kind of memory allocated at program exit and rely on the operating system to reclaim it, since the OS cleans up all process memory on exit regardless. This is not considered a memory leak in the traditional sense.

**Definitely lost and indirectly lost** — The only genuine memory leak (184 bytes, 1 block) and the two indirectly lost blocks (1,825 bytes) were traced through the Valgrind report to the `libdbus-1` library, which SFML uses internally for inter-process communication on Linux. These leaks occur in third-party library code, not in ONRL's source code. The project itself does not have any memory leaks.

---

### 2.4 Unit Testing

Unit tests were written using the GoogleTest framework and are located in `tools/unit-tests/`. Code coverage was measured with `lcov` and `genhtml`.

**12 tests across 3 suites, all passing:**

*ConsoleTest* — covers the `gfx::Console` class:
- `CreateConsole` — verifies the console can be constructed and that `render()` and `window_display()` complete without throwing
- `SetAndGetGlyph` — verifies that a glyph written to a position can be read back with the correct character and colors
- `SetGlyphOutOfBounds` — verifies that `set_glyph()` throws `std::runtime_error` for out-of-bounds coordinates
- `GetGlyphOutOfBounds` — verifies that `get_glyph()` throws `std::runtime_error` for out-of-bounds coordinates
- `GetWindow` — verifies that `get_window()` returns a reference to an open SFML window
- `SetRegion` — verifies that `set_region()` correctly writes a 2×2 block of glyphs

*UtilTest* — covers `util.cpp` math and error functions:
- `DistanceSamePoint` — verifies distance from a point to itself is 0
- `DistancePythagorean` — verifies the distance calculation using a 3-4-5 right triangle

*SfUtilTest* — covers `util::sf::to_string`:
- `ToStringClosed`, `ToStringKeyPressed`, `ToStringMouseMoved` — verify that known SFML event types are converted to the correct string

**Coverage results:**

| File | Lines covered | Functions covered |
|---|---|---|
| `console.cpp` | 69/86 (80.2%) | 7/9 (77.8%) |
| `util.cpp` | 13/35 (37.1%) | 4/4 (100%) |

The two uncovered functions in `console.cpp` are `get_mouse_tile_xy()` and `poll_event()`, both of which depend on live OS input (mouse position and window events) and cannot be exercised in an automated test without a running game loop. The uncovered lines in `util.cpp` are the untested `case` branches in the `to_string` switch statement.

Note: the `DistancePythagorean` test only tests the case where both components of the first argument are greater than those of the second (`distance({5,6}, {2,2}) == 5.0`). As identified by clang-tidy, calling the function in the opposite direction (`distance({2,2}, {5,6})`) would produce an incorrect result due to unsigned integer underflow.

---

### 2.5 Lizard

Lizard measures cyclomatic complexity (CCN) — the number of independent execution paths through a function. A CCN of 1 means a straight-line function with no branches. Each `if`, `for`, `while`, or `switch` case adds 1. The default warning threshold is CCN > 15.

**3 warnings out of 42 functions:**

- **`main` in `main.cpp`** — CCN 31, 107 NLOC. The entire game loop lives in a single function: reading input, updating player position, running enemy AI, rendering the map, rendering all units, and processing events. The high complexity is a direct consequence of this design. In a more mature codebase these responsibilities would be split across separate functions or systems.

- **`game::BSP_recurse_region` in `map.cpp`** — CCN 16, 38 NLOC. This function implements the recursive Binary Space Partitioning algorithm for map generation. It has many branching conditions to decide whether to split a region horizontally or vertically, how large the resulting rooms should be, and when to stop recursing. The complexity here is inherent to the algorithm rather than a design problem.

- **`util::sf::to_string` in `util.cpp`** — CCN 25, 29 NLOC. This is a switch statement with one `case` for each of the 24 SFML event types. Each case adds 1 to the CCN, making the score appear alarming. In practice the function is trivial to read and maintain. This is a well-known limitation of cyclomatic complexity as a metric: it penalizes large switch statements equally regardless of how simple the individual cases are.

The remaining 39 functions all have CCN ≤ 15, most with CCN between 1 and 5, indicating that the non-algorithmic parts of the codebase are straightforward.

---

### 2.6 Hyperfine

Hyperfine is a command-line benchmarking tool. Since ONRL is an interactive game that never exits on its own, the build time was benchmarked as a meaningful alternative metric. The benchmark forces a full recompile on each run using `cmake --build build --clean-first`.

**Results (5 runs, 1 warmup run):**
```
Time (mean ± σ):     15.864 s ±  0.025 s
Range (min … max):   15.712 s … 16.137 s
User: 12.602 s  |  System: 3.262 s
```

The build time is highly consistent — a standard deviation of 0.025 seconds across 5 runs indicates that the build is not affected by background activity or I/O variance. The total wall time is approximately 15.9 seconds.

User time (12.6 s) is less than wall time (15.9 s), which indicates the build is not fully parallelized. If cmake were using all available CPU cores in parallel, user time would exceed wall time by roughly the number of cores. The remaining gap is partly accounted for by system time (3.3 s) spent on disk I/O and linking, which is inherently sequential.

For a project of this size (approximately 700 NLOC across 6 translation units), a 15.9-second build is relatively slow. The main contributor is the SFML dependency which cmake fetches and compiles from source as part of the build, rather than using a pre-installed system library.

---

## 3. Conclusions

The static analysis tools (Cppcheck and Clang-tidy) converge on a consistent set of code quality issues:

- **Unsigned comparisons against zero** appear in both `map.cpp` and `unit.cpp`. The checks `x >= 0` and `x < 0` on `uint32_t` variables are always true or always false respectively, meaning the boundary conditions they were meant to guard against are never actually checked. This is a latent bug: tiles or units at position (0, 0) might bypass bounds checks that the developer assumed were in place.

- **Parameters passed by value** instead of by `const` reference in `log()` and `set_region()` cause unnecessary copies of `std::string` and `std::vector` on every call. For a roguelike that calls `log()` frequently during rendering, this is a minor but unnecessary performance cost.

- **`util::distance` contains an unsigned underflow bug.** The function subtracts unsigned integers without checking which is larger, meaning the result is only correct when the first argument is component-wise greater than or equal to the second. This is confirmed by the unit tests: the `DistancePythagorean` test was deliberately written to avoid triggering the bug.

- **The `main` function** has a cyclomatic complexity of 31, which is the clearest structural problem in the codebase. It handles input, AI, physics, and rendering in a single function. This makes the game loop difficult to extend (which likely contributed to the project being abandoned) and impossible to unit test in isolation.

- **Memory management is clean** at the project level. Valgrind found no leaks in ONRL's own code. The only leaks trace to `libdbus-1`, a system library used internally by SFML on Linux, which the project has no control over.

- **Build time** is dominated by the SFML dependency being compiled from source. The project source itself is small and would compile in under a second in isolation.

Overall, ONRL is a readable and functional prototype with code quality issues typical of a time-constrained hobby project. The most actionable findings are the unsigned comparison bugs in `map.cpp` and `unit.cpp`, the underflow bug in `util::distance`, and the monolithic `main` function. None of these bugs cause visible incorrect behavior under normal gameplay conditions, but they represent reliability risks that would need to be addressed before the project could be considered production-ready.
