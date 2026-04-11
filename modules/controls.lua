------------------------------------------------------
-- WindowUtils - Controls Aggregator
-- Thin merge of all sub-modules into a single table
------------------------------------------------------

local core = require("modules/controls/core")
local controls = {}

-- Copy core exports
for k, v in pairs(core) do controls[k] = v end

-- Load sub-modules in dependency order, merge exports
local submodules = {
    "modules/controls/display",
    "modules/controls/buttons",
    "modules/controls/sliders",
    "modules/controls/holdbuttons",
    "modules/controls/inputs",
    "modules/controls/drags",
    "modules/controls/layout",
    "modules/controls/panels",
}
for _, path in ipairs(submodules) do
    for k, v in pairs(require(path)) do
        controls[k] = v
    end
end

-- Bind is last: receives full controls table
local bind = require("modules/controls/bind")
bind.init(controls)
for k, v in pairs(bind.exports) do controls[k] = v end

return controls
