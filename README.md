# 2026_Analysis_ONRL

Bojan Velickovic 1070/2024

The project analyzed in this assignment is https://github.com/nullspeaker/ONRL, main branch.
The specific commit is ```12efcde267c00f120b9b16ad7800fe117dd44d9c```. <br>
<br>
This repository has been inactive for some time, so the project in question is not complete. It can still run and has its core functioanlity:
- game window
- terrain
- player character
- enemies
- movement
- object collision
<br>
I actually forked that repository to add:


- ```#include <cstdint>``` to ONRL/src/main.cpp
- ```#include <cstdint>``` and ```#include <string>``` to ONRL/src/console.h

and change the movement controls to wasd from hjkl in main.cpp lines 41-44.<br> <br>
The inclusions were needed becouse of cpp version missmatch. It might not be needed for everyone, but it can't hurt either.


## Build instructions:

1. The build requires some dependencies that I did not have previously installed. Run: <br>
```
sudo apt update
sudo apt install libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev \
                 libxi-dev libgl1-mesa-dev libglu1-mesa-dev freeglut3-dev \
                 libudev-dev libopenal-dev libflac-dev libvorbis-dev libogg-dev \ 
                 libfreetype6-dev libsfml-dev
```
<br>
This did the trick for me.

2. Build:
```
cd ONRL
mkdir build
cmake -B build -S .
cmake --build build
./build/ONRL || build/Debug/ONRL.exe
```

CI configuration is provided in .github/workflows/ci.yml

## Tools and Analysis
1. Cppcheck <br>
   ```cd ONRL``` and run ```cppcheck --enable=all --inconclusive --quiet src/ 2>../tools/cppcheck/cppcheck.log``` which runs the tool on ONRL src/ code. <br>
   ```--enable=all``` runs checks for everything (style, performance, portability...)<br>
   ```--inconclusive``` reports issues that are not 100% certain<br>
   ```--quiet``` only shows warnings/errors<br>
   ```2>../tools/cppcheck/cppcheck.log``` redirects the output into a log file at the provided path<br>
<br><br>
   In the log file we can see that there are a lot of warnings that the tool could not find the libraries included in the code (things like iostream, SFML/Graphics.hpp, optional, cstdint...). We can safely ignore these warnings.<br>
   Additional warnings are things like:
     - different names for arguments in the function definition and declaration
     - redundant or unnecessary if clauses
     - unused variables and functions
     - not passing vectors and strings by reference but rather by name which copies the whole thing
     - use existing std library functions instead of implementing new ones that do the same thing
  
2. Clang-tidy<br>
   ```cd ONRL``` and run 
   ```
   clang-tidy src/*.cpp -checks='bugprone-*,performance-*,modernize-*,readability-*,cppcoreguidelines-*,-cppcoreguidelines-avoid-magic-numbers' -- -I./src 2>&1 | tee ../tools/clang-tidy/clang-tidy.log
   ``` 
   which runs the tool on ONRL src/ code. <br>

  In the log we can find 104 warnings and 2 errors. <br>
  Regarding the errors, they are both in connection with the SFML (Simple and Fast Multimedia Library). Clang-tidy can't find the library, which is to be expected since the dependencies are built using cmake and are located in a separate directory. This means that these errors are not really errors, just indicators that the necessary dependencies were not included in the directory in which we ran clang-tidy.<br>
  Regarding the warnings, let's split them up by type:
  1. bugprone
     - a couple of warnings for easily swappable parameters of functions that share the same type
     - implicit conversion from uint32_t to unsigned long due to multiplication of two uint32_t values
    
  2. performance
     - not passing parameters by reference when that would be more optimal
     - using larger types than necessary
    
  3. modernize
     - when to use a trailing return type
    
  4. readability
     - mostly paramaeter naming issues
     - replacing "magic numbers" with named constants
     - leaving out braces {} for if blocks when they have only one line
     - ...
    
  5. cppcoreguidelines
     - avoid pointer arithmetic
     - replacing macros with enums
     - avoid creating C-style arrays, should use ```std::array<>``` instead
     - ...    


3. Valgrind<br>
```cd ONRL``` and run ```valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes ./build/ONRL &>../tools/valgrind/valgrind_log.txt``` which runs the executable ONRL file and tracks memory leaks.<br>
- ```--leak-check=full``` - show all leaks
- ```--show-leak-kinds=all``` - categorizes all kinds of leaks
- ```--track-origins=yes``` - shows where uninitialized values come from

The short leak summary is:
```
LEAK SUMMARY:
    definitely lost: 184 bytes in 1 blocks
    indirectly lost: 1,825 bytes in 2 blocks
    possibly lost: 0 bytes in 0 blocks
    still reachable: 74,869 bytes in 558 blocks
    suppressed: 0 bytes in 0 blocks
```
While the full leak report can be found in the log.<br>
- As we can see, there is a lot of still reachable memory. That is memory that was left allocated at program exit but it was still reachable. This in it self is not a big problem.For example, in record 74/130 we have still reachable memory that happened due to ```gfx::Console::Console(unsigned int, unsigned int, std::string, unsigned int)``` which creates a console i.e. a game window. The practice of leaveing this memory allocated at program end without losing the pointer to it seems standard for GUI applications that rely on the OS to clean up such memory on program exit.<br>
- In record 120/130 we have our only definitely lost memory, which is a genuine memory leak. However, the leak didn't occur in the repository code, but instead it happened in the code of the libdbus-1 library.<br>
- In records 83/130 and 119/130 we have our only two instances of indirectly lost memory. Again, both of these memory leaks happen in the libdbus-1 library, not in the original ONRL source code.<br>

4. Unit testing <br>
   Unit tests are written using the GoogleTest framework and are located in ```tools/unit-tests/test_console.cpp``` and ```tools/unit-tests/test_util.cpp```. To reproduce, run ```bash tools/unit-tests/run_tests.sh``` from the repo root. The script compiles the tests, runs them, and generates a coverage report. <br>
   The compile command used inside the script is:
   ```
   g++ -std=c++20 --coverage -g test_console.cpp test_util.cpp ../../ONRL/src/console.cpp ../../ONRL/src/util.cpp -o runTests -lgtest -lgtest_main -lpthread -lsfml-graphics -lsfml-window -lsfml-system
   ```
   - ```--coverage``` enables GCC's built-in coverage instrumentation. At compile time it produces ```.gcno``` files (a static map of the code structure), and at runtime the executed binary writes ```.gcda``` files (hit counters for each line and branch)
   - ```-lgtest -lgtest_main``` links the GoogleTest static libraries
   - ```-lpthread``` is required by GoogleTest
   - ```-lsfml-*``` links the SFML libraries needed by the tested source files <br><br>

   12 tests pass across 3 test suites. <br><br>

   Tests for ```gfx::Console``` from ```console.cpp``` (```test_console.cpp```):
   - ```ConsoleTest.CreateConsole``` - constructs a console window and verifies that ```render()``` and ```window_display()``` can be called without throwing an exception
   - ```ConsoleTest.SetAndGetGlyph``` - sets a glyph at position (0,0) with a specific character and colors, then reads it back and verifies the values match
   - ```ConsoleTest.SetGlyphOutOfBounds``` - verifies that ```set_glyph()``` throws ```std::runtime_error``` when given coordinates outside the console bounds
   - ```ConsoleTest.GetGlyphOutOfBounds``` - verifies that ```get_glyph()``` throws ```std::runtime_error``` when given coordinates outside the console bounds
   - ```ConsoleTest.GetWindow``` - verifies that ```get_window()``` returns a reference to an open SFML window
   - ```ConsoleTest.SetRegion``` - sets a 2x2 block of glyphs using ```set_region()``` and verifies each position contains the correct glyph <br><br>

   Tests for utility functions from ```util.cpp``` (```test_util.cpp```):
   - ```UtilTest.DistanceSamePoint``` - verifies that the distance from a point to itself is 0
   - ```UtilTest.DistancePythagorean``` - verifies the distance calculation using a 3-4-5 right triangle (expected result: 5.0)
   - ```UtilTest.HaltCatchFireThrows``` - verifies that ```halt_catch_fire()``` throws ```std::runtime_error```
   - ```SfUtilTest.ToStringClosed``` - verifies that ```util::sf::to_string()``` returns ```"Closed"``` for the ```sf::Event::Closed``` event type
   - ```SfUtilTest.ToStringKeyPressed``` - verifies that ```util::sf::to_string()``` returns ```"KeyPressed"``` for the ```sf::Event::KeyPressed``` event type
   - ```SfUtilTest.ToStringMouseMoved``` - verifies that ```util::sf::to_string()``` returns ```"MouseMoved"``` for the ```sf::Event::MouseMoved``` event type <br><br>

   Code coverage is measured using ```lcov``` and ```genhtml```:
   ```
   lcov --capture --directory . --output-file coverage.info --ignore-errors mismatch
   genhtml coverage.info --output-directory coverage_report
   ```
   - ```--capture --directory .``` scans the current directory for ```.gcda``` files and collects the coverage data
   - ```--output-file coverage.info``` writes the collected data to a single ```.info``` file
   - ```--ignore-errors mismatch``` is required because lcov 2.x is stricter than earlier versions and errors out on minor line number mismatches in gcov data generated for GoogleTest macros. The mismatches are harmless.
   - ```genhtml``` generates an HTML report from the ```.info``` file into ```coverage_report/``` <br><br>

   The coverage results for the project source files are:
   - ```console.cpp```: 69/86 lines covered (80.2%), 7/9 functions covered (77.8%)
   - ```util.cpp```: 13/35 lines covered (37.1%), 4/4 functions covered (100%) <br><br>

   The two uncovered functions in ```console.cpp``` are ```get_mouse_tile_xy()``` and ```poll_event()```, both of which require live OS input (mouse position and window events) and cannot be exercised in an automated test without a running game loop.
5. Lizard <br>
   Lizard is a cyclomatic complexity analyzer. Cyclomatic complexity (CCN) counts the number of independent paths through a function — each `if`, `for`, `while`, or `switch` case adds 1 to the base value of 1. Higher CCN means the function is harder to understand, test, and maintain. Install with ```pip install lizard``` and run ```bash tools/lizard/run_lizard.sh``` from the repo root. The command used is:
   ```
   lizard ONRL/src/ 2>&1 | tee tools/lizard/lizard.log
   ```
   - ```lizard ONRL/src/``` runs the tool on all source files in the directory
   - ```2>&1``` merges stderr into stdout so all output is captured
   - ```tee``` writes the output to the log file and also prints it to the terminal <br><br>

   Lizard reports 3 warnings (functions with CCN > 15, which is the default threshold):
   - ```main``` in ```main.cpp``` — CCN 31, 107 NLOC. This is the game loop: it handles input, updates all entities, renders the map and more. All of that logic is in one function, which is why the complexity is so high.
   - ```game::BSP_recurse_region``` in ```map.cpp``` — CCN 16, 38 NLOC. This is the recursive Binary Space Partitioning map generator. It has many branching conditions to decide how to split regions and place rooms.
   - ```util::sf::to_string``` in ```util.cpp``` — CCN 25, 29 NLOC. This is a switch statement with one case per SFML event type (24 cases). Each case adds 1 to the CCN, making this look complex even though it's really not.

6. Hyperfine <br>
   Hyperfine is a command-line benchmarking tool. It runs a command repeatedly and reports statistics: mean time, standard deviation, and min/max across all runs. Install with ```sudo apt install hyperfine``` and run ```bash tools/hyperfine/run_hyperfine.sh``` from the repo root. <br><br>

   ONRL is an interactive game that never exits on its own, so benchmarking the executable directly is not something worth doing — hyperfine would hang waiting for it to finish. Instead, the build time is benchmarked, which measures how long the compiler takes to process the full project. The command used is:
   ```
   hyperfine --warmup 1 --runs 5 'cd ONRL && cmake --build build --clean-first 2>/dev/null' --export-json tools/hyperfine/hyperfine.json 2>&1 | tee tools/hyperfine/hyperfine.log
   ```
   - ```--warmup 1``` runs the command once before measuring to warm up the disk cache, so cached files don't skew the first run
   - ```--runs 5``` sets the number of timed runs to average over
   - ```--clean-first``` forces cmake to recompile everything from scratch on each run, ensuring a fair and consistent measurement
   - ```2>/dev/null``` suppresses cmake's build output so it doesn't clutter the terminal
   - ```--export-json``` saves the full results (mean, standard deviation, min and max per run) to a JSON file for reference <br><br>

   Results:
   ```
   Time (mean ± σ):     15.889 s ±  0.175 s    [User: 12.701 s, System: 3.187 s]
   Range (min … max):   15.712 s … 16.137 s    5 runs
   ```
   The build is consistent (σ = 0.175 s) with a mean of ~15.9 seconds. The small standard deviation means that the build time is stable and consistent. User time (12.7 s) is less than wall time (15.9 s).

## Conclusions

- Unsigned comparisons against zero in ```map.cpp``` and ```unit.cpp``` are always true or always false
- ```util::distance``` contains an unsigned integer underflow bug — the result is only correct when the first argument is component-wise greater than or equal to the second
- Parameters are passed by value instead of by ```const``` reference in ```log()``` and ```set_region()```, causing unnecessary copies on every call
- The ```main``` function has a cyclomatic complexity of 31 — it handles input, AI, physics, and rendering in a single monolithic function, making it difficult to extend or test
- No memory leaks were found in the project's own code — all leaks reported by Valgrind trace to the ```libdbus-1``` system library used internally by SFML
- Build time (~15.9 s) is dominated by SFML being compiled from source; the project's own source would compile much faster in comparison 
- 39 out of 42 functions have a cyclomatic complexity of 15 or below, indicating the codebase is generally straightforward outside of the game loop and map generation algorithm

A detailed analysis with full findings for each tool can be found in ```ProjectAnalysisReport_EN.md``` (English) and ```ProjectAnalysisReport_SR.md``` (Serbian).
