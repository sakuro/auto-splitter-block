local setting = {
  type = "string-setting",
  name = "auto-splitter-block-filter-item",
  setting_type = "startup",
  default_value = "deconstruction-planner",
  allowed_values = {"deconstruction-planner"},
  order = "a",
}

if mods["atan-null"] then
  table.insert(setting.allowed_values, "atan-null")
  setting.default_value = "atan-null"
end

setting.hidden = #setting.allowed_values <= 1

data:extend({setting})
