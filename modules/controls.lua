------------------------------------------------------
-- WindowUtils - Controls Module
-- Universal ImGui control helpers for CET mods
------------------------------------------------------

local styles = require("modules/styles")
local tooltips = require("modules/tooltips")
local utils = require("modules/utils")

local controls = {}

--------------------------------------------------------------------------------
-- Per-frame style cache (call controls.cacheFrameState() once per onDraw)
--------------------------------------------------------------------------------

local frameCache = {}

---@return nil
function controls.cacheFrameState()
    local style = ImGui.GetStyle()
    frameCache.itemSpacingX = style.ItemSpacing.x
    frameCache.itemSpacingY = style.ItemSpacing.y
    frameCache.framePaddingX = style.FramePadding.x
    frameCache.windowPaddingY = style.WindowPadding.y
    frameCache.frameHeight = ImGui.GetFrameHeight()
    frameCache.textLineHeight = ImGui.GetTextLineHeightWithSpacing()
end

---@return table frameCache Cached style values for the current frame
function controls.getFrameCache()
    return frameCache
end

--------------------------------------------------------------------------------
-- Grid System (Bootstrap-style columns)
--------------------------------------------------------------------------------

-- Approximate icon button width (glyph + padding)
local ICON_WIDTH = 24

--- Calculate width for a column ratio (1-12 out of 12 columns)
---@param cols? number Column span (1-12, default 12)
---@param gap? number Gap between columns in pixels (default itemSpacingX)
---@param hasIcon? boolean Whether an icon occupies space to the left
---@return number width Calculated pixel width (minimum 20)
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
---@param offset? number Pixels to subtract from remaining width (default 0)
---@return number width Remaining width in pixels
function controls.RemainingWidth(offset)
    offset = offset or 0
    return ImGui.GetContentRegionAvail() - offset
end

--------------------------------------------------------------------------------
-- Icon Button (Invisible button with icon for labels)
--------------------------------------------------------------------------------

--- Create an invisible button with an icon (for use as slider/input labels)
---@param icon string Icon glyph string or IconGlyphs key
---@param clickable? boolean If true, returns click state (default false)
---@return boolean clicked True if clickable and the button was clicked
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
---@param label string Button label text
---@param styleName? string Style name from styles module (default "inactive")
---@param width? number Button width in pixels (0=auto, negative=fill available)
---@param height? number Button height in pixels (default 0)
---@return boolean clicked True if the button was clicked
function controls.Button(label, styleName, width, height)
    styleName = styleName or "inactive"
    width = width or 0
    height = height or 0
    if width < 0 then width = ImGui.GetContentRegionAvail() end

    styles.PushButton(styleName)
    local clicked = ImGui.Button(label, width, height)
    styles.PopButton(styleName)

    return clicked
end

--- Create a toggle button that switches between active/inactive styles
---@param label string Button label text
---@param isActive boolean Current toggle state
---@param width? number Button width in pixels (default 0)
---@param height? number Button height in pixels (default 0)
---@return boolean clicked True if the button was clicked
function controls.ToggleButton(label, isActive, width, height)
    local styleName = isActive and "active" or "inactive"
    return controls.Button(label, styleName, width, height)
end

--- Create a full-width button (fills available width)
---@param label string Button label text
---@param styleName? string Style name from styles module (default "inactive")
---@return boolean clicked True if the button was clicked
function controls.FullWidthButton(label, styleName)
    return controls.Button(label, styleName, ImGui.GetContentRegionAvail())
end

--- Create a disabled button that cannot be clicked
---@param label string Button label text
---@param width? number Button width in pixels (default 0)
---@param height? number Button height in pixels (default 0)
---@return nil
function controls.DisabledButton(label, width, height)
    width = width or 0
    height = height or 0

    styles.PushButtonDisabled()
    ImGui.Button(label, width, height)
    styles.PopButtonDisabled()
end

--------------------------------------------------------------------------------
-- Helpers: icon prefix + width calculation (shared by sliders, inputs, combo)
--------------------------------------------------------------------------------

local resolveIcon = utils.resolveIcon

local function iconPrefix(icon, tooltip, alwaysShow)
    icon = resolveIcon(icon)
    if not icon then return false end
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 4, frameCache.itemSpacingY)
    controls.IconButton(icon, false)
    if tooltip then
        if alwaysShow then tooltips.ShowAlways(tooltip)
        else tooltips.Show(tooltip) end
    end
    ImGui.SameLine()
    ImGui.PopStyleVar()
    return true
end

local function calcControlWidth(cols, hasIcon)
    if cols then return controls.ColWidth(cols, nil, hasIcon) end
    return ImGui.GetContentRegionAvail()
end

local truncateText = utils.truncateText

--- Create a button that adapts content based on available width.
--- Normal: full text. Narrow: truncated with "...". Icon mode: icon only.
--- opts.minChars: minimum visible characters before switching to icon (default 3)
--- opts.iconThreshold: explicit pixel override for icon switch threshold
---@param label string Full button label text
---@param icon string|nil Icon glyph or IconGlyphs key for narrow display
---@param opts? table {style?, width?, height?, minChars?, iconThreshold?, iconFallback?, tooltip?}
---@return boolean clicked True if the button was clicked
function controls.DynamicButton(label, icon, opts)
    opts = opts or {}
    local iconStr = resolveIcon(icon) or opts.iconFallback or "?"
    local styleName = opts.style or "inactive"
    local width = opts.width or ImGui.GetContentRegionAvail()
    local height = opts.height or 0
    if width < 0 then width = ImGui.GetContentRegionAvail() end

    local padX = (frameCache.framePaddingX or 6) * 2
    local innerWidth = width - padX

    -- Smart threshold: switch to icon if fewer than minChars would show
    local minChars = opts.minChars or 3
    local iconThreshold = opts.iconThreshold
    if not iconThreshold then
        local charW = ImGui.CalcTextSize("M")
        local ellipsisW = ImGui.CalcTextSize("...")
        iconThreshold = (charW * minChars) + ellipsisW
    end

    local displayLabel
    local wasTruncated = false
    local isIconMode = false

    if innerWidth <= iconThreshold then
        displayLabel = iconStr
        isIconMode = true
    else
        displayLabel, wasTruncated = truncateText(label, innerWidth)
    end

    styles.PushButton(styleName)
    local clicked = ImGui.Button(displayLabel, width, height)
    styles.PopButton(styleName)

    if (wasTruncated or isIconMode) and ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text(opts.tooltip or label)
        ImGui.EndTooltip()
    end

    return clicked
end

--------------------------------------------------------------------------------
-- Sliders with Icon (Shift-style: icon on left, slider fills remaining width)
--------------------------------------------------------------------------------

--- Create a float slider (icon, id, value, min, max, opts)
---@param icon string|nil Icon glyph or IconGlyphs key (nil to hide)
---@param id string Unique ImGui ID suffix
---@param value number Current slider value
---@param min number Minimum value
---@param max number Maximum value
---@param opts? table {format?, tooltip?, cols?, default?}
---@return number newValue Updated value
---@return boolean changed True if the value was modified
function controls.SliderFloat(icon, id, value, min, max, opts)
    opts = opts or {}
    local format = opts.format or "%.2f"
    local hasIcon = iconPrefix(icon, opts.tooltip, true)
    ImGui.SetNextItemWidth(calcControlWidth(opts.cols, hasIcon))
    styles.PushOutlined()
    local newValue, changed = ImGui.SliderFloat("##" .. id, value, min, max, format)
    styles.PopOutlined()
    if opts.default ~= nil and ImGui.IsItemClicked(1) then
        newValue = opts.default
        changed = true
    end
    return newValue, changed
end

--- Create an integer slider (icon, id, value, min, max, opts)
---@param icon string|nil Icon glyph or IconGlyphs key (nil to hide)
---@param id string Unique ImGui ID suffix
---@param value integer Current slider value
---@param min integer Minimum value
---@param max integer Maximum value
---@param opts? table {format?, tooltip?, cols?, default?}
---@return integer newValue Updated value
---@return boolean changed True if the value was modified
function controls.SliderInt(icon, id, value, min, max, opts)
    opts = opts or {}
    local format = opts.format or "%d"
    local hasIcon = iconPrefix(icon, opts.tooltip, true)
    ImGui.SetNextItemWidth(calcControlWidth(opts.cols, hasIcon))
    styles.PushOutlined()
    local newValue, changed = ImGui.SliderInt("##" .. id, value, min, max, format)
    styles.PopOutlined()
    if opts.default ~= nil and ImGui.IsItemClicked(1) then
        newValue = opts.default
        changed = true
    end
    return newValue, changed
end

--- Create a disabled slider appearance (greyed out)
---@param icon string|nil Icon glyph or IconGlyphs key (nil to hide)
---@param label string Slider display label
---@return nil
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

--- Create a checkbox (opts: icon, default, tooltip, alwaysShowTooltip)
---@param label string Checkbox label text
---@param value boolean Current checked state
---@param opts? table {icon?, default?, tooltip?, alwaysShowTooltip?}
---@return boolean newValue Updated checked state
---@return boolean changed True if the value was toggled
function controls.Checkbox(label, value, opts)
    opts = opts or {}
    local hasIcon = false
    if opts.icon then
        hasIcon = true
        iconPrefix(opts.icon, opts.tooltip, opts.alwaysShowTooltip)
    end

    local newValue, changed = ImGui.Checkbox(label, value)

    if not hasIcon and opts.tooltip then
        if opts.alwaysShowTooltip then
            tooltips.ShowAlways(opts.tooltip)
        else
            tooltips.Show(opts.tooltip)
        end
    end

    if opts.default ~= nil and ImGui.IsItemClicked(1) then
        newValue = opts.default
        changed = true
    end

    return newValue, changed
end

--------------------------------------------------------------------------------
-- Progress Bars
--------------------------------------------------------------------------------

--- Create a styled progress bar
---@param fraction number Progress value between 0.0 and 1.0
---@param width? number Bar width in pixels (default fills available)
---@param height? number Bar height in pixels (default 0)
---@param overlay? string Text overlay on the bar (default "")
---@param styleName? string|table Style name ("default"|"danger"|"success") or custom color table
---@return nil
function controls.ProgressBar(fraction, width, height, overlay, styleName)
    width = width or ImGui.GetContentRegionAvail()
    height = height or 0
    overlay = overlay or ""

    if type(styleName) == "table" then
        local s = styleName
        if s.fill then
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, s.fill[1], s.fill[2], s.fill[3], s.fill[4])
        end
        ImGui.PushStyleColor(ImGuiCol.FrameBg, s.frameBg[1], s.frameBg[2], s.frameBg[3], s.frameBg[4])
        ImGui.PushStyleColor(ImGuiCol.Border, s.border[1], s.border[2], s.border[3], s.border[4])
        ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, s.borderSize or 2.0)
        ImGui.ProgressBar(fraction, width, height, overlay)
        ImGui.PopStyleVar(1)
        ImGui.PopStyleColor(s.fill and 3 or 2)
    else
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
end

--------------------------------------------------------------------------------
-- Color Picker
--------------------------------------------------------------------------------

--- Create a color picker (icon, id, color, opts)
---@param icon string|nil Icon glyph or IconGlyphs key (nil to hide)
---@param id string Unique ImGui ID suffix
---@param color table RGBA color array {r, g, b, a}
---@param opts? table {tooltip?, label?, default?}
---@return table newColor Updated RGBA color array
---@return boolean changed True if the color was modified
function controls.ColorEdit4(icon, id, color, opts)
    opts = opts or {}
    iconPrefix(icon, opts.tooltip, true)
    if opts.label then
        ImGui.Text(opts.label)
        ImGui.SameLine()
    end
    ImGui.SetNextItemWidth(ImGui.GetContentRegionAvail())
    local newColor, changed = ImGui.ColorEdit4("##" .. id, color, ImGuiColorEditFlags.NoOptions)
    if opts.default and ImGui.IsItemClicked(1) then
        newColor = {opts.default[1], opts.default[2], opts.default[3], opts.default[4]}
        changed = true
    end
    return newColor, changed
end

--------------------------------------------------------------------------------
-- Text Display
--------------------------------------------------------------------------------

--- Display muted/grey text
---@param text string Text to display
---@return nil
function controls.TextMuted(text)
    styles.PushTextMuted()
    ImGui.Text(text)
    styles.PopTextMuted()
end

--- Display success/green text
---@param text string Text to display
---@return nil
function controls.TextSuccess(text)
    styles.PushTextSuccess()
    ImGui.Text(text)
    styles.PopTextSuccess()
end

--- Display danger/red text
---@param text string Text to display
---@return nil
function controls.TextDanger(text)
    styles.PushTextDanger()
    ImGui.Text(text)
    styles.PopTextDanger()
end

--- Display warning/yellow text
---@param text string Text to display
---@return nil
function controls.TextWarning(text)
    styles.PushTextWarning()
    ImGui.Text(text)
    styles.PopTextWarning()
end

--------------------------------------------------------------------------------
-- Combo/Dropdown with Icon
--------------------------------------------------------------------------------

--- Create a combo dropdown (icon, id, currentIndex, items, opts)
---@param icon string|nil Icon glyph or IconGlyphs key (nil to hide)
---@param id string Unique ImGui ID suffix
---@param currentIndex integer Zero-based selected index
---@param items table Array of string labels
---@param opts? table {tooltip?, cols?, default?}
---@return integer newIndex Updated selected index
---@return boolean changed True if the selection changed
function controls.Combo(icon, id, currentIndex, items, opts)
    opts = opts or {}
    local hasIcon = iconPrefix(icon, opts.tooltip, true)
    ImGui.SetNextItemWidth(calcControlWidth(opts.cols, hasIcon))
    styles.PushOutlined()
    local newIndex, changed = ImGui.Combo("##" .. id, currentIndex, items, #items)
    styles.PopOutlined()
    if opts.default ~= nil and ImGui.IsItemClicked(1) then
        newIndex = opts.default
        changed = true
    end
    return newIndex, changed
end

--------------------------------------------------------------------------------
-- Input Fields with Icon
--------------------------------------------------------------------------------

--- Create an input text field (icon, id, text, opts)
---@param icon string|nil Icon glyph or IconGlyphs key (nil to hide)
---@param id string Unique ImGui ID suffix
---@param text string Current text value
---@param opts? table {maxLength?, tooltip?, alwaysShowTooltip?, cols?}
---@return string newText Updated text value
---@return boolean changed True if the text was modified
function controls.InputText(icon, id, text, opts)
    opts = opts or {}
    local maxLength = opts.maxLength or 256
    local hasIcon = iconPrefix(icon, opts.tooltip, opts.alwaysShowTooltip)
    ImGui.SetNextItemWidth(calcControlWidth(opts.cols, hasIcon))
    styles.PushOutlined()
    local newText, changed = ImGui.InputText("##" .. id, text, maxLength)
    styles.PopOutlined()
    return newText, changed
end

--- Create an input float field (icon, id, value, opts)
---@param icon string|nil Icon glyph or IconGlyphs key (nil to hide)
---@param id string Unique ImGui ID suffix
---@param value number Current float value
---@param opts? table {step?, stepFast?, format?, tooltip?, alwaysShowTooltip?, cols?}
---@return number newValue Updated float value
---@return boolean changed True if the value was modified
function controls.InputFloat(icon, id, value, opts)
    opts = opts or {}
    local step = opts.step or 0.1
    local stepFast = opts.stepFast or 1.0
    local format = opts.format or "%.2f"
    local hasIcon = iconPrefix(icon, opts.tooltip, opts.alwaysShowTooltip)
    ImGui.SetNextItemWidth(calcControlWidth(opts.cols, hasIcon))
    styles.PushOutlined()
    local newValue, changed = ImGui.InputFloat("##" .. id, value, step, stepFast, format)
    styles.PopOutlined()
    return newValue, changed
end

--- Create an input int field (icon, id, value, opts)
---@param icon string|nil Icon glyph or IconGlyphs key (nil to hide)
---@param id string Unique ImGui ID suffix
---@param value integer Current integer value
---@param opts? table {step?, stepFast?, tooltip?, alwaysShowTooltip?, cols?}
---@return integer newValue Updated integer value
---@return boolean changed True if the value was modified
function controls.InputInt(icon, id, value, opts)
    opts = opts or {}
    local step = opts.step or 1
    local stepFast = opts.stepFast or 10
    local hasIcon = iconPrefix(icon, opts.tooltip, opts.alwaysShowTooltip)
    ImGui.SetNextItemWidth(calcControlWidth(opts.cols, hasIcon))
    styles.PushOutlined()
    local newValue, changed = ImGui.InputInt("##" .. id, value, step, stepFast)
    styles.PopOutlined()
    return newValue, changed
end

--------------------------------------------------------------------------------
-- Layout Helpers
--------------------------------------------------------------------------------

--- Create a separator with optional spacing
---@param spacingBefore? number Vertical spacing in pixels before the separator
---@param spacingAfter? number Vertical spacing in pixels after the separator
---@return nil
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
---@param label string Section title text
---@param spacingBefore? number Vertical spacing in pixels before the separator
---@param spacingAfter? number Vertical spacing in pixels after the label
---@return nil
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
local HOLD_OVERLAY_COLOR = nil

--- Create a hold-to-confirm button with progress fill overlay
---@param id string Unique button ID (also used as label in legacy mode)
---@param label string Button label text
---@param opts? table {duration?, style?, width?, progressDisplay?, progressStyle?, disabled?, tooltip?, overlayColor?, onClick?, onHold?}
---@return boolean triggered True if the hold completed
---@return boolean clicked True if released before hold completed
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
    if width < 0 then width = ImGui.GetContentRegionAvail() end
    local progressDisplay = opts.progressDisplay or "overlay"
    local progressStyle = opts.progressStyle or "danger"
    local isDisabled = opts.disabled or false

    if isDisabled then ImGui.BeginDisabled(true) end

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
    local clicked = false

    -- Reset completed lock when mouse is fully released
    if state.completed and not ImGui.IsMouseDown(0) then
        state.completed = false
    end

    -- "replace" mode: show progress bar instead of button while held
    if progressDisplay == "replace" and state.holding then
        controls.ProgressBar(state.progress, width > 0 and width or nil, 0, "", progressStyle)
        if not ImGui.IsMouseDown(0) then
            clicked = state.holding
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
        if isDisabled then ImGui.EndDisabled() end
        if opts.tooltip then tooltips.Show(opts.tooltip) end
        if triggered and opts.onHold then opts.onHold() end
        if clicked and opts.onClick then opts.onClick() end
        return triggered, clicked
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
            -- Released before completion
            state.holding = false
            clicked = true
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
        local color
        if opts.overlayColor then
            local oc = opts.overlayColor
            color = ImGui.GetColorU32(oc[1], oc[2], oc[3], oc[4])
        else
            if not HOLD_OVERLAY_COLOR then
                HOLD_OVERLAY_COLOR = ImGui.GetColorU32(0.16, 0.16, 0.16, 0.31)
            end
            color = HOLD_OVERLAY_COLOR
        end
        ImGui.ImDrawListAddRectFilled(drawList, minX, minY, fillX, maxY, color, 2.0)
    end
    -- "external" mode: no visual — other elements read via getHoldProgress()

    if isDisabled then ImGui.EndDisabled() end
    if opts.tooltip then tooltips.Show(opts.tooltip) end

    -- Fire callbacks
    if triggered and opts.onHold then opts.onHold() end
    if clicked and opts.onClick then opts.onClick() end

    return triggered, clicked
end

--- Get the current hold progress for a button ID
---@param id string Button ID to query
---@return number|nil progress Hold progress 0.0-1.0, or nil if not holding
function controls.getHoldProgress(id)
    local state = holdStates[id]
    if not state or not state.holding then return nil end
    return math.min((os.clock() - state.startTime) / state.holdDuration, 1.0)
end

--- Display a progress bar showing another button's hold progress
---@param sourceId string Button ID whose hold progress to display
---@param width? number Bar width in pixels (default fills available)
---@param progressStyle? string Style name for the progress bar (default "danger")
---@return boolean shown True if a progress bar was rendered
function controls.ShowHoldProgress(sourceId, width, progressStyle)
    local progress = controls.getHoldProgress(sourceId)
    if not progress then return false end

    width = width or ImGui.GetContentRegionAvail()
    progressStyle = progressStyle or "danger"
    controls.ProgressBar(progress, width, 0, "", progressStyle)
    return true
end

--- Compound action button: primary label + secondary icon with cross-element progress
---@param id string Unique button group ID
---@param label string Primary button label text
---@param opts? table {onPrimary?, onSecondary?, secondaryIcon?, secondaryDuration?, secondaryStyle?, progressStyle?, style?, isActive?, width?}
---@return table result {primaryClicked: boolean, secondaryTriggered: boolean}
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
---@param id string Button ID to reset
---@return nil
function controls.resetHoldState(id)
    holdStates[id] = nil
end

--- Reset all hold states.
---@return nil
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
---@param label string Section header text
---@param id? string Unique section ID (defaults to label)
---@param defaultOpen? boolean Initial open state (default true)
---@return boolean isOpen True if the section content should be rendered (call EndCollapsingSection after)
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
---@param id? string Section ID matching the CollapsingSection call
---@return nil
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
---@param id string Unique child ID (## prefix added automatically if missing)
---@param opts? table {footerHeight?, border?, flags?, bg?}
---@return boolean visible True if the child region is visible
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

    local width, contentAvailH = ImGui.GetContentRegionAvail()
    -- Subtract footer + item spacing between child and footer (if any)
    local spacingBeforeFooter = footerHeight > 0 and ImGui.GetStyle().ItemSpacing.y or 0
    local childHeight = math.max(contentAvailH - footerHeight - spacingBeforeFooter, 1)

    local flags = ImGuiWindowFlags.AlwaysUseWindowPadding + extraFlags

    return ImGui.BeginChild(childId, width, childHeight, border, flags)
end

--- End a fill child region
---@param opts? table {bg?} Must match the opts.bg passed to BeginFillChild to pop the color
---@return nil
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
---@param id string Unique row ID prefix
---@param defs table Array of column defs: {width?, cols?, flex?, bg?, border?, flags?, content?}
---@param opts? table {gap?, height?}
---@return nil
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

    local calcWidths = {}
    for i, def in ipairs(defs) do
        if def.width then
            fixedW = fixedW + def.width
        elseif def.cols then
            calcWidths[i] = controls.ColWidth(def.cols, gap)
            fixedW = fixedW + calcWidths[i]
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
        elseif calcWidths[i] then
            childW = calcWidths[i]
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

-- Auto-size cache for Column: [columnId] = { [childIndex] = measuredHeight }
local columnAutoCache = {}

--- Vertical column of child windows that fills available height.
--- Children can be flex (fill proportional space), fixed height, or auto-sized.
---@param id string Unique column ID prefix
---@param defs table Array of row defs: {flex?, height?, auto?, bg?, border?, flags?, content?}
---@param opts? table {gap?} gap = spacing in pixels between children (default ItemSpacing.y * 2)
---@return nil
function controls.Column(id, defs, opts)
    if not defs or #defs == 0 then return end
    opts = opts or {}

    -- Phase 1: calculate heights (cancel spacing between children, matching splitter pattern)
    local spacingY = ImGui.GetStyle().ItemSpacing.y
    local gap = opts.gap or spacingY * 2
    local availW, availH = ImGui.GetContentRegionAvail()
    availH = math.max(availH, 1)
    local totalGap = gap * math.max(#defs - 1, 0)
    local fixedH = 0
    local totalFlex = 0

    local autoCache = columnAutoCache[id]
    if not autoCache then
        autoCache = {}
        columnAutoCache[id] = autoCache
    end

    for i, def in ipairs(defs) do
        if def.auto then
            fixedH = fixedH + (autoCache[i] or 0)
        elseif def.height then
            fixedH = fixedH + def.height
        else
            totalFlex = totalFlex + (def.flex or 1)
        end
    end

    local remainingH = math.max(availH - fixedH - totalGap, 0)

    -- Phase 2: render children, cancelling implicit item spacing and applying gap
    for i, def in ipairs(defs) do
        if i > 1 then
            ImGui.SetCursorPosY(ImGui.GetCursorPosY() - spacingY + gap)
        end

        if def.auto then
            -- Auto-sized: render inline (no child window), measure content height
            local _, startY = ImGui.GetCursorPos()
            if def.content then def.content() end
            local _, endY = ImGui.GetCursorPos()
            autoCache[i] = math.max(endY - startY - spacingY, 0)
        else
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
            local childFlags = (def.flags or 0)
            if def.height then
                childFlags = childFlags + ImGuiWindowFlags.NoScrollbar
            end
            ImGui.BeginChild(childId, availW, childH, def.border or false, childFlags)
            if def.content then def.content() end
            ImGui.EndChild()

            if def.bg then ImGui.PopStyleColor() end
        end
    end
end

--------------------------------------------------------------------------------
-- Panel (child window with default styling)
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- ButtonRow (two-tier width: auto-sized icons + weighted text)
--------------------------------------------------------------------------------

--- Render a row of buttons with automatic width distribution.
--- Icon-only buttons (def.icon, no def.label) auto-size. Text buttons share remaining space by weight.
---@param defs table Array of button defs: {label?, icon?, style?, weight?, width?, height?, disabled?, tooltip?, onClick?, onHold?, holdDuration?, progressFrom?, progressStyle?, progressDisplay?, id?}
---@param opts? table {gap?}
---@return nil
function controls.ButtonRow(defs, opts)
    if not defs or #defs == 0 then return end
    opts = opts or {}
    local gap = opts.gap or frameCache.itemSpacingX
    local availW = ImGui.GetContentRegionAvail()

    -- Phase 1: measure fixed-width buttons, sum flex weights
    local fixedW = gap * (#defs - 1)
    local totalWeight = 0
    local measured = {}

    for i, def in ipairs(defs) do
        if def.width then
            measured[i] = def.width
            fixedW = fixedW + def.width
        elseif def.icon and not def.label and not def.weight then
            local icon = resolveIcon(def.icon) or def.icon
            measured[i] = ImGui.CalcTextSize(icon) + frameCache.framePaddingX * 2
            fixedW = fixedW + measured[i]
        else
            totalWeight = totalWeight + (def.weight or 1)
        end
    end

    local remainingW = math.max(availW - fixedW, 0)

    -- Phase 2: render
    for i, def in ipairs(defs) do
        local w = measured[i] or math.floor(remainingW * (def.weight or 1) / totalWeight)
        local icon = def.icon and resolveIcon(def.icon)
        local displayLabel = icon or def.label or def[1]
        local style = def.style or def[2] or "inactive"

        if def.disabled then ImGui.BeginDisabled(true) end

        -- Cross-element progress: show progress bar instead of button when source is held
        local showedProgress = false
        if def.progressFrom then
            local progress = controls.getHoldProgress(def.progressFrom)
            if progress then
                controls.ProgressBar(progress, w, 0, "", def.progressStyle or "danger")
                showedProgress = true
            end
        end

        if not showedProgress then
            if def.onHold then
                local held, clicked = controls.HoldButton(def.id or ("btnrow_" .. i), displayLabel, {
                    duration = def.holdDuration or 2.0, style = style, width = w,
                    warningMessage = def.warningMessage,
                    progressDisplay = def.progressDisplay,
                })
                if held and def.onHold then def.onHold() end
                if clicked and def.onClick then def.onClick() end
            else
                local clicked = controls.Button(displayLabel, style, w, def.height or 0)
                if clicked and def.onClick then def.onClick() end
            end
        end

        if def.tooltip then tooltips.Show(def.tooltip) end
        if def.disabled then ImGui.EndDisabled() end
        if i < #defs then ImGui.SameLine() end
    end
end

--------------------------------------------------------------------------------
-- Bound Controls API
--------------------------------------------------------------------------------

--- Create a bound context that auto-reads, auto-writes, auto-resets, and auto-saves.
--- Usage: local c = controls.bind(data, defaults, onSave, { idPrefix = "prefix_" })
---        c:SliderFloat(icon, key, min, max, opts)  -- reads data[key], resets to defaults[key]
--- idPrefix is prepended to key for the ImGui ID but the raw key is used for data/defaults lookup.
---@param data table Data table to read/write values from
---@param defaults? table Default values table for right-click reset
---@param onSave? function Callback invoked after any value change
---@param bindOpts? table {idPrefix?: string}
---@return table ctx Bound context with SliderFloat, SliderInt, Checkbox, ColorEdit4, Combo, InputText, InputFloat, InputInt, ToggleButtonRow methods
function controls.bind(data, defaults, onSave, bindOpts)
    local ctx = {}
    local idPrefix = bindOpts and bindOpts.idPrefix or ""

    function ctx:SliderFloat(icon, key, min, max, opts)
        opts = opts or {}
        local t = opts.transform
        if opts.percent then
            local pct = (data[key] - min) / (max - min) * 100
            opts.format = string.format("%.0f%%%%", pct)
        end
        if defaults and defaults[key] ~= nil and opts.default == nil then
            opts.default = t and t.read(defaults[key]) or defaults[key]
        end
        local displayValue = t and t.read(data[key]) or data[key]
        local newValue, changed = controls.SliderFloat(icon, idPrefix .. key, displayValue, min, max, opts)
        if changed then
            data[key] = t and t.write(newValue) or newValue
            if onSave then onSave() end
        end
        return newValue, changed
    end

    function ctx:SliderInt(icon, key, min, max, opts)
        opts = opts or {}
        local t = opts.transform
        if opts.percent then
            local pct = (data[key] - min) / (max - min) * 100
            opts.format = string.format("%.0f%%%%", pct)
        end
        if defaults and defaults[key] ~= nil and opts.default == nil then
            opts.default = t and t.read(defaults[key]) or defaults[key]
        end
        local displayValue = t and t.read(data[key]) or data[key]
        local newValue, changed = controls.SliderInt(icon, idPrefix .. key, displayValue, min, max, opts)
        if changed then
            data[key] = t and t.write(newValue) or newValue
            if onSave then onSave() end
        end
        return newValue, changed
    end

    function ctx:Checkbox(label, key, opts)
        opts = opts or {}
        if defaults and defaults[key] ~= nil and opts.default == nil then
            opts.default = defaults[key]
        end
        local newValue, changed = controls.Checkbox(label, data[key], opts)
        if changed then
            data[key] = newValue
            if onSave then onSave() end
        end
        return newValue, changed
    end

    function ctx:ColorEdit4(icon, key, opts)
        opts = opts or {}
        if defaults and defaults[key] ~= nil and opts.default == nil then
            opts.default = defaults[key]
        end
        local newValue, changed = controls.ColorEdit4(icon, idPrefix .. key, data[key], opts)
        if changed then
            data[key] = newValue
            if onSave then onSave() end
        end
        return newValue, changed
    end

    function ctx:Combo(icon, key, items, opts)
        opts = opts or {}
        local t = opts.transform
        if defaults and defaults[key] ~= nil and opts.default == nil then
            opts.default = t and t.read(defaults[key]) or defaults[key]
        end
        local displayValue = t and t.read(data[key]) or data[key]
        local newValue, changed = controls.Combo(icon, idPrefix .. key, displayValue, items, opts)
        if changed then
            data[key] = t and t.write(newValue) or newValue
            if onSave then onSave() end
        end
        return newValue, changed
    end

    function ctx:InputText(icon, key, opts)
        opts = opts or {}
        if defaults and defaults[key] ~= nil and opts.default == nil then
            opts.default = defaults[key]
        end
        local newValue, changed = controls.InputText(icon, idPrefix .. key, data[key], opts)
        if changed then
            data[key] = newValue
            if onSave then onSave() end
        end
        return newValue, changed
    end

    function ctx:InputFloat(icon, key, opts)
        opts = opts or {}
        if defaults and defaults[key] ~= nil and opts.default == nil then
            opts.default = defaults[key]
        end
        local newValue, changed = controls.InputFloat(icon, idPrefix .. key, data[key], opts)
        if changed then
            data[key] = newValue
            if onSave then onSave() end
        end
        return newValue, changed
    end

    function ctx:InputInt(icon, key, opts)
        opts = opts or {}
        if defaults and defaults[key] ~= nil and opts.default == nil then
            opts.default = defaults[key]
        end
        local newValue, changed = controls.InputInt(icon, idPrefix .. key, data[key], opts)
        if changed then
            data[key] = newValue
            if onSave then onSave() end
        end
        return newValue, changed
    end

    --- Render a row of icon toggle buttons bound to boolean keys in data.
    function ctx:ToggleButtonRow(defs, opts)
        if not defs or #defs == 0 then return end
        opts = opts or {}
        local gap = opts.gap or frameCache.itemSpacingX
        local availW = ImGui.GetContentRegionAvail()

        -- Phase 1: measure fixed vs flex
        local fixedW = gap * (#defs - 1)
        local totalWeight = 0
        local measured = {}

        for i, def in ipairs(defs) do
            if def.width then
                measured[i] = def.width
                fixedW = fixedW + def.width
            elseif def.icon and not def.label and not def.weight then
                local icon = resolveIcon(def.icon) or def.icon
                measured[i] = ImGui.CalcTextSize(icon) + frameCache.framePaddingX * 2
                fixedW = fixedW + measured[i]
            else
                totalWeight = totalWeight + (def.weight or 1)
            end
        end

        local remainingW = math.max(availW - fixedW, 0)

        -- Phase 2: render
        for i, def in ipairs(defs) do
            local key = def.key
            local icon = resolveIcon(def.icon)
            local displayLabel = icon or def.label or key
            local isActive = data[key]
            local w = measured[i] or math.floor(remainingW * (def.weight or 1) / totalWeight)

            controls.Button(displayLabel, isActive and "active" or "inactive", w)

            if ImGui.IsItemClicked(0) then
                data[key] = not data[key]
                if onSave then onSave() end
                if def.onChange then def.onChange(data[key]) end
            end
            if ImGui.IsItemClicked(1) and defaults and defaults[key] ~= nil then
                data[key] = defaults[key]
                if onSave then onSave() end
                if def.onChange then def.onChange(data[key]) end
            end

            if def.tooltip then tooltips.Show(def.tooltip) end
            if i < #defs then ImGui.SameLine() end
        end
    end

    return ctx
end

--------------------------------------------------------------------------------
-- Panel (child window with default styling)
--------------------------------------------------------------------------------

--- Render a child window panel with default styling (opts: bg, border, width, height, flags)
---@param id string Unique panel ID (## prefix added automatically if missing)
local panelHoverState = {}

---@param contentFn? function Callback that renders panel content
---@param opts? table {bg?, border?, borderOnHover?, width?, height?, flags?}
---@return nil
function controls.Panel(id, contentFn, opts)
    opts = opts or {}
    local border = opts.border == true
    local borderOnHover = opts.borderOnHover or false
    local bg = opts.bg
    if bg == nil then bg = { 0.65, 0.7, 1.0, 0.045 } end
    local width = opts.width or 0
    local height = opts.height or 0
    local flags = ImGuiWindowFlags.AlwaysUseWindowPadding + (opts.flags or 0)

    -- Show border on hover using previous frame's hover state
    local showBorder = border
    if borderOnHover and not border then
        showBorder = panelHoverState[id] or false
    end

    local childId = id:find("^##") and id or ("##" .. id)

    if bg then
        ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(bg[1], bg[2], bg[3], bg[4] or 1.0))
    end
    ImGui.BeginChild(childId, width, height, showBorder, flags)
    if bg then ImGui.PopStyleColor() end
    if contentFn then contentFn() end
    ImGui.EndChild()

    if borderOnHover then
        panelHoverState[id] = ImGui.IsItemHovered()
    end
end

return controls
