local BELT_TYPES = {["transport-belt"] = true, ["underground-belt"] = true}
local STRICT_TYPES = {["splitter"] = true, ["loader"] = true, ["loader-1x1"] = true}

local ALL_TRANSPORT_TYPES = {}
for k in pairs(BELT_TYPES) do ALL_TRANSPORT_TYPES[k] = true end
for k in pairs(STRICT_TYPES) do ALL_TRANSPORT_TYPES[k] = true end

local function is_transport_entity(entity)
  return ALL_TRANSPORT_TYPES[entity.type] or false
end

-- Belts/underground belts: any direction except opposite (facing back into splitter)
-- Splitters/loaders: same direction only
local function is_output_compatible(entity_type, entity_dir, splitter_dir)
  if BELT_TYPES[entity_type] then
    return (entity_dir + 8) % 16 ~= splitter_dir
  elseif STRICT_TYPES[entity_type] then
    return entity_dir == splitter_dir
  end
  return false
end

return {
  is_transport_entity = is_transport_entity,
  is_output_compatible = is_output_compatible,
}
