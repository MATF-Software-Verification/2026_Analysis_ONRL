#include <gtest/gtest.h>
#include "../../ONRL/src/console.h"

TEST(ConsoleTest, CreateConsole) {
    gfx::Console console(80, 25, "LiberationMono-Bold.ttf", 12);

    EXPECT_NO_THROW(console.render());
    EXPECT_NO_THROW(console.window_display());
}

TEST(ConsoleTest, SetAndGetGlyph) {
    gfx::Console console(10, 10, "LiberationMono-Bold.ttf", 12);

    gfx::Console::glyph_t g{'A', sf::Color::Red, sf::Color::Black};
    console.set_glyph(0, 0, g);

    auto result = console.get_glyph(0, 0);
    EXPECT_EQ(result.c, 'A');
    EXPECT_EQ(result.fg, sf::Color::Red);
    EXPECT_EQ(result.bg, sf::Color::Black);
}

TEST(ConsoleTest, SetGlyphOutOfBounds) {
    gfx::Console console(10, 10, "LiberationMono-Bold.ttf", 12);
    gfx::Console::glyph_t g{'X', sf::Color::White, sf::Color::Black};
    EXPECT_THROW(console.set_glyph(10, 0, g), std::runtime_error);
}

TEST(ConsoleTest, GetGlyphOutOfBounds) {
    gfx::Console console(10, 10, "LiberationMono-Bold.ttf", 12);
    EXPECT_THROW(console.get_glyph(0, 10), std::runtime_error);
}

TEST(ConsoleTest, GetWindow) {
    gfx::Console console(10, 10, "LiberationMono-Bold.ttf", 12);
    sf::RenderWindow& window = console.get_window();
    EXPECT_TRUE(window.isOpen());
}

TEST(ConsoleTest, SetRegion) {
    gfx::Console console(10, 10, "LiberationMono-Bold.ttf", 12);
    std::vector<gfx::Console::glyph_t> region = {
        {'A', sf::Color::Red,   sf::Color::Black},
        {'B', sf::Color::Green, sf::Color::Black},
        {'C', sf::Color::Blue,  sf::Color::Black},
        {'D', sf::Color::White, sf::Color::Black},
    };
    console.set_region(0, 0, 2, 2, region);
    EXPECT_EQ(console.get_glyph(0, 0).c, 'A');
    EXPECT_EQ(console.get_glyph(1, 0).c, 'B');
    EXPECT_EQ(console.get_glyph(0, 1).c, 'C');
    EXPECT_EQ(console.get_glyph(1, 1).c, 'D');
}
