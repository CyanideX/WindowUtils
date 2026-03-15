------------------------------------------------------
-- WindowUtils Demo
-- Production-ready reference sample for the WindowUtils API.
-- Hover any interactive element for API usage info.
------------------------------------------------------

local wu = nil
local visible = false

-- Demo state for standard controls
local demoDefaults = { slider = 0.5, checkbox = true, combo = 0, input = "Hello, World!" }
local demoState = { slider = 0.5, checkbox = true, combo = 0, input = "Hello, World!" }
local notifCounter = 0

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

-- Controls tab sidebar navigation
local controlsPage = 1
local controlsPages = {} -- populated in onInit after IconGlyphs is available

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
    local tooltips = wu.Tooltips

    wu.Splitter.multi("ctl_split", {
        { content = function()
            controls.Panel("ctl_nav", function()
                -- Left sidebar: DynamicButton nav (truncates text, collapses to icon)
                for _, entry in ipairs(controlsPages) do
                    if controls.DynamicButton(entry.label, entry.icon, {
                        style = controlsPage == entry.page and "active" or "inactive",
                        width = -1,
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
                    tooltip = "ctx:SliderFloat(icon, key, min, max, opts)\nRight-click to reset to default",
                })
                c:Checkbox("Enable Feature", "checkbox", {
                    tooltip = "ctx:Checkbox(label, key, opts)\nRight-click to reset to default",
                })
                c:Combo("Reload", "combo", { "Option A", "Option B", "Option C" }, {
                    tooltip = "ctx:Combo(icon, key, items, opts)\nRight-click to reset to default",
                })
                c:InputText("Reload", "input", {
                    maxLength = 256,
                    tooltip = "ctx:InputText(icon, key, opts)\nmaxLength = 256",
                })
                ImGui.Dummy(0, 2)
                controls.TextMuted("All controls use controls.bind(data, defaults) for auto-read/write/reset.")

            elseif controlsPage == 2 then
                -- Buttons: HoldButton variants + ActionButton
                controls.TextMuted("Overlay mode: progress overlays the button")
                ImGui.Dummy(0, 2)
                local held, clicked = controls.HoldButton("demo_overlay", "  Hold to Reset  ", {
                    duration = 2.0, style = "danger", width = controls.ColWidth(6),
                    tooltip = "controls.HoldButton(id, label, opts)\nprogressDisplay = \"overlay\" (default), duration = 2.0",
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
                    tooltip = "controls.HoldButton(id, label, opts)\nprogressDisplay = \"replace\", progressStyle = \"danger\"",
                })
                if held then wu.Notify.success("Replace mode triggered!") end
                if clicked then wu.Notify.info("Hold the button to confirm") end

                ImGui.Dummy(0, 6)

                controls.TextMuted("External mode: progress on a separate element")
                ImGui.Dummy(0, 2)
                held, clicked = controls.HoldButton("demo_external", "  Hold Me  ", {
                    duration = 2.0, style = "danger", width = controls.ColWidth(4),
                    progressDisplay = "external",
                    tooltip = "controls.HoldButton(id, label, opts)\nprogressDisplay = \"external\"",
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
                    tooltip = "controls.HoldButton(id, label, opts)\nonClick + onHold callbacks, width = -1 (full width)",
                })

                ImGui.Dummy(0, 6)

                controls.TextMuted("Hold-only with warning message")
                ImGui.Dummy(0, 2)
                controls.HoldButton("ctl_delete", "  Delete All Data  ", {
                    duration = 2.0, style = "danger", width = -1,
                    onHold = function() wu.Notify.success("All data deleted!") end,
                    onClick = function() wu.Notify.info("Hold to confirm deletion") end,
                    warningMessage = "Hold to confirm deletion",
                    tooltip = "controls.HoldButton(id, label, opts)\nwarningMessage shows text while holding",
                })

                ImGui.Dummy(0, 6)

                controls.TextMuted("Disabled state")
                ImGui.Dummy(0, 2)
                controls.HoldButton("ctl_locked", "  Cannot Click  ", {
                    style = "inactive", width = -1, disabled = true,
                    tooltip = "controls.HoldButton(id, label, opts)\ndisabled = true",
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
                tooltips.ShowBullets("controls.ActionButton(id, label, opts)", {
                    "onPrimary: click callback",
                    "onSecondary: hold-to-confirm callback",
                    "secondaryDuration = 1.0",
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
                tooltips.ShowBullets("controls.ActionButton(id, label, opts)", {
                    "progressStyle = \"success\"",
                    "Changes the hold progress bar color",
                })

            elseif controlsPage == 3 then
                -- Rows: ButtonRow + ToggleButtonRow
                controls.TextMuted("Equal text buttons:")
                controls.ButtonRow({
                    { label = "  Select A  ", style = "active",   onClick = function() wu.Notify.info("Clicked A") end },
                    { label = "  Select B  ", style = "inactive", onClick = function() wu.Notify.info("Clicked B") end },
                    { label = "  Select C  ", style = "inactive", onClick = function() wu.Notify.info("Clicked C") end },
                })
                tooltips.ShowBullets("controls.ButtonRow(defs)", {
                    "defs: {label, style, onClick}",
                    "Auto-distributes width across buttons",
                })

                ImGui.Dummy(0, 6)

                controls.TextMuted("Text + icons with cross-element progress:")
                controls.ButtonRow({
                    { label = "My Preset Name", style = "active",
                      onClick = function() wu.Notify.info("Load preset") end,
                      progressFrom = "ctl_del_b", progressStyle = "danger" },
                    { icon = "Undo", style = "inactive",
                      onClick = function() wu.Notify.info("Reset") end, tooltip = "Reset preset" },
                    { icon = "Delete", style = "danger",
                      onHold = function() wu.Notify.success("Deleted!") end,
                      holdDuration = 1.0, id = "ctl_del_b", progressDisplay = "external" },
                })
                tooltips.ShowBullets("controls.ButtonRow(defs)", {
                    "progressFrom = id: show another button's hold progress",
                    "onHold + holdDuration: hold-to-confirm on icon",
                    "progressDisplay = \"external\": progress shown elsewhere",
                })

                ImGui.Dummy(0, 6)

                controls.TextMuted("Weighted distribution (2:1 text + icon):")
                controls.ButtonRow({
                    { label = "Primary Action", style = "active", weight = 2,
                      onClick = function() wu.Notify.info("Primary") end },
                    { label = "Cancel", style = "inactive",
                      onClick = function() wu.Notify.info("Cancel") end },
                    { icon = "ContentSave", style = "active",
                      onClick = function() wu.Notify.info("Quick save") end, tooltip = "Quick save" },
                })
                tooltips.ShowBullets("controls.ButtonRow(defs)", {
                    "weight = 2: takes twice the space of unweighted",
                    "icon: auto-sized icon-only button",
                })

                controls.Separator(8, 8)

                local tc = controls.bind(advState, advDefaults)

                controls.TextMuted("Auto-sized icon toggles (left-click toggle, right-click reset):")
                tc:ToggleButtonRow({
                    { key = "featureA", icon = "AngleAcute", tooltip = "Feature A" },
                    { key = "featureB", icon = "SineWave",   tooltip = "Feature B" },
                    { key = "featureC", icon = "Motorbike",  tooltip = "Feature C" },
                    { key = "featureD", icon = "Car",        tooltip = "Feature D" },
                })
                tooltips.ShowBullets("ctx:ToggleButtonRow(defs)", {
                    "key: settings key to toggle (boolean)",
                    "icon: IconGlyphs name",
                    "Auto-sized to icon width",
                })
                controls.TextMuted("A=" .. tostring(advState.featureA) .. "  B=" .. tostring(advState.featureB)
                    .. "  C=" .. tostring(advState.featureC) .. "  D=" .. tostring(advState.featureD))

                ImGui.Dummy(0, 6)

                controls.TextMuted("With weight = 1 (fill remaining space evenly):")
                tc:ToggleButtonRow({
                    { key = "featureA", icon = "AngleAcute", weight = 1, tooltip = "Feature A (fill)" },
                    { key = "featureB", icon = "SineWave",   weight = 1, tooltip = "Feature B (fill)" },
                    { key = "featureC", icon = "Motorbike",  weight = 1, tooltip = "Feature C (fill)" },
                    { key = "featureD", icon = "Car",        weight = 1, tooltip = "Feature D (fill)" },
                })
                tooltips.ShowBullets("ctx:ToggleButtonRow(defs)", {
                    "weight = 1: each button fills equal space",
                })

            elseif controlsPage == 4 then
                -- Sliders: percent + transform
                local c = controls.bind(advState, advDefaults)

                c:SliderFloat("Brightness6", "opacity", 0, 1, {
                    percent = true,
                    tooltip = "ctx:SliderFloat(icon, key, 0, 1, {percent=true})\nDisplays 0-100% for a 0.0-1.0 float",
                })

                c:SliderInt("TuneVariant", "quality", 1, 23, {
                    percent = true,
                    tooltip = "ctx:SliderInt(icon, key, 1, 23, {percent=true})\nDisplays percentage of range for integers",
                })

                c:SliderInt("Speedometer", "speed", 0, 10, {
                    tooltip = "ctx:SliderInt(icon, key, min, max, opts)\nNormal slider (no percent) for comparison",
                })

                ImGui.Dummy(0, 6)

                controls.TextMuted("Combo with transform (stored as string, shown as index):")
                local findIdx = function(key)
                    for i, k in ipairs(easingKeys) do if k == key then return i - 1 end end
                    return 0
                end
                c:Combo("SineWave", "easeFunction", easingNames, {
                    tooltip = "ctx:Combo(icon, key, items, {transform={read, write}})\nStored as \"" .. tostring(advState.easeFunction) .. "\", displayed as dropdown index",
                    transform = {
                        read  = function(v) return findIdx(v) end,
                        write = function(v) return easingKeys[v + 1] end,
                    },
                })

            elseif controlsPage == 5 then
                -- Grid System
                controls.TextMuted("controls.ColWidth(n) sizes widgets to n/12 of available width.")
                ImGui.Dummy(0, 4)

                controls.SectionHeader("4 x col-3", 0, 4)
                local w3 = controls.ColWidth(3)
                for i = 1, 4 do
                    controls.Button("  col-3  ", "active", w3)
                    if i < 4 then ImGui.SameLine() end
                end
                tooltips.ShowBullets("controls.ColWidth(3)", {
                    "Returns pixel width for 3/12 of available space",
                    "Accounts for item spacing between elements",
                })

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

            elseif controlsPage == 6 then
                -- Layout Helpers
                controls.TextMuted("CollapsingSection: animated expand/collapse")
                ImGui.Dummy(0, 2)

                if controls.CollapsingSection("Nested Section A", "ctl_nested_a", true) then
                    controls.TextMuted("Open by default (3rd arg = true).")
                    ImGui.Text("Any content can go here.")
                    ImGui.Dummy(0, 4)
                    controls.EndCollapsingSection("ctl_nested_a")
                end
                tooltips.ShowBullets("controls.CollapsingSection(label, id, defaultOpen)", {
                    "Returns true when open",
                    "Call EndCollapsingSection(id) after content",
                })

                if controls.CollapsingSection("Nested Section B", "ctl_nested_b", false) then
                    controls.TextMuted("Starts closed (3rd arg = false).")
                    ImGui.Dummy(0, 4)
                    controls.EndCollapsingSection("ctl_nested_b")
                end

                ImGui.Dummy(0, 6)

                controls.TextMuted("BeginFillChild: scrollable child filling remaining space")
                ImGui.Dummy(0, 2)
                if controls.BeginFillChild("demo_fill", { bg = { 0.65, 0.7, 1.0, 0.045 } }) then
                    for i = 1, 30 do
                        ImGui.Text("  Scrollable item " .. i)
                    end
                end
                controls.EndFillChild({ bg = true })
                tooltips.ShowBullets("controls.BeginFillChild(id, opts)", {
                    "opts: {bg, footerHeight, border, flags}",
                    "Call EndFillChild(opts) to close",
                })

            elseif controlsPage == 7 then
                -- Notifications
                controls.TextMuted("Toast notifications drawn by WindowUtils:")
                ImGui.Dummy(0, 4)

                if controls.Button("  Info Toast  ", "inactive", controls.ColWidth(6)) then
                    notifCounter = notifCounter + 1
                    wu.Notify.info("This is an info message #" .. notifCounter)
                end
                tooltips.ShowBullets("wu.Notify.info(message, opts)", {
                    "opts: {ttl, fadeOut}",
                })
                ImGui.SameLine()
                if controls.Button("  Success Toast  ", "active", controls.ColWidth(6)) then
                    notifCounter = notifCounter + 1
                    wu.Notify.success("Operation completed! #" .. notifCounter)
                end
                tooltips.ShowBullets("wu.Notify.success(message, opts)", {
                    "Green success toast notification",
                })

                if controls.Button("  Warning Toast  ", "warning", controls.ColWidth(6)) then
                    notifCounter = notifCounter + 1
                    wu.Notify.warn("Caution: something needs attention #" .. notifCounter)
                end
                tooltips.ShowBullets("wu.Notify.warn(message, opts)", {
                    "Yellow warning toast notification",
                })
                ImGui.SameLine()
                if controls.Button("  Error Toast  ", "danger", controls.ColWidth(6)) then
                    notifCounter = notifCounter + 1
                    wu.Notify.error("Something went wrong! #" .. notifCounter)
                end
                tooltips.ShowBullets("wu.Notify.error(message, opts)", {
                    "Red error toast notification",
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
    local tooltips = wu.Tooltips

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
            tooltips.ShowBullets("controls.Column(id, defs)", {
                "flex = 1: equal height distribution",
                "height = N: fixed-height child",
                "border = true: visible border",
            })
        end },
    })
end

--------------------------------------------------------------------------------
-- Tab 3: Splitter Demo
--------------------------------------------------------------------------------

local function drawSplitterDemo()
    local controls = wu.Controls
    local splitter = wu.Splitter
    local tooltips = wu.Tooltips

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
            tooltips.ShowBullets("wu.Splitter.horizontal(id, leftFn, rightFn, opts)", {
                "defaultPct = 0.35 (left panel gets 35%)",
                "minPct = 0.15, maxPct = 0.7",
                "Position persists per ID",
            })
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
            tooltips.ShowBullets("wu.Splitter.vertical(id, topFn, bottomFn, opts)", {
                "defaultPct = 0.4 (top panel gets 40%)",
                "Same opts as horizontal: minPct, maxPct, grabWidth",
            })
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
                        controls.TextMuted("Dbl-click divider to collapse")
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
    local tooltips = wu.Tooltips

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
            tooltips.ShowBullets("wu.Splitter.toggle(id, panels, opts)", {
                "side = \"left\", size = 200",
                "defaultOpen = true",
                "Panels: [{content}] (toggle panel first, main second)",
            })
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
            tooltips.ShowBullets("wu.Splitter.toggle(id, panels, opts)", {
                "side = \"top\", size = 50",
                "Also supports: \"right\", \"bottom\"",
            })
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
            tooltips.ShowBullets("splitter.setToggle(id, bool)", {
                "Programmatically open/close a toggle panel",
            })
            ImGui.SameLine()
            if controls.Button(topOpen and "  Close Top  " or "  Open Top  ", topOpen and "danger" or "active", w6) then
                splitter.setToggle("tgl_top", not topOpen)
            end
            tooltips.ShowBullets("splitter.getToggle(id)", {
                "Returns current open/closed state (boolean)",
            })
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
        { toggle = true, size = toolbarH, defaultOpen = true, content = function()
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
                -- Core panel 2: output (flex)
                { content = function()
                    controls.Panel("etgl_output", function()
                        ImGui.Text("Output")
                        ImGui.Separator()
                        for i = 1, 4 do
                            controls.TextMuted("  [info] message " .. i)
                        end
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
        { toggle = true, size = statusH, defaultOpen = true, content = function()
            controls.Panel("etgl_status", function()
                ImGui.Text("Status Bar")
                ImGui.Separator()
                controls.TextMuted("Ln 42, Col 8  |  UTF-8  |  Lua")
            end, { bg = { 0.1, 0.12, 0.16, 1.0 } })
        end },
    }, { direction = "vertical" })
end

--------------------------------------------------------------------------------
-- Main Draw
--------------------------------------------------------------------------------

registerForEvent("onInit", function()
    wu = GetMod("WindowUtils")
    if not wu then
        print("[WindowUtils_TestMod] WindowUtils not found!")
    end

    local ic = IconGlyphs or {}
    controlsPages = {
        { label = "Standard", icon = ic.Tune              or "?", page = 1 },
        { label = "Buttons",  icon = ic.GestureTapButton  or "?", page = 2 },
        { label = "Rows",     icon = ic.TableRow          or "?", page = 3 },
        { label = "Sliders",  icon = ic.TuneVariant       or "?", page = 4 },
        { label = "Grid",     icon = ic.Grid              or "?", page = 5 },
        { label = "Layout",   icon = ic.ViewDashboard     or "?", page = 6 },
        { label = "Notify",   icon = ic.BellOutline       or "?", page = 7 },
    }
end)

registerHotkey("ToggleTestMod", "Toggle WindowUtils Test Mod", function()
    visible = not visible
end)

registerForEvent("onDraw", function()
    if not wu or not visible then return end

    local tabs = wu.Tabs

    ImGui.SetNextWindowSize(620, 550, ImGuiCond.FirstUseEver)

    if ImGui.Begin("WindowUtils Demo") then
        ImGui.Text("WindowUtils Demo")
        wu.Controls.TextMuted("Hover elements for API usage. Right-click bound controls to reset.")
        ImGui.Dummy(0, 4)

        tabs.bar("##testmod_tabs", {
            { label = "Controls",    content = drawControlsDemo },
            { label = "Drag & Drop", content = drawDragDropDemo },
            { label = "Splitters",   content = drawSplitterDemo },
            { label = "Multi-Split", content = drawMultiSplitterDemo },
            { label = "Toggle",      content = drawTogglePanelDemo },
            { label = "Edge Toggle", content = drawEdgeToggleDemo },
        })
    end
    ImGui.End()
end)

registerForEvent("onOverlayOpen", function() end)
registerForEvent("onOverlayClose", function()
    visible = false
end)
