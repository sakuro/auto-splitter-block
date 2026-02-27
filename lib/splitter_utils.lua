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
       entity_utils.is_output_compatible(entity.type, entity.direction, splitter_dir) then
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
  splitter.splitter_filter = BLOCK_FILTER
  splitter.splitter_output_priority = side
end

local function clear_block_filter(splitter)
  splitter.splitter_filter = nil
  splitter.splitter_output_priority = "none"
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
  update_block_filter = update_block_filter,
}
