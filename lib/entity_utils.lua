local ALL_TRANSPORT_TYPES = {
  ["transport-belt"] = true,
  ["underground-belt"] = true,
  ["splitter"] = true,
  ["loader"] = true,
  ["loader-1x1"] = true,
}

--- True when the entity is a belt, underground belt, splitter, or loader.
---@param entity LuaEntity
---@return boolean
local function is_transport_entity(entity)
  return ALL_TRANSPORT_TYPES[entity.type] or false
end

return {
  is_transport_entity = is_transport_entity,
}
