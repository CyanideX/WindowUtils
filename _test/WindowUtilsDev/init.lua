------------------------------------------------------
-- WindowUtils Dev Tools - Style Color Preview
-- Standalone CET mod for enumerating, editing, and
-- previewing all WindowUtils color presets and button
-- style groups. Requires WindowUtils to be installed.
------------------------------------------------------

local wu = nil
local styles = nil
local controls = nil
local tooltips = nil
local notifications = nil
local tabs = nil
local utils = nil

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local isOpen          = false
local isOverlayOpen   = false
local hasSnapshot     = false
local filterText      = ""

-- Color presets
local snapshotColors   = nil  -- {key -> {r,g,b,a}}
local sortedColorKeys  = nil
local colorGroups      = nil
local colorsExpanded   = true

-- Button styles: fully independent edit copies
local snapshotButtons  = nil  -- {key -> full edit table}
local editButtons      = nil  -- {key -> full edit table}
local sortedButtonKeys = nil
local buttonsExpanded  = true
local newStyleName     = ""   -- input buffer for "Add Style"
local newColorName     = ""   -- input buffer for "Add Color Preset"

-- Expand/collapse: nil = no pending action, true/false = apply once then clear
local pendingColorsExpand  = nil
local pendingButtonsExpand = nil

-- All editable color sub-keys for every button style
local BUTTON_COLOR_KEYS = {"bg", "hover", "active", "text", "borderColor"}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function deepCopyColor(color)
    return { color[1], color[2], color[3], color[4] }
end

local function colorsEqual(a, b)
    return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

--- Build a full independent edit copy from a buttonDefaults entry.
--- Every style gets ALL properties regardless of whether the original has border.
local function buildEditButton(group)
    local defaultBorder = styles.colors.frameBorder or {0.24, 0.59, 1.0, 0.35}
    return {
        bg          = deepCopyColor(group.bg),
        hover       = deepCopyColor(group.hover),
        active      = deepCopyColor(group.active),
        text        = deepCopyColor(group.text),
        border      = group.border and true or false,
        borderColor = deepCopyColor(group.borderColor or defaultBorder),
        borderSize  = group.borderSize or 2.0,
    }
end

--- Build a blank new button style with neutral defaults.
local function buildBlankButton()
    return {
        bg          = { 0.2, 0.2, 0.2, 1.0 },
        hover       = { 0.3, 0.3, 0.3, 1.0 },
        active      = { 0.25, 0.25, 0.25, 1.0 },
        text        = { 1.0, 1.0, 1.0, 1.0 },
        border      = false,
        borderColor = { 0.24, 0.59, 1.0, 0.35 },
        borderSize  = 2.0,
    }
end

local function extractPrefix(key)
    for i = 2, #key do
        local byte = string.byte(key, i)
        if byte >= 65 and byte <= 90 then
            return string.sub(key, 1, i - 1)
        end
    end
    return key
end

local function buildColorGroups()
    local groupMap = {}
    local prefixes = {}
    for _, key in ipairs(sortedColorKeys) do
        local prefix = extractPrefix(key)
        if not groupMap[prefix] then
            groupMap[prefix] = {}
            prefixes[#prefixes + 1] = prefix
        end
        local g = groupMap[prefix]
        g[#g + 1] = key
    end
    table.sort(prefixes)
    local groups = {}
    for _, prefix in ipairs(prefixes) do
        groups[#groups + 1] = { prefix = prefix, keys = groupMap[prefix] }
    end
    return groups
end

local function matchesFilter(key, filter)
    if not filter or filter == "" then return true end
    return string.find(string.lower(key), string.lower(filter), 1, true) ~= nil
end

--- Rebuild the sorted button keys list from editButtons.
local function rebuildSortedButtonKeys()
    sortedButtonKeys = {}
    for k in pairs(editButtons) do
        sortedButtonKeys[#sortedButtonKeys + 1] = k
    end
    table.sort(sortedButtonKeys)
end

--- Rebuild sorted color keys and groups from styles.colors.
local function rebuildColorKeys()
    sortedColorKeys = {}
    for k in pairs(styles.colors) do
        sortedColorKeys[#sortedColorKeys + 1] = k
    end
    table.sort(sortedColorKeys)
    colorGroups = buildColorGroups()
end

--- Capitalize the first letter of a string.
local function capitalize(s)
    return s:sub(1, 1):upper() .. s:sub(2)
end

--- Add a new color preset group: base, Hover, Active.
--- e.g. name="purple" creates purple, purpleHover, purpleActive
local function addNewColorPreset(name)
    if not name or name == "" then
        notifications.warn("Enter a name for the new color preset.")
        return
    end
    if styles.colors[name] then
        notifications.warn("Color preset '" .. name .. "' already exists.")
        return
    end

    local suffixes = { "", "Hover", "Active" }
    for _, suffix in ipairs(suffixes) do
        local key = name .. suffix
        if not styles.colors[key] then
            styles.colors[key] = { 0.5, 0.5, 0.5, 1.0 }
        end
    end

    rebuildColorKeys()
    notifications.success("Added color preset group: " .. name)
end

--------------------------------------------------------------------------------
-- Snapshot / Restore / Sync
--------------------------------------------------------------------------------

local function captureSnapshot()
    snapshotColors = {}
    for k, v in pairs(styles.colors) do
        snapshotColors[k] = deepCopyColor(v)
    end

    snapshotButtons = {}
    editButtons = {}
    for k, v in pairs(styles.buttonDefaults) do
        snapshotButtons[k] = buildEditButton(v)
        editButtons[k] = buildEditButton(v)
    end

    hasSnapshot = true

    sortedColorKeys = {}
    for k in pairs(styles.colors) do
        sortedColorKeys[#sortedColorKeys + 1] = k
    end
    table.sort(sortedColorKeys)

    rebuildSortedButtonKeys()
    colorGroups = buildColorGroups()
end

--- Write edit copy colors back into styles.buttonDefaults so the mod sees changes live.
local function syncButtonToStyles(key)
    local edit = editButtons[key]
    local group = styles.buttonDefaults[key]
    if not edit or not group then return end
    for _, sub in ipairs({"bg", "hover", "active", "text"}) do
        local e = edit[sub]
        local t = group[sub]
        if e and t then
            t[1], t[2], t[3], t[4] = e[1], e[2], e[3], e[4]
        end
    end
    -- Sync border flag
    group.border = edit.border or nil
end

local function restoreSnapshot()
    if not hasSnapshot then return end

    for k, v in pairs(snapshotColors) do
        local target = styles.colors[k]
        if target then
            target[1], target[2], target[3], target[4] = v[1], v[2], v[3], v[4]
        end
    end

    for k, snap in pairs(snapshotButtons) do
        local edit = editButtons[k]
        if edit then
            for _, sub in ipairs(BUTTON_COLOR_KEYS) do
                local s = snap[sub]
                local e = edit[sub]
                if s and e then
                    e[1], e[2], e[3], e[4] = s[1], s[2], s[3], s[4]
                end
            end
            edit.border = snap.border
            edit.borderSize = snap.borderSize
            syncButtonToStyles(k)
        end
    end

    -- Remove any user-added styles that weren't in the original snapshot
    for k in pairs(editButtons) do
        if not snapshotButtons[k] then
            editButtons[k] = nil
            if styles.buttonDefaults[k] then
                styles.buttonDefaults[k] = nil
            end
        end
    end
    rebuildSortedButtonKeys()

    -- Remove any user-added color presets
    for k in pairs(styles.colors) do
        if not snapshotColors[k] then
            styles.colors[k] = nil
        end
    end
    rebuildColorKeys()
end

local function restoreColorPreset(key)
    if not hasSnapshot or not snapshotColors[key] then return end
    local target = styles.colors[key]
    local src = snapshotColors[key]
    if target and src then
        target[1], target[2], target[3], target[4] = src[1], src[2], src[3], src[4]
    end
end

local function restoreButtonGroupEdit(key)
    local snap = snapshotButtons[key]
    local edit = editButtons[key]
    if not snap or not edit then return end
    for _, sub in ipairs(BUTTON_COLOR_KEYS) do
        local s = snap[sub]
        local e = edit[sub]
        if s and e then
            e[1], e[2], e[3], e[4] = s[1], s[2], s[3], s[4]
        end
    end
    edit.border = snap.border
    edit.borderSize = snap.borderSize
    syncButtonToStyles(key)
end

--------------------------------------------------------------------------------
-- Add New Style
--------------------------------------------------------------------------------

local function addNewStyle(name)
    if not name or name == "" then
        notifications.warn("Enter a name for the new style.")
        return
    end
    if editButtons[name] then
        notifications.warn("Style '" .. name .. "' already exists.")
        return
    end

    local edit = buildBlankButton()
    editButtons[name] = edit

    -- Also inject into styles.buttonDefaults so PushButton/PopButton works
    styles.buttonDefaults[name] = {
        bg     = deepCopyColor(edit.bg),
        hover  = deepCopyColor(edit.hover),
        active = deepCopyColor(edit.active),
        text   = deepCopyColor(edit.text),
    }

    rebuildSortedButtonKeys()
    notifications.success("Added new style: " .. name)
end

--------------------------------------------------------------------------------
-- Export (only changed values)
--------------------------------------------------------------------------------

local function exportStyles()
    local data = { colors = {}, buttonDefaults = {} }
    local hasAny = false

    for k, v in pairs(styles.colors) do
        local snap = snapshotColors[k]
        if not snap or not colorsEqual(v, snap) then
            data.colors[k] = { v[1], v[2], v[3], v[4] }
            hasAny = true
        end
    end

    for k, edit in pairs(editButtons) do
        local snap = snapshotButtons[k]
        local entry = {}
        local anyChanged = false

        if not snap then
            -- Entirely new style: export everything
            for _, sub in ipairs(BUTTON_COLOR_KEYS) do
                entry[sub] = { edit[sub][1], edit[sub][2], edit[sub][3], edit[sub][4] }
            end
            entry.border = edit.border
            entry.borderSize = edit.borderSize
            anyChanged = true
        else
            -- Existing style: only export diffs
            for _, sub in ipairs(BUTTON_COLOR_KEYS) do
                if not colorsEqual(edit[sub], snap[sub]) then
                    entry[sub] = { edit[sub][1], edit[sub][2], edit[sub][3], edit[sub][4] }
                    anyChanged = true
                end
            end
            if edit.border ~= snap.border then
                entry.border = edit.border
                anyChanged = true
            end
            if edit.borderSize ~= snap.borderSize then
                entry.borderSize = edit.borderSize
                anyChanged = true
            end
        end

        if anyChanged then
            data.buttonDefaults[k] = entry
            hasAny = true
        end
    end

    if not hasAny then
        notifications.info("No changes to export.")
        return
    end

    local ok, encoded = pcall(json.encode, data)
    if not ok then
        notifications.error("Export failed: " .. tostring(encoded))
        return
    end

    local path = "data/styles_export.json"
    local file, err = io.open(path, "w")
    if not file then
        notifications.error("Export failed: " .. tostring(err))
        return
    end

    file:write(encoded)
    file:close()
    notifications.success("Styles exported to " .. path)
end

--------------------------------------------------------------------------------
-- UI: Color Presets Tab
--------------------------------------------------------------------------------

--- Label width as a 3-column span (25% of available, matches one RGBA drag slider).
local LABEL_COLS = 3

local function drawColorPresetsTab()
    if not colorGroups then return end

    local expandIcon = utils.resolveIcon("UnfoldMoreHorizontal") or "+"
    local collapseIcon = utils.resolveIcon("UnfoldLessHorizontal") or "-"
    local addIcon = utils.resolveIcon("Plus") or "+"
    if controls.IconButton(expandIcon .. "##scp_expand_colors", true) then pendingColorsExpand = true end
    tooltips.Show("Expand all groups")
    ImGui.SameLine()
    if controls.IconButton(collapseIcon .. "##scp_collapse_colors", true) then pendingColorsExpand = false end
    tooltips.Show("Collapse all groups")

    -- Add new color preset row
    ImGui.SameLine()
    ImGui.Dummy(8, 0)
    ImGui.SameLine()
    local newName, nameChanged = controls.InputText(addIcon, "scp_new_color_name", newColorName, { tooltip = "Base name for new color preset (creates name, nameHover, nameActive)", cols = 6 })
    if nameChanged then newColorName = newName end
    ImGui.SameLine()
    if controls.Button("Add Preset", "active") then
        addNewColorPreset(newColorName)
        newColorName = ""
    end
    tooltips.Show("Create color preset group with base, Hover, and Active variants")

    controls.BeginFillChild("scp_colors", { footerHeight = ImGui.GetFrameHeightWithSpacing() })

    local resetIcon = utils.resolveIcon("UndoVariant") or "R"

    for _, group in ipairs(colorGroups) do
        local visibleKeys = {}
        for _, key in ipairs(group.keys) do
            if matchesFilter(key, filterText) then
                visibleKeys[#visibleKeys + 1] = key
            end
        end

        if #visibleKeys > 0 then
            local nodeLabel = group.prefix .. " (" .. #visibleKeys .. ")"
            if pendingColorsExpand ~= nil then
                ImGui.SetNextItemOpen(pendingColorsExpand, ImGuiCond.Always)
            end
            if ImGui.TreeNode(nodeLabel) then
                for _, key in ipairs(visibleKeys) do
                    local color = styles.colors[key]
                    if color then
                        -- Label button with proportional width (3/12 = one RGBA drag)
                        controls.Button(key, "label", controls.ColWidth(LABEL_COLS))
                        ImGui.SameLine()

                        -- Color picker fills remaining width
                        ImGui.SetNextItemWidth(ImGui.GetContentRegionAvail())
                        local newColor, changed = ImGui.ColorEdit4("##scp_c_" .. key, color, ImGuiColorEditFlags.NoOptions)
                        if changed then
                            color[1], color[2], color[3], color[4] = newColor[1], newColor[2], newColor[3], newColor[4]
                        end

                        ImGui.SameLine()
                        if controls.IconButton(resetIcon .. "##scp_cr_" .. key, true) then
                            restoreColorPreset(key)
                        end
                        tooltips.Show("Reset " .. key .. " to snapshot value")
                    end
                end
                ImGui.TreePop()
            end
        end
    end

    controls.EndFillChild("scp_colors")
    pendingColorsExpand = nil
end

--------------------------------------------------------------------------------
-- UI: Button Styles Tab
--------------------------------------------------------------------------------

--- Push preview colors from an edit copy using raw ImGui calls.
local function pushPreviewButton(edit)
    ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
    if edit.border then
        local bc = edit.borderColor
        ImGui.PushStyleColor(ImGuiCol.Border, bc[1], bc[2], bc[3], bc[4])
        ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, edit.borderSize)
    end
    local bg, hv, ac, tx = edit.bg, edit.hover, edit.active, edit.text
    ImGui.PushStyleColor(ImGuiCol.Button,        bg[1], bg[2], bg[3], bg[4])
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered,  hv[1], hv[2], hv[3], hv[4])
    ImGui.PushStyleColor(ImGuiCol.ButtonActive,   ac[1], ac[2], ac[3], ac[4])
    ImGui.PushStyleColor(ImGuiCol.Text,           tx[1], tx[2], tx[3], tx[4])
end

local function popPreviewButton(edit)
    ImGui.PopStyleColor(4)
    if edit.border then
        ImGui.PopStyleVar()
        ImGui.PopStyleColor()
    end
    ImGui.PopStyleVar()
end

--- Color picker labels for the button editor
local BUTTON_COLOR_LABELS = {
    bg          = "bg",
    hover       = "hover",
    active      = "active",
    text        = "text",
    borderColor = "borderColor",
}

local function drawButtonStylesTab()
    if not sortedButtonKeys or not editButtons then return end

    local expandIcon = utils.resolveIcon("UnfoldMoreHorizontal") or "+"
    local collapseIcon = utils.resolveIcon("UnfoldLessHorizontal") or "-"
    local addIcon = utils.resolveIcon("Plus") or "+"
    if controls.IconButton(expandIcon .. "##scp_expand_buttons", true) then pendingButtonsExpand = true end
    tooltips.Show("Expand all")
    ImGui.SameLine()
    if controls.IconButton(collapseIcon .. "##scp_collapse_buttons", true) then pendingButtonsExpand = false end
    tooltips.Show("Collapse all")

    -- Add new style row
    ImGui.SameLine()
    ImGui.Dummy(8, 0)
    ImGui.SameLine()
    local newName, nameChanged = controls.InputText(addIcon, "scp_new_style_name", newStyleName, { tooltip = "Name for new button style", cols = 6 })
    if nameChanged then newStyleName = newName end
    ImGui.SameLine()
    if controls.Button("Add Style", "active") then
        addNewStyle(newStyleName)
        newStyleName = ""
    end
    tooltips.Show("Create a new button style with default colors")

    controls.BeginFillChild("scp_buttons", { footerHeight = ImGui.GetFrameHeightWithSpacing() })

    local resetIcon = utils.resolveIcon("UndoVariant") or "R"

    for _, groupKey in ipairs(sortedButtonKeys) do
        if matchesFilter(groupKey, filterText) then
            local edit = editButtons[groupKey]
            if edit then
                if pendingButtonsExpand ~= nil then
                    ImGui.SetNextItemOpen(pendingButtonsExpand, ImGuiCond.Always)
                end
                if ImGui.TreeNode(groupKey) then

                    -- All color properties for every button
                    for _, sub in ipairs(BUTTON_COLOR_KEYS) do
                        local color = edit[sub]
                        if color then
                            local label = BUTTON_COLOR_LABELS[sub] or sub
                            -- Label button with proportional width (3/12 = one RGBA drag)
                            controls.Button(label, "label", controls.ColWidth(LABEL_COLS))
                            ImGui.SameLine()

                            -- Color picker fills remaining width
                            ImGui.SetNextItemWidth(ImGui.GetContentRegionAvail())
                            local newColor, changed = ImGui.ColorEdit4("##scp_b_" .. groupKey .. "_" .. sub, color, ImGuiColorEditFlags.NoOptions)
                            if changed then
                                color[1], color[2], color[3], color[4] = newColor[1], newColor[2], newColor[3], newColor[4]
                                syncButtonToStyles(groupKey)
                            end
                        end
                    end

                    -- Border toggle
                    local borderVal, borderChanged = controls.Checkbox(
                        "border##scp_b_" .. groupKey .. "_borderToggle",
                        edit.border,
                        { tooltip = "Enable/disable border outline for this style" }
                    )
                    if borderChanged then
                        edit.border = borderVal
                        syncButtonToStyles(groupKey)
                    end

                    -- Border size slider (always visible so you can set it before toggling)
                    local newSize, sizeChanged = controls.SliderFloat(
                        nil,
                        "scp_b_" .. groupKey .. "_borderSize",
                        edit.borderSize, 0.0, 6.0,
                        { format = "%.1f", tooltip = "Border thickness" }
                    )
                    if sizeChanged then
                        edit.borderSize = newSize
                    end

                    controls.Separator(4, 4)

                    -- Live preview at 50% width
                    local previewWidth = math.floor(ImGui.GetContentRegionAvail() * 0.5)
                    pushPreviewButton(edit)
                    ImGui.Button("Preview " .. groupKey, previewWidth, 0)
                    popPreviewButton(edit)
                    tooltips.Show("Live preview with current colors")

                    -- Reset button
                    ImGui.SameLine()
                    if controls.IconButton(resetIcon .. "##scp_br_" .. groupKey, true) then
                        restoreButtonGroupEdit(groupKey)
                    end
                    tooltips.Show("Reset " .. groupKey .. " to snapshot values")

                    -- Show if this is a user-added style (no snapshot)
                    if not snapshotButtons[groupKey] then
                        ImGui.SameLine()
                        controls.TextMuted("(new)")
                    end

                    ImGui.TreePop()
                end
            end
        end
    end

    controls.EndFillChild("scp_buttons")
    pendingButtonsExpand = nil
end

--------------------------------------------------------------------------------
-- UI: Footer + Main Window
--------------------------------------------------------------------------------

local function drawFooter()
    local resetIcon = utils.resolveIcon("UndoVariant") or "R"
    local exportIcon = utils.resolveIcon("Export") or "E"

    if controls.Button(resetIcon .. " Reset All", "danger") then
        restoreSnapshot()
    end
    tooltips.Show("Restore all colors and button styles to their snapshot values")

    ImGui.SameLine()

    if controls.Button(exportIcon .. " Export Styles", "active") then
        exportStyles()
    end
    tooltips.Show("Export changed colors to data/styles_export.json")
end

local function drawWindow()
    local hasColors = styles.colors and next(styles.colors)
    local hasButtons = styles.buttonDefaults and next(styles.buttonDefaults)

    ImGui.SetNextWindowSize(500, 650, ImGuiCond.FirstUseEver)
    local visible, open = ImGui.Begin("Style Color Preview", true, ImGuiWindowFlags.None)
    if not open then
        isOpen = false
        ImGui.End()
        return
    end

    if visible then
        if not hasColors and not hasButtons then
            controls.TextMuted("No color presets or button styles found.")
            ImGui.End()
            return
        end

        local searchIcon = utils.resolveIcon("Magnify") or "?"
        local newFilter, changed = controls.InputText(searchIcon, "scp_filter", filterText, { tooltip = "Filter by name (case-insensitive)" })
        if changed then filterText = newFilter end

        if filterText ~= "" then
            ImGui.SameLine()
            local clearIcon = utils.resolveIcon("CloseCircle") or "X"
            if controls.IconButton(clearIcon .. "##scp_clear_filter", true) then
                filterText = ""
            end
            tooltips.Show("Clear filter")
        end

        tabs.bar("scp_tabs", {
            { label = "Color Presets",  content = drawColorPresetsTab },
            { label = "Button Styles",  content = drawButtonStylesTab },
        })

        drawFooter()
    end

    ImGui.End()
end

--------------------------------------------------------------------------------
-- CET Registration
--------------------------------------------------------------------------------

registerForEvent("onInit", function()
    wu = GetMod("WindowUtils")
    if not wu then
        print("[WindowUtilsDev] WindowUtils not found!")
        return
    end
    styles        = wu.Styles
    controls      = wu.Controls
    tooltips      = wu.Tooltips
    notifications = wu.Notify
    tabs          = wu.Tabs
    utils         = wu.Utils
end)

registerHotkey("ToggleStyleColorPreview", "Toggle Style Color Preview", function()
    if not wu then return end
    isOpen = not isOpen
    if isOpen and not hasSnapshot then
        captureSnapshot()
    end
end)

registerForEvent("onDraw", function()
    if not wu or not isOpen or not isOverlayOpen then return end
    controls.cacheFrameState()
    drawWindow()
end)

registerForEvent("onOverlayOpen", function()
    isOverlayOpen = true
end)

registerForEvent("onOverlayClose", function()
    if hasSnapshot then restoreSnapshot() end
    isOpen = false
    isOverlayOpen = false
end)
