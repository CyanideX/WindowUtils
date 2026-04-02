------------------------------------------------------
-- WindowUtils - Registry Module
-- Window metadata registry for pOpen/close-button tracking
------------------------------------------------------

local registry = {}

-- { [normalizedKey] = { hasCloseButton = bool, originalName = string } }
local entries = {}

--- Extract the stable ID portion from a window name.
--- ### syntax: key is "###" .. id (matches across display prefixes).
--- ## syntax or plain name: key is the full string (exact match only).
---@param windowName string
---@return string key
local function normalizeKey(windowName)
    local id = windowName:match("###(.+)$")
    if id then return "###" .. id end
    return windowName
end

---@param windowName string Window name (may contain ## or ### syntax)
---@param options table { hasCloseButton = boolean }
---@return boolean success
function registry.register(windowName, options)
    local key = normalizeKey(windowName)
    entries[key] = {
        hasCloseButton = options.hasCloseButton or false,
        originalName = windowName,
    }
    return true
end

---@param windowName string
---@return boolean success True if the entry existed and was removed
function registry.unregister(windowName)
    local key = normalizeKey(windowName)
    if entries[key] then
        entries[key] = nil
        return true
    end
    return false
end

---@param windowName string The discovered or registered window name
---@return table|nil entry { hasCloseButton = bool, originalName = string } or nil
function registry.lookup(windowName)
    local key = normalizeKey(windowName)
    return entries[key]
end

--- Get all registered entries (for debugging).
---@return table entries Copy of the registry
function registry.getAll()
    local copy = {}
    for k, v in pairs(entries) do
        copy[k] = { hasCloseButton = v.hasCloseButton, originalName = v.originalName }
    end
    return copy
end

--- Clear all entries.
function registry.clear()
    entries = {}
end

return registry
