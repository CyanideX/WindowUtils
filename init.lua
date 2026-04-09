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

local settings = require("core/settings")
local utils = require("modules/utils")
local core = require("core/core")
local ui = require("ui/ui")
local effects = require("core/effects")
local api = require("modules/api")
local styles = require("modules/styles")
local controls = require("modules/controls")
local tooltips = require("modules/tooltips")
local splitter = require("modules/splitter")
local expand = require("modules/expand")
local tabs = require("modules/tabs")
local dragdrop = require("modules/dragdrop")
local notifications = require("modules/notifications")
local search = require("modules/search")
local modal = require("modules/modal")
local lists = require("modules/lists")
local popout = require("modules/popout")

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
WindowUtils.SnapToGrid = core.snapToGrid
WindowUtils.GridAlignMin = core.gridAlignMin
WindowUtils.GridAlignMax = core.gridAlignMax
WindowUtils.SetNextWindowSizeConstraints = core.setNextWindowSizeConstraints
WindowUtils.SetNextWindowSizeConstraintsPercent = core.setNextWindowSizeConstraintsPercent
WindowUtils.Lerp = core.lerp
WindowUtils.ApplyEasing = core.applyEasing

-- State queries
WindowUtils.IsAnimating = core.isAnimating
WindowUtils.GetExpandedSize = core.getExpandedSize
WindowUtils.CompleteAnimation = core.completeAnimation
WindowUtils.ResetWindow = core.resetWindow
WindowUtils.InvalidateGridCache = core.invalidateGridCache

-- Constraint animations
WindowUtils.StartConstraintAnimation = core.startConstraintAnimation
WindowUtils.UpdateConstraintAnimation = core.updateConstraintAnimation
WindowUtils.IsConstraintAnimating = core.isConstraintAnimating
WindowUtils.IsAnyConstraintAnimating = core.isAnyConstraintAnimating
WindowUtils.IsConstraintAnimatingForWindow = core.isConstraintAnimatingForWindow

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
WindowUtils.Search = search
WindowUtils.Modal = modal
WindowUtils.Lists = lists
WindowUtils.Popout = popout

registerHotkey("ToggleWindowUtilsGUI", "Toggle Window Utils GUI", function()
    ui.toggle()
end)

registerForEvent("onInit", function()
    settings.load()
    settings.loadWindows()
    core.loadWindowCache()
    tooltips.setDefaultWidthPct(settings.master.tooltipMaxWidthPct)
    ui.init()
    effects.setRuntimeData(WindowUtils.runtimeData)

    settings.debugPrint("Initialized!", true)
end)

registerForEvent("onDraw", function()
    controls.cacheFrameState()

    -- Runs even when overlay is closing (fade-out needs to complete)
    effects.updateBlurAnimation()
    effects.updateDimAnimation()

    if WindowUtils.runtimeData.cetOpen then
        effects.updateBlurDragState()
        effects.drawGridOverlay()

        -- Scrollbar styles only wrap our own UI, not external windows
        styles.PushScrollbar()
        ui.drawWindow()
        styles.PopScrollbar()

        modal.draw()

        popout.drawAll()

        core.updateExternalWindows()
        core.processDeferred()
    end

    styles.PushScrollbar()
    notifications.draw()
    styles.PopScrollbar()

    settings.flushIfIdle()
end)

registerForEvent("onOverlayOpen", function()
    WindowUtils.runtimeData.cetOpen = true
    -- Re-probe external windows that may have become active while overlay was closed
    core.resetExternalProbes()
    if settings.master.blurOnOverlayOpen and not settings.master.blurOnDragOnly then
        effects.enableBlur()
    end
end)

registerForEvent("onOverlayClose", function()
    settings.flushNow()
    WindowUtils.runtimeData.cetOpen = false
    core.saveWindowCache()
    effects.disableBlur(true)
    effects.disableDim()
    ui.onOverlayClose()
end)

return WindowUtils
