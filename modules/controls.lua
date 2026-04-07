------------------------------------------------------
-- WindowUtils - Controls
-- ImGui control helpers for CET mods
------------------------------------------------------
-- PUBLIC API:
--   controls.ColWidth(cols, gap, hasIcon)
--   controls.IconButton(icon, visible)
--   controls.Button(label, style, width, height)
--   controls.ToggleButton(label, isActive, width, height)
--   controls.SliderFloat(icon, id, value, min, max, opts)
--   controls.SliderInt(icon, id, value, min, max, opts)
--   controls.DragFloat(icon, id, value, min, max, opts)
--   controls.DragInt(icon, id, value, min, max, opts)
--   controls.DragFloatRow(icon, id, drags, opts)
--   controls.DragIntRow(icon, id, drags, opts)
--   controls.Checkbox(label, value, opts)
--   controls.ProgressBar(fraction, width, height, overlay, styleName)
--   controls.ColorEdit4(icon, id, color, opts)
--   controls.SwatchGrid(id, colors, selectedHex, onSelect, config)
--   controls.TextMuted(text, value) / TextSuccess / TextDanger / TextWarning
--   controls.SectionHeader(text, spacingBefore, spacingAfter, iconGlyph)
--   controls.Separator(before, after)
--   controls.Combo(icon, id, currentIndex, items, opts)
--   controls.InputText(icon, id, text, opts)
--   controls.InputFloat(icon, id, value, opts)
--   controls.InputInt(icon, id, value, opts)
--   controls.HoldButton(id, label, opts)
--   controls.ActionButton(label, opts)
--   controls.BeginFillChild(id, opts) / EndFillChild(id)
--   controls.Row(defs, opts)
--   controls.Column(defs, opts)
--   controls.ButtonRow(defs, opts)
--   controls.bind(data, defaults, onSave, bindOpts) / unbind(ctx)
--   controls.PanelGroup(id, opts)
------------------------------------------------------
-- See controls.md docs for more information
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

-- Scale a 1080p-baseline pixel value to the current display resolution
local function Scaled(value)
    return math.floor(value * (frameCache.displayHeight / 1080) + 0.5)
end

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
local buttonGroupWidths = {}    -- Cached combined widths for button groups (keyed by groupId)
local swatchSortCache = {}      -- Cached sort results keyed by grid id
local swatchSortQuickCheck = {} -- Quick staleness check: id -> {count, hasCategories, cacheKey}

-- Reused tables for ActionButton (avoids per-frame allocation)
local actionButtonHoldOpts = { duration = 0, style = "", progressDisplay = "external" }
local actionButtonResult = { primaryClicked = false, secondaryTriggered = false }

---@param id string ButtonRow id (from opts.id)
---@return number|nil minWidth Cached minimum width in pixels, or nil if unknown
function controls.getButtonRowMinWidth(id)
    return buttonRowMinWidths[id]
end

--- Get the cached combined width of a button group from a previous DragFloatRow/DragIntRow.
--- Buttons with the same groupId have their widths + spacing summed and cached.
---@param groupId string The group ID assigned to buttons via the groupId field
---@return number|nil width Combined pixel width, or nil if not yet measured
function controls.getButtonGroupWidth(groupId)
    return buttonGroupWidths[groupId]
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

local function cachedCalcTextSize(text)
    return utils.cachedCalcTextSize(text, frameCache.charWidth)
end

local function cachedTruncateText(label, innerWidth)
    return utils.cachedTruncateText(label, innerWidth, frameCache.charWidth)
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
-- Drag Controls with Shift Precision
-- DragFloat/DragInt: like sliders but with configurable drag speed.
-- Hold Shift for precision mode (reduced speed).
--------------------------------------------------------------------------------

--- Compute drag speed accounting for Shift precision.
--- ImGui natively multiplies drag speed by 10x when Shift is held,
--- so we counter that and apply our own precision factor.
---@param baseSpeed number Normal drag speed
---@param opts table Control opts (may contain precisionMultiplier, noPrecision)
---@return number speed Effective drag speed for this frame
local function getDragSpeed(baseSpeed, opts)
    if opts.noPrecision then return baseSpeed end
    return utils.getDragSpeed(baseSpeed, opts.precisionMultiplier)
end

--------------------------------------------------------------------------------
-- DragRow: shared width computation and rendering for DragFloatRow/DragIntRow
--------------------------------------------------------------------------------

--- Compute per-element widths for a drag row.
--- Fixed-width elements (explicit width or buttons) keep their size.
--- Weighted drags share remaining space proportionally.
---@param drags table Array of Drag_Definitions and/or Button_Definitions
---@param availWidth number Total available width for all elements
---@param spacing number Pixel gap between elements
---@return table widths Array of computed widths (one per element)
local function computeElementWidths(drags, availWidth, spacing)
    local n = #drags
    if n == 0 then return {} end

    local totalSpacing = (n - 1) * spacing
    local remaining = availWidth - totalSpacing
    local totalWeight = 0
    local widths = {}
    local padX2 = frameCache.framePaddingX * 2

    -- First pass: resolve fixed widths, accumulate weights
    for i = 1, n do
        local el = drags[i]
        if el.width then
            widths[i] = el.width
            remaining = remaining - el.width
        elseif el.widthFrom then
            -- Use cached width from a button group
            local w = buttonGroupWidths[el.widthFrom] or 0
            widths[i] = w
            remaining = remaining - w
        elseif el.widthPercent then
            -- Percentage of display width
            local w = math.floor(frameCache.displayWidth * el.widthPercent / 100)
            widths[i] = w
            remaining = remaining - w
        elseif el.fitLabel and el.label then
            -- Fit to label text + frame padding + extra breathing room
            local w = cachedCalcTextSize(el.label) + padX2 + frameCache.charWidth * 2
            widths[i] = w
            remaining = remaining - w
        elseif el.type == "button" then
            if el.weight then
                -- Weighted button: participates in remaining space distribution
                totalWeight = totalWeight + el.weight
                widths[i] = 0
            else
                local icon = el.icon and resolveIcon(el.icon)
                local text = icon or el.label or ""
                local w = cachedCalcTextSize(text) + padX2
                widths[i] = w
                remaining = remaining - w
            end
        else
            totalWeight = totalWeight + (el.weight or 1)
            widths[i] = 0
        end
    end

    -- Second pass: distribute remaining space by weight
    if totalWeight > 0 and remaining > 0 then
        for i = 1, n do
            if widths[i] == 0 then
                widths[i] = math.floor(remaining * (drags[i].weight or 1) / totalWeight)
            end
        end
    end

    return widths
end

--- Shared renderer for DragFloatRow and DragIntRow.
--- Renders a horizontal row of drag inputs and/or buttons with color theming,
--- width weighting, label-to-value display, delta mode, and right-click reset.
---@param icon string|nil Icon prefix glyph
---@param id string Base ImGui ID (each element appends its index)
---@param drags table Array of Drag_Definitions and/or Button_Definitions
---@param opts table Row-level options (state, cols, speed, min, max, spacing, mode, onChange, etc.)
---@param dragFn function ImGui.DragFloat or ImGui.DragInt
---@param defaultFormat string Default format string ("%.2f" or "%d")
---@param defaultSpeed number|nil Default base speed (nil = derived from range)
---@return table values New values (one per drag element, buttons excluded)
---@return boolean anyChanged True if any drag value changed
local function renderDragRow(icon, id, drags, opts, dragFn, defaultFormat, defaultSpeed)
    if not drags or #drags == 0 then return {}, false end
    opts = opts or {}

    local spacing = opts.spacing or frameCache.itemSpacingX
    local isDelta = opts.mode == "delta"
    local customSpacing = spacing ~= frameCache.itemSpacingX

    -- Caller-owned state table for hover tracking, delta accum, and cached ImGui IDs.
    -- Bound calls always provide this; unbound calls can pass opts.state for persistence.
    local state = opts._state or opts.state

    -- Icon prefix
    if icon then
        iconPrefix(icon, opts.tooltip, true)
    end

    -- Available width
    local availWidth
    if opts.cols then
        availWidth = controls.ColWidth(opts.cols, nil, icon ~= nil)
    else
        availWidth = ImGui.GetContentRegionAvail()
    end

    local widths = computeElementWidths(drags, availWidth, spacing)

    if customSpacing then
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, spacing, frameCache.itemSpacingY)
    end

    -- Resolve sub-tables from state (all nil-safe if state is nil)
    local hovered = state and state.hovered
    local deltaAccum = state and state.deltaAccum
    local imguiIds = state and state.imguiIds

    -- Build/extend cached ImGui ID strings on the state table
    if state then
        if not imguiIds then
            imguiIds = {}
            state.imguiIds = imguiIds
        end
        if not hovered then
            hovered = {}
            state.hovered = hovered
        end
        if isDelta and not deltaAccum then
            deltaAccum = {}
            state.deltaAccum = deltaAccum
        end
        if not deltaAccum then
            for _, el in ipairs(drags) do
                if el.mode == "delta" then
                    deltaAccum = {}
                    state.deltaAccum = deltaAccum
                    break
                end
            end
        end
        -- Extend ID cache if drags array grew
        for j = #imguiIds + 1, #drags do
            imguiIds[j] = "##" .. id .. "_" .. j
        end
    end

    local values = {}
    local anyChanged = false
    local dragIndex = 0
    local skipUntil = 0
    local ctrlReveal = not opts.suppressCtrlReveal and utils.isCtrlHeld() and not ImGui.IsAnyItemActive()

    for i = 1, #drags do
        -- Skip elements merged into a previous progress bar
        if i <= skipUntil then goto continueDragLoop end

        local el = drags[i]

        if el.type == "button" then
            local btnWidth = widths[i]

            -- Cross-element progress: replace button with progress bar
            if el.progressFrom then
                local progress = controls.getHoldProgress(el.progressFrom)
                if progress then
                    controls.ProgressBar(progress, btnWidth, 0, "", el.progressStyle or "danger")
                    if el.tooltip then tooltips.Show(el.tooltip) end
                    if i < #drags then ImGui.SameLine() end
                    goto continueDragLoop
                end
            end

            -- Label-to-value: hoverLabel reveals on hover/Ctrl (same pattern as drag labels)
            local btnIcon = el.icon and resolveIcon(el.icon)
            local btnLabel
            if el.hoverLabel then
                local wasHovered = hovered and hovered[i]
                if wasHovered or ctrlReveal then
                    btnLabel = el.hoverLabel
                else
                    btnLabel = btnIcon or el.label or ""
                end
            else
                btnLabel = btnIcon or el.label or ""
            end

            -- Disabled styling for buttons (matches drag disabled look)
            -- Skip for transparent buttons (invisible spacers should stay invisible)
            local btnDisabled = el.style ~= "transparent" and (el.disabled or opts.disabled)
            if btnDisabled then
                styles.PushDragDisabled()
                -- Disabled: render raw ImGui.Button so PushDragDisabled colors show through
                ImGui.Button(btnLabel, btnWidth, 0)
            elseif el.holdDuration then
                local btnId = el.id or (imguiIds and imguiIds[i] or ("##" .. id .. "_" .. i))
                local triggered = controls.HoldButton(btnId, btnLabel, {
                    duration = el.holdDuration,
                    style = el.style or "inactive",
                    width = btnWidth,
                    progressDisplay = el.progressDisplay,
                })
                if triggered and el.onClick then el.onClick(i) end
            else
                local clicked = controls.Button(btnLabel, el.style or "inactive", btnWidth)
                if clicked and el.onClick then el.onClick(i) end
            end

            -- Track hover for hoverLabel next frame
            if hovered and el.hoverLabel then
                hovered[i] = ImGui.IsItemHovered() or ImGui.IsItemActive()
            end

            if btnDisabled then
                styles.PopDragDisabled()
            end

            if el.tooltip then tooltips.Show(el.tooltip) end
        else
            dragIndex = dragIndex + 1
            local elMin = el.min or opts.min or -math.huge
            local elMax = el.max or opts.max or math.huge
            local isInt = el.type == "int"
            local format = el.format or (isInt and "%d" or defaultFormat)
            local baseSpeed = el.speed or opts.speed or defaultSpeed or ((elMax - elMin) / 200)

            -- Delta mode: feed accumulated value while active, 0 when idle
            -- Supports per-element delta via el.mode or row-level via opts.mode
            local elIsDelta = (el.mode == "delta") or isDelta
            local inputValue
            if elIsDelta then
                inputValue = deltaAccum and deltaAccum[i] or 0
            else
                inputValue = el.value or 0
            end
            if isInt then inputValue = math.floor(inputValue + 0.5) end

            -- Label-to-value: show label when idle, value when hovered/active or Ctrl held (not while dragging)
            -- Skip for truly disabled elements (they always show their label)
            local wasHovered = hovered and hovered[i]
            local dim = el.disabled or opts.disabled
            local trulyDisabled = dim == true
            local displayFormat = format
            if el.label and (trulyDisabled or (not wasHovered and not ctrlReveal)) then
                displayFormat = el.label
            end

            -- Cross-element progress: replace consecutive drags sharing the same
            -- progressFrom with a single progress bar spanning their combined width
            if el.progressFrom then
                local progress = controls.getHoldProgress(el.progressFrom)
                if progress then
                    local totalW = widths[i]
                    local lastMerged = i
                    for j = i + 1, #drags do
                        local nextEl = drags[j]
                        if nextEl.type == "button" or nextEl.progressFrom ~= el.progressFrom then break end
                        totalW = totalW + spacing + widths[j]
                        lastMerged = j
                    end
                    controls.ProgressBar(progress, totalW, 0, "", el.progressStyle or "danger")
                    -- Fill return values for all merged elements
                    for j = i, lastMerged do
                        if drags[j].type ~= "button" then
                            dragIndex = dragIndex + 1
                            local jDelta = (drags[j].mode == "delta") or isDelta
                            values[dragIndex] = jDelta and 0 or (drags[j].value or 0)
                        end
                    end
                    skipUntil = lastMerged
                    if lastMerged < #drags then ImGui.SameLine() end
                    goto continueDragLoop
                end
            end

            -- Style selection: disabled variants use previous-frame hover for transitions
            local styleType = styles.PushDragStyle(el, dim, wasHovered)

            ImGui.SetNextItemWidth(widths[i])
            local dragId = imguiIds and imguiIds[i] or ("##" .. id .. "_" .. i)
            local elDragFn = isInt and ImGui.DragInt or dragFn
            local newValue, changed = elDragFn(
                dragId,
                inputValue,
                getDragSpeed(baseSpeed, opts),
                elMin, elMax,
                displayFormat
            )

            local isActive = ImGui.IsItemActive()

            -- Track hover/active for next frame
            if hovered then
                hovered[i] = ImGui.IsItemHovered() or isActive
            end

            styles.PopDragStyle(styleType, trulyDisabled)

            -- Right-click reset
            if el.default ~= nil and ImGui.IsItemClicked(1) then
                if elIsDelta then
                    if el.onReset then
                        el.onReset(el.key)
                    elseif opts.onReset then
                        opts.onReset(dragIndex, el.key)
                    end
                else
                    newValue = el.default
                    changed = true
                end
            end

            if el.tooltip then tooltips.Show(el.tooltip) end

            if elIsDelta then
                if changed then
                    if deltaAccum then deltaAccum[i] = newValue end
                    anyChanged = true
                    local delta = newValue - inputValue
                    if el.onChange then
                        el.onChange(delta, el.key)
                    elseif opts.onChange then
                        opts.onChange(dragIndex, delta, el.key)
                    end
                    values[dragIndex] = delta
                else
                    if not isActive and deltaAccum and deltaAccum[i] then
                        deltaAccum[i] = nil
                    end
                    values[dragIndex] = 0
                end
            else
                local outValue = changed and newValue or (el.value or 0)
                values[dragIndex] = outValue

                if changed then
                    anyChanged = true
                    if el.onChange then
                        el.onChange(newValue, el.key)
                    elseif opts.onChange then
                        opts.onChange(dragIndex, newValue, el.key)
                    end
                end
            end
        end

        if i < #drags then
            ImGui.SameLine()
        end
        ::continueDragLoop::
    end

    -- Cache button group widths for widthFrom references in other rows
    local groupSeen = nil
    for i = 1, #drags do
        local gid = drags[i].groupId
        if gid then
            if not groupSeen then groupSeen = {} end
            if not groupSeen[gid] then
                groupSeen[gid] = { total = 0, count = 0 }
            end
            local g = groupSeen[gid]
            g.total = g.total + widths[i]
            g.count = g.count + 1
        end
    end
    if groupSeen then
        for gid, g in pairs(groupSeen) do
            buttonGroupWidths[gid] = g.total + (g.count - 1) * spacing
        end
    end

    if customSpacing then
        ImGui.PopStyleVar()
    end

    return values, anyChanged
end

--- Create a float drag control with Shift precision (icon, id, value, min, max, opts)
---@param icon string|nil Icon glyph or IconGlyphs key (nil to hide)
---@param id string Unique ImGui ID suffix
---@param value number Current value
---@param min number Minimum value
---@param max number Maximum value
---@param opts? table {speed?, format?, tooltip?, cols?, default?, precisionMultiplier?, noPrecision?}
---@return number newValue Updated value
---@return boolean changed True if the value was modified
function controls.DragFloat(icon, id, value, min, max, opts)
    opts = opts or {}
    local baseSpeed = opts.speed or ((max - min) / 200)
    local format = opts.format or "%.2f"
    local hasIcon = iconPrefix(icon, opts.tooltip, true)
    ImGui.SetNextItemWidth(calcControlWidth(opts.cols, hasIcon))
    styles.PushOutlined()
    local newValue, changed = ImGui.DragFloat("##" .. id, value, getDragSpeed(baseSpeed, opts), min, max, format)
    styles.PopOutlined()
    if opts.default ~= nil and ImGui.IsItemClicked(1) then
        newValue = opts.default
        changed = true
    end
    return newValue, changed
end

--- Create an integer drag control with Shift precision (icon, id, value, min, max, opts)
---@param icon string|nil Icon glyph or IconGlyphs key (nil to hide)
---@param id string Unique ImGui ID suffix
---@param value integer Current value
---@param min integer Minimum value
---@param max integer Maximum value
---@param opts? table {speed?, format?, tooltip?, cols?, default?, precisionMultiplier?, noPrecision?}
---@return integer newValue Updated value
---@return boolean changed True if the value was modified
function controls.DragInt(icon, id, value, min, max, opts)
    opts = opts or {}
    local baseSpeed = opts.speed or 0.5
    local format = opts.format or "%d"
    local hasIcon = iconPrefix(icon, opts.tooltip, true)
    ImGui.SetNextItemWidth(calcControlWidth(opts.cols, hasIcon))
    styles.PushOutlined()
    local newValue, changed = ImGui.DragInt("##" .. id, value, getDragSpeed(baseSpeed, opts), min, max, format)
    styles.PopOutlined()
    if opts.default ~= nil and ImGui.IsItemClicked(1) then
        newValue = opts.default
        changed = true
    end
    return newValue, changed
end

--- Create a row of float drag inputs with color theming, width weighting, and Shift precision.
--- Thin wrapper around renderDragRow using ImGui.DragFloat.
---@param icon string|nil Icon glyph prefix (nil = no icon)
---@param id string Base ImGui ID (each drag appends its index)
---@param drags table Array of Drag_Definitions and/or Button_Definitions
---@param opts? table Row-level options (cols, speed, min, max, spacing, mode, onChange, etc.)
---@return table values New values (one per drag element, buttons excluded)
---@return boolean anyChanged True if any drag value changed
function controls.DragFloatRow(icon, id, drags, opts)
    return renderDragRow(icon, id, drags, opts, ImGui.DragFloat, "%.2f", nil)
end

--- Create a row of integer drag inputs with color theming, width weighting, and Shift precision.
--- Thin wrapper around renderDragRow using ImGui.DragInt.
---@param icon string|nil Icon glyph prefix (nil = no icon)
---@param id string Base ImGui ID (each drag appends its index)
---@param drags table Array of Drag_Definitions and/or Button_Definitions
---@param opts? table Row-level options (cols, speed, min, max, spacing, mode, onChange, etc.)
---@return table values New values (one per drag element, buttons excluded)
---@return boolean anyChanged True if any drag value changed
function controls.DragIntRow(icon, id, drags, opts)
    return renderDragRow(icon, id, drags, opts, ImGui.DragInt, "%d", 0.5)
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
-- Swatch Grid (sort/cache helper)
--------------------------------------------------------------------------------

-- Saturation below this threshold is considered neutral/achromatic
local NEUTRAL_SAT_THRESHOLD = 0.12

-- Sort comparators keyed by mode name.
local swatchSortComparators = {}

--- Perceived chroma accounting for lightness (ported from SDH0GarageManager).
--- Light colors approaching white lose their color; dark colors retain hue.
local function getPerceivedChroma(s, l)
    if l > 0.5 then
        local w = 1 - (l - 0.5) * 2
        if w < 0 then w = 0 end
        return s * (0.15 + 0.85 * w)
    else
        local w = l * 2
        return s * (0.6 + 0.4 * w)
    end
end

-- "hue": Neutrals first by luminance, then chromatic by hue band then luminance.
swatchSortComparators.hue = function(a, b)
    if a._neutral ~= b._neutral then return a._neutral end
    if a._neutral then return a._luma < b._luma end
    if a._hueBand ~= b._hueBand then return a._hueBand < b._hueBand end
    return a._luma < b._luma
end

-- "lightness": Luminance bands (8 bands) with hue flow within each band.
-- Gives a smooth dark-to-light gradient where colors at similar brightness
-- are grouped by hue instead of jumping between unrelated hues.
swatchSortComparators.lightness = function(a, b)
    if a._lumaBand ~= b._lumaBand then return a._lumaBand < b._lumaBand end
    if a._hueBand ~= b._hueBand then return a._hueBand < b._hueBand end
    return a._luma < b._luma
end


--- Build or retrieve cached swatch data: sorted order, pre-computed RGB, category breaks.
--- @param id string Grid instance ID for cache keying
--- @param colors table Array of Color_Entry tables
--- @param sortMode string|boolean|nil Sort mode: false/nil/"none", true/"hue", "lightness"
--- @return table {sorted, colorData, categoryBreaks, breakLabels}
local function getSwatchData(id, colors, sortMode)
    -- Normalize sortMode: true -> "hue", false/nil -> "none"
    if sortMode == true then sortMode = "hue"
    elseif not sortMode then sortMode = "none"
    end

    local count = #colors

    -- Detect whether any entry has a category field
    local hasCategories = false
    for i = 1, count do
        if colors[i].category then
            hasCategories = true
            break
        end
    end

    -- Quick staleness check
    local quick = swatchSortQuickCheck[id]
    if quick and quick.count == count and quick.hasCategories == hasCategories and quick.sortMode == sortMode then
        local cached = swatchSortCache[quick.cacheKey]
        if cached then return cached end
    end

    -- Full fingerprint
    local hexParts = {}
    for i = 1, count do
        hexParts[i] = colors[i].hex or ""
    end
    local fingerprint = table.concat(hexParts, ",") .. ":" .. sortMode

    local cached = swatchSortCache[fingerprint]
    if cached then
        swatchSortQuickCheck[id] = { count = count, hasCategories = hasCategories, sortMode = sortMode, cacheKey = fingerprint }
        return cached
    end

    -- Cache miss: build pre-computed color data for each entry
    local entries = {}
    for i = 1, count do
        local c = colors[i]
        local r, g, b = utils.HexToRGB(c.hex)
        local h, s, l = utils.RGBToHSL(r, g, b)
        local chroma = getPerceivedChroma(s, l)
        local luma = r * 0.299 + g * 0.587 + b * 0.114
        entries[i] = {
            entry = c,
            r = r, g = g, b = b,
            h = h, s = s, l = l,
            _luma = luma,
            _lumaBand = math.floor(luma * 8),
            _neutral = chroma < 0.15,
            -- Offset hue by half a band so reds (hue near 0 and near 1) share band 0
            _hueBand = math.floor(((h + 1/24) % 1) * 12),
            origIndex = i,
        }
    end

    local cmp = swatchSortComparators[sortMode]

    -- Group entries by category, preserving encounter order
    local categoryOrder = {}
    local categoryGroups = {}
    for i = 1, #entries do
        local cat = entries[i].entry.category
        if cat then
            if not categoryGroups[cat] then
                categoryGroups[cat] = {}
                categoryOrder[#categoryOrder + 1] = cat
            end
            categoryGroups[cat][#categoryGroups[cat] + 1] = entries[i]
        else
            if not categoryGroups[""] then
                categoryGroups[""] = {}
                categoryOrder[#categoryOrder + 1] = ""
            end
            categoryGroups[""][#categoryGroups[""] + 1] = entries[i]
        end
    end

    -- Sort within each category group
    if cmp then
        for _, cat in ipairs(categoryOrder) do
            table.sort(categoryGroups[cat], cmp)
        end
    end

    -- Build output arrays
    local sorted = {}
    local colorData = {}
    local categoryBreaks = {}

    for _, cat in ipairs(categoryOrder) do
        local group = categoryGroups[cat]
        if cat ~= "" then
            categoryBreaks[#categoryBreaks + 1] = { index = #sorted + 1, label = cat }
        end
        for j = 1, #group do
            local e = group[j]
            sorted[#sorted + 1] = e.entry
            colorData[#colorData + 1] = { r = e.r, g = e.g, b = e.b }
        end
    end

    -- Build break label lookup (cached with the result)
    local breakLabels = nil
    if #categoryBreaks > 0 then
        breakLabels = {}
        for _, brk in ipairs(categoryBreaks) do
            breakLabels[brk.index] = brk.label
        end
    end

    local result = {
        sorted = sorted,
        colorData = colorData,
        categoryBreaks = categoryBreaks,
        breakLabels = breakLabels,
    }

    swatchSortCache[fingerprint] = result
    swatchSortQuickCheck[id] = { count = count, hasCategories = hasCategories, sortMode = sortMode, cacheKey = fingerprint }

    return result
end

--------------------------------------------------------------------------------
-- Swatch Grid
--------------------------------------------------------------------------------

-- Defaults for SwatchGrid config (1080p baseline, scaled internally)
local SWATCH_DEFAULTS = {
    swatchSize    = 24,    -- Base swatch size (1080p px); max is always 2x this
    swatchSpacing = 4,
    borderSize    = 2,
    scaleBorder   = false, -- When true, border scales proportionally with swatch size
    sortMode      = false, -- false/"none", true/"hue", "lightness"
}

--- Render a grid of colored swatch buttons.
--- @param id string Unique ImGui ID for this grid instance
--- @param colors table Array of Color_Entry tables
--- @param selectedHex string|nil Hex of the currently selected color (for highlight)
--- @param onSelect function Callback: onSelect(entry) called when a swatch is clicked
--- @param config table|nil Swatch_Config overrides (merged with defaults)
function controls.SwatchGrid(id, colors, selectedHex, onSelect, config)
    if not colors or #colors == 0 then return end

    -- Merge caller config with defaults
    local cfg = SWATCH_DEFAULTS
    if config then
        cfg = {}
        for k, v in pairs(SWATCH_DEFAULTS) do cfg[k] = v end
        for k, v in pairs(config) do cfg[k] = v end
    end

    -- Resolve sort mode
    local sortMode = cfg.sortMode or false

    -- Scale pixel values to current resolution
    local minSize   = Scaled(cfg.swatchSize)
    local maxSize   = minSize * 2
    local spacing   = Scaled(cfg.swatchSpacing)
    local baseBorder = cfg.borderSize * (frameCache.displayHeight / 1080)

    -- Retrieve cached sort data
    local data = getSwatchData(id, colors, sortMode)
    local sorted = data.sorted
    local colorData = data.colorData
    local breakLabels = data.breakLabels

    -- Dynamic column calculation
    local availWidth = ImGui.GetContentRegionAvail()
    local perRow = math.max(1, math.floor((availWidth + spacing) / (minSize + spacing)))
    local swatchSize = math.min(maxSize, (availWidth - (perRow - 1) * spacing) / perRow)

    -- Scale border with swatch size if enabled (baseline: borderSize 2 at swatchSize 24)
    local borderSize = baseBorder
    if cfg.scaleBorder then
        borderSize = math.max(0.5, baseBorder * (cfg.swatchSize / 24))
    end

    local col = 0

    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, spacing, spacing)

    for i = 1, #sorted do
        local entry = sorted[i]
        local cd = colorData[i]
        local r, g, b = cd.r, cd.g, cd.b

        -- Category separator at group boundaries
        if breakLabels then
            local label = breakLabels[i]
            if label then
                if col > 0 then col = 0 end
                if i > 1 then ImGui.Spacing() end
                ImGui.TextDisabled(label)
                ImGui.Separator()
                ImGui.Spacing()
            end
        end

        -- SameLine between swatches on the same row
        if col > 0 then
            ImGui.SameLine()
        end

        local isSelected = selectedHex and entry.hex == selectedHex

        -- Push button colors from cached RGB
        if isSelected then
            ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(r, g, b, 1))
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(r, g, b, 1))
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(r, g, b, 1))
            ImGui.PushStyleColor(ImGuiCol.Border, ImGui.GetColorU32(0, 1, 1, 1))
            ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, borderSize)
        else
            ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(r, g, b, 1))
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(r * 1.2, g * 1.2, b * 1.2, 1))
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(r * 0.8, g * 0.8, b * 0.8, 1))
            ImGui.PushStyleColor(ImGuiCol.Border, ImGui.GetColorU32(0.3, 0.3, 0.3, 0.5))
            ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 1)
        end

        if ImGui.Button("##swatch_" .. id .. "_" .. i, swatchSize, swatchSize) then
            onSelect(entry)
        end

        ImGui.PopStyleVar(1)
        ImGui.PopStyleColor(4)

        -- Tooltip on hover
        if ImGui.IsItemHovered() then
            local displayName = entry.displayName or entry.name
            tooltips.ShowColor(r, g, b, displayName, entry.hex)
        end

        col = col + 1
        if col >= perRow then
            col = 0
        end
    end

    ImGui.PopStyleVar(1)

    -- Ensure new line after partial row
    if col > 0 then
        ImGui.NewLine()
    end
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
---@param iconGlyph? table HeaderIconGlyph opts table
---@return nil
function controls.SectionHeader(label, spacingBefore, spacingAfter, iconGlyph)
    if spacingBefore then
        ImGui.Dummy(0, spacingBefore)
    end
    ImGui.Separator()
    ImGui.Text(label)
    if type(iconGlyph) == "table" then
        controls.HeaderIconGlyph(iconGlyph)
    end
    if spacingAfter then
        ImGui.Dummy(0, spacingAfter)
    end
end

--- Render a right-justified icon glyph on the current ImGui line.
--- Intended for use after header/section header text to show contextual icons.
--- Uses a frameless button when onClick is provided so clicks register in CET.
---@param opts table {icon: string, tooltip?: string, color?: table, visible?: boolean, onClick?: function}
function controls.HeaderIconGlyph(opts)
    if not IconGlyphs then return end
    if opts.visible == false then return end

    local icon = utils.resolveIcon(opts.icon)
    if not icon then return end

    local iconWidth = ImGui.CalcTextSize(icon)
    ImGui.SameLine(ImGui.GetWindowWidth() - iconWidth - frameCache.itemSpacingX)

    if opts.color then
        ImGui.PushStyleColor(ImGuiCol.Text, opts.color[1], opts.color[2], opts.color[3], opts.color[4])
    end

    local clicked = false
    if opts.onClick then
        styles.PushButtonFrameless()
        clicked = ImGui.Button(icon)
        styles.PopButtonFrameless()
    else
        ImGui.Text(icon)
    end

    if opts.color then
        ImGui.PopStyleColor()
    end

    if clicked then
        opts.onClick()
    end

    if opts.tooltip then
        if opts.alwaysShowTooltip then
            tooltips.ShowAlways(opts.tooltip)
        else
            tooltips.Show(opts.tooltip)
        end
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

--------------------------------------------------------------------------------
-- Bind Dispatcher (shared logic for SliderFloat, SliderInt, Combo, InputText,
-- InputFloat, InputInt)
--------------------------------------------------------------------------------

local bindDispatch = {
    SliderFloat = { fn = controls.SliderFloat, hasMinMax = true,  hasItems = false, hasTransform = true,  hasPercent = true  },
    SliderInt   = { fn = controls.SliderInt,   hasMinMax = true,  hasItems = false, hasTransform = true,  hasPercent = true  },
    DragFloat   = { fn = controls.DragFloat,   hasMinMax = true,  hasItems = false, hasTransform = true,  hasPercent = true  },
    DragInt     = { fn = controls.DragInt,      hasMinMax = true,  hasItems = false, hasTransform = true,  hasPercent = true  },
    Combo       = { fn = controls.Combo,       hasMinMax = false, hasItems = true,  hasTransform = true,  hasPercent = false },
    InputText   = { fn = controls.InputText,   hasMinMax = false, hasItems = false, hasTransform = false, hasPercent = false },
    InputFloat  = { fn = controls.InputFloat,  hasMinMax = false, hasItems = false, hasTransform = false, hasPercent = false },
    InputInt    = { fn = controls.InputInt,     hasMinMax = false, hasItems = false, hasTransform = false, hasPercent = false },
}

--- Generic bind dispatcher. Handles def resolution, search dimming, transform,
--- percent format, default resolution, control call, onChange/onSave, and endDim.
---@param self table Bind context
---@param controlType string Key into bindDispatch
---@param icon string|nil Icon glyph or IconGlyphs key
---@param key string Data table key
---@param arg3 any min (sliders), items (combo), or nil (inputs)
---@param arg4 any max (sliders) or nil
---@param opts table|nil Control options
local function bindControl(self, controlType, icon, key, arg3, arg4, opts)
    opts = opts or {}
    local entry = bindDispatch[controlType]
    local def = self.defs and self.defs[key]

    -- Resolve def fields when call arguments are nil
    if def then
        if not icon and def.icon then icon = def.icon end
        if entry.hasMinMax then
            if not arg3 and def.min then arg3 = def.min end
            if not arg4 and def.max then arg4 = def.max end
        end
        if entry.hasItems then
            if not arg3 and def.items then arg3 = def.items end
        end
    end

    local opts2, dimmed = applyDefAndSearch(self, key, opts)
    local t = entry.hasTransform and opts2.transform or nil

    -- Percent format (sliders only)
    if entry.hasPercent and opts2.percent then
        local pct = (self.data[key] - arg3) / (arg4 - arg3) * 100
        opts2.format = string.format("%.0f%%%%", pct)
    end

    -- Default resolution with optional transform read
    if self.defaults and self.defaults[key] ~= nil and opts2.default == nil then
        opts2.default = t and t.read(self.defaults[key]) or self.defaults[key]
    end

    -- Display value and control call
    local newValue, changed
    if entry.hasMinMax then
        local displayValue = t and t.read(self.data[key]) or self.data[key]
        newValue, changed = entry.fn(icon, self.idPrefix .. key, displayValue, arg3, arg4, opts2)
    elseif entry.hasItems then
        local displayValue = t and t.read(self.data[key]) or self.data[key]
        newValue, changed = entry.fn(icon, self.idPrefix .. key, displayValue, arg3, opts2)
    else
        newValue, changed = entry.fn(icon, self.idPrefix .. key, self.data[key], opts2)
    end

    -- Write back and fire callbacks
    if changed then
        self.data[key] = t and t.write(newValue) or newValue
        if self.onSave then self.onSave() end
        local onChange = opts2.onChange or (def and def.onChange)
        if onChange then onChange(self.data[key], key) end
    end

    endDim(dimmed)
    return newValue, changed
end

--- Bound float slider. Reads/writes data[key], resets to defaults[key] on right-click.
---@param icon string|nil Icon glyph or IconGlyphs key
---@param key string Data table key
---@param min number Minimum value
---@param max number Maximum value
---@param opts? table {format?, tooltip?, cols?, default?, transform?, percent?, onChange?}
---@return number newValue
---@return boolean changed
function bindMethods:SliderFloat(icon, key, min, max, opts)
    return bindControl(self, "SliderFloat", icon, key, min, max, opts)
end

--- Bound integer slider. Reads/writes data[key], resets to defaults[key] on right-click.
---@param icon string|nil Icon glyph or IconGlyphs key
---@param key string Data table key
---@param min integer Minimum value
---@param max integer Maximum value
---@param opts? table {format?, tooltip?, cols?, default?, transform?, percent?, onChange?}
---@return integer newValue
---@return boolean changed
function bindMethods:SliderInt(icon, key, min, max, opts)
    return bindControl(self, "SliderInt", icon, key, min, max, opts)
end

--- Bound float drag. Reads/writes data[key], resets to defaults[key] on right-click.
--- Hold Shift for precision mode.
---@param icon string|nil Icon glyph or IconGlyphs key
---@param key string Data table key
---@param min number Minimum value
---@param max number Maximum value
---@param opts? table {speed?, format?, tooltip?, cols?, default?, transform?, percent?, precisionMultiplier?, noPrecision?, onChange?}
---@return number newValue
---@return boolean changed
function bindMethods:DragFloat(icon, key, min, max, opts)
    return bindControl(self, "DragFloat", icon, key, min, max, opts)
end

--- Bound integer drag. Reads/writes data[key], resets to defaults[key] on right-click.
--- Hold Shift for precision mode.
---@param icon string|nil Icon glyph or IconGlyphs key
---@param key string Data table key
---@param min integer Minimum value
---@param max integer Maximum value
---@param opts? table {speed?, format?, tooltip?, cols?, default?, transform?, percent?, precisionMultiplier?, noPrecision?, onChange?}
---@return integer newValue
---@return boolean changed
function bindMethods:DragInt(icon, key, min, max, opts)
    return bindControl(self, "DragInt", icon, key, min, max, opts)
end

--- Shared bind DragRow implementation.
---@param self table Bind context
---@param icon string|nil
---@param keys table Array of data keys
---@param min number
---@param max number
---@param opts table
---@param controlFn function controls.DragFloatRow or controls.DragIntRow
---@return table values, boolean anyChanged
local function bindDragRow(self, icon, keys, min, max, opts, controlFn)
    local isDelta = opts.mode == "delta"

    -- Resolve def-driven row config
    local defRow = opts.def and self.defs and self.defs[opts.def]
    if defRow then
        for k, v in pairs(defRow) do
            if opts[k] == nil then opts[k] = v end
        end
    end

    -- Search dimming on first key
    local dimmed = false
    if self.search and not self.search:isEmpty() then
        local def = self.defs and self.defs[keys[1]]
        local terms = ""
        if def then
            if def.label then terms = def.label end
            if def.searchTerms then terms = terms .. " " .. def.searchTerms end
            if def.tooltip and (self.searchTooltips or not def.label) then
                terms = terms .. " " .. def.tooltip
            end
        end
        if terms ~= "" and not self.search:matches(keys[1], terms) then
            ImGui.PushStyleVar(ImGuiStyleVar.Alpha, self.search.dimAlpha)
            dimmed = true
        end
    end

    -- Build drags array from keys
    local drags = {}
    local optsDrags = opts.drags
    for i, key in ipairs(keys) do
        local drag = {
            value = isDelta and 0 or (self.data[key] or 0),
            min = min,
            max = max,
            key = key,
        }
        if self.defaults and self.defaults[key] ~= nil then
            drag.default = self.defaults[key]
        end
        if optsDrags and optsDrags[i] then
            for k, v in pairs(optsDrags[i]) do
                drag[k] = v
            end
        end
        drags[i] = drag
    end

    -- Delta mode reset callback (cached on context)
    if isDelta and self.defaults then
        if not self._dragRowOnReset then
            local data = self.data
            local defaults = self.defaults
            local onSave = self.onSave
            self._dragRowOnReset = function(index, key)
                if key and defaults[key] ~= nil then
                    data[key] = defaults[key]
                    if onSave then onSave() end
                end
            end
        end
        opts.onReset = self._dragRowOnReset
    end

    opts.drags = nil

    -- Per-row state lives on the data table (persists across frames regardless of bind context lifetime)
    -- Cache a unique ID prefix on the data table (computed once from table address)
    local dataPrefix = self.data._uid
    if not dataPrefix then
        dataPrefix = tostring(self.data):sub(8) .. "_"  -- strip "table: " prefix
        self.data._uid = dataPrefix
    end
    local rowId = self.idPrefix .. dataPrefix .. (opts.id or keys[1]) .. "_row"
    local drs = self.data._drs
    if not drs then
        drs = {}
        self.data._drs = drs
    end
    if not drs[rowId] then drs[rowId] = {} end
    opts._state = drs[rowId]

    local values, anyChanged = controlFn(icon, rowId, drags, opts)

    if anyChanged then
        if isDelta then
            if opts.onChange then opts.onChange(values, keys) end
        else
            for i, key in ipairs(keys) do
                if values[i] and values[i] ~= self.data[key] then
                    self.data[key] = values[i]
                end
            end
            if self.onSave then self.onSave() end
        end
    end

    endDim(dimmed)
    return values, anyChanged
end

--- Bound float drag row. Reads data[key] for each key, writes back on change.
--- In delta mode, calls opts.onChange(values, keys) instead of auto-writing.
---@param icon string|nil Icon glyph or IconGlyphs key
---@param keys table Array of data table keys (e.g. {"x", "y", "z"})
---@param min number Minimum value
---@param max number Maximum value
---@param opts? table {drags?, speed?, cols?, mode?, onChange?, def?, tooltip?, precisionMultiplier?, noPrecision?, spacing?}
---@return table values New values (one per drag)
---@return boolean anyChanged True if any drag value changed
function bindMethods:DragFloatRow(icon, keys, min, max, opts)
    return bindDragRow(self, icon, keys, min, max, opts or {}, controls.DragFloatRow)
end

--- Bound integer drag row. Same as DragFloatRow but calls controls.DragIntRow.
---@param icon string|nil Icon glyph or IconGlyphs key
---@param keys table Array of data table keys
---@param min integer Minimum value
---@param max integer Maximum value
---@param opts? table {drags?, speed?, cols?, mode?, onChange?, def?, tooltip?, precisionMultiplier?, noPrecision?, spacing?}
---@return table values New values (one per drag)
---@return boolean anyChanged True if any drag value changed
function bindMethods:DragIntRow(icon, keys, min, max, opts)
    return bindDragRow(self, icon, keys, min, max, opts or {}, controls.DragIntRow)
end

--- Bound checkbox. Reads/writes data[key], resets to defaults[key] on right-click.
---@param label string Checkbox label text
---@param key string Data table key
---@param opts? table {icon?, default?, tooltip?, alwaysShowTooltip?, onChange?}
---@return boolean newValue
---@return boolean changed
function bindMethods:Checkbox(label, key, opts)
    opts = opts or {}
    local def = self.defs and self.defs[key]
    local opts2, dimmed = applyDefAndSearch(self, key, opts, label)
    if self.defaults and self.defaults[key] ~= nil and opts2.default == nil then
        opts2.default = self.defaults[key]
    end
    local newValue, changed = controls.Checkbox(label, self.data[key], opts2)
    if changed then
        self.data[key] = newValue
        if self.onSave then self.onSave() end
        local onChange = opts2.onChange or (def and def.onChange)
        if onChange then onChange(newValue, key) end
    end
    endDim(dimmed)
    return newValue, changed
end

--- Bound color picker. Reads/writes data[key], resets to defaults[key] on right-click.
---@param icon string|nil Icon glyph or IconGlyphs key
---@param key string Data table key
---@param opts? table {tooltip?, label?, default?, onChange?}
---@return table newColor
---@return boolean changed
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
        local onChange = opts2.onChange or (def and def.onChange)
        if onChange then onChange(newValue, key) end
    end
    endDim(dimmed)
    return newValue, changed
end

--- Bound swatch grid. Reads data[key] as selected hex, writes back on selection.
--- Right-click on the grid area resets to defaults[key].
---@param key string Data table key (value is a hex string)
---@param colors table Array of Color_Entry tables
---@param opts? table {config?: Swatch_Config, onChange?: function}
function bindMethods:SwatchGrid(key, colors, opts)
    opts = opts or {}
    local self_ = self

    ImGui.BeginGroup()
    controls.SwatchGrid(self.idPrefix .. key, colors, self.data[key], function(entry)
        self_.data[key] = entry.hex
        if self_.onSave then self_.onSave() end
        if opts.onChange then opts.onChange(entry, key) end
    end, opts.config)
    ImGui.EndGroup()

    -- Right-click reset to default
    if ImGui.IsItemClicked(1) and self.defaults and self.defaults[key] ~= nil
        and self.data[key] ~= self.defaults[key] then
        self.data[key] = self.defaults[key]
        if self.onSave then self.onSave() end
    end
end

--- Bound combo dropdown. Reads/writes data[key], resets to defaults[key] on right-click.
---@param icon string|nil Icon glyph or IconGlyphs key
---@param key string Data table key
---@param items table Array of string labels
---@param opts? table {tooltip?, cols?, default?, transform?, onChange?}
---@return integer newIndex
---@return boolean changed
function bindMethods:Combo(icon, key, items, opts)
    return bindControl(self, "Combo", icon, key, items, nil, opts)
end

--- Bound text input. Reads/writes data[key], resets to defaults[key] on right-click.
---@param icon string|nil Icon glyph or IconGlyphs key
---@param key string Data table key
---@param opts? table {maxLength?, tooltip?, alwaysShowTooltip?, cols?, onChange?}
---@return string newText
---@return boolean changed
function bindMethods:InputText(icon, key, opts)
    return bindControl(self, "InputText", icon, key, nil, nil, opts)
end

--- Bound float input. Reads/writes data[key], resets to defaults[key] on right-click.
---@param icon string|nil Icon glyph or IconGlyphs key
---@param key string Data table key
---@param opts? table {step?, stepFast?, format?, tooltip?, alwaysShowTooltip?, cols?, onChange?}
---@return number newValue
---@return boolean changed
function bindMethods:InputFloat(icon, key, opts)
    return bindControl(self, "InputFloat", icon, key, nil, nil, opts)
end

--- Bound integer input. Reads/writes data[key], resets to defaults[key] on right-click.
---@param icon string|nil Icon glyph or IconGlyphs key
---@param key string Data table key
---@param opts? table {step?, stepFast?, tooltip?, alwaysShowTooltip?, cols?, onChange?}
---@return integer newValue
---@return boolean changed
function bindMethods:InputInt(icon, key, opts)
    return bindControl(self, "InputInt", icon, key, nil, nil, opts)
end

--- Bound toggle button row. Each def toggles data[def.key] on click, resets on right-click.
---@param defs table Array of button defs: {key, icon?, label?, weight?, tooltip?, onChange?}
---@param opts? table {gap?, id?}
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
---@param iconGlyph? table HeaderIconGlyph opts table
function bindMethods:Header(text, category, iconGlyph)
    local dimmed = false
    if self.search and self.defs and category and not self.search:isEmpty() then
        if not self.search:categoryHasMatch(category, self.defs, self.searchTooltips) then
            ImGui.PushStyleVar(ImGuiStyleVar.Alpha, self.search.dimAlpha)
            dimmed = true
        end
    end
    ImGui.Text(text)
    if type(iconGlyph) == "table" then
        controls.HeaderIconGlyph(iconGlyph)
    end
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
---@param iconGlyph? table HeaderIconGlyph opts table
function bindMethods:SectionHeader(text, category, spacingBefore, spacingAfter, iconGlyph)
    local dimmed = false
    if self.search and self.defs and category and not self.search:isEmpty() then
        if not self.search:categoryHasMatch(category, self.defs, self.searchTooltips) then
            ImGui.PushStyleVar(ImGuiStyleVar.Alpha, self.search.dimAlpha)
            dimmed = true
        end
    end
    controls.SectionHeader(text, spacingBefore, spacingAfter, iconGlyph)
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
    ctx._dragRowOnReset = nil
    bindPoolSize = bindPoolSize + 1
    bindPool[bindPoolSize] = ctx
end

--------------------------------------------------------------------------------
-- PanelGroup
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

--------------------------------------------------------------------------------
-- Panel (child window with default styling)
--------------------------------------------------------------------------------

-- Cache for auto-height panels (measured on previous frame)
local panelAutoHeight = {}

--- Render a child window panel with default styling (opts: bg, border, width, height, flags)
---@param id string Unique panel ID (## prefix added automatically if missing)
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

    -- Auto-height: use cached content height from previous frame
    if height == "auto" then
        height = panelAutoHeight[id] or 100
    end

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

    -- Measure content height for auto-sizing on next frame
    -- Add bottom window padding so content isn't clipped
    if opts.height == "auto" then
        local padY = ImGui.GetStyle().WindowPadding.y
        local spacingY = ImGui.GetStyle().ItemSpacing.y
        panelAutoHeight[id] = ImGui.GetCursorPosY() + padY - spacingY
    end

    ImGui.EndChild()

    if borderOnHover then
        panelHoverState[id] = ImGui.IsItemHovered()
    end
end

return controls
