local entity_utils = require("lib.entity_utils")

describe("entity_utils.is_transport_entity", function()
  it("is true for every transport type", function()
    for _, t in ipairs({ "transport-belt", "underground-belt", "splitter", "loader", "loader-1x1" }) do
      assert.is_true(entity_utils.is_transport_entity({ type = t }))
    end
  end)

  it("is false for an unrelated type", function()
    assert.is_false(entity_utils.is_transport_entity({ type = "inserter" }))
  end)

  it("returns false, not nil, for a non-match", function()
    assert.equal(false, entity_utils.is_transport_entity({ type = "assembling-machine" }))
  end)
end)

describe("entity_utils.is_output_compatible", function()
  -- Direction encoding: 0 = north, 4 = east, 8 = south, 12 = west (16-way).
  local SOUTH = 8

  it("accepts a transport belt facing the same way as the splitter", function()
    assert.is_true(entity_utils.is_output_compatible({ type = "transport-belt", direction = SOUTH }, SOUTH))
  end)

  it("rejects a transport belt facing back into the splitter", function()
    local opposite = (SOUTH + 8) % 16
    assert.is_false(entity_utils.is_output_compatible({ type = "transport-belt", direction = opposite }, SOUTH))
  end)

  it("accepts a transport belt facing perpendicular", function()
    assert.is_true(entity_utils.is_output_compatible({ type = "transport-belt", direction = 4 }, SOUTH))
  end)

  it("rejects an underground-belt output pointing the same way as the splitter", function()
    assert.is_false(entity_utils.is_output_compatible(
      { type = "underground-belt", belt_to_ground_type = "output", direction = SOUTH }, SOUTH))
  end)

  it("accepts an underground-belt output pointing perpendicular (side-loading)", function()
    assert.is_true(entity_utils.is_output_compatible(
      { type = "underground-belt", belt_to_ground_type = "output", direction = 4 }, SOUTH))
  end)

  it("accepts an underground-belt input pointing the same way as the splitter", function()
    assert.is_true(entity_utils.is_output_compatible(
      { type = "underground-belt", belt_to_ground_type = "input", direction = SOUTH }, SOUTH))
  end)

  it("rejects an underground-belt input facing back into the splitter", function()
    assert.is_false(entity_utils.is_output_compatible(
      { type = "underground-belt", belt_to_ground_type = "input", direction = 0 }, SOUTH))
  end)

  it("accepts a splitter aligned with the splitter direction", function()
    assert.is_true(entity_utils.is_output_compatible({ type = "splitter", direction = SOUTH }, SOUTH))
  end)

  it("rejects a splitter that is not aligned", function()
    assert.is_false(entity_utils.is_output_compatible({ type = "splitter", direction = 4 }, SOUTH))
  end)

  it("accepts a loader-1x1 aligned with the splitter direction", function()
    assert.is_true(entity_utils.is_output_compatible({ type = "loader-1x1", direction = SOUTH }, SOUTH))
  end)

  it("rejects an unknown entity type", function()
    assert.is_false(entity_utils.is_output_compatible({ type = "inserter", direction = SOUTH }, SOUTH))
  end)
end)
