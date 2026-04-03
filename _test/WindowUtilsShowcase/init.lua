------------------------------------------------------
-- Window Utils Showcase
-- Production-ready reference sample for the WindowUtils API.
-- Hover any interactive element for API usage info.
------------------------------------------------------

local wu = nil
local visible = false
local overlayOpen = false
local DEMO_WINDOW_NAME = "Window Utils Showcase"
local resW, resH = 1920, 1080

-- Demo state for standard controls
local demoDefaults = { slider = 0.5, checkbox = true, combo = 0, input = "Hello, World!" }
local demoState = { slider = 0.5, checkbox = true, combo = 0, input = "Hello, World!" }
local notifCounter = 0
local notifBadgeMode = "count"   -- "none", "dot", "count"
local notifBadgeCount = 0
local notifClearOnOpen = false

-- Demo state for advanced controls (percent sliders, toggles, transforms)
local advDefaults = {
    opacity = 0.75, quality = 12, speed = 5,
    featureA = true, featureB = false, featureC = true, featureD = false,
    easeFunction = "easeInOut",
}
local advState = {
    opacity = 0.75, quality = 12, speed = 5,
    featureA = true, featureB = false, featureC = true, featureD = false,
    easeFunction = "easeInOut",
}
local easingNames = { "Linear", "Ease In", "Ease In Out", "Ease Out" }
local easingKeys  = { "linear", "easeIn", "easeInOut", "easeOut" }

-- Demo state for Tooltips tab bound controls
local ttDefaults = {
    ttSliderF = 0.5, ttSliderI = 5, ttCheck = true,
    ttCombo = 0, ttInput = "demo", ttInputF = 1.5,
    ttInputI = 42, ttColor = { 0.4, 0.6, 0.8, 1.0 },
    ttTogA = true, ttTogB = false,
}
local ttState = {
    ttSliderF = 0.5, ttSliderI = 5, ttCheck = true,
    ttCombo = 0, ttInput = "demo", ttInputF = 1.5,
    ttInputI = 42, ttColor = { 0.4, 0.6, 0.8, 1.0 },
    ttTogA = true, ttTogB = false,
}

-- Demo state for drag controls with Shift precision
local dragDefaults = {
    dragFloat = 0.5, preciseFloat = 0.5, dragInt = 50, noPrecFloat = 0.5,
}
local dragState = {
    dragFloat = 0.5, preciseFloat = 0.5, dragInt = 50, noPrecFloat = 0.5,
}

-- Demo state for drag row controls
local dragRowDefaults = {
    x = 0, y = 0, z = 0,
    r = 0.5, g = 0.7, b = 0.3, a = 1.0,
    yaw = 0, tilt = 0, roll = 0, fov = 90,
    quality = 50, priority = 5, count = 10,
    rangeMin = 20, rangeMax = 80,
}
local dragRowState = {
    x = 0, y = 0, z = 0,
    r = 0.5, g = 0.7, b = 0.3, a = 1.0,
    yaw = 0, tilt = 0, roll = 0, fov = 90,
    quality = 50, priority = 5, count = 10,
    rangeMin = 20, rangeMax = 80,
}

-- Separate state for mixed buttons demo (avoids sharing x/y/z with row 1)
local mixedRowState = { x = 0, y = 0, z = 0 }
local mixedRowDragState = {} -- Persistent state for unbound mixed row

-- Separate state for label-to-value demo
local ltvRowDefaults = { x = 0, y = 0, z = 0 }
local ltvRowState = { x = 0, y = 0, z = 0 }

-- Separate state for disabled style demos
local disabledRowDefaults = { x = 0, y = 0, z = 0 }
local disabledRowState = { x = 0, y = 0, z = 0 }
local dimmedRowState = { x = 0, y = 0, z = 0 }
local dimmedColorRowState = { x = 0, y = 0, z = 0 }

-- Delta mode accumulated values
local dragRowDeltaState = { dx = 0, dy = 0, dz = 0 }
local dragRowDeltaRowState = {} -- Persistent state for unbound delta row (hover/delta accum)

-- Expand demo state
local expSizeMode = "fixed"
local expVertSizeMode = "fixed"

-- Telemetry: cached main-window metrics (updated each draw before BeginChild)
local showcaseWinX, showcaseWinY = 0, 0
local showcaseWinW, showcaseWinH = 0, 0
local showcaseIsDragging  = false
local showcaseIsAnimating = false
local showcaseIsCollapsed = false
local showcaseIsFocused   = false

-- Controls tab sidebar navigation
local controlsPage = 1
local controlsPages = {} -- populated in onInit after IconGlyphs is available

-- Search demo: defs-based approach (no beginDim/endDim needed)
local searchDemoDefs = {
    gridSnapping = { label = "Grid Snapping", category = "window", searchTerms = "snap alignment" },
    animation    = { label = "Animation",     category = "window", searchTerms = "easing duration smooth" },
    blur         = { label = "Blur",          category = "window", searchTerms = "background overlay" },
    dimming      = { label = "Dim Background",category = "window", searchTerms = "darken opacity" },
    feather      = { label = "Feathered Grid",category = "visual", searchTerms = "feather radius fade" },
    tooltips     = { label = "Tooltips",      category = "visual", searchTerms = "hover help" },
    debug        = { label = "Debug Output",  category = "visual", searchTerms = "console log" },
    lineColor    = { label = "Line Color",    category = "visual", searchTerms = "palette colour" },
}
local searchDemoData = {
    gridSnapping = true, animation = true, blur = false, dimming = false,
    feather = true, tooltips = true, debug = false, lineColor = false,
}

-- Modal demo state
local modalContentCounter = 0

-- DragDrop demo items
local dragItems = {
    { name = "First Item",  icon = "1" },
    { name = "Second Item", icon = "2" },
    { name = "Third Item",  icon = "3" },
    { name = "Fourth Item", icon = "4" },
    { name = "Fifth Item",  icon = "5" },
}

--------------------------------------------------------------------------------
-- Tab 1: Controls Demo
-- Merges: standard controls, hold buttons, action buttons, button rows,
--         toggle rows, percent sliders, transforms, grid, layout helpers,
--         and notifications.
--------------------------------------------------------------------------------

local function drawControlsDemo()
    local controls = wu.Controls
    local styles = wu.Styles

    wu.Splitter.multi("ctl_split", {
        { content = function()
            controls.Panel("ctl_nav", function()
                -- Left sidebar: DynamicButton nav (truncates text, collapses to icon)
                for _, entry in ipairs(controlsPages) do
                    if controls.DynamicButton(entry.label, entry.icon, {
                        style = controlsPage == entry.page and "active" or "inactive",
                        width = -1,
                        tooltip = entry.label,
                    }) then
                        controlsPage = entry.page
                    end
                end
            end)
        end },
        { content = function()
            controls.Panel("ctl_content", function()
            -- Right content: selected page
            if controlsPage == 1 then
                -- Standard Controls
                local c = controls.bind(demoState, demoDefaults)

                c:SliderFloat("Reload", "slider", 0.0, 1.0, {
                    format = "%.2f",
                    tooltip = "Adjusts the slider value between 0 and 1",
                })
                c:Checkbox("Enable Feature", "checkbox", {
                    tooltip = "Toggles a boolean on or off",
                })
                c:Combo("Reload", "combo", { "Option A", "Option B", "Option C" }, {
                    tooltip = "Pick one option from the dropdown",
                })
                c:InputText("Reload", "input", {
                    maxLength = 256,
                    tooltip = "Type any text value here",
                })
                ImGui.Dummy(0, 2)
                controls.TextMuted("All controls use controls.bind(data, defaults) for auto-read/write/reset.")

                controls.Separator(8, 8)

                local ac = controls.bind(advState, advDefaults)

                ac:SliderFloat("Brightness6", "opacity", 0, 1, {
                    percent = true,
                    tooltip = "Opacity as a percentage",
                })

                ac:SliderInt("TuneVariant", "quality", 1, 23, {
                    percent = true,
                    tooltip = "Quality level as a percentage",
                })

                ac:SliderInt("Speedometer", "speed", 0, 10, {
                    tooltip = "Speed value from 0 to 10",
                })

                ImGui.Dummy(0, 6)

                controls.TextMuted("Combo with transform (stored as string, shown as index):")
                local findIdx = function(key)
                    for i, k in ipairs(easingKeys) do if k == key then return i - 1 end end
                    return 0
                end
                ac:Combo("SineWave", "easeFunction", easingNames, {
                    transform = {
                        read  = function(v) return findIdx(v) end,
                        write = function(v) return easingKeys[v + 1] end,
                    },
                    tooltip = "Easing function for animations",
                })

                controls.Separator(8, 8)

                -- Drag Controls with Shift Precision
                controls.TextMuted("DragFloat / DragInt: hold Shift for precision mode")
                ImGui.Dummy(0, 2)

                local dc = controls.bind(dragState, dragDefaults)

                dc:DragFloat("Speedometer", "dragFloat", 0.0, 1.0, {
                    tooltip = "Default drag (hold Shift for precision)",
                })
                dc:DragFloat("TuneVariant", "preciseFloat", 0.0, 1.0, {
                    precisionMultiplier = 0.01,
                    tooltip = "Custom precision: Shift = 0.01x multiplier",
                })
                dc:DragInt("Counter", "dragInt", 0, 100, {
                    tooltip = "Integer drag (hold Shift for precision)",
                })
                dc:DragFloat("Cancel", "noPrecFloat", 0.0, 1.0, {
                    noPrecision = true,
                    tooltip = "Precision disabled (noPrecision = true)",
                })

                controls.Separator(8, 8)

                -- DragFloatRow / DragIntRow
                controls.TextMuted("DragFloatRow / DragIntRow: multiple drags on one line")
                ImGui.Dummy(0, 2)

                local drc = controls.bind(dragRowState, dragRowDefaults)

                controls.TextMuted("XYZ with preset DragColors:")
                drc:DragFloatRow(nil, {"x", "y", "z"}, -2000, 2000, {
                    drags = {
                        { color = styles.dragColors.x },
                        { color = styles.dragColors.y },
                        { color = styles.dragColors.z },
                    },
                })

                ImGui.Dummy(0, 4)
                controls.TextMuted("RGBA color editor with custom colors:")
                drc:DragFloatRow("Palette", {"r", "g", "b", "a"}, 0.0, 1.0, {
                    speed = 0.005,
                    drags = {
                        { color = { 1, 0.3, 0.3, 1 }, label = "R" },
                        { color = { 0.3, 1, 0.3, 1 }, label = "G" },
                        { color = { 0.3, 0.3, 1, 1 }, label = "B" },
                        { color = { 0.7, 0.7, 0.7, 1 }, label = "A" },
                    },
                })

                ImGui.Dummy(0, 4)
                controls.TextMuted("DragIntRow with fit-to-label columns:")
                drc:DragIntRow("TuneVariant", {"quality", "priority", "count"}, 0, 100, {
                    drags = {
                        { label = "Quality" },
                        { label = "Priority", fitLabel = true },
                        { label = "Count", fitLabel = true },
                    },
                })

                ImGui.Dummy(0, 4)
                controls.TextMuted("Width weighting (3 equal + 1 percent-width):")
                drc:DragFloatRow(nil, {"yaw", "tilt", "roll", "fov"}, nil, nil, {
                    speed = 0.5,
                    drags = {
                        { label = "Yaw", min = -180, max = 180 },
                        { label = "Tilt", min = -90, max = 90 },
                        { label = "Roll", min = -360, max = 360 },
                        { label = "FOV", widthPercent = 5, min = 20, max = 130 },
                    },
                })

                ImGui.Dummy(0, 4)
                controls.TextMuted("Mixed buttons + drags:")
                local mixedValues, mixedChanged = controls.DragFloatRow(nil, "posRow", {
                    { type = "button", icon = "Upload", tooltip = "Load", onClick = function() end },
                    { type = "button", icon = "Refresh", tooltip = "Update", holdDuration = 1.0, onClick = function() end },
                    { value = mixedRowState.x, color = styles.dragColors.x, label = "X", min = -2000, max = 2000, default = 0 },
                    { value = mixedRowState.y, color = styles.dragColors.y, label = "Y", min = -2000, max = 2000, default = 0 },
                    { value = mixedRowState.z, color = styles.dragColors.z, label = "Z", min = -2000, max = 2000, default = 0 },
                }, { speed = 0.1, state = mixedRowDragState })
                if mixedChanged then
                    mixedRowState.x = mixedValues[1]
                    mixedRowState.y = mixedValues[2]
                    mixedRowState.z = mixedValues[3]
                end

                ImGui.Dummy(0, 4)
                controls.TextMuted("Delta mode (drags show delta while dragging, onChange accumulates):")
                controls.DragFloatRow(nil, "delta", {
                    { value = 0, color = styles.dragColors.x, label = "X", min = -100, max = 100, default = 0 },
                    { value = 0, color = styles.dragColors.y, label = "Y", min = -100, max = 100, default = 0 },
                    { value = 0, color = styles.dragColors.z, label = "Z", min = -100, max = 100, default = 0 },
                }, {
                    mode = "delta",
                    speed = 0.1,
                    state = dragRowDeltaRowState,
                    onChange = function(index, delta)
                        local keys = { "dx", "dy", "dz" }
                        dragRowDeltaState[keys[index]] = dragRowDeltaState[keys[index]] + delta
                    end,
                    onReset = function(index)
                        local keys = { "dx", "dy", "dz" }
                        dragRowDeltaState[keys[index]] = 0
                    end,
                })
                controls.TextMuted(string.format("  Accumulated: dx=%.2f  dy=%.2f  dz=%.2f",
                    dragRowDeltaState.dx, dragRowDeltaState.dy, dragRowDeltaState.dz))

                ImGui.Dummy(0, 4)
                controls.TextMuted("Label-to-value (labels switch to values on hover):")
                local drcLtv = controls.bind(ltvRowState, ltvRowDefaults)
                drcLtv:DragFloatRow(nil, {"x", "y", "z"}, -2000, 2000, {
                    speed = 0.1,
                    drags = {
                        { color = styles.dragColors.x, label = "X" },
                        { color = styles.dragColors.y, label = "Y" },
                        { color = styles.dragColors.z, label = "Z" },
                    },
                })

                ImGui.Dummy(0, 4)
                controls.TextMuted("Disabled style (fully faded, no hover change):")
                local drcDis = controls.bind(disabledRowState, disabledRowDefaults)
                drcDis:DragFloatRow(nil, {"x", "y", "z"}, -2000, 2000, {
                    speed = 0.1,
                    disabled = true,
                })

                ImGui.Dummy(0, 4)
                controls.TextMuted("Dimmed style (faded, reveals outlined on hover):")
                local drcDim = controls.bind(dimmedRowState, disabledRowDefaults)
                drcDim:DragFloatRow(nil, {"x", "y", "z"}, -2000, 2000, {
                    speed = 0.1,
                    disabled = "dimmed",
                })

                ImGui.Dummy(0, 4)
                controls.TextMuted("Dimmed+color style (faded, reveals color border on hover):")
                local drcDimC = controls.bind(dimmedColorRowState, disabledRowDefaults)
                drcDimC:DragFloatRow(nil, {"x", "y", "z"}, -2000, 2000, {
                    speed = 0.1,
                    disabled = "dimmedColor",
                    drags = {
                        { color = styles.dragColors.x },
                        { color = styles.dragColors.y },
                        { color = styles.dragColors.z },
                    },
                })

            elseif controlsPage == 2 then
                -- Buttons: HoldButton variants + ActionButton
                controls.TextMuted("Overlay mode: progress overlays the button")
                ImGui.Dummy(0, 2)
                local held, clicked = controls.HoldButton("demo_overlay", "  Hold to Reset  ", {
                    duration = 2.0, style = "danger", width = controls.ColWidth(6),
                    tooltip = "Hold for 2 seconds to reset all values",
                })
                if held then
                    for k, v in pairs(demoDefaults) do demoState[k] = v end
                    wu.Notify.success("All values reset!")
                elseif clicked then
                    wu.Notify.info("Hold the button to confirm reset")
                end

                ImGui.Dummy(0, 6)

                controls.TextMuted("Replace mode: button becomes a progress bar")
                ImGui.Dummy(0, 2)
                held, clicked = controls.HoldButton("demo_replace", "  Hold (Replace)  ", {
                    duration = 1.5, style = "warning", width = controls.ColWidth(6),
                    progressDisplay = "replace", progressStyle = "danger",
                    tooltip = "Hold to see the button replaced by a progress bar",
                })
                if held then wu.Notify.success("Replace mode triggered!") end
                if clicked then wu.Notify.info("Hold the button to confirm") end

                ImGui.Dummy(0, 6)

                controls.TextMuted("External mode: progress on a separate element")
                ImGui.Dummy(0, 2)
                held, clicked = controls.HoldButton("demo_external", "  Hold Me  ", {
                    duration = 2.0, style = "danger", width = controls.ColWidth(4),
                    progressDisplay = "external",
                    tooltip = "Hold to show progress on the element to the right",
                })
                if held then wu.Notify.success("External progress triggered!") end
                if clicked then wu.Notify.info("Hold the button to confirm") end
                ImGui.SameLine()
                if not controls.ShowHoldProgress("demo_external", controls.ColWidth(8), "danger") then
                    controls.TextMuted("  <- Progress appears here")
                end

                ImGui.Dummy(0, 6)

                controls.TextMuted("Click or hold: separate actions")
                ImGui.Dummy(0, 2)
                controls.HoldButton("ctl_save", "  Save Settings  ", {
                    style = "active", width = -1,
                    onClick = function() wu.Notify.success("Settings saved!") end,
                    onHold = function() wu.Notify.success("Settings force-saved!") end,
                    tooltip = "Click to save, hold to force-save",
                })

                ImGui.Dummy(0, 6)

                controls.TextMuted("Hold-only with warning message")
                ImGui.Dummy(0, 2)
                controls.HoldButton("ctl_delete", "  Delete All Data  ", {
                    duration = 2.0, style = "danger", width = -1,
                    onHold = function() wu.Notify.success("All data deleted!") end,
                    onClick = function() wu.Notify.info("Hold to confirm deletion") end,
                    warningMessage = "Hold to confirm deletion",
                    tooltip = "Hold for 2 seconds to delete all data",
                })

                ImGui.Dummy(0, 6)

                controls.TextMuted("Disabled state")
                ImGui.Dummy(0, 2)
                controls.HoldButton("ctl_locked", "  Cannot Click  ", {
                    style = "inactive", width = -1, disabled = true,
                    tooltip = "This button is disabled and cannot be interacted with",
                })

                controls.Separator(8, 8)

                controls.TextMuted("ActionButton: primary click + secondary hold-to-delete")
                ImGui.Dummy(0, 2)
                controls.ActionButton("demo_action_1", "  Item One  ", {
                    onPrimary = function()
                        notifCounter = notifCounter + 1
                        wu.Notify.info("Primary clicked #" .. notifCounter)
                    end,
                    onSecondary = function()
                        notifCounter = notifCounter + 1
                        wu.Notify.success("Deleted item #" .. notifCounter)
                    end,
                    secondaryDuration = 1.0,
                })

                controls.ActionButton("demo_action_2", "  Item Two  ", {
                    onPrimary = function()
                        notifCounter = notifCounter + 1
                        wu.Notify.info("Primary clicked #" .. notifCounter)
                    end,
                    onSecondary = function()
                        notifCounter = notifCounter + 1
                        wu.Notify.success("Deleted item #" .. notifCounter)
                    end,
                    secondaryDuration = 1.0,
                    progressStyle = "success",
                })

            elseif controlsPage == 3 then
                -- Rows: ButtonRow + ToggleButtonRow
                controls.TextMuted("Equal text buttons:")
                controls.ButtonRow({
                    { label = "  Select A  ", style = "active",   onClick = function() wu.Notify.info("Clicked A") end },
                    { label = "  Select B  ", style = "inactive", onClick = function() wu.Notify.info("Clicked B") end },
                    { label = "  Select C  ", style = "inactive", onClick = function() wu.Notify.info("Clicked C") end },
                })

                ImGui.Dummy(0, 6)

                controls.TextMuted("Text + icons with cross-element progress:")
                controls.ButtonRow({
                    { label = "My Preset Name", style = "active",
                      onClick = function() wu.Notify.info("Load preset") end,
                      progressFrom = "ctl_del_b", progressStyle = "danger" },
                    { icon = "Undo", style = "inactive",
                      onClick = function() wu.Notify.info("Reset") end },
                    { icon = "Delete", style = "danger",
                      onHold = function() wu.Notify.success("Deleted!") end,
                      holdDuration = 1.0, id = "ctl_del_b", progressDisplay = "external" },
                })

                ImGui.Dummy(0, 6)

                controls.TextMuted("Weighted distribution (2:1 text + icon):")
                controls.ButtonRow({
                    { label = "Primary Action", style = "active", weight = 2,
                      onClick = function() wu.Notify.info("Primary") end },
                    { label = "Cancel", style = "inactive",
                      onClick = function() wu.Notify.info("Cancel") end },
                    { icon = "ContentSave", style = "active",
                      onClick = function() wu.Notify.info("Quick save") end },
                })

                controls.Separator(8, 8)

                local tc = controls.bind(advState, advDefaults)

                controls.TextMuted("Auto-sized icon toggles (left-click toggle, right-click reset):")
                tc:ToggleButtonRow({
                    { key = "featureA", icon = "AngleAcute", tooltip = "Toggle angle mode" },
                    { key = "featureB", icon = "SineWave", tooltip = "Toggle wave mode" },
                    { key = "featureC", icon = "Motorbike", tooltip = "Toggle motorbike mode" },
                    { key = "featureD", icon = "Car", tooltip = "Toggle car mode" },
                })
                controls.TextMuted("A=" .. tostring(advState.featureA) .. "  B=" .. tostring(advState.featureB)
                    .. "  C=" .. tostring(advState.featureC) .. "  D=" .. tostring(advState.featureD))

                ImGui.Dummy(0, 6)

                controls.TextMuted("With weight = 1 (fill remaining space evenly):")
                tc:ToggleButtonRow({
                    { key = "featureA", icon = "AngleAcute", weight = 1, tooltip = "Toggle angle mode" },
                    { key = "featureB", icon = "SineWave",   weight = 1, tooltip = "Toggle wave mode" },
                    { key = "featureC", icon = "Motorbike",  weight = 1, tooltip = "Toggle motorbike mode" },
                    { key = "featureD", icon = "Car",        weight = 1, tooltip = "Toggle car mode" },
                })

            elseif controlsPage == 4 then
                -- Grid System
                controls.TextMuted("controls.ColWidth(n) sizes widgets to n/12 of available width.")
                ImGui.Dummy(0, 4)

                controls.SectionHeader("4 x col-3", 0, 4)
                local w3 = controls.ColWidth(3)
                for i = 1, 4 do
                    controls.Button("  col-3  ", "active", w3)
                    if i < 4 then ImGui.SameLine() end
                end

                controls.SectionHeader("2 x col-6", 8, 4)
                local w6 = controls.ColWidth(6)
                controls.Button("  col-6  ", "danger", w6)
                ImGui.SameLine()
                controls.Button("  col-6  ", "update", w6)

                controls.SectionHeader("col-4 + col-8 (sidebar + main)", 8, 4)
                local w4 = controls.ColWidth(4)
                local w8 = controls.ColWidth(8)
                controls.Button("  col-4  ", "active", w4)
                ImGui.SameLine()
                controls.Button("  col-8  ", "inactive", w8)

                controls.SectionHeader("col-3 + col-6 + col-3 (centered)", 8, 4)
                local w3b = controls.ColWidth(3)
                local w6b = controls.ColWidth(6)
                controls.Button("  col-3  ", "inactive", w3b)
                ImGui.SameLine()
                controls.Button("  col-6  ", "active", w6b)
                ImGui.SameLine()
                controls.Button("  col-3  ", "inactive", w3b)

            elseif controlsPage == 5 then
                -- Layout Helpers
                controls.TextMuted("BeginFillChild: scrollable child filling remaining space")
                ImGui.Dummy(0, 2)
                if controls.BeginFillChild("demo_fill") then
                    for i = 1, 30 do
                        ImGui.Text("  Scrollable item " .. i)
                    end
                end
                controls.EndFillChild("demo_fill")

            elseif controlsPage == 6 then
                -- Notifications
                controls.TextMuted("Toast notifications drawn by WindowUtils:")
                ImGui.Dummy(0, 4)

                if controls.Button("  Info Toast  ", "inactive", controls.ColWidth(6)) then
                    notifCounter = notifCounter + 1
                    notifBadgeCount = notifBadgeCount + 1
                    wu.Notify.info("This is an info message #" .. notifCounter)
                end
                ImGui.SameLine()
                if controls.Button("  Success Toast  ", "active", controls.ColWidth(6)) then
                    notifCounter = notifCounter + 1
                    notifBadgeCount = notifBadgeCount + 1
                    wu.Notify.success("Operation completed! #" .. notifCounter)
                end

                if controls.Button("  Warning Toast  ", "warning", controls.ColWidth(6)) then
                    notifCounter = notifCounter + 1
                    notifBadgeCount = notifBadgeCount + 1
                    wu.Notify.warn("Caution: something needs attention #" .. notifCounter)
                end
                ImGui.SameLine()
                if controls.Button("  Error Toast  ", "danger", controls.ColWidth(6)) then
                    notifCounter = notifCounter + 1
                    notifBadgeCount = notifBadgeCount + 1
                    wu.Notify.error("Something went wrong! #" .. notifCounter)
                end

                ImGui.Dummy(0, 8)
                controls.TextMuted("Tab badge demo:")
                ImGui.Dummy(0, 2)

                controls.ButtonRow({
                    { label = "No Badge",    style = notifBadgeMode == "none"  and "active" or "inactive",
                      onClick = function() notifBadgeMode = "none" end },
                    { label = "Green Dot",   style = notifBadgeMode == "dot"   and "active" or "inactive",
                      onClick = function() notifBadgeMode = "dot" end },
                    { label = "Count Badge", style = notifBadgeMode == "count" and "active" or "inactive",
                      onClick = function() notifBadgeMode = "count" end },
                })

                ImGui.Dummy(0, 4)

                controls.ButtonRow({
                    { label = "Clear on Tab Open: " .. (notifClearOnOpen and "ON" or "OFF"),
                      style = notifClearOnOpen and "active" or "inactive",
                      onClick = function() notifClearOnOpen = not notifClearOnOpen end },
                    { label = "Clear Now", style = "inactive",
                      onClick = function() notifBadgeCount = 0 end },
                })
            end
            end)
        end },
    }, { direction = "horizontal", defaultPcts = { 0.2, 0.8 } })
end

--------------------------------------------------------------------------------
-- Tab 2: Drag & Drop Demo
--------------------------------------------------------------------------------

local function drawDragDropDemo()
    local controls = wu.Controls
    local dragdrop = wu.DragDrop
    controls.Column("dd_layout", {
        { flex = 1, content = function()
            controls.TextMuted("Drag items to reorder:")
            ImGui.Dummy(0, 4)
            dragdrop.list("##demo_dd_list", dragItems, function(item, index, ctx)
                local label = item.icon .. ".  " .. item.name
                ImGui.Selectable(label, ctx.isDragged, 0, 0, 0)
            end, function(from, to)
                notifCounter = notifCounter + 1
                wu.Notify.info("Moved item from " .. from .. " to " .. to)
            end)
        end },
        { flex = 1, content = function()
            controls.TextMuted("With drag handle and custom colors:")
            ImGui.Dummy(0, 4)
            dragdrop.list("##demo_dd_handle", dragItems, function(item, index, ctx)
                local label = item.icon .. ".  " .. item.name
                ImGui.Selectable(label, ctx.isDragged, 0, 0, 0)
            end, function(from, to)
                notifCounter = notifCounter + 1
                wu.Notify.info("Moved item from " .. from .. " to " .. to)
            end, {
                showHandle = true,
                handleColor = { 0.2, 0.8, 0.5, 0.7 },
                colors = {
                    hover = { 0.13, 0.79, 0.60, 0.3 },
                    separator = { 0.0, 1.0, 0.7, 1.0 },
                    dragAlpha = 0.3,
                },
            })
        end },
        { auto = true, content = function()
            ImGui.Dummy(0, 2)
            if controls.Button("  Reset Order  ", "inactive") then
                dragItems = {
                    { name = "First Item",  icon = "1" },
                    { name = "Second Item", icon = "2" },
                    { name = "Third Item",  icon = "3" },
                    { name = "Fourth Item", icon = "4" },
                    { name = "Fifth Item",  icon = "5" },
                }
                wu.Notify.success("List order reset!")
            end
        end },
    })
end

--------------------------------------------------------------------------------
-- Tab 3: Splitter Demo
--------------------------------------------------------------------------------

local function drawSplitterDemo()
    local controls = wu.Controls
    local splitter = wu.Splitter

    controls.Column("sp_layout", {
        { flex = 1, content = function()
            controls.TextMuted("Horizontal splitter - drag the bar to resize panels:")
            ImGui.Dummy(0, 4)
            splitter.horizontal("##demo_h_split", function()
                ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(0.1, 0.15, 0.2, 1.0))
                ImGui.BeginChild("##left_content", 0, 0, false, ImGuiWindowFlags.AlwaysUseWindowPadding)
                ImGui.Text("Left Panel")
                ImGui.Separator()
                controls.TextMuted("Sidebar content")
                ImGui.Dummy(0, 4)
                controls.Button("  Select A  ", "active")
                controls.Button("  Select B  ", "inactive")
                controls.Button("  Select C  ", "inactive")
                ImGui.EndChild()
                ImGui.PopStyleColor()
            end, function()
                ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(0.08, 0.08, 0.12, 1.0))
                ImGui.BeginChild("##right_content", 0, 0, false, ImGuiWindowFlags.AlwaysUseWindowPadding)
                ImGui.Text("Right Panel")
                ImGui.Separator()
                controls.TextMuted("Main content area")
                ImGui.EndChild()
                ImGui.PopStyleColor()
            end, { defaultPct = 0.35, minPct = 0.15, maxPct = 0.7 })
        end },
        { flex = 1, content = function()
            controls.TextMuted("Vertical splitter:")
            ImGui.Dummy(0, 4)
            splitter.vertical("##demo_v_split", function()
                ImGui.Text("Top Panel")
                ImGui.Separator()
                controls.TextMuted("Header, toolbar, or search bar")
            end, function()
                ImGui.Text("Bottom Panel")
                ImGui.Separator()
                controls.TextMuted("Log output, status, or detail pane")
            end, { defaultPct = 0.4 })
        end },
    })
end

--------------------------------------------------------------------------------
-- Tab 4: Multi-Splitter Demo
--------------------------------------------------------------------------------

local function drawMultiSplitterDemo()
    local controls = wu.Controls
    local splitter = wu.Splitter

    splitter.multi("ms_rows", {
        -- Row 1: 3 equal panels
        { content = function()
            splitter.multi("ms_3panel", {
                { content = function()
                    controls.Panel("ms3_p1", function()
                        ImGui.Text("Panel 1")
                        ImGui.Separator()
                        controls.TextMuted("API: splitter.multi(id, panels, opts)")
                        controls.TextMuted("3 equal panels with defaultPcts")
                    end)
                end },
                { content = function()
                    controls.Panel("ms3_p2", function()
                        ImGui.Text("Panel 2")
                        ImGui.Separator()
                        controls.TextMuted("Border on hover:")
                        controls.TextMuted("borderOnHover = true")
                        ImGui.Dummy(0, 2)
                        controls.TextMuted("Shift+drag: proportional scale")
                        controls.TextMuted("Ctrl+drag: snap to 5% grid")
                        controls.TextMuted("Right-click: context menu")
                    end, { borderOnHover = true })
                end },
                { content = function()
                    controls.Panel("ms3_p3", function()
                        ImGui.Text("Panel 3")
                        ImGui.Separator()
                        controls.TextMuted("Enabled panel border:")
                        controls.TextMuted("border = true")
                    end, { border = true })
                end },
            }, { direction = "horizontal", defaultPcts = { 0.33, 0.34, 0.33 } })
        end },
        -- Row 2: Weighted panels (fixed + flex + minWidth)
        { content = function()
            splitter.multi("ms_weighted", {
                { content = function()
                    controls.Panel("msw_p1", function()
                        ImGui.Text("Fixed 150px")
                        ImGui.Separator()
                        controls.TextMuted("width = 150")
                    end)
                end, width = 150 },
                { content = function()
                    controls.Panel("msw_p2", function()
                        ImGui.Text("Flex 2")
                        ImGui.Separator()
                        controls.TextMuted("flex = 2")
                    end)
                end, flex = 2 },
                { content = function()
                    controls.Panel("msw_p3", function()
                        ImGui.Text("Flex 1 (min 80)")
                        ImGui.Separator()
                        controls.TextMuted("flex = 1, minWidth = 80")
                    end)
                end, flex = 1, minWidth = 80 },
            }, { direction = "horizontal" })
        end },
        -- Row 3: DynamicButton demo
        { content = function()
            splitter.multi("ms_dynbtn", {
                { content = function()
                    controls.Panel("msdb_p1", function()
                        ImGui.Text("DynamicButton")
                        ImGui.Separator()
                        controls.TextMuted("Resize to see modes:")
                        ImGui.Dummy(0, 2)
                        controls.DynamicButton("Save Settings", "ContentSave", { style = "active" })
                        controls.DynamicButton("Delete All Items", "Delete", { style = "danger" })
                        controls.DynamicButton("Export Config", "Export", { style = "inactive" })
                    end)
                end },
                { content = function()
                    controls.Panel("msdb_p2", function()
                        ImGui.Text("Normal Buttons")
                        ImGui.Separator()
                        controls.TextMuted("For comparison:")
                        ImGui.Dummy(0, 2)
                        controls.Button("Save Settings", "active", -1)
                        controls.Button("Delete All Items", "danger", -1)
                        controls.Button("Export Config", "inactive", -1)
                    end)
                end },
            }, { direction = "horizontal", defaultPcts = { 0.5, 0.5 } })
        end },
    }, { direction = "vertical", defaultPcts = { 0.33, 0.34, 0.33 } })
end

--------------------------------------------------------------------------------
-- Tab 5: Toggle Panel Demo
--------------------------------------------------------------------------------

local function drawTogglePanelDemo()
    local controls = wu.Controls
    local splitter = wu.Splitter

    controls.Column("tgl_layout", {
        { flex = 1, content = function()
            ImGui.Text("Left Sidebar (200px)")
            ImGui.Dummy(0, 4)
            splitter.toggle("tgl_left", {
                { content = function()
                    controls.Panel("tgl_left_panel", function()
                        ImGui.Text("Sidebar")
                        ImGui.Separator()
                        ImGui.Dummy(0, 4)
                        controls.Button("  Nav A  ", "active")
                        controls.Button("  Nav B  ", "inactive")
                        controls.Button("  Nav C  ", "inactive")
                    end, { bg = { 0.1, 0.15, 0.2, 1.0 }, borderOnHover = true })
                end },
                { content = function()
                    controls.Panel("tgl_left_main", function()
                        ImGui.Text("Main Content")
                        ImGui.Separator()
                        controls.TextMuted("Click the chevron bar to toggle.")
                    end, { borderOnHover = true })
                end },
            }, { side = "left", size = 200, defaultOpen = true })
        end },
        { flex = 1, content = function()
            ImGui.Text("Top Toolbar (50px)")
            ImGui.Dummy(0, 4)
            splitter.toggle("tgl_top", {
                { content = function()
                    controls.Panel("tgl_top_bar", function()
                        ImGui.Text("Toolbar")
                        ImGui.SameLine()
                        controls.TextMuted("  side = \"top\", size = 50")
                    end, { bg = { 0.15, 0.15, 0.2, 1.0 }, borderOnHover = true })
                end },
                { content = function()
                    controls.Panel("tgl_top_main", function()
                        ImGui.Text("Content Below")
                        ImGui.Separator()
                        controls.TextMuted("Click the chevron bar above to toggle.")
                        for i = 1, 5 do
                            ImGui.Text("  Item " .. i)
                        end
                    end, { borderOnHover = true })
                end },
            }, { side = "top", size = 50, defaultOpen = true })
        end },
        { auto = true, content = function()
            ImGui.Text("Programmatic Control")
            ImGui.Dummy(0, 4)
            controls.TextMuted("Use setToggle(id, bool) / getToggle(id) to control from code:")
            ImGui.Dummy(0, 2)

            local leftOpen = splitter.getToggle("tgl_left")
            local topOpen = splitter.getToggle("tgl_top")

            local w6 = controls.ColWidth(6)
            if controls.Button(leftOpen and "  Close Left  " or "  Open Left  ", leftOpen and "danger" or "active", w6) then
                splitter.setToggle("tgl_left", not leftOpen)
            end
            ImGui.SameLine()
            if controls.Button(topOpen and "  Close Top  " or "  Open Top  ", topOpen and "danger" or "active", w6) then
                splitter.setToggle("tgl_top", not topOpen)
            end
        end },
    })
end

--------------------------------------------------------------------------------
-- Tab 6: Edge Toggle Layout Demo
--------------------------------------------------------------------------------

local function drawEdgeToggleDemo()
    local controls = wu.Controls
    local splitter = wu.Splitter

    -- Dynamic sizes from ImGui metrics
    local lineH = ImGui.GetTextLineHeightWithSpacing()
    local padY = ImGui.GetStyle().WindowPadding.y
    local spacY = ImGui.GetStyle().ItemSpacing.y

    local toolbarH = lineH + padY * 2 + 2
    local statusH = lineH * 2 + spacY + padY * 2 + 2

    -- Outer vertical: toolbar | core row | status bar
    splitter.multi("etgl_outer", {
        -- Top edge: toolbar (toggle)
        { toggle = true, size = toolbarH, defaultOpen = true, animate = false, content = function()
            controls.Panel("etgl_toolbar", function()
                ImGui.Text("Toolbar")
                ImGui.SameLine()
                controls.TextMuted("  toggle=true, size=toolbarH")
            end, { bg = { 0.15, 0.15, 0.2, 1.0 } })
        end },
        -- Core: horizontal multi with sidebar + editor + properties
        { content = function()
            splitter.multi("etgl_inner", {
                -- Left edge: sidebar (toggle)
                { toggle = true, size = 160, defaultOpen = true, content = function()
                    controls.Panel("etgl_sidebar", function()
                        ImGui.Text("Explorer")
                        ImGui.Separator()
                        controls.TextMuted("toggle=true, size=160")
                        ImGui.Dummy(0, 2)
                        for _, name in ipairs({ "init.lua", "config.lua", "utils.lua" }) do
                            ImGui.Text("  " .. name)
                        end
                    end, { bg = { 0.1, 0.12, 0.16, 1.0 } })
                end },
                -- Core panel 1: editor (flex)
                { content = function()
                    controls.Panel("etgl_editor", function()
                        ImGui.Text("Editor")
                        ImGui.Separator()
                        controls.TextMuted("Nested multi-splitters:")
                        controls.TextMuted("Outer = vertical (toolbar/status)")
                        controls.TextMuted("Inner = horizontal (sidebar/editor/props)")
                        ImGui.Dummy(0, 4)
                        for i = 1, 6 do
                            controls.TextMuted(string.format("  %2d |  local x = %d", i, i * 10))
                        end
                    end)
                end },
                -- Core panel 2: output + toggle controls (flex)
                { content = function()
                    controls.Panel("etgl_output", function()
                        controls.Column("etgl_out_col", {
                            { flex = 1, content = function()
                                ImGui.Text("Output")
                                ImGui.Separator()
                                for i = 1, 4 do
                                    controls.TextMuted("  [info] message " .. i)
                                end
                            end },
                            { auto = true, content = function()
                                controls.TextMuted("Toggle Controls:")
                                ImGui.Dummy(0, 2)
                                local toggleIds = {
                                    { id = "etgl_outer_tgl_lead",  label = "Toolbar" },
                                    { id = "etgl_inner_tgl_lead",  label = "Explorer" },
                                    { id = "etgl_inner_tgl_trail", label = "Properties" },
                                    { id = "etgl_outer_tgl_trail", label = "Status Bar" },
                                }
                                if controls.DynamicButton("Expand All", "ArrowExpandAll", { style = "active" }) then
                                    for _, t in ipairs(toggleIds) do splitter.setToggle(t.id, true) end
                                end
                                if controls.DynamicButton("Collapse All", "ArrowCollapseAll", { style = "danger" }) then
                                    for _, t in ipairs(toggleIds) do splitter.setToggle(t.id, false) end
                                end
                                local animIds = { "etgl_outer_tgl_lead", "etgl_outer_tgl_trail" }
                                local animOn = splitter.getToggleAnimate(animIds[1])
                                local animLabel = animOn and "Disable Animation" or "Enable Animation"
                                local animIcon = animOn and "AnimationPlayOutline" or "AnimationPlay"
                                if controls.DynamicButton(animLabel, animIcon, { style = animOn and "inactive" or "active" }) then
                                    for _, aid in ipairs(animIds) do splitter.setToggleAnimate(aid, not animOn) end
                                end
                                ImGui.Dummy(0, 2)
                                for _, t in ipairs(toggleIds) do
                                    local isOpen = splitter.getToggle(t.id)
                                    local label = isOpen and ("Hide " .. t.label) or ("Show " .. t.label)
                                    local icon = isOpen and "EyeOff" or "Eye"
                                    if controls.DynamicButton(label, icon, { style = isOpen and "inactive" or "active" }) then
                                        splitter.setToggle(t.id, not isOpen)
                                    end
                                end
                            end },
                        }, { gap = 0 })
                    end)
                end },
                -- Right edge: properties (toggle, default closed)
                { toggle = true, size = 360, defaultOpen = false, content = function()
                    controls.Panel("etgl_props", function()
                        ImGui.Text("Properties")
                        ImGui.Separator()
                        controls.TextMuted("toggle=true, size=180")
                        controls.TextMuted("defaultOpen=false")
                    end, { bg = { 0.12, 0.1, 0.18, 1.0 } })
                end },
            }, { direction = "horizontal" })
        end },
        -- Bottom edge: status bar (toggle)
        { toggle = true, size = statusH, defaultOpen = true, animate = false, content = function()
            controls.Panel("etgl_status", function()
                ImGui.Text("Status Bar")
                ImGui.Separator()
                controls.TextMuted("Ln 42, Col 8  |  UTF-8  |  Lua")
            end, { bg = { 0.1, 0.12, 0.16, 1.0 } })
        end },
    }, { direction = "vertical" })
end

--------------------------------------------------------------------------------
-- Tab 7: Expand Demo
--------------------------------------------------------------------------------

local function drawExpandDemo()
    local splitter = wu.Splitter
    local controls = wu.Controls
    splitter.toggle("exp_right", {
        { content = function()
            controls.Panel("exp_props", function()
                ImGui.Text("Properties")
                ImGui.Separator()
                controls.TextMuted("Drag bar to resize.")
                controls.TextMuted("Double-click to toggle.")
                ImGui.Dummy(0, 4)
                controls.TextMuted("Size Mode:")
                ImGui.Dummy(0, 2)
                controls.ButtonRow({
                    { label = "Fixed", style = expSizeMode == "fixed" and "active" or "inactive",
                      onClick = function() expSizeMode = "fixed" end },
                    { label = "Flex",  style = expSizeMode == "flex"  and "active" or "inactive",
                      onClick = function() expSizeMode = "flex" end },
                    { label = "Auto",  style = expSizeMode == "auto"  and "active" or "inactive",
                      onClick = function() expSizeMode = "auto" end },
                })
                -- Auto-fit measurement (inside Panel child where cursor reflects content)
                local padY = ImGui.GetStyle().WindowPadding.y
                wu.Expand.setMeasuredSize("exp_right", ImGui.GetCursorPosY() + padY)
            end, { borderOnHover = true })
        end },
        { content = function()
            controls.Panel("exp_main", function()
                ImGui.Text("Main Content")
                ImGui.Separator()
                controls.TextMuted("Window grows to fit the panel.")
                controls.TextMuted("Mode: " .. expSizeMode)
                ImGui.Dummy(0, 4)

                local isOpen = splitter.getToggle("exp_right")
                local openLabel = isOpen and "Close Panel" or "Open Panel"
                local openIcon = isOpen and "ArrowCollapseRight" or "ArrowExpandLeft"
                if controls.DynamicButton(openLabel, openIcon, { style = isOpen and "danger" or "active" }) then
                    splitter.setToggle("exp_right", not isOpen)
                end

                local animOn = splitter.getToggleAnimate("exp_right")
                local animLabel = animOn and "Disable Animation" or "Enable Animation"
                local animIcon = animOn and "AnimationPlayOutline" or "AnimationPlay"
                if controls.DynamicButton(animLabel, animIcon, { style = animOn and "inactive" or "active" }) then
                    splitter.setToggleAnimate("exp_right", not animOn)
                end

                ImGui.Dummy(0, 4)
                for i = 1, 6 do
                    controls.TextMuted(string.format("  Content line %d", i))
                end
            end, { borderOnHover = true })
        end },
    }, {
        side = "right",
        size = 400,
        sizeMode = expSizeMode,
        expand = true,
        defaultOpen = false,
        windowName = DEMO_WINDOW_NAME,
    })
end

--------------------------------------------------------------------------------
-- Tab 8: Expand (Vertical) Demo
--------------------------------------------------------------------------------

local function drawExpandVertDemo()
    local splitter = wu.Splitter
    local controls = wu.Controls
    splitter.toggle("exp_bottom", {
        { content = function()
            controls.Panel("exp_output", function()
                ImGui.Text("Output")
                ImGui.Separator()
                controls.TextMuted("Drag bar to resize.")
                controls.TextMuted("Double-click to toggle.")
                ImGui.Dummy(0, 4)
                controls.TextMuted("Size Mode:")
                ImGui.Dummy(0, 2)
                controls.ButtonRow({
                    { label = "Fixed", style = expVertSizeMode == "fixed" and "active" or "inactive",
                      onClick = function() expVertSizeMode = "fixed" end },
                    { label = "Flex",  style = expVertSizeMode == "flex"  and "active" or "inactive",
                      onClick = function() expVertSizeMode = "flex" end },
                    { label = "Auto",  style = expVertSizeMode == "auto"  and "active" or "inactive",
                      onClick = function() expVertSizeMode = "auto" end },
                })
                -- Auto-fit measurement (inside Panel child where cursor reflects content)
                local padY = ImGui.GetStyle().WindowPadding.y
                wu.Expand.setMeasuredSize("exp_bottom", ImGui.GetCursorPosY() + padY)
            end, { borderOnHover = true })
        end },
        { content = function()
            controls.Panel("exp_editor", function()
                ImGui.Text("Editor")
                ImGui.Separator()
                controls.TextMuted("Window grows to fit the panel.")
                controls.TextMuted("Mode: " .. expVertSizeMode)
                ImGui.Dummy(0, 4)

                local isOpen = splitter.getToggle("exp_bottom")
                local openLabel = isOpen and "Close Panel" or "Open Panel"
                local openIcon = isOpen and "ArrowCollapseDown" or "ArrowExpandUp"
                if controls.DynamicButton(openLabel, openIcon, { style = isOpen and "danger" or "active" }) then
                    splitter.setToggle("exp_bottom", not isOpen)
                end

                local animOn = splitter.getToggleAnimate("exp_bottom")
                local animLabel = animOn and "Disable Animation" or "Enable Animation"
                local animIcon = animOn and "AnimationPlayOutline" or "AnimationPlay"
                if controls.DynamicButton(animLabel, animIcon, { style = animOn and "inactive" or "active" }) then
                    splitter.setToggleAnimate("exp_bottom", not animOn)
                end
                ImGui.Dummy(0, 4)
                for i = 1, 6 do
                    controls.TextMuted(string.format("  Content line %d", i))
                end
            end, { borderOnHover = true })
        end },
    }, {
        side = "bottom",
        size = 200,
        sizeMode = expVertSizeMode,
        expand = true,
        defaultOpen = false,
        windowName = DEMO_WINDOW_NAME,
    })

end

--------------------------------------------------------------------------------
-- Tab 9: Telemetry
-- Live window metrics, grid math, WU feature states, and animation settings.
--------------------------------------------------------------------------------

local function drawTelemetryDemo()
    local controls = wu.Controls
    local splitter  = wu.Splitter
    local s         = wu.API.Get()
    local UNIT_PX   = 20  -- WindowUtils base grid unit (px)
    local cellPx    = UNIT_PX * s.gridUnits

    local function midX()
        local availW = ImGui.GetContentRegionAvail()
        return ImGui.GetCursorPosX() + availW * 0.5
    end

    local function statRow(label, val)
        local vx = midX()
        ImGui.Text(label)
        ImGui.SameLine(vx)
        ImGui.TextColored(0.65, 0.85, 1.0, 1.0, tostring(val))
    end

    local function boolRow(label, val)
        local vx = midX()
        ImGui.Text(label)
        ImGui.SameLine(vx)
        if val then
            ImGui.TextColored(0.35, 1.0, 0.55, 1.0, "On")
        else
            ImGui.TextColored(1.0, 0.4, 0.4, 1.0, "Off")
        end
    end

    local function gap() ImGui.Dummy(0, 3) end

    local function statusRow(label, text, r, g, b)
        local vx = midX()
        ImGui.Text(label)
        ImGui.SameLine(vx)
        ImGui.TextColored(r, g, b, 1.0, text)
    end

    splitter.multi("tele_rows", {
        -- ── Row 1 ──────────────────────────────────────────────────────
        { content = function()
            splitter.multi("tele_top", {
                -- Q1: Window Dimensions
                { content = function()
                    controls.Panel("tele_q1", function()
                        ImGui.Text("Window")
                        ImGui.Separator()
                        ImGui.Dummy(0, 3)
                        statRow("Position:",    string.format("(%.0f, %.0f) px", showcaseWinX, showcaseWinY))
                        statRow("Size:",        string.format("%.0f \xc3\x97 %.0f px",  showcaseWinW, showcaseWinH))
                        gap()
                        statRow("Display:",     string.format("%d \xc3\x97 %d px", resW, resH))
                        statRow("Width %:",     string.format("%.1f%%",  showcaseWinW / resW * 100))
                        statRow("Height %:",    string.format("%.1f%%",  showcaseWinH / resH * 100))
                        gap()
                        statRow("Win cols:",    string.format("%d cells", math.floor(showcaseWinW / cellPx)))
                        statRow("Win rows:",    string.format("%d cells", math.floor(showcaseWinH / cellPx)))
                        gap()
                        ImGui.Separator()
                        ImGui.Dummy(0, 3)
                        -- Live status
                        local statusText, sr, sg, sb
                        if showcaseIsDragging then
                            statusText, sr, sg, sb = "Dragging",  1.0,  0.65, 0.2
                        elseif showcaseIsAnimating then
                            statusText, sr, sg, sb = "Animating", 0.35, 0.9,  1.0
                        elseif showcaseIsCollapsed then
                            statusText, sr, sg, sb = "Collapsed", 0.9,  0.8,  0.3
                        else
                            statusText, sr, sg, sb = "Idle",      0.55, 0.55, 0.55
                        end
                        statusRow("Status:",    statusText,          sr,   sg,   sb)
                        boolRow("Focused:",     showcaseIsFocused)
                        boolRow("Collapsed:",   showcaseIsCollapsed)
                        boolRow("Animating:",   showcaseIsAnimating)
                        boolRow("Cstr anim:",   wu.IsAnyConstraintAnimating())
                        ImGui.Dummy(0, 4)
                        controls.TextMuted("Live stats. Drag or resize to update.")
                    end)
                end },
                -- Q2: Grid Math
                { content = function()
                    controls.Panel("tele_q2", function()
                        ImGui.Text("Grid")
                        ImGui.Separator()
                        ImGui.Dummy(0, 3)
                        statRow("Unit size:",    string.format("%d px",   UNIT_PX))
                        statRow("Multiplier:",   string.format("\xc3\x97%d",      s.gridUnits))
                        statRow("Cell size:",    string.format("%d px",   cellPx))
                        gap()
                        statRow("Disp cols:",    string.format("%d cells", math.floor(resW  / cellPx)))
                        statRow("Disp rows:",    string.format("%d cells", math.floor(resH  / cellPx)))
                        gap()
                        boolRow("Grid snap:",    s.gridEnabled)
                        boolRow("Snap collapse:",s.snapCollapsed)
                        boolRow("Viz overlay:",  s.gridVisualizationEnabled)
                        boolRow("Dim bg:",       s.gridDimBackground)
                        boolRow("Feather:",      s.gridFeatherEnabled)
                        statRow("Feather r:",    string.format("%d px", s.gridFeatherRadius))
                    end)
                end },
            }, { direction = "horizontal", defaultPcts = { 0.5, 0.5 } })
        end },
        -- ── Row 2 ──────────────────────────────────────────────────────
        { content = function()
            splitter.multi("tele_bottom", {
                -- Q3: Feature States
                { content = function()
                    controls.Panel("tele_q3", function()
                        ImGui.Text("States")
                        ImGui.Separator()
                        ImGui.Dummy(0, 3)
                        boolRow("Master:",        s.enabled)
                        boolRow("Grid snap:",      s.gridEnabled)
                        boolRow("Animation:",      s.animationEnabled)
                        boolRow("Tooltips:",       s.tooltipsEnabled)
                        gap()
                        boolRow("Override all:",   s.overrideAllWindows)
                        boolRow("Grid viz:",       s.gridVisualizationEnabled)
                        boolRow("Grid guides:",    s.gridGuidesEnabled)
                        boolRow("Dim bg:",         s.gridDimBackground)
                        boolRow("Auto-adj res:",   s.autoAdjustOnResize)
                        gap()
                        boolRow("Show GUI:",       s.showGuiWindow)
                        boolRow("Debug output:",   s.debugOutput)
                    end)
                end },
                -- Q4: Animation & Effects
                { content = function()
                    controls.Panel("tele_q4", function()
                        ImGui.Text("Animation & Effects")
                        ImGui.Separator()
                        ImGui.Dummy(0, 3)
                        -- Live runtime
                        local snapAnim = wu.IsAnimating(DEMO_WINDOW_NAME)
                        local cstrAnim = wu.IsAnyConstraintAnimating()
                        local blurLive = s.blurOnOverlayOpen
                            and (not s.blurOnDragOnly or showcaseIsDragging)
                        boolRow("Snap anim:",   snapAnim)
                        boolRow("Cstr anim:",   cstrAnim)
                        boolRow("Blur active:", blurLive)
                        gap()
                        ImGui.Separator()
                        ImGui.Dummy(0, 3)
                        statRow("Ease fn:",        s.easeFunction)
                        statRow("Duration:",       string.format("%.3f s",  s.animationDuration))
                        gap()
                        boolRow("Blur on open:",   s.blurOnOverlayOpen)
                        boolRow("Blur drag only:", s.blurOnDragOnly)
                        statRow("Blur intensity:", string.format("%.4f",    s.blurIntensity))
                        statRow("Blur fade in:",   string.format("%.2f s",  s.fadeInDuration))
                        statRow("Blur fade out:",  string.format("%.2f s",  s.fadeOutDuration))
                        gap()
                        boolRow("Feather:",        s.gridFeatherEnabled)
                        statRow("Feather r:",      string.format("%d px",   s.gridFeatherRadius))
                        statRow("Feather pad:",    string.format("%d px",   s.gridFeatherPadding))
                        statRow("Feather curve:",  string.format("%.1f",    s.gridFeatherCurve))
                        gap()
                        statRow("Probe intv.:",    string.format("%.1f s",  s.probeInterval))
                        boolRow("Auto-remove:",    s.autoRemoveEmptyWindows)
                        statRow("Remove intv.:",   string.format("%.1f s",  s.autoRemoveInterval))
                    end)
                end },
            }, { direction = "horizontal", defaultPcts = { 0.5, 0.5 } })
        end },
    }, { direction = "vertical", defaultPcts = { 0.5, 0.5 } })
end

--------------------------------------------------------------------------------
-- Tab 10: Tooltips
-- API-reference tab: one working example of each control with signature tooltip.
--------------------------------------------------------------------------------

local function drawTooltipsDemo()
    local tooltips = wu.Tooltips
    local controls = wu.Controls
    local ctx = controls.bind(ttState, ttDefaults)

    -- Scrollable wrapper with styled scrollbar (matches other tabs)
    if controls.BeginFillChild("tt_scroll") then
    -- content rendered below; EndFillChild at bottom of function
    end

    ----------------------------------------------------------------------------
    -- Bound Controls
    ----------------------------------------------------------------------------
    controls.SectionHeader("Bound Controls", 0, 4)
    controls.TextMuted("controls.bind(data, defaults)  - right-click any bound control to reset.")
    tooltips.ShowBullets("controls.bind(data, defaults, onSave, bindOpts)", {
        "data  - mutable state table",
        "defaults  - default values (right-click resets)",
        "onSave  - optional callback on change",
        "Returns ctx with :SliderFloat, :SliderInt, :Checkbox, :Combo, etc.",
    })
    ImGui.Dummy(0, 2)

    ctx:SliderFloat("Tune", "ttSliderF", 0.0, 1.0, {
        format = "%.2f",
        tooltip = "ctx:SliderFloat(icon, key, min, max, opts)\nformat = \"%.2f\"",
    })
    ctx:SliderFloat("Brightness6", "ttSliderF", 0.0, 1.0, {
        percent = true,
        tooltip = "ctx:SliderFloat  - percent = true\nDisplays 0-100% instead of raw float",
    })
    ctx:SliderInt("Speedometer", "ttSliderI", 0, 10, {
        tooltip = "ctx:SliderInt(icon, key, min, max, opts)",
    })
    ctx:Checkbox("Enable Feature", "ttCheck", {
        tooltip = "ctx:Checkbox(label, key, opts)",
    })
    ctx:Combo("FormatListBulleted", "ttCombo", { "Alpha", "Beta", "Gamma" }, {
        tooltip = "ctx:Combo(icon, key, items, opts)",
    })
    ctx:InputText("FormTextbox", "ttInput", {
        maxLength = 256,
        tooltip = "ctx:InputText(icon, key, opts)\nmaxLength = 256",
    })
    ctx:InputFloat("Numeric", "ttInputF", {
        tooltip = "ctx:InputFloat(icon, key, opts)",
    })
    ctx:InputInt("Counter", "ttInputI", {
        tooltip = "ctx:InputInt(icon, key, opts)",
    })
    ImGui.Dummy(0, 2)
    local newColor, colorChanged = controls.ColorEdit4("Palette", "tt_color", ttState.ttColor, {
        tooltip = "controls.ColorEdit4(icon, id, color, opts)",
    })
    if colorChanged then ttState.ttColor = newColor end
    ImGui.Dummy(0, 2)
    ctx:ToggleButtonRow({
        { key = "ttTogA", icon = "ToggleSwitchOutline",    tooltip = "ctx:ToggleButtonRow  - toggle A" },
        { key = "ttTogB", icon = "ToggleSwitchOffOutline", tooltip = "ctx:ToggleButtonRow  - toggle B" },
    })
    tooltips.ShowBullets("ctx:ToggleButtonRow(defs)", {
        "defs  - array of {key, icon, label?, weight?, tooltip?}",
        "Left-click toggles, right-click resets to default",
    })

    ----------------------------------------------------------------------------
    -- Section: Direct Controls (non-bound)
    ----------------------------------------------------------------------------
    controls.SectionHeader("Direct Controls", 8, 4)
    controls.SliderDisabled("Lock", "##Locked Slider")
    tooltips.ShowBullets("controls.SliderDisabled(icon, label)", {
        "icon  - IconGlyphs key name",
        "label  - display label for the disabled slider",
    })
    ImGui.Dummy(0, 2)
    controls.StatusBar("Status")
    tooltips.ShowBullets("controls.StatusBar(label, value, opts)", {
        "label  - left-side label text",
        "value  - right-side value text",
        "opts  - {widthFraction?, style?}",
    })
    ImGui.Dummy(0, 2)
    controls.ProgressBar(0.65, nil, 0, "65%", "default")
    tooltips.ShowBullets("controls.ProgressBar(fraction, width, height, overlay, styleName)", {
        "fraction  - 0.0 to 1.0",
        "width  - nil = full width",
        "overlay  - text drawn over the bar",
        "styleName  - default, danger, success",
    })
    ImGui.Dummy(0, 2)
    controls.ProgressBar(0.35, nil, 0, "35%", "danger")
    tooltips.ShowBullets("controls.ProgressBar  - styleName = \"danger\"", {
        "Red-colored progress bar variant",
    })
    ImGui.Dummy(0, 2)
    controls.ProgressBar(0.85, nil, 0, "85%", "success")
    tooltips.ShowBullets("controls.ProgressBar  - styleName = \"success\"", {
        "Green-colored progress bar variant",
    })

    ----------------------------------------------------------------------------
    -- Section: Buttons
    ----------------------------------------------------------------------------
    controls.SectionHeader("Buttons", 8, 4)
    controls.Button("  Demo Button  ", "active")
    tooltips.ShowBullets("controls.Button(label, styleName, width, height)", {
        "label  - button text",
        "styleName  - active, inactive, danger, warning, update, statusbar",
        "width  - pixel width (0 = auto)",
        "height  - pixel height (0 = auto)",
    })
    ImGui.Dummy(0, 2)
    controls.IconButton(IconGlyphs.ContentSave, true)
    tooltips.ShowBullets("controls.IconButton(icon, clickable)", {
        "icon  - IconGlyphs glyph string",
        "clickable  - if true, returns click state",
    })
    ImGui.SameLine()
    controls.IconButton(IconGlyphs.Delete, true)
    tooltips.ShowBullets("controls.IconButton(icon, clickable)", {
        "Another icon button example (Delete)",
    })
    ImGui.Dummy(0, 2)
    controls.ToggleButton("  Toggle Me  ", true)
    tooltips.ShowBullets("controls.ToggleButton(label, isActive, width, height)", {
        "label  - button text",
        "isActive  - true = active style, false = inactive",
    })
    ImGui.Dummy(0, 2)
    controls.FullWidthButton("  Full Width Button  ", "active")
    tooltips.ShowBullets("controls.FullWidthButton(label, styleName)", {
        "label  - button text",
        "styleName  - stretches to full available width",
    })
    ImGui.Dummy(0, 2)
    controls.DisabledButton("  Disabled Button  ")
    tooltips.ShowBullets("controls.DisabledButton(label, width, height)", {
        "label  - greyed-out, non-interactive button",
    })
    ImGui.Dummy(0, 2)
    controls.DynamicButton("Dynamic Save", "ContentSave", {
        style = "active",
        tooltip = "controls.DynamicButton(label, icon, opts)\nCollapses to icon when narrow",
    })
    tooltips.ShowBullets("controls.DynamicButton(label, icon, opts)", {
        "label  - full text label",
        "icon  - IconGlyphs key (shown when space is tight)",
        "opts  - {style?, width?, tooltip?, minChars?, iconThreshold?}",
    })

    ----------------------------------------------------------------------------
    -- Section: Hold Buttons
    ----------------------------------------------------------------------------
    controls.SectionHeader("Hold Buttons", 8, 4)
    controls.HoldButton("tt_hold_overlay", "  Hold (Overlay)  ", {
        duration = 2.0, style = "danger", width = controls.ColWidth(6),
        tooltip = "controls.HoldButton  - overlay mode (default)\nduration = 2.0",
    })
    ImGui.Dummy(0, 2)
    controls.HoldButton("tt_hold_replace", "  Hold (Replace)  ", {
        duration = 1.5, style = "warning", width = controls.ColWidth(6),
        progressDisplay = "replace", progressStyle = "danger",
        tooltip = "controls.HoldButton  - progressDisplay = \"replace\"",
    })
    ImGui.Dummy(0, 2)
    controls.HoldButton("tt_hold_ext", "  Hold (External)  ", {
        duration = 2.0, style = "danger", width = controls.ColWidth(4),
        progressDisplay = "external",
        tooltip = "controls.HoldButton  - progressDisplay = \"external\"",
    })
    ImGui.SameLine()
    if not controls.ShowHoldProgress("tt_hold_ext", controls.ColWidth(8), "danger") then
        controls.TextMuted("  <- Progress appears here")
    end
    tooltips.ShowBullets("controls.ShowHoldProgress(sourceId, width, progressStyle)", {
        "sourceId  - id of the HoldButton to track",
        "width  - progress bar width in pixels",
        "progressStyle  - color style name",
    })
    ImGui.Dummy(0, 2)
    controls.HoldButton("tt_hold_cb", "  Click or Hold  ", {
        style = "active", width = -1,
        onClick = function() wu.Notify.info("Clicked!") end,
        onHold = function() wu.Notify.success("Held!") end,
        tooltip = "controls.HoldButton  - onClick + onHold callbacks",
    })
    ImGui.Dummy(0, 2)
    controls.HoldButton("tt_hold_dis", "  Disabled Hold  ", {
        style = "inactive", width = -1, disabled = true,
        tooltip = "controls.HoldButton  - disabled = true",
    })
    ImGui.Dummy(0, 4)
    controls.ActionButton("tt_action", "  Action: Click or Hold  ", {
        onPrimary = function() wu.Notify.info("Primary click") end,
        onSecondary = function() wu.Notify.success("Secondary hold") end,
        secondaryDuration = 1.0,
    })
    tooltips.ShowBullets("controls.ActionButton(id, label, opts)", {
        "id  - unique button group identifier",
        "label  - primary button text",
        "opts  - {onPrimary?, onSecondary?, secondaryDuration?, style?}",
    })

    ----------------------------------------------------------------------------
    -- Section: Button Rows
    ----------------------------------------------------------------------------
    controls.SectionHeader("Button Rows", 8, 4)
    controls.TextMuted("Equal text buttons:")
    controls.ButtonRow({
        { label = "  Option A  ", style = "active",   onClick = function() end },
        { label = "  Option B  ", style = "inactive", onClick = function() end },
        { label = "  Option C  ", style = "inactive", onClick = function() end },
    })
    tooltips.ShowBullets("controls.ButtonRow(defs, opts)", {
        "defs  - array of {label, icon, style, onClick, onHold, weight, ...}",
        "opts  - {gap?, id?}",
    })
    ImGui.Dummy(0, 4)
    controls.TextMuted("Weighted (2:1 text + icon):")
    controls.ButtonRow({
        { label = "Primary Action", style = "active", weight = 2,
          onClick = function() end },
        { label = "Cancel", style = "inactive",
          onClick = function() end },
        { icon = "ContentSave", style = "active",
          onClick = function() end },
    })
    tooltips.ShowBullets("controls.ButtonRow  - weighted", {
        "weight  - relative width share for text buttons",
        "Icon-only buttons auto-size, text buttons share remaining space",
    })

    ----------------------------------------------------------------------------
    -- Section: Layout & Display
    ----------------------------------------------------------------------------
    controls.SectionHeader("Layout & Display", 8, 4)
    -- ColWidth
    local w4 = controls.ColWidth(4)
    local w8 = controls.ColWidth(8)
    controls.Button("  col-4  ", "active", w4)
    tooltips.ShowBullets("controls.ColWidth(cols, gap, hasIcon)", {
        "cols  - column span 1-12 (Bootstrap-style grid)",
        "gap  - spacing between columns in pixels",
        "hasIcon  - whether an icon occupies space to the left",
    })
    ImGui.SameLine()
    controls.Button("  col-8  ", "inactive", w8)
    tooltips.ShowBullets("controls.ColWidth(8)", {
        "8/12 of available width",
    })
    ImGui.Dummy(0, 2)

    -- RemainingWidth
    local rw = controls.RemainingWidth(0)
    controls.Button("  Remaining (" .. math.floor(rw) .. "px)  ", "inactive", rw)
    tooltips.ShowBullets("controls.RemainingWidth(offset)", {
        "offset  - pixels to subtract from remaining width",
        "Returns available width minus offset",
    })
    ImGui.Dummy(0, 2)

    -- Separator
    controls.Separator(4, 4)
    ImGui.Text("^ Separator above ^")
    tooltips.ShowBullets("controls.Separator(spacingBefore, spacingAfter)", {
        "spacingBefore  - pixels above the line",
        "spacingAfter  - pixels below the line",
    })
    ImGui.Dummy(0, 2)

    -- SectionHeader
    controls.SectionHeader("Example Header", 0, 2)
    tooltips.ShowBullets("controls.SectionHeader(label, spacingBefore, spacingAfter, iconGlyph?)", {
        "label  - section title text",
        "spacingBefore  - pixels above",
        "spacingAfter  - pixels below",
        "iconGlyph  - optional HeaderIconGlyph opts table",
    })

    -- SectionHeader with icon glyph
    controls.SectionHeader("Header with Glyph", 4, 2, {
        icon = "Information",
        tooltip = "controls.HeaderIconGlyph(opts) rendered via SectionHeader's iconGlyph parameter",
    })
    controls.SectionHeader("Clickable Glyph", 4, 2, {
        icon = "AlertBox",
        tooltip = "Click the icon to trigger a callback",
        onClick = function() wu.Notify.info("Icon glyph clicked!") end,
    })
    tooltips.ShowBullets("controls.HeaderIconGlyph(opts)", {
        "icon  - IconGlyphs key name or raw glyph string",
        "tooltip  - hover tooltip text",
        "color  - {r, g, b, a} text color (optional)",
        "visible  - false to skip rendering (optional)",
        "onClick  - click callback (optional, renders as frameless button)",
    })

    -- Text styles
    controls.TextMuted("TextMuted  - dimmed helper text")
    tooltips.ShowBullets("controls.TextMuted(text)", { "Dimmed text for descriptions and hints" })
    controls.TextSuccess("TextSuccess  - green text")
    tooltips.ShowBullets("controls.TextSuccess(text)", { "Green-colored text for success messages" })
    controls.TextDanger("TextDanger  - red text")
    tooltips.ShowBullets("controls.TextDanger(text)", { "Red-colored text for error or danger" })
    controls.TextWarning("TextWarning  - yellow text")
    tooltips.ShowBullets("controls.TextWarning(text)", { "Yellow-colored text for warnings" })

    ----------------------------------------------------------------------------
    -- Section: Containers
    ----------------------------------------------------------------------------
    controls.SectionHeader("Containers", 8, 4)
    -- Row
    controls.TextMuted("Row (horizontal flex layout):")
    controls.Row("tt_row", {
        { flex = 1, content = function() controls.Button("  Left  ", "active") end },
        { flex = 1, content = function() controls.Button("  Right  ", "inactive") end },
    }, { height = ImGui.GetFrameHeight() })
    tooltips.ShowBullets("controls.Row(id, defs, opts)", {
        "id  - unique row identifier",
        "defs  - array of {flex?, auto?, content}",
        "opts  - {gap?, height?}",
    })
    ImGui.Dummy(0, 4)

    -- Column
    controls.TextMuted("Column (vertical auto layout):")
    controls.Column("tt_col", {
        { auto = true, content = function() controls.TextMuted("  Top (auto)") end },
        { auto = true, content = function() controls.TextMuted("  Bottom (auto)") end },
    })
    tooltips.ShowBullets("controls.Column(id, defs, opts)", {
        "id  - unique column identifier",
        "defs  - array of {flex?, auto?, content}",
        "opts  - {gap?}",
    })
    ImGui.Dummy(0, 4)

    -- Panel (nested demo with explicit height)
    controls.TextMuted("Panel (styled child window):")
    controls.Panel("tt_inner_panel", function()
        ImGui.Text("Nested panel content")
        controls.TextMuted("borderOnHover = true, custom bg")
    end, { borderOnHover = true, bg = { 0.12, 0.14, 0.18, 1.0 }, height = ImGui.GetTextLineHeightWithSpacing() * 2 + ImGui.GetStyle().WindowPadding.y * 2 })
    tooltips.ShowBullets("controls.Panel(id, contentFn, opts)", {
        "id  - unique panel identifier",
        "contentFn  - callback that renders panel content",
        "opts  - {bg?, border?, borderOnHover?, width?, height?, flags?}",
    })
    ImGui.Dummy(0, 4)

    -- BeginFillChild (demo with fixed height)
    controls.TextMuted("BeginFillChild (scrollable region):")
    ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(0.65, 0.7, 1.0, 0.045))
    ImGui.BeginChild("##tt_fill_demo", 0, 80, true)
    for i = 1, 12 do
        ImGui.Text("  Scrollable item " .. i)
    end
    ImGui.EndChild()
    ImGui.PopStyleColor()
    tooltips.ShowBullets("controls.BeginFillChild(id, opts) / EndFillChild(id)", {
        "id  - unique child region identifier",
        "opts  - {bg?, footerHeight?, border?, flags?}",
        "Fills remaining vertical space in normal use",
    })

    ----------------------------------------------------------------------------
    -- Section: Tooltip Styles
    ----------------------------------------------------------------------------
    controls.SectionHeader("Tooltip Styles", 8, 4)
    controls.TextMuted("Hover each button to see the tooltip style.")
    ImGui.Dummy(0, 2)

    controls.Button("  Show  ", "inactive")
    tooltips.Show("tooltips.Show(text, widthPct?)  - respects tooltipsEnabled, auto-wraps at configured max width")
    ImGui.Dummy(0, 2)

    controls.Button("  Show (20%)  ", "inactive")
    tooltips.Show("tooltips.Show(text, 20)  - override max width to 20% of screen width. This is a longer sentence to demonstrate the wrapping behavior at a wider percentage.", 20)
    ImGui.Dummy(0, 2)

    controls.Button("  Show (no wrap)  ", "inactive")
    tooltips.Show("tooltips.Show(text, 0)  - pass 0 to disable wrapping entirely", 0)
    ImGui.Dummy(0, 2)

    controls.Button("  ShowAlways  ", "inactive")
    tooltips.ShowAlways("tooltips.ShowAlways(text, widthPct?)  - always visible, ignores settings, auto-wraps")
    ImGui.Dummy(0, 2)

    controls.Button("  ShowWrapped  ", "inactive")
    tooltips.ShowWrapped("tooltips.ShowWrapped(text, maxWidth)  - wraps long text. This sentence demonstrates the wrapping behavior at 250px width.", 250)
    ImGui.Dummy(0, 2)

    controls.Button("  ShowTitled  ", "inactive")
    tooltips.ShowTitled("tooltips.ShowTitled(title, desc)", "Title line with separator and grey description below.")
    ImGui.Dummy(0, 2)

    controls.Button("  ShowHelp  ", "inactive")
    tooltips.ShowHelp("tooltips.ShowHelp(text)  - blue [?] prefix with wrapped help text.")
    ImGui.Dummy(0, 2)

    controls.Button("  ShowKeybind  ", "inactive")
    tooltips.ShowKeybind("tooltips.ShowKeybind(action, keybind)", "Ctrl+S")
    ImGui.Dummy(0, 2)

    controls.Button("  ShowWithHint  ", "inactive")
    tooltips.ShowWithHint("tooltips.ShowWithHint(text, hint)", "Grey hint below a separator")
    ImGui.Dummy(0, 2)

    controls.Button("  ShowLines  ", "inactive")
    tooltips.ShowLines({
        "tooltips.ShowLines(lines)",
        "Line 1  - each entry is a separate line",
        "Line 2  - no bullets, just plain text",
    })
    ImGui.Dummy(0, 2)

    controls.Button("  ShowBullets  ", "inactive")
    tooltips.ShowBullets("tooltips.ShowBullets(title, bullets)", {
        "title  - optional header above separator",
        "bullets  - array of bullet point strings",
    })
    ImGui.Dummy(0, 2)

    controls.Button("  ShowColored  ", "inactive")
    tooltips.ShowColored("tooltips.ShowColored(text, r, g, b, a)  - custom RGBA", 0.2, 0.8, 1.0, 1.0)
    ImGui.Dummy(0, 2)

    controls.Button("  ShowMuted  ", "inactive")
    tooltips.ShowMuted("tooltips.ShowMuted(text)  - grey/dimmed")
    ImGui.Dummy(0, 2)

    controls.Button("  ShowSuccess  ", "inactive")
    tooltips.ShowSuccess("tooltips.ShowSuccess(text)  - green")
    ImGui.Dummy(0, 2)

    controls.Button("  ShowDanger  ", "inactive")
    tooltips.ShowDanger("tooltips.ShowDanger(text)  - red")
    ImGui.Dummy(0, 2)

    controls.Button("  ShowWarning  ", "inactive")
    tooltips.ShowWarning("tooltips.ShowWarning(text)  - yellow")
    ImGui.Dummy(0, 2)

    controls.Button("  ShowIf (true)  ", "active")
    tooltips.ShowIf("tooltips.ShowIf(text, condition)  - shows when condition is true", true)
    ImGui.SameLine()
    controls.Button("  ShowIf (false)  ", "inactive")
    tooltips.ShowAlways("tooltips.ShowIf(text, condition)  - condition is false, so ShowIf would hide this. Using ShowAlways to demonstrate.")

    ----------------------------------------------------------------------------
    -- Section: Notifications
    ----------------------------------------------------------------------------
    controls.SectionHeader("Notifications", 8, 4)
    controls.TextMuted("Toast notifications via wu.Notify:")
    tooltips.ShowBullets("wu.Notify", {
        "wu.Notify.info(msg)  - blue info toast",
        "wu.Notify.success(msg)  - green success toast",
        "wu.Notify.warn(msg)  - yellow warning toast",
        "wu.Notify.error(msg)  - red error toast",
    })
    ImGui.Dummy(0, 2)
    if controls.Button("  Info  ", "inactive", controls.ColWidth(6)) then
        wu.Notify.info("wu.Notify.info  - informational toast")
    end
    tooltips.ShowBullets("wu.Notify.info(msg)", { "Blue informational toast" })
    ImGui.SameLine()
    if controls.Button("  Success  ", "active", controls.ColWidth(6)) then
        wu.Notify.success("wu.Notify.success  - success toast")
    end
    tooltips.ShowBullets("wu.Notify.success(msg)", { "Green success toast" })
    if controls.Button("  Warning  ", "warning", controls.ColWidth(6)) then
        wu.Notify.warn("wu.Notify.warn  - warning toast")
    end
    tooltips.ShowBullets("wu.Notify.warn(msg)", { "Yellow warning toast" })
    ImGui.SameLine()
    if controls.Button("  Error  ", "danger", controls.ColWidth(6)) then
        wu.Notify.error("wu.Notify.error  - error toast")
    end
    tooltips.ShowBullets("wu.Notify.error(msg)", { "Red error toast" })

    ImGui.Dummy(0, 8)
    controls.EndFillChild("tt_scroll")
end

--------------------------------------------------------------------------------
-- Tab 11: Search Demo
--------------------------------------------------------------------------------

local searchDemoState = nil
local searchDemoCtx = nil

local function drawSearchDemo()
    local controls = wu.Controls
    local search = wu.Search

    -- Create state and bind context once
    if not searchDemoState then
        searchDemoState = search.new("showcase_search")
        searchDemoCtx = controls.bind(searchDemoData, nil, nil, {
            search = searchDemoState,
            defs = searchDemoDefs,
        })
    end

    local c = searchDemoCtx

    controls.TextMuted("Search module with defs-based bind integration.")
    controls.TextMuted("No beginDim/endDim needed. Controls dim automatically.")
    ImGui.Dummy(0, 4)

    search.SearchBar(searchDemoState, { cols = 12 })
    ImGui.Dummy(0, 4)

    -- Group A: headers and controls dim automatically via category
    c:Header("Window Settings", "window")
    ImGui.Dummy(0, 2)
    c:Checkbox("Grid Snapping", "gridSnapping")
    c:Checkbox("Animation", "animation")
    c:Checkbox("Blur", "blur")
    c:Checkbox("Dim Background", "dimming")

    ImGui.Dummy(0, 4)

    -- Group B
    c:SectionHeader("Visual Settings", "visual", 0, 4)
    c:Checkbox("Feathered Grid", "feather")
    c:Checkbox("Tooltips", "tooltips")
    c:Checkbox("Debug Output", "debug")
    c:Checkbox("Line Color", "lineColor")

    ImGui.Dummy(0, 8)

    controls.TextMuted("Query: \"" .. searchDemoState:getQuery() .. "\"")
    controls.TextMuted("Empty: " .. tostring(searchDemoState:isEmpty()))
    controls.TextMuted("Window match: " .. tostring(searchDemoState:categoryHasMatch("window", searchDemoDefs)))
    controls.TextMuted("Visual match: " .. tostring(searchDemoState:categoryHasMatch("visual", searchDemoDefs)))

    ImGui.Dummy(0, 4)
    if controls.Button("  Clear Search  ", "inactive") then
        searchDemoState:clear()
    end
end

--------------------------------------------------------------------------------
-- Tab 12: Modal Demo
--------------------------------------------------------------------------------

local function drawModalDemo()
    local controls = wu.Controls
    local modal = wu.Modal

    controls.TextMuted("Modal module: centered popups with percent-based sizing.")
    ImGui.Dummy(0, 4)

    controls.SectionHeader("Basic Modals", 0, 4)

    controls.ButtonRow({
        { label = "Confirm", style = "active", weight = 1,
          onClick = function()
              modal.confirm("demo_confirm", {
                  title = "Confirm Action",
                  body = "Are you sure you want to proceed?",
                  onConfirm = function()
                      modalContentCounter = modalContentCounter + 1
                      wu.Notify.success("Confirmed #" .. modalContentCounter)
                  end,
              })
          end },
        { label = "Alert", style = "warning", weight = 1,
          onClick = function()
              modal.alert("demo_alert", {
                  title = "Alert",
                  body = "Something important happened.",
              })
          end },
        { label = "Info", style = "inactive", weight = 1,
          onClick = function()
              modal.info("demo_info", {
                  title = "Information",
                  body = "WindowUtils provides grid snapping, smooth animations, and a full controls library.",
              })
          end },
    })

    controls.SectionHeader("Hold to Confirm", 8, 4)

    controls.ButtonRow({
        { label = "Hold Confirm", style = "danger", weight = 1,
          onClick = function()
              modal.confirm("demo_hold_confirm", {
                  title = "Destructive Action",
                  body = "This will permanently delete all data. Hold to confirm.",
                  holdToConfirm = true,
                  holdDuration = 2.0,
                  onConfirm = function()
                      modalContentCounter = modalContentCounter + 1
                      wu.Notify.success("Hold-confirmed #" .. modalContentCounter)
                  end,
              })
          end },
        { label = "Custom Hold Buttons", style = "active", weight = 1,
          onClick = function()
              modal.open("demo_custom_hold", {
                  title = "Custom Buttons",
                  body = "Hold the delete button or click cancel:",
                  buttons = {
                      { label = "  Hold to Delete  ", style = "danger",
                        onHold = function()
                            modalContentCounter = modalContentCounter + 1
                            wu.Notify.success("Deleted #" .. modalContentCounter)
                        end,
                        holdDuration = 1.5, progressDisplay = "overlay" },
                      { label = "Cancel", style = "inactive" },
                  },
              })
          end },
    })

    controls.SectionHeader("Custom Content", 8, 4)

    controls.ButtonRow({
        { label = "Content Callback", style = "active", weight = 1,
          onClick = function()
              modal.open("demo_content", {
                  title = "Custom Content",
                  body = "Arbitrary ImGui content via callback:",
                  content = function(innerWidth)
                      ImGui.Dummy(0, 4)
                      controls.ProgressBar(0.7, innerWidth, 0, "70%", "success")
                      ImGui.Dummy(0, 2)
                      controls.ProgressBar(0.3, innerWidth, 0, "30%", "danger")
                      ImGui.Dummy(0, 4)
                  end,
                  buttons = {
                      { label = "Nice", style = "active" },
                      { label = "Close", style = "inactive" },
                  },
              })
          end },
        { label = "Padded (3%)", style = "inactive", weight = 1,
          onClick = function()
              modal.info("demo_padded", {
                  title = "Padded Modal",
                  body = "paddingPercent = 3 adds inner spacing around the content as a percentage of screen size.",
                  widthPercent = 40,
                  paddingPercent = 3,
              })
          end },
    })

    controls.SectionHeader("Sizing Options", 8, 4)
    controls.TextMuted("Width, height, and max height as screen percentages:")
    ImGui.Dummy(0, 2)

    controls.ButtonRow({
        { label = "Dynamic (default)", style = "inactive", weight = 3,
          onClick = function()
              modal.info("demo_dynamic", {
                  title = "Dynamic Size",
                  body = "Default: auto-height, 33% width, 50% max height. The popup grows to fit content.",
              })
          end },
        { label = "Wide (50%)", style = "inactive", weight = 5,
          onClick = function()
              modal.info("demo_wide", {
                  title = "Wide Modal",
                  body = "widthPercent = 50",
                  widthPercent = 50,
              })
          end },
        { label = "Narrow (20%)", style = "inactive", weight = 2,
          onClick = function()
              modal.info("demo_narrow", {
                  title = "Narrow Modal",
                  body = "widthPercent = 20",
                  widthPercent = 20,
              })
          end },
    })

    controls.ButtonRow({
        { label = "Fixed Height (30%)", style = "inactive", weight = 1,
          onClick = function()
              modal.info("demo_fixed_h", {
                  title = "Fixed Height",
                  body = "heightPercent = 30 locks the popup to exactly 30% of screen height.",
                  widthPercent = 33,
                  heightPercent = 30,
              })
          end },
        { label = "Large (50x35)", style = "inactive", weight = 1,
          onClick = function()
              modal.open("demo_large", {
                  title = "Large Modal",
                  body = "widthPercent = 50, heightPercent = 35",
                  widthPercent = 50,
                  heightPercent = 35,
                  content = function()
                      ImGui.Dummy(0, 4)
                      for i = 1, 8 do
                          controls.TextMuted("  Content line " .. i)
                      end
                  end,
                  buttons = { { label = "Close", style = "inactive" } },
              })
          end },
    })

    controls.SectionHeader("Styled Variant", 8, 4)
    controls.TextMuted("Centered title, no title bar, panel background behind body:")
    ImGui.Dummy(0, 2)

    controls.ButtonRow({
        { label = "Styled Info", style = "active", weight = 1,
          onClick = function()
              modal.styled("demo_styled", {
                  title = "About WindowUtils",
                  body = "WindowUtils is a universal ImGui window management library for CET mods. It provides grid snapping, smooth animations, collapse-safe sizing, visual effects, and a master settings GUI.",
                  widthPercent = 35,
              })
          end },
        { label = "Styled + Content", style = "active", weight = 1,
          onClick = function()
              modal.styled("demo_styled_content", {
                  title = "System Status",
                  widthPercent = 35,
                  content = function(innerWidth)
                      ImGui.Dummy(0, 2)
                      controls.TextMuted("Grid Snapping")
                      controls.ProgressBar(0.9, innerWidth, 0, "90%", "success")
                      ImGui.Dummy(0, 2)
                      controls.TextMuted("Animation Load")
                      controls.ProgressBar(0.45, innerWidth, 0, "45%", "default")
                      ImGui.Dummy(0, 2)
                      controls.TextMuted("Memory Usage")
                      controls.ProgressBar(0.72, innerWidth, 0, "72%", "danger")
                      ImGui.Dummy(0, 2)
                  end,
                  buttons = {
                      { label = "Refresh", style = "active", closesModal = false,
                        onClick = function() wu.Notify.info("Refreshed!") end },
                      { label = "Close", style = "inactive" },
                  },
              })
          end },
    })

    controls.ButtonRow({
        { label = "Styled Hold Confirm", style = "danger", weight = 1,
          onClick = function()
              modal.confirm("demo_styled_hold", {
                  title = "Delete Everything",
                  body = "This action is irreversible. All saved presets and window configurations will be permanently removed.",
                  styled = true,
                  widthPercent = 35,
                  holdToConfirm = true,
                  holdDuration = 2.0,
                  onConfirm = function()
                      modalContentCounter = modalContentCounter + 1
                      wu.Notify.success("Styled hold-confirmed #" .. modalContentCounter)
                  end,
              })
          end },
        { label = "Styled Hold Buttons", style = "danger", weight = 1,
          onClick = function()
              modal.styled("demo_styled_hold_btns", {
                  title = "Confirm Reset",
                  body = "Hold the reset button to restore all settings to their default values.",
                  widthPercent = 35,
                  buttons = {
                      { label = "  Hold to Reset  ", style = "danger",
                        onHold = function()
                            modalContentCounter = modalContentCounter + 1
                            wu.Notify.success("Reset via styled hold #" .. modalContentCounter)
                        end,
                        holdDuration = 1.5, progressDisplay = "overlay" },
                      { label = "Cancel", style = "inactive" },
                  },
              })
          end },
    })

    controls.ButtonRow({
        { label = "Styled Alert", style = "warning", weight = 1,
          onClick = function()
              modal.alert("demo_styled_alert", {
                  title = "Warning",
                  body = "The configuration file could not be saved. Check file permissions and try again.",
                  styled = true,
                  widthPercent = 35,
              })
          end },
        { label = "Styled Custom BG", style = "inactive", weight = 1,
          onClick = function()
              modal.styled("demo_styled_bg", {
                  title = "Custom Panel Color",
                  body = "This styled modal uses a custom panelBg color.",
                  widthPercent = 35,
                  panelBg = { 0.2, 0.8, 0.5, 0.06 },
              })
          end },
    })

    controls.SectionHeader("Changelog Preset", 8, 4)
    controls.TextMuted("Version sidebar + scrollable changes panel:")
    ImGui.Dummy(0, 2)

    controls.ButtonRow({
        { label = "Changelog", style = "active", weight = 1,
          onClick = function()
              modal.changelog("demo_changelog", {
                  title = "WindowUtils Changelog",
                  heightPercent = 65,
                  buttons = {
                      { label = "Dismiss", style = "inactive" },
                      { label = "  Acknowledge  ", style = "active",
                        onHold = function()
                            wu.Notify.success("Changelog acknowledged!")
                        end,
                        holdDuration = 1.5, progressDisplay = "overlay" },
                  },
                  versions = {
                      { version = "1.0.0-RC10", date = "2026-03-28", changes = {
                          "Added modal popup module with percent-based sizing",
                          "Added search/filter module with multi-word matching",
                          "Added multi-source hold progress helpers",
                          "Added styled modal variant with centered title",
                          "Added changelog modal preset",
                      }},
                      { version = "1.0.0-RC9", date = "2026-03-15", changes = {
                          "Fixed constraint animation edge case on collapse",
                          "Improved grid feathering performance",
                          "Added DynamicButton icon-only fallback mode",
                          "Updated notification toast fade timing",
                      }},
                      { version = "1.0.0-Beta20", date = "2026-02-28", changes = {
                          "Added expand module for window size management",
                          "Added toggle panel animations",
                          "Fixed splitter drag handle alignment",
                          "Improved scrollbar styling consistency",
                      }},
                      { version = "1.0.0-Beta19", date = "2026-02-10", changes = {
                          "Added drag and drop list reordering",
                          "Added tab bar with badge support",
                          "Fixed color picker alpha channel handling",
                      }},
                  },
              })
          end },
    })
end

--------------------------------------------------------------------------------
-- Tab 13: Multi-Source Hold Progress Demo
--------------------------------------------------------------------------------

local function drawHoldProgressDemo()
    local controls = wu.Controls

    controls.TextMuted("Multi-source hold progress: one display slot for several buttons.")
    ImGui.Dummy(0, 4)

    controls.SectionHeader("Shared Progress Target", 0, 4)
    controls.TextMuted("Hold any button below. The shared bar shows whichever is active:")
    ImGui.Dummy(0, 2)

    -- Three hold buttons with external progress
    local w4 = controls.ColWidth(4)
    controls.HoldButton("hp_src_a", "  Action A  ", {
        duration = 2.0, style = "active", width = w4,
        progressDisplay = "external",
        onHold = function() wu.Notify.success("Action A completed!") end,
        onClick = function() wu.Notify.info("Hold to confirm A") end,
    })
    ImGui.SameLine()
    controls.HoldButton("hp_src_b", "  Action B  ", {
        duration = 1.5, style = "warning", width = w4,
        progressDisplay = "external",
        onHold = function() wu.Notify.success("Action B completed!") end,
        onClick = function() wu.Notify.info("Hold to confirm B") end,
    })
    ImGui.SameLine()
    controls.HoldButton("hp_src_c", "  Action C  ", {
        duration = 1.0, style = "danger", width = w4,
        progressDisplay = "external",
        onHold = function() wu.Notify.success("Action C completed!") end,
        onClick = function() wu.Notify.info("Hold to confirm C") end,
    })

    ImGui.Dummy(0, 4)

    -- Shared progress target using getFirstActiveHoldProgress
    local sourceIds = { "hp_src_a", "hp_src_b", "hp_src_c" }
    if not controls.ShowFirstActiveHoldProgress(sourceIds, -1, "danger") then
        controls.TextMuted("  ^ Hold any button above to see progress here")
    end

    ImGui.Dummy(0, 8)

    controls.SectionHeader("ButtonRow with progressFrom", 0, 4)
    controls.TextMuted("The first slot shows progress from the delete button:")
    ImGui.Dummy(0, 2)

    controls.ButtonRow({
        { label = "My Preset", style = "active",
          onClick = function() wu.Notify.info("Load preset") end,
          progressFrom = "hp_row_del", progressStyle = "danger" },
        { icon = "Undo", style = "inactive",
          onClick = function() wu.Notify.info("Reset") end },
        { icon = "Delete", style = "danger",
          onHold = function() wu.Notify.success("Deleted!") end,
          holdDuration = 1.5, id = "hp_row_del", progressDisplay = "external" },
    })

    ImGui.Dummy(0, 8)

    controls.SectionHeader("Individual Progress Readout", 0, 4)
    local progressA = controls.getHoldProgress("hp_src_a")
    local progressB = controls.getHoldProgress("hp_src_b")
    local progressC = controls.getHoldProgress("hp_src_c")
    controls.TextMuted("A: " .. (progressA and string.format("%.1f%%", progressA * 100) or "idle"))
    controls.TextMuted("B: " .. (progressB and string.format("%.1f%%", progressB * 100) or "idle"))
    controls.TextMuted("C: " .. (progressC and string.format("%.1f%%", progressC * 100) or "idle"))

    local firstProgress, firstId = controls.getFirstActiveHoldProgress(sourceIds)
    if firstProgress then
        controls.TextMuted("First active: " .. firstId .. " at " .. string.format("%.1f%%", firstProgress * 100))
    else
        controls.TextMuted("First active: none")
    end
end

--------------------------------------------------------------------------------

registerForEvent("onInit", function()
    wu = GetMod("WindowUtils")
    if not wu then
        print("[WindowUtils_Showcase] WindowUtils not found!")
    end
    resW, resH = GetDisplayResolution()

    local ic = IconGlyphs or {}
    controlsPages = {
        { label = "Standard", icon = ic.Tune              or "?", page = 1 },
        { label = "Buttons",  icon = ic.GestureTapButton  or "?", page = 2 },
        { label = "Rows",     icon = ic.TableRow          or "?", page = 3 },
        { label = "Grid",     icon = ic.Grid              or "?", page = 4 },
        { label = "Layout",   icon = ic.ViewDashboard     or "?", page = 5 },
        { label = "Notify",   icon = ic.BellOutline       or "?", page = 6 },
    }
end)

registerHotkey("ToggleShowcase", "Toggle Window Utils Showcase", function()
    visible = not visible
end)

registerForEvent("onDraw", function()
    if not wu or not visible or not overlayOpen then return end

    local tabs = wu.Tabs

    local splitter = wu.Splitter
    local padX = ImGui.GetStyle().WindowPadding.x * 2
    local minW = math.max(
        splitter.getMinSize("etgl_inner") or 0,
        splitter.getMinSize("ms_dynbtn") or 0,
        splitter.getMinSize("ms_weighted") or 0,
        400 - padX
    ) + padX
    wu.SetNextWindowSizeConstraints(minW, 300, 9999, 9999, DEMO_WINDOW_NAME)
    ImGui.SetNextWindowSize(resW * 0.45, resH * 0.60, ImGuiCond.FirstUseEver)

    if ImGui.Begin(DEMO_WINDOW_NAME) then
        showcaseWinX,    showcaseWinY    = ImGui.GetWindowPos()
        showcaseWinW,    showcaseWinH    = ImGui.GetWindowSize()
        showcaseIsCollapsed = ImGui.IsWindowCollapsed()
        showcaseIsFocused   = ImGui.IsWindowFocused(ImGuiFocusedFlags.RootAndChildWindows)
        showcaseIsDragging  = showcaseIsFocused and ImGui.IsMouseDragging(ImGuiMouseButton.Left)
        showcaseIsAnimating = wu.IsAnimating(DEMO_WINDOW_NAME)
        ImGui.Text(DEMO_WINDOW_NAME)
        wu.Controls.TextMuted("See the Tooltips tab for API usage. Right-click bound controls to reset.")
        ImGui.Dummy(0, 4)

        -- Wrap tabs in NoScrollbar child to prevent main window scrollbar flash
        local cw, ch = ImGui.GetContentRegionAvail()
        local noScroll = ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse
        ImGui.BeginChild("##showcase_content", cw, ch, false, noScroll)
        local controlsBadge = nil
        if notifBadgeMode == "dot" and notifBadgeCount > 0 then
            controlsBadge = true
        elseif notifBadgeMode == "count" and notifBadgeCount > 0 then
            controlsBadge = notifBadgeCount
        end

        local selected, changed = tabs.bar("##showcase_tabs", {
            { label = "Controls",    content = drawControlsDemo, badge = controlsBadge },
            { label = "Drag & Drop", content = drawDragDropDemo },
            { label = "Splitters",   content = drawSplitterDemo },
            { label = "Multi-Split", content = drawMultiSplitterDemo },
            { label = "Toggle",      content = drawTogglePanelDemo },
            { label = "Edge Toggle", content = drawEdgeToggleDemo },
            { label = "Expand",      content = drawExpandDemo },
            { label = "Expand (V)", content = drawExpandVertDemo },
            { label = "Telemetry",  content = drawTelemetryDemo },
            { label = "Tooltips",   content = drawTooltipsDemo },
            { label = "Search",     content = drawSearchDemo },
            { label = "Modal",      content = drawModalDemo },
            { label = "Hold Multi", content = drawHoldProgressDemo },
        })

        if changed and selected == 1 and notifClearOnOpen then
            notifBadgeCount = 0
        end
        ImGui.EndChild()

        -- Expand: drive window sizing at main window scope (after EndChild)
        wu.Expand.applyWindowSize(DEMO_WINDOW_NAME)
    end
    wu.Update(DEMO_WINDOW_NAME)
    ImGui.End()
end)

registerForEvent("onOverlayOpen", function()
    overlayOpen = true
end)
registerForEvent("onOverlayClose", function()
    overlayOpen = false
end)
