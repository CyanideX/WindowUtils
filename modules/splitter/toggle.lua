------------------------------------------------------
-- WindowUtils - Splitter Toggle
-- Toggle panel layout and toggle state management
------------------------------------------------------

local styles = require("modules/styles")
local controls = require("modules/controls")
local coreModule = require("core/core")
local expand = require("modules/expand")
local core = require("modules/splitter/core")

local toggle = {}

local getToggleState = core.getToggleState
local drawToggleBar = core.drawToggleBar
local cancelSpacing = core.cancelSpacing
local parseSizeSpec = core.parseSizeSpec
local tickToggle = core.tickToggle

local toggleStates = core.toggleStates
local splitterMinSizes = core.splitterMinSizes

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Render a toggleable panel with animated open/close.
--- panels[1] = fixed/toggleable panel, panels[2] = flex panel.
---@param id string Unique toggle identifier
---@param panels table Two-element array: [1] = fixed panel { content }, [2] = flex panel { content }
---@param opts? table Options: side ("left"|"right"|"top"|"bottom"), size (number|string), defaultOpen (boolean), speed (number), barWidth (number)
---@return boolean isOpen Current open state
function toggle.toggle(id, panels, opts)
    opts = opts or {}
    local side = opts.side or "left"
    local isVert = (side == "top" or side == "bottom")

    local state = getToggleState(id, opts)
    state.toggleOnClick = opts.toggleOnClick or false

    local availW, availH = ImGui.GetContentRegionAvail()
    local totalAvail = isVert and availH or availW

    local defaultSize = parseSizeSpec(opts.size or 200, totalAvail) or 200

    local expandedSize = defaultSize
    if opts.expand then
        state.expandId = id
        expand.init(id, {
            windowName = opts.windowName,
            side = side,
            size = defaultSize,
            sizeMode = opts.sizeMode,
            normalConstraintPct = opts.normalConstraintPct,
            expandDuration = opts.expandDuration,
            expandEasing = opts.expandEasing,
            isOpen = state.isOpen,
            restoredDragSize = state.restoredDragSize,
        })
        local prevMode = state.sizeMode
        state.sizeMode = opts.sizeMode or "fixed"
        if state.sizeMode ~= prevMode and prevMode ~= nil then
            state.dragging = false
            state.expandDragStart = nil
            expand.commitDrag(id)
        end
        expandedSize = expand.getTargetSize(id) or defaultSize
    end

    local eased = tickToggle(state)

    local panelSize = math.floor(expandedSize * eased)
    local barW = state.barWidth
    if panelSize > 0 and panelSize <= barW then
        if state.isOpen then
            panelSize = barW + 1
        else
            panelSize = 0
            state.animProgress = 0
        end
    end

    local fc = controls.getFrameCache()
    local spacing = isVert and fc.itemSpacingY or fc.itemSpacingX

    -- edgeFlush (right/bottom only): bar sits flush against window edge when collapsed.
    -- Top/left would require window-level padding changes outside the splitter's scope.
    local fixedFirst = (side == "left" or side == "top")
    local flushOffset = 0
    if opts.edgeFlush and not fixedFirst then
        flushOffset = isVert and fc.windowPaddingY or fc.windowPaddingX
    end

    local flexSize
    if opts.expand then
        expand.cacheBase(id, totalAvail, panelSize)
        if panelSize > 0 and not state.dragging then
            local baseAvail = expand.getBaseAvail(id)
            flexSize = math.max((baseAvail or totalAvail) - barW, 1)
        else
            flexSize = math.max(totalAvail - panelSize - barW, 1)
        end
    else
        flexSize = math.max(totalAvail - panelSize - barW, 1)
    end

    if flushOffset > 0 and panelSize == 0 then
        flexSize = flexSize + flushOffset
    end

    local fixedPanel = panels[1]
    local flexPanel = panels[2]

    local flexMinSpec = flexPanel and (isVert and flexPanel.minHeight or flexPanel.minWidth)
    if type(flexMinSpec) == "function" then flexMinSpec = flexMinSpec() end
    local flexMinPx = parseSizeSpec(flexMinSpec, totalAvail)
    if not flexMinPx then
        flexMinPx = fc.minIconButtonWidth
                  + (isVert and fc.windowPaddingY or fc.windowPaddingX) * 2
    end
    splitterMinSizes[id] = panelSize + barW + flexMinPx

    local noScroll = ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse

    local function renderFixed()
        if panelSize > 0 then
            local cw = isVert and availW or panelSize
            local ch = isVert and panelSize or 0
            ImGui.BeginChild("##toggle_fixed_" .. id, cw, ch, false, noScroll)
            if panelSize > state.barWidth and fixedPanel.content then
                local animating = state.animProgress > 0 and state.animProgress < 1
                if animating then ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, 0) end
                fixedPanel.content()
                if animating then ImGui.PopStyleVar() end
            end
            ImGui.EndChild()
        end
    end

    local function renderFlex()
        local cw = isVert and availW or flexSize
        local ch = isVert and flexSize or 0
        ImGui.BeginChild("##toggle_flex_" .. id, cw, ch, false)
        if flexPanel.content then flexPanel.content() end
        ImGui.EndChild()
    end

    styles.PushScrollbar()

    if fixedFirst then
        renderFixed()
        if panelSize > 0 then cancelSpacing(isVert, spacing) end
        drawToggleBar(id, state, side)
        cancelSpacing(isVert, spacing)
        renderFlex()
    else
        renderFlex()
        cancelSpacing(isVert, spacing)
        drawToggleBar(id, state, side)
        if panelSize > 0 then cancelSpacing(isVert, spacing) end
        renderFixed()
    end

    styles.PopScrollbar()

    -- Recompute panelSize for no-animation mode in case a toggle happened mid-frame (stale value)
    if opts.expand then
        local reportedSize = panelSize
        if not state.animate then
            state.animProgress = state.isOpen and 1.0 or 0.0
            local e = coreModule.easeInOut(state.animProgress)
            reportedSize = math.floor(expandedSize * e)
        end
        local isAnimating = state.animProgress > 0 and state.animProgress < 1
        expand.afterRender(id, reportedSize, isAnimating, state.dragging)
    end

    return state.isOpen
end

--- Programmatically set toggle state
---@param id string Toggle identifier
---@param open boolean Desired open state
function toggle.setToggle(id, open)
    local state = toggleStates[id]
    if state then
        state.isOpen = open
        if not state.animate then
            state.animProgress = open and 1.0 or 0.0
        end
        if state.expandId then
            expand.onToggle(state.expandId, open)
        end
        if state.persist and state.windowName then
            local ds = state.expandId and expand.getTargetSize(state.expandId) or nil
            coreModule.savePanelState(state.windowName, id, open, state.persist, ds)
        end
    end
end

--- Query toggle state
---@param id string Toggle identifier
---@return boolean|nil isOpen Current open state, or nil if not found
function toggle.getToggle(id)
    local state = toggleStates[id]
    return state and state.isOpen or nil
end

--- Query a panel's last saved open state from the window cache.
--- Works with any persist mode ("auto" or "manual"). Returns the state
--- that was saved when the game last closed, regardless of current state.
---@param windowName string The window name
---@param panelId string The panel identifier
---@return boolean|nil wasOpen The saved open state, or nil if not found
function toggle.getSavedToggle(windowName, panelId)
    return coreModule.getSavedPanelState(windowName, panelId)
end

--- Set toggle animation enabled/disabled
---@param id string Toggle identifier
---@param enabled boolean Whether animation is enabled
function toggle.setToggleAnimate(id, enabled)
    local state = toggleStates[id]
    if state then state.animate = enabled end
end

--- Query toggle animation state
---@param id string Toggle identifier
---@return boolean|nil animate Whether animation is enabled, or nil if not found
function toggle.getToggleAnimate(id)
    local state = toggleStates[id]
    return state and state.animate or nil
end

--- Get the current animated constraint value for an expand-mode toggle.
--- Call before ImGui.Begin() to feed into SetNextWindowSizeConstraintsPercent.
--- Returns nil if the toggle hasn't rendered yet or isn't in expand mode.
---@param id string Toggle identifier (same id passed to splitter.toggle with expand=true)
---@return number|nil constraintPct Current animated constraint value (display %), or nil
function toggle.getExpandConstraint(id)
    local state = toggleStates[id]
    if not state or not state.expandId then return nil end
    return expand.getConstraint(state.expandId, state.isOpen)
end

return toggle
