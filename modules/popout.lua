------------------------------------------------------
-- WindowUtils - Popout
-- Detachable panel support with docked/floating modes
------------------------------------------------------

local settings = require("core/settings")
local controls = require("modules/controls")
local core     = require("core/core")

local popout = {}

local popoutStates = {}

--------------------------------------------------------------------------------
-- Icon Fallbacks (resolved lazily)
--------------------------------------------------------------------------------

local _undockIcon = nil
local _dockIcon = nil

local function getUndockIcon()
    if not _undockIcon then
        _undockIcon = IconGlyphs and IconGlyphs.OpenInNew or "[+]"
    end
    return _undockIcon
end

local function getDockIcon()
    if not _dockIcon then
        _dockIcon = IconGlyphs and IconGlyphs.DockWindow or "[x]"
    end
    return _dockIcon
end

--------------------------------------------------------------------------------
-- Instance Management
--------------------------------------------------------------------------------

---@param id string
---@param opts table
---@return table
local function getInstance(id, opts)
    if not popoutStates[id] then
        local style = opts.style
        if style ~= "panel" and style ~= "inline" then
            style = "panel"
        end
        local size = opts.size or {}
        popoutStates[id] = {
            isDocked = opts.defaultDocked ~= false,
            style = style,
            title = opts.title or id,
            size = { width = size.width or 300, height = size.height or 200 },
            icon = opts.icon,
            windowName = "###popout_" .. id,
            warnedNoUpdate = false,
        }
    end
    return popoutStates[id]
end

--------------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------------

--- Resolve the initial floating window width from opts.
--- Supports pixels (number) or display percentage (string like "25%").
---@param opts table
---@param fallback number
---@return number
local function resolveWidth(opts, fallback)
    if opts.widthPercent then
        local sw = GetDisplayResolution()
        return math.floor(sw * opts.widthPercent / 100)
    end
    local size = opts.size or {}
    return size.width or fallback
end

--- Render the floating window for a detached popout.
---@param inst table PopoutInstance
---@param opts table Caller options
local function renderFloatingWindow(inst, opts)
    local w = resolveWidth(opts, inst.size.width)
    local h = inst.size.height

    -- Size constraints (grid-aligned when available)
    -- widthPercent doubles as minimum width when no explicit minSize is set
    local mn = opts.minSize or {}
    local mx = opts.maxSize or {}
    local minW = mn.width or (opts.widthPercent and w or 0)
    core.setNextWindowSizeConstraints(
        minW, mn.height or 0,
        mx.width or 9999, mx.height or 9999
    )

    -- Initial size (FirstUseEver only, so user can resize width freely)
    ImGui.SetNextWindowSize(w, h, ImGuiCond.FirstUseEver)

    local extraFlags = opts.flags or 0
    local flags = ImGuiWindowFlags.NoTitleBar + ImGuiWindowFlags.NoScrollbar + extraFlags
    local displayTitle = inst.title .. inst.windowName

    if ImGui.Begin(displayTitle, flags) then
        -- fitHeight: lock height to grid-ceiled cache, preserve user's current width
        if opts.fitHeight and inst.fitHeightCache then
            local curW = ImGui.GetWindowSize()
            ImGui.SetWindowSize(curW, inst.fitHeightCache)
            -- Re-measure if width changed (content may reflow)
            if inst.fitLastWidth and inst.fitLastWidth ~= curW then
                inst.fitHeightStable = false
            end
            inst.fitLastWidth = curW
        end

        -- Centered title
        local titleW = ImGui.CalcTextSize(inst.title)
        local winW = ImGui.GetWindowSize()
        ImGui.SetCursorPosX((winW - titleW) * 0.5)
        ImGui.Text(inst.title)

        if core.update then
            core.update(displayTitle, { treatAllDragsAsWindowDrag = true })
        elseif not inst.warnedNoUpdate then
            inst.warnedNoUpdate = true
            settings.debugPrint("popout: WindowUtils.Update not available for '" .. inst.title .. "'")
        end

        local wantBg = opts.bg
        if wantBg == nil then
            wantBg = (inst.style == "panel")
        end

        if wantBg then
            local panelOpts = {}
            if type(wantBg) == "table" then panelOpts.bg = wantBg end

            if opts.fitHeight then
                if inst.fitHeightStable then
                    -- Cache is stable: Panel fills remaining space, no measurement
                    controls.Panel("popout_float_" .. inst.windowName, opts.content, panelOpts)
                else
                    -- Measuring frame: auto-height Panel, compute grid-ceiled window height
                    panelOpts.height = "auto"
                    controls.Panel("popout_float_" .. inst.windowName, opts.content, panelOpts)
                    local gridSize = (settings.master.gridUnits or settings.defaults.gridUnits) * settings.GRID_UNIT_SIZE
                    local padY = ImGui.GetStyle().WindowPadding.y
                    local totalH = ImGui.GetCursorPosY() + padY
                    local newCache = math.ceil(totalH / gridSize) * gridSize
                    if inst.fitHeightCache == newCache then
                        -- Height settled, switch to fill mode next frame
                        inst.fitHeightStable = true
                    end
                    inst.fitHeightCache = newCache
                end
            else
                controls.Panel("popout_float_" .. inst.windowName, opts.content, panelOpts)
            end
        elseif opts.content then
            opts.content()
            if opts.fitHeight and not inst.fitHeightStable then
                local gridSize = (settings.master.gridUnits or settings.defaults.gridUnits) * settings.GRID_UNIT_SIZE
                local padY = ImGui.GetStyle().WindowPadding.y
                local totalH = ImGui.GetCursorPosY() + padY
                local newCache = math.ceil(totalH / gridSize) * gridSize
                if inst.fitHeightCache == newCache then
                    inst.fitHeightStable = true
                end
                inst.fitHeightCache = newCache
            end
        end
    end
    ImGui.End()
end

--- Render the docked state.
--- Panel style: controls.Panel with auto-height and default bg.
--- Inline style: content rendered directly (no wrapper) unless opts.bg is set.
---@param id string
---@param inst table
---@param opts table
local function renderDocked(id, inst, opts)
    -- opts.bg: nil = style default, false = no bg, table = custom color
    local wantBg = opts.bg
    if wantBg == nil then
        wantBg = (inst.style == "panel")
    end

    if wantBg then
        local panelOpts = { height = "auto" }
        if type(wantBg) == "table" then panelOpts.bg = wantBg end
        controls.Panel("popout_docked_" .. id, opts.content, panelOpts)
    elseif opts.content then
        opts.content()
    end
end

--- Render the placeholder left behind when a popout is detached.
--- Panel style: styled panel with a dock button and optional opts.placeholder content.
--- Inline style: only opts.placeholder if provided (no auto button, user controls via toggleButton).
---@param id string
---@param inst table
---@param opts table
local function renderPlaceholder(id, inst, opts)
    if inst.style == "inline" then
        -- Inline: no auto button. User places toggleButton wherever they want.
        if opts.placeholder then
            opts.placeholder()
        end
        return
    end

    -- Panel: styled container with dock button
    local wantBg = opts.bg
    if wantBg == nil then wantBg = true end

    local function placeholderContent()
        local icon = inst.icon or getDockIcon()
        if controls.Button("  " .. icon .. "  ", "inactive") then
            inst.isDocked = true
        end
        if opts.placeholder then
            ImGui.SameLine()
            opts.placeholder()
        end
    end

    if wantBg then
        local panelOpts = { height = "auto" }
        if type(wantBg) == "table" then panelOpts.bg = wantBg end
        controls.Panel("popout_placeholder_" .. id, placeholderContent, panelOpts)
    else
        placeholderContent()
    end
end

--------------------------------------------------------------------------------
-- Main API
--------------------------------------------------------------------------------

--- Render a popout panel. Call once per frame where the content should appear.
---
--- opts fields:
---   content          function    Content callback (rendered docked or in floating window)
---   title            string      Floating window title (default: id)
---   style            string      "panel" (default) or "inline"
---   defaultDocked    boolean     Initial dock state (default: true)
---   size             table       Floating window size {width, height} in pixels
---   widthPercent     number      Floating window width as display percentage (overrides size.width)
---   fitHeight        boolean     Auto-resize floating window height to content, snapped to grid
---   minSize          table       Minimum floating window size {width, height}
---   maxSize          table       Maximum floating window size {width, height}
---   flags            number      Extra ImGui window flags for the floating window
---   icon             string      Glyph for placeholder dock button
---   bg               table|false Panel background: nil = style default, false = none, table = custom RGBA
---   placeholder      function    Extra content rendered in the placeholder when detached
---   hideWhenDetached boolean     Skip placeholder entirely when detached (default: false)
---
---@param id string Unique popout identifier
---@param opts table
---@return boolean isDocked
function popout.popout(id, opts)
    opts = opts or {}
    local inst = getInstance(id, opts)

    if inst.isDocked then
        renderDocked(id, inst, opts)
    else
        if not opts.hideWhenDetached then
            renderPlaceholder(id, inst, opts)
        end
        renderFloatingWindow(inst, opts)
    end

    return inst.isDocked
end

--- Flip the dock state.
---@param id string
function popout.toggle(id)
    local inst = popoutStates[id]
    if inst then inst.isDocked = not inst.isDocked end
end

--- Set the dock state programmatically.
---@param id string
---@param docked boolean
function popout.setDocked(id, docked)
    local inst = popoutStates[id]
    if inst then inst.isDocked = docked end
end

--- Query the current dock state. Returns true if ID not found (safe default).
---@param id string
---@return boolean
function popout.isDocked(id)
    local inst = popoutStates[id]
    return inst and inst.isDocked or true
end

--- Returns the appropriate icon glyph for the current state.
---@param id string
---@return string
function popout.getIcon(id)
    local inst = popoutStates[id]
    if inst and not inst.isDocked then return getDockIcon() end
    return getUndockIcon()
end

--- Returns a ButtonRow-compatible button definition for toggling the popout.
---@param id string
---@param opts? table
---@return table
function popout.toggleButton(id, opts)
    local docked = popout.isDocked(id)
    return {
        type = "button",
        icon = popout.getIcon(id),
        tooltip = docked and "Detach panel" or "Dock panel",
        onClick = function() popout.toggle(id) end,
    }
end

return popout
