local entity_utils = require("lib.entity_utils")

local BLOCK_FILTER = settings.startup["auto-splitter-block-filter-item"].value

-- {left_dx, left_dy, right_dx, right_dy}
local OUTPUT_OFFSETS = {
  [defines.direction.north] = {-0.5, -1,  0.5, -1},
  [defines.direction.east]  = { 1, -0.5,  1,  0.5},
  [defines.direction.south] = { 0.5,  1, -0.5,  1},
  [defines.direction.west]  = {-1,  0.5, -1, -0.5},
}

local function positions_match(pos_a, pos_b)
  return math.abs(pos_a.x - pos_b.x) < 0.01
     and math.abs(pos_a.y - pos_b.y) < 0.01
end

local function get_output_positions(splitter)
  local pos = splitter.position
  local offsets = OUTPUT_OFFSETS[splitter.direction]
  local left_pos  = {x = pos.x + offsets[1], y = pos.y + offsets[2]}
  local right_pos = {x = pos.x + offsets[3], y = pos.y + offsets[4]}
  return left_pos, right_pos
end

local function is_circuit_controlled(splitter)
  return splitter.get_circuit_network(defines.wire_type.red) ~= nil
      or splitter.get_circuit_network(defines.wire_type.green) ~= nil
end

-- exclude_entity: entity to ignore (used during removal events)
local function has_compatible_entity_at(surface, position, splitter_dir, exclude_entity)
  local entities = surface.find_entities_filtered{
    position = position,
    type = {"transport-belt", "underground-belt", "splitter", "loader", "loader-1x1"},
  }
  for _, entity in ipairs(entities) do
    if entity ~= exclude_entity and
       entity_utils.is_output_compatible(entity, splitter_dir) then
      return true
    end
  end
  return false
end

-- 1x1 entities: single position. 2x1 entities (splitter, loader): two positions.
local function get_tile_positions(entity)
  local pos = entity.position
  local etype = entity.type
  if etype == "splitter" or etype == "loader" then
    local dir = entity.direction
    if dir == defines.direction.north or dir == defines.direction.south then
      return {{x = pos.x - 0.5, y = pos.y}, {x = pos.x + 0.5, y = pos.y}}
    else
      return {{x = pos.x, y = pos.y - 0.5}, {x = pos.x, y = pos.y + 0.5}}
    end
  end
  return {{x = pos.x, y = pos.y}}
end

local function find_affecting_splitters(entity)
  local pos = entity.position
  local tile_positions = get_tile_positions(entity)
  local splitters = entity.surface.find_entities_filtered{
    type = "splitter",
    area = {{pos.x - 2, pos.y - 2}, {pos.x + 2, pos.y + 2}},
  }
  local result = {}
  for _, splitter in ipairs(splitters) do
    if splitter ~= entity then
      local left_pos, right_pos = get_output_positions(splitter)
      for _, tile_pos in ipairs(tile_positions) do
        if positions_match(tile_pos, left_pos) or positions_match(tile_pos, right_pos) then
          result[#result + 1] = splitter
          break
        end
      end
    end
  end
  return result
end

local function has_block_filter(splitter)
  local filter = splitter.splitter_filter
  if not filter then return false end
  local name = type(filter) == "string" and filter or filter.name
  return name == BLOCK_FILTER
end

local function set_block_filter(splitter, side)
  local id = splitter.unit_number
  -- Save the user's priority so clear_block_filter can restore it. Keyed by
  -- unit_number and kept until the matching clear -- a block and its clear are
  -- usually ticks or minutes apart, whenever the other output side gets
  -- (dis)connected. register_on_object_destroyed lets the engine tell us when
  -- the splitter is gone so the entry cannot leak (biters, explosions, script
  -- removal -- the mining events do not cover those).
  if storage.saved_priorities[id] == nil then
    storage.saved_priorities[id] = splitter.splitter_output_priority
    script.register_on_object_destroyed(splitter)
  end
  splitter.splitter_filter = BLOCK_FILTER
  splitter.splitter_output_priority = side
end

local function clear_block_filter(splitter)
  local id = splitter.unit_number
  local saved = storage.saved_priorities[id]
  storage.saved_priorities[id] = nil
  splitter.splitter_filter = nil
  -- A non-string value can only be legacy junk (pre-0.7 saved a { priority = }
  -- table); fall back to "none" rather than hand it to the API.
  splitter.splitter_output_priority = type(saved) == "string" and saved or "none"
end

local function discard_saved_priority(unit_number)
  storage.saved_priorities[unit_number] = nil
end

--- Rebuild storage.saved_priorities from the live world, keeping one entry per
--- splitter that currently carries the block filter (its priority read from the
--- old entry, string or legacy { priority = } table; dropped when unrecoverable).
--- Clears the legacy table-level `tick` key and entries orphaned by a removed
--- splitter, and re-registers the survivors for on_object_destroyed. Idempotent;
--- run from on_configuration_changed.
local function sanitize_saved_priorities()
  local old = storage.saved_priorities or {}
  local fresh = {}

  for _, surface in pairs(game.surfaces) do
    for _, splitter in pairs(surface.find_entities_filtered{type = "splitter"}) do
      if has_block_filter(splitter) then
        local saved = old[splitter.unit_number]
        if type(saved) == "table" then
          saved = saved.priority
        end
        if type(saved) == "string" then
          fresh[splitter.unit_number] = saved
          script.register_on_object_destroyed(splitter)
        end
      end
    end
  end

  storage.saved_priorities = fresh
end

local function update_block_filter(splitter, exclude_entity)
  local surface = splitter.surface
  local dir = splitter.direction
  local left_pos, right_pos = get_output_positions(splitter)

  local has_left = has_compatible_entity_at(surface, left_pos, dir, exclude_entity)
  local has_right = has_compatible_entity_at(surface, right_pos, dir, exclude_entity)

  if has_left == has_right and has_block_filter(splitter) then
    clear_block_filter(splitter)
  elseif has_left and not has_right and not splitter.splitter_filter then
    set_block_filter(splitter, "right")
  elseif has_right and not has_left and not splitter.splitter_filter then
    set_block_filter(splitter, "left")
  end
end

return {
  is_circuit_controlled = is_circuit_controlled,
  find_affecting_splitters = find_affecting_splitters,
  has_block_filter = has_block_filter,
  clear_block_filter = clear_block_filter,
  discard_saved_priority = discard_saved_priority,
  sanitize_saved_priorities = sanitize_saved_priorities,
  update_block_filter = update_block_filter,
}
