local BELT_TYPES = { ["transport-belt"] = true, ["underground-belt"] = true }
local STRICT_TYPES = { ["splitter"] = true, ["loader"] = true, ["loader-1x1"] = true }

local ALL_TRANSPORT_TYPES = {}
for k in pairs(BELT_TYPES) do
  ALL_TRANSPORT_TYPES[k] = true
end
for k in pairs(STRICT_TYPES) do
  ALL_TRANSPORT_TYPES[k] = true
end

--- True when the entity is a belt, underground belt, splitter, or loader.
---@param entity LuaEntity
---@return boolean
local function is_transport_entity(entity)
  return ALL_TRANSPORT_TYPES[entity.type] or false
end

--- True when the entity can take items from a splitter output facing splitter_dir.
---
--- Transport belts and underground belt inputs accept any direction except the
--- opposite one, which faces back into the splitter. Underground belt outputs
--- accept side-loading (perpendicular) but not the splitter's own direction.
--- Splitters and loaders accept the same direction only.
---@param entity LuaEntity
---@param splitter_dir defines.direction
---@return boolean
local function is_output_compatible(entity, splitter_dir)
  local entity_type = entity.type
  if BELT_TYPES[entity_type] then
    if
      entity_type == "underground-belt"
      and entity.belt_to_ground_type == "output"
      and entity.direction == splitter_dir
    then
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
