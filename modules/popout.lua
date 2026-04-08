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

local _undockIcon, _dockIcon

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
-- Helpers
--------------------------------------------------------------------------------

--- Resolve whether a panel background should be rendered.
--- nil = style default (panel=true, inline=false), false = off, table = custom RGBA.
---@param bg any opts.bg value
---@param style string "panel" or "inline"
---@return any wantBg false or truthy (true or RGBA table)
local function resolveBg(bg, style)
    if bg == nil then return style == "panel" end
    return bg
end

--- Compute the floating window width in pixels.
---@param opts table
---@param fallbackW number
---@return number
local function resolveWidth(opts, fallbackW)
    if opts.widthPercent then
        local sw = GetDisplayResolution()
        return math.floor(sw * opts.widthPercent / 100)
    end
    return fallbackW
end

--- Compute grid cell size from current settings.
---@return number
local function getGridCellSize()
    local units = settings.master.gridUnits or settings.defaults.gridUnits
    return units * settings.GRID_UNIT_SIZE
end

--- Build Panel opts table from bg value.
---@param bg any resolved bg (false, true, or RGBA table)
---@param height? any Panel height override
---@return table
local function panelOpts(bg, height)
    local p = {}
    if type(bg) == "table" then p.bg = bg end
    if height then p.height = height end
    return p
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
            isDocked        = opts.defaultDocked ~= false,
            style           = style,
            title           = opts.title or id,
            size            = { width = size.width or 300, height = size.height or 200 },
            icon            = opts.icon,
            windowName      = "###popout_" .. id,
            warnedNoUpdate  = false,
            -- fitHeight state
            fitCache        = nil,   -- grid-ceiled height (number or nil)
            fitStable       = false, -- true once measurement settles
            fitLastWidth    = nil,   -- tracks width changes for reflow detection
        }
    end
    return popoutStates[id]
end

--------------------------------------------------------------------------------
-- Floating Window
--------------------------------------------------------------------------------

--- Apply fitHeight: lock height to cached grid-ceiled value, allow width resize.
--- Invalidates the stable flag if the user resized width (content may reflow).
---@param inst table
local function applyFitHeight(inst)
    if not inst.fitCache then return end
    local curW = ImGui.GetWindowSize()
    ImGui.SetWindowSize(curW, inst.fitCache)
    if inst.fitLastWidth and inst.fitLastWidth ~= curW then
        inst.fitStable = false
    end
    inst.fitLastWidth = curW
end

--- Measure content height after rendering, ceil to grid, update cache.
--- Sets fitStable=true once the measurement settles (same value two frames running).
---@param inst table
local function measureFitHeight(inst)
    local gridSize = getGridCellSize()
    local padY = ImGui.GetStyle().WindowPadding.y
    local totalH = ImGui.GetCursorPosY() + padY
    local newCache = math.ceil(totalH / gridSize) * gridSize
    if inst.fitCache == newCache then
        inst.fitStable = true
    end
    inst.fitCache = newCache
end

--- Render content inside the floating window with appropriate bg wrapping.
--- fitHeight uses a two-phase approach:
---   Measuring: Panel with auto-height so cursor reflects content, not window.
---   Stable: Panel fills remaining space (window is already grid-locked).
---@param inst table
---@param opts table
local function renderFloatingContent(inst, opts)
    local bg = resolveBg(opts.bg, inst.style)

    if not opts.fitHeight then
        -- Normal mode: Panel fills remaining space or render content directly
        if bg then
            controls.Panel("popout_float_" .. inst.windowName, opts.content, panelOpts(bg))
        elseif opts.content then
            opts.content()
        end
        return
    end

    -- fitHeight mode
    if bg then
        if inst.fitStable then
            controls.Panel("popout_float_" .. inst.windowName, opts.content, panelOpts(bg))
        else
            controls.Panel("popout_float_" .. inst.windowName, opts.content, panelOpts(bg, "auto"))
            measureFitHeight(inst)
        end
    else
        if opts.content then opts.content() end
        if not inst.fitStable then
            measureFitHeight(inst)
        end
    end
end

---@param inst table
---@param opts table
local function renderFloatingWindow(inst, opts)
    local w = resolveWidth(opts, inst.size.width)

    -- Size constraints (only when needed)
    local hasConstraints = opts.minSize or opts.maxSize or opts.widthPercent
    if hasConstraints then
        local mn = opts.minSize or {}
        local mx = opts.maxSize or {}
        local minW = mn.width or (opts.widthPercent and w or 0)
        core.setNextWindowSizeConstraints(
            minW, mn.height or 0,
            mx.width or 9999, mx.height or 9999
        )
    end

    ImGui.SetNextWindowSize(w, inst.size.height, ImGuiCond.FirstUseEver)

    local flags = ImGuiWindowFlags.NoTitleBar + ImGuiWindowFlags.NoScrollbar + (opts.flags or 0)
    local displayTitle = inst.title .. inst.windowName

    if ImGui.Begin(displayTitle, flags) then
        if opts.fitHeight then
            applyFitHeight(inst)
        end

        -- Centered title
        local titleW = ImGui.CalcTextSize(inst.title)
        local winW = ImGui.GetWindowSize()
        ImGui.SetCursorPosX((winW - titleW) * 0.5)
        ImGui.Text(inst.title)

        -- WindowUtils.Update integration
        if core.update then
            core.update(displayTitle, { treatAllDragsAsWindowDrag = true })
        elseif not inst.warnedNoUpdate then
            inst.warnedNoUpdate = true
            settings.debugPrint("popout: WindowUtils.Update not available for '" .. inst.title .. "'")
        end

        renderFloatingContent(inst, opts)
    end
    ImGui.End()
end

--------------------------------------------------------------------------------
-- Docked / Placeholder
--------------------------------------------------------------------------------

---@param id string
---@param inst table
---@param opts table
local function renderDocked(id, inst, opts)
    local bg = resolveBg(opts.bg, inst.style)
    if bg then
        controls.Panel("popout_docked_" .. id, opts.content, panelOpts(bg, "auto"))
    elseif opts.content then
        opts.content()
    end
end

---@param id string
---@param inst table
---@param opts table
local function renderPlaceholder(id, inst, opts)
    -- Inline: no auto button, only user-provided placeholder content
    if inst.style == "inline" then
        if opts.placeholder then opts.placeholder() end
        return
    end

    -- Panel: styled container with dock button + optional placeholder content
    local bg = resolveBg(opts.bg, inst.style)

    local function content()
        local icon = inst.icon or getDockIcon()
        if controls.Button("  " .. icon .. "  ", "inactive") then
            inst.isDocked = true
        end
        if opts.placeholder then
            ImGui.SameLine()
            opts.placeholder()
        end
    end

    if bg then
        controls.Panel("popout_placeholder_" .. id, content, panelOpts(bg, "auto"))
    else
        content()
    end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Render a popout panel. Call once per frame where the content should appear.
---
---   content          function    Content callback
---   title            string      Floating window title (default: id)
---   style            string      "panel" (default) or "inline"
---   defaultDocked    boolean     Initial dock state (default: true)
---   size             table       Floating window size {width, height} in pixels
---   widthPercent     number      Width as display % (also sets min width)
---   fitHeight        boolean     Auto-size height to content, snapped to grid
---   minSize          table       Min floating window size {width, height}
---   maxSize          table       Max floating window size {width, height}
---   flags            number      Extra ImGui window flags
---   icon             string      Glyph for placeholder dock button
---   bg               table|false Background: nil=style default, false=none, table=custom RGBA
---   placeholder      function    Content in placeholder when detached
---   hideWhenDetached boolean     Skip placeholder entirely (default: false)
---
---@param id string
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
