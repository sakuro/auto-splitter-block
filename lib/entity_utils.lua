local BELT_TYPES = {["transport-belt"] = true, ["underground-belt"] = true}
local STRICT_TYPES = {["splitter"] = true, ["loader"] = true, ["loader-1x1"] = true}

local ALL_TRANSPORT_TYPES = {}
for k in pairs(BELT_TYPES) do ALL_TRANSPORT_TYPES[k] = true end
for k in pairs(STRICT_TYPES) do ALL_TRANSPORT_TYPES[k] = true end

local function is_transport_entity(entity)
  return ALL_TRANSPORT_TYPES[entity.type] or false
end

-- Transport belts/underground belt inputs: any direction except opposite (facing back into splitter)
-- Underground belt outputs: side-loading (perpendicular) is compatible, but same direction as splitter is not
-- Splitters/loaders: same direction only
local function is_output_compatible(entity, splitter_dir)
  local entity_type = entity.type
  if BELT_TYPES[entity_type] then
    if entity_type == "underground-belt"
       and entity.belt_to_ground_type == "output"
       and entity.direction == splitter_dir then
      return false
    end
    return (entity.direction + 8) % 16 ~= splitter_dir
  elseif STRICT_TYPES[entity_type] then
    return entity.direction == splitter_dir
  end
  return false
end

return {
  is_transport_entity = is_transport_entity,
  is_output_compatible = is_output_compatible,
}
