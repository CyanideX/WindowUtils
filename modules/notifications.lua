------------------------------------------------------
-- WindowUtils - Notifications Module
-- Toast notification queue rendered at screen edge
------------------------------------------------------

local styles = require("modules/styles")

local notifications = {}

local TOAST_FLAGS = nil

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local config = {
    position = "topRight",  -- "topRight", "topLeft", "bottomRight", "bottomLeft"
    maxVisible = 5,
    ttl = 3.0,              -- seconds before fade starts
    fadeOut = 0.5,           -- seconds for fade-out
    offsetX = 20,           -- pixels from screen edge
    offsetY = 20,           -- pixels from screen edge
    toastWidth = 300,
    toastPadding = 8,
    spacing = 6,            -- vertical gap between toasts
    windowRounding = 4.0,   -- corner rounding for toast windows
    windowBorderSize = 1.0, -- border thickness for toast windows
}

--------------------------------------------------------------------------------
-- Internal State
--------------------------------------------------------------------------------

local queue = {}  -- { message, level, spawnTime, ttl, fadeOut }
local nextId = 1

-- Level colors mapped to styles.colors
local levelColors = {
    info    = "blue",
    success = "green",
    warn    = "yellow",
    error   = "red",
}

-- Level icons (lazy-loaded)
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
    local ok, w, h = pcall(GetDisplayResolution)
    if not ok or not w or w <= 0 then
        return 1920, 1080
    end
    return w, h
end

local function getToastPosition(index)
    local screenW, screenH = getScreenSize()
    local x, y

    local totalHeight = (index - 1) * (ImGui.GetTextLineHeightWithSpacing() + config.toastPadding * 2 + config.spacing)

    if config.position == "topRight" then
        x = screenW - config.toastWidth - config.offsetX
        y = config.offsetY + totalHeight
    elseif config.position == "topLeft" then
        x = config.offsetX
        y = config.offsetY + totalHeight
    elseif config.position == "bottomRight" then
        x = screenW - config.toastWidth - config.offsetX
        y = screenH - config.offsetY - totalHeight - (ImGui.GetTextLineHeightWithSpacing() + config.toastPadding * 2)
    elseif config.position == "bottomLeft" then
        x = config.offsetX
        y = screenH - config.offsetY - totalHeight - (ImGui.GetTextLineHeightWithSpacing() + config.toastPadding * 2)
    else
        x = screenW - config.toastWidth - config.offsetX
        y = config.offsetY + totalHeight
    end

    return x, y
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Show an info notification
function notifications.info(message, opts)
    notifications.show(message, "info", opts)
end

--- Show a success notification
function notifications.success(message, opts)
    notifications.show(message, "success", opts)
end

--- Show a warning notification
function notifications.warn(message, opts)
    notifications.show(message, "warn", opts)
end

--- Show an error notification
function notifications.error(message, opts)
    notifications.show(message, "error", opts)
end

--- Show a notification with a specific level
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

    -- Trim oldest if over max
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
    local toRemove = {}

    for i, toast in ipairs(queue) do
        local elapsed = now - toast.spawnTime
        local totalLife = toast.ttl + toast.fadeOut

        -- Mark for removal if fully expired
        if elapsed >= totalLife then
            table.insert(toRemove, i)
        else
            visibleIndex = visibleIndex + 1
            if visibleIndex > config.maxVisible then
                -- Don't render beyond max, but keep in queue for ordering
            else
                -- Calculate alpha
                local alpha = 1.0
                if elapsed > toast.ttl then
                    -- In fade-out phase
                    local fadeElapsed = elapsed - toast.ttl
                    alpha = 1.0 - (fadeElapsed / toast.fadeOut)
                    alpha = math.max(0, math.min(1, alpha))
                end

                -- Get position and color
                local posX, posY = getToastPosition(visibleIndex)
                local colorKey = levelColors[toast.level] or "blue"
                local color = styles.colors[colorKey] or styles.colors.blue
                local icon = levelIcons[toast.level] or ""

                -- Render toast as a positioned window
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
                    -- Icon + message on same line
                    ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(color[1], color[2], color[3], alpha))
                    ImGui.Text(icon)
                    ImGui.PopStyleColor()

                    ImGui.SameLine()

                    ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(1.0, 1.0, 1.0, alpha))
                    ImGui.TextWrapped(toast.message)
                    ImGui.PopStyleColor()
                end
                ImGui.End()

                ImGui.PopStyleColor()
                ImGui.PopStyleVar(3)
            end
        end
    end

    -- Remove expired toasts (iterate in reverse to preserve indices)
    for i = #toRemove, 1, -1 do
        table.remove(queue, toRemove[i])
    end
end

--- Configure notification defaults
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

--- Get current notification count
function notifications.count()
    return #queue
end

return notifications
