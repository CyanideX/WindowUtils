------------------------------------------------------
-- WindowUtils - Popout
-- Detachable panel support with docked/floating modes
------------------------------------------------------

local settings = require("core/settings")
local controls = require("modules/controls")
local styles   = require("modules/styles")
local core     = require("core/core")

local popout = {}

local popoutStates = {}

--------------------------------------------------------------------------------
-- Icon Fallbacks (resolved lazily)
--------------------------------------------------------------------------------

local _undockIcon, _dockIcon, _handleIcon

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

local function getHandleIcon()
    if not _handleIcon then
        _handleIcon = IconGlyphs and IconGlyphs.DotsVertical or "||"
    end
    return _handleIcon
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function resolveBg(bg, style)
    if bg == nil then return style == "panel" end
    return bg
end

local function resolveWidth(opts, fallbackW)
    if opts.widthPercent then
        local sw = GetDisplayResolution()
        return math.floor(sw * opts.widthPercent / 100)
    end
    return fallbackW
end

local function getGridCellSize()
    local units = settings.master.gridUnits or settings.defaults.gridUnits
    return units * settings.GRID_UNIT_SIZE
end

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
            fitCache        = nil,
            fitStable       = false,
            fitLastWidth    = nil,
            -- Cached opts for drawAll
            lastOpts        = nil,
        }
    end
    return popoutStates[id]
end

--------------------------------------------------------------------------------
-- Floating Window
--------------------------------------------------------------------------------

local function applyFitHeight(inst)
    if not inst.fitCache then return end
    local curW = ImGui.GetWindowSize()
    ImGui.SetWindowSize(curW, inst.fitCache)
    -- Only invalidate on meaningful width changes (> 1px) to avoid flicker
    if inst.fitLastWidth and math.abs(inst.fitLastWidth - curW) > 1 then
        inst.fitStable = false
    end
    inst.fitLastWidth = curW
end

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

local function renderFloatingContent(inst, opts)
    local bg = resolveBg(opts.bg, inst.style)

    if not opts.fitHeight then
        if bg then
            controls.Panel("popout_float_" .. inst.windowName, opts.content, panelOpts(bg))
        elseif opts.content then
            opts.content()
        end
        return
    end

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

local HANDLE_FLAGS = ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse

--- Render a vertical side handle bar with a centered grip icon.
---@param id string Child window ID
---@param height number Available height
local function renderSideHandle(id, height)
    local icon = getHandleIcon()
    local handleW = controls.Scaled(5)
    local colors = styles.colors

    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0, 0)

    if ImGui.BeginChild(id, handleW, height, false, HANDLE_FLAGS) then
        local winW, winH = ImGui.GetWindowSize()
        local textW, textH = ImGui.CalcTextSize(icon)
        ImGui.SetCursorPosX((winW - textW) / 2)
        ImGui.SetCursorPosY((winH - textH) / 2)
        ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(colors.splitterIcon[1], colors.splitterIcon[2], colors.splitterIcon[3], colors.splitterIcon[4]))
        ImGui.Text(icon)
        ImGui.PopStyleColor()
    end
    ImGui.EndChild()

    ImGui.PopStyleVar()
end

local function renderFloatingWindow(inst, opts)
    local w = resolveWidth(opts, inst.size.width)

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

        if opts.showTitle ~= false then
            local titleW = ImGui.CalcTextSize(inst.title)
            local winW = ImGui.GetWindowSize()
            ImGui.SetCursorPosX((winW - titleW) * 0.5)
            ImGui.Text(inst.title)
            ImGui.Dummy(0, controls.Scaled(4))
        end

        if core.update then
            core.update(displayTitle)
        elseif not inst.warnedNoUpdate then
            inst.warnedNoUpdate = true
            settings.debugPrint("popout: WindowUtils.Update not available for '" .. inst.title .. "'")
        end

        if opts.sideHandle then
            local handleW = controls.Scaled(5)
            local _, contentH = ImGui.GetContentRegionAvail()
            controls.Row("popout_hr_" .. inst.windowName, {
                { width = handleW, content = function()
                    renderSideHandle("##popout_handle_" .. inst.windowName, contentH)
                end },
                { content = function()
                    renderFloatingContent(inst, opts)
                end },
            }, { height = contentH })
        else
            renderFloatingContent(inst, opts)
        end
    end
    ImGui.End()
end

--------------------------------------------------------------------------------
-- Docked / Placeholder
--------------------------------------------------------------------------------

local function renderDocked(id, inst, opts)
    local bg = resolveBg(opts.bg, inst.style)
    if bg then
        controls.Panel("popout_docked_" .. id, opts.content, panelOpts(bg, "auto"))
    elseif opts.content then
        opts.content()
    end
end

local function renderPlaceholder(id, inst, opts)
    if inst.style == "inline" then
        if opts.placeholder then opts.placeholder() end
        return
    end

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

--- Render a popout panel at the call site.
--- Docked: renders content inline. Detached: renders placeholder + floating window.
--- Stores opts on the instance so drawAll() can re-render detached windows
--- even when this call site is inactive (e.g., tab switched away).
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
---   showTitle        boolean     Show centered title in floating window (default: true)
---   sideHandle       boolean     Show vertical grab handle on the left side (default: false)
---
---@param id string
---@param opts table
---@return boolean isDocked
function popout.popout(id, opts)
    opts = opts or {}
    local inst = getInstance(id, opts)

    -- Store opts so drawAll renders the floating window from a consistent context
    inst.lastOpts = opts

    if inst.isDocked then
        renderDocked(id, inst, opts)
    else
        if not opts.hideWhenDetached then
            renderPlaceholder(id, inst, opts)
        end
        -- Floating window is rendered by drawAll() at the top level
    end

    return inst.isDocked
end

--- Render floating windows for all detached popouts.
--- Call once per frame at the top level, outside any Begin/End or child windows.
--- All detached popouts are rendered here, ensuring a consistent ImGui context.
function popout.drawAll()
    for id, inst in pairs(popoutStates) do
        if not inst.isDocked and inst.lastOpts then
            renderFloatingWindow(inst, inst.lastOpts)
        end
    end
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
