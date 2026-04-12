------------------------------------------------------
-- WindowUtils - Controls Bind
-- Bind system: bind/unbind, bindMethods metatable,
-- bindControl, bindDragRow, applyDefAndSearch
------------------------------------------------------

local tooltips = require("modules/tooltips")
local core = require("modules/controls/core")

local frameCache = core.frameCache
local resolveIcon = core.resolveIcon
local buttonRowMinWidths = core.buttonRowMinWidths

--------------------------------------------------------------------------------
-- Module-local state
--------------------------------------------------------------------------------

local bindPool = {}
local bindPoolSize = 0

--------------------------------------------------------------------------------
-- Captured controls table (set by init())
--------------------------------------------------------------------------------

local controls

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

-- Populated by init() once the full controls table is available
local bindDispatch

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

    local optsDrags = opts.drags
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

    -- Cache drags array on _drs keyed by row ID; update in-place on subsequent frames
    local dragsKey = rowId .. "_drags"
    local cachedDrags = drs[dragsKey]
    local keyCount = #keys
    local needsRebuild = not cachedDrags or #cachedDrags ~= keyCount

    if needsRebuild then
        cachedDrags = {}
        for i, key in ipairs(keys) do
            local drag = {
                value = isDelta and 0 or (self.data[key] or 0),
                min = min, max = max, key = key,
            }
            if self.defaults and self.defaults[key] ~= nil then
                drag.default = self.defaults[key]
            end
            if optsDrags and optsDrags[i] then
                for k, v in pairs(optsDrags[i]) do drag[k] = v end
            end
            cachedDrags[i] = drag
        end
        drs[dragsKey] = cachedDrags
    else
        for i, key in ipairs(keys) do
            cachedDrags[i].value = isDelta and 0 or (self.data[key] or 0)
            cachedDrags[i].min = min
            cachedDrags[i].max = max
            if self.defaults and self.defaults[key] ~= nil then
                cachedDrags[i].default = self.defaults[key]
            end
        end
    end

    local values, anyChanged = controlFn(icon, rowId, cachedDrags, opts)

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

    local fixedW, totalWeight, measured, totalMinWidth = controls.measureButtonDefs(defs, gap, function(d) return d.key end)

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
-- Module exports
--------------------------------------------------------------------------------

local M = {}
M.exports = {}

--- Initialize the bind module with the full controls table.
--- Called by the aggregator after all other sub-modules are loaded.
---@param ctrlTable table The fully-populated controls table from the aggregator
function M.init(ctrlTable)
    controls = ctrlTable

    bindDispatch = {
        SliderFloat = { fn = controls.SliderFloat, hasMinMax = true,  hasItems = false, hasTransform = true,  hasPercent = true  },
        SliderInt   = { fn = controls.SliderInt,   hasMinMax = true,  hasItems = false, hasTransform = true,  hasPercent = true  },
        DragFloat   = { fn = controls.DragFloat,   hasMinMax = true,  hasItems = false, hasTransform = true,  hasPercent = true  },
        DragInt     = { fn = controls.DragInt,      hasMinMax = true,  hasItems = false, hasTransform = true,  hasPercent = true  },
        Combo       = { fn = controls.Combo,       hasMinMax = false, hasItems = true,  hasTransform = true,  hasPercent = false },
        InputText   = { fn = controls.InputText,   hasMinMax = false, hasItems = false, hasTransform = false, hasPercent = false },
        InputFloat  = { fn = controls.InputFloat,  hasMinMax = false, hasItems = false, hasTransform = false, hasPercent = false },
        InputInt    = { fn = controls.InputInt,     hasMinMax = false, hasItems = false, hasTransform = false, hasPercent = false },
    }

    --- Create a bound context that auto-reads, auto-writes, auto-resets, and auto-saves.
    --- Usage: local c = controls.bind(data, defaults, onSave, { idPrefix = "prefix_" })
    ---        c:SliderFloat(icon, key, min, max, opts)  -- reads data[key], resets to defaults[key]
    --- idPrefix is prepended to key for the ImGui ID but the raw key is used for data/defaults lookup.
    ---@param data table Data table to read/write values from
    ---@param defaults? table Default values table for right-click reset
    ---@param onSave? function Callback invoked after any value change
    ---@param bindOpts? table {idPrefix?: string, search?: table, defs?: table, searchTooltips?: boolean}
    ---@return table ctx Bound context with SliderFloat, SliderInt, Checkbox, ColorEdit4, Combo, InputText, InputFloat, InputInt, ToggleButtonRow methods
    M.exports.bind = function(data, defaults, onSave, bindOpts)
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
    M.exports.unbind = function(ctx)
        ctx._dragRowOnReset = nil
        bindPoolSize = bindPoolSize + 1
        bindPool[bindPoolSize] = ctx
    end
end

return M
