--------------------------------------------------------------------------------
--  _    _ _           _               _   _ _   _ _
-- | |  | (_)         | |             | | | | | (_) |
-- | |  | |_ _ __   __| | _____      _| | | | |_ _| |___
-- | |/\| | | '_ \ / _` |/ _ \ \ /\ / / | | | __| | / __|
-- \  /\  / | | | | (_| | (_) \ V  V /| |_| | |_| | \__ \
--  \/  \/|_|_| |_|\__,_|\___/ \_/\_/  \___/ \__|_|_|___/
--------------------------------------------------------------------------------
-- A universal library for ImGui window management in CET mods.
-- Provides grid snapping, smooth animations, and collapse-safe sizing.
--
-- Copyright (c) 2026 CyanideX
-- https://next.nexusmods.com/profile/theCyanideX/mods
--------------------------------------------------------------------------------

local settings = require("modules/settings")
local utils = require("modules/utils")
local core = require("modules/core")
local ui = require("modules/ui")
local effects = require("modules/effects")
local api = require("modules/api")
local styles = require("modules/styles")
local controls = require("modules/controls")
local tooltips = require("modules/tooltips")
local splitter = require("modules/splitter")
local expand = require("modules/expand")
local tabs = require("modules/tabs")
local dragdrop = require("modules/dragdrop")
local notifications = require("modules/notifications")

---@class WindowUtils
---@field runtimeData {cetOpen: boolean}
local WindowUtils = {
    NAME = settings.NAME,
    ICON = settings.ICON,
    VERSION = settings.VERSION,
    runtimeData = {
        cetOpen = false
    }
}

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
WindowUtils.GridAlignMin = core.gridAlignMin
WindowUtils.GridAlignMax = core.gridAlignMax
WindowUtils.SetNextWindowSizeConstraints = core.setNextWindowSizeConstraints
WindowUtils.SetNextWindowSizeConstraintsPercent = core.setNextWindowSizeConstraintsPercent
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
WindowUtils.IsConstraintAnimatingForWindow = core.isConstraintAnimatingForWindow
WindowUtils.ApplyEasingByName = core.applyEasingByName

-- UI controls
WindowUtils.ShowSettingsWindow = ui.show
WindowUtils.HideSettingsWindow = ui.hide
WindowUtils.ToggleSettingsWindow = ui.toggle
WindowUtils.IsSettingsWindowVisible = ui.isVisible

function WindowUtils.IsMasterEnabled()
    return settings.master.enabled
end

function WindowUtils.GetMasterSettings()
    return settings.master
end

WindowUtils.API = api

WindowUtils.Styles = styles
WindowUtils.Controls = controls
WindowUtils.Tooltips = tooltips
WindowUtils.Utils = utils

WindowUtils.Splitter = splitter
WindowUtils.Expand = expand
WindowUtils.Tabs = tabs
WindowUtils.DragDrop = dragdrop
WindowUtils.Notify = notifications

-- Register hotkey for toggling the main window (can also be toggled via API)
registerHotkey("ToggleWindowUtilsGUI", "Toggle Window Utils GUI", function()
    ui.toggle()
end)

registerForEvent("onInit", function()
    settings.load()
    core.loadWindowCache()
    ui.init()

    settings.debugPrint("Initialized!", true)
end)

registerForEvent("onDraw", function()
    -- Cache style values for controls (GetStyle() once per frame)
    controls.cacheFrameState()

    -- Apply themed scrollbar defaults for all WU-rendered content
    styles.PushScrollbar()

    -- Update blur animation (runs even when overlay might be closing)
    effects.updateBlurAnimation()

    if WindowUtils.runtimeData.cetOpen then
        -- Update blur based on drag state (for "blur on drag only" mode)
        effects.updateBlurDragState()

        effects.drawGridOverlay()
        ui.drawWindow()

        -- Process external windows if override is enabled
        core.updateExternalWindows()

        -- Execute deferred snap operations
        core.processDeferred()
    end

    -- Draw toast notifications LAST so they render on top of all other windows
    notifications.draw()

    styles.PopScrollbar()
end)

registerForEvent("onOverlayOpen", function()
    WindowUtils.runtimeData.cetOpen = true
    effects.state.isOverlayOpen = true
    -- Re-probe blocked external windows in case they became active while overlay was closed
    core.resetExternalProbes()
    -- Enable blur if setting is enabled (unless drag-only mode)
    if settings.master.blurOnOverlayOpen and not settings.master.blurOnDragOnly then
        effects.enableBlur()
    end
end)

registerForEvent("onOverlayClose", function()
    WindowUtils.runtimeData.cetOpen = false
    effects.state.isOverlayOpen = false
    -- Save cached external window sizes to disk
    core.saveWindowCache()
    -- Disable blur and dim when overlay closes
    effects.disableBlur()
    effects.disableDim()
end)

return WindowUtils
