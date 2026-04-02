------------------------------------------------------
-- WindowUtils - Modal Module
-- Centered popup system with button configuration
-- and convenience functions
------------------------------------------------------

local settings = require("core/settings")
local controls = require("modules/controls")
local splitter = require("modules/splitter")
local styles   = require("modules/styles")

local modal = {}

local activeModals = {}

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

--- Open a modal popup.
---@param id string Unique modal identifier
---@param opts table {title?, body?, content?, buttons?, widthPercent?, heightPercent?, maxHeightPercent?, paddingPercent?, styled?, panelBg?}
function modal.open(id, opts)
    opts = opts or {}
    if activeModals[id] then
        settings.debugPrint("modal.open: replacing existing modal '" .. id .. "'")
    end
    local title = opts.title or id
    local entry = {
        id = id,
        title = title,
        popupLabel = title .. "###" .. id,
        body = opts.body,
        content = opts.content,
        buttons = opts.buttons,
        widthPercent = opts.widthPercent or 33,
        heightPercent = opts.heightPercent,
        maxHeightPercent = opts.maxHeightPercent or 50,
        paddingPercent = opts.paddingPercent,
        styled = opts.styled,
        panelBg = opts.panelBg,
        pendingOpen = true,
    }
    -- Pre-build button defs with close-wrapping (avoids per-frame closure creation)
    entry.cachedButtonDefs = buildButtonDefs(entry)
    activeModals[id] = entry
end

--- Close an open modal.
---@param id string
function modal.close(id)
    if not activeModals[id] then return end
    ImGui.CloseCurrentPopup()
    activeModals[id] = nil
end

---@param id string
---@return boolean
function modal.isOpen(id)
    return activeModals[id] ~= nil
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

--- Wrap button callbacks to auto-close the modal.
local function buildButtonDefs(entry)
    local buttons = entry.buttons or {
        { label = "OK", style = "active" }
    }
    local defs = {}
    for i, btn in ipairs(buttons) do
        local def = {
            label = btn.label, icon = btn.icon, style = btn.style,
            weight = btn.weight, disabled = btn.disabled, tooltip = btn.tooltip,
            id = btn.id or (entry.id .. "_btn_" .. i),
            holdDuration = btn.holdDuration,
            progressDisplay = btn.progressDisplay,
            warningMessage = btn.warningMessage,
        }
        local shouldClose = btn.closesModal ~= false

        if btn.onHold then
            local orig = btn.onHold
            def.onHold = shouldClose
                and function() orig(); modal.close(entry.id) end
                or orig
        end

        if btn.onClick then
            local orig = btn.onClick
            def.onClick = shouldClose
                and function() orig(); modal.close(entry.id) end
                or orig
        elseif not btn.onHold and shouldClose then
            def.onClick = function() modal.close(entry.id) end
        end

        defs[i] = def
    end
    return defs
end

--- Render the styled variant: centered title + draw-list panel background.
local function drawStyledContent(entry, contentWidth)
    local titleW = ImGui.CalcTextSize(entry.title)
    ImGui.SetCursorPosX(ImGui.GetCursorPosX() + (contentWidth - titleW) * 0.5)
    ImGui.Text(entry.title)
    ImGui.Dummy(0, 4)

    local bg = entry.panelBg or { 0.65, 0.7, 1.0, 0.0225 }
    local drawList = ImGui.GetWindowDrawList()
    local panelPad = ImGui.GetStyle().WindowPadding
    local startX, startY = ImGui.GetCursorScreenPos()

    ImGui.Dummy(0, panelPad.y)
    ImGui.Indent(panelPad.x)
    local innerW = contentWidth - panelPad.x * 2

    if entry.body then
        ImGui.PushTextWrapPos(ImGui.GetCursorPosX() + innerW)
        ImGui.TextWrapped(entry.body)
        ImGui.PopTextWrapPos()
    end
    if entry.content then
        entry.content(innerW)
    end

    ImGui.Unindent(panelPad.x)
    ImGui.Dummy(0, panelPad.y)
    local endY = select(2, ImGui.GetCursorScreenPos())

    local bgColor = ImGui.GetColorU32(bg[1], bg[2], bg[3], bg[4])
    ImGui.ImDrawListAddRectFilled(drawList, startX, startY, startX + contentWidth, endY, bgColor, 4.0)
    ImGui.Dummy(0, 4)
end

--- Render the standard variant: body text + content callback.
local function drawStandardContent(entry, contentWidth, hasPadding)
    if entry.body then
        if hasPadding then
            ImGui.PushTextWrapPos(ImGui.GetCursorPosX() + contentWidth)
            ImGui.TextWrapped(entry.body)
            ImGui.PopTextWrapPos()
        else
            ImGui.TextWrapped(entry.body)
        end
    end
    if entry.content then
        local innerWidth = hasPadding and contentWidth or ImGui.GetContentRegionAvail()
        entry.content(innerWidth)
    end
end

--- Render all active modals. Call once per frame.
function modal.draw()
    if not next(activeModals) then return end

    local sw, sh = GetDisplayResolution()
    local toRemove = {}

    for id, entry in pairs(activeModals) do
        if entry.pendingOpen then
            ImGui.OpenPopup(entry.popupLabel)
            entry.pendingOpen = false
            goto continue
        end

        local width = math.floor(sw * entry.widthPercent / 100)
        local minH = 0
        local maxH = math.floor(sh * entry.maxHeightPercent / 100)
        if entry.heightPercent then
            local h = math.floor(sh * entry.heightPercent / 100)
            minH = h
            maxH = h
        end
        ImGui.SetNextWindowSizeConstraints(width, minH, width, maxH)
        ImGui.SetNextWindowPos(sw / 2, sh / 2, ImGuiCond.Always, 0.5, 0.5)

        -- Auto-resize for dynamic height, fixed size when heightPercent is set
        local flags = ImGuiWindowFlags.NoMove
        if entry.heightPercent then
            flags = flags + ImGuiWindowFlags.NoResize
        else
            flags = flags + ImGuiWindowFlags.AlwaysAutoResize
        end
        if entry.styled then
            flags = flags + ImGuiWindowFlags.NoTitleBar
        end

        if ImGui.BeginPopupModal(entry.popupLabel, flags) then
            local winPadX = ImGui.GetStyle().WindowPadding.x
            local contentWidth = width - winPadX * 2

            -- Optional percent-based inner padding
            local hasPadding = entry.paddingPercent and entry.paddingPercent > 0
            local padPx = hasPadding and math.floor(sw * entry.paddingPercent / 100) or 0
            if hasPadding then
                local padY = math.floor(sh * entry.paddingPercent / 100)
                ImGui.Dummy(0, padY)
                ImGui.Indent(padPx)
                contentWidth = contentWidth - padPx * 2
            end

            if entry.styled then
                drawStyledContent(entry, contentWidth)
            else
                drawStandardContent(entry, contentWidth, hasPadding)
            end

            if hasPadding then
                local padY = math.floor(sh * entry.paddingPercent / 100)
                ImGui.Unindent(padPx)
                ImGui.Dummy(0, padY)
            end

            controls.ButtonRow(entry.cachedButtonDefs)
            ImGui.EndPopup()
        else
            toRemove[#toRemove + 1] = id
        end

        ::continue::
    end

    for _, rid in ipairs(toRemove) do
        activeModals[rid] = nil
    end
end

--------------------------------------------------------------------------------
-- Convenience Functions
--------------------------------------------------------------------------------

--- Confirmation dialog with Confirm + Cancel buttons.
--- Set holdToConfirm = true for a hold-to-confirm button.
---@param id string
---@param opts table {title?, body?, content?, onConfirm, holdToConfirm?, holdDuration?, widthPercent?, maxHeightPercent?, styled?, panelBg?}
function modal.confirm(id, opts)
    opts = opts or {}
    local confirmBtn = { label = "Confirm", style = "active" }
    if opts.holdToConfirm then
        confirmBtn.onHold = opts.onConfirm
        confirmBtn.holdDuration = opts.holdDuration or 1.5
        confirmBtn.progressDisplay = "overlay"
    else
        confirmBtn.onClick = opts.onConfirm
    end
    opts.buttons = { confirmBtn, { label = "Cancel", style = "inactive" } }
    modal.open(id, opts)
end

--- Alert dialog with a single OK button.
---@param id string
---@param opts table {title?, body?, content?, widthPercent?, maxHeightPercent?, styled?, panelBg?}
function modal.alert(id, opts)
    opts = opts or {}
    opts.buttons = { { label = "OK", style = "active" } }
    modal.open(id, opts)
end

--- Info dialog with a single Close button.
---@param id string
---@param opts table {title?, body?, content?, widthPercent?, maxHeightPercent?, styled?, panelBg?}
function modal.info(id, opts)
    opts = opts or {}
    opts.buttons = { { label = "Close", style = "inactive" } }
    modal.open(id, opts)
end

--- Styled dialog with centered title and panel-wrapped body.
---@param id string
---@param opts table {title?, body?, content?, buttons?, widthPercent?, maxHeightPercent?, panelBg?}
function modal.styled(id, opts)
    opts = opts or {}
    opts.styled = true
    if not opts.buttons then
        opts.buttons = { { label = "Close", style = "inactive" } }
    end
    modal.open(id, opts)
end

--------------------------------------------------------------------------------
-- Changelog Preset
--------------------------------------------------------------------------------

-- Per-changelog selected version index
local changelogState = {}

--- Changelog dialog with version sidebar and scrollable changes panel.
--- versions: array of {version = "1.0.0", date? = "2026-01-01", changes = {"Added X", "Fixed Y"}}
--- Versions are displayed in array order (put newest first).
---@param id string
---@param opts table {title?, versions: table[], widthPercent?, heightPercent?, maxHeightPercent?, buttons?}
function modal.changelog(id, opts)
    opts = opts or {}
    local versions = opts.versions or {}
    local userButtons = opts.buttons or { { label = "Close", style = "inactive" } }

    if not changelogState[id] then
        changelogState[id] = 1
    end

    local contentFn = function()
        if #versions == 0 then
            controls.TextMuted("No changelog entries.")
            return
        end

        local sel = changelogState[id] or 1
        if sel > #versions then sel = 1; changelogState[id] = 1 end

        -- Column layout: flex splitter fills space, auto buttons anchor to bottom
        controls.Column("##cl_col_" .. id, {
            { flex = 1, content = function()
                splitter.multi("##cl_" .. id, {
                    { content = function()
                        controls.Panel("##cl_nav_" .. id, function()
                            for i, v in ipairs(versions) do
                                if controls.DynamicButton(v.version, nil, {
                                    style = sel == i and "active" or "inactive",
                                    width = -1,
                                }) then
                                    changelogState[id] = i
                                end
                            end
                        end)
                    end },
                    { content = function()
                        local entry = versions[sel]
                        if not entry then return end

                        controls.Panel("##cl_changes_" .. id, function()
                            ImGui.Text(entry.version)
                            if entry.date then
                                ImGui.SameLine()
                                styles.PushTextMuted()
                                ImGui.Text("  " .. entry.date)
                                styles.PopTextMuted()
                            end
                            ImGui.Separator()
                            ImGui.Dummy(0, 2)

                            for _, change in ipairs(entry.changes or {}) do
                                ImGui.Bullet()
                                ImGui.TextWrapped(change)
                            end
                        end)
                    end },
                }, { direction = "horizontal", defaultPcts = { 0.25, 0.75 } })
            end },
            { auto = true, content = function()
                controls.ButtonRow(buildButtonDefs({
                    id = id,
                    buttons = userButtons,
                }))
            end },
        })
    end

    modal.open(id, {
        title = opts.title or "Changelog",
        widthPercent = opts.widthPercent or 30,
        heightPercent = opts.heightPercent or 75,
        maxHeightPercent = opts.maxHeightPercent or 80,
        content = contentFn,
        -- Empty buttons so modal.draw() doesn't render a second row
        buttons = {},
    })
end

return modal
