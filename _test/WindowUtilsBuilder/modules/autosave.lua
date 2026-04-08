------------------------------------------------------
-- WindowUtils Builder - Autosave Manager
-- Debounced JSON persistence for project state
------------------------------------------------------

local autosave = {}

local SAVE_PATH = "data/builder_project.json"
local DEBOUNCE_SECONDS = 5

local wu = nil
local lastDirtyTime = nil

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

--- Store WindowUtils reference for notifications
---@param wuRef table WindowUtils instance
function autosave.init(wuRef)
    wu = wuRef
end

--------------------------------------------------------------------------------
-- Load
--------------------------------------------------------------------------------

--- Load project from autosave JSON file
---@param project table Project module
function autosave.load(project)
    local file = io.open(SAVE_PATH, "r")
    if not file then
        print("[WindowUtilsBuilder] No autosave file found, starting empty project")
        return
    end

    local content = file:read("*a")
    file:close()

    if not content or content == "" then
        print("[WindowUtilsBuilder] Autosave file is empty, starting empty project")
        if wu and wu.Notify then
            wu.Notify.error("Autosave file is empty, starting fresh")
        end
        return
    end

    local data = json.decode(content)
    if not data then
        print("[WindowUtilsBuilder] Failed to decode autosave JSON, starting empty project")
        if wu and wu.Notify then
            wu.Notify.error("Failed to load autosave: corrupted JSON")
        end
        return
    end

    project.deserialize(data)
    print("[WindowUtilsBuilder] Project loaded from autosave")
end

--------------------------------------------------------------------------------
-- Tick (called each frame)
--------------------------------------------------------------------------------

--- Check dirty flag and write if debounce period has elapsed
---@param project table Project module
function autosave.tick(project)
    if not project.isDirty() then
        lastDirtyTime = nil
        return
    end

    local now = os.clock()

    if not lastDirtyTime then
        lastDirtyTime = now
        return
    end

    if (now - lastDirtyTime) < DEBOUNCE_SECONDS then
        return
    end

    -- Time to save
    local data = project.serialize()
    local encoded = json.encode(data)

    local file = io.open(SAVE_PATH, "w")
    if not file then
        print("[WindowUtilsBuilder] Failed to open autosave file for writing")
        if wu and wu.Notify then
            wu.Notify.error("Failed to save project")
        end
        return
    end

    file:write(encoded)
    file:close()

    project.clearDirty()
    lastDirtyTime = nil

    if wu and wu.Notify then
        wu.Notify.success("Project saved")
    end
end

return autosave
