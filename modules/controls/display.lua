------------------------------------------------------
-- WindowUtils - Controls Display
-- Non-interactive display: ProgressBar, ColorEdit4, SwatchGrid,
-- Text*, Separator, SectionHeader, HeaderIconGlyph
------------------------------------------------------

local styles = require("modules/styles")
local tooltips = require("modules/tooltips")
local utils = require("modules/utils")
local core = require("modules/controls/core")

local frameCache = core.frameCache
local Scaled = core.Scaled
local iconPrefix = core.iconPrefix

local M = {}

--------------------------------------------------------------------------------
-- Module-local state
--------------------------------------------------------------------------------

local swatchSortCache = {}      -- Cached sort results keyed by grid id
local swatchSortQuickCheck = {} -- Quick staleness check: id -> {count, hasCategories, cacheKey}

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
function M.ProgressBar(fraction, width, height, overlay, styleName)
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
function M.ColorEdit4(icon, id, color, opts)
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
function M.SwatchGrid(id, colors, selectedHex, onSelect, config)
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
function M.TextMuted(text)
    styles.PushTextMuted()
    ImGui.Text(text)
    styles.PopTextMuted()
end

--- Display success/green text
---@param text string Text to display
---@return nil
function M.TextSuccess(text)
    styles.PushTextSuccess()
    ImGui.Text(text)
    styles.PopTextSuccess()
end

--- Display danger/red text
---@param text string Text to display
---@return nil
function M.TextDanger(text)
    styles.PushTextDanger()
    ImGui.Text(text)
    styles.PopTextDanger()
end

--- Display warning/yellow text
---@param text string Text to display
---@return nil
function M.TextWarning(text)
    styles.PushTextWarning()
    ImGui.Text(text)
    styles.PopTextWarning()
end

--------------------------------------------------------------------------------
-- Layout Helpers
--------------------------------------------------------------------------------

--- Create a separator with optional spacing
---@param spacingBefore? number Vertical spacing in pixels before the separator
---@param spacingAfter? number Vertical spacing in pixels after the separator
---@return nil
function M.Separator(spacingBefore, spacingAfter)
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
function M.SectionHeader(label, spacingBefore, spacingAfter, iconGlyph)
    if spacingBefore then
        ImGui.Dummy(0, spacingBefore)
    end
    ImGui.Separator()
    ImGui.Text(label)
    if type(iconGlyph) == "table" then
        M.HeaderIconGlyph(iconGlyph)
    end
    if spacingAfter then
        ImGui.Dummy(0, spacingAfter)
    end
end

--- Render a right-justified icon glyph on the current ImGui line.
--- Intended for use after header/section header text to show contextual icons.
--- Uses a frameless button when onClick is provided so clicks register in CET.
---@param opts table {icon: string, tooltip?: string, color?: table, visible?: boolean, onClick?: function}
function M.HeaderIconGlyph(opts)
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

return M
