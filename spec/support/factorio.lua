--- Minimal Factorio runtime fakes for busted specs. `require` this before the
--- module under test and call `factorio.reset()` in `before_each`.
local factorio = {}

local DEFAULT_FILTER_ITEM = "no-item"
local filter_item
local next_unit_number

_G.defines = {
  direction = { north = 0, east = 4, south = 8, west = 12 },
  wire_type = { red = 1, green = 2 },
  target_type = { entity = 1 },
}

--- unit_number -> true for every entity passed to register_on_object_destroyed.
_G.script = {
  register_on_object_destroyed = function(entity)
    factorio.registered_for_destroy[entity.unit_number] = true
  end,
}

_G.settings = {
  startup = setmetatable({}, {
    __index = function(_, key)
      if key == "auto-splitter-block-filter-item" then
        return { value = filter_item }
      end
      return { value = nil }
    end,
  }),
}

--- Reset mutable global state. Call in `before_each`.
function factorio.reset()
  filter_item = DEFAULT_FILTER_ITEM
  next_unit_number = 0
  factorio.registered_for_destroy = {}
  _G.storage = { saved_priorities = {} }
  _G.game = { tick = 1, surfaces = {} }
end

--- Change what `settings.startup["auto-splitter-block-filter-item"]` reports.
--- `lib/splitter_utils.lua` reads it lazily, so a change takes effect on the
--- next call. Set it before calling the `update_block_filter` /
--- `has_block_filter` under test.
function factorio.set_filter_item(name)
  filter_item = name
end

function factorio.set_tick(tick)
  _G.game.tick = tick
end

local EPS = 0.01

-- Tile footprint per entity type as {along-flow, across-flow}. The real API's
-- `find_entities_filtered{position=}` returns any entity whose box contains the
-- point, so a 2x1 splitter/loader is matched on either of its two tiles even
-- though its `position` (centre) sits on the tile edge.
local FOOTPRINT = {
  ["transport-belt"] = { 1, 1 },
  ["underground-belt"] = { 1, 1 },
  ["loader-1x1"] = { 1, 1 },
  ["loader"] = { 2, 1 },
  ["splitter"] = { 1, 2 },
}

--- {left, top, right, bottom} tile-footprint box for a fake entity.
local function entity_box(e)
  local fp = FOOTPRINT[e.type] or { 1, 1 }
  local along, across = fp[1], fp[2]
  local horizontal = e.direction == _G.defines.direction.east or e.direction == _G.defines.direction.west
  local half_x = (horizontal and along or across) / 2
  local half_y = (horizontal and across or along) / 2
  return e.position.x - half_x, e.position.y - half_y, e.position.x + half_x, e.position.y + half_y
end

local function box_contains(e, point)
  if not (e.position and point) then
    return false
  end
  local left, top, right, bottom = entity_box(e)
  return point.x >= left - EPS and point.x <= right + EPS and point.y >= top - EPS and point.y <= bottom + EPS
end

-- Inclusive on both edges, unlike Factorio's exclusive far edge. Harmless for
-- the +/-2 area query find_affecting_splitters uses.
local function in_area(pos, area)
  return pos.x >= area[1][1] and pos.x <= area[2][1] and pos.y >= area[1][2] and pos.y <= area[2][2]
end

local function type_matches(entity_type, query_type)
  if query_type == nil then
    return true
  end
  if type(query_type) == "table" then
    for _, t in ipairs(query_type) do
      if t == entity_type then
        return true
      end
    end
    return false
  end
  return query_type == entity_type
end

--- A surface whose find_entities_filtered searches `opts.entities` (a table you
--- may keep mutating, since the search reads it live).
function factorio.surface(opts)
  opts = opts or {}
  local entities = opts.entities or {}
  return {
    find_entities_filtered = function(query)
      local matches = {}
      for _, e in ipairs(entities) do
        local ok = type_matches(e.type, query.type)
        if ok and query.position then
          ok = box_contains(e, query.position)
        end
        if ok and query.area then
          ok = in_area(e.position, query.area)
        end
        if ok then
          matches[#matches + 1] = e
          if query.limit and #matches >= query.limit then
            break
          end
        end
      end
      return matches
    end,
  }
end

--- A surface plus a mutable entity list. `w.add(entity)` registers an entity so
--- `w.surface.find_entities_filtered` sees it, defaulting its `surface` field to
--- `w.surface`. `w.remove(entity)` deregisters it. Both return the entity. The
--- surface is also pushed onto `game.surfaces`.
function factorio.world()
  local entities = {}
  local surface = factorio.surface({ entities = entities })
  _G.game.surfaces[#_G.game.surfaces + 1] = surface
  return {
    surface = surface,
    add = function(entity)
      entity.surface = entity.surface or surface
      entities[#entities + 1] = entity
      return entity
    end,
    remove = function(entity)
      for i, e in ipairs(entities) do
        if e == entity then
          table.remove(entities, i)
          break
        end
      end
      return entity
    end,
  }
end

-- Engine connection rules, as measured in Factorio 2.1 by reading
-- belt_neighbours.outputs of a splitter with each candidate on an output tile.
-- Only the fake encodes them; the MOD asks the engine.
local function receives_from_splitter(e, splitter_dir)
  local opposite = (splitter_dir + 8) % 16
  if e.type == "transport-belt" then
    return e.direction ~= opposite
  elseif e.type == "underground-belt" then
    if e.belt_to_ground_type == "output" then
      return e.direction ~= opposite and e.direction ~= splitter_dir
    end
    return e.direction ~= opposite
  elseif e.type == "splitter" or e.type == "lane-splitter" then
    return e.direction == splitter_dir
  elseif e.type == "loader" or e.type == "loader-1x1" then
    return e.loader_type == "input" and e.direction == splitter_dir
  elseif e.type == "linked-belt" then
    return e.linked_belt_type == "input" and e.direction == splitter_dir
  end
  return false
end

local FORWARD = { [0] = { 0, -1 }, [4] = { 1, 0 }, [8] = { 0, 1 }, [12] = { -1, 0 } }

-- Computed on each read so it tracks entities added to or removed from the world.
-- An entity covering both output tiles appears once per tile.
local function belt_neighbours(splitter)
  local fx, fy = FORWARD[splitter.direction][1], FORWARD[splitter.direction][2]
  local outputs = {}
  for _, side in ipairs({ -0.5, 0.5 }) do
    local tile = {
      x = splitter.position.x + fx - fy * side,
      y = splitter.position.y + fy + fx * side,
    }
    for _, e in ipairs(splitter.surface.find_entities_filtered({ position = tile })) do
      if e ~= splitter and receives_from_splitter(e, splitter.direction) then
        outputs[#outputs + 1] = e
      end
    end
  end
  return { inputs = {}, outputs = outputs }
end

--- A fake splitter usable with lib/splitter_utils.lua.
function factorio.splitter(opts)
  opts = opts or {}
  next_unit_number = next_unit_number + 1
  local circuit = opts.circuit
  local splitter = {
    valid = true,
    type = opts.type or "splitter",
    unit_number = opts.unit_number or next_unit_number,
    position = opts.position or { x = 0, y = 0 },
    direction = opts.direction or _G.defines.direction.north,
    surface = opts.surface,
    splitter_filter = opts.splitter_filter, -- nil, a string, or { name = ... }
    splitter_output_priority = opts.priority or "none",
    get_circuit_network = function(wire)
      if wire == _G.defines.wire_type.red and (circuit == "red" or circuit == "both") then
        return {}
      end
      if wire == _G.defines.wire_type.green and (circuit == "green" or circuit == "both") then
        return {}
      end
      return nil
    end,
  }
  return setmetatable(splitter, {
    __index = function(self, key)
      if key == "belt_neighbours" then
        return belt_neighbours(self)
      end
    end,
  })
end

--- A fake 1x1 transport belt. `surface` is needed when the belt is the argument
--- to find_affecting_splitters (which reads entity.surface). `opts.type`
--- overrides "transport-belt" (e.g. "loader-1x1").
function factorio.belt(opts)
  opts = opts or {}
  return {
    valid = true,
    type = opts.type or "transport-belt",
    direction = opts.direction or _G.defines.direction.north,
    position = opts.position or { x = 0, y = 0 },
    surface = opts.surface,
  }
end

--- A fake underground belt. `belt_to_ground_type` is "input" (default) or "output".
function factorio.underground_belt(opts)
  opts = opts or {}
  local belt = factorio.belt(opts)
  belt.type = "underground-belt"
  belt.belt_to_ground_type = opts.belt_to_ground_type or "input"
  return belt
end

--- A fake linked belt. `linked_belt_type` is "input" (default) or "output".
function factorio.linked_belt(opts)
  opts = opts or {}
  local belt = factorio.belt(opts)
  belt.type = "linked-belt"
  belt.linked_belt_type = opts.linked_belt_type or "input"
  return belt
end

--- A fake loader, 2x1 unless `opts.type` is "loader-1x1". `loader_type` is
--- "input" (default) or "output".
function factorio.loader(opts)
  opts = opts or {}
  local loader = factorio.belt(opts)
  loader.type = opts.type or "loader"
  loader.loader_type = opts.loader_type or "input"
  return loader
end

factorio.reset()

return factorio
