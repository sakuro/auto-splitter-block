local splitter_utils = require("lib.splitter_utils")
local entity_utils = require("lib.entity_utils")

local function on_splitter_placed(splitter)
  if splitter_utils.is_circuit_controlled(splitter) then return end

  local surface = splitter.surface
  local dir = splitter.direction
  local left_pos, right_pos = splitter_utils.get_output_positions(splitter)

  local has_left = splitter_utils.has_compatible_entity_at(surface, left_pos, dir)
  local has_right = splitter_utils.has_compatible_entity_at(surface, right_pos, dir)

  if has_left and not has_right then
    splitter_utils.set_block_filter(splitter, "right")
  elseif has_right and not has_left then
    splitter_utils.set_block_filter(splitter, "left")
  end
end

local function on_transport_placed(entity)
  local splitters = splitter_utils.find_affecting_splitters(entity)
  for _, splitter in ipairs(splitters) do
    if not splitter_utils.is_circuit_controlled(splitter) then
      local surface = splitter.surface
      local dir = splitter.direction
      local left_pos, right_pos = splitter_utils.get_output_positions(splitter)

      local has_left = splitter_utils.has_compatible_entity_at(surface, left_pos, dir)
      local has_right = splitter_utils.has_compatible_entity_at(surface, right_pos, dir)

      if has_left and has_right and splitter.splitter_filter then
        splitter_utils.clear_block_filter(splitter)
      elseif has_left and not has_right then
        splitter_utils.set_block_filter(splitter, "right")
      elseif has_right and not has_left then
        splitter_utils.set_block_filter(splitter, "left")
      end
    end
  end
end

local function on_transport_removed(entity)
  local splitters = splitter_utils.find_affecting_splitters(entity)
  for _, splitter in ipairs(splitters) do
    if not splitter_utils.is_circuit_controlled(splitter) then
      local surface = splitter.surface
      local dir = splitter.direction
      local left_pos, right_pos = splitter_utils.get_output_positions(splitter)

      local has_left = splitter_utils.has_compatible_entity_at(surface, left_pos, dir, entity)
      local has_right = splitter_utils.has_compatible_entity_at(surface, right_pos, dir, entity)

      if not has_left and not has_right then
        splitter_utils.clear_block_filter(splitter)
      elseif has_left and not has_right and not splitter.splitter_filter then
        splitter_utils.set_block_filter(splitter, "right")
      elseif has_right and not has_left and not splitter.splitter_filter then
        splitter_utils.set_block_filter(splitter, "left")
      end
    end
  end
end

local function on_entity_built(event)
  local entity = event.entity
  if entity.type == "splitter" then
    on_splitter_placed(entity)
  elseif entity_utils.is_transport_entity(entity) then
    on_transport_placed(entity)
  end
end

local function on_entity_removed(event)
  local entity = event.entity
  if entity_utils.is_transport_entity(entity) then
    on_transport_removed(entity)
  end
end

local ENTITY_FILTER = {
  {filter = "type", type = "splitter"},
  {filter = "type", type = "transport-belt"},
  {filter = "type", type = "underground-belt"},
  {filter = "type", type = "loader"},
  {filter = "type", type = "loader-1x1"},
}

script.on_event(defines.events.on_built_entity, on_entity_built, ENTITY_FILTER)
script.on_event(defines.events.on_robot_built_entity, on_entity_built, ENTITY_FILTER)
script.on_event(defines.events.on_space_platform_built_entity, on_entity_built, ENTITY_FILTER)

script.on_event(defines.events.on_player_mined_entity, on_entity_removed, ENTITY_FILTER)
script.on_event(defines.events.on_robot_mined_entity, on_entity_removed, ENTITY_FILTER)
script.on_event(defines.events.on_space_platform_mined_entity, on_entity_removed, ENTITY_FILTER)
