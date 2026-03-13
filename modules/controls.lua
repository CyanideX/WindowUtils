------------------------------------------------------
-- WindowUtils - Controls Module
-- Universal ImGui control helpers for CET mods
------------------------------------------------------

local styles = require("modules/styles")
local tooltips = require("modules/tooltips")

local controls = {}

--------------------------------------------------------------------------------
-- Per-frame style cache (call controls.cacheFrameState() once per onDraw)
--------------------------------------------------------------------------------

local frameCache = {}

function controls.cacheFrameState()
    local style = ImGui.GetStyle()
    frameCache.itemSpacingX = style.ItemSpacing.x
    frameCache.itemSpacingY = style.ItemSpacing.y
    frameCache.framePaddingX = style.FramePadding.x
    frameCache.windowPaddingY = style.WindowPadding.y
    frameCache.frameHeight = ImGui.GetFrameHeight()
    frameCache.textLineHeight = ImGui.GetTextLineHeightWithSpacing()
end

function controls.getFrameCache()
    return frameCache
end

--------------------------------------------------------------------------------
-- Grid System (Bootstrap-style columns)
--------------------------------------------------------------------------------

-- Approximate icon button width (glyph + padding)
local ICON_WIDTH = 24

--- Calculate width for a column ratio (1-12 out of 12 columns)
function controls.ColWidth(cols, gap, hasIcon)
    cols = math.max(1, math.min(12, cols or 12))
    gap = gap or frameCache.itemSpacingX
    local availWidth = ImGui.GetContentRegionAvail()
    -- If called after icon placement, add icon width back for accurate column calculation
    if hasIcon then
        availWidth = availWidth + ICON_WIDTH + gap
    end
    local colWidth = (availWidth - (gap * 11)) / 12
    local targetWidth = (colWidth * cols) + (gap * (cols - 1))
    -- Subtract icon space if present
    if hasIcon then
        targetWidth = targetWidth - ICON_WIDTH - gap
    end
    return math.max(targetWidth, 20)  -- Minimum 20px
end

--- Get remaining width after current cursor position
function controls.RemainingWidth(offset)
    offset = offset or 0
    return ImGui.GetContentRegionAvail() - offset
end

--------------------------------------------------------------------------------
-- Icon Button (Invisible button with icon for labels)
--------------------------------------------------------------------------------

--- Create an invisible button with an icon (for use as slider/input labels)
function controls.IconButton(icon, clickable)
    clickable = clickable or false

    styles.PushButtonTransparent()
    local clicked = ImGui.Button(icon)
    styles.PopButtonTransparent()

    if clickable then
        return clicked
    end
    return false
end

--------------------------------------------------------------------------------
-- Styled Buttons
--------------------------------------------------------------------------------

--- Create a styled button with automatic push/pop
function controls.Button(label, styleName, width, height)
    styleName = styleName or "inactive"
    width = width or 0
    height = height or 0

    styles.PushButton(styleName)
    local clicked = ImGui.Button(label, width, height)
    styles.PopButton(styleName)

    return clicked
end

--- Create a toggle button that switches between active/inactive styles
function controls.ToggleButton(label, isActive, width, height)
    local styleName = isActive and "active" or "inactive"
    return controls.Button(label, styleName, width, height)
end

--- Create a full-width button (fills available width)
function controls.FullWidthButton(label, styleName)
    return controls.Button(label, styleName, ImGui.GetContentRegionAvail())
end

--- Create a disabled button that cannot be clicked
function controls.DisabledButton(label, width, height)
    width = width or 0
    height = height or 0

    styles.PushButtonDisabled()
    ImGui.Button(label, width, height)
    styles.PopButtonDisabled()
end

--------------------------------------------------------------------------------
-- Sliders with Icon (Shift-style: icon on left, slider fills remaining width)
--------------------------------------------------------------------------------

--- Create a float slider with icon on left, fills remaining width
function controls.SliderFloat(icon, id, value, min, max, format, cols, defaultValue, tooltip)
    format = format or "%.2f"

    local hasIcon = icon ~= nil and icon ~= ""
    if hasIcon then
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 4, frameCache.itemSpacingY)
        controls.IconButton(icon, false)

        -- Icon tooltips always show (serve as labels)
        if tooltip then
            tooltips.ShowAlways(tooltip)
        end

        ImGui.SameLine()
        ImGui.PopStyleVar()
    end

    -- Calculate width: either column-based or fill remaining
    local width
    if cols then
        width = controls.ColWidth(cols, nil, hasIcon)
    else
        width = ImGui.GetContentRegionAvail()
    end

    ImGui.SetNextItemWidth(width)
    styles.PushOutlined()
    local newValue, changed = ImGui.SliderFloat("##" .. id, value, min, max, format)
    styles.PopOutlined()

    -- Right-click to reset to default
    if defaultValue ~= nil and ImGui.IsItemClicked(1) then
        newValue = defaultValue
        changed = true
    end

    return newValue, changed
end

--- Create an integer slider with icon on left
function controls.SliderInt(icon, id, value, min, max, format, cols, defaultValue, tooltip)
    format = format or "%d"

    local hasIcon = icon ~= nil and icon ~= ""
    if hasIcon then
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 4, frameCache.itemSpacingY)
        controls.IconButton(icon, false)

        -- Icon tooltips always show (serve as labels)
        if tooltip then
            tooltips.ShowAlways(tooltip)
        end

        ImGui.SameLine()
        ImGui.PopStyleVar()
    end

    local width
    if cols then
        width = controls.ColWidth(cols, nil, hasIcon)
    else
        width = ImGui.GetContentRegionAvail()
    end

    ImGui.SetNextItemWidth(width)
    styles.PushOutlined()
    local newValue, changed = ImGui.SliderInt("##" .. id, value, min, max, format)
    styles.PopOutlined()

    -- Right-click to reset to default
    if defaultValue ~= nil and ImGui.IsItemClicked(1) then
        newValue = defaultValue
        changed = true
    end

    return newValue, changed
end

--- Create a disabled slider appearance (greyed out)
function controls.SliderDisabled(icon, label)
    if icon then
        controls.IconButton(icon, false)
        ImGui.SameLine()
    end

    ImGui.SetNextItemWidth(ImGui.GetContentRegionAvail())
    styles.PushSliderDisabled()
    ImGui.BeginDisabled(true)
    ImGui.SliderFloat(label, 0, 0, 0, "%.2f", 0)
    ImGui.EndDisabled()
    styles.PopSliderDisabled()
end

--------------------------------------------------------------------------------
-- Checkboxes (standard ImGui styling - no custom colors)
--------------------------------------------------------------------------------

--- Create a standard checkbox with optional tooltip
function controls.Checkbox(label, value, defaultValue, tooltip, alwaysShowTooltip)
    if alwaysShowTooltip == nil then alwaysShowTooltip = false end

    local newValue, changed = ImGui.Checkbox(label, value)

    if tooltip then
        if alwaysShowTooltip then
            tooltips.ShowAlways(tooltip)
        else
            tooltips.Show(tooltip)
        end
    end

    -- Right-click to reset to default
    if defaultValue ~= nil and ImGui.IsItemClicked(1) then
        newValue = defaultValue
        changed = true
    end

    return newValue, changed
end

--- Create a checkbox with icon prefix
function controls.CheckboxWithIcon(icon, label, value, defaultValue, tooltip, alwaysShowTooltip)
    if alwaysShowTooltip == nil then alwaysShowTooltip = false end

    controls.IconButton(icon, false)

    if tooltip then
        if alwaysShowTooltip then
            tooltips.ShowAlways(tooltip)
        else
            tooltips.Show(tooltip)
        end
    end

    ImGui.SameLine()
    local newValue, changed = ImGui.Checkbox(label, value)

    -- Tooltip on checkbox too
    if tooltip then
        if alwaysShowTooltip then
            tooltips.ShowAlways(tooltip)
        else
            tooltips.Show(tooltip)
        end
    end

    -- Right-click to reset to default
    if defaultValue ~= nil and ImGui.IsItemClicked(1) then
        newValue = defaultValue
        changed = true
    end

    return newValue, changed
end

--------------------------------------------------------------------------------
-- Progress Bars
--------------------------------------------------------------------------------

--- Create a styled progress bar
function controls.ProgressBar(fraction, width, height, overlay, styleName)
    width = width or ImGui.GetContentRegionAvail()
    height = height or 0
    overlay = overlay or ""
    styleName = styleName or "default"

    if styleName == "danger" then
        styles.PushOutlinedDanger()
    elseif styleName == "success" then
        styles.PushOutlinedSuccess()
    else
        styles.PushOutlined()
    end

    ImGui.ProgressBar(fraction, width, height, overlay)

    if styleName == "danger" then
        styles.PopOutlinedDanger()
    elseif styleName == "success" then
        styles.PopOutlinedSuccess()
    else
        styles.PopOutlined()
    end
end

--------------------------------------------------------------------------------
-- Color Picker
--------------------------------------------------------------------------------

--- Create a color picker with icon on left
function controls.ColorEdit4(icon, id, color, label, defaultColor, tooltip)
    local hasIcon = icon ~= nil

    if hasIcon then
        controls.IconButton(icon, false)

        if tooltip then
            tooltips.ShowAlways(tooltip)
        end

        ImGui.SameLine()
    end

    ImGui.SetNextItemWidth(ImGui.GetContentRegionAvail())
    local newColor, changed = ImGui.ColorEdit4(label or ("##" .. id), color, ImGuiColorEditFlags.NoOptions)

    -- Right-click to reset to default
    if defaultColor and ImGui.IsItemClicked(1) then
        newColor = {defaultColor[1], defaultColor[2], defaultColor[3], defaultColor[4]}
        changed = true
    end

    return newColor, changed
end

--------------------------------------------------------------------------------
-- Text Display
--------------------------------------------------------------------------------

--- Display muted/grey text
function controls.TextMuted(text)
    styles.PushTextMuted()
    ImGui.Text(text)
    styles.PopTextMuted()
end

--- Display success/green text
function controls.TextSuccess(text)
    styles.PushTextSuccess()
    ImGui.Text(text)
    styles.PopTextSuccess()
end

--- Display danger/red text
function controls.TextDanger(text)
    styles.PushTextDanger()
    ImGui.Text(text)
    styles.PopTextDanger()
end

--- Display warning/yellow text
function controls.TextWarning(text)
    styles.PushTextWarning()
    ImGui.Text(text)
    styles.PopTextWarning()
end

--------------------------------------------------------------------------------
-- Combo/Dropdown with Icon
--------------------------------------------------------------------------------

--- Create a combo dropdown with icon on left
function controls.Combo(icon, id, currentIndex, items, cols, defaultIndex, tooltip)
    local hasIcon = icon ~= nil

    if hasIcon then
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 4, frameCache.itemSpacingY)
        controls.IconButton(icon, false)

        -- Icon tooltips always show (serve as labels)
        if tooltip then
            tooltips.ShowAlways(tooltip)
        end

        ImGui.SameLine()
        ImGui.PopStyleVar()
    end

    local width
    if cols then
        width = controls.ColWidth(cols, nil, hasIcon)
    else
        width = ImGui.GetContentRegionAvail()
    end

    ImGui.SetNextItemWidth(width)
    styles.PushOutlined()
    local newIndex, changed = ImGui.Combo("##" .. id, currentIndex, items, #items)
    styles.PopOutlined()

    -- Right-click to reset to default
    if defaultIndex ~= nil and ImGui.IsItemClicked(1) then
        newIndex = defaultIndex
        changed = true
    end

    return newIndex, changed
end

--------------------------------------------------------------------------------
-- Input Fields with Icon
--------------------------------------------------------------------------------

--- Create an input text field with icon on left
function controls.InputText(icon, id, text, maxLength, cols, tooltip, alwaysShowTooltip)
    maxLength = maxLength or 256
    if alwaysShowTooltip == nil then alwaysShowTooltip = false end
    local hasIcon = icon ~= nil

    if hasIcon then
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 4, frameCache.itemSpacingY)
        controls.IconButton(icon, false)

        if tooltip then
            if alwaysShowTooltip then
                tooltips.ShowAlways(tooltip)
            else
                tooltips.Show(tooltip)
            end
        end

        ImGui.SameLine()
        ImGui.PopStyleVar()
    end

    local width
    if cols then
        width = controls.ColWidth(cols, nil, hasIcon)
    else
        width = ImGui.GetContentRegionAvail()
    end

    ImGui.SetNextItemWidth(width)
    styles.PushOutlined()
    local newText, changed = ImGui.InputText("##" .. id, text, maxLength)
    styles.PopOutlined()

    return newText, changed
end

--- Create an input float field with icon on left
function controls.InputFloat(icon, id, value, step, stepFast, format, cols, tooltip, alwaysShowTooltip)
    step = step or 0.1
    stepFast = stepFast or 1.0
    format = format or "%.2f"
    if alwaysShowTooltip == nil then alwaysShowTooltip = false end
    local hasIcon = icon ~= nil

    if hasIcon then
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 4, frameCache.itemSpacingY)
        controls.IconButton(icon, false)

        if tooltip then
            if alwaysShowTooltip then
                tooltips.ShowAlways(tooltip)
            else
                tooltips.Show(tooltip)
            end
        end

        ImGui.SameLine()
        ImGui.PopStyleVar()
    end

    local width
    if cols then
        width = controls.ColWidth(cols, nil, hasIcon)
    else
        width = ImGui.GetContentRegionAvail()
    end

    ImGui.SetNextItemWidth(width)
    styles.PushOutlined()
    local newValue, changed = ImGui.InputFloat("##" .. id, value, step, stepFast, format)
    styles.PopOutlined()

    return newValue, changed
end

--- Create an input int field with icon on left
function controls.InputInt(icon, id, value, step, stepFast, cols, tooltip, alwaysShowTooltip)
    step = step or 1
    stepFast = stepFast or 10
    if alwaysShowTooltip == nil then alwaysShowTooltip = false end
    local hasIcon = icon ~= nil

    if hasIcon then
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 4, frameCache.itemSpacingY)
        controls.IconButton(icon, false)

        if tooltip then
            if alwaysShowTooltip then
                tooltips.ShowAlways(tooltip)
            else
                tooltips.Show(tooltip)
            end
        end

        ImGui.SameLine()
        ImGui.PopStyleVar()
    end

    local width
    if cols then
        width = controls.ColWidth(cols, nil, hasIcon)
    else
        width = ImGui.GetContentRegionAvail()
    end

    ImGui.SetNextItemWidth(width)
    styles.PushOutlined()
    local newValue, changed = ImGui.InputInt("##" .. id, value, step, stepFast)
    styles.PopOutlined()

    return newValue, changed
end

--------------------------------------------------------------------------------
-- Layout Helpers
--------------------------------------------------------------------------------

--- Create a separator with optional spacing
function controls.Separator(spacingBefore, spacingAfter)
    if spacingBefore then
        ImGui.Dummy(0, spacingBefore)
    end
    ImGui.Separator()
    if spacingAfter then
        ImGui.Dummy(0, spacingAfter)
    end
end

--- Create a labeled section header
function controls.SectionHeader(label, spacingBefore, spacingAfter)
    if spacingBefore then
        ImGui.Dummy(0, spacingBefore)
    end
    ImGui.Separator()
    ImGui.Text(label)
    if spacingAfter then
        ImGui.Dummy(0, spacingAfter)
    end
end

--------------------------------------------------------------------------------
-- Hold-to-Confirm Button
--------------------------------------------------------------------------------

-- State for hold buttons: [id] = { holding, startTime, holdDuration, progress, lastTime }
local holdStates = {}

--- Create a hold-to-confirm button with progress fill overlay
function controls.HoldButton(id, label, opts)
    -- Backward compatibility: detect old HoldButton(label, duration, styleName, width)
    if type(label) == "number" or label == nil then
        local oldLabel = id
        local oldDuration = label
        local oldStyle = type(opts) == "string" and opts or nil
        return controls.HoldButton(oldLabel, oldLabel, {
            duration = oldDuration,
            style = oldStyle,
        })
    end

    opts = opts or {}
    local duration = opts.duration or 2.0
    local styleName = opts.style or "danger"
    local width = opts.width or 0
    local progressDisplay = opts.progressDisplay or "overlay"
    local progressStyle = opts.progressStyle or "danger"

    -- Initialize state
    if not holdStates[id] then
        holdStates[id] = {
            holding = false,
            completed = false,
            startTime = 0,
            holdDuration = duration,
            progress = 0,
            lastTime = os.clock(),
            displayLabel = label .. "##hold_" .. id,
        }
    end
    local state = holdStates[id]
    state.holdDuration = duration
    local now = os.clock()
    local dt = now - state.lastTime
    state.lastTime = now

    local triggered = false

    -- Reset completed lock when mouse is fully released
    if state.completed and not ImGui.IsMouseDown(0) then
        state.completed = false
    end

    -- "replace" mode: show progress bar instead of button while held
    if progressDisplay == "replace" and state.holding then
        controls.ProgressBar(state.progress, width > 0 and width or nil, 0, "", progressStyle)
        if not ImGui.IsMouseDown(0) then
            state.holding = false
        elseif not state.completed then
            state.progress = math.min((now - state.startTime) / duration, 1.0)
            if state.progress >= 1.0 then
                state.progress = 0
                state.holding = false
                state.completed = true
                triggered = true
            end
        end
        return triggered
    end

    -- Draw the button
    local displayLabel = state.displayLabel
    styles.PushButton(styleName)
    ImGui.Button(displayLabel, width, 0)
    local isActive = ImGui.IsItemActive()
    styles.PopButton(styleName)

    if isActive and not state.holding and not state.completed then
        -- Start holding
        state.holding = true
        state.startTime = now
        state.progress = 0
    end

    if state.holding then
        if (isActive or ImGui.IsMouseDown(0)) and not state.completed then
            state.progress = math.min((now - state.startTime) / duration, 1.0)
            if state.progress >= 1.0 then
                state.progress = 0
                state.holding = false
                state.completed = true
                triggered = true
            end
        else
            -- Released before completion or already completed
            state.holding = false
        end
    end

    -- Decay progress when not holding
    if not state.holding and state.progress > 0 then
        state.progress = math.max(0, state.progress - dt * 4)
    end

    -- "overlay" mode: draw rect fill over button
    if progressDisplay == "overlay" and state.progress > 0 then
        local minX, minY = ImGui.GetItemRectMin()
        local maxX, maxY = ImGui.GetItemRectMax()
        local fillX = minX + (maxX - minX) * state.progress

        local drawList = ImGui.GetWindowDrawList()
        local overlayColor = ImGui.GetColorU32(1.0, 1.0, 1.0, 0.2)
        ImGui.ImDrawListAddRectFilled(drawList, minX, minY, fillX, maxY, overlayColor, 2.0)
    end
    -- "external" mode: no visual — other elements read via getHoldProgress()

    return triggered
end

--- Get the current hold progress for a button ID
function controls.getHoldProgress(id)
    local state = holdStates[id]
    if not state or not state.holding then return nil end
    return math.min((os.clock() - state.startTime) / state.holdDuration, 1.0)
end

--- Display a progress bar showing another button's hold progress
function controls.ShowHoldProgress(sourceId, width, progressStyle)
    local progress = controls.getHoldProgress(sourceId)
    if not progress then return false end

    width = width or ImGui.GetContentRegionAvail()
    progressStyle = progressStyle or "danger"
    controls.ProgressBar(progress, width, 0, "", progressStyle)
    return true
end

--- Compound action button: primary label + secondary icon with cross-element progress
function controls.ActionButton(id, label, opts)
    opts = opts or {}
    local onPrimary = opts.onPrimary
    local onSecondary = opts.onSecondary
    local secondaryIcon = opts.secondaryIcon or (IconGlyphs and IconGlyphs.TrashCanOutline or "X")
    local secondaryDuration = opts.secondaryDuration or 1.0
    local secondaryStyle = opts.secondaryStyle or "danger"
    local progressStyle = opts.progressStyle or "danger"
    local style = opts.style or "inactive"
    local isActive = opts.isActive
    local totalWidth = opts.width

    -- Calculate widths
    local secondaryWidth = 0
    if onSecondary then
        local iconWidth = ImGui.CalcTextSize(secondaryIcon)
        local framePadX = frameCache.framePaddingX * 2
        local spacing = frameCache.itemSpacingX
        secondaryWidth = iconWidth + framePadX + spacing
    end
    local mainWidth = (totalWidth or ImGui.GetContentRegionAvail()) - secondaryWidth

    local secondaryId = id .. "_secondary"
    local primaryClicked = false

    -- Primary button: show progress bar from secondary hold, or normal button
    if onSecondary and controls.ShowHoldProgress(secondaryId, mainWidth, progressStyle) then
        -- Progress bar is being shown in place of the primary button
    else
        local resolvedStyle = isActive and "active" or style
        styles.PushButton(resolvedStyle)
        primaryClicked = ImGui.Button(label, mainWidth, 0)
        styles.PopButton(resolvedStyle)
    end

    if primaryClicked and onPrimary then
        onPrimary()
    end

    -- Secondary button (hold to confirm)
    local secondaryTriggered = false
    if onSecondary then
        ImGui.SameLine()
        secondaryTriggered = controls.HoldButton(secondaryId, secondaryIcon, {
            duration = secondaryDuration,
            style = secondaryStyle,
            progressDisplay = "external",
        })
        if secondaryTriggered then
            onSecondary()
        end
    end

    return {
        primaryClicked = primaryClicked,
        secondaryTriggered = secondaryTriggered,
    }
end

--- Reset hold state for a specific button ID
function controls.resetHoldState(id)
    holdStates[id] = nil
end

--- Reset all hold states.
function controls.resetAllHoldStates()
    holdStates = {}
end

--------------------------------------------------------------------------------
-- Collapsing Section (animated)
--------------------------------------------------------------------------------

-- State for collapsible sections: [id] = { open, measuredHeight, animProgress }
local collapseStates = {}

-- Arrow icons (lazy-loaded)
local _arrowRight = nil
local _arrowDown = nil
local function ensureArrows()
    if _arrowRight then return end
    _arrowRight = IconGlyphs and IconGlyphs.ChevronRight or ">"
    _arrowDown = IconGlyphs and IconGlyphs.ChevronDown or "v"
end

--- Begin an animated collapsible section
function controls.CollapsingSection(label, id, defaultOpen)
    ensureArrows()

    id = id or label
    if defaultOpen == nil then defaultOpen = true end

    -- Initialize state
    if not collapseStates[id] then
        collapseStates[id] = {
            open = defaultOpen,
            measuredHeight = 0,
            animProgress = defaultOpen and 1.0 or 0.0,
            lastTime = os.clock(),
            childId = "##collapse_" .. id,
            label = label,
        }
    end
    local state = collapseStates[id]

    -- Draw header button
    local arrow = state.open and _arrowDown or _arrowRight
    local headerLabel = arrow .. "  " .. state.label

    styles.PushButtonTransparent()
    if ImGui.Button(headerLabel, ImGui.GetContentRegionAvail(), 0) then
        state.open = not state.open
    end
    styles.PopButtonTransparent()

    -- Animate progress toward target
    local target = state.open and 1.0 or 0.0
    local speed = 8.0
    local now = os.clock()
    local dt = now - state.lastTime
    state.lastTime = now
    if state.animProgress < target then
        state.animProgress = math.min(target, state.animProgress + speed * dt)
    elseif state.animProgress > target then
        state.animProgress = math.max(target, state.animProgress - speed * dt)
    end

    -- If fully closed and animation complete, skip content entirely
    if state.animProgress <= 0 then
        return false
    end

    -- Begin content region with animated height
    if state.measuredHeight > 0 and state.animProgress < 1.0 then
        local height = state.measuredHeight * state.animProgress
        ImGui.BeginChild(state.childId, 0, height, false, ImGuiWindowFlags.NoScrollbar)
    else
        ImGui.BeginChild(state.childId, 0, 0, false,
            ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.AlwaysAutoResize)
    end

    return true
end

--- End a collapsing section (must be called after CollapsingSection returns true)
function controls.EndCollapsingSection(id)
    id = id or ""
    local state = collapseStates[id]

    -- Measure content height for animation
    if state then
        local _, cursorY = ImGui.GetCursorPos()
        if cursorY > 0 then
            state.measuredHeight = cursorY
        end
    end

    ImGui.EndChild()
end

--------------------------------------------------------------------------------
-- Fill-Available-Space Child Region
--------------------------------------------------------------------------------

--- Begin a child region that fills remaining vertical space in the window
function controls.BeginFillChild(id, opts)
    opts = opts or {}
    local footerHeight = opts.footerHeight or 0
    local border = opts.border or false
    local extraFlags = opts.flags or 0
    local bg = opts.bg

    local childId = id
    if not id:find("^##") then
        childId = "##" .. id
    end

    if bg then
        ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(bg[1], bg[2], bg[3], bg[4] or 1.0))
    end

    local windowHeight = ImGui.GetWindowHeight()
    local _, cursorY = ImGui.GetCursorPos()
    local paddingY = frameCache.windowPaddingY
    local childHeight = math.max(windowHeight - cursorY - paddingY - footerHeight, 1)

    local flags = ImGuiWindowFlags.AlwaysUseWindowPadding + extraFlags
    local width = ImGui.GetContentRegionAvail()

    return ImGui.BeginChild(childId, width, childHeight, border, flags)
end

--- End a fill child region
function controls.EndFillChild(opts)
    ImGui.EndChild()
    opts = opts or {}
    if opts.bg then
        ImGui.PopStyleColor()
    end
end

--------------------------------------------------------------------------------
-- Layout: Row (horizontal child windows)
--------------------------------------------------------------------------------

--- Horizontal row of child windows that fills available width
function controls.Row(id, defs, opts)
    if not defs or #defs == 0 then return end
    opts = opts or {}
    local gap = opts.gap or frameCache.itemSpacingX
    local rowHeight = opts.height or 0

    -- Phase 1: calculate widths
    local availW = ImGui.GetContentRegionAvail()
    local totalGap = gap * (#defs - 1)
    local fixedW = 0
    local totalFlex = 0

    for _, def in ipairs(defs) do
        if def.width then
            fixedW = fixedW + def.width
        elseif def.cols then
            def._calcWidth = controls.ColWidth(def.cols, gap)
            fixedW = fixedW + def._calcWidth
        else
            totalFlex = totalFlex + (def.flex or 1)
        end
    end

    local remainingW = math.max(availW - totalGap - fixedW, 0)

    -- Phase 2: render children
    for i, def in ipairs(defs) do
        local childW
        if def.width then
            childW = def.width
        elseif def._calcWidth then
            childW = def._calcWidth
            def._calcWidth = nil
        else
            childW = totalFlex > 0
                and math.floor(remainingW * (def.flex or 1) / totalFlex)
                or 0
        end

        if def.bg then
            ImGui.PushStyleColor(ImGuiCol.ChildBg, def.bg[1], def.bg[2], def.bg[3], def.bg[4] or 1.0)
        end

        local childId = "##row_" .. id .. "_" .. i
        ImGui.BeginChild(childId, childW, rowHeight, def.border or false, def.flags or 0)
        if def.content then def.content() end
        ImGui.EndChild()

        if def.bg then ImGui.PopStyleColor() end

        if i < #defs then
            ImGui.SameLine()
        end
    end
end

--------------------------------------------------------------------------------
-- Layout: Column (vertical child windows)
--------------------------------------------------------------------------------

--- Vertical column of child windows that fills available height
function controls.Column(id, defs, opts)
    if not defs or #defs == 0 then return end
    opts = opts or {}

    -- Phase 1: calculate heights
    -- ImGui adds itemSpacingY between each child automatically
    local spacingY = frameCache.itemSpacingY
    local windowH = ImGui.GetWindowHeight()
    local _, cursorY = ImGui.GetCursorPos()
    local paddingY = frameCache.windowPaddingY
    local availH = math.max(windowH - cursorY - paddingY, 1)
    local implicitGap = spacingY * (#defs - 1)
    local fixedH = 0
    local totalFlex = 0

    for _, def in ipairs(defs) do
        if def.height then
            fixedH = fixedH + def.height
        else
            totalFlex = totalFlex + (def.flex or 1)
        end
    end

    local remainingH = math.max(availH - implicitGap - fixedH, 0)
    local availW = ImGui.GetContentRegionAvail()

    -- Phase 2: render children
    for i, def in ipairs(defs) do
        local childH
        if def.height then
            childH = def.height
        else
            childH = totalFlex > 0
                and math.floor(remainingH * (def.flex or 1) / totalFlex)
                or 0
        end

        if def.bg then
            ImGui.PushStyleColor(ImGuiCol.ChildBg, def.bg[1], def.bg[2], def.bg[3], def.bg[4] or 1.0)
        end

        local childId = "##col_" .. id .. "_" .. i
        ImGui.BeginChild(childId, availW, childH, def.border or false, def.flags or 0)
        if def.content then def.content() end
        ImGui.EndChild()

        if def.bg then ImGui.PopStyleColor() end
    end
end

return controls
