------------------------------------------------------
--  _    _ _           _               _   _ _   _ _
-- | |  | (_)         | |             | | | | | (_) |
-- | |  | |_ _ __   __| | _____      _| | | | |_ _| |___
-- | |/\| | | '_ \ / _` |/ _ \ \ /\ / / | | | __| | / __|
-- \  /\  / | | | | (_| | (_) \ V  V /| |_| | |_| | \__ \
--  \/  \/|_|_| |_|\__,_|\___/ \_/\_/  \___/ \__|_|_|___/
------------------------------------------------------
-- A universal library for ImGui window management in CET mods.
-- Provides grid snapping, smooth animations, and collapse-safe sizing.
--
-- Copyright (c) 2024 CyanideX
-- https://next.nexusmods.com/profile/theCyanideX/mods
------------------------------------------------------

local settings = require("modules/settings")
local core = require("modules/core")
local ui = require("modules/ui")
local api = require("modules/api")
local styles = require("modules/styles")
local controls = require("modules/controls")
local tooltips = require("modules/tooltips")

---@class WindowUtils
---@field runtimeData {cetOpen: boolean}
local WindowUtils = {
    runtimeData = {
        cetOpen = false
    }
}

--------------------------------------------------------------------------------
-- Public API (delegates to modules)
--------------------------------------------------------------------------------

-- Configuration
WindowUtils.SetGlobalDefaults = settings.setDefaults
WindowUtils.Configure = settings.configure
WindowUtils.SetWindowConfig = settings.setWindowConfig
WindowUtils.ClearWindowConfig = settings.clearWindowConfig
WindowUtils.GetConfig = settings.getConfig

-- Core functionality
WindowUtils.Update = core.update
WindowUtils.UpdateWindow = core.updateWindow
WindowUtils.SnapToGrid = core.snapToGrid
WindowUtils.Lerp = core.lerp
WindowUtils.ApplyEasing = core.applyEasing
WindowUtils.GetEasingFunctions = core.getEasingFunctions

-- State queries
WindowUtils.IsAnimating = core.isAnimating
WindowUtils.GetExpandedSize = core.getExpandedSize
WindowUtils.CompleteAnimation = core.completeAnimation
WindowUtils.ResetWindow = core.resetWindow
WindowUtils.CleanupUnusedWindows = core.cleanupUnusedWindows
WindowUtils.InvalidateGridCache = core.invalidateGridCache

-- Constraint animations
WindowUtils.StartConstraintAnimation = core.startConstraintAnimation
WindowUtils.UpdateConstraintAnimation = core.updateConstraintAnimation
WindowUtils.IsConstraintAnimating = core.isConstraintAnimating
WindowUtils.IsAnyConstraintAnimating = core.isAnyConstraintAnimating

-- UI controls
WindowUtils.ShowSettingsWindow = ui.show
WindowUtils.HideSettingsWindow = ui.hide
WindowUtils.ToggleSettingsWindow = ui.toggle
WindowUtils.IsSettingsWindowVisible = ui.isVisible

-- Master settings access
function WindowUtils.IsMasterEnabled()
    return settings.master.enabled
end

function WindowUtils.GetMasterSettings()
    return settings.master
end

-- External Mod API
WindowUtils.API = api

-- Styles, Controls, and Tooltips modules
WindowUtils.Styles = styles
WindowUtils.Controls = controls
WindowUtils.Tooltips = tooltips

--------------------------------------------------------------------------------
-- CET Event Registration
--------------------------------------------------------------------------------

registerForEvent("onInit", function()
    settings.load()
    ui.init()  -- Initialize UI state from saved settings
    print(IconGlyphs.WindowMaximize .. " WindowUtils: Initialized!")
end)

registerForEvent("onDraw", function()
    if WindowUtils.runtimeData.cetOpen then
        ui.drawSettingsWindow()

        -- Process external windows if override is enabled
        core.updateExternalWindows()

        -- Execute deferred snap operations
        core.processDeferred()
    end
end)

registerForEvent("onOverlayOpen", function()
    WindowUtils.runtimeData.cetOpen = true
    -- Respect saved visibility state (don't force show on overlay open)
end)

registerForEvent("onOverlayClose", function()
    WindowUtils.runtimeData.cetOpen = false
end)

return WindowUtils
