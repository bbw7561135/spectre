// Distributed under the MIT License.
// See LICENSE.txt for details.

#include <catch.hpp>

#include "Domain/Block.cpp"
#include "Domain/EmbeddingMaps/Identity.hpp"
#include "tests/Unit/TestHelpers.hpp"

template <size_t Dim>
void test_block() {
  const EmbeddingMaps::Identity<Dim> identity_map{};
  Block<Dim> block(identity_map, 7, {});

  // Test external boundaries:
  CHECK((block.external_boundaries().size()) == 2 * Dim);

  // Test neighbors:
  CHECK((block.neighbors().size()) == 0);

  // Test id:
  CHECK((block.id()) == 7);

  // Test that the block's embedding_map is Identity:
  const auto& map = block.embedding_map();
  const Point<Dim, Frame::Logical> xi(1.0);
  const Point<Dim, Frame::Grid> x(1.0);
  CHECK(map(xi) == x);
  CHECK(map.inverse(x) == xi);

  // Test PUP
  // CHECK(block == serialize_and_deserialize(block));

  // Test move semantics:
  const Block<Dim> block_copy(identity_map, 7, {});
  test_move_semantics(std::move(block), block_copy);
}

TEST_CASE("Unit.Domain.Block.Identity", "[Domain][Unit]") {
  test_block<1>();
  test_block<2>();
  // test_identity<3>();
}

TEST_CASE("Unit.Domain.Block.Neighbors", "[Domain][Unit]") {
  // Create std::unordered_map<Direction<VolumeDim>, BlockNeighbor<VolumeDim>>

  // Each BlockNeighbor is an id and an Orientation:
  const BlockNeighbor<2> block_neighbor1(
      1, Orientation<2>(std::array<Direction<2>, 2>{
             {Direction<2>::upper_xi(), Direction<2>::upper_eta()}}));
  const BlockNeighbor<2> block_neighbor2(
      2, Orientation<2>(std::array<Direction<2>, 2>{
             {Direction<2>::lower_xi(), Direction<2>::upper_eta()}}));
  std::unordered_map<Direction<2>, BlockNeighbor<2>> neighbors = {
      {Direction<2>::upper_xi(), block_neighbor1},
      {Direction<2>::lower_eta(), block_neighbor2}};
  const EmbeddingMaps::Identity<2> identity_map{};
  const Block<2> block(identity_map, 3, std::move(neighbors));

  // Test external boundaries:
  CHECK((block.external_boundaries().size()) == 2);

  // Test neighbors:
  CHECK((block.neighbors().size()) == 2);

  // Test id:
  CHECK((block.id()) == 3);

  // Test output:
  CHECK(get_output(block) ==
        "Block 3:\n"
        "Neighbors:\n"
        "-1: Id = 2; orientation = (-0, +1)\n"
        "+0: Id = 1; orientation = (+0, +1)\n"
        "External boundaries: (+1,-0)\n");

  // Test comparison:
  const Block<2> neighborless_block(identity_map, 7, {});
  CHECK(block == block);
  CHECK(block != neighborless_block);
  CHECK(neighborless_block == neighborless_block);
}