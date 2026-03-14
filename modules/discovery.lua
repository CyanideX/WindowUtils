------------------------------------------------------
-- WindowUtils - Discovery Module
-- Dynamic window discovery via RedCetWM plugin
------------------------------------------------------

local discovery = {}

-- Per-frame cache to avoid re-parsing layout string multiple times per frame
local cachedWindows = nil
local cacheGeneration = -1
local currentGeneration = 0
local lastLayoutString = nil  -- Skip re-parsing when layout string unchanged

--- Invalidate the per-frame cache (call once at start of each frame).
function discovery.invalidateCache()
    currentGeneration = currentGeneration + 1
end

--------------------------------------------------------------------------------
-- Plugin Detection
--------------------------------------------------------------------------------

--- Check if the RedCetWM window discovery plugin is available.
---@return boolean
function discovery.isAvailable()
    return RedCetWM ~= nil and RedCetWM.GetWindowLayout ~= nil
end

--------------------------------------------------------------------------------
-- Window Discovery
--------------------------------------------------------------------------------

--- Parse layout string from RedCetWM into window info tables.
--- Results are cached per-frame; call invalidateCache() to refresh.
---@return table[] windows Array of {name, posX, posY, sizeX, sizeY, collapsed}
function discovery.getActiveWindows()
    if not discovery.isAvailable() then
        return {}
    end

    -- Return cached result if still valid this frame
    if cachedWindows and cacheGeneration == currentGeneration then
        return cachedWindows
    end

    local layoutString = RedCetWM.GetWindowLayout()

    if not layoutString or layoutString == "" then
        cachedWindows = {}
        cacheGeneration = currentGeneration
        lastLayoutString = layoutString
        return cachedWindows
    end

    -- Skip re-parsing if layout string hasn't changed since last parse
    if layoutString == lastLayoutString and cachedWindows then
        cacheGeneration = currentGeneration
        return cachedWindows
    end
    lastLayoutString = layoutString

    local windows = {}

    -- Parse layout string into lines
    local layoutLines = {}
    for line in layoutString:gmatch("[^\n]+") do
        layoutLines[#layoutLines + 1] = line
    end

    -- Extract window information
    for i, line in ipairs(layoutLines) do
        -- Find window header lines: [Window][WindowName]
        if line:find("[Window]", 1, true) == 1 then
            local name = line:match("%[Window%]%[(.-)%]")

            if name then
                -- Parse position from next line (Pos=X,Y)
                local posX, posY = 0, 0
                if layoutLines[i + 1] then
                    posX, posY = layoutLines[i + 1]:match("Pos=(%d+),(%d+)")
                    posX = tonumber(posX) or 0
                    posY = tonumber(posY) or 0
                end

                -- Parse size from line after that (Size=W,H)
                local sizeX, sizeY = 200, 200
                if layoutLines[i + 2] then
                    sizeX, sizeY = layoutLines[i + 2]:match("Size=(%d+),(%d+)")
                    sizeX = tonumber(sizeX) or 200
                    sizeY = tonumber(sizeY) or 200
                end

                -- Parse collapsed state (Collapsed=0|1)
                local collapsed = false
                if layoutLines[i + 3] then
                    local collapsedVal = layoutLines[i + 3]:match("Collapsed=(%d+)")
                    collapsed = (collapsedVal == "1")
                end

                windows[#windows + 1] = {
                    name = name,
                    posX = posX,
                    posY = posY,
                    sizeX = sizeX,
                    sizeY = sizeY,
                    collapsed = collapsed
                }
            end
        end
    end

    cachedWindows = windows
    cacheGeneration = currentGeneration
    return windows
end

--- Get an array of all discovered window names.
---@return string[]
function discovery.getWindowNames()
    local names = {}
    local windows = discovery.getActiveWindows()

    for _, window in ipairs(windows) do
        table.insert(names, window.name)
    end

    return names
end

return discovery
