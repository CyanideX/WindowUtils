------------------------------------------------------
-- WindowUtils - Controls Drags
-- Drag family: DragFloat, DragInt, DragFloatRow, DragIntRow,
-- computeElementWidths, renderDragRow, getDragSpeed
------------------------------------------------------

local styles = require("modules/styles")
local tooltips = require("modules/tooltips")
local utils = require("modules/utils")
local core = require("modules/controls/core")
local buttons = require("modules/controls/buttons")
local holdbuttons = require("modules/controls/holdbuttons")
local display = require("modules/controls/display")

local frameCache = core.frameCache
local iconPrefix = core.iconPrefix
local cachedCalcTextSize = core.cachedCalcTextSize
local resolveIcon = core.resolveIcon
local buttonGroupWidths = core.buttonGroupWidths

local M = {}

--------------------------------------------------------------------------------
-- Module-local state
--------------------------------------------------------------------------------

local pooledWidths = {}         -- Reused by computeElementWidths (consumed before next call)

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
    if n == 0 then
        -- Clear any stale entry so #pooledWidths returns 0
        pooledWidths[1] = nil
        return pooledWidths
    end

    local totalSpacing = (n - 1) * spacing
    local remaining = availWidth - totalSpacing
    local totalWeight = 0
    local padX2 = frameCache.framePaddingX * 2

    -- First pass: resolve fixed widths, accumulate weights
    for i = 1, n do
        local el = drags[i]
        if el.width then
            pooledWidths[i] = el.width
            remaining = remaining - el.width
        elseif el.widthFrom then
            -- Use cached width from a button group
            local w = buttonGroupWidths[el.widthFrom] or 0
            pooledWidths[i] = w
            remaining = remaining - w
        elseif el.widthPercent then
            -- Percentage of display width
            local w = math.floor(frameCache.displayWidth * el.widthPercent / 100)
            pooledWidths[i] = w
            remaining = remaining - w
        elseif el.fitLabel and el.label then
            -- Fit to label text + frame padding + extra breathing room
            local w = cachedCalcTextSize(el.label) + padX2 + frameCache.charWidth * 2
            pooledWidths[i] = w
            remaining = remaining - w
        elseif el.type == "button" then
            if el.weight then
                -- Weighted button: participates in remaining space distribution
                totalWeight = totalWeight + el.weight
                pooledWidths[i] = 0
            else
                local icon = el.icon and resolveIcon(el.icon)
                local text = icon or el.label or ""
                local w = cachedCalcTextSize(text) + padX2
                pooledWidths[i] = w
                remaining = remaining - w
            end
        else
            totalWeight = totalWeight + (el.weight or 1)
            pooledWidths[i] = 0
        end
    end

    -- Second pass: distribute remaining space by weight
    if totalWeight > 0 and remaining > 0 then
        for i = 1, n do
            if pooledWidths[i] == 0 then
                pooledWidths[i] = math.floor(remaining * (drags[i].weight or 1) / totalWeight)
            end
        end
    end

    -- Clear stale entries from previous calls with more elements
    for i = n + 1, #pooledWidths do
        pooledWidths[i] = nil
    end

    return pooledWidths
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
        availWidth = core.ColWidth(opts.cols, nil, icon ~= nil)
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

    local values = state and state._values or {}
    if state then state._values = values end
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
                local progress = holdbuttons.getHoldProgress(el.progressFrom)
                if progress then
                    display.ProgressBar(progress, btnWidth, 0, "", el.progressStyle or "danger")
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
                local triggered = holdbuttons.HoldButton(btnId, btnLabel, {
                    duration = el.holdDuration,
                    style = el.style or "inactive",
                    width = btnWidth,
                    progressDisplay = el.progressDisplay,
                })
                if triggered and el.onClick then el.onClick(i) end
            else
                local clicked = buttons.Button(btnLabel, el.style or "inactive", btnWidth)
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
                local progress = holdbuttons.getHoldProgress(el.progressFrom)
                if progress then
                    local totalW = widths[i]
                    local lastMerged = i
                    for j = i + 1, #drags do
                        local nextEl = drags[j]
                        if nextEl.type == "button" or nextEl.progressFrom ~= el.progressFrom then break end
                        totalW = totalW + spacing + widths[j]
                        lastMerged = j
                    end
                    display.ProgressBar(progress, totalW, 0, "", el.progressStyle or "danger")
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

    -- Clear stale entries from previous frames with more drag elements
    for i = dragIndex + 1, #values do
        values[i] = nil
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
function M.DragFloat(icon, id, value, min, max, opts)
    opts = opts or {}
    local fmt = opts.format or "%.2f"
    local speed = getDragSpeed(opts.speed or ((max - min) / 200), opts)
    return core.renderIconControl(icon, id, opts, ImGui.DragFloat, value, speed, min, max, fmt)
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
function M.DragInt(icon, id, value, min, max, opts)
    opts = opts or {}
    local fmt = opts.format or "%d"
    local speed = getDragSpeed(opts.speed or 0.5, opts)
    return core.renderIconControl(icon, id, opts, ImGui.DragInt, value, speed, min, max, fmt)
end

--- Create a row of float drag inputs with color theming, width weighting, and Shift precision.
--- Thin wrapper around renderDragRow using ImGui.DragFloat.
---@param icon string|nil Icon glyph prefix (nil = no icon)
---@param id string Base ImGui ID (each drag appends its index)
---@param drags table Array of Drag_Definitions and/or Button_Definitions
---@param opts? table Row-level options (cols, speed, min, max, spacing, mode, onChange, etc.)
---@return table values New values (one per drag element, buttons excluded)
---@return boolean anyChanged True if any drag value changed
function M.DragFloatRow(icon, id, drags, opts)
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
function M.DragIntRow(icon, id, drags, opts)
    return renderDragRow(icon, id, drags, opts, ImGui.DragInt, "%d", 0.5)
end

return M
