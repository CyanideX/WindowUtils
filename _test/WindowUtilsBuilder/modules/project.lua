------------------------------------------------------
-- WindowUtils Builder - Project Model
-- Central state container for all Builder data
------------------------------------------------------

local element_defs = require("modules/element_defs")

local project = {}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local state = {
    elements = {},
    elementIndex = {},
    config = {
        windowTitle = "My Mod",
        windowWidth = 400,
        windowHeight = 300,
        modFolderName = "MyMod",
    },
    selectedId = nil,
    selectedZoneIdx = nil,
    dirty = false,
    undoStack = {},
    nextCounters = {},
}

local UNDO_MAX = 50

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------

local function deepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = deepCopy(v)
    end
    return copy
end

local function isValidName(name)
    if type(name) ~= "string" or name == "" then return false end
    return name:match("^[a-zA-Z0-9_]+$") ~= nil
end
local function sanitizeName(name)
    if type(name) ~= "string" then return "Element" end
    local sanitized = name:gsub("[^a-zA-Z0-9_]", "")
    if sanitized == "" then return "Element" end
    return sanitized
end

local function isNameUnique(name, excludeId)
    for _, el in ipairs(state.elements) do
        if el.name == name and el.id ~= excludeId then
            return false
        end
    end
    return true
end

local function makeUniqueName(baseName, excludeId)
    if isNameUnique(baseName, excludeId) then return baseName end
    local i = 1
    while true do
        local candidate = baseName .. "_" .. i
        if isNameUnique(candidate, excludeId) then return candidate end
        i = i + 1
    end
end

local function rebuildIndex()
    state.elementIndex = {}
    for _, el in ipairs(state.elements) do
        state.elementIndex[el.id] = el
    end
end

local function markDirty()
    state.dirty = true
end

--------------------------------------------------------------------------------
-- Undo
--------------------------------------------------------------------------------

local function pushUndo()
    local snapshot = {
        elements = deepCopy(state.elements),
        config = deepCopy(state.config),
        selectedId = state.selectedId,
        selectedZoneIdx = state.selectedZoneIdx,
        nextCounters = deepCopy(state.nextCounters),
    }
    state.undoStack[#state.undoStack + 1] = snapshot
    if #state.undoStack > UNDO_MAX then
        table.remove(state.undoStack, 1)
    end
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

function project.init()
    state.elements = {}
    state.elementIndex = {}
    state.config = {
        windowTitle = "My Mod",
        windowWidth = 400,
        windowHeight = 300,
        modFolderName = "MyMod",
    }
    state.selectedId = nil
    state.selectedZoneIdx = nil
    state.dirty = false
    state.undoStack = {}
    state.nextCounters = {}
end

--------------------------------------------------------------------------------
-- Element CRUD
--------------------------------------------------------------------------------

function project.addElement(typeName)
    local def = element_defs.get(typeName)
    if not def then
        print("[WindowUtilsBuilder] Unknown element type: " .. tostring(typeName))
        return nil
    end

    pushUndo()

    local counter = (state.nextCounters[typeName] or 0) + 1
    state.nextCounters[typeName] = counter

    local id = def.idPrefix .. "_" .. counter
    local name = typeName .. "_" .. counter

    local el = {
        id = id,
        name = name,
        type = typeName,
        parentId = nil,
        zoneIdx = nil,
        props = deepCopy(def.defaultProps),
    }

    if def.zones then
        el.zones = deepCopy(def.zones)
    end

    state.elements[#state.elements + 1] = el
    state.elementIndex[id] = el
    markDirty()
    return el
end

function project.removeElement(id)
    local el = state.elementIndex[id]
    if not el then
        print("[WindowUtilsBuilder] removeElement: element not found: " .. tostring(id))
        return
    end

    pushUndo()

    -- Clean up parent zone children list if parented
    if el.parentId and el.zoneIdx then
        local parent = state.elementIndex[el.parentId]
        if parent and parent.zones and parent.zones[el.zoneIdx] then
            local children = parent.zones[el.zoneIdx].children
            for i = #children, 1, -1 do
                if children[i] == id then
                    table.remove(children, i)
                    break
                end
            end
        end
    end

    -- Remove from elements array
    for i = #state.elements, 1, -1 do
        if state.elements[i].id == id then
            table.remove(state.elements, i)
            break
        end
    end

    state.elementIndex[id] = nil

    -- Clear selection if removed element was selected
    if state.selectedId == id then
        state.selectedId = nil
        state.selectedZoneIdx = nil
    end

    markDirty()
end

function project.duplicateElement(id)
    local el = state.elementIndex[id]
    if not el then
        print("[WindowUtilsBuilder] duplicateElement: element not found: " .. tostring(id))
        return nil
    end

    pushUndo()

    local counter = (state.nextCounters[el.type] or 0) + 1
    state.nextCounters[el.type] = counter

    local def = element_defs.get(el.type)
    local newId = (def and def.idPrefix or el.type:lower()) .. "_" .. counter
    local newName = makeUniqueName(el.name, nil)

    local newEl = deepCopy(el)
    newEl.id = newId
    newEl.name = newName

    -- Clear zone children for duplicated containers (start fresh)
    if newEl.zones then
        for _, zone in ipairs(newEl.zones) do
            zone.children = {}
        end
    end

    -- Insert after original
    local idx = project.getElementIndex(id)
    if idx then
        table.insert(state.elements, idx + 1, newEl)
    else
        state.elements[#state.elements + 1] = newEl
    end

    state.elementIndex[newId] = newEl
    markDirty()
    return newEl
end

function project.moveElement(id, direction)
    local idx = project.getElementIndex(id)
    if not idx then return end

    if direction == "up" and idx <= 1 then return end
    if direction == "down" and idx >= #state.elements then return end

    pushUndo()

    local targetIdx = direction == "up" and idx - 1 or idx + 1
    state.elements[idx], state.elements[targetIdx] = state.elements[targetIdx], state.elements[idx]
    markDirty()
end

function project.reorderElement(fromIdx, toIdx)
    if fromIdx < 1 or fromIdx > #state.elements then return end
    if toIdx < 1 or toIdx > #state.elements then return end
    if fromIdx == toIdx then return end

    pushUndo()

    local el = table.remove(state.elements, fromIdx)
    table.insert(state.elements, toIdx, el)
    markDirty()
end

function project.reparentElement(elementId, containerId, zoneIdx)
    local el = state.elementIndex[elementId]
    local container = state.elementIndex[containerId]
    if not el or not container then
        print("[WindowUtilsBuilder] reparentElement: invalid element or container")
        return
    end
    if not container.zones or not container.zones[zoneIdx] then
        print("[WindowUtilsBuilder] reparentElement: invalid zone index " .. tostring(zoneIdx))
        return
    end

    pushUndo()

    -- Remove from old parent zone if previously parented
    if el.parentId and el.zoneIdx then
        local oldParent = state.elementIndex[el.parentId]
        if oldParent and oldParent.zones and oldParent.zones[el.zoneIdx] then
            local children = oldParent.zones[el.zoneIdx].children
            for i = #children, 1, -1 do
                if children[i] == elementId then
                    table.remove(children, i)
                    break
                end
            end
        end
    end

    el.parentId = containerId
    el.zoneIdx = zoneIdx

    local children = container.zones[zoneIdx].children
    children[#children + 1] = elementId
    markDirty()
end

function project.moveChildInZone(elementId, direction)
    local el = state.elementIndex[elementId]
    if not el or not el.parentId or not el.zoneIdx then return end

    local parent = state.elementIndex[el.parentId]
    if not parent or not parent.zones or not parent.zones[el.zoneIdx] then return end

    local children = parent.zones[el.zoneIdx].children
    local pos = nil
    for i, childId in ipairs(children) do
        if childId == elementId then
            pos = i
            break
        end
    end
    if not pos then return end

    if direction == "up" and pos <= 1 then return end
    if direction == "down" and pos >= #children then return end

    pushUndo()

    local targetPos = direction == "up" and pos - 1 or pos + 1
    children[pos], children[targetPos] = children[targetPos], children[pos]
    markDirty()
end

function project.touchElement(id)
    if not state.elementIndex[id] then return end
    pushUndo()
    markDirty()
end

--------------------------------------------------------------------------------
-- Properties
--------------------------------------------------------------------------------

function project.setProperty(id, key, value)
    local el = state.elementIndex[id]
    if not el then
        print("[WindowUtilsBuilder] setProperty: element not found: " .. tostring(id))
        return
    end

    pushUndo()

    if key == "name" then
        local sanitized = sanitizeName(value)
        if sanitized ~= value then
            print("[WindowUtilsBuilder] Name sanitized: '" .. tostring(value) .. "' -> '" .. sanitized .. "'")
        end
        el.name = makeUniqueName(sanitized, id)
    else
        el.props[key] = value
    end

    markDirty()
end

--------------------------------------------------------------------------------
-- Lookups
--------------------------------------------------------------------------------

function project.findElement(id)
    return state.elementIndex[id]
end

function project.getElementIndex(id)
    for i, el in ipairs(state.elements) do
        if el.id == id then return i end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Selection
--------------------------------------------------------------------------------

function project.setSelected(id)
    if not state.elementIndex[id] then return end
    -- Only reset zone selection when selecting a DIFFERENT element
    if state.selectedId ~= id then
        state.selectedZoneIdx = nil
    end
    state.selectedId = id
end

function project.getSelected()
    if not state.selectedId then return nil end
    return state.elementIndex[state.selectedId]
end

function project.clearSelection()
    state.selectedId = nil
    state.selectedZoneIdx = nil
end

function project.setSelectedZone(zoneIdx)
    state.selectedZoneIdx = zoneIdx
end

function project.getSelectedZone()
    return state.selectedZoneIdx or 1
end

--------------------------------------------------------------------------------
-- Accessors
--------------------------------------------------------------------------------

function project.getElements()
    return state.elements
end

function project.getConfig()
    return state.config
end

function project.setConfig(key, value)
    pushUndo()
    state.config[key] = value
    markDirty()
end

--------------------------------------------------------------------------------
-- Undo
--------------------------------------------------------------------------------

function project.undo()
    if #state.undoStack == 0 then
        return false
    end

    local snapshot = table.remove(state.undoStack)
    state.elements = snapshot.elements
    state.config = snapshot.config
    state.selectedId = snapshot.selectedId
    state.selectedZoneIdx = snapshot.selectedZoneIdx
    state.nextCounters = snapshot.nextCounters
    rebuildIndex()
    markDirty()
    return true
end

--------------------------------------------------------------------------------
-- Dirty flag
--------------------------------------------------------------------------------

function project.isDirty()
    return state.dirty
end

function project.clearDirty()
    state.dirty = false
end

--------------------------------------------------------------------------------
-- Serialization
--------------------------------------------------------------------------------

function project.serialize()
    return {
        version = 1,
        config = deepCopy(state.config),
        elements = deepCopy(state.elements),
        nextCounters = deepCopy(state.nextCounters),
    }
end

function project.deserialize(data)
    if not data then
        print("[WindowUtilsBuilder] deserialize: nil data")
        return
    end

    state.config = data.config or {
        windowTitle = "My Mod",
        windowWidth = 400,
        windowHeight = 300,
        modFolderName = "MyMod",
    }
    state.elements = data.elements or {}
    state.nextCounters = data.nextCounters or {}
    state.selectedId = nil
    state.selectedZoneIdx = nil
    state.undoStack = {}
    state.dirty = false
    rebuildIndex()
end

return project
