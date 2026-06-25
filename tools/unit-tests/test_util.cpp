#include <gtest/gtest.h>
#include "../../ONRL/src/util.h"

TEST(UtilTest, DistanceSamePoint) {
    sf::Vector2u a{5, 5};
    EXPECT_FLOAT_EQ(util::distance(a, a), 0.0f);
}

TEST(UtilTest, DistancePythagorean) {
    // 3-4-5 right triangle. Both components of a are >= b to avoid unsigned underflow.
    sf::Vector2u a{5, 6};
    sf::Vector2u b{2, 2};
    EXPECT_FLOAT_EQ(util::distance(a, b), 5.0f);
}

TEST(UtilTest, HaltCatchFireThrows) {
    EXPECT_THROW(util::halt_catch_fire("test error"), std::runtime_error);
}

TEST(SfUtilTest, ToStringClosed) {
    EXPECT_EQ(util::sf::to_string(sf::Event::Closed), "Closed");
}

TEST(SfUtilTest, ToStringKeyPressed) {
    EXPECT_EQ(util::sf::to_string(sf::Event::KeyPressed), "KeyPressed");
}

TEST(SfUtilTest, ToStringMouseMoved) {
    EXPECT_EQ(util::sf::to_string(sf::Event::MouseMoved), "MouseMoved");
}
