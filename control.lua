local splitter_utils = require("lib.splitter_utils")
local entity_utils = require("lib.entity_utils")

local function on_splitter_placed(splitter)
  if splitter_utils.is_circuit_controlled(splitter) then return end
  splitter_utils.update_block_filter(splitter)
end

local function on_transport_placed(entity)
  local splitters = splitter_utils.find_affecting_splitters(entity)
  for _, splitter in ipairs(splitters) do
    if splitter_utils.is_circuit_controlled(splitter) then goto continue end
    splitter_utils.update_block_filter(splitter)
    ::continue::
  end
end

local function on_transport_removed(entity)
  local splitters = splitter_utils.find_affecting_splitters(entity)
  for _, splitter in ipairs(splitters) do
    if splitter_utils.is_circuit_controlled(splitter) then goto continue end
    splitter_utils.update_block_filter(splitter, entity)
    ::continue::
  end
end

local function on_splitter_orientation_changed(event)
  local splitter = event.entity
  if splitter.type ~= "splitter" then return end
  if splitter_utils.is_circuit_controlled(splitter) then return end

  if splitter_utils.has_block_filter(splitter) then
    splitter_utils.clear_block_filter(splitter)
  elseif splitter.splitter_filter then
    return
  end

  splitter_utils.update_block_filter(splitter)
end

local function is_automated_build_enabled()
  return settings.global["auto-splitter-block-enable-for-automated-builds"].value
end

local function on_entity_built(event)
  local entity = event.entity
  if entity.type == "splitter" then
    on_splitter_placed(entity)
  end
  if entity_utils.is_transport_entity(entity) then
    on_transport_placed(entity)
  end
end

local function on_entity_built_automated(event)
  if not is_automated_build_enabled() then return end
  on_entity_built(event)
end

local function on_entity_removed(event)
  local entity = event.entity
  if entity_utils.is_transport_entity(entity) then
    on_transport_removed(entity)
  end
end

local function on_entity_removed_automated(event)
  if not is_automated_build_enabled() then return end
  on_entity_removed(event)
end

local ENTITY_FILTER = {
  {filter = "type", type = "splitter"},
  {filter = "type", type = "transport-belt"},
  {filter = "type", type = "underground-belt"},
  {filter = "type", type = "loader"},
  {filter = "type", type = "loader-1x1"},
}

script.on_event(defines.events.on_built_entity, on_entity_built, ENTITY_FILTER)
script.on_event(defines.events.on_robot_built_entity, on_entity_built_automated, ENTITY_FILTER)
script.on_event(defines.events.on_space_platform_built_entity, on_entity_built_automated, ENTITY_FILTER)

script.on_event(defines.events.on_player_mined_entity, on_entity_removed, ENTITY_FILTER)
script.on_event(defines.events.on_robot_mined_entity, on_entity_removed_automated, ENTITY_FILTER)
script.on_event(defines.events.on_space_platform_mined_entity, on_entity_removed_automated, ENTITY_FILTER)

script.on_event(defines.events.on_player_rotated_entity, on_splitter_orientation_changed)
script.on_event(defines.events.on_player_flipped_entity, on_splitter_orientation_changed)
