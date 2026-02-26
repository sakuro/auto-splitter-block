local allowed_values = {"deconstruction-planner"}
local default_filter_item = "deconstruction-planner"

if mods["atan-null"] then
  table.insert(allowed_values, "atan-null")
  default_filter_item = "atan-null"
end

data:extend({
  {
    type = "string-setting",
    name = "auto-splitter-block-filter-item",
    setting_type = "startup",
    default_value = default_filter_item,
    allowed_values = allowed_values,
    order = "a",
  }
})
