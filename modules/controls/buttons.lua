------------------------------------------------------
-- WindowUtils - Controls Buttons
-- Button family: Button, ToggleButton, FullWidthButton, DisabledButton,
-- StatusBar, DynamicButton, ButtonRow, measureButtonDefs
------------------------------------------------------

local styles = require("modules/styles")
local tooltips = require("modules/tooltips")
local core = require("modules/controls/core")

local frameCache = core.frameCache
local resolveIcon = core.resolveIcon
local cachedCalcTextSize = core.cachedCalcTextSize
local cachedTruncateText = core.cachedTruncateText

local buttonRowMinWidths = core.buttonRowMinWidths
local buttonGroupWidths = core.buttonGroupWidths

local M = {}

--------------------------------------------------------------------------------
-- Styled Buttons
--------------------------------------------------------------------------------

--- Create a styled button with automatic push/pop
---@param label string Button label text
---@param styleName? string Style name from styles module (default "inactive")
---@param width? number Button width in pixels (0=auto, negative=fill available width)
---@param height? number Button height in pixels (0=auto, negative=fill available height)
---@return boolean clicked True if the button was clicked
function M.Button(label, styleName, width, height)
    styleName = styleName or "inactive"
    width = width or 0
    height = height or 0
    if width < 0 then width = ImGui.GetContentRegionAvail() end
    if height < 0 then height = select(2, ImGui.GetContentRegionAvail()) end

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
function M.ToggleButton(label, isActive, width, height)
    local styleName = isActive and "active" or "inactive"
    return M.Button(label, styleName, width, height)
end

--- Create a full-width button (fills available width)
---@param label string Button label text
---@param styleName? string Style name from styles module (default "inactive")
---@return boolean clicked True if the button was clicked
function M.FullWidthButton(label, styleName)
    return M.Button(label, styleName, ImGui.GetContentRegionAvail())
end

--- Create a disabled button that cannot be clicked
---@param label string Button label text
---@param width? number Button width in pixels (default 0)
---@param height? number Button height in pixels (default 0)
---@return nil
function M.DisabledButton(label, width, height)
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
function M.StatusBar(label, value, opts)
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

--- Create a button that adapts content based on available width.
--- Normal: full text. Narrow: truncated with "...". Icon mode: icon only.
--- opts.minChars: minimum visible characters before switching to icon (default 3)
--- opts.iconThreshold: explicit pixel override for icon switch threshold
---@param label string Full button label text
---@param icon string|nil Icon glyph or IconGlyphs key for narrow display
---@param opts? table {style?, width?, height?, minChars?, iconThreshold?, iconFallback?, tooltip?}
---@return boolean clicked True if the button was clicked
function M.DynamicButton(label, icon, opts)
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
-- ButtonRow (with measureButtonDefs helper)
--------------------------------------------------------------------------------

local display = require("modules/controls/display")

-- Lazy-loaded: holdbuttons loads after buttons in the aggregator
local holdbuttons
local function getHoldbuttons()
    if not holdbuttons then holdbuttons = require("modules/controls/holdbuttons") end
    return holdbuttons
end

--- Measure button defs for width distribution (shared by ButtonRow and ToggleButtonRow).
---@param defs table Array of button defs
---@param gap number Gap between buttons in pixels
---@param textFallback? function (def) -> string fallback text for flex buttons
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

M.measureButtonDefs = measureButtonDefs

--- Render a row of buttons with automatic width distribution.
--- Icon-only buttons (def.icon, no def.label) auto-size. Text buttons share remaining space by weight.
---@param defs table Array of button defs: {label?, icon?, style?, weight?, width?, height?, disabled?, tooltip?, onClick?, onHold?, holdDuration?, progressFrom?, progressStyle?, progressDisplay?, id?}
---@param opts? table {gap?, id?}
---@return nil
function M.ButtonRow(defs, opts)
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
    local hb = getHoldbuttons()
    for i, def in ipairs(defs) do
        local w = measured[i] or math.floor(remainingW * (def.weight or 1) / totalWeight)
        local icon = def.icon and resolveIcon(def.icon)
        local displayLabel = icon or def.label or def[1]
        local style = def.style or def[2] or "inactive"

        -- Soft disable: override style to "disabled" but keep hover for tooltips.
        -- Hard disable (disabled = "hard"): uses BeginDisabled for full ImGui blocking.
        local effectiveStyle = style
        local suppressClick = false
        if def.disabled == "hard" then
            ImGui.BeginDisabled(true)
        elseif def.disabled then
            effectiveStyle = "disabled"
            suppressClick = true
        end

        -- Cross-element progress: show progress bar instead of button when source is held
        local showedProgress = false
        if def.progressFrom then
            local progress = hb.getHoldProgress(def.progressFrom)
            if progress then
                display.ProgressBar(progress, w, 0, "", def.progressStyle or "danger")
                showedProgress = true
            end
        end

        if not showedProgress then
            if def.onHold and not suppressClick then
                local held, clicked = hb.HoldButton(def.id or ("btnrow_" .. i), displayLabel, {
                    duration = def.holdDuration or 2.0, style = effectiveStyle, width = w,
                    warningMessage = def.warningMessage,
                    progressDisplay = def.progressDisplay,
                })
                if held and def.onHold then def.onHold() end
                if clicked and def.onClick then def.onClick() end
            else
                local clicked = M.Button(displayLabel, effectiveStyle, w, def.height or 0)
                if clicked and not suppressClick and def.onClick then def.onClick() end
            end
        end

        if def.tooltip then tooltips.Show(def.tooltip) end
        if def.disabled == "hard" then ImGui.EndDisabled() end
        if i < #defs then ImGui.SameLine() end
    end
end

return M
