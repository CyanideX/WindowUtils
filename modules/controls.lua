------------------------------------------------------
-- WindowUtils - Controls Module
-- Universal ImGui control helpers for CET mods
------------------------------------------------------

local styles = require("modules/styles")
local tooltips = require("modules/tooltips")
local utils = require("modules/utils")

local controls = {}

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local PANEL_DEFAULT_BG = { 0.65, 0.7, 1.0, 0.045 }

--------------------------------------------------------------------------------
-- Per-frame style cache (call controls.cacheFrameState() once per onDraw)
--------------------------------------------------------------------------------

local frameCache = {}

--------------------------------------------------------------------------------
-- State tables (grouped here for organization; used by various controls below)
--------------------------------------------------------------------------------

local buttonRowMinWidths = {}   -- ButtonRow minimum width cache (keyed by opts.id)
local holdStates = {}           -- HoldButton per-id state
local HOLD_OVERLAY_COLOR = nil  -- Cached overlay color for HoldButton
local fillChildBgState = {}     -- BeginFillChild bg push tracking
local columnAutoCache = {}      -- Column auto-size cache: [columnId][childIndex] = height
local panelHoverState = {}      -- Panel hover state for borderOnHover
local bindPool = {}             -- Reusable bind context pool
local bindPoolSize = 0

-- Reused tables for ActionButton (avoids per-frame allocation)
local actionButtonHoldOpts = { duration = 0, style = "", progressDisplay = "external" }
local actionButtonResult = { primaryClicked = false, secondaryTriggered = false }

---@param id string ButtonRow id (from opts.id)
---@return number|nil minWidth Cached minimum width in pixels, or nil if unknown
function controls.getButtonRowMinWidth(id)
    return buttonRowMinWidths[id]
end

---@return nil
function controls.cacheFrameState()
    local style = ImGui.GetStyle()
    frameCache.itemSpacingX = style.ItemSpacing.x
    frameCache.itemSpacingY = style.ItemSpacing.y
    frameCache.framePaddingX = style.FramePadding.x
    frameCache.windowPaddingX = style.WindowPadding.x
    frameCache.windowPaddingY = style.WindowPadding.y
    frameCache.frameHeight = ImGui.GetFrameHeight()
    frameCache.textLineHeight = ImGui.GetTextLineHeightWithSpacing()
    frameCache.minIconButtonWidth = utils.minIconButtonWidth(style.FramePadding.x)
    frameCache.charWidth = ImGui.CalcTextSize("M")
    frameCache.ellipsisWidth = ImGui.CalcTextSize("...")
    frameCache.displayWidth, frameCache.displayHeight = GetDisplayResolution()
end

---@return table frameCache Cached style values for the current frame
function controls.getFrameCache()
    return frameCache
end

--------------------------------------------------------------------------------
-- Grid System (Bootstrap-style columns)
--------------------------------------------------------------------------------

--- Calculate width for a column ratio (1-12 out of 12 columns)
---@param cols? number Column span (1-12, default 12)
---@param gap? number Gap between columns in pixels (default itemSpacingX)
---@param hasIcon? boolean Whether an icon occupies space to the left
---@return number width Calculated pixel width (minimum 20)
function controls.ColWidth(cols, gap, hasIcon)
    cols = math.max(1, math.min(12, cols or 12))
    gap = gap or frameCache.itemSpacingX
    local iconWidth = frameCache.minIconButtonWidth
    local availWidth = ImGui.GetContentRegionAvail()
    if hasIcon then
        availWidth = availWidth + iconWidth + gap
    end
    local colWidth = (availWidth - (gap * 11)) / 12
    local targetWidth = (colWidth * cols) + (gap * (cols - 1))
    if hasIcon then
        targetWidth = targetWidth - iconWidth - gap
    end
    return math.max(targetWidth, 20)
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

--- Create a non-interactive status bar with a label and optional value.
---@param label string Left-side label text (rendered inside button)
---@param value? any Right-side value text (rendered after button via SameLine)
---@param opts? {widthFraction: number, style: string} widthFraction divides available width (default 1), style name (default "statusbar")
function controls.StatusBar(label, value, opts)
    opts = opts or {}
    local style = opts.style or "statusbar"
    local w = ImGui.GetContentRegionAvail() / (opts.widthFraction or 1)

    styles.PushButton(style)
    ImGui.Button(label, w, 0)
    styles.PopButton(style)

    if value ~= nil then
        ImGui.SameLine()
        ImGui.Text(tostring(value))
    end
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
local truncateCache = {}
local truncateCacheCharWidth = nil

local textSizeCache = {}
local textSizeCacheCharWidth = nil

local function cachedCalcTextSize(text)
    local cw = frameCache.charWidth
    if cw ~= textSizeCacheCharWidth then
        textSizeCache = {}
        textSizeCacheCharWidth = cw
    end
    local cached = textSizeCache[text]
    if cached then return cached end
    local w = ImGui.CalcTextSize(text)
    textSizeCache[text] = w
    return w
end

local function cachedTruncateText(label, innerWidth)
    local cw = frameCache.charWidth
    if cw ~= truncateCacheCharWidth then
        truncateCache = {}
        truncateCacheCharWidth = cw
    end
    local key = label .. "|" .. math.floor(innerWidth)
    local cached = truncateCache[key]
    if cached then return cached[1], cached[2] end
    local result, wasTruncated = truncateText(label, innerWidth)
    truncateCache[key] = { result, wasTruncated }
    return result, wasTruncated
end

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

    local minChars = opts.minChars or 3
    local iconThreshold = opts.iconThreshold
    if not iconThreshold then
        iconThreshold = (frameCache.charWidth * minChars) + frameCache.ellipsisWidth
    end

    local displayLabel
    local wasTruncated = false
    local isIconMode = false

    if innerWidth <= iconThreshold then
        displayLabel = iconStr
        isIconMode = true
    else
        displayLabel, wasTruncated = cachedTruncateText(label, innerWidth)
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

--- Create a hold-to-confirm button with progress fill overlay
---@param id string Unique button ID (also used as label in legacy mode)
---@param label string Button label text
---@param opts? table {duration?, style?, width?, progressDisplay?, progressStyle?, disabled?, tooltip?, overlayColor?, onClick?, onHold?}
---@return boolean triggered True if the hold completed
---@return boolean clicked True if released before hold completed
function controls.HoldButton(id, label, opts)
    opts = opts or {}
    local duration = opts.duration or 2.0
    local styleName = opts.style or "danger"
    local width = opts.width or 0
    if width < 0 then width = ImGui.GetContentRegionAvail() end
    local progressDisplay = opts.progressDisplay or "overlay"
    local progressStyle = opts.progressStyle or "danger"
    local isDisabled = opts.disabled or false

    if isDisabled then ImGui.BeginDisabled(true) end

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

    if state.completed and not ImGui.IsMouseDown(0) then
        state.completed = false
    end

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

    local displayLabel = state.displayLabel
    styles.PushButton(styleName)
    ImGui.Button(displayLabel, width, 0)
    local isActive = ImGui.IsItemActive()
    styles.PopButton(styleName)

    if isActive and not state.holding and not state.completed then
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
            state.holding = false
            clicked = true
        end
    end

    if not state.holding and state.progress > 0 then
        state.progress = math.max(0, state.progress - dt * 4)
    end

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
    -- "external" mode: no visual - other elements read via getHoldProgress()

    if isDisabled then ImGui.EndDisabled() end
    if opts.tooltip then tooltips.Show(opts.tooltip) end

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

--- Return the progress and source ID of the first actively-held button from a list.
---@param ids string[] Array of button IDs to check
---@return number|nil progress Hold progress 0.0-1.0, or nil if none active
---@return string|nil sourceId The ID of the first active button, or nil
function controls.getFirstActiveHoldProgress(ids)
    if not ids then return nil end
    for i = 1, #ids do
        local progress = controls.getHoldProgress(ids[i])
        if progress then return progress, ids[i] end
    end
    return nil
end

--- Render a progress bar for the first active hold source, or return false.
---@param ids string[] Array of button IDs to check
---@param width? number Bar width in pixels (default fills available)
---@param progressStyle? string Style name (default "danger")
---@return boolean shown True if a progress bar was rendered
function controls.ShowFirstActiveHoldProgress(ids, width, progressStyle)
    local progress = controls.getFirstActiveHoldProgress(ids)
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

    local secondaryWidth = 0
    if onSecondary then
        local iconWidth = cachedCalcTextSize(secondaryIcon)
        local framePadX = frameCache.framePaddingX * 2
        local spacing = frameCache.itemSpacingX
        secondaryWidth = iconWidth + framePadX + spacing
    end
    local mainWidth = (totalWidth or ImGui.GetContentRegionAvail()) - secondaryWidth

    local secondaryId = id .. "_secondary"
    local primaryClicked = false

    -- Primary button: show progress bar from secondary hold, or normal button
    if onSecondary and controls.ShowHoldProgress(secondaryId, mainWidth, progressStyle) then
        -- (progress bar replaces primary button while held)
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
        actionButtonHoldOpts.duration = secondaryDuration
        actionButtonHoldOpts.style = secondaryStyle
        secondaryTriggered = controls.HoldButton(secondaryId, secondaryIcon, actionButtonHoldOpts)
        if secondaryTriggered then
            onSecondary()
        end
    end

    actionButtonResult.primaryClicked = primaryClicked
    actionButtonResult.secondaryTriggered = secondaryTriggered
    return actionButtonResult
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
-- Fill-Available-Space Child Region
--------------------------------------------------------------------------------

--- Begin a child region that fills remaining vertical space in the window.
--- bg defaults to the standard panel background. Pass false for transparent,
--- or an {r,g,b,a} table for a custom color.
---@param id string Unique child ID (## prefix added automatically if missing)
---@param opts? table {footerHeight?, border?, flags?, bg?}
---@return boolean visible True if the child region is visible
function controls.BeginFillChild(id, opts)
    opts = opts or {}
    local footerHeight = opts.footerHeight or 0
    local border = opts.border or false
    local extraFlags = opts.flags or 0
    local bg = opts.bg
    if bg == nil then bg = PANEL_DEFAULT_BG end

    local childId = id
    if not id:find("^##") then
        childId = "##" .. id
    end

    if bg and bg ~= false then
        ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(bg[1], bg[2], bg[3], bg[4] or 1.0))
        fillChildBgState[id] = true
    else
        fillChildBgState[id] = false
    end

    local width, contentAvailH = ImGui.GetContentRegionAvail()
    -- Subtract footer + item spacing between child and footer (if any)
    local spacingBeforeFooter = footerHeight > 0 and frameCache.itemSpacingY or 0
    local childHeight = math.max(contentAvailH - footerHeight - spacingBeforeFooter, 1)

    local flags = ImGuiWindowFlags.AlwaysUseWindowPadding + extraFlags

    styles.PushScrollbar()
    return ImGui.BeginChild(childId, width, childHeight, border, flags)
end

--- End a fill child region. Pops ChildBg if BeginFillChild pushed one for this id.
---@param id string Child ID passed to BeginFillChild
---@return nil
function controls.EndFillChild(id)
    ImGui.EndChild()
    styles.PopScrollbar()
    if id == nil then
        print("[WindowUtils] EndFillChild called with nil id")
        return
    end
    if fillChildBgState[id] then
        ImGui.PopStyleColor()
        fillChildBgState[id] = nil
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
    local spacingY = frameCache.itemSpacingY
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
-- ButtonRow (two-tier width: auto-sized icons + weighted text)
--------------------------------------------------------------------------------

--- Measure button defs for width distribution (shared by ButtonRow and ToggleButtonRow).
---@param defs table Array of button defs
---@param gap number Gap between buttons in pixels
---@param textFallback? function (def) → string fallback text for flex buttons
---@return number fixedW, number totalWeight, table measured, number totalMinWidth
local function measureButtonDefs(defs, gap, textFallback)
    local fixedW = gap * (#defs - 1)
    local totalWeight = 0
    local measured = {}
    local totalMinWidth = fixedW

    for i, def in ipairs(defs) do
        if def.width then
            measured[i] = def.width
            fixedW = fixedW + def.width
            totalMinWidth = totalMinWidth + def.width
        elseif def.icon and not def.label and not def.weight then
            local icon = resolveIcon(def.icon) or def.icon
            measured[i] = cachedCalcTextSize(icon) + frameCache.framePaddingX * 2
            fixedW = fixedW + measured[i]
            totalMinWidth = totalMinWidth + measured[i]
        else
            totalWeight = totalWeight + (def.weight or 1)
            local text = (def.icon and resolveIcon(def.icon))
                or def.label or (textFallback and textFallback(def)) or ""
            totalMinWidth = totalMinWidth + cachedCalcTextSize(text) + frameCache.framePaddingX * 2
        end
    end

    return fixedW, totalWeight, measured, totalMinWidth
end

--- Render a row of buttons with automatic width distribution.
--- Icon-only buttons (def.icon, no def.label) auto-size. Text buttons share remaining space by weight.
---@param defs table Array of button defs: {label?, icon?, style?, weight?, width?, height?, disabled?, tooltip?, onClick?, onHold?, holdDuration?, progressFrom?, progressStyle?, progressDisplay?, id?}
---@param opts? table {gap?, id?}
---@return nil
function controls.ButtonRow(defs, opts)
    if not defs or #defs == 0 then return end
    opts = opts or {}
    local gap = opts.gap or frameCache.itemSpacingX
    local availW = ImGui.GetContentRegionAvail()

    -- Phase 1: measure fixed-width buttons, sum flex weights
    local fixedW, totalWeight, measured, totalMinWidth = measureButtonDefs(defs, gap, function(d) return d[1] end)

    if opts.id then
        buttonRowMinWidths[opts.id] = totalMinWidth
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
-- Shared Bind Methods (metatable-based, zero closures per bind call)
--------------------------------------------------------------------------------

local bindMethods = {}

--- Apply def defaults to opts and handle search dimming.
--- label is included in search matching so localized text is searchable.
--- Returns opts (possibly modified) and whether dimming was pushed.
local function applyDefAndSearch(self, key, opts, label)
    local def = self.defs and self.defs[key]
    if def then
        if def.tooltip and not opts.tooltip then opts.tooltip = def.tooltip end
        if def.format and not opts.format then opts.format = def.format end
        if def.percent ~= nil and opts.percent == nil then opts.percent = def.percent end
        if def.transform and not opts.transform then opts.transform = def.transform end
        if def.items and not opts._items then opts._items = def.items end
        if def.alwaysShowTooltip and opts.alwaysShowTooltip == nil then opts.alwaysShowTooltip = def.alwaysShowTooltip end
    end

    local dimmed = false
    if self.search and not self.search:isEmpty() then
        local searchLabel = label or (def and def.label)
        local terms = ""
        if searchLabel then terms = searchLabel end
        if def then
            if def.searchTerms then terms = terms .. " " .. def.searchTerms end
            -- Include tooltip when explicitly opted in, or when there's no text label
            -- (icon-only controls like sliders need tooltip as their searchable text)
            if def.tooltip and (self.searchTooltips or not searchLabel) then
                terms = terms .. " " .. def.tooltip
            end
        end
        if terms ~= "" then
            local matched = self.search:matches(key, terms)
            if not matched then
                ImGui.PushStyleVar(ImGuiStyleVar.Alpha, self.search.dimAlpha)
                dimmed = true
            end
        end
    end
    return opts, dimmed
end

local function endDim(dimmed)
    if dimmed then ImGui.PopStyleVar() end
end

function bindMethods:SliderFloat(icon, key, min, max, opts)
    opts = opts or {}
    local def = self.defs and self.defs[key]
    if def then
        if not icon and def.icon then icon = def.icon end
        if not min and def.min then min = def.min end
        if not max and def.max then max = def.max end
    end
    local opts2, dimmed = applyDefAndSearch(self, key, opts)
    local t = opts2.transform
    if opts2.percent then
        local pct = (self.data[key] - min) / (max - min) * 100
        opts2.format = string.format("%.0f%%%%", pct)
    end
    if self.defaults and self.defaults[key] ~= nil and opts2.default == nil then
        opts2.default = t and t.read(self.defaults[key]) or self.defaults[key]
    end
    local displayValue = t and t.read(self.data[key]) or self.data[key]
    local newValue, changed = controls.SliderFloat(icon, self.idPrefix .. key, displayValue, min, max, opts2)
    if changed then
        self.data[key] = t and t.write(newValue) or newValue
        if self.onSave then self.onSave() end
    end
    endDim(dimmed)
    return newValue, changed
end

function bindMethods:SliderInt(icon, key, min, max, opts)
    opts = opts or {}
    local def = self.defs and self.defs[key]
    if def then
        if not icon and def.icon then icon = def.icon end
        if not min and def.min then min = def.min end
        if not max and def.max then max = def.max end
    end
    local opts2, dimmed = applyDefAndSearch(self, key, opts)
    local t = opts2.transform
    if opts2.percent then
        local pct = (self.data[key] - min) / (max - min) * 100
        opts2.format = string.format("%.0f%%%%", pct)
    end
    if self.defaults and self.defaults[key] ~= nil and opts2.default == nil then
        opts2.default = t and t.read(self.defaults[key]) or self.defaults[key]
    end
    local displayValue = t and t.read(self.data[key]) or self.data[key]
    local newValue, changed = controls.SliderInt(icon, self.idPrefix .. key, displayValue, min, max, opts2)
    if changed then
        self.data[key] = t and t.write(newValue) or newValue
        if self.onSave then self.onSave() end
    end
    endDim(dimmed)
    return newValue, changed
end

function bindMethods:Checkbox(label, key, opts)
    opts = opts or {}
    local opts2, dimmed = applyDefAndSearch(self, key, opts, label)
    if self.defaults and self.defaults[key] ~= nil and opts2.default == nil then
        opts2.default = self.defaults[key]
    end
    local newValue, changed = controls.Checkbox(label, self.data[key], opts2)
    if changed then
        self.data[key] = newValue
        if self.onSave then self.onSave() end
    end
    endDim(dimmed)
    return newValue, changed
end

function bindMethods:ColorEdit4(icon, key, opts)
    opts = opts or {}
    local def = self.defs and self.defs[key]
    if def and not icon and def.icon then icon = def.icon end
    local opts2, dimmed = applyDefAndSearch(self, key, opts)
    if self.defaults and self.defaults[key] ~= nil and opts2.default == nil then
        opts2.default = self.defaults[key]
    end
    local newValue, changed = controls.ColorEdit4(icon, self.idPrefix .. key, self.data[key], opts2)
    if changed then
        self.data[key] = newValue
        if self.onSave then self.onSave() end
    end
    endDim(dimmed)
    return newValue, changed
end

function bindMethods:Combo(icon, key, items, opts)
    opts = opts or {}
    local def = self.defs and self.defs[key]
    if def then
        if not icon and def.icon then icon = def.icon end
        if not items and def.items then items = def.items end
    end
    local opts2, dimmed = applyDefAndSearch(self, key, opts)
    local t = opts2.transform
    if self.defaults and self.defaults[key] ~= nil and opts2.default == nil then
        opts2.default = t and t.read(self.defaults[key]) or self.defaults[key]
    end
    local displayValue = t and t.read(self.data[key]) or self.data[key]
    local newValue, changed = controls.Combo(icon, self.idPrefix .. key, displayValue, items, opts2)
    if changed then
        self.data[key] = t and t.write(newValue) or newValue
        if self.onSave then self.onSave() end
    end
    endDim(dimmed)
    return newValue, changed
end

function bindMethods:InputText(icon, key, opts)
    opts = opts or {}
    local def = self.defs and self.defs[key]
    if def and not icon and def.icon then icon = def.icon end
    local opts2, dimmed = applyDefAndSearch(self, key, opts)
    if self.defaults and self.defaults[key] ~= nil and opts2.default == nil then
        opts2.default = self.defaults[key]
    end
    local newValue, changed = controls.InputText(icon, self.idPrefix .. key, self.data[key], opts2)
    if changed then
        self.data[key] = newValue
        if self.onSave then self.onSave() end
    end
    endDim(dimmed)
    return newValue, changed
end

function bindMethods:InputFloat(icon, key, opts)
    opts = opts or {}
    local def = self.defs and self.defs[key]
    if def and not icon and def.icon then icon = def.icon end
    local opts2, dimmed = applyDefAndSearch(self, key, opts)
    if self.defaults and self.defaults[key] ~= nil and opts2.default == nil then
        opts2.default = self.defaults[key]
    end
    local newValue, changed = controls.InputFloat(icon, self.idPrefix .. key, self.data[key], opts2)
    if changed then
        self.data[key] = newValue
        if self.onSave then self.onSave() end
    end
    endDim(dimmed)
    return newValue, changed
end

function bindMethods:InputInt(icon, key, opts)
    opts = opts or {}
    local def = self.defs and self.defs[key]
    if def and not icon and def.icon then icon = def.icon end
    local opts2, dimmed = applyDefAndSearch(self, key, opts)
    if self.defaults and self.defaults[key] ~= nil and opts2.default == nil then
        opts2.default = self.defaults[key]
    end
    local newValue, changed = controls.InputInt(icon, self.idPrefix .. key, self.data[key], opts2)
    if changed then
        self.data[key] = newValue
        if self.onSave then self.onSave() end
    end
    endDim(dimmed)
    return newValue, changed
end

function bindMethods:ToggleButtonRow(defs, opts)
    if not defs or #defs == 0 then return end
    opts = opts or {}
    local gap = opts.gap or frameCache.itemSpacingX
    local availW = ImGui.GetContentRegionAvail()

    local fixedW, totalWeight, measured, totalMinWidth = measureButtonDefs(defs, gap, function(d) return d.key end)

    if opts.id then
        buttonRowMinWidths[opts.id] = totalMinWidth
    end

    local remainingW = math.max(availW - fixedW, 0)

    for i, def in ipairs(defs) do
        local key = def.key
        local icon = resolveIcon(def.icon)
        local displayLabel = icon or def.label or key
        local isActive = self.data[key]
        local w = measured[i] or math.floor(remainingW * (def.weight or 1) / totalWeight)

        controls.Button(displayLabel, isActive and "active" or "inactive", w)

        if ImGui.IsItemClicked(0) then
            self.data[key] = not self.data[key]
            if self.onSave then self.onSave() end
            if def.onChange then def.onChange(self.data[key]) end
        end
        if ImGui.IsItemClicked(1) and self.defaults and self.defaults[key] ~= nil then
            self.data[key] = self.defaults[key]
            if self.onSave then self.onSave() end
            if def.onChange then def.onChange(self.data[key]) end
        end

        if def.tooltip then tooltips.Show(def.tooltip) end
        if i < #defs then ImGui.SameLine() end
    end
end

--- Render a text header that auto-dims when no controls in the category match the search query.
--- No-op dimming when search or defs are not configured.
---@param text string Header text
---@param category string Category key to check against defs
function bindMethods:Header(text, category)
    local dimmed = false
    if self.search and self.defs and category and not self.search:isEmpty() then
        if not self.search:categoryHasMatch(category, self.defs, self.searchTooltips) then
            ImGui.PushStyleVar(ImGuiStyleVar.Alpha, self.search.dimAlpha)
            dimmed = true
        end
    end
    ImGui.Text(text)
    if dimmed then ImGui.PopStyleVar() end
end

--- Push search dimming for a key using its def. For wrapping non-bound controls.
--- Returns true if dimming was pushed (caller must call c:EndDim() after).
---@param key string Setting key to check
---@return boolean dimmed
function bindMethods:BeginDim(key)
    if not self.search or self.search:isEmpty() then return false end
    local def = self.defs and self.defs[key]
    if not def then return false end
    local searchLabel = def.label
    local terms = ""
    if searchLabel then terms = searchLabel end
    if def.searchTerms then terms = terms .. " " .. def.searchTerms end
    if def.tooltip and (self.searchTooltips or not searchLabel) then
        terms = terms .. " " .. def.tooltip
    end
    if terms ~= "" and not self.search:matches(key, terms) then
        ImGui.PushStyleVar(ImGuiStyleVar.Alpha, self.search.dimAlpha)
        return true
    end
    return false
end

--- Pop search dimming if it was pushed by BeginDim.
---@param dimmed boolean Value returned by BeginDim
function bindMethods:EndDim(dimmed)
    if dimmed then ImGui.PopStyleVar() end
end

--- Render a section header (separator + label) that auto-dims based on category match.
---@param text string Section title text
---@param category string Category key to check against defs
---@param spacingBefore? number Vertical spacing before separator
---@param spacingAfter? number Vertical spacing after label
function bindMethods:SectionHeader(text, category, spacingBefore, spacingAfter)
    local dimmed = false
    if self.search and self.defs and category and not self.search:isEmpty() then
        if not self.search:categoryHasMatch(category, self.defs, self.searchTooltips) then
            ImGui.PushStyleVar(ImGuiStyleVar.Alpha, self.search.dimAlpha)
            dimmed = true
        end
    end
    controls.SectionHeader(text, spacingBefore, spacingAfter)
    if dimmed then ImGui.PopStyleVar() end
end

local bindMT = { __index = bindMethods }

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
---@param bindOpts? table {idPrefix?: string, search?: table, defs?: table, searchTooltips?: boolean}
---@return table ctx Bound context with SliderFloat, SliderInt, Checkbox, ColorEdit4, Combo, InputText, InputFloat, InputInt, ToggleButtonRow methods
function controls.bind(data, defaults, onSave, bindOpts)
    local ctx
    if bindPoolSize > 0 then
        ctx = bindPool[bindPoolSize]
        bindPoolSize = bindPoolSize - 1
    else
        ctx = setmetatable({}, bindMT)
    end
    ctx.data = data
    ctx.defaults = defaults
    ctx.onSave = onSave
    ctx.idPrefix = (bindOpts and bindOpts.idPrefix) or ""
    ctx.search = bindOpts and bindOpts.search or nil
    ctx.defs = bindOpts and bindOpts.defs or nil
    ctx.searchTooltips = bindOpts and bindOpts.searchTooltips or false
    return ctx
end

--- Return a bind context to the pool for reuse.
--- Optional; without this, contexts become garbage as before but without closure overhead.
---@param ctx table Bind context previously returned by controls.bind()
function controls.unbind(ctx)
    bindPoolSize = bindPoolSize + 1
    bindPool[bindPoolSize] = ctx
end

--------------------------------------------------------------------------------
-- Panel (child window with default styling)
--------------------------------------------------------------------------------

--- Render a child window panel with default styling (opts: bg, border, width, height, flags)
---@param id string Unique panel ID (## prefix added automatically if missing)

--------------------------------------------------------------------------------
-- PanelGroup: visual panel using BeginGroup/EndGroup + DrawList.
-- No BeginChild, no explicit height - content flows in parent scroll region.
-- Background and border drawn via DrawList with proper padding and rounding.
--------------------------------------------------------------------------------

--- Visual panel wrapper for scrollable regions. Uses Group + DrawList instead
--- of BeginChild, so no explicit height is needed and no measurement feedback.
---@param id string Unique identifier (for hover state tracking)
---@param contentFn? function Callback that renders panel content
---@param opts? table {bg?, border?, borderOnHover?}
function controls.PanelGroup(id, contentFn, opts)
    opts = opts or {}
    local borderOnHover = opts.borderOnHover or false
    local bg = opts.bg
    if bg == nil then bg = PANEL_DEFAULT_BG end

    local padX = frameCache.windowPaddingX or 8
    local padY = frameCache.windowPaddingY or 8
    local rounding = ImGui.GetStyle().ChildRounding or 4.0

    -- Capture start position and full available width before content
    local startX, startY = ImGui.GetCursorScreenPos()
    local availW = ImGui.GetContentRegionAvail()
    local contentW = availW - padX * 2

    ImGui.BeginGroup()

    -- Top padding + width reservation (forces group to full width)
    ImGui.Dummy(availW, padY)

    -- Left padding via indent; PushItemWidth constrains widget widths
    ImGui.Indent(padX)
    ImGui.PushItemWidth(contentW)
    if contentFn then contentFn() end
    ImGui.PopItemWidth()
    ImGui.Unindent(padX)

    -- Bottom padding
    ImGui.Dummy(availW, padY)

    ImGui.EndGroup()

    -- Rect: full available width, actual content height
    local _, maxY = ImGui.GetItemRectMax()
    local rectMinX = startX
    local rectMinY = startY
    local rectMaxX = startX + availW
    local rectMaxY = maxY

    local drawList = ImGui.GetWindowDrawList()

    -- Background fill
    if bg then
        local bgColor = ImGui.GetColorU32(bg[1], bg[2], bg[3], bg[4] or 1.0)
        ImGui.ImDrawListAddRectFilled(drawList, rectMinX, rectMinY, rectMaxX, rectMaxY, bgColor, rounding)
    end

    -- Border: thin outline (4 edge rects, inset at corners for rounding)
    local showBorder = opts.border == true
    if borderOnHover and not showBorder then
        showBorder = panelHoverState[id] or false
    end
    if showBorder then
        local bc = ImGui.GetColorU32(ImGuiCol.Border)
        local t = 1.0
        local r = math.min(rounding, 6)
        ImGui.ImDrawListAddRectFilled(drawList, rectMinX + r, rectMinY, rectMaxX - r, rectMinY + t, bc)
        ImGui.ImDrawListAddRectFilled(drawList, rectMinX + r, rectMaxY - t, rectMaxX - r, rectMaxY, bc)
        ImGui.ImDrawListAddRectFilled(drawList, rectMinX, rectMinY + r, rectMinX + t, rectMaxY - r, bc)
        ImGui.ImDrawListAddRectFilled(drawList, rectMaxX - t, rectMinY + r, rectMaxX, rectMaxY - r, bc)
    end

    -- Hover tracking + tooltip
    if borderOnHover then
        local mx, my = ImGui.GetMousePos()
        local hovered = mx >= rectMinX and mx <= rectMaxX and my >= rectMinY and my <= rectMaxY
        panelHoverState[id] = hovered
        -- Show tooltip when hovering the panel background (not a child widget)
        if hovered and not ImGui.IsAnyItemHovered() then
            ImGui.BeginTooltip()
            ImGui.Text("controls.PanelGroup(\"" .. id .. "\", fn, opts)")
            ImGui.EndTooltip()
        end
    end
end

---@param contentFn? function Callback that renders panel content
---@param opts? table {bg?, border?, borderOnHover?, width?, height?, flags?}
---@return nil
function controls.Panel(id, contentFn, opts)
    opts = opts or {}
    local border = opts.border == true
    local borderOnHover = opts.borderOnHover or false
    local bg = opts.bg
    if bg == nil then bg = PANEL_DEFAULT_BG end
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
