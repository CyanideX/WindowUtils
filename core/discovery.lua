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

-- Pooled window tables to avoid per-frame allocation during re-parse
local pooledWindows = {}
local pooledCount = 0

--- Invalidate the per-frame cache (call once at start of each frame).
function discovery.invalidateCache()
    currentGeneration = currentGeneration + 1
end

--- Return the current cache generation counter.
--- Used by the browser sort cache to detect when discovery data has changed.
---@return number
function discovery.getGeneration()
    return currentGeneration
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

    local writeIndex = 0
    local current = nil

    for line in layoutString:gmatch("[^\n]+") do
        local name = line:match("^%[Window%]%[(.-)%]")
        if name then
            -- Finalize previous window block into pool
            if current then
                writeIndex = writeIndex + 1
                local entry = pooledWindows[writeIndex]
                if entry then
                    entry.name = current.name
                    entry.posX = current.posX
                    entry.posY = current.posY
                    entry.sizeX = current.sizeX
                    entry.sizeY = current.sizeY
                    entry.collapsed = current.collapsed
                else
                    pooledWindows[writeIndex] = current
                end
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
    -- Finalize last window block into pool
    if current then
        writeIndex = writeIndex + 1
        local entry = pooledWindows[writeIndex]
        if entry then
            entry.name = current.name
            entry.posX = current.posX
            entry.posY = current.posY
            entry.sizeX = current.sizeX
            entry.sizeY = current.sizeY
            entry.collapsed = current.collapsed
        else
            pooledWindows[writeIndex] = current
        end
    end

    -- Clear stale entries when window count shrinks
    for i = writeIndex + 1, pooledCount do
        pooledWindows[i] = nil
    end
    pooledCount = writeIndex

    cachedWindows = pooledWindows
    cacheGeneration = currentGeneration
    return pooledWindows
end

return discovery
