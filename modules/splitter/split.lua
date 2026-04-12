------------------------------------------------------
-- WindowUtils - Splitter Split
-- Horizontal, vertical, and multi-panel split layouts
------------------------------------------------------

local styles = require("modules/styles")
local controls = require("modules/controls")
local core = require("modules/splitter/core")

local split = {}

local getState = core.getState
local getMultiState = core.getMultiState
local getToggleState = core.getToggleState
local drawGrabBar = core.drawGrabBar
local drawToggleBar = core.drawToggleBar
local cancelSpacing = core.cancelSpacing
local tickToggle = core.tickToggle
local tickAnimation = core.tickAnimation
local parseSizeSpec = core.parseSizeSpec
local getPanelMinFrac = core.getPanelMinFrac
local getPanelMaxFrac = core.getPanelMaxFrac
local isCtrlHeld = core.isCtrlHeld
local isShiftHeld = core.isShiftHeld
local snapValue = core.snapValue

local splitStates = core.splitStates
local multiStates = core.multiStates
local splitterMinSizes = core.splitterMinSizes

local COLLAPSE_SPEED = core.COLLAPSE_SPEED

--------------------------------------------------------------------------------
-- Public API: Two-panel splits
--------------------------------------------------------------------------------

--- Horizontal split (left | right)
---@param id string Unique splitter identifier
---@param leftFn? function Render callback for the left panel
---@param rightFn? function Render callback for the right panel
---@param opts? table Options: defaultPct, minPct, maxPct, grabWidth
---@return number pct Current split fraction (0..1)
function split.horizontal(id, leftFn, rightFn, opts)
    local state = getState(id, opts)
    local grabW = state.grabWidth
    local spacingX = controls.getFrameCache().itemSpacingX

    local availW = ImGui.GetContentRegionAvail()
    local usableW = availW - grabW
    local leftW = math.floor(usableW * state.pct)
    local rightW = usableW - leftW

    styles.PushScrollbar()

    ImGui.BeginChild("##splitter_left_" .. id, leftW, 0, false)
    if leftFn then leftFn() end
    ImGui.EndChild()

    ImGui.SameLine()
    ImGui.SetCursorPosX(ImGui.GetCursorPosX() - spacingX)

    drawGrabBar(id, state, false)

    ImGui.SameLine()
    ImGui.SetCursorPosX(ImGui.GetCursorPosX() - spacingX)

    ImGui.BeginChild("##splitter_right_" .. id, rightW, 0, false)
    if rightFn then rightFn() end
    ImGui.EndChild()

    styles.PopScrollbar()

    return state.pct
end

--- Vertical split (top / bottom)
---@param id string Unique splitter identifier
---@param topFn? function Render callback for the top panel
---@param bottomFn? function Render callback for the bottom panel
---@param opts? table Options: defaultPct, minPct, maxPct, grabWidth
---@return number pct Current split fraction (0..1)
function split.vertical(id, topFn, bottomFn, opts)
    local state = getState(id, opts)
    local grabH = state.grabWidth
    local spacingY = controls.getFrameCache().itemSpacingY

    local availW, availH = ImGui.GetContentRegionAvail()
    local usableH = availH - grabH
    local topH = math.floor(usableH * state.pct)
    local bottomH = usableH - topH

    styles.PushScrollbar()

    ImGui.BeginChild("##splitter_top_" .. id, availW, topH, false)
    if topFn then topFn() end
    ImGui.EndChild()

    ImGui.SetCursorPosY(ImGui.GetCursorPosY() - spacingY)

    drawGrabBar(id, state, true)

    ImGui.SetCursorPosY(ImGui.GetCursorPosY() - spacingY)

    ImGui.BeginChild("##splitter_bottom_" .. id, availW, bottomH, false)
    if bottomFn then bottomFn() end
    ImGui.EndChild()

    styles.PopScrollbar()

    return state.pct
end

--- Get current split percentage for an ID
---@param id string Splitter identifier
---@return number|nil pct Current split fraction, or nil if not found
function split.getSplitPct(id)
    local state = splitStates[id]
    return state and state.pct or nil
end

--- Set split percentage programmatically
---@param id string Splitter identifier
---@param pct number Desired split fraction (clamped to minPct..maxPct)
function split.setSplitPct(id, pct)
    local state = splitStates[id]
    if state then
        state.pct = math.max(state.minPct, math.min(state.maxPct, pct))
    end
end

--- Reset to default percentage
---@param id string Splitter identifier
function split.reset(id)
    local state = splitStates[id]
    if state then
        state.pct = state.defaultPct
        state.collapsed = false
        state.animProgress = 1.0
    end
end

--------------------------------------------------------------------------------
-- Multi-panel helpers
--------------------------------------------------------------------------------

--- Render a right-click context menu for a multi-splitter divider
local function drawContextMenu(id, i, ms, isVertical)
    if ImGui.BeginPopupContextItem("##splitter_ctx_" .. id .. "_d" .. i) then
        local resetLabel = isVertical and "Reset Column" or "Reset Row"
        if ImGui.MenuItem(resetLabel) then
            for j = 1, #ms.defaults do
                ms.breakpoints[j] = ms.defaults[j]
            end
            ms.dirty = true
        end
        if ImGui.MenuItem("Reset All") then
            for _, state in pairs(multiStates) do
                for j = 1, #state.defaults do
                    state.breakpoints[j] = state.defaults[j]
                end
                state.dirty = true
            end
        end
        ImGui.EndPopup()
    end
end

--------------------------------------------------------------------------------
-- Toggle Panel Rendering Helper
-- Used by multi() for lead and trail edge toggle panels.
--------------------------------------------------------------------------------

--- Render a toggle panel (lead or trail) with animation, size clamping, and child window.
--- For "lead" side: renders content first, then the toggle bar.
--- For "trail" side: renders the toggle bar first, then content.
---@param id string Base splitter identifier
---@param suffix string Toggle suffix ("lead" or "trail")
---@param panel table Panel definition with toggle, size, content fields
---@param side string Toggle bar side ("left", "right", "top", "bottom")
---@param isVertical boolean Whether the layout is vertical
---@param totalAvail number Total available space in the split direction
---@param availW number Available width from content region
---@param spacing number Item spacing to cancel between elements
---@param noScroll number ImGui child window flags for no-scroll
---@return table state Toggle state table
---@return number panelSize Computed panel size in pixels
---@return number barWidth Toggle bar width in pixels
local function renderTogglePanel(id, suffix, panel, side, isVertical, totalAvail, availW, spacing, noScroll)
    local tglId = id .. "_tgl_" .. suffix
    local state = getToggleState(tglId, panel)
    local eased = tickToggle(state)
    local expandedSize = parseSizeSpec(panel.size, totalAvail) or 0
    local panelSize = math.floor(expandedSize * eased)
    local barW = state.barWidth

    -- Skip sub-barW sizes to avoid CET min-height mismatch
    if panelSize > 0 and panelSize <= barW then
        if state.isOpen then
            panelSize = barW + 1
        else
            panelSize = 0
            state.animProgress = 0
        end
    end

    local isLead = (suffix == "lead")

    -- Render the child window content
    local function renderContent()
        if panelSize <= 0 then return end
        local cw = isVertical and availW or panelSize
        local ch = isVertical and panelSize or 0
        ImGui.BeginChild("##splitter_multi_" .. tglId, cw, ch, false, noScroll)
        if panelSize > barW and panel.content then
            local animating = state.animProgress > 0 and state.animProgress < 1
            if animating then ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, 0) end
            panel.content()
            if animating then ImGui.PopStyleVar() end
        end
        ImGui.EndChild()
    end

    if isLead then
        -- Lead: content first, then bar
        renderContent()
        if panelSize > 0 then cancelSpacing(isVertical, spacing) end
        drawToggleBar(tglId, state, side)
        cancelSpacing(isVertical, spacing)
    else
        -- Trail: bar first, then content
        cancelSpacing(isVertical, spacing)
        drawToggleBar(tglId, state, side)
        if panelSize > 0 then cancelSpacing(isVertical, spacing) end
        renderContent()
    end

    return state, panelSize, barW
end

--------------------------------------------------------------------------------
-- Divider Drag Update
--------------------------------------------------------------------------------

--- Apply drag deltas to breakpoints after all panels have rendered.
--- Must run post-render to prevent one-frame desync / rubber banding.
---@param ms table Multi-state table (breakpoints, dividers, minGap, panelDefs, dirty)
---@param coreN number Number of core (non-toggle) panels
---@param totalSize number Usable pixel size for core panels (excluding grab bars)
---@param coreAvail number Total core available space (including grab bars)
---@param grabW number Grab bar width in pixels
---@param isVertical boolean Whether the layout is vertical
---@param minFracs table Pre-computed minimum fractions per panel
local function applyDividerDrags(ms, coreN, totalSize, coreAvail, grabW, isVertical, minFracs)
    local minGap = ms.minGap

    -- Animation tick for multi dividers (used by context menu "Reset")
    for i = 1, coreN - 1 do
        local div = ms.dividers[i]
        if div.animProgress and div.animProgress < 1.0 then
            ms.breakpoints[i] = tickAnimation(div, COLLAPSE_SPEED)
            div.dragging = false
            ms.dirty = true
        end
    end

    -- Apply drag updates AFTER all rendering (prevents one-frame desync / rubber banding)
    for i = 1, coreN - 1 do
        if ms.dividers[i].dragging and (not ms.dividers[i].animProgress or ms.dividers[i].animProgress >= 1.0) then
            if not ms.dividers[i].dragOrigin then
                ms.dividers[i].dragOrigin = ms.breakpoints[i]
            end

            local dx, dy = ImGui.GetMouseDragDelta(0, 0)
            local delta = isVertical and dy or dx
            if delta ~= 0 then
                local oldBp = ms.breakpoints[i]
                local newBp = ms.dividers[i].dragOrigin + (delta / totalSize)
                if isCtrlHeld() then
                    local pixFrac = (newBp * totalSize + (i - 0.5) * grabW) / coreAvail
                    pixFrac = snapValue(pixFrac)
                    newBp = (pixFrac * coreAvail - (i - 0.5) * grabW) / totalSize
                end
                local shiftHeld = isShiftHeld()

                if shiftHeld then
                    newBp = math.max(minGap, math.min(1 - minGap, newBp))
                    ms.breakpoints[i] = newBp

                    if oldBp > 0 then
                        local leftScale = newBp / oldBp
                        for j = 1, i - 1 do
                            ms.breakpoints[j] = ms.breakpoints[j] * leftScale
                        end
                    end

                    if oldBp < 1 then
                        local rightScale = (1 - newBp) / (1 - oldBp)
                        for j = i + 1, coreN - 1 do
                            ms.breakpoints[j] = newBp + (ms.breakpoints[j] - oldBp) * rightScale
                        end
                    end
                else
                    local loBase = (i == 1) and 0 or ms.breakpoints[i - 1]
                    local hiBase = (i == coreN - 1) and 1 or ms.breakpoints[i + 1]

                    local leftMin = minFracs[i]
                    local rightMin = minFracs[i + 1]
                    local leftMax = getPanelMaxFrac(ms.panelDefs, i, totalSize, isVertical)
                    local rightMax = getPanelMaxFrac(ms.panelDefs, i + 1, totalSize, isVertical)

                    local lo = loBase + leftMin
                    local hi = hiBase - rightMin

                    local loMax = loBase + leftMax
                    local hiMin = hiBase - rightMax
                    if loMax < hi then hi = math.min(hi, loMax) end
                    if hiMin > lo then lo = math.max(lo, hiMin) end

                    ms.breakpoints[i] = math.max(lo, math.min(hi, newBp))
                end
                ms.dirty = true
            end
        else
            ms.dividers[i].dragOrigin = nil
        end
    end
end

--------------------------------------------------------------------------------
-- Multi-panel split
--------------------------------------------------------------------------------

--- Multi-panel layout with independent flat breakpoints.
--- Each divider moves independently - dragging divider i only affects panels i and i+1.
---@param id string Unique splitter identifier
---@param panels table Array of panel definitions ({ content, width/height, minWidth/minHeight, maxWidth/maxHeight, flex, toggle, size })
---@param opts? table Options: direction ("horizontal"|"vertical"), grabWidth, minPct, defaultPcts
function split.multi(id, panels, opts)
    if not panels or #panels < 2 then return end
    opts = opts or {}
    local n = #panels
    local isVertical = (opts.direction or "horizontal") == "vertical"

    -- Detect edge toggle panels (only first/last may be toggles)
    local leadToggle = panels[1] and panels[1].toggle and panels[1] or nil
    local trailToggle = panels[n] and panels[n].toggle and panels[n] or nil

    -- Build core (draggable) panel list
    local corePanels = {}
    local coreStart = leadToggle and 2 or 1
    local coreEnd = trailToggle and (n - 1) or n
    for i = coreStart, coreEnd do
        corePanels[#corePanels + 1] = panels[i]
    end
    local coreN = #corePanels
    if coreN < 1 then return end

    local ms = getMultiState(id, coreN, opts, corePanels)
    local grabW = ms.grabWidth
    local minGap = ms.minGap

    local noScroll = ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse

    local availW, availH = ImGui.GetContentRegionAvail()
    local totalAvail = isVertical and availH or availW
    local fc = controls.getFrameCache()
    local spacing = isVertical and fc.itemSpacingY or fc.itemSpacingX

    local leadState, leadSize, leadBarW = nil, 0, 0
    if leadToggle then
        leadState = getToggleState(id .. "_tgl_lead", leadToggle)
        local eased = tickToggle(leadState)
        local expandedSize = parseSizeSpec(leadToggle.size, totalAvail) or 0
        leadSize = math.floor(expandedSize * eased)
        leadBarW = leadState.barWidth
        -- Skip sub-barW sizes to avoid CET min-height mismatch
        if leadSize > 0 and leadSize <= leadBarW then
            if leadState.isOpen then
                leadSize = leadBarW + 1
            else
                leadSize = 0
                leadState.animProgress = 0
            end
        end
    end

    local trailState, trailSize, trailBarW = nil, 0, 0
    if trailToggle then
        trailState = getToggleState(id .. "_tgl_trail", trailToggle)
        local eased = tickToggle(trailState)
        local expandedSize = parseSizeSpec(trailToggle.size, totalAvail) or 0
        trailSize = math.floor(expandedSize * eased)
        trailBarW = trailState.barWidth
        if trailSize > 0 and trailSize <= trailBarW then
            if trailState.isOpen then
                trailSize = trailBarW + 1
            else
                trailSize = 0
                trailState.animProgress = 0
            end
        end
    end

    local toggleSpace = leadSize + leadBarW + trailSize + trailBarW
    local grabTotal = coreN > 1 and (coreN - 1) * grabW or 0
    local minCoreSpace = grabTotal + coreN  -- at least 1px per core panel
    local coreAvail = totalAvail - toggleSpace

    -- If toggles consume too much, compress them proportionally
    if coreAvail < minCoreSpace and (leadSize + trailSize) > 0 then
        local excess = minCoreSpace - coreAvail
        local toggleTotal = leadSize + trailSize
        if excess >= toggleTotal then
            leadSize = 0
            trailSize = 0
        else
            local ratio = excess / toggleTotal
            leadSize = math.max(0, math.floor(leadSize - leadSize * ratio))
            trailSize = math.max(0, math.floor(trailSize - trailSize * ratio))
        end
        toggleSpace = leadSize + leadBarW + trailSize + trailBarW
        coreAvail = totalAvail - toggleSpace
    end

    local coreUsable = coreAvail - grabTotal
    if coreUsable < 1 then return end  -- only fires if totalAvail is truly tiny
    local totalSize = coreUsable

    local minFracs = ms.minFracs
    for i = 1, coreN do
        minFracs[i] = getPanelMinFrac(corePanels, i, totalSize, minGap, isVertical)
    end

    if not ms.dirty then
        for i = 1, coreN - 1 do
            local div = ms.dividers[i]
            if div.dragging or (div.animProgress and div.animProgress < 1.0) then
                ms.dirty = true
                break
            end
        end
    end
    if not ms.dirty then
        if leadState and leadState.animProgress > 0 and leadState.animProgress < 1 then
            ms.dirty = true
        end
        if trailState and trailState.animProgress > 0 and trailState.animProgress < 1 then
            ms.dirty = true
        end
    end
    -- Available space changed (window resize)
    if not ms.dirty and ms.lastTotalAvail ~= totalAvail then
        ms.dirty = true
    end
    ms.lastTotalAvail = totalAvail

    local effectiveBps = ms.effectiveBps
    if ms.dirty then
        -- Per-frame enforcement of panel minimums (protects during window resize, not just drag)
        for i = 1, coreN - 1 do
            effectiveBps[i] = ms.breakpoints[i]
        end
        -- Forward pass: protect panels from left
        for i = 1, coreN - 1 do
            local prev = (i > 1) and effectiveBps[i - 1] or 0
            effectiveBps[i] = math.max(effectiveBps[i], prev + minFracs[i])
        end
        -- Backward pass: protect panels from right
        for i = coreN - 1, 1, -1 do
            local nxt = (i < coreN - 1) and effectiveBps[i + 1] or 1
            effectiveBps[i] = math.min(effectiveBps[i], nxt - minFracs[i + 1])
        end
        ms.dirty = false
    end

    local sizes = {}
    local consumed = 0
    for i = 1, coreN do
        local startFrac = (i == 1) and 0 or effectiveBps[i - 1]
        local endFrac = (i == coreN) and 1 or effectiveBps[i]
        if i == coreN then
            sizes[i] = coreUsable - consumed
        else
            sizes[i] = math.floor(coreUsable * (endFrac - startFrac))
            consumed = consumed + sizes[i]
        end
    end

    local totalMinPx = 0
    for i = 1, coreN do
        totalMinPx = totalMinPx + math.max(math.ceil(minFracs[i] * totalSize), 1)
    end
    splitterMinSizes[id] = totalMinPx + grabTotal + toggleSpace

    local leadSide = isVertical and "top" or "left"
    local trailSide = isVertical and "bottom" or "right"

    styles.PushScrollbar()

    -- 1. Lead toggle panel + toggle bar
    if leadToggle then
        renderTogglePanel(id, "lead", leadToggle, leadSide, isVertical, totalAvail, availW, spacing, noScroll)
    end

    -- 2. Core panels with dividers
    for i = 1, coreN do
        local cw = isVertical and availW or sizes[i]
        local ch = isVertical and sizes[i] or 0
        ImGui.BeginChild("##splitter_multi_" .. id .. "_p" .. i, cw, ch, false, noScroll)
        if corePanels[i].content then corePanels[i].content() end
        ImGui.EndChild()

        if i < coreN then
            cancelSpacing(isVertical, spacing)
            drawGrabBar(id .. "_d" .. i, ms.dividers[i], isVertical)
            drawContextMenu(id, i, ms, isVertical)
            cancelSpacing(isVertical, spacing)
        end
    end

    -- 3. Trail toggle bar + toggle panel
    if trailToggle then
        renderTogglePanel(id, "trail", trailToggle, trailSide, isVertical, totalAvail, availW, spacing, noScroll)
    end

    styles.PopScrollbar()

    -- 4. Post-render drag updates
    applyDividerDrags(ms, coreN, totalSize, coreAvail, grabW, isVertical, minFracs)
end

--- Reset a multi-splitter to default breakpoints
---@param id string Multi-splitter identifier
function split.resetMulti(id)
    local ms = multiStates[id]
    if ms then
        for i = 1, #ms.defaults do
            ms.breakpoints[i] = ms.defaults[i]
        end
        for i = 1, #ms.dividers do
            ms.dividers[i].animProgress = 1.0
        end
        ms.dirty = true
    end
end

return split
