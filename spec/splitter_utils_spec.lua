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

  it("is true when both circuit networks are connected", function()
    assert.is_true(splitter_utils.is_circuit_controlled(factorio.splitter({ circuit = "both" })))
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

  it("follows the configured filter item", function()
    assert.is_false(splitter_utils.has_block_filter(factorio.splitter({ splitter_filter = "deconstruction-planner" })))

    factorio.set_filter_item("deconstruction-planner")

    assert.is_true(splitter_utils.has_block_filter(factorio.splitter({ splitter_filter = "deconstruction-planner" })))
    assert.is_false(splitter_utils.has_block_filter(factorio.splitter({ splitter_filter = "no-item" })))
  end)
end)

describe("splitter_utils.discard_saved_priority", function()
  before_each(factorio.reset)

  it("drops the entry for a unit_number", function()
    storage.saved_priorities[7] = "left"

    splitter_utils.discard_saved_priority(7)

    assert.is_nil(storage.saved_priorities[7])
  end)

  it("is a no-op for an unknown unit_number", function()
    assert.has_no.errors(function()
      splitter_utils.discard_saved_priority(999)
    end)
  end)
end)

describe("splitter_utils.sanitize_saved_priorities", function()
  before_each(factorio.reset)

  local function blocked_splitter(world, unit_number)
    return world.add(factorio.splitter({ unit_number = unit_number, splitter_filter = "no-item" }))
  end

  it("drops the legacy table-level tick key", function()
    factorio.world()
    storage.saved_priorities = { tick = 42 }

    splitter_utils.sanitize_saved_priorities()

    assert.same({}, storage.saved_priorities)
  end)

  it("keeps a string entry for a currently block-filtered splitter and re-registers it", function()
    local w = factorio.world()
    blocked_splitter(w, 7)
    storage.saved_priorities = { [7] = "left" }

    splitter_utils.sanitize_saved_priorities()

    assert.equal("left", storage.saved_priorities[7])
    assert.is_true(factorio.registered_for_destroy[7])
  end)

  it("normalizes a legacy { priority = ... } entry to its string", function()
    local w = factorio.world()
    blocked_splitter(w, 3)
    storage.saved_priorities = { [3] = { priority = "right", tick = 10 } }

    splitter_utils.sanitize_saved_priorities()

    assert.equal("right", storage.saved_priorities[3])
  end)

  it("drops an entry whose splitter is gone", function()
    local w = factorio.world()
    blocked_splitter(w, 1)
    storage.saved_priorities = { [1] = "left", [999] = "right" }

    splitter_utils.sanitize_saved_priorities()

    assert.is_nil(storage.saved_priorities[999])
  end)

  it("leaves no entry for a block-filtered splitter whose value is unrecoverable", function()
    local w = factorio.world()
    blocked_splitter(w, 4)
    storage.saved_priorities = {}

    splitter_utils.sanitize_saved_priorities()

    assert.is_nil(storage.saved_priorities[4])
  end)

  it("ignores splitters without the block filter", function()
    local w = factorio.world()
    w.add(factorio.splitter({ unit_number = 5 }))
    storage.saved_priorities = { [5] = "left" }

    splitter_utils.sanitize_saved_priorities()

    assert.is_nil(storage.saved_priorities[5])
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

  it("sees a same-direction 2x1 splitter whose body covers the left output tile", function()
    local w = factorio.world()
    local splitter = north_splitter(w, { priority = "left" })
    -- North splitter at {-1,-1}: its 2x1 body covers {-0.5,-1} (the left output)
    -- but not {0.5,-1} (the right one). Its centre sits on the tile edge, so a
    -- centre-only match would miss it.
    w.add(factorio.splitter({ position = { x = -1, y = -1 }, direction = D.north, surface = w.surface }))

    splitter_utils.update_block_filter(splitter)

    assert.equal("no-item", splitter.splitter_filter)
    assert.equal("right", splitter.splitter_output_priority)
    assert.equal("left", storage.saved_priorities[splitter.unit_number])
  end)

  it("sees a 2x1 loader whose body covers an output tile", function()
    local w = factorio.world()
    local splitter = north_splitter(w)
    -- North loader at {-0.5,-1.5}: 2 tiles long in y, so its body reaches the
    -- left output tile {-0.5,-1} while its centre sits a tile away.
    w.add(factorio.loader({ position = { x = -0.5, y = -1.5 }, direction = D.north, surface = w.surface }))

    splitter_utils.update_block_filter(splitter)

    assert.equal("right", splitter.splitter_output_priority)
  end)

  it("ignores a 2x1 splitter that covers the output tile but faces another direction", function()
    local w = factorio.world()
    local splitter = north_splitter(w)
    w.add(factorio.splitter({ position = { x = -1, y = -1 }, direction = D.south, surface = w.surface }))

    splitter_utils.update_block_filter(splitter)

    assert.is_nil(splitter.splitter_filter)
  end)

  it("uses the configured filter item", function()
    factorio.set_filter_item("deconstruction-planner")
    local w = factorio.world()
    local splitter = north_splitter(w)
    w.add(aligned_belt(-0.5, -1))

    splitter_utils.update_block_filter(splitter)

    assert.equal("deconstruction-planner", splitter.splitter_filter)
    assert.is_true(splitter_utils.has_block_filter(splitter))
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
    assert.equal("none", splitter.splitter_output_priority) -- nothing saved for this splitter
  end)

  it("leaves a filter set by something else alone", function()
    local w = factorio.world()
    local splitter = north_splitter(w, { splitter_filter = "iron-plate", priority = "left" })
    w.add(aligned_belt(-0.5, -1))

    splitter_utils.update_block_filter(splitter)

    assert.equal("iron-plate", splitter.splitter_filter)
    assert.equal("left", splitter.splitter_output_priority)
  end)

  it("saves the original priority on set and restores it on clear", function()
    local w = factorio.world()
    local splitter = north_splitter(w, { priority = "left" })
    w.add(aligned_belt(-0.5, -1))

    splitter_utils.update_block_filter(splitter)
    assert.equal("no-item", splitter.splitter_filter)
    assert.equal("right", splitter.splitter_output_priority)
    assert.equal("left", storage.saved_priorities[splitter.unit_number])
    assert.is_true(factorio.registered_for_destroy[splitter.unit_number])

    w.add(aligned_belt(0.5, -1))
    splitter_utils.update_block_filter(splitter)

    assert.is_nil(splitter.splitter_filter)
    assert.equal("left", splitter.splitter_output_priority)
    assert.is_nil(storage.saved_priorities[splitter.unit_number])
  end)

  it("restores none when the saved value is a legacy table", function()
    local w = factorio.world()
    local splitter = north_splitter(w, { splitter_filter = "no-item", priority = "right" })
    storage.saved_priorities[splitter.unit_number] = { priority = "left", tick = 5 }
    w.add(aligned_belt(-0.5, -1))
    w.add(aligned_belt(0.5, -1))

    splitter_utils.update_block_filter(splitter)

    assert.is_nil(splitter.splitter_filter)
    assert.equal("none", splitter.splitter_output_priority)
    assert.is_nil(storage.saved_priorities[splitter.unit_number])
  end)

  it("restores the saved priority on a clear in a later tick than the set", function()
    factorio.set_tick(5)
    local w = factorio.world()
    local splitter = north_splitter(w, { priority = "left" })
    w.add(aligned_belt(-0.5, -1))
    splitter_utils.update_block_filter(splitter)
    assert.equal("right", splitter.splitter_output_priority)

    factorio.set_tick(120)
    w.add(aligned_belt(0.5, -1))
    splitter_utils.update_block_filter(splitter)

    assert.is_nil(splitter.splitter_filter)
    assert.equal("left", splitter.splitter_output_priority)
    assert.is_nil(storage.saved_priorities[splitter.unit_number])
  end)

  it("restores the saved priority when both outputs go empty in a later tick", function()
    factorio.set_tick(5)
    local w = factorio.world()
    local splitter = north_splitter(w, { priority = "left" })
    local left = w.add(aligned_belt(-0.5, -1))
    splitter_utils.update_block_filter(splitter)
    assert.equal("right", splitter.splitter_output_priority)

    factorio.set_tick(120)
    w.remove(left)
    splitter_utils.update_block_filter(splitter)

    assert.is_nil(splitter.splitter_filter)
    assert.equal("left", splitter.splitter_output_priority)
  end)

  it("keeps the saved priority across a re-block in a later tick", function()
    factorio.set_tick(5)
    local w = factorio.world()
    local splitter = north_splitter(w, { priority = "left" })
    w.add(aligned_belt(-0.5, -1))
    splitter_utils.update_block_filter(splitter)
    assert.equal("left", storage.saved_priorities[splitter.unit_number])

    -- Filter cleared out of band (e.g. via the splitter GUI), then re-evaluated
    -- a later tick: the MOD must not re-save its own "right" as the user's value.
    splitter.splitter_filter = nil
    factorio.set_tick(120)
    splitter_utils.update_block_filter(splitter)

    assert.equal("no-item", splitter.splitter_filter)
    assert.equal("left", storage.saved_priorities[splitter.unit_number])
  end)

  it("ignores the excluded entity when scanning the outputs", function()
    local w = factorio.world()
    local splitter = north_splitter(w)
    local left = aligned_belt(-0.5, -1)
    w.add(left)

    splitter_utils.update_block_filter(splitter, left)

    assert.is_nil(splitter.splitter_filter)
  end)

  it("clears an existing block filter once neither output has a compatible entity", function()
    local w = factorio.world()
    local splitter = north_splitter(w, { splitter_filter = "no-item", priority = "left" })

    splitter_utils.update_block_filter(splitter)

    assert.is_nil(splitter.splitter_filter)
  end)

  it("is idempotent when the block filter is already set for the same side", function()
    local w = factorio.world()
    local splitter = north_splitter(w, { splitter_filter = "no-item", priority = "right" })
    w.add(aligned_belt(-0.5, -1))

    splitter_utils.update_block_filter(splitter)

    assert.equal("no-item", splitter.splitter_filter)
    assert.equal("right", splitter.splitter_output_priority)
    assert.is_nil(storage.saved_priorities[splitter.unit_number])
  end)

  it("counts an underground-belt output that side-loads the output tile", function()
    local w = factorio.world()
    local splitter = north_splitter(w)
    w.add(factorio.underground_belt({
      position = { x = -0.5, y = -1 },
      belt_to_ground_type = "output",
      direction = D.east,
    }))

    splitter_utils.update_block_filter(splitter)

    assert.equal("no-item", splitter.splitter_filter)
    assert.equal("right", splitter.splitter_output_priority)
  end)

  it("ignores an underground-belt output pointing the splitter's own way", function()
    local w = factorio.world()
    local splitter = north_splitter(w)
    w.add(factorio.underground_belt({
      position = { x = -0.5, y = -1 },
      belt_to_ground_type = "output",
      direction = D.north,
    }))
    w.add(aligned_belt(0.5, -1))

    splitter_utils.update_block_filter(splitter)

    assert.equal("no-item", splitter.splitter_filter)
    assert.equal("left", splitter.splitter_output_priority)
  end)
end)
