------------------------------------------------------
-- WindowUtils - Search Module
-- Reusable search state manager with multi-word
-- matching, caching, and UI helpers
------------------------------------------------------

local settings = require("modules/settings")
local controls = require("modules/controls")

local search = {}

local registry = {}

--------------------------------------------------------------------------------
-- SearchState Methods
--------------------------------------------------------------------------------

local SearchState = {}
SearchState.__index = SearchState

local function splitWords(text)
    local words = {}
    for word in text:gmatch("%S+") do
        words[#words + 1] = word:lower()
    end
    return words
end

---@param text string
function SearchState:setQuery(text)
    if self.query == text then return end
    self.query = text
    self.words = splitWords(text)
    self.cacheVersion = self.cacheVersion + 1
end

function SearchState:clear()
    self.query = ""
    self.words = {}
    self.cacheVersion = self.cacheVersion + 1
end

---@return string
function SearchState:getQuery()
    return self.query
end

---@return boolean
function SearchState:isEmpty()
    return #self.words == 0
end

--- Test if a key matches the current query using its search terms string.
--- Terms is a space-separated string (not an array). Results are cached.
---@param key string Unique item identifier (used as cache key)
---@param terms string|nil Space-separated searchable terms
---@return boolean
function SearchState:matches(key, terms)
    if #self.words == 0 then return true end
    if not terms or terms == "" then return true end

    local cached = self.itemCache[key]
    if cached and cached.version == self.cacheVersion then
        return cached.result
    end

    local lowerTerms = terms:lower()
    local result = true
    for _, word in ipairs(self.words) do
        if not lowerTerms:find(word, 1, true) then
            result = false
            break
        end
    end

    self.itemCache[key] = { version = self.cacheVersion, result = result }
    return result
end

--- Test if any def with the given category matches the current query.
--- Supports prefix matching: category "general" matches defs with "general", "general.override", etc.
---@param category string Category identifier (exact or prefix)
---@param defs table Setting definitions table {key = {category, searchTerms, ...}}
---@param includeTooltips? boolean Include tooltip text in matching (default false)
---@return boolean
function SearchState:categoryHasMatch(category, defs, includeTooltips)
    if #self.words == 0 then return true end
    if not defs then return true end

    local cacheKey = "cat_" .. category
    local cached = self.categoryCache[cacheKey]
    if cached and cached.version == self.cacheVersion then
        return cached.result
    end

    local prefix = category .. "."
    local prefixLen = #prefix
    local result = false
    for key, def in pairs(defs) do
        local dc = def.category
        if dc and (dc == category or dc:sub(1, prefixLen) == prefix) then
            local terms = ""
            if def.label then terms = def.label end
            if def.searchTerms then terms = terms .. " " .. def.searchTerms end
            -- Include tooltip when opted in, or when there's no label (icon-only controls)
            if def.tooltip and (includeTooltips or not def.label) then
                terms = terms .. " " .. def.tooltip
            end
            if self:matches(key, terms) then
                result = true
                break
            end
        end
    end

    self.categoryCache[cacheKey] = { version = self.cacheVersion, result = result }
    return result
end

--- Push dimming style if item does not match. Returns match result.
---@param key string Item identifier
---@param terms string|nil Search terms
---@return boolean matches
function SearchState:beginDim(key, terms)
    local matched = self:matches(key, terms)
    if not matched and #self.words > 0 then
        ImGui.PushStyleVar(ImGuiStyleVar.Alpha, self.dimAlpha)
        self._dimPushed = true
    else
        self._dimPushed = false
    end
    return matched
end

--- Pop dimming style if it was pushed by beginDim.
function SearchState:endDim()
    if self._dimPushed then
        ImGui.PopStyleVar()
        self._dimPushed = false
    end
end

--------------------------------------------------------------------------------
-- Constructor and Registry
--------------------------------------------------------------------------------

--- Create a new search state bound to a unique identifier.
---@param id string Unique identifier for this search state
---@param opts? table {dimAlpha?: number} Alpha for non-matching items (default 0.25)
---@return table SearchState
function search.new(id, opts)
    opts = opts or {}

    if registry[id] then
        settings.debugPrint("search.new: overwriting existing search state '" .. id .. "'")
    end

    local state = setmetatable({
        id = id,
        query = "",
        words = {},
        cacheVersion = 0,
        itemCache = {},
        categoryCache = {},
        dimAlpha = opts.dimAlpha or 0.25,
        _dimPushed = false,
    }, SearchState)

    registry[id] = state
    return state
end

--- Retrieve an existing search state by identifier, or nil.
---@param id string
---@return table|nil SearchState
function search.get(id)
    if not id then return nil end
    return registry[id]
end

--------------------------------------------------------------------------------
-- SearchBar Control
--------------------------------------------------------------------------------

--- Render a search bar that drives a search state.
---@param state table|nil SearchState (no-op if nil)
---@param opts? table {cols?: number, placeholder?: string}
---@return string query Current query text
function search.SearchBar(state, opts)
    if not state then return "" end
    opts = opts or {}
    local newText, changed = controls.InputText(
        IconGlyphs.Magnify,
        "search_" .. state.id,
        state:getQuery(),
        { cols = opts.cols, placeholder = opts.placeholder }
    )
    if changed then
        state:setQuery(newText)
    end
    return state:getQuery()
end

return search
