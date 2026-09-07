local factorio = require("spec.support.factorio")
local splitter_utils = require("lib.splitter_utils")

local D = _G.defines.direction

describe("splitter_utils.is_circuit_controlled", function()
  before_each(factorio.reset)

  it("is true when a red circuit network is connected", function()
    assert.is_true(splitter_utils.is_circuit_controlled(factorio.splitter({ circuit = "red" })))
  end)

  it("is true when a green circuit network is connected", function()
    assert.is_true(splitter_utils.is_circuit_controlled(factorio.splitter({ circuit = "green" })))
  end)

  it("is false when no circuit network is connected", function()
    assert.is_false(splitter_utils.is_circuit_controlled(factorio.splitter({})))
  end)
end)

describe("splitter_utils.find_affecting_splitters", function()
  before_each(factorio.reset)

  -- A north-facing splitter at {0,0} outputs onto {-0.5,-1} (left) and {0.5,-1}
  -- (right); OUTPUT_OFFSETS keys the four cardinals.
  local left_output_tile = {
    { dir = D.north, at = { x = -0.5, y = -1 } },
    { dir = D.east, at = { x = 1, y = -0.5 } },
    { dir = D.south, at = { x = 0.5, y = 1 } },
    { dir = D.west, at = { x = -1, y = 0.5 } },
  }

  for _, case in ipairs(left_output_tile) do
    it("matches a belt on the left output tile for direction " .. case.dir, function()
      local w = factorio.world()
      local splitter = w.add(factorio.splitter({ position = { x = 0, y = 0 }, direction = case.dir }))
      local belt = factorio.belt({ position = case.at, surface = w.surface })

      local result = splitter_utils.find_affecting_splitters(belt)

      assert.equal(1, #result)
      assert.equal(splitter, result[1])
    end)
  end

  it("matches a belt on the right output tile", function()
    local w = factorio.world()
    local splitter = w.add(factorio.splitter({ position = { x = 0, y = 0 }, direction = D.north }))
    local belt = factorio.belt({ position = { x = 0.5, y = -1 }, surface = w.surface })

    local result = splitter_utils.find_affecting_splitters(belt)

    assert.equal(1, #result)
    assert.equal(splitter, result[1])
  end)

  it("returns nothing when the belt is on no splitter output tile", function()
    local w = factorio.world()
    w.add(factorio.splitter({ position = { x = 0, y = 0 }, direction = D.north }))
    local belt = factorio.belt({ position = { x = 0, y = 0 }, surface = w.surface })

    assert.same({}, splitter_utils.find_affecting_splitters(belt))
  end)

  it("returns every splitter whose output lands on the belt's tile", function()
    local w = factorio.world()
    w.add(factorio.splitter({ position = { x = 0, y = 0 }, direction = D.north }))   -- right output {0.5,-1}
    w.add(factorio.splitter({ position = { x = 1, y = 0 }, direction = D.north }))   -- left output {0.5,-1}
    local belt = factorio.belt({ position = { x = 0.5, y = -1 }, surface = w.surface })

    assert.equal(2, #splitter_utils.find_affecting_splitters(belt))
  end)

  it("excludes the queried entity when it is itself a splitter", function()
    local w = factorio.world()
    local target = w.add(factorio.splitter({ position = { x = 0, y = 0 }, direction = D.north }))

    assert.same({}, splitter_utils.find_affecting_splitters(target))
  end)

  it("matches when one of a 2x1 entity's occupied tiles is an output tile", function()
    local w = factorio.world()
    local a = w.add(factorio.splitter({ position = { x = 0, y = 0 }, direction = D.north }))     -- right output {0.5,-1}
    local b = w.add(factorio.splitter({ position = { x = 0.5, y = -1.5 }, direction = D.east })) -- occupies {0.5,-2},{0.5,-1}

    local result = splitter_utils.find_affecting_splitters(b)

    assert.equal(1, #result)
    assert.equal(a, result[1])
  end)
end)

describe("splitter_utils.has_block_filter", function()
  before_each(factorio.reset)

  it("is false when there is no filter", function()
    assert.is_false(splitter_utils.has_block_filter(factorio.splitter({})))
  end)

  it("is true for the block filter item as a string", function()
    assert.is_true(splitter_utils.has_block_filter(factorio.splitter({ splitter_filter = "no-item" })))
  end)

  it("is true for the block filter item as a { name = ... } table", function()
    assert.is_true(splitter_utils.has_block_filter(factorio.splitter({ splitter_filter = { name = "no-item" } })))
  end)

  it("is false for a different filter item", function()
    assert.is_false(splitter_utils.has_block_filter(factorio.splitter({ splitter_filter = "iron-plate" })))
  end)
end)

describe("splitter_utils.update_block_filter", function()
  before_each(factorio.reset)

  -- North splitter at {0,0}: left output {-0.5,-1}, right output {0.5,-1}.
  local function north_splitter(world, opts)
    opts = opts or {}
    opts.position = { x = 0, y = 0 }
    opts.direction = D.north
    opts.surface = world.surface
    return factorio.splitter(opts)
  end
  local function aligned_belt(x, y)
    return factorio.belt({ position = { x = x, y = y }, direction = D.north })
  end

  it("blocks the right side when only the left output has a compatible entity", function()
    local w = factorio.world()
    local splitter = north_splitter(w)
    w.add(aligned_belt(-0.5, -1))

    splitter_utils.update_block_filter(splitter)

    assert.equal("no-item", splitter.splitter_filter)
    assert.equal("right", splitter.splitter_output_priority)
  end)

  it("blocks the left side when only the right output has a compatible entity", function()
    local w = factorio.world()
    local splitter = north_splitter(w)
    w.add(aligned_belt(0.5, -1))

    splitter_utils.update_block_filter(splitter)

    assert.equal("no-item", splitter.splitter_filter)
    assert.equal("left", splitter.splitter_output_priority)
  end)

  it("does nothing when both outputs have a compatible entity and no filter is set", function()
    local w = factorio.world()
    local splitter = north_splitter(w)
    w.add(aligned_belt(-0.5, -1))
    w.add(aligned_belt(0.5, -1))

    splitter_utils.update_block_filter(splitter)

    assert.is_nil(splitter.splitter_filter)
  end)

  it("does nothing when neither output has a compatible entity", function()
    local w = factorio.world()
    local splitter = north_splitter(w)

    splitter_utils.update_block_filter(splitter)

    assert.is_nil(splitter.splitter_filter)
  end)

  it("clears an existing block filter once both outputs have a compatible entity", function()
    local w = factorio.world()
    local splitter = north_splitter(w, { splitter_filter = "no-item", priority = "left" })
    w.add(aligned_belt(-0.5, -1))
    w.add(aligned_belt(0.5, -1))

    splitter_utils.update_block_filter(splitter)

    assert.is_nil(splitter.splitter_filter)
    assert.equal("none", splitter.splitter_output_priority) -- no priority saved this tick
  end)

  it("leaves a filter set by something else alone", function()
    local w = factorio.world()
    local splitter = north_splitter(w, { splitter_filter = "iron-plate", priority = "left" })
    w.add(aligned_belt(-0.5, -1))

    splitter_utils.update_block_filter(splitter)

    assert.equal("iron-plate", splitter.splitter_filter)
    assert.equal("left", splitter.splitter_output_priority)
  end)

  it("saves the original priority on set and restores it on a same-tick clear", function()
    factorio.set_tick(5)
    local w = factorio.world()
    local splitter = north_splitter(w, { priority = "left" })
    local left = aligned_belt(-0.5, -1)
    w.add(left)

    splitter_utils.update_block_filter(splitter)
    assert.equal("no-item", splitter.splitter_filter)
    assert.equal("right", splitter.splitter_output_priority)
    assert.equal("left", storage.saved_priorities[splitter.unit_number])
    assert.equal(5, storage.saved_priorities.tick)

    w.add(aligned_belt(0.5, -1))
    splitter_utils.update_block_filter(splitter)

    assert.is_nil(splitter.splitter_filter)
    assert.equal("left", splitter.splitter_output_priority)
    assert.is_nil(storage.saved_priorities[splitter.unit_number])
  end)

  it("ignores the excluded entity when scanning the outputs", function()
    local w = factorio.world()
    local splitter = north_splitter(w)
    local left = aligned_belt(-0.5, -1)
    w.add(left)

    splitter_utils.update_block_filter(splitter, left)

    assert.is_nil(splitter.splitter_filter)
  end)
end)
