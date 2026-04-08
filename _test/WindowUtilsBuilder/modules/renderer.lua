------------------------------------------------------
-- WindowUtils Builder - Renderer
-- Dispatch table for rendering elements via WindowUtils
------------------------------------------------------

local element_defs = require("modules/element_defs")

local renderer = {}

local controls, styles, splitter, tabs, dd, search
local projectRef = nil
local draggingId = nil
local pendingReparent = nil

-- Transient preview state keyed by element ID
local previewState = {}

local PANEL_DEFAULT_BG = { 0.65, 0.7, 1.0, 0.045 }

local function pushPanelBg()
    ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(PANEL_DEFAULT_BG[1], PANEL_DEFAULT_BG[2], PANEL_DEFAULT_BG[3], PANEL_DEFAULT_BG[4]))
end

local function popPanelBg()
    ImGui.PopStyleColor()
end

--------------------------------------------------------------------------------
-- Preview state helpers
--------------------------------------------------------------------------------

local function getPreview(elId, key, default)
    if not previewState[elId] then previewState[elId] = {} end
    if previewState[elId][key] == nil then previewState[elId][key] = default end
    return previewState[elId][key]
end

local function setPreview(elId, key, value)
    if not previewState[elId] then previewState[elId] = {} end
    previewState[elId][key] = value
end

-- Tracks the last child element clicked inside a container
local clickedChildId = nil
-- Tracks if a child element was right-clicked this frame (blocks container context menu)
local childRightClicked = false

--------------------------------------------------------------------------------
-- Zone rendering
--------------------------------------------------------------------------------

local function renderChildren(zone)
    if not zone.children or #zone.children == 0 then return end
    if not projectRef then return end
    for _, childId in ipairs(zone.children) do
        local child = projectRef.findElement(childId)
        if child then
            renderer.render(child)
        end
    end
end

-- Per-zone DragDrop states keyed by "elId_zoneIdx"
local zoneDdStates = {}

local function getZoneDdState(elId, zoneIdx)
    local key = elId .. "_" .. zoneIdx
    if not zoneDdStates[key] then
        zoneDdStates[key] = dd.createState()
    end
    return zoneDdStates[key]
end

local function renderZoneOrPlaceholder(zone, elId, zoneIdx)
    local isTarget = false
    if projectRef then
        local sel = projectRef.getSelected()
        if sel and sel.id == elId then
            isTarget = (projectRef.getSelectedZone() == zoneIdx)
        end
    end

    -- Render children with DragDrop reordering within the zone
    local children = zone.children
    if children and #children > 0 then
        local ddSt = getZoneDdState(elId, zoneIdx)
        for ci, childId in ipairs(children) do
            local child = projectRef and projectRef.findElement(childId) or nil
            if child then
                local ctx = dd.getItemContext(ci, ddSt)
                if ddSt.draggingIndex then dd.drawSeparator(ctx.dropAbove) end
                dd.pushItemStyles(ctx)

                renderer.render(child)

                local shouldReorder, fromIdx, toIdx = dd.handleDrag(ci, #children, ddSt)
                dd.popItemStyles(ctx)
                if ddSt.draggingIndex then dd.drawSeparator(ctx.dropBelow) end

                if shouldReorder and fromIdx and toIdx and fromIdx ~= toIdx then
                    -- Swap children in the zone array
                    if projectRef then
                        projectRef.touchElement(elId)
                    end
                    local moved = table.remove(children, fromIdx)
                    table.insert(children, toIdx, moved)
                end
            end
        end
        dd.updateCursor(ddSt)
    else
        ImGui.TextDisabled("(empty)")
    end

    -- Click empty space to select this zone as target
    -- Use an invisible button that fills remaining space
    local w, _ = ImGui.GetContentRegionAvail()
    if w > 0 then
        ImGui.InvisibleButton("##zone_click_" .. elId .. "_" .. zoneIdx, w, math.max(20, 4))
        if ImGui.IsItemClicked(0) then
            if projectRef then
                projectRef.setSelected(elId)
                projectRef.setSelectedZone(zoneIdx)
            end
        end
    end

    -- Orange outline on the active target zone
    if isTarget then
        local drawList = ImGui.GetWindowDrawList()
        local winX, winY = ImGui.GetWindowPos()
        local winW, winH = ImGui.GetWindowSize()
        local ORANGE = ImGui.GetColorU32(1.0, 0.6, 0.0, 0.8)
        ImGui.ImDrawListAddRect(drawList, winX, winY, winX + winW, winY + winH, ORANGE, 0, 0, 2.0)
    end

    -- Drop target for drag-to-reparent from outside
    if draggingId and draggingId ~= elId then
        ImGui.InvisibleButton("##drop_" .. elId .. "_" .. zoneIdx, w > 0 and w or 10, 4)
        if ImGui.IsItemHovered() then
            local drawList = ImGui.GetWindowDrawList()
            local minX, minY = ImGui.GetItemRectMin()
            local maxX, maxY = ImGui.GetItemRectMax()
            ImGui.ImDrawListAddRectFilled(drawList, minX, minY, maxX, maxY, ImGui.GetColorU32(0.26, 0.59, 0.98, 0.4))
            if not ImGui.IsMouseDown(0) then
                pendingReparent = { elementId = draggingId, containerId = elId, zoneIdx = zoneIdx }
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Dispatch table
--------------------------------------------------------------------------------

local dispatch = {}

-- Buttons
dispatch["Button"] = function(el)
    local p = el.props
    controls.Button(p.label or el.name, p.style or "inactive", p.width or -1, p.height or 0)
end

dispatch["ToggleButton"] = function(el)
    local p = el.props
    local active = getPreview(el.id, "active", false)
    if controls.ToggleButton(p.label or el.name, active, p.width or -1, p.height or 0) then
        setPreview(el.id, "active", not active)
    end
end

dispatch["DynamicButton"] = function(el)
    local p = el.props
    controls.DynamicButton(p.label or el.name, p.icon, {
        style = p.style or "inactive",
        width = p.width or -1,
        height = p.height or 0,
        minChars = p.minChars or 3,
        tooltip = p.tooltip,
    })
end

dispatch["HoldButton"] = function(el)
    local p = el.props
    controls.HoldButton("builder_hold_" .. el.id, p.label or el.name, {
        duration = p.duration or 1.0,
        style = p.style or "inactive",
        width = p.width or -1,
    })
end

dispatch["ActionButton"] = function(el)
    local p = el.props
    controls.ActionButton("builder_act_" .. el.id, p.label or el.name, {
        style = p.style or "inactive",
        width = p.width or -1,
    })
end

dispatch["ButtonRow"] = function(el)
    local p = el.props
    local defs = {}
    if p.buttons then
        for _, btn in ipairs(p.buttons) do
            defs[#defs + 1] = {
                label = btn.label,
                icon = btn.icon,
                style = btn.style or "inactive",
                weight = btn.weight or 1,
                width = btn.width,
                height = btn.height,
                disabled = btn.disabled,
                tooltip = btn.tooltip,
            }
        end
    end
    controls.ButtonRow(defs, { gap = p.gap })
end

dispatch["DisabledButton"] = function(el)
    local p = el.props
    controls.DisabledButton(p.label or el.name, p.width or -1, p.height or 0)
end

dispatch["FullWidthButton"] = function(el)
    local p = el.props
    controls.Button(p.label or el.name, p.style or "inactive", -1, 0)
end

dispatch["IconButton"] = function(el)
    local p = el.props
    controls.IconButton(p.icon or "?", p.clickable or false)
end

-- Sliders
dispatch["SliderFloat"] = function(el)
    local p = el.props
    local val = getPreview(el.id, "value", (p.default or p.min or 0))
    local newVal, changed = controls.SliderFloat(p.icon, "builder_" .. el.id, val, p.min or 0, p.max or 1, {
        format = p.format, cols = p.cols, default = p.default, tooltip = p.tooltip,
    })
    if changed then setPreview(el.id, "value", newVal) end
end

dispatch["SliderInt"] = function(el)
    local p = el.props
    local val = getPreview(el.id, "value", (p.default or p.min or 0))
    local newVal, changed = controls.SliderInt(p.icon, "builder_" .. el.id, val, p.min or 0, p.max or 100, {
        format = p.format, cols = p.cols, default = p.default, tooltip = p.tooltip,
    })
    if changed then setPreview(el.id, "value", newVal) end
end

dispatch["SliderDisabled"] = function(el)
    local p = el.props
    controls.SliderDisabled(p.icon, p.label or el.name)
end

-- Drags
dispatch["DragFloat"] = function(el)
    local p = el.props
    local val = getPreview(el.id, "value", (p.default or p.min or 0))
    local newVal, changed = controls.DragFloat(p.icon, "builder_" .. el.id, val, p.min or 0, p.max or 1, {
        speed = p.speed, format = p.format, cols = p.cols, default = p.default, tooltip = p.tooltip,
    })
    if changed then setPreview(el.id, "value", newVal) end
end

dispatch["DragInt"] = function(el)
    local p = el.props
    local val = getPreview(el.id, "value", (p.default or p.min or 0))
    local newVal, changed = controls.DragInt(p.icon, "builder_" .. el.id, val, p.min or 0, p.max or 100, {
        speed = p.speed, format = p.format, cols = p.cols, default = p.default, tooltip = p.tooltip,
    })
    if changed then setPreview(el.id, "value", newVal) end
end

dispatch["DragFloatRow"] = function(el)
    local p = el.props
    controls.DragFloatRow(p.icon, "builder_" .. el.id, {
        { value = getPreview(el.id, "v1", 0), min = p.min or 0, max = p.max or 1 },
    }, { speed = p.speed, cols = p.cols, tooltip = p.tooltip })
end

dispatch["DragIntRow"] = function(el)
    local p = el.props
    controls.DragIntRow(p.icon, "builder_" .. el.id, {
        { value = getPreview(el.id, "v1", 0), min = p.min or 0, max = p.max or 100 },
    }, { speed = p.speed, cols = p.cols, tooltip = p.tooltip })
end

-- Inputs
dispatch["InputText"] = function(el)
    local p = el.props
    local val = getPreview(el.id, "text", "")
    local newVal, changed = controls.InputText(p.icon, "builder_" .. el.id, val, {
        maxLength = p.maxLength or 256, cols = p.cols, tooltip = p.tooltip,
    })
    if changed then setPreview(el.id, "text", newVal) end
end

dispatch["InputFloat"] = function(el)
    local p = el.props
    local val = getPreview(el.id, "value", (p.default or 0))
    local newVal, changed = controls.InputFloat(p.icon, "builder_" .. el.id, val, {
        format = p.format, cols = p.cols, tooltip = p.tooltip,
    })
    if changed then setPreview(el.id, "value", newVal) end
end

dispatch["InputInt"] = function(el)
    local p = el.props
    local val = getPreview(el.id, "value", (p.default or 0))
    local newVal, changed = controls.InputInt(p.icon, "builder_" .. el.id, val, {
        cols = p.cols, tooltip = p.tooltip,
    })
    if changed then setPreview(el.id, "value", newVal) end
end

-- Selection
dispatch["Checkbox"] = function(el)
    local p = el.props
    local val = getPreview(el.id, "checked", (p.default or false))
    local newVal, changed = controls.Checkbox(p.label or el.name, val, { tooltip = p.tooltip })
    if changed then setPreview(el.id, "checked", newVal) end
end

dispatch["Combo"] = function(el)
    local p = el.props
    local items = p.items or { "Option 1", "Option 2" }
    local val = getPreview(el.id, "index", 0)
    local newVal, changed = controls.Combo(p.icon, "builder_" .. el.id, val, items, {
        cols = p.cols, tooltip = p.tooltip,
    })
    if changed then setPreview(el.id, "index", newVal) end
end

dispatch["ColorEdit4"] = function(el)
    local p = el.props
    local val = getPreview(el.id, "color", p.default or { 1, 1, 1, 1 })
    local newVal, changed = controls.ColorEdit4(p.icon, "builder_" .. el.id, val, {
        tooltip = p.tooltip,
    })
    if changed then setPreview(el.id, "color", newVal) end
end

-- Display
dispatch["ProgressBar"] = function(el)
    local p = el.props
    local w, _ = ImGui.GetContentRegionAvail()
    controls.ProgressBar(p.fraction or 0.5, p.width or w, p.height or 0, p.overlay or "", p.style or "default")
end

dispatch["StatusBar"] = function(el)
    local p = el.props
    controls.StatusBar(p.label or el.name, p.value, { style = p.style or "statusbar" })
end

dispatch["TextMuted"] = function(el)
    controls.TextMuted(el.props.text or "Muted text")
end

dispatch["TextSuccess"] = function(el)
    controls.TextSuccess(el.props.text or "Success text")
end

dispatch["TextDanger"] = function(el)
    controls.TextDanger(el.props.text or "Danger text")
end

dispatch["TextWarning"] = function(el)
    controls.TextWarning(el.props.text or "Warning text")
end

dispatch["SectionHeader"] = function(el)
    local p = el.props
    controls.SectionHeader(p.text or "Section", p.spacingBefore, p.spacingAfter, p.icon)
end

dispatch["Separator"] = function(el)
    local p = el.props
    controls.Separator(p.before, p.after)
end

-- Layout containers

dispatch["SplitterH"] = function(el)
    local p = el.props
    local zones = el.zones
    if not zones or #zones < 2 then return end
    pushPanelBg()
    splitter.horizontal("builder_" .. el.id, function()
        renderZoneOrPlaceholder(zones[1], el.id, 1)
    end, function()
        renderZoneOrPlaceholder(zones[2], el.id, 2)
    end, { defaultPct = p.defaultPct or 0.5, minPct = p.minPct or 0.1, maxPct = p.maxPct or 0.9 })
    popPanelBg()
end

dispatch["SplitterV"] = function(el)
    local p = el.props
    local zones = el.zones
    if not zones or #zones < 2 then return end
    pushPanelBg()
    splitter.vertical("builder_" .. el.id, function()
        renderZoneOrPlaceholder(zones[1], el.id, 1)
    end, function()
        renderZoneOrPlaceholder(zones[2], el.id, 2)
    end, { defaultPct = p.defaultPct or 0.5, minPct = p.minPct or 0.1, maxPct = p.maxPct or 0.9 })
    popPanelBg()
end

dispatch["SplitterMulti"] = function(el)
    local p = el.props
    local zones = el.zones
    if not zones or #zones == 0 then return end
    local panels = {}
    for i, zone in ipairs(zones) do
        panels[i] = {
            content = function()
                renderZoneOrPlaceholder(zone, el.id, i)
            end,
        }
    end
    pushPanelBg()
    splitter.multi("builder_" .. el.id, panels, {
        direction = p.direction or "horizontal",
        grabWidth = p.grabWidth,
    })
    popPanelBg()
end

dispatch["SplitterToggle"] = function(el)
    local p = el.props
    local zones = el.zones
    if not zones or #zones < 2 then return end
    pushPanelBg()
    splitter.toggle("builder_" .. el.id, {
        {
            content = function()
                renderZoneOrPlaceholder(zones[1], el.id, 1)
            end,
        },
        {
            content = function()
                renderZoneOrPlaceholder(zones[2], el.id, 2)
            end,
        },
    }, { side = p.side or "left", size = p.size or 200, barWidth = p.barWidth, defaultOpen = p.defaultOpen ~= false })
    popPanelBg()
end

dispatch["Tabs"] = function(el)
    local zones = el.zones
    if not zones or #zones == 0 then return end
    local tabDefs = {}
    for i, zone in ipairs(zones) do
        tabDefs[i] = {
            label = zone.label or ("Tab " .. i),
            content = function()
                renderZoneOrPlaceholder(zone, el.id, i)
            end,
        }
    end
    local selectedTab, tabChanged = tabs.bar("builder_" .. el.id, tabDefs, { flags = el.props.flags or 0 })
    -- When user clicks a tab, select this container and set the zone to the active tab
    if tabChanged and projectRef then
        projectRef.setSelected(el.id)
        projectRef.setSelectedZone(selectedTab)
    end
    -- Also allow clicking the tab content area to select
    if ImGui.IsMouseClicked(0) and not clickedChildId then
        local tMinX, tMinY = ImGui.GetItemRectMin()
        local tMaxX, tMaxY = ImGui.GetItemRectMax()
        local mx, my = ImGui.GetMousePos()
        if mx >= tMinX and mx <= tMaxX and my >= tMinY and my <= tMaxY then
            if projectRef then
                projectRef.setSelected(el.id)
                -- Use the currently visible tab as the zone
                local currentTab = tabs.getSelected("builder_" .. el.id)
                if currentTab then
                    projectRef.setSelectedZone(currentTab)
                end
            end
        end
    end
    -- Orange outline when this tab container is selected
    local isTarget = false
    if projectRef then
        local sel = projectRef.getSelected()
        if sel and sel.id == el.id then isTarget = true end
    end
    if isTarget then
        local drawList = ImGui.GetWindowDrawList()
        local tMinX, tMinY = ImGui.GetItemRectMin()
        local tMaxX, tMaxY = ImGui.GetItemRectMax()
        local ORANGE = ImGui.GetColorU32(1.0, 0.6, 0.0, 0.8)
        ImGui.ImDrawListAddRect(drawList, tMinX, tMinY, tMaxX, tMaxY, ORANGE, 4, 0, 2.0)
    end
end

dispatch["Panel"] = function(el)
    local p = el.props
    local zones = el.zones
    if not zones or #zones == 0 then return end
    controls.Panel("builder_panel_" .. el.id, function()
        renderZoneOrPlaceholder(zones[1], el.id, 1)
    end, {
        bg = p.bg,
        border = p.border,
        borderOnHover = p.borderOnHover,
        width = p.width or 0,
        height = p.height or "auto",
    })
    -- Click the panel to select it (mouse position hit test)
    local pMinX, pMinY = ImGui.GetItemRectMin()
    local pMaxX, pMaxY = ImGui.GetItemRectMax()
    if ImGui.IsMouseClicked(0) and not clickedChildId then
        local mx, my = ImGui.GetMousePos()
        if mx >= pMinX and mx <= pMaxX and my >= pMinY and my <= pMaxY then
            if projectRef then
                projectRef.setSelected(el.id)
                projectRef.setSelectedZone(1)
            end
        end
    end
    -- Orange outline when this panel is the active target
    local isTarget = false
    if projectRef then
        local sel = projectRef.getSelected()
        if sel and sel.id == el.id then isTarget = true end
    end
    if isTarget then
        local drawList = ImGui.GetWindowDrawList()
        local ORANGE = ImGui.GetColorU32(1.0, 0.6, 0.0, 0.8)
        ImGui.ImDrawListAddRect(drawList, pMinX, pMinY, pMaxX, pMaxY, ORANGE, 4, 0, 2.0)
    end
end

dispatch["Column"] = function(el)
    local p = el.props
    local zones = el.zones
    if not zones or #zones == 0 then return end
    local defs = {}
    for i, zone in ipairs(zones) do
        defs[i] = {
            flex = zone.flex or 1,
            height = zone.height,
            auto = zone.auto,
            content = function()
                renderZoneOrPlaceholder(zone, el.id, i)
            end,
        }
    end
    controls.Column("builder_col_" .. el.id, defs, { gap = p.spacing })
end

dispatch["Row"] = function(el)
    local p = el.props
    local zones = el.zones
    if not zones or #zones == 0 then return end
    local defs = {}
    for i, zone in ipairs(zones) do
        defs[i] = {
            flex = zone.flex or 1,
            width = zone.width,
            cols = zone.cols,
            content = function()
                renderZoneOrPlaceholder(zone, el.id, i)
            end,
        }
    end
    controls.Row("builder_row_" .. el.id, defs, { gap = p.spacing })
end

-- Advanced (placeholder labels)
dispatch["Lists"] = function(el)
    controls.Button("[Lists: " .. el.name .. "]", "label", -1, 0)
end
dispatch["Search"] = function(el)
    controls.Button("[Search: " .. el.name .. "]", "label", -1, 0)
end
dispatch["Modal"] = function(el)
    controls.Button("[Modal: " .. el.name .. "]", "label", -1, 0)
end
dispatch["Notifications"] = function(el)
    controls.Button("[Notifications: " .. el.name .. "]", "label", -1, 0)
end
dispatch["DragDrop"] = function(el)
    controls.Button("[DragDrop: " .. el.name .. "]", "label", -1, 0)
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function renderer.init(wu)
    controls = wu.Controls
    styles = wu.Styles
    splitter = wu.Splitter
    tabs = wu.Tabs
    dd = wu.DragDrop
    search = wu.Search
end

function renderer.setProject(project)
    projectRef = project
end

function renderer.setDraggingId(id)
    draggingId = id
end

function renderer.render(el)
    if not el or not el.type then return end
    local fn = dispatch[el.type]
    if fn then
        fn(el)
        -- Detect clicks on child elements inside containers
        if el.parentId and not el.zones then
            if ImGui.IsItemClicked(0) then
                clickedChildId = el.id
            end
            -- Context menu for child elements
            if ImGui.BeginPopupContextItem("##child_ctx_" .. el.id) then
                childRightClicked = true
                if ImGui.MenuItem("Select") then
                    if projectRef then projectRef.setSelected(el.id) end
                end
                if ImGui.MenuItem("Move Up") then
                    if projectRef then projectRef.moveChildInZone(el.id, "up") end
                end
                if ImGui.MenuItem("Move Down") then
                    if projectRef then projectRef.moveChildInZone(el.id, "down") end
                end
                if ImGui.MenuItem("Duplicate") then
                    if projectRef then
                        local dup = projectRef.duplicateElement(el.id)
                        if dup then
                            -- Reparent duplicate into same zone as original
                            projectRef.reparentElement(dup.id, el.parentId, el.zoneIdx)
                        end
                    end
                end
                ImGui.Separator()
                if ImGui.MenuItem("Remove") then
                    if projectRef then projectRef.removeElement(el.id) end
                end
                ImGui.EndPopup()
            end
        end
    else
        ImGui.Text("[Unknown: " .. tostring(el.type) .. "]")
    end
end

function renderer.clearState(id)
    previewState[id] = nil
end

function renderer.consumeReparent()
    local r = pendingReparent
    pendingReparent = nil
    return r
end

--- Return and clear the ID of a child element clicked inside a container.
---@return string|nil elementId
function renderer.getClickedChild()
    local id = clickedChildId
    clickedChildId = nil
    return id
end

--- Check if a child element's context menu was opened this frame.
--- Used by the canvas to skip the container's context menu.
---@return boolean
function renderer.wasChildRightClicked()
    local val = childRightClicked
    childRightClicked = false
    return val
end

return renderer
