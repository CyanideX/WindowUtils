------------------------------------------------------
-- WindowUtils - UI Definitions
-- Setting metadata for search, icons, ranges, tooltips
-- Initialized after IconGlyphs is available
------------------------------------------------------

local settings = require("modules/settings")

local uidefs = {}

local function findEasingIndex(key)
    for i, k in ipairs(settings.easingKeys) do
        if k == key then return i - 1 end
    end
    return 3
end

--- Build and return the definitions table.
--- Must be called after IconGlyphs is available (from onInit).
function uidefs.init()
    return {
        -- General: Master Override
        enabled          = { label = "Enable Master Override", category = "general.override",
                             searchTerms = "master configuration",
                             tooltip = "Override all mod settings with master configuration" },
        -- General: Settings
        tooltipsEnabled  = { label = "Show Tooltips", category = "general.settings",
                             searchTerms = "hover help",
                             tooltip = "Show Tooltips on Hover", alwaysShowTooltip = true },
        debugOutput      = { label = "Debug Output", category = "general.settings",
                             searchTerms = "console print messages",
                             tooltip = "Print Debug Messages to Console", alwaysShowTooltip = true },
        -- General: Experimental
        showExperimental = { label = "Show Experimental Settings", category = "general.experimental",
                             searchTerms = "expand panel",
                             tooltip = "Expand the Experimental panel at the bottom of the window\n\nYou can also toggle it by clicking the arrow at the bottom edge" },

        -- Grid
        gridEnabled      = { label = "Enable Grid Snapping", category = "grid",
                             searchTerms = "snap alignment",
                             tooltip = "Snap Windows to Grid When Released" },
        snapCollapsed    = { label = "Snap Collapsed", category = "grid",
                             searchTerms = "collapsed minimized",
                             tooltip = "Snap Collapsed Windows When Dragged" },
        gridUnits        = { label = "Grid Scale", category = "grid",
                             searchTerms = "size units pixel scale",
                             icon = "Grid",
                             tooltip = "Grid Scale (maps to valid grid sizes for your resolution)",
                             transform = {
                                 read = function(v)
                                     local validUnits = settings.getValidGridUnits(10)
                                     local maxScale = math.min(#validUnits, 5)
                                     for i, units in ipairs(validUnits) do
                                         if i <= maxScale and units == v then return i end
                                     end
                                     return 1
                                 end,
                                 write = function(v)
                                     local validUnits = settings.getValidGridUnits(10)
                                     return validUnits[v]
                                 end,
                             }},
        autoAdjustOnResize = { label = "Auto Adjust", category = "grid",
                               searchTerms = "resize re-snap",
                               tooltip = "Automatically re-snap all windows to the new grid when scale changes" },
        animationEnabled = { label = "Snap Animation", category = "grid",
                             searchTerms = "animate smooth",
                             tooltip = "Animate Window Snapping" },
        animationDuration = { label = "Animation Duration", category = "grid",
                              searchTerms = "timer speed",
                              icon = "TimerOutline", min = 0.05, max = 1.0, format = "%.2f s",
                              tooltip = "Animation Duration" },
        easeFunction     = { label = "Easing Function", category = "grid",
                             searchTerms = "ease curve interpolation",
                             icon = "SineWave", items = settings.easingNames,
                             tooltip = "Easing Function",
                             transform = {
                                 read  = function(v) return findEasingIndex(v) end,
                                 write = function(v) return settings.easingKeys[v + 1] end,
                             }},

        -- Visuals
        gridVisualizationEnabled = { label = "Grid Visualization", category = "visuals",
                                     searchTerms = "display lines overlay",
                                     tooltip = "Display Grid Lines on Screen" },
        gridShowOnDragOnly = { label = "On Drag Only", category = "visuals",
                               searchTerms = "grid dragging",
                               tooltip = "Only Show Grid While Dragging Windows" },
        gridGuidesEnabled = { label = "Guides", category = "visuals",
                              searchTerms = "alignment edges highlight",
                              tooltip = "Highlight Alignment Lines at Window Edges\n(Dims full grid, shows full-brightness lines at snapped edges)\nCan be combined with Feathered Grid\n\nTip: Hold Shift while dragging to lock movement to one axis" },
        gridGuidesDimming = { label = "Grid Dimming", category = "visuals",
                              searchTerms = "brightness opacity guides",
                              icon = "Brightness5", min = 0, max = 1, percent = true,
                              tooltip = "Grid Dimming (opacity of grid lines when guides active)" },
        gridFeatherEnabled = { label = "Feathered Grid", category = "visuals",
                               searchTerms = "feather fade proximity",
                               tooltip = "Show Grid Only Around Active Window" },
        gridFeatherRadius = { label = "Feather Radius", category = "visuals",
                              searchTerms = "distance fade",
                              icon = "BlurRadial", min = 200, max = 1200, format = "%.0f px",
                              tooltip = "Feather Radius (distance where grid fades to zero)" },
        gridFeatherPadding = { label = "Window Padding", category = "visuals",
                               searchTerms = "feather area spacing",
                               icon = "SelectionEllipse", min = 0, max = 120, format = "%.0f px",
                               tooltip = "Window Padding (area around window with full opacity)" },
        gridFeatherCurve = { label = "Feather Curve", category = "visuals",
                             searchTerms = "falloff gradient",
                             icon = "ChartBellCurveCumulative", min = 1.0, max = 12.0, format = "%.1f",
                             tooltip = "Feather Curve (higher = faster drop near window, gradual fade at edges)" },
        gridLineThickness = { label = "Grid Line Thickness", category = "visuals",
                              searchTerms = "width stroke",
                              icon = "FormatLineWeight", min = 0.5, max = 5.0, format = "%.1f px",
                              tooltip = "Grid Line Thickness" },
        gridLineColor    = { label = "Grid Line Color", category = "visuals",
                             searchTerms = "palette colour",
                             icon = "Palette", tooltip = "Grid Line Color" },

        -- Background: Dim
        gridDimBackground = { label = "Dim Background", category = "background.dim",
                              searchTerms = "darken screen",
                              tooltip = "Darken Screen When Grid Overlay Visible" },
        gridDimBackgroundOnDragOnly = { label = "On Drag Only", category = "background.dim",
                                        searchTerms = "dragging",
                                        tooltip = "Only Dim Background While Dragging Windows" },
        gridDimBackgroundOpacity = { label = "Background Dimming Opacity", category = "background.dim",
                                     searchTerms = "darkness level",
                                     icon = "Brightness4", min = 0.1, max = 0.9, format = "%.2f",
                                     tooltip = "Background Dimming Opacity" },
        -- Background: Blur
        blurOnOverlayOpen = { label = "Blur on Overlay Open", category = "background.blur",
                              searchTerms = "game background",
                              tooltip = "Blur Game Background When CET Overlay Opens" },
        blurOnDragOnly   = { label = "On Drag Only", category = "background.blur",
                             searchTerms = "dragging",
                             tooltip = "Only Blur While Dragging Windows" },
        blurIntensity    = { label = "Blur Intensity", category = "background.blur",
                             searchTerms = "strength amount",
                             icon = "Blur", min = 0.001, max = 0.02, format = "%.4f",
                             tooltip = "Blur Intensity" },
        -- Background: Transition
        fadeInDuration   = { label = "Fade In Duration", category = "background.transition",
                             searchTerms = "speed",
                             icon = "TransitionMasked", min = 0.05, max = 1.0, format = "%.2f s",
                             tooltip = "Fade In Duration" },
        fadeOutDuration  = { label = "Fade Out Duration", category = "background.transition",
                             searchTerms = "speed",
                             icon = "TransitionMasked", min = 0.05, max = 1.0, format = "%.2f s",
                             tooltip = "Fade Out Duration" },
        quickExit        = { label = "Quick Exit", category = "background.transition",
                             searchTerms = "fast closing",
                             tooltip = "Faster dim and blur transition when closing CET overlay" },

        -- Experimental
        overrideAllWindows = { label = "Override All Windows", category = "experimental",
                               searchTerms = "manage external CET",
                               tooltip = "Apply Grid Snapping to All CET Windows" },
        overrideStyling  = { label = "Scrollbar Style", category = "experimental",
                             searchTerms = "scrollbar styling",
                             tooltip = "Apply WindowUtils scrollbar styling to all managed windows" },
        disableScrollbar = { label = "No Scrollbar", category = "experimental",
                             searchTerms = "hide scrollbar",
                             tooltip = "Hide scrollbars on all managed external windows" },
        probeInterval    = { label = "Re-Probe Interval", category = "experimental",
                             searchTerms = "scan discover",
                             icon = "TimerSand", min = 0.1, max = 5.0, format = "%.1f s",
                             tooltip = "How often to scan for newly-drawn windows" },
        autoRemoveEmptyWindows = { label = "Auto-Remove Empty Windows", category = "experimental",
                                   searchTerms = "cleanup empty shells",
                                   tooltip = "Automatically stop managing windows that are no longer drawn by any mod." },
        batchAutoRemove  = { label = "Batch Auto-Remove", category = "experimental",
                             searchTerms = "simultaneous round-robin",
                             tooltip = "Check all windows simultaneously each interval" },
        autoRemoveInterval = { label = "Auto-Remove Interval", category = "experimental",
                               searchTerms = "cleanup frequency",
                               icon = "TimerSand", min = 0.1, max = 5.0, format = "%.1f s",
                               tooltip = "How often to check for empty window shells" },
        windowBrowserOpen = { label = "Window Browser", category = "experimental",
                              searchTerms = "browse discover list",
                              tooltip = "Browse all discovered CET windows" },
    }
end

return uidefs
