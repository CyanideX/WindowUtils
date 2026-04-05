------------------------------------------------------
-- WindowUtils - Notifications
-- Toast notification queue
------------------------------------------------------

local styles = require("modules/styles")

local notifications = {}

local TOAST_FLAGS = nil

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local config = {
    position = "topRight",
    maxVisible = 5,
    ttl = 3.0,
    fadeOut = 0.5,
    offsetX = 20,
    offsetY = 20,
    toastWidth = 300,
    toastPadding = 8,
    spacing = 6,
    windowRounding = 4.0,
    windowBorderSize = 1.0,
}

--------------------------------------------------------------------------------
-- Internal State
--------------------------------------------------------------------------------

local queue = {}
local nextId = 1
local toRemove = {}
local toRemoveCount = 0

local levelColors = {
    info    = "blue",
    success = "green",
    warn    = "yellow",
    error   = "red",
}

local levelIcons = nil
local function ensureIcons()
    if levelIcons then return end
    levelIcons = {
        info    = IconGlyphs and IconGlyphs.InformationOutline or "i",
        success = IconGlyphs and IconGlyphs.CheckCircleOutline or "ok",
        warn    = IconGlyphs and IconGlyphs.AlertOutline or "!",
        error   = IconGlyphs and IconGlyphs.AlertOctagonOutline or "X",
    }
end

--------------------------------------------------------------------------------
-- Internal: Calculate toast position
--------------------------------------------------------------------------------

local function getScreenSize()
    local w, h = GetDisplayResolution()
    if not w or w <= 0 then return 1920, 1080 end
    return w, h
end

local function getToastPosition(yOffset, toastH)
    local screenW, screenH = getScreenSize()
    local x, y

    if config.position == "topRight" then
        x = screenW - config.toastWidth - config.offsetX
        y = config.offsetY + yOffset
    elseif config.position == "topLeft" then
        x = config.offsetX
        y = config.offsetY + yOffset
    elseif config.position == "bottomRight" then
        x = screenW - config.toastWidth - config.offsetX
        y = screenH - config.offsetY - yOffset - toastH
    elseif config.position == "bottomLeft" then
        x = config.offsetX
        y = screenH - config.offsetY - yOffset - toastH
    else
        x = screenW - config.toastWidth - config.offsetX
        y = config.offsetY + yOffset
    end

    return x, y
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Show an info notification.
---@param message string Notification text
---@param opts? table {ttl?: number, fadeOut?: number}
function notifications.info(message, opts)
    notifications.show(message, "info", opts)
end

--- Show a success notification.
---@param message string Notification text
---@param opts? table {ttl?: number, fadeOut?: number}
function notifications.success(message, opts)
    notifications.show(message, "success", opts)
end

--- Show a warning notification.
---@param message string Notification text
---@param opts? table {ttl?: number, fadeOut?: number}
function notifications.warn(message, opts)
    notifications.show(message, "warn", opts)
end

--- Show an error notification.
---@param message string Notification text
---@param opts? table {ttl?: number, fadeOut?: number}
function notifications.error(message, opts)
    notifications.show(message, "error", opts)
end

--- Show a notification with a specific level.
---@param message string Notification text
---@param level? string "info"|"success"|"warn"|"error" (default "info")
---@param opts? table {ttl?: number, fadeOut?: number}
function notifications.show(message, level, opts)
    opts = opts or {}
    local toast = {
        id = nextId,
        message = message,
        level = level or "info",
        spawnTime = os.clock(),
        ttl = opts.ttl or config.ttl,
        fadeOut = opts.fadeOut or config.fadeOut,
    }
    nextId = nextId + 1
    table.insert(queue, toast)

    while #queue > config.maxVisible * 2 do
        table.remove(queue, 1)
    end
end

--- Draw all active notifications (call once per frame from init.lua onDraw)
function notifications.draw()
    if #queue == 0 then return end

    ensureIcons()

    local now = os.clock()
    local visibleIndex = 0
    local yOffset = 0
    local defaultToastH = ImGui.GetTextLineHeightWithSpacing() + config.toastPadding * 2
    toRemoveCount = 0

    for i, toast in ipairs(queue) do
        local elapsed = now - toast.spawnTime
        local totalLife = toast.ttl + toast.fadeOut

        if elapsed >= totalLife then
            toRemoveCount = toRemoveCount + 1
            toRemove[toRemoveCount] = i
        else
            visibleIndex = visibleIndex + 1
            if visibleIndex > config.maxVisible then
                -- Keep in queue for ordering, just don't render
            else
                local alpha = 1.0
                if elapsed > toast.ttl then
                    local fadeElapsed = elapsed - toast.ttl
                    alpha = 1.0 - (fadeElapsed / toast.fadeOut)
                    alpha = math.max(0, math.min(1, alpha))
                end

                -- Use cached height from previous frame, or fall back to estimate
                local estimatedH = toast.lastHeight or defaultToastH
                local posX, posY = getToastPosition(yOffset, estimatedH)
                local colorKey = levelColors[toast.level] or "blue"
                local color = styles.colors[colorKey] or styles.colors.blue
                local icon = levelIcons[toast.level] or ""

                local windowName = "##wu_toast_" .. toast.id
                ImGui.SetNextWindowPos(posX, posY, ImGuiCond.Always)
                ImGui.SetNextWindowSize(config.toastWidth, 0)
                ImGui.SetNextWindowBgAlpha(0.92 * alpha)
                ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, config.windowRounding)
                ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, config.toastPadding, config.toastPadding)
                ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, config.windowBorderSize)
                ImGui.PushStyleColor(ImGuiCol.Border, ImGui.GetColorU32(color[1], color[2], color[3], 0.6 * alpha))

                if not TOAST_FLAGS then
                    TOAST_FLAGS = ImGuiWindowFlags.NoTitleBar
                        + ImGuiWindowFlags.NoResize
                        + ImGuiWindowFlags.NoMove
                        + ImGuiWindowFlags.NoScrollbar
                        + ImGuiWindowFlags.NoInputs
                        + ImGuiWindowFlags.NoFocusOnAppearing
                        + ImGuiWindowFlags.AlwaysAutoResize
                        + ImGuiWindowFlags.NoSavedSettings
                end

                if ImGui.Begin(windowName, TOAST_FLAGS) then
                    ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(color[1], color[2], color[3], alpha))
                    ImGui.Text(icon)
                    ImGui.PopStyleColor()

                    ImGui.SameLine()

                    ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(1.0, 1.0, 1.0, alpha))
                    ImGui.TextWrapped(toast.message)
                    ImGui.PopStyleColor()
                end

                -- Capture actual rendered height for next frame's layout
                local _, actualH = ImGui.GetWindowSize()
                toast.lastHeight = actualH

                ImGui.End()

                ImGui.PopStyleColor()
                ImGui.PopStyleVar(3)

                yOffset = yOffset + actualH + config.spacing
            end
        end
    end

    for i = toRemoveCount, 1, -1 do
        table.remove(queue, toRemove[i])
    end
end

--- Configure notification defaults.
---@param opts? table Key-value pairs to merge into config (position, maxVisible, ttl, etc.)
function notifications.configure(opts)
    if not opts then return end
    for k, v in pairs(opts) do
        if config[k] ~= nil then
            config[k] = v
        end
    end
end

--- Clear all pending notifications
function notifications.clear()
    queue = {}
end

--- Get current notification count.
---@return number
function notifications.count()
    return #queue
end

return notifications
