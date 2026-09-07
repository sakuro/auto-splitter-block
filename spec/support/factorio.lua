--- Minimal Factorio runtime fakes for busted specs. `require` this before the
--- module under test and call `factorio.reset()` in `before_each`.
local factorio = {}

local DEFAULT_FILTER_ITEM = "no-item"
local filter_item
local next_unit_number

_G.defines = {
  direction = { north = 0, east = 4, south = 8, west = 12 },
  wire_type = { red = 1, green = 2 },
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
  _G.storage = { saved_priorities = {} }
  _G.game = { tick = 1 }
end

--- Change the startup filter item. `lib/splitter_utils.lua` caches it into
--- BLOCK_FILTER at require time, so this only affects modules required after the
--- change; for already-required code it changes what `settings.startup` reports.
function factorio.set_filter_item(name)
  filter_item = name
end

function factorio.set_tick(tick)
  _G.game.tick = tick
end

local function positions_near(a, b)
  return a ~= nil and b ~= nil
    and math.abs(a.x - b.x) < 0.01
    and math.abs(a.y - b.y) < 0.01
end

local function in_area(pos, area)
  return pos.x >= area[1][1] and pos.x <= area[2][1]
    and pos.y >= area[1][2] and pos.y <= area[2][2]
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
--- may keep mutating -- the search reads it live).
function factorio.surface(opts)
  opts = opts or {}
  local entities = opts.entities or {}
  return {
    find_entities_filtered = function(query)
      local matches = {}
      for _, e in ipairs(entities) do
        local ok = type_matches(e.type, query.type)
        if ok and query.position then
          ok = positions_near(e.position, query.position)
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
--- `w.surface`. Returns the entity.
function factorio.world()
  local entities = {}
  local surface = factorio.surface({ entities = entities })
  return {
    surface = surface,
    add = function(entity)
      entity.surface = entity.surface or surface
      entities[#entities + 1] = entity
      return entity
    end,
  }
end

--- A fake splitter usable with lib/splitter_utils.lua.
function factorio.splitter(opts)
  opts = opts or {}
  next_unit_number = next_unit_number + 1
  local circuit = opts.circuit
  return {
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
end

--- A fake transport belt. `surface` is needed when the belt is the argument to
--- find_affecting_splitters (which reads entity.surface).
function factorio.belt(opts)
  opts = opts or {}
  return {
    valid = true,
    type = "transport-belt",
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

factorio.reset()

return factorio
