------------------------------------------------------
-- WindowUtils - Discovery Module
-- Dynamic window discovery via RedCetWM plugin
------------------------------------------------------

local discovery = {}

--------------------------------------------------------------------------------
-- Plugin Detection
--------------------------------------------------------------------------------

--- Check if RedCetWM plugin is available.
-- @return boolean: True if the plugin is loaded and functional
function discovery.isAvailable()
    return RedCetWM ~= nil and RedCetWM.GetWindowLayout ~= nil
end

--------------------------------------------------------------------------------
-- Window Discovery
--------------------------------------------------------------------------------

--- Get all active ImGui windows from the layout.
-- Parses the layout string returned by RedCetWM.GetWindowLayout()
-- Format: [Window][WindowName]\nPos=X,Y\nSize=W,H\nCollapsed=0|1
-- @return table: Array of window info tables {name, posX, posY, sizeX, sizeY, collapsed}
function discovery.getActiveWindows()
    if not discovery.isAvailable() then
        return {}
    end

    local windows = {}
    local layoutString = RedCetWM.GetWindowLayout()

    if not layoutString or layoutString == "" then
        return {}
    end

    -- Parse layout string into lines
    local layoutLines = {}
    for line in layoutString:gmatch("[^\n]+") do
        table.insert(layoutLines, line)
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

                table.insert(windows, {
                    name = name,
                    posX = posX,
                    posY = posY,
                    sizeX = sizeX,
                    sizeY = sizeY,
                    collapsed = collapsed
                })
            end
        end
    end

    return windows
end

--- Get just the window names (convenience function).
-- @return table: Array of window name strings
function discovery.getWindowNames()
    local names = {}
    local windows = discovery.getActiveWindows()

    for _, window in ipairs(windows) do
        table.insert(names, window.name)
    end

    return names
end

return discovery
