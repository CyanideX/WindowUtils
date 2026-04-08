------------------------------------------------------
-- WindowUtils Builder - Property Inspector
-- Per-element property editing
------------------------------------------------------

local element_defs = require("modules/element_defs")

local inspector = {}

local controls, styles, notify

-- Style names for combo dropdown
local STYLE_NAMES = {
    "active", "inactive", "danger", "warning", "update",
    "disabled", "statusbar", "label", "labelOutlined",
    "transparent", "frameless",
}

-- Height mode options for Panel
local HEIGHT_MODES = { "auto", "fixed", "fill" }

--------------------------------------------------------------------------------
-- Schema definitions: per-type property editors
--------------------------------------------------------------------------------

local schemas = {}

schemas["Button"] = {
    { key = "label",   editor = "InputText",  label = "Label" },
    { key = "style",   editor = "StyleCombo", label = "Style" },
    { key = "width",   editor = "DragFloat",  label = "Width", min = -1, max = 2000 },
    { key = "height",  editor = "DragFloat",  label = "Height", min = 0, max = 500 },
    { key = "tooltip", editor = "InputText",  label = "Tooltip" },
}

schemas["ToggleButton"] = {
    { key = "label",   editor = "InputText",  label = "Label" },
    { key = "style",   editor = "StyleCombo", label = "Style" },
    { key = "width",   editor = "DragFloat",  label = "Width", min = -1, max = 2000 },
    { key = "height",  editor = "DragFloat",  label = "Height", min = 0, max = 500 },
    { key = "tooltip", editor = "InputText",  label = "Tooltip" },
}

schemas["DynamicButton"] = {
    { key = "label",    editor = "InputText",  label = "Label" },
    { key = "icon",     editor = "InputText",  label = "Icon" },
    { key = "style",    editor = "StyleCombo", label = "Style" },
    { key = "width",    editor = "DragFloat",  label = "Width", min = -1, max = 2000 },
    { key = "height",   editor = "DragFloat",  label = "Height", min = 0, max = 500 },
    { key = "minChars", editor = "DragInt",    label = "Min Chars", min = 1, max = 20 },
    { key = "tooltip",  editor = "InputText",  label = "Tooltip" },
}

schemas["HoldButton"] = {
    { key = "label",    editor = "InputText",  label = "Label" },
    { key = "duration", editor = "DragFloat",  label = "Duration (s)", min = 0.1, max = 10 },
    { key = "style",    editor = "StyleCombo", label = "Style" },
    { key = "width",    editor = "DragFloat",  label = "Width", min = -1, max = 2000 },
    { key = "tooltip",  editor = "InputText",  label = "Tooltip" },
}

schemas["ActionButton"] = {
    { key = "label",   editor = "InputText",  label = "Label" },
    { key = "style",   editor = "StyleCombo", label = "Style" },
    { key = "width",   editor = "DragFloat",  label = "Width", min = -1, max = 2000 },
    { key = "tooltip", editor = "InputText",  label = "Tooltip" },
}

schemas["DisabledButton"] = {
    { key = "label",  editor = "InputText",  label = "Label" },
    { key = "width",  editor = "DragFloat",  label = "Width", min = -1, max = 2000 },
    { key = "height", editor = "DragFloat",  label = "Height", min = 0, max = 500 },
}

schemas["FullWidthButton"] = {
    { key = "label", editor = "InputText",  label = "Label" },
    { key = "style", editor = "StyleCombo", label = "Style" },
}

schemas["IconButton"] = {
    { key = "icon",      editor = "InputText", label = "Icon" },
    { key = "clickable", editor = "Checkbox",  label = "Clickable" },
    { key = "tooltip",   editor = "InputText", label = "Tooltip" },
}

schemas["SliderFloat"] = {
    { key = "icon",    editor = "InputText",  label = "Icon" },
    { key = "min",     editor = "DragFloat",  label = "Min", min = -10000, max = 10000 },
    { key = "max",     editor = "DragFloat",  label = "Max", min = -10000, max = 10000 },
    { key = "default", editor = "DragFloat",  label = "Default", min = -10000, max = 10000 },
    { key = "format",  editor = "InputText",  label = "Format" },
    { key = "cols",    editor = "DragInt",    label = "Columns", min = 1, max = 12 },
    { key = "tooltip", editor = "InputText",  label = "Tooltip" },
}

schemas["SliderInt"] = {
    { key = "icon",    editor = "InputText",  label = "Icon" },
    { key = "min",     editor = "DragInt",    label = "Min", min = -10000, max = 10000 },
    { key = "max",     editor = "DragInt",    label = "Max", min = -10000, max = 10000 },
    { key = "default", editor = "DragInt",    label = "Default", min = -10000, max = 10000 },
    { key = "format",  editor = "InputText",  label = "Format" },
    { key = "cols",    editor = "DragInt",    label = "Columns", min = 1, max = 12 },
    { key = "tooltip", editor = "InputText",  label = "Tooltip" },
}

schemas["SliderDisabled"] = {
    { key = "icon",  editor = "InputText", label = "Icon" },
    { key = "label", editor = "InputText", label = "Label" },
}

schemas["DragFloat"] = {
    { key = "icon",    editor = "InputText",  label = "Icon" },
    { key = "min",     editor = "DragFloat",  label = "Min", min = -10000, max = 10000 },
    { key = "max",     editor = "DragFloat",  label = "Max", min = -10000, max = 10000 },
    { key = "speed",   editor = "DragFloat",  label = "Speed", min = 0, max = 100 },
    { key = "default", editor = "DragFloat",  label = "Default", min = -10000, max = 10000 },
    { key = "format",  editor = "InputText",  label = "Format" },
    { key = "cols",    editor = "DragInt",    label = "Columns", min = 1, max = 12 },
    { key = "tooltip", editor = "InputText",  label = "Tooltip" },
}

schemas["DragInt"] = {
    { key = "icon",    editor = "InputText",  label = "Icon" },
    { key = "min",     editor = "DragInt",    label = "Min", min = -10000, max = 10000 },
    { key = "max",     editor = "DragInt",    label = "Max", min = -10000, max = 10000 },
    { key = "speed",   editor = "DragFloat",  label = "Speed", min = 0, max = 100 },
    { key = "default", editor = "DragInt",    label = "Default", min = -10000, max = 10000 },
    { key = "format",  editor = "InputText",  label = "Format" },
    { key = "cols",    editor = "DragInt",    label = "Columns", min = 1, max = 12 },
    { key = "tooltip", editor = "InputText",  label = "Tooltip" },
}

schemas["DragFloatRow"] = {
    { key = "icon",    editor = "InputText",  label = "Icon" },
    { key = "min",     editor = "DragFloat",  label = "Min", min = -10000, max = 10000 },
    { key = "max",     editor = "DragFloat",  label = "Max", min = -10000, max = 10000 },
    { key = "speed",   editor = "DragFloat",  label = "Speed", min = 0, max = 100 },
    { key = "format",  editor = "InputText",  label = "Format" },
    { key = "cols",    editor = "DragInt",    label = "Columns", min = 1, max = 12 },
    { key = "tooltip", editor = "InputText",  label = "Tooltip" },
}

schemas["DragIntRow"] = {
    { key = "icon",    editor = "InputText",  label = "Icon" },
    { key = "min",     editor = "DragInt",    label = "Min", min = -10000, max = 10000 },
    { key = "max",     editor = "DragInt",    label = "Max", min = -10000, max = 10000 },
    { key = "speed",   editor = "DragFloat",  label = "Speed", min = 0, max = 100 },
    { key = "format",  editor = "InputText",  label = "Format" },
    { key = "cols",    editor = "DragInt",    label = "Columns", min = 1, max = 12 },
    { key = "tooltip", editor = "InputText",  label = "Tooltip" },
}

schemas["InputText"] = {
    { key = "icon",      editor = "InputText", label = "Icon" },
    { key = "maxLength", editor = "DragInt",   label = "Max Length", min = 1, max = 4096 },
    { key = "cols",      editor = "DragInt",   label = "Columns", min = 1, max = 12 },
    { key = "tooltip",   editor = "InputText", label = "Tooltip" },
}

schemas["InputFloat"] = {
    { key = "icon",    editor = "InputText",  label = "Icon" },
    { key = "default", editor = "DragFloat",  label = "Default", min = -10000, max = 10000 },
    { key = "format",  editor = "InputText",  label = "Format" },
    { key = "cols",    editor = "DragInt",    label = "Columns", min = 1, max = 12 },
    { key = "tooltip", editor = "InputText",  label = "Tooltip" },
}

schemas["InputInt"] = {
    { key = "icon",    editor = "InputText", label = "Icon" },
    { key = "default", editor = "DragInt",   label = "Default", min = -10000, max = 10000 },
    { key = "cols",    editor = "DragInt",   label = "Columns", min = 1, max = 12 },
    { key = "tooltip", editor = "InputText", label = "Tooltip" },
}

schemas["Checkbox"] = {
    { key = "label",   editor = "InputText", label = "Label" },
    { key = "default", editor = "Checkbox",  label = "Default" },
    { key = "tooltip", editor = "InputText", label = "Tooltip" },
}

schemas["Combo"] = {
    { key = "icon",    editor = "InputText", label = "Icon" },
    { key = "cols",    editor = "DragInt",   label = "Columns", min = 1, max = 12 },
    { key = "tooltip", editor = "InputText", label = "Tooltip" },
}

schemas["ColorEdit4"] = {
    { key = "icon",    editor = "InputText",  label = "Icon" },
    { key = "default", editor = "ColorEdit4", label = "Default Color" },
    { key = "tooltip", editor = "InputText",  label = "Tooltip" },
}

schemas["ProgressBar"] = {
    { key = "fraction", editor = "DragFloat",  label = "Fraction", min = 0, max = 1 },
    { key = "width",    editor = "DragFloat",  label = "Width", min = 0, max = 2000 },
    { key = "height",   editor = "DragFloat",  label = "Height", min = 0, max = 200 },
    { key = "overlay",  editor = "InputText",  label = "Overlay" },
    { key = "style",    editor = "InputText",  label = "Style" },
}

schemas["StatusBar"] = {
    { key = "label", editor = "InputText",  label = "Label" },
    { key = "value", editor = "InputText",  label = "Value" },
    { key = "style", editor = "StyleCombo", label = "Style" },
}

schemas["TextMuted"]   = { { key = "text", editor = "InputText", label = "Text" } }
schemas["TextSuccess"] = { { key = "text", editor = "InputText", label = "Text" } }
schemas["TextDanger"]  = { { key = "text", editor = "InputText", label = "Text" } }
schemas["TextWarning"] = { { key = "text", editor = "InputText", label = "Text" } }

schemas["SectionHeader"] = {
    { key = "text",          editor = "InputText", label = "Text" },
    { key = "spacingBefore", editor = "DragFloat", label = "Spacing Before", min = 0, max = 100 },
    { key = "spacingAfter",  editor = "DragFloat", label = "Spacing After", min = 0, max = 100 },
    { key = "icon",          editor = "InputText", label = "Icon" },
}

schemas["Separator"] = {
    { key = "before", editor = "DragFloat", label = "Before", min = 0, max = 100 },
    { key = "after",  editor = "DragFloat", label = "After", min = 0, max = 100 },
}

-- Layout containers
schemas["SplitterH"] = {
    { key = "defaultPct", editor = "DragFloat", label = "Default %", min = 0.05, max = 0.95 },
    { key = "minPct",     editor = "DragFloat", label = "Min %", min = 0.01, max = 0.5 },
    { key = "maxPct",     editor = "DragFloat", label = "Max %", min = 0.5, max = 0.99 },
}
schemas["SplitterV"] = schemas["SplitterH"]

schemas["SplitterMulti"] = {
    { key = "direction", editor = "InputText", label = "Direction" },
}

schemas["SplitterToggle"] = {
    { key = "side",        editor = "InputText", label = "Side" },
    { key = "size",        editor = "DragFloat", label = "Size", min = 50, max = 1000 },
    { key = "defaultOpen", editor = "Checkbox",  label = "Default Open" },
}

schemas["Tabs"] = {}

schemas["Panel"] = {
    { key = "border",        editor = "Checkbox",  label = "Border" },
    { key = "borderOnHover", editor = "Checkbox",  label = "Border on Hover" },
    { key = "width",         editor = "DragFloat", label = "Width", min = 0, max = 2000 },
}

schemas["Column"] = {
    { key = "spacing", editor = "DragFloat", label = "Spacing", min = 0, max = 100 },
}

schemas["Row"] = {
    { key = "spacing", editor = "DragFloat", label = "Spacing", min = 0, max = 100 },
}

-- Advanced (minimal)
schemas["Lists"]         = {}
schemas["Search"]        = { { key = "placeholder", editor = "InputText", label = "Placeholder" } }
schemas["Modal"]         = { { key = "title", editor = "InputText", label = "Title" } }
schemas["Notifications"] = { { key = "message", editor = "InputText", label = "Message" } }
schemas["DragDrop"]      = {}

--------------------------------------------------------------------------------
-- Editor renderers
--------------------------------------------------------------------------------

local function drawEditor(project, el, field)
    local key = field.key
    local value = el.props[key]
    local editorType = field.editor

    if editorType == "InputText" then
        ImGui.Text(field.label)
        ImGui.SetNextItemWidth(-1)
        local newVal, changed = ImGui.InputText("##insp_" .. el.id .. "_" .. key, tostring(value or ""), 256)
        if changed then
            project.setProperty(el.id, key, newVal)
        end

    elseif editorType == "DragFloat" then
        ImGui.Text(field.label)
        ImGui.SetNextItemWidth(-1)
        local newVal, changed = ImGui.DragFloat("##insp_" .. el.id .. "_" .. key, value or 0, 0.1, field.min or -10000, field.max or 10000, "%.2f")
        if changed then
            project.setProperty(el.id, key, newVal)
        end

    elseif editorType == "DragInt" then
        ImGui.Text(field.label)
        ImGui.SetNextItemWidth(-1)
        local newVal, changed = ImGui.DragInt("##insp_" .. el.id .. "_" .. key, value or 0, 0.5, field.min or -10000, field.max or 10000, "%d")
        if changed then
            project.setProperty(el.id, key, newVal)
        end

    elseif editorType == "Checkbox" then
        local newVal, changed = ImGui.Checkbox(field.label .. "##insp_" .. el.id .. "_" .. key, value or false)
        if changed then
            project.setProperty(el.id, key, newVal)
        end

    elseif editorType == "StyleCombo" then
        ImGui.Text(field.label)
        local currentIdx = 0
        for i, name in ipairs(STYLE_NAMES) do
            if name == (value or "inactive") then
                currentIdx = i - 1
                break
            end
        end
        ImGui.SetNextItemWidth(-1)
        local newIdx, changed = ImGui.Combo("##insp_" .. el.id .. "_" .. key, currentIdx, STYLE_NAMES, #STYLE_NAMES)
        if changed then
            project.setProperty(el.id, key, STYLE_NAMES[newIdx + 1])
        end
        -- Style preview button
        local styleName = value or "inactive"
        controls.Button("Preview##style_preview_" .. el.id, styleName, -1, 0)

    elseif editorType == "ColorEdit4" then
        ImGui.Text(field.label)
        local color = value or { 1, 1, 1, 1 }
        local newColor, changed = controls.ColorEdit4(nil, "insp_" .. el.id .. "_" .. key, color)
        if changed then
            project.setProperty(el.id, key, newColor)
        end
    end
end

--------------------------------------------------------------------------------
-- ButtonRow child editor
--------------------------------------------------------------------------------

local function drawButtonRowEditor(project, el)
    local buttons = el.props.buttons
    if not buttons then return end

    controls.SectionHeader("Buttons", 8, 4)

    for i, btn in ipairs(buttons) do
        if ImGui.CollapsingHeader("Button " .. i .. "##btnrow_" .. el.id .. "_" .. i) then
            ImGui.PushID("btnrow_edit_" .. el.id .. "_" .. i)

            ImGui.Text("Label")
            ImGui.SetNextItemWidth(-1)
            local newLabel, labelChanged = ImGui.InputText("##label", btn.label or "", 256)
            if labelChanged then
                btn.label = newLabel
                project.touchElement(el.id)
            end

            ImGui.Text("Style")
            local currentIdx = 0
            for si, name in ipairs(STYLE_NAMES) do
                if name == (btn.style or "inactive") then
                    currentIdx = si - 1
                    break
                end
            end
            ImGui.SetNextItemWidth(-1)
            local newIdx, styleChanged = ImGui.Combo("##style", currentIdx, STYLE_NAMES, #STYLE_NAMES)
            if styleChanged then
                btn.style = STYLE_NAMES[newIdx + 1]
                project.touchElement(el.id)
            end

            ImGui.Text("Weight")
            ImGui.SetNextItemWidth(-1)
            local newWeight, wChanged = ImGui.DragFloat("##weight", btn.weight or 1, 0.1, 0, 10, "%.1f")
            if wChanged then
                btn.weight = newWeight
                project.touchElement(el.id)
            end

            ImGui.Text("Icon")
            ImGui.SetNextItemWidth(-1)
            local newIcon, iconChanged = ImGui.InputText("##icon", btn.icon or "", 256)
            if iconChanged then
                btn.icon = (newIcon ~= "") and newIcon or nil
                project.touchElement(el.id)
            end

            local newDisabled, disChanged = ImGui.Checkbox("Disabled##dis", btn.disabled or false)
            if disChanged then
                btn.disabled = newDisabled
                project.touchElement(el.id)
            end

            ImGui.Text("Tooltip")
            ImGui.SetNextItemWidth(-1)
            local newTip, tipChanged = ImGui.InputText("##tooltip", btn.tooltip or "", 256)
            if tipChanged then
                btn.tooltip = (newTip ~= "") and newTip or nil
                project.touchElement(el.id)
            end

            ImGui.Spacing()
            if controls.Button("Remove##remove_btn_" .. i, "danger", -1, 0) then
                table.remove(buttons, i)
                project.touchElement(el.id)
            end

            ImGui.PopID()
        end
    end

    ImGui.Spacing()
    if controls.Button("Add Button", "inactive", -1, 0) then
        buttons[#buttons + 1] = { label = "Button " .. (#buttons + 1), style = "inactive", weight = 1 }
        project.touchElement(el.id)
    end
end

--------------------------------------------------------------------------------
-- Zone editor for dynamic-zone containers
--------------------------------------------------------------------------------

local function drawZoneEditor(project, el)
    if not el.zones then return end

    controls.SectionHeader("Zones", 8, 4)

    for i, zone in ipairs(el.zones) do
        ImGui.PushID("zone_edit_" .. el.id .. "_" .. i)

        ImGui.Text("Zone " .. i .. " Label")
        ImGui.SetNextItemWidth(-1)
        local newLabel, labelChanged = ImGui.InputText("##zlabel", zone.label or "", 256)
        if labelChanged then
            zone.label = newLabel
            project.touchElement(el.id)
        end

        -- Size mode for Row zones
        if el.type == "Row" then
            ImGui.Text("Width Mode")
            local modes = { "flex", "fixed", "cols" }
            local currentMode = "flex"
            if zone.width then currentMode = "fixed"
            elseif zone.cols then currentMode = "cols" end
            local modeIdx = 0
            for mi, m in ipairs(modes) do
                if m == currentMode then modeIdx = mi - 1 break end
            end
            ImGui.SetNextItemWidth(-1)
            local newModeIdx, modeChanged = ImGui.Combo("##wmode", modeIdx, modes, #modes)
            if modeChanged then
                local newMode = modes[newModeIdx + 1]
                zone.width = nil
                zone.cols = nil
                zone.flex = nil
                if newMode == "fixed" then zone.width = 100
                elseif newMode == "cols" then zone.cols = 6
                else zone.flex = 1 end
                project.touchElement(el.id)
            end
            if zone.width then
                ImGui.SetNextItemWidth(-1)
                local newW, wChanged = ImGui.DragFloat("##zwidth", zone.width, 1, 10, 2000, "%.0f")
                if wChanged then zone.width = newW; project.touchElement(el.id) end
            elseif zone.cols then
                ImGui.SetNextItemWidth(-1)
                local newC, cChanged = ImGui.DragInt("##zcols", zone.cols, 0.5, 1, 12, "%d")
                if cChanged then zone.cols = newC; project.touchElement(el.id) end
            elseif zone.flex then
                ImGui.SetNextItemWidth(-1)
                local newF, fChanged = ImGui.DragFloat("##zflex", zone.flex, 0.1, 0.1, 10, "%.1f")
                if fChanged then zone.flex = newF; project.touchElement(el.id) end
            end
        end

        -- Size mode for Column zones
        if el.type == "Column" then
            ImGui.Text("Height Mode")
            local modes = { "flex", "fixed", "auto" }
            local currentMode = "flex"
            if zone.height then currentMode = "fixed"
            elseif zone.auto then currentMode = "auto" end
            local modeIdx = 0
            for mi, m in ipairs(modes) do
                if m == currentMode then modeIdx = mi - 1 break end
            end
            ImGui.SetNextItemWidth(-1)
            local newModeIdx, modeChanged = ImGui.Combo("##hmode", modeIdx, modes, #modes)
            if modeChanged then
                local newMode = modes[newModeIdx + 1]
                zone.height = nil
                zone.auto = nil
                zone.flex = nil
                if newMode == "fixed" then zone.height = 100
                elseif newMode == "auto" then zone.auto = true
                else zone.flex = 1 end
                project.touchElement(el.id)
            end
            if zone.height then
                ImGui.SetNextItemWidth(-1)
                local newH, hChanged = ImGui.DragFloat("##zheight", zone.height, 1, 10, 2000, "%.0f")
                if hChanged then zone.height = newH; project.touchElement(el.id) end
            elseif zone.flex then
                ImGui.SetNextItemWidth(-1)
                local newF, fChanged = ImGui.DragFloat("##zflex", zone.flex, 0.1, 0.1, 10, "%.1f")
                if fChanged then zone.flex = newF; project.touchElement(el.id) end
            end
        end

        if #el.zones > 1 then
            if controls.Button("Remove Zone##rmzone_" .. i, "danger", -1, 0) then
                -- Remove zone and unparent its children
                local children = zone.children or {}
                for _, childId in ipairs(children) do
                    local child = project.findElement(childId)
                    if child then
                        child.parentId = nil
                        child.zoneIdx = nil
                    end
                end
                table.remove(el.zones, i)
                project.touchElement(el.id)
            end
        end

        ImGui.PopID()
        ImGui.Spacing()
    end

    if controls.Button("Add Zone", "inactive", -1, 0) then
        el.zones[#el.zones + 1] = { label = "Zone " .. (#el.zones + 1), children = {} }
        project.touchElement(el.id)
    end
end

--------------------------------------------------------------------------------
-- Panel height mode editor
--------------------------------------------------------------------------------

local function drawPanelHeightEditor(project, el)
    if el.type ~= "Panel" then return end

    ImGui.Text("Height Mode")
    local currentHeight = el.props.height
    local currentMode = "auto"
    if currentHeight == "auto" or currentHeight == nil then
        currentMode = "auto"
    elseif currentHeight == 0 then
        currentMode = "fill"
    elseif type(currentHeight) == "number" then
        currentMode = "fixed"
    end

    local modeIdx = 0
    for i, m in ipairs(HEIGHT_MODES) do
        if m == currentMode then modeIdx = i - 1 break end
    end
    ImGui.SetNextItemWidth(-1)
    local newModeIdx, modeChanged = ImGui.Combo("##panel_hmode_" .. el.id, modeIdx, HEIGHT_MODES, #HEIGHT_MODES)
    if modeChanged then
        local newMode = HEIGHT_MODES[newModeIdx + 1]
        if newMode == "auto" then
            project.setProperty(el.id, "height", "auto")
        elseif newMode == "fill" then
            project.setProperty(el.id, "height", 0)
        else
            project.setProperty(el.id, "height", 200)
        end
    end

    if currentMode == "fixed" and type(currentHeight) == "number" then
        ImGui.Text("Height (px)")
        ImGui.SetNextItemWidth(-1)
        local newH, hChanged = ImGui.DragFloat("##panel_hpx_" .. el.id, currentHeight, 1, 10, 2000, "%.0f")
        if hChanged then
            project.setProperty(el.id, "height", newH)
        end
    end
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

function inspector.init(wu)
    controls = wu.Controls
    styles = wu.Styles
    notify = wu.Notify
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------

function inspector.draw(project)
    if not controls then return end

    ImGui.SetNextWindowSize(300, 500, ImGuiCond.FirstUseEver)
    if ImGui.Begin("Property Inspector") then
        local el = project.getSelected()

        if not el then
            ImGui.TextWrapped("No element selected")
        else
            -- Element type (read-only)
            ImGui.Text("Type: " .. el.type)

            -- Element name (editable)
            ImGui.Text("Name")
            ImGui.SetNextItemWidth(-1)
            local newName, nameChanged = ImGui.InputText("##insp_name_" .. el.id, el.name or "", 256)
            if nameChanged then
                project.setProperty(el.id, "name", newName)
            end

            -- Element ID (read-only)
            ImGui.Text("ID: " .. el.id)

            ImGui.Spacing()
            ImGui.Separator()
            ImGui.Spacing()

            -- Child element management
            if el.parentId then
                local parent = project.findElement(el.parentId)
                if parent then
                    ImGui.Text("Parent: " .. parent.name)
                    if controls.Button("Select Parent##sel_parent_" .. el.id, "inactive", -1, 0) then
                        project.setSelected(parent.id)
                    end

                    if controls.Button("Move Up##child_up_" .. el.id, "inactive", -1, 0) then
                        project.moveChildInZone(el.id, "up")
                    end
                    if controls.Button("Move Down##child_down_" .. el.id, "inactive", -1, 0) then
                        project.moveChildInZone(el.id, "down")
                    end
                    if controls.Button("Remove from Parent##unparent_" .. el.id, "danger", -1, 0) then
                        project.removeElement(el.id)
                        if notify then
                            notify.warn("Removed " .. el.name)
                        end
                    end

                    ImGui.Spacing()
                    ImGui.Separator()
                    ImGui.Spacing()
                end
            end

            -- Target Zone dropdown for containers
            if el.zones and #el.zones > 0 then
                ImGui.Text("Target Zone")
                local zoneLabels = {}
                for i, zone in ipairs(el.zones) do
                    zoneLabels[i] = zone.label or ("Zone " .. i)
                end
                local currentZone = project.getSelectedZone() - 1
                ImGui.SetNextItemWidth(-1)
                local newZone, zoneChanged = ImGui.Combo("##insp_zone_" .. el.id, currentZone, zoneLabels, #zoneLabels)
                if zoneChanged then
                    project.setSelectedZone(newZone + 1)
                end
                ImGui.TextWrapped("New elements will be added to this zone")

                ImGui.Spacing()
                ImGui.Separator()
                ImGui.Spacing()
            end

            -- Schema-driven property editors
            local schema = schemas[el.type]
            if schema then
                for _, field in ipairs(schema) do
                    drawEditor(project, el, field)
                    ImGui.Spacing()
                end
            end

            -- ButtonRow child editor
            if el.type == "ButtonRow" then
                drawButtonRowEditor(project, el)
            end

            -- Zone editor for dynamic-zone containers
            local dynamicZoneTypes = { SplitterMulti = true, Tabs = true, Column = true, Row = true }
            if dynamicZoneTypes[el.type] then
                drawZoneEditor(project, el)
            end

            -- Panel height mode
            drawPanelHeightEditor(project, el)
        end
    end
    ImGui.End()
end

return inspector
