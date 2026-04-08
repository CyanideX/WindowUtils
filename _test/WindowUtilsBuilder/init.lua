------------------------------------------------------
-- WindowUtils Builder
-- Visual GUI builder for composing ImGui windows
-- using the WindowUtils library
------------------------------------------------------

local project   = require("modules/project")
local autosave  = require("modules/autosave")
local library   = require("modules/library")
local canvas    = require("modules/canvas")
local inspector = require("modules/inspector")

local runtimeData = {
    cetOpen = false,
    visible = false,
    disabled = false,
    wu = nil,
}

registerHotkey("ToggleWindowUtilsBuilder", "Toggle WindowUtils Builder", function()
    runtimeData.visible = not runtimeData.visible
end)

registerForEvent("onInit", function()
    local wu = GetMod("WindowUtils")
    if not wu then
        print("[WindowUtilsBuilder] WindowUtils not found. Builder disabled.")
        runtimeData.disabled = true
        return
    end

    runtimeData.wu = wu

    project.init()
    autosave.init(wu)
    autosave.load(project)

    library.init(wu)
    canvas.init(wu)
    inspector.init(wu)
end)

registerForEvent("onDraw", function()
    if runtimeData.disabled then return end
    if not runtimeData.wu then return end

    local wu = runtimeData.wu
    wu.Controls.cacheFrameState()

    if not runtimeData.cetOpen or not runtimeData.visible then return end

    -- Ctrl+Z undo detection
    if ImGui.IsKeyDown(ImGuiKey.LeftCtrl) and ImGui.IsKeyPressed(ImGuiKey.Z) then
        local undone = project.undo()
        if not undone then
            wu.Notify.info("Nothing to undo")
        end
    end

    -- Draw Builder windows
    library.draw(project)
    canvas.draw(project)
    inspector.draw(project)

    autosave.tick(project)
end)

registerForEvent("onOverlayOpen", function()
    runtimeData.cetOpen = true
end)

registerForEvent("onOverlayClose", function()
    runtimeData.cetOpen = false
end)
