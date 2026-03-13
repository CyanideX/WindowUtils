------------------------------------------------------
-- WindowUtils Test Mod
-- Standalone demo consuming WindowUtils as a library
------------------------------------------------------

local wu = nil
local visible = false

-- Demo state
local sliderValue = 0.5
local checkboxValue = true
local comboIndex = 0
local inputText = "Hello, World!"
local notifCounter = 0

-- Scrollbar customization state (applied to entire window)
local scrollSize = nil
local scrollRounding = nil
local scrollDefaults = nil
local scrollBg = { 0, 0, 0, 0 }
local scrollGrab = { 0.8, 0.8, 1.0, 0.4 }
local scrollHover = { 0.8, 0.8, 1.0, 0.6 }
local scrollActive = { 0.8, 0.8, 1.0, 0.8 }

-- Style color customization state (mirrors styles defaults)
local styleColors = {
    buttons = {
        active   = { bg = { 0.0, 1.0, 0.70, 0.88 },  hover = { 0.26, 1.0, 0.78, 1.0 },  active = { 0.0, 1.0, 0.70, 1.0 },  text = { 0.0, 0.11, 0.08, 1.0 } },
        inactive = { bg = { 0.26, 0.59, 0.98, 0.43 }, hover = { 0.26, 0.59, 0.98, 1.0 },  active = { 0.06, 0.53, 0.98, 1.0 }, text = { 1.0, 1.0, 1.0, 1.0 } },
        danger   = { bg = { 1.0, 0.30, 0.30, 0.88 },  hover = { 1.0, 0.38, 0.38, 1.0 },  active = { 0.93, 0.27, 0.27, 1.0 }, text = { 0.17, 0.0, 0.0, 1.0 } },
        warning  = { bg = { 1.0, 0.76, 0.24, 0.88 },  hover = { 1.0, 0.76, 0.24, 1.0 },  active = { 0.91, 0.63, 0.23, 1.0 }, text = { 0.16, 0.07, 0.0, 1.0 } },
        update   = { bg = { 0.0, 1.0, 0.70, 0.88 },   hover = { 0.25, 1.0, 0.78, 1.0 },  active = { 0.0, 1.0, 0.70, 0.88 },  text = { 0.0, 0.11, 0.08, 1.0 } },
    },
    holdOverlay = { 0.16, 0.16, 0.16, 0.31 },
    disabled = { bg = { 0.30, 0.30, 0.30, 0.71 }, text = { 0.5, 0.5, 0.5, 1.0 } },
    text = { muted = { 0.6, 0.6, 0.6, 1.0 }, success = { 0.0, 1.0, 0.7, 1.0 }, danger = { 1.0, 0.3, 0.3, 1.0 }, warning = { 1.0, 0.8, 0.0, 1.0 } },
    progress = {
        default = { fill = { 0.26, 0.59, 0.98, 1.0 }, frameBg = { 0.12, 0.26, 0.42, 0.3 }, border = { 0.24, 0.59, 1.0, 0.35 }, borderSize = 2.0 },
        danger  = { fill = { 1.0, 0.30, 0.30, 1.0 },   frameBg = { 0.78, 0.19, 0.19, 0.10 }, border = { 0.78, 0.19, 0.19, 0.47 }, borderSize = 2.0 },
        success = { fill = { 0.0, 1.0, 0.7, 1.0 },      frameBg = { 0.13, 0.79, 0.60, 0.10 }, border = { 0.13, 0.79, 0.59, 0.30 }, borderSize = 2.0 },
    },
}
local stylesDirty = false

-- Immutable defaults for right-click reset
local styleDefaults = {
    buttons = {
        active   = { bg = { 0.0, 1.0, 0.70, 0.88 },  hover = { 0.26, 1.0, 0.78, 1.0 },  active = { 0.0, 1.0, 0.70, 1.0 },  text = { 0.0, 0.11, 0.08, 1.0 } },
        inactive = { bg = { 0.26, 0.59, 0.98, 0.43 }, hover = { 0.26, 0.59, 0.98, 1.0 },  active = { 0.06, 0.53, 0.98, 1.0 }, text = { 1.0, 1.0, 1.0, 1.0 } },
        danger   = { bg = { 1.0, 0.30, 0.30, 0.88 },  hover = { 1.0, 0.38, 0.38, 1.0 },  active = { 0.93, 0.27, 0.27, 1.0 }, text = { 0.17, 0.0, 0.0, 1.0 } },
        warning  = { bg = { 1.0, 0.76, 0.24, 0.88 },  hover = { 1.0, 0.76, 0.24, 1.0 },  active = { 0.91, 0.63, 0.23, 1.0 }, text = { 0.16, 0.07, 0.0, 1.0 } },
        update   = { bg = { 0.0, 1.0, 0.70, 0.88 },   hover = { 0.25, 1.0, 0.78, 1.0 },  active = { 0.0, 1.0, 0.70, 0.88 },  text = { 0.0, 0.11, 0.08, 1.0 } },
    },
    holdOverlay = { 0.16, 0.16, 0.16, 0.31 },
    disabled = { bg = { 0.30, 0.30, 0.30, 0.71 }, text = { 0.5, 0.5, 0.5, 1.0 } },
    text = { muted = { 0.6, 0.6, 0.6, 1.0 }, success = { 0.0, 1.0, 0.7, 1.0 }, danger = { 1.0, 0.3, 0.3, 1.0 }, warning = { 1.0, 0.8, 0.0, 1.0 } },
    progress = {
        default = { fill = { 0.26, 0.59, 0.98, 1.0 }, frameBg = { 0.12, 0.26, 0.42, 0.3 }, border = { 0.24, 0.59, 1.0, 0.35 }, borderSize = 2.0 },
        danger  = { fill = { 1.0, 0.30, 0.30, 1.0 },   frameBg = { 0.78, 0.19, 0.19, 0.10 }, border = { 0.78, 0.19, 0.19, 0.47 }, borderSize = 2.0 },
        success = { fill = { 0.0, 1.0, 0.7, 1.0 },      frameBg = { 0.13, 0.79, 0.60, 0.10 }, border = { 0.13, 0.79, 0.59, 0.30 }, borderSize = 2.0 },
    },
}

local STYLES_PATH = "style_colors.json"
local function loadStyleColors()
    local file = io.open(STYLES_PATH, "r")
    if not file then return end
    local content = file:read("*a")
    file:close()
    local ok, data = pcall(json.decode, content)
    if ok and data then
        -- Deep-merge loaded data into styleColors
        for section, entries in pairs(data) do
            if type(styleColors[section]) == "table" and type(entries) == "table" then
                if entries[1] then
                    -- Simple color array (holdOverlay)
                    styleColors[section] = entries
                else
                    for key, val in pairs(entries) do
                        if type(styleColors[section][key]) == "table" and type(val) == "table" then
                            if val[1] then
                                styleColors[section][key] = val
                            else
                                for k2, v2 in pairs(val) do
                                    if styleColors[section][key][k2] ~= nil then
                                        styleColors[section][key][k2] = v2
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function saveStyleColors()
    local ok, content = pcall(json.encode, styleColors)
    if not ok then return end
    local file = io.open(STYLES_PATH, "w")
    if not file then return end
    file:write(content)
    file:close()
end

-- DragDrop demo items
local dragItems = {
    { name = "First Item",  icon = "1" },
    { name = "Second Item", icon = "2" },
    { name = "Third Item",  icon = "3" },
    { name = "Fourth Item", icon = "4" },
    { name = "Fifth Item",  icon = "5" },
}

--------------------------------------------------------------------------------
-- Tab 1: Grid System Demo
--------------------------------------------------------------------------------

local function drawGridDemo()
    local controls = wu.Controls
    local styles = wu.Styles

    ImGui.Dummy(0, 4)
    controls.TextMuted("12-column grid - use controls.ColWidth(n) to size any widget to n/12 of available width.")
    ImGui.Dummy(0, 8)

    -- NOTE: ColWidth() uses GetContentRegionAvail() internally, which shrinks
    -- after each SameLine(). Capture widths ONCE per row before placing elements.

    -- Row: 12 × col-1
    controls.SectionHeader("12 x col-1", 0, 4)
    local w1 = controls.ColWidth(1)
    for i = 1, 12 do
        controls.Button(" 1 ", "inactive", w1)
        if i < 12 then ImGui.SameLine() end
    end

    -- Row: 4 × col-3
    controls.SectionHeader("4 x col-3", 8, 4)
    local w3 = controls.ColWidth(3)
    for i = 1, 4 do
        controls.Button("  col-3  ", "active", w3)
        if i < 4 then ImGui.SameLine() end
    end

    -- Row: 3 × col-4
    controls.SectionHeader("3 x col-4", 8, 4)
    local w4 = controls.ColWidth(4)
    for i = 1, 3 do
        controls.Button("  col-4  ", "warning", w4)
        if i < 3 then ImGui.SameLine() end
    end

    -- Row: 2 × col-6
    controls.SectionHeader("2 x col-6", 8, 4)
    local w6 = controls.ColWidth(6)
    controls.Button("  col-6  ", "danger", w6)
    ImGui.SameLine()
    controls.Button("  col-6  ", "update", w6)

    -- Row: col-4 + col-8
    controls.SectionHeader("col-4 + col-8 (sidebar + main)", 8, 4)
    local w4b = controls.ColWidth(4)
    local w8 = controls.ColWidth(8)
    controls.Button("  col-4  ", "active", w4b)
    ImGui.SameLine()
    controls.Button("  col-8  ", "inactive", w8)

    -- Row: col-3 + col-6 + col-3
    controls.SectionHeader("col-3 + col-6 + col-3 (centered)", 8, 4)
    local w3b = controls.ColWidth(3)
    local w6b = controls.ColWidth(6)
    controls.Button("  col-3  ", "inactive", w3b)
    ImGui.SameLine()
    controls.Button("  col-6  ", "active", w6b)
    ImGui.SameLine()
    controls.Button("  col-3  ", "inactive", w3b)

    -- Row: full-width col-12
    controls.SectionHeader("col-12 (full width)", 8, 4)
    controls.Button("  col-12  ", "update", controls.ColWidth(12))
end

--------------------------------------------------------------------------------
-- Tab 2: Controls Demo (HoldButton, ActionButton, FillChild)
--------------------------------------------------------------------------------

local function drawControlsDemo()
    local controls = wu.Controls

    ImGui.Dummy(0, 4)

    -- HoldButton: overlay mode
    controls.SectionHeader("Hold Button - Overlay Mode", 0, 4)
    controls.TextMuted("Hold to trigger, click to see feedback:")
    ImGui.Dummy(0, 2)

    local held, clicked = controls.HoldButton("demo_overlay", "  Hold to Reset  ", {
        duration = 2.0, style = "danger", width = controls.ColWidth(6)
    })
    if held then
        sliderValue = 0.5
        checkboxValue = true
        comboIndex = 0
        inputText = "Hello, World!"
        wu.Notify.success("All values reset!")
    elseif clicked then
        wu.Notify.info("Hold the button to confirm reset")
    end

    ImGui.Dummy(0, 4)

    -- HoldButton: replace mode
    controls.SectionHeader("Hold Button - Replace Mode", 8, 4)
    controls.TextMuted("Button is replaced by a progress bar while held:")
    ImGui.Dummy(0, 2)

    held, clicked = controls.HoldButton("demo_replace", "  Hold (Replace)  ", {
        duration = 1.5, style = "warning", width = controls.ColWidth(6),
        progressDisplay = "replace", progressStyle = "danger"
    })
    if held then
        wu.Notify.success("Replace mode triggered!")
    elseif clicked then
        wu.Notify.info("Hold the button to confirm")
    end

    ImGui.Dummy(0, 4)

    -- Cross-element progress
    controls.SectionHeader("Cross-Element Progress", 8, 4)
    controls.TextMuted("Hold the button - progress appears on a separate element:")
    ImGui.Dummy(0, 2)

    held, clicked = controls.HoldButton("demo_external", "  Hold Me  ", {
        duration = 2.0, style = "danger", width = controls.ColWidth(4),
        progressDisplay = "external"
    })
    if held then
        wu.Notify.success("External progress triggered!")
    elseif clicked then
        wu.Notify.info("Hold the button to confirm")
    end
    ImGui.SameLine()
    if not controls.ShowHoldProgress("demo_external", controls.ColWidth(8), "danger") then
        controls.TextMuted("  <- Progress appears here while holding")
    end

    ImGui.Dummy(0, 4)

    -- ActionButton
    controls.SectionHeader("Action Button (primary + secondary hold)", 8, 4)
    controls.TextMuted("Click the label or hold the delete icon:")
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

    ImGui.Dummy(0, 4)

    -- Standard controls
    controls.SectionHeader("Standard Controls", 8, 4)

    sliderValue = controls.SliderFloat(IconGlyphs.Reload, "demo_slider", sliderValue, 0.0, 1.0, "%.2f", nil, 0.5, "Drag to adjust value")
    checkboxValue = controls.Checkbox("Enable Feature", checkboxValue, true, "Toggle this feature on or off")
    comboIndex = controls.Combo(IconGlyphs.Reload, "demo_combo", comboIndex, { "Option A", "Option B", "Option C" }, nil, 0, "Select an option")
    inputText = controls.InputText(IconGlyphs.Reload, "demo_input", inputText, 256, nil, "Type something here")

    -- CollapsingSection
    controls.SectionHeader("Collapsible Sections", 8, 4)

    if controls.CollapsingSection("Section A: Settings", "demo_section_a", true) then
        controls.TextMuted("This section is open by default.")
        ImGui.Text("Put any content here - sliders, buttons, etc.")
        ImGui.Dummy(0, 4)
        controls.EndCollapsingSection("demo_section_a")
    end

    if controls.CollapsingSection("Section B: Advanced", "demo_section_b", false) then
        controls.TextMuted("This section starts closed.")
        ImGui.Text("Click the header to toggle it open/closed.")
        ImGui.Dummy(0, 4)
        controls.EndCollapsingSection("demo_section_b")
    end

    -- FillChild demo
    controls.SectionHeader("Fill Child Region", 8, 4)
    controls.TextMuted("This child fills remaining vertical space:")

    if controls.BeginFillChild("demo_fill", {
        bg = { 0.65, 0.7, 1.0, 0.045 }
    }) then
        for i = 1, 30 do
            ImGui.Text("  Scrollable item " .. i)
        end
    end
    controls.EndFillChild({ bg = true })
end

--------------------------------------------------------------------------------
-- Tab 3: Splitter Demo
--------------------------------------------------------------------------------

local function drawSplitterDemo()
    local controls = wu.Controls
    local splitter = wu.Splitter

    ImGui.Dummy(0, 4)
    controls.TextMuted("Horizontal Splitter - drag the bar to resize panels")
    ImGui.Dummy(0, 4)

    ImGui.BeginChild("##splitter_demo_area", 0, 200, true)

    splitter.horizontal("##demo_h_split", function()
        ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(0.1, 0.15, 0.2, 1.0))
        ImGui.BeginChild("##left_content", 0, 0, false, ImGuiWindowFlags.AlwaysUseWindowPadding)
        ImGui.Text("Left Panel")
        ImGui.Separator()
        controls.TextMuted("Navigation, mod list, or")
        controls.TextMuted("any sidebar content here.")
        ImGui.Dummy(0, 8)
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
        controls.TextMuted("Detail view, settings, preview,")
        controls.TextMuted("or main content area.")
        ImGui.Dummy(0, 8)
        ImGui.TextWrapped("The splitter persists its position per ID. Mod authors can read it with getSplitPct() and save it to their own config.")
        ImGui.EndChild()
        ImGui.PopStyleColor()
    end, { defaultPct = 0.35, minPct = 0.15, maxPct = 0.7 })

    ImGui.EndChild()

    ImGui.Dummy(0, 8)
    controls.TextMuted("Vertical Splitter")
    ImGui.Dummy(0, 4)

    ImGui.BeginChild("##splitter_demo_v_area", 0, 200, true)

    splitter.vertical("##demo_v_split", function()
        ImGui.Text("Top Panel")
        ImGui.Separator()
        controls.TextMuted("Header content, toolbar, or search bar.")
    end, function()
        ImGui.Text("Bottom Panel")
        ImGui.Separator()
        controls.TextMuted("Log output, status bar, or detail pane.")
    end, { defaultPct = 0.4 })

    ImGui.EndChild()
end

--------------------------------------------------------------------------------
-- Tab 4: DragDrop Demo
--------------------------------------------------------------------------------

local function drawDragDropDemo()
    local controls = wu.Controls
    local dragdrop = wu.DragDrop

    ImGui.Dummy(0, 4)
    controls.TextMuted("Drag items to reorder the list:")
    ImGui.Dummy(0, 4)

    dragdrop.list("##demo_dd_list", dragItems, function(item, index, ctx)
        local label = item.icon .. ".  " .. item.name
        ImGui.Selectable(label, ctx.isDragged, 0, 0, 0)
    end, function(from, to)
        notifCounter = notifCounter + 1
        wu.Notify.info("Moved item from " .. from .. " to " .. to)
    end)

    ImGui.Dummy(0, 8)
    controls.Separator(4, 4)

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
end

--------------------------------------------------------------------------------
-- Tab 5: Notifications Demo
--------------------------------------------------------------------------------

local function drawNotificationsDemo()
    local controls = wu.Controls

    ImGui.Dummy(0, 4)
    controls.TextMuted("Fire toast notifications:")
    ImGui.Dummy(0, 4)

    if controls.Button("  Info Toast  ", "inactive", controls.ColWidth(6)) then
        notifCounter = notifCounter + 1
        wu.Notify.info("This is an info message #" .. notifCounter)
    end
    ImGui.SameLine()
    if controls.Button("  Success Toast  ", "active", controls.ColWidth(6)) then
        notifCounter = notifCounter + 1
        wu.Notify.success("Operation completed! #" .. notifCounter)
    end

    if controls.Button("  Warning Toast  ", "warning", controls.ColWidth(6)) then
        notifCounter = notifCounter + 1
        wu.Notify.warn("Caution: something needs attention #" .. notifCounter)
    end
    ImGui.SameLine()
    if controls.Button("  Error Toast  ", "danger", controls.ColWidth(6)) then
        notifCounter = notifCounter + 1
        wu.Notify.error("Something went wrong! #" .. notifCounter)
    end

    ImGui.Dummy(0, 8)
    controls.Separator(4, 4)
    controls.TextMuted("Notifications are drawn by WindowUtils itself.")
    controls.TextMuted("This mod only fires toasts via wu.Notify.info/success/warn/error.")
end

--------------------------------------------------------------------------------
-- Tab 6: Styles Demo
--------------------------------------------------------------------------------

local function drawStylesDemo()
    local controls = wu.Controls
    local styles = wu.Styles

    ImGui.Dummy(0, 4)

    local ic = IconGlyphs or {}
    local iconBg     = ic.SquareRounded or "B"
    local iconHover  = ic.CursorDefaultOutline or "H"
    local iconActive = ic.GestureTapButton or "A"
    local iconText   = ic.FormatText or "T"

    controls.TextMuted("Colors auto-save to style_colors.json. Right-click any picker to reset.")

    -- Helper: 4-picker row for a button color set
    local function buttonPickers(prefix, c, d)
        local new, ch
        new, ch = controls.ColorEdit4(iconBg, prefix .. "_bg", c.bg, nil, d.bg, "Background")
        if ch then c.bg = new; stylesDirty = true end
        new, ch = controls.ColorEdit4(iconHover, prefix .. "_hover", c.hover, nil, d.hover, "Hover")
        if ch then c.hover = new; stylesDirty = true end
        new, ch = controls.ColorEdit4(iconActive, prefix .. "_active", c.active, nil, d.active, "Active")
        if ch then c.active = new; stylesDirty = true end
        new, ch = controls.ColorEdit4(iconText, prefix .. "_text", c.text, nil, d.text, "Text color")
        if ch then c.text = new; stylesDirty = true end
    end

    -- Helper: push/pop custom progress bar colors from picker values
    local function pushCustomProgress(p)
        if p.fill then
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, p.fill[1], p.fill[2], p.fill[3], p.fill[4])
        end
        ImGui.PushStyleColor(ImGuiCol.FrameBg, p.frameBg[1], p.frameBg[2], p.frameBg[3], p.frameBg[4])
        ImGui.PushStyleColor(ImGuiCol.Border, p.border[1], p.border[2], p.border[3], p.border[4])
        ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, p.borderSize or 2.0)
    end
    local function popCustomProgress(p)
        ImGui.PopStyleVar(1)
        ImGui.PopStyleColor(p.fill and 3 or 2)
    end

    -- Helper: 3 color pickers + border thickness slider for progress bar colors
    local iconFill   = ic.FormatColorFill or "F"
    local iconFrame  = iconBg
    local iconBorder = ic.BorderOutside or "R"
    local function progressPickers(prefix, p, dp)
        local new, ch
        new, ch = controls.ColorEdit4(iconFill, prefix .. "_fill", p.fill, nil, dp.fill, "Fill color")
        if ch then p.fill = new; stylesDirty = true end
        new, ch = controls.ColorEdit4(iconFrame, prefix .. "_frameBg", p.frameBg, nil, dp.frameBg, "Frame background")
        if ch then p.frameBg = new; stylesDirty = true end
        new, ch = controls.ColorEdit4(iconBorder, prefix .. "_border", p.border, nil, dp.border, "Border color")
        if ch then p.border = new; stylesDirty = true end
        local newSize = controls.SliderFloat(iconBorder, prefix .. "_borderSize", p.borderSize or 2.0, 0.0, 6.0, "%.1f", nil, dp.borderSize or 2.0, "Border thickness")
        if newSize ~= p.borderSize then p.borderSize = newSize; stylesDirty = true end
    end

    local btnOrder = { "active", "inactive", "danger", "warning", "update" }
    local btns = styleColors.buttons
    local defs = styleDefaults.buttons

    -- Each button style: Label → Sample → Pickers
    for _, name in ipairs(btnOrder) do
        local c = btns[name]
        local d = defs[name]
        controls.SectionHeader(name:sub(1,1):upper() .. name:sub(2), 4, 4)
        styles.PushButton(c)
        ImGui.Button("  " .. name:sub(1,1):upper() .. name:sub(2) .. " Button  ", controls.ColWidth(6), 0)
        styles.PopButton(c)
        buttonPickers("btn_" .. name, c, d)
    end

    -- Disabled: Label → Sample → Pickers
    local dis = styleColors.disabled
    local dDis = styleDefaults.disabled
    controls.SectionHeader("Disabled", 4, 4)
    styles.PushButton({ bg = dis.bg, hover = dis.bg, active = dis.bg, text = dis.text })
    ImGui.Button("  Disabled Button  ", controls.ColWidth(6), 0)
    styles.PopButton({ bg = dis.bg, hover = dis.bg, active = dis.bg, text = dis.text })
    local newD, chD
    newD, chD = controls.ColorEdit4(iconBg, "dis_bg", dis.bg, nil, dDis.bg, "Disabled background")
    if chD then dis.bg = newD; stylesDirty = true end
    newD, chD = controls.ColorEdit4(iconText, "dis_text", dis.text, nil, dDis.text, "Disabled text")
    if chD then dis.text = newD; stylesDirty = true end

    -- Hold Overlay: Label → Sample → Picker
    controls.SectionHeader("Hold Button — Overlay", 4, 4)
    local held, clicked = controls.HoldButton("style_hold_overlay", "  Hold (Overlay)  ", {
        duration = 2.0, style = btns.danger, width = controls.ColWidth(6), progressDisplay = "overlay",
        overlayColor = styleColors.holdOverlay
    })
    if held then wu.Notify.success("Overlay hold triggered!") end
    if clicked then wu.Notify.info("Hold the button to confirm") end
    local newOv, chOv = controls.ColorEdit4(ic.SquareOpacity or "O", "hold_overlay", styleColors.holdOverlay, nil, styleDefaults.holdOverlay, "Overlay fill color")
    if chOv then styleColors.holdOverlay = newOv; stylesDirty = true end

    -- Hold Replace: Label → Sample + sample bar → Pickers
    controls.SectionHeader("Hold Button — Replace", 4, 4)
    local replW = controls.ColWidth(6)
    held, clicked = controls.HoldButton("style_hold_replace", "  Hold (Replace)  ", {
        duration = 2.0, style = btns.danger, width = replW, progressDisplay = "replace",
        progressStyle = styleColors.progress.danger
    })
    if held then wu.Notify.success("Replace hold triggered!") end
    if clicked then wu.Notify.info("Hold the button to confirm") end
    ImGui.SameLine()
    local pDanger = styleColors.progress.danger
    pushCustomProgress(pDanger)
    ImGui.ProgressBar(0.6, controls.ColWidth(6), 0, "Sample")
    popCustomProgress(pDanger)
    progressPickers("prog_danger", pDanger, styleDefaults.progress.danger)

    -- Hold External: Label → Sample + swap text/bar → Pickers
    controls.SectionHeader("Hold Button — External", 4, 4)
    held, clicked = controls.HoldButton("style_hold_external", "  Hold (External)  ", {
        duration = 2.0, style = btns.warning, width = controls.ColWidth(6), progressDisplay = "external"
    })
    if held then wu.Notify.success("External hold triggered!") end
    if clicked then wu.Notify.info("Hold the button to confirm") end
    local extProgress = controls.getHoldProgress("style_hold_external") or 0
    local pSuccess = styleColors.progress.success
    if extProgress > 0 then
        pushCustomProgress(pSuccess)
        ImGui.ProgressBar(extProgress, ImGui.GetContentRegionAvail(), 0, string.format("%.0f%%", extProgress * 100))
        popCustomProgress(pSuccess)
    else
        controls.TextMuted("Hold the button above to see the external progress bar.")
    end
    progressPickers("prog_success", pSuccess, styleDefaults.progress.success)

    -- Text Styles: Label → Samples → Pickers
    local tx = styleColors.text
    local dTx = styleDefaults.text
    local function colorText(text, color)
        ImGui.PushStyleColor(ImGuiCol.Text, color[1], color[2], color[3], color[4])
        ImGui.Text(text)
        ImGui.PopStyleColor()
    end
    controls.SectionHeader("Text — Muted", 4, 4)
    colorText("Muted text for descriptions", tx.muted)
    local newT, chT
    newT, chT = controls.ColorEdit4(iconText, "txt_muted", tx.muted, nil, dTx.muted, "Muted text")
    if chT then tx.muted = newT; stylesDirty = true end

    controls.SectionHeader("Text — Success", 4, 4)
    colorText("Success - operation completed", tx.success)
    newT, chT = controls.ColorEdit4(iconText, "txt_success", tx.success, nil, dTx.success, "Success text")
    if chT then tx.success = newT; stylesDirty = true end

    controls.SectionHeader("Text — Danger", 4, 4)
    colorText("Danger - something went wrong", tx.danger)
    newT, chT = controls.ColorEdit4(iconText, "txt_danger", tx.danger, nil, dTx.danger, "Danger text")
    if chT then tx.danger = newT; stylesDirty = true end

    controls.SectionHeader("Text — Warning", 4, 4)
    colorText("Warning - proceed with caution", tx.warning)
    newT, chT = controls.ColorEdit4(iconText, "txt_warning", tx.warning, nil, dTx.warning, "Warning text")
    if chT then tx.warning = newT; stylesDirty = true end

    -- Progress Bars — each style with live preview + pickers
    local pProg = styleColors.progress
    local dProg = styleDefaults.progress

    controls.SectionHeader("Progress Bar — Default", 4, 4)
    pushCustomProgress(pProg.default)
    ImGui.ProgressBar(0.7, ImGui.GetContentRegionAvail(), 0, "70% Complete")
    popCustomProgress(pProg.default)
    progressPickers("prog_def", pProg.default, dProg.default)

    controls.SectionHeader("Progress Bar — Danger", 4, 4)
    pushCustomProgress(pProg.danger)
    ImGui.ProgressBar(0.3, ImGui.GetContentRegionAvail(), 0, "30% Health")
    popCustomProgress(pProg.danger)
    controls.TextMuted("Colors shared with Hold Replace pickers above.")

    controls.SectionHeader("Progress Bar — Success", 4, 4)
    pushCustomProgress(pProg.success)
    ImGui.ProgressBar(0.9, ImGui.GetContentRegionAvail(), 0, "90% Progress")
    popCustomProgress(pProg.success)
    controls.TextMuted("Colors shared with Hold External pickers above.")

    ImGui.Dummy(0, 4)
    controls.SectionHeader("Scrollbar Styles", 4, 4)
    controls.TextMuted("PushScrollbar() / PopScrollbar() - these settings apply to the entire window.")
    ImGui.Dummy(0, 4)

    -- Capture defaults before any push (first frame only)
    if not scrollDefaults then
        scrollDefaults = { size = math.max(6, math.floor(ImGui.GetFontSize() * 0.4)), rounding = 10 }
        scrollSize = scrollDefaults.size
        scrollRounding = scrollDefaults.rounding
    end

    scrollSize = controls.SliderFloat(nil, "scroll_size", scrollSize, 1, 40, "%.0f", 6, scrollDefaults.size, "Thickness")
    ImGui.SameLine()
    scrollRounding = controls.SliderFloat(nil, "scroll_rounding", scrollRounding, 0, 20, "%.0f", 6, scrollDefaults.rounding, "Rounding")

    scrollBg = controls.ColorEdit4(ic.SquareRounded or "B", "scroll_bg", scrollBg, nil, { 0, 0, 0, 0 }, "Track background")
    scrollGrab = controls.ColorEdit4(ic.GestureTapButton or "G", "scroll_grab", scrollGrab, nil, { 0.8, 0.8, 1.0, 0.4 }, "Thumb color")
    scrollHover = controls.ColorEdit4(ic.CursorDefaultOutline or "H", "scroll_hover", scrollHover, nil, { 0.8, 0.8, 1.0, 0.6 }, "Thumb hover")
    scrollActive = controls.ColorEdit4(ic.GestureTapButton or "A", "scroll_active", scrollActive, nil, { 0.8, 0.8, 1.0, 0.8 }, "Thumb active")

    ImGui.Dummy(0, 4)
    ImGui.Text("Preview:")
    ImGui.BeginChild("##scroll_preview", 0, 100, true)
    for i = 1, 20 do
        ImGui.Text("  Scrollable item " .. i)
    end
    ImGui.EndChild()
end

--------------------------------------------------------------------------------
-- Tab 7: Layout Demo (Row / Column)
--------------------------------------------------------------------------------

local function drawLayoutDemo()
    local controls = wu.Controls
    local splitter = wu.Splitter

    ImGui.Dummy(0, 4)
    controls.TextMuted("Row/Column layouts with draggable splitters for resizing.")
    ImGui.Dummy(0, 8)

    -- Vertical splitter: top (3-column row) | middle (sidebar + flex) | bottom (column)
    -- Top row section: 3 equal flex panels with horizontal splitters between them
    splitter.vertical("##layout_top_mid", function()

        -- Row 1: 3 equal panels separated by horizontal splitters
        splitter.horizontal("##layout_h_outer", function()
            splitter.horizontal("##layout_h_inner", function()
                -- Panel 1
                ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(0.65, 0.7, 1.0, 0.045))
                ImGui.BeginChild("##lp1", 0, 0, true)
                ImGui.Text("Panel 1")
                ImGui.Separator()
                controls.TextMuted("flex = 1 (default)")
                controls.TextMuted("Drag bars to resize.")
                ImGui.Dummy(0, ImGui.GetStyle().ItemSpacing.y * 0.5)
                controls.Button("  Select A  ", "active")
                controls.Button("  Select B  ", "inactive")
                controls.Button("  Select C  ", "inactive")
                ImGui.EndChild()
                ImGui.PopStyleColor()
            end, function()
                -- Panel 2
                ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(0.65, 0.7, 1.0, 0.045))
                ImGui.BeginChild("##lp2", 0, 0, true)
                ImGui.Text("Panel 2")
                ImGui.Separator()
                controls.TextMuted("flex = 1 (default)")
                controls.TextMuted("Resizable from both sides.")
                ImGui.Dummy(0, ImGui.GetStyle().ItemSpacing.y * 0.5)
                for i = 1, 6 do
                    ImGui.Text("  Item " .. i)
                end
                ImGui.EndChild()
                ImGui.PopStyleColor()
            end, { defaultPct = 0.5, minPct = 0.15, maxPct = 0.85 })
        end, function()
            -- Panel 3
            ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(0.65, 0.7, 1.0, 0.045))
            ImGui.BeginChild("##lp3", 0, 0, true)
            ImGui.Text("Panel 3")
            ImGui.Separator()
            controls.TextMuted("flex = 1 (default)")
            controls.TextMuted("Properties / details.")
            ImGui.EndChild()
            ImGui.PopStyleColor()
        end, { defaultPct = 0.66, minPct = 0.3, maxPct = 0.85 })

    end, function()

        -- Vertical splitter: middle (sidebar + flex) | bottom (column)
        splitter.vertical("##layout_mid_bot", function()

            -- Row 2: fixed sidebar + flex content
            splitter.horizontal("##layout_h_sidebar", function()
                ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(0.1, 0.15, 0.2, 1.0))
                ImGui.BeginChild("##lsidebar", 0, 0, true)
                ImGui.Text("Sidebar")
                ImGui.Separator()
                controls.TextMuted("width = 150")
                ImGui.EndChild()
                ImGui.PopStyleColor()
            end, function()
                ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(0.65, 0.7, 1.0, 0.045))
                ImGui.BeginChild("##lmain", 0, 0, true)
                ImGui.Text("Main Content")
                ImGui.Separator()
                controls.TextMuted("flex = 1 (fills remaining)")
                ImGui.EndChild()
                ImGui.PopStyleColor()
            end, { defaultPct = 0.25, minPct = 0.1, maxPct = 0.5 })

        end, function()

            -- Row 3: header + content + footer using Column
            local rowH = ImGui.GetTextLineHeight() + ImGui.GetStyle().WindowPadding.y * 2
            controls.Column("demo_col", {
                { height = rowH, border = true, bg = { 0.15, 0.15, 0.2, 1.0 }, content = function()
                    ImGui.Text("  Header (fixed 1 row)")
                end },
                { border = true, bg = { 0.65, 0.7, 1.0, 0.045 }, content = function()
                    ImGui.Text("  Scrollable content (flex)")
                    for i = 1, 10 do
                        controls.TextMuted("    Log entry " .. i)
                    end
                end },
                { height = rowH, border = true, bg = { 0.15, 0.15, 0.2, 1.0 }, content = function()
                    ImGui.Text("  Footer (fixed 1 row)")
                end },
            })

        end, { defaultPct = 0.45, minPct = 0.15, maxPct = 0.85 })

    end, { defaultPct = 0.4, minPct = 0.15, maxPct = 0.85 })
end

--------------------------------------------------------------------------------
-- Main Draw
--------------------------------------------------------------------------------

registerForEvent("onInit", function()
    wu = GetMod("WindowUtils")
    if not wu then
        print("[WindowUtils_TestMod] WindowUtils not found!")
    end
    loadStyleColors()
end)

registerHotkey("ToggleTestMod", "Toggle WindowUtils Test Mod", function()
    visible = not visible
end)

registerForEvent("onDraw", function()
    if not wu or not visible then return end

    local tabs = wu.Tabs
    local controls = wu.Controls

    ImGui.SetNextWindowSize(620, 550, ImGuiCond.FirstUseEver)

    -- Push scrollbar customization for the entire window
    local styles = wu.Styles
    local scrollPushed = scrollSize ~= nil
    if scrollPushed then
        styles.PushScrollbar({
            size = scrollSize, rounding = scrollRounding,
            bg = scrollBg, grab = scrollGrab,
            hover = scrollHover, active = scrollActive,
        })
    end

    if ImGui.Begin("WindowUtils Test Mod") then
        ImGui.Text("WindowUtils Test Mod")
        controls.TextMuted("Interactive demo - consuming WindowUtils as a library")
        ImGui.Dummy(0, 4)

        local selected, changed = tabs.bar("##testmod_tabs", {
            { label = "Grid",          content = drawGridDemo },
            { label = "Controls",      content = drawControlsDemo },
            { label = "Splitter",      content = drawSplitterDemo },
            { label = "DragDrop",      content = drawDragDropDemo, badge = true },
            { label = "Notifications", content = drawNotificationsDemo, badge = notifCounter > 0 and notifCounter or nil },
            { label = "Styles",        content = drawStylesDemo },
            { label = "Layout",        content = drawLayoutDemo },
        })
        if changed and selected == 5 then notifCounter = 0 end
    end
    ImGui.End()

    if scrollPushed then
        styles.PopScrollbar()
    end

    -- Auto-save style colors when changed
    if stylesDirty then
        saveStyleColors()
        stylesDirty = false
    end
end)

registerForEvent("onOverlayOpen", function() end)
registerForEvent("onOverlayClose", function()
    visible = false
end)
