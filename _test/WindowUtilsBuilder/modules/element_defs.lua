------------------------------------------------------
-- WindowUtils Builder - Element Definitions
-- Registry of all element types with default properties
------------------------------------------------------

local element_defs = {}

local registry = {}

local function reg(typeName, category, idPrefix, defaultProps, zones)
    registry[typeName] = {
        category = category,
        idPrefix = idPrefix,
        defaultProps = defaultProps,
        zones = zones,
    }
end

-- Buttons
reg("Button", "Buttons", "btn", {
    label = "Button", style = "inactive", width = -1, height = 0, tooltip = nil, icon = nil,
})
reg("ToggleButton", "Buttons", "tog", {
    label = "Toggle", style = "inactive", width = -1, height = 0, tooltip = nil,
})
reg("DynamicButton", "Buttons", "dyn", {
    label = "Dynamic", icon = nil, style = "inactive", width = -1, height = 0, minChars = 3, tooltip = nil,
})
reg("HoldButton", "Buttons", "hold", {
    label = "Hold", duration = 1.0, style = "inactive", width = -1, height = 0, tooltip = nil,
})
reg("ActionButton", "Buttons", "act", {
    label = "Action", style = "inactive", width = -1, height = 0, holdDuration = 0, tooltip = nil,
})
reg("ButtonRow", "Buttons", "btnrow", {
    gap = nil,
    buttons = {
        { label = "Button 1", style = "inactive", weight = 1 },
        { label = "Button 2", style = "inactive", weight = 1 },
    },
})
reg("DisabledButton", "Buttons", "disbtn", {
    label = "Disabled", width = -1, height = 0,
})
reg("FullWidthButton", "Buttons", "fwbtn", {
    label = "Full Width", style = "inactive",
})
reg("IconButton", "Buttons", "icbtn", {
    icon = nil, clickable = false, tooltip = nil,
})

-- Sliders
reg("SliderFloat", "Sliders", "sf", {
    icon = nil, min = 0, max = 1, default = nil, format = "%.2f", cols = nil, tooltip = nil,
})
reg("SliderInt", "Sliders", "si", {
    icon = nil, min = 0, max = 100, default = nil, format = "%d", cols = nil, tooltip = nil,
})
reg("SliderDisabled", "Sliders", "sd", {
    icon = nil, label = "Disabled",
})

-- Drags
reg("DragFloat", "Drags", "df", {
    icon = nil, min = 0, max = 1, speed = nil, default = nil, format = "%.2f", cols = nil, tooltip = nil,
})
reg("DragInt", "Drags", "di", {
    icon = nil, min = 0, max = 100, speed = nil, default = nil, format = "%d", cols = nil, tooltip = nil,
})
reg("DragFloatRow", "Drags", "dfr", {
    icon = nil, min = 0, max = 1, speed = nil, format = "%.2f", cols = nil, tooltip = nil,
})
reg("DragIntRow", "Drags", "dir", {
    icon = nil, min = 0, max = 100, speed = nil, format = "%d", cols = nil, tooltip = nil,
})

-- Inputs
reg("InputText", "Inputs", "itxt", {
    icon = nil, maxLength = 256, cols = nil, tooltip = nil,
})
reg("InputFloat", "Inputs", "iflt", {
    icon = nil, default = nil, format = "%.2f", cols = nil, tooltip = nil,
})
reg("InputInt", "Inputs", "iint", {
    icon = nil, default = nil, cols = nil, tooltip = nil,
})

-- Selection
reg("Checkbox", "Selection", "chk", {
    label = "Checkbox", default = false, tooltip = nil,
})
reg("Combo", "Selection", "cmb", {
    icon = nil, items = { "Option 1", "Option 2" }, default = nil, cols = nil, tooltip = nil,
})
reg("ColorEdit4", "Selection", "clr", {
    icon = nil, default = { 1, 1, 1, 1 }, tooltip = nil,
})

-- Display
reg("ProgressBar", "Display", "prog", {
    fraction = 0.5, width = nil, height = 0, overlay = "", style = "default",
})
reg("StatusBar", "Display", "stat", {
    label = "Status", value = nil, style = "statusbar",
})
reg("TextMuted", "Display", "tmut", { text = "Muted text" })
reg("TextSuccess", "Display", "tsuc", { text = "Success text" })
reg("TextDanger", "Display", "tdan", { text = "Danger text" })
reg("TextWarning", "Display", "twrn", { text = "Warning text" })
reg("SectionHeader", "Display", "shdr", {
    text = "Section", spacingBefore = nil, spacingAfter = nil, icon = nil,
})
reg("Separator", "Display", "sep", {
    before = nil, after = nil,
})

-- Layout (containers with zones)
reg("SplitterH", "Layout", "splh", {
    defaultPct = 0.5, minPct = 0.1, maxPct = 0.9,
}, {
    { label = "Left", children = {} },
    { label = "Right", children = {} },
})
reg("SplitterV", "Layout", "splv", {
    defaultPct = 0.5, minPct = 0.1, maxPct = 0.9,
}, {
    { label = "Top", children = {} },
    { label = "Bottom", children = {} },
})
reg("SplitterMulti", "Layout", "splm", {
    direction = "horizontal", grabWidth = nil,
}, {
    { label = "Panel 1", children = {} },
    { label = "Panel 2", children = {} },
    { label = "Panel 3", children = {} },
})
reg("SplitterToggle", "Layout", "splt", {
    side = "left", size = 200, barWidth = nil, defaultOpen = true,
}, {
    { label = "Toggle", children = {} },
    { label = "Content", children = {} },
})
reg("Tabs", "Layout", "tabs", {
    flags = 0,
}, {
    { label = "Tab 1", children = {} },
    { label = "Tab 2", children = {} },
})
reg("Panel", "Layout", "pnl", {
    bg = nil, border = false, borderOnHover = false, width = 0, height = "auto",
}, {
    { label = "Content", children = {} },
})
reg("Column", "Layout", "col", {
    spacing = nil,
}, {
    { label = "Slot 1", children = {} },
    { label = "Slot 2", children = {} },
})
reg("Row", "Layout", "row", {
    spacing = nil,
}, {
    { label = "Slot 1", children = {} },
    { label = "Slot 2", children = {} },
})

-- Advanced
reg("Lists", "Advanced", "lst", { id = "list" })
reg("Search", "Advanced", "srch", { id = "search", placeholder = "Search..." })
reg("Modal", "Advanced", "mdl", { title = "Modal", width = 300, height = 200 })
reg("Notifications", "Advanced", "notif", { level = "info", message = "Notification" })
reg("DragDrop", "Advanced", "dd", { id = "dragdrop" })

--------------------------------------------------------------------------------
-- Category ordering
--------------------------------------------------------------------------------

local categories = {
    { name = "Buttons",   types = { "Button", "ToggleButton", "DynamicButton", "HoldButton", "ActionButton", "ButtonRow", "DisabledButton", "FullWidthButton", "IconButton" } },
    { name = "Sliders",   types = { "SliderFloat", "SliderInt", "SliderDisabled" } },
    { name = "Drags",     types = { "DragFloat", "DragInt", "DragFloatRow", "DragIntRow" } },
    { name = "Inputs",    types = { "InputText", "InputFloat", "InputInt" } },
    { name = "Selection", types = { "Checkbox", "Combo", "ColorEdit4" } },
    { name = "Display",   types = { "ProgressBar", "StatusBar", "TextMuted", "TextSuccess", "TextDanger", "TextWarning", "SectionHeader", "Separator" } },
    { name = "Layout",    types = { "SplitterH", "SplitterV", "SplitterMulti", "SplitterToggle", "Tabs", "Panel", "Column", "Row" } },
    { name = "Advanced",  types = { "Lists", "Search", "Modal", "Notifications", "DragDrop" } },
}

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Get element definition by type name
---@param typeName string
---@return table|nil { category, idPrefix, defaultProps, zones? }
function element_defs.get(typeName)
    return registry[typeName]
end

--- Get the ID prefix for a type
---@param typeName string
---@return string|nil
function element_defs.getIdPrefix(typeName)
    local def = registry[typeName]
    return def and def.idPrefix or nil
end

--- Get ordered category list with their element types
---@return table[] { { name, types } }
function element_defs.getCategories()
    return categories
end

--- Get all registered type names
---@return string[]
function element_defs.getAllTypes()
    local result = {}
    for typeName in pairs(registry) do
        result[#result + 1] = typeName
    end
    return result
end

return element_defs
