------------------------------------------------------
-- WindowUtils Builder - Export Engine
-- Generates a complete CET mod init.lua
------------------------------------------------------

local element_defs = require("modules/element_defs")

local export = {}

-- Value-producing element types that get data/defaults entries
local VALUE_TYPES = {
    SliderFloat = true, SliderInt = true,
    DragFloat = true, DragInt = true,
    InputText = true, InputFloat = true, InputInt = true,
    Checkbox = true, Combo = true, ColorEdit4 = true,
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function indent(level)
    return string.rep("    ", level)
end

local function quote(s)
    return '"' .. tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
end

local function formatValue(v)
    if type(v) == "string" then return quote(v)
    elseif type(v) == "boolean" then return tostring(v)
    elseif type(v) == "number" then return tostring(v)
    elseif type(v) == "table" then
        local parts = {}
        for _, item in ipairs(v) do
            parts[#parts + 1] = formatValue(item)
        end
        return "{ " .. table.concat(parts, ", ") .. " }"
    end
    return "nil"
end

--------------------------------------------------------------------------------
-- Per-element code emitters
--------------------------------------------------------------------------------

local emitters = {}

local function emitOpts(parts, p, keys)
    local opts = {}
    for _, k in ipairs(keys) do
        if p[k] ~= nil then
            opts[#opts + 1] = k .. " = " .. formatValue(p[k])
        end
    end
    if #opts > 0 then
        return "{ " .. table.concat(opts, ", ") .. " }"
    end
    return nil
end

emitters["Button"] = function(el, lvl)
    local p = el.props
    return indent(lvl) .. "controls.Button(" .. quote(p.label or el.name) .. ", " ..
        quote(p.style or "inactive") .. ", " .. (p.width or -1) .. ", " .. (p.height or 0) .. ")"
end

emitters["ToggleButton"] = function(el, lvl)
    local p = el.props
    return indent(lvl) .. "controls.ToggleButton(" .. quote(p.label or el.name) ..
        ", data." .. el.name .. ", " .. (p.width or -1) .. ", " .. (p.height or 0) .. ")"
end

emitters["DynamicButton"] = function(el, lvl)
    local p = el.props
    local opts = emitOpts({}, p, { "style", "width", "height", "minChars", "tooltip" })
    return indent(lvl) .. "controls.DynamicButton(" .. quote(p.label or el.name) ..
        ", " .. formatValue(p.icon) .. (opts and (", " .. opts) or "") .. ")"
end

emitters["HoldButton"] = function(el, lvl)
    local p = el.props
    return indent(lvl) .. 'controls.HoldButton("' .. el.name .. '", ' ..
        quote(p.label or el.name) .. ", { duration = " .. (p.duration or 1) ..
        ", style = " .. quote(p.style or "inactive") .. " })"
end

emitters["ActionButton"] = function(el, lvl)
    local p = el.props
    return indent(lvl) .. 'controls.ActionButton("' .. el.name .. '", ' ..
        quote(p.label or el.name) .. ", { style = " .. quote(p.style or "inactive") .. " })"
end

emitters["ButtonRow"] = function(el, lvl)
    local p = el.props
    local lines = { indent(lvl) .. "controls.ButtonRow({" }
    if p.buttons then
        for _, btn in ipairs(p.buttons) do
            local parts = {}
            parts[#parts + 1] = "label = " .. quote(btn.label or "Button")
            parts[#parts + 1] = "style = " .. quote(btn.style or "inactive")
            if btn.weight and btn.weight ~= 1 then parts[#parts + 1] = "weight = " .. btn.weight end
            if btn.icon then parts[#parts + 1] = "icon = " .. quote(btn.icon) end
            lines[#lines + 1] = indent(lvl + 1) .. "{ " .. table.concat(parts, ", ") .. " },"
        end
    end
    local gapStr = p.gap and (", { gap = " .. p.gap .. " }") or ""
    lines[#lines + 1] = indent(lvl) .. "}" .. gapStr .. ")"
    return table.concat(lines, "\n")
end

emitters["DisabledButton"] = function(el, lvl)
    local p = el.props
    return indent(lvl) .. "controls.DisabledButton(" .. quote(p.label or el.name) ..
        ", " .. (p.width or -1) .. ", " .. (p.height or 0) .. ")"
end

emitters["FullWidthButton"] = function(el, lvl)
    local p = el.props
    return indent(lvl) .. "controls.Button(" .. quote(p.label or el.name) ..
        ", " .. quote(p.style or "inactive") .. ", -1, 0)"
end

emitters["IconButton"] = function(el, lvl)
    local p = el.props
    return indent(lvl) .. "controls.IconButton(" .. formatValue(p.icon or "?") ..
        ", " .. tostring(p.clickable or false) .. ")"
end

-- Bound controls use ctx:Method pattern
emitters["SliderFloat"] = function(el, lvl)
    local p = el.props
    local opts = emitOpts({}, p, { "format", "cols", "default", "tooltip" })
    return indent(lvl) .. "c:SliderFloat(" .. formatValue(p.icon) .. ", " ..
        quote(el.name) .. ", " .. (p.min or 0) .. ", " .. (p.max or 1) ..
        (opts and (", " .. opts) or "") .. ")"
end

emitters["SliderInt"] = function(el, lvl)
    local p = el.props
    local opts = emitOpts({}, p, { "format", "cols", "default", "tooltip" })
    return indent(lvl) .. "c:SliderInt(" .. formatValue(p.icon) .. ", " ..
        quote(el.name) .. ", " .. (p.min or 0) .. ", " .. (p.max or 100) ..
        (opts and (", " .. opts) or "") .. ")"
end

emitters["SliderDisabled"] = function(el, lvl)
    local p = el.props
    return indent(lvl) .. "controls.SliderDisabled(" .. formatValue(p.icon) ..
        ", " .. quote(p.label or el.name) .. ")"
end

emitters["DragFloat"] = function(el, lvl)
    local p = el.props
    local opts = emitOpts({}, p, { "speed", "format", "cols", "default", "tooltip" })
    return indent(lvl) .. "c:DragFloat(" .. formatValue(p.icon) .. ", " ..
        quote(el.name) .. ", " .. (p.min or 0) .. ", " .. (p.max or 1) ..
        (opts and (", " .. opts) or "") .. ")"
end

emitters["DragInt"] = function(el, lvl)
    local p = el.props
    local opts = emitOpts({}, p, { "speed", "format", "cols", "default", "tooltip" })
    return indent(lvl) .. "c:DragInt(" .. formatValue(p.icon) .. ", " ..
        quote(el.name) .. ", " .. (p.min or 0) .. ", " .. (p.max or 100) ..
        (opts and (", " .. opts) or "") .. ")"
end

emitters["DragFloatRow"] = function(el, lvl)
    local p = el.props
    return indent(lvl) .. "-- DragFloatRow: " .. el.name .. " (configure drags in code)"
end

emitters["DragIntRow"] = function(el, lvl)
    return indent(lvl) .. "-- DragIntRow: " .. el.name .. " (configure drags in code)"
end

emitters["InputText"] = function(el, lvl)
    local p = el.props
    local opts = emitOpts({}, p, { "maxLength", "cols", "tooltip" })
    return indent(lvl) .. "c:InputText(" .. formatValue(p.icon) .. ", " ..
        quote(el.name) .. (opts and (", " .. opts) or "") .. ")"
end

emitters["InputFloat"] = function(el, lvl)
    local p = el.props
    local opts = emitOpts({}, p, { "format", "cols", "tooltip" })
    return indent(lvl) .. "c:InputFloat(" .. formatValue(p.icon) .. ", " ..
        quote(el.name) .. (opts and (", " .. opts) or "") .. ")"
end

emitters["InputInt"] = function(el, lvl)
    local p = el.props
    local opts = emitOpts({}, p, { "cols", "tooltip" })
    return indent(lvl) .. "c:InputInt(" .. formatValue(p.icon) .. ", " ..
        quote(el.name) .. (opts and (", " .. opts) or "") .. ")"
end

emitters["Checkbox"] = function(el, lvl)
    local p = el.props
    local opts = emitOpts({}, p, { "tooltip" })
    return indent(lvl) .. "c:Checkbox(" .. quote(p.label or el.name) .. ", " ..
        quote(el.name) .. (opts and (", " .. opts) or "") .. ")"
end

emitters["Combo"] = function(el, lvl)
    local p = el.props
    local items = p.items or { "Option 1", "Option 2" }
    return indent(lvl) .. "c:Combo(" .. formatValue(p.icon) .. ", " ..
        quote(el.name) .. ", " .. formatValue(items) .. ")"
end

emitters["ColorEdit4"] = function(el, lvl)
    local p = el.props
    return indent(lvl) .. "c:ColorEdit4(" .. formatValue(p.icon) .. ", " ..
        quote(el.name) .. ")"
end

emitters["ProgressBar"] = function(el, lvl)
    local p = el.props
    return indent(lvl) .. "controls.ProgressBar(" .. (p.fraction or 0.5) ..
        ", nil, " .. (p.height or 0) .. ", " .. quote(p.overlay or "") ..
        ", " .. quote(p.style or "default") .. ")"
end

emitters["StatusBar"] = function(el, lvl)
    local p = el.props
    return indent(lvl) .. "controls.StatusBar(" .. quote(p.label or el.name) ..
        ", " .. formatValue(p.value) .. ")"
end

emitters["TextMuted"]   = function(el, lvl) return indent(lvl) .. "controls.TextMuted(" .. quote(el.props.text or "") .. ")" end
emitters["TextSuccess"] = function(el, lvl) return indent(lvl) .. "controls.TextSuccess(" .. quote(el.props.text or "") .. ")" end
emitters["TextDanger"]  = function(el, lvl) return indent(lvl) .. "controls.TextDanger(" .. quote(el.props.text or "") .. ")" end
emitters["TextWarning"] = function(el, lvl) return indent(lvl) .. "controls.TextWarning(" .. quote(el.props.text or "") .. ")" end

emitters["SectionHeader"] = function(el, lvl)
    local p = el.props
    return indent(lvl) .. "controls.SectionHeader(" .. quote(p.text or "Section") ..
        ", " .. (p.spacingBefore or "nil") .. ", " .. (p.spacingAfter or "nil") ..
        ", " .. formatValue(p.icon) .. ")"
end

emitters["Separator"] = function(el, lvl)
    local p = el.props
    return indent(lvl) .. "controls.Separator(" .. (p.before or "nil") .. ", " .. (p.after or "nil") .. ")"
end

--------------------------------------------------------------------------------
-- Container emitters (emit nested calls with child callbacks)
--------------------------------------------------------------------------------

local function emitChildren(projectRef, zone, lvl)
    local lines = {}
    if zone.children then
        for _, childId in ipairs(zone.children) do
            local child = projectRef.findElement(childId)
            if child then
                local emitter = emitters[child.type]
                if emitter then
                    lines[#lines + 1] = emitter(child, lvl)
                else
                    lines[#lines + 1] = indent(lvl) .. "-- Unknown: " .. child.type
                end
            end
        end
    end
    return table.concat(lines, "\n")
end

emitters["SplitterH"] = function(el, lvl, projectRef)
    local p = el.props
    local zones = el.zones or {}
    local lines = {}
    lines[#lines + 1] = indent(lvl) .. 'splitter.horizontal("' .. el.name .. '", function()'
    if zones[1] then lines[#lines + 1] = emitChildren(projectRef, zones[1], lvl + 1) end
    lines[#lines + 1] = indent(lvl) .. "end, function()"
    if zones[2] then lines[#lines + 1] = emitChildren(projectRef, zones[2], lvl + 1) end
    lines[#lines + 1] = indent(lvl) .. "end, { defaultPct = " .. (p.defaultPct or 0.5) ..
        ", minPct = " .. (p.minPct or 0.1) .. ", maxPct = " .. (p.maxPct or 0.9) .. " })"
    return table.concat(lines, "\n")
end

emitters["SplitterV"] = function(el, lvl, projectRef)
    local p = el.props
    local zones = el.zones or {}
    local lines = {}
    lines[#lines + 1] = indent(lvl) .. 'splitter.vertical("' .. el.name .. '", function()'
    if zones[1] then lines[#lines + 1] = emitChildren(projectRef, zones[1], lvl + 1) end
    lines[#lines + 1] = indent(lvl) .. "end, function()"
    if zones[2] then lines[#lines + 1] = emitChildren(projectRef, zones[2], lvl + 1) end
    lines[#lines + 1] = indent(lvl) .. "end, { defaultPct = " .. (p.defaultPct or 0.5) ..
        ", minPct = " .. (p.minPct or 0.1) .. ", maxPct = " .. (p.maxPct or 0.9) .. " })"
    return table.concat(lines, "\n")
end

emitters["SplitterMulti"] = function(el, lvl, projectRef)
    local p = el.props
    local zones = el.zones or {}
    local lines = {}
    lines[#lines + 1] = indent(lvl) .. 'splitter.multi("' .. el.name .. '", {'
    for i, zone in ipairs(zones) do
        lines[#lines + 1] = indent(lvl + 1) .. "{ content = function()"
        lines[#lines + 1] = emitChildren(projectRef, zone, lvl + 2)
        lines[#lines + 1] = indent(lvl + 1) .. "end },"
    end
    lines[#lines + 1] = indent(lvl) .. '}, { direction = ' .. quote(p.direction or "horizontal") .. " })"
    return table.concat(lines, "\n")
end

emitters["SplitterToggle"] = function(el, lvl, projectRef)
    local p = el.props
    local zones = el.zones or {}
    local lines = {}
    lines[#lines + 1] = indent(lvl) .. 'splitter.toggle("' .. el.name .. '", {'
    for i, zone in ipairs(zones) do
        lines[#lines + 1] = indent(lvl + 1) .. "{ content = function()"
        lines[#lines + 1] = emitChildren(projectRef, zone, lvl + 2)
        lines[#lines + 1] = indent(lvl + 1) .. "end },"
    end
    lines[#lines + 1] = indent(lvl) .. "}, { side = " .. quote(p.side or "left") ..
        ", size = " .. (p.size or 200) .. " })"
    return table.concat(lines, "\n")
end

emitters["Tabs"] = function(el, lvl, projectRef)
    local zones = el.zones or {}
    local lines = {}
    lines[#lines + 1] = indent(lvl) .. 'tabs.bar("' .. el.name .. '", {'
    for i, zone in ipairs(zones) do
        lines[#lines + 1] = indent(lvl + 1) .. "{ label = " .. quote(zone.label or ("Tab " .. i)) .. ", content = function()"
        lines[#lines + 1] = emitChildren(projectRef, zone, lvl + 2)
        lines[#lines + 1] = indent(lvl + 1) .. "end },"
    end
    lines[#lines + 1] = indent(lvl) .. "})"
    return table.concat(lines, "\n")
end

emitters["Panel"] = function(el, lvl, projectRef)
    local p = el.props
    local zones = el.zones or {}
    local lines = {}
    local opts = {}
    if p.bg then opts[#opts + 1] = "bg = " .. formatValue(p.bg) end
    if p.border then opts[#opts + 1] = "border = true" end
    if p.height and p.height ~= "auto" then opts[#opts + 1] = "height = " .. formatValue(p.height) end
    local optsStr = #opts > 0 and ("{ " .. table.concat(opts, ", ") .. " }") or "nil"
    lines[#lines + 1] = indent(lvl) .. 'controls.Panel("' .. el.name .. '", function()'
    if zones[1] then lines[#lines + 1] = emitChildren(projectRef, zones[1], lvl + 1) end
    lines[#lines + 1] = indent(lvl) .. "end, " .. optsStr .. ")"
    return table.concat(lines, "\n")
end

emitters["Column"] = function(el, lvl, projectRef)
    local zones = el.zones or {}
    local lines = {}
    lines[#lines + 1] = indent(lvl) .. 'controls.Column("' .. el.name .. '", {'
    for i, zone in ipairs(zones) do
        local defParts = {}
        if zone.flex then defParts[#defParts + 1] = "flex = " .. zone.flex end
        if zone.height then defParts[#defParts + 1] = "height = " .. zone.height end
        if zone.auto then defParts[#defParts + 1] = "auto = true" end
        defParts[#defParts + 1] = "content = function()"
        lines[#lines + 1] = indent(lvl + 1) .. "{ " .. table.concat(defParts, ", ")
        lines[#lines + 1] = emitChildren(projectRef, zone, lvl + 2)
        lines[#lines + 1] = indent(lvl + 1) .. "end },"
    end
    lines[#lines + 1] = indent(lvl) .. "})"
    return table.concat(lines, "\n")
end

emitters["Row"] = function(el, lvl, projectRef)
    local zones = el.zones or {}
    local lines = {}
    lines[#lines + 1] = indent(lvl) .. 'controls.Row("' .. el.name .. '", {'
    for i, zone in ipairs(zones) do
        local defParts = {}
        if zone.flex then defParts[#defParts + 1] = "flex = " .. zone.flex end
        if zone.width then defParts[#defParts + 1] = "width = " .. zone.width end
        if zone.cols then defParts[#defParts + 1] = "cols = " .. zone.cols end
        defParts[#defParts + 1] = "content = function()"
        lines[#lines + 1] = indent(lvl + 1) .. "{ " .. table.concat(defParts, ", ")
        lines[#lines + 1] = emitChildren(projectRef, zone, lvl + 2)
        lines[#lines + 1] = indent(lvl + 1) .. "end },"
    end
    lines[#lines + 1] = indent(lvl) .. "})"
    return table.concat(lines, "\n")
end

-- Advanced placeholders
emitters["Lists"]         = function(el, lvl) return indent(lvl) .. "-- Lists: " .. el.name end
emitters["Search"]        = function(el, lvl) return indent(lvl) .. "-- Search: " .. el.name end
emitters["Modal"]         = function(el, lvl) return indent(lvl) .. "-- Modal: " .. el.name end
emitters["Notifications"] = function(el, lvl) return indent(lvl) .. "-- Notifications: " .. el.name end
emitters["DragDrop"]      = function(el, lvl) return indent(lvl) .. "-- DragDrop: " .. el.name end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Generate the complete Lua mod string
---@param projectRef table Project module
---@return string lua Complete init.lua content
function export.generate(projectRef)
    local config = projectRef.getConfig()
    local elements = projectRef.getElements()

    local lines = {}

    -- Header
    lines[#lines + 1] = "local wu, controls, styles, splitter, tabs"
    lines[#lines + 1] = "local overlayOpen = false"
    lines[#lines + 1] = ""

    -- Data and defaults tables
    local dataEntries = {}
    local defaultEntries = {}
    for _, el in ipairs(elements) do
        if VALUE_TYPES[el.type] then
            local p = el.props
            local defaultVal = "nil"
            if el.type == "Checkbox" then
                defaultVal = tostring(p.default or false)
            elseif el.type == "Combo" then
                defaultVal = tostring(p.default or 0)
            elseif el.type == "ColorEdit4" then
                defaultVal = formatValue(p.default or { 1, 1, 1, 1 })
            elseif el.type == "InputText" then
                defaultVal = quote("")
            elseif el.type == "SliderFloat" or el.type == "DragFloat" or el.type == "InputFloat" then
                defaultVal = tostring(p.default or p.min or 0)
            elseif el.type == "SliderInt" or el.type == "DragInt" or el.type == "InputInt" then
                defaultVal = tostring(p.default or p.min or 0)
            end
            dataEntries[#dataEntries + 1] = "    " .. el.name .. " = " .. defaultVal
            defaultEntries[#defaultEntries + 1] = "    " .. el.name .. " = " .. defaultVal
        end
    end

    lines[#lines + 1] = "local data = {"
    for _, entry in ipairs(dataEntries) do
        lines[#lines + 1] = entry .. ","
    end
    lines[#lines + 1] = "}"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "local defaults = {"
    for _, entry in ipairs(defaultEntries) do
        lines[#lines + 1] = entry .. ","
    end
    lines[#lines + 1] = "}"
    lines[#lines + 1] = ""

    lines[#lines + 1] = "local function onSave() end"
    lines[#lines + 1] = ""

    -- onInit
    lines[#lines + 1] = 'registerForEvent("onInit", function()'
    lines[#lines + 1] = '    wu = GetMod("WindowUtils")'
    lines[#lines + 1] = "    if not wu then return end"
    lines[#lines + 1] = "    controls = wu.Controls"
    lines[#lines + 1] = "    styles = wu.Styles"
    lines[#lines + 1] = "    splitter = wu.Splitter"
    lines[#lines + 1] = "    tabs = wu.Tabs"
    lines[#lines + 1] = "end)"
    lines[#lines + 1] = ""

    -- Overlay events
    lines[#lines + 1] = 'registerForEvent("onOverlayOpen", function() overlayOpen = true end)'
    lines[#lines + 1] = 'registerForEvent("onOverlayClose", function() overlayOpen = false end)'
    lines[#lines + 1] = ""

    -- onDraw
    lines[#lines + 1] = 'registerForEvent("onDraw", function()'
    lines[#lines + 1] = "    if not wu or not overlayOpen then return end"
    lines[#lines + 1] = "    controls.cacheFrameState()"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "    ImGui.SetNextWindowSize(" ..
        (config.windowWidth or 400) .. ", " .. (config.windowHeight or 300) .. ", ImGuiCond.FirstUseEver)"
    lines[#lines + 1] = '    if ImGui.Begin(' .. quote(config.windowTitle or "My Mod") .. ') then'
    lines[#lines + 1] = "        local c = controls.bind(data, defaults, onSave)"
    lines[#lines + 1] = ""

    -- Emit top-level elements
    for _, el in ipairs(elements) do
        if el.parentId == nil then
            local emitter = emitters[el.type]
            if emitter then
                -- Container emitters accept projectRef as 3rd arg
                local code = emitter(el, 2, projectRef)
                if code and code ~= "" then
                    lines[#lines + 1] = code
                end
            end
        end
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "        controls.unbind(c)"
    lines[#lines + 1] = "    end"
    lines[#lines + 1] = "    ImGui.End()"
    lines[#lines + 1] = "end)"
    lines[#lines + 1] = ""

    return table.concat(lines, "\n")
end

--- Write the exported file to disk
---@param projectRef table Project module
---@param notify table|nil Notifications module
function export.write(projectRef, notify)
    local config = projectRef.getConfig()
    local folderName = config.modFolderName or "MyMod"
    local outputDir = folderName
    local outputPath = outputDir .. "/init.lua"

    -- Attempt to create directory
    local dirHandle = io.open(outputDir .. "/.dircheck", "w")
    if not dirHandle then
        os.execute('mkdir "' .. outputDir .. '"')
        dirHandle = io.open(outputDir .. "/.dircheck", "w")
        if not dirHandle then
            print("[WindowUtilsBuilder] Failed to create output directory: " .. outputDir)
            if notify then notify.error("Export failed: cannot create " .. outputDir) end
            return false
        end
    end
    dirHandle:close()
    os.remove(outputDir .. "/.dircheck")

    local code = export.generate(projectRef)

    local file = io.open(outputPath, "w")
    if not file then
        print("[WindowUtilsBuilder] Failed to write export file: " .. outputPath)
        if notify then notify.error("Export failed: cannot write " .. outputPath) end
        return false
    end

    file:write(code)
    file:close()

    print("[WindowUtilsBuilder] Exported to " .. outputPath)
    if notify then notify.success("Exported to " .. outputPath) end
    return true
end

return export
