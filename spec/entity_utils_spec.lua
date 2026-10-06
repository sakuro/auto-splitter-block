local entity_utils = require("lib.entity_utils")

describe("entity_utils.is_transport_entity", function()
  it("is true for every transport type", function()
    for _, t in ipairs({ "transport-belt", "underground-belt", "splitter", "loader", "loader-1x1", "lane-splitter" }) do
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
