local setting = {
  type = "string-setting",
  name = "auto-splitter-block-filter-item",
  setting_type = "startup",
  default_value = "no-item",
  allowed_values = {"no-item", "deconstruction-planner"},
  order = "a",
}

if mods["atan-null"] then
  table.insert(setting.allowed_values, "atan-null")
end

if mods["null"] then
  table.insert(setting.allowed_values, "null")
end

data:extend({
  setting,
  {
    type = "bool-setting",
    name = "auto-splitter-block-enable-for-automated-builds",
    setting_type = "runtime-global",
    default_value = false,
    order = "b",
  },
})
