------------------------------------------------------
-- WindowUtils - Discovery
-- Dynamic window discovery via RedCetWM plugin
------------------------------------------------------

local discovery = {}

-- Per-frame cache to avoid re-parsing layout string multiple times per frame
local cachedWindows = nil
local cacheGeneration = -1
local currentGeneration = 0
local lastLayoutString = nil

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
    local current = nil

    for line in layoutString:gmatch("[^\n]+") do
        local name = line:match("^%[Window%]%[(.-)%]")
        if name then
            -- Finalize previous window block
            if current then
                windows[#windows + 1] = current
            end
            current = {
                name = name,
                posX = 0, posY = 0,
                sizeX = 200, sizeY = 200,
                collapsed = false,
            }
        elseif current then
            -- Match fields by prefix (order-independent within block)
            local px, py = line:match("^Pos=(%d+),(%d+)")
            if px then
                current.posX = tonumber(px) or 0
                current.posY = tonumber(py) or 0
            else
                local sx, sy = line:match("^Size=(%d+),(%d+)")
                if sx then
                    current.sizeX = tonumber(sx) or 200
                    current.sizeY = tonumber(sy) or 200
                else
                    local cv = line:match("^Collapsed=(%d+)")
                    if cv then
                        current.collapsed = (cv == "1")
                    end
                end
            end
        end
    end
    -- Finalize last window block
    if current then
        windows[#windows + 1] = current
    end

    cachedWindows = windows
    cacheGeneration = currentGeneration
    return windows
end

return discovery
