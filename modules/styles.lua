------------------------------------------------------
-- WindowUtils - Styles
-- Push/pop ImGui style pairs for CET mods
------------------------------------------------------

local styles = {}

--------------------------------------------------------------------------------
-- Default Spacing Values
--------------------------------------------------------------------------------

styles.spacing = {
    framePaddingX = 6,
    framePaddingY = 6,
    itemSpacingX = 6,
    itemSpacingY = 8
}

--------------------------------------------------------------------------------
-- Color Presets (RGBA 0-1)
--------------------------------------------------------------------------------

styles.colors = {
    -- Greens
    green       = { 0.0, 1.0, 0.7, 1.0 },
    greenHover  = { 0.0, 0.8, 0.56, 1.0 },
    greenActive = { 0.1, 0.8, 0.6, 1.0 },

    -- Blues
    blue       = { 0.14, 0.27, 0.43, 1.0 },
    blueHover  = { 0.26, 0.59, 0.98, 1.0 },
    blueActive = { 0.3, 0.3, 0.3, 1.0 },

    -- Reds
    red       = { 1.0, 0.3, 0.3, 1.0 },
    redHover  = { 1.0, 0.45, 0.45, 1.0 },
    redActive = { 1.0, 0.45, 0.45, 1.0 },

    -- Yellows
    yellow       = { 1.0, 0.8, 0.0, 0.8 },
    yellowHover  = { 1.0, 0.9, 0.2, 1.0 },
    yellowActive = { 1.0, 0.9, 0.2, 1.0 },

    -- Oranges
    orange       = { 1.0, 0.6, 0.0, 1.0 },
    orangeHover  = { 1.0, 0.7, 0.1, 1.0 },
    orangeActive = { 0.9, 0.5, 0.0, 1.0 },

    -- Greys
    grey       = { 0.3, 0.3, 0.3, 1.0 },
    greyHover  = { 0.35, 0.35, 0.35, 1.0 },
    greyActive = { 0.35, 0.35, 0.35, 1.0 },
    greyText   = { 0.5, 0.5, 0.5, 1.0 },
    greyLight  = { 0.6, 0.6, 0.6, 1.0 },
    greyDim    = { 0.7, 0.7, 0.7, 1.0 },

    -- Text
    textBlack = { 0.0, 0.0, 0.0, 1.0 },
    textWhite = { 1.0, 1.0, 1.0, 1.0 },

    -- Transparent
    transparent = { 0.0, 0.0, 0.0, 0.0 },

    -- Frame (outlined controls, borders)
    frameBg     = { 0.12, 0.26, 0.42, 0.3 },
    frameBorder = { 0.24, 0.59, 1.0, 0.35 },

    -- Outlined danger
    outlinedDangerBg     = { 0.78, 0.19, 0.19, 0.10 },
    outlinedDangerBorder = { 0.78, 0.19, 0.19, 0.47 },

    -- Outlined success
    outlinedSuccessBg     = { 0.13, 0.79, 0.60, 0.10 },
    outlinedSuccessBorder = { 0.13, 0.79, 0.59, 0.30 },

    -- Slider disabled
    sliderDisabledBg = { 0.65, 0.7, 1.0, 0.045 },

    -- Splitter
    splitterHover  = { 0.3, 0.5, 0.7, 0.5 },
    splitterDrag   = { 0.0, 1.0, 0.7, 0.6 },
    splitterIcon   = { 0.6, 0.6, 0.7, 1.0 },
    splitterIconHi = { 1.0, 1.0, 1.0, 1.0 },

    -- Scrollbar
    scrollbarBg     = { 0, 0, 0, 0 },
    scrollbarGrab   = { 0.8, 0.8, 1.0, 0.4 },
    scrollbarHover  = { 0.8, 0.8, 1.0, 0.6 },
    scrollbarActive = { 0.8, 0.8, 1.0, 0.8 },
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

---@param c table {r, g, b, a}
---@return number
function styles.ToColor(c)
    return ImGui.GetColorU32(c[1], c[2], c[3], c[4])
end

local function pushColor(col, c)
    ImGui.PushStyleColor(col, c[1], c[2], c[3], c[4])
end

--- Push standard button colors: 1 var (ButtonTextAlign) + 4 colors.
local function pushButtonColors(c)
    ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
    pushColor(ImGuiCol.Button, c.bg)
    pushColor(ImGuiCol.ButtonHovered, c.hover)
    pushColor(ImGuiCol.ButtonActive, c.active)
    pushColor(ImGuiCol.Text, c.text)
end

--- Pop standard button colors: 4 colors + 1 var.
local function popButtonColors()
    ImGui.PopStyleColor(4)
    ImGui.PopStyleVar()
end

--- Push standard button colors with border: 2 vars + 5 colors.
local function pushButtonColorsWithBorder(c)
    ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
    pushColor(ImGuiCol.Border, styles.colors.frameBorder)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 2.0)
    pushColor(ImGuiCol.Button, c.bg)
    pushColor(ImGuiCol.ButtonHovered, c.hover)
    pushColor(ImGuiCol.ButtonActive, c.active)
    pushColor(ImGuiCol.Text, c.text)
end

--- Pop standard button colors with border: 5 colors + 2 vars.
local function popButtonColorsWithBorder()
    ImGui.PopStyleColor(5)
    ImGui.PopStyleVar(2)
end

--------------------------------------------------------------------------------
-- Button Color Definitions
--------------------------------------------------------------------------------

styles.buttonDefaults = {
    active        = { bg = { 0.0, 1.0, 0.70, 0.88 },   hover = { 0.26, 1.0, 0.78, 1.0 },   active = { 0.0, 1.0, 0.70, 1.0 },    text = { 0.0, 0.11, 0.08, 1.0 } },
    inactive      = { bg = { 0.26, 0.59, 0.98, 0.43 }, hover = { 0.26, 0.59, 0.98, 1.0 },  active = { 0.06, 0.53, 0.98, 1.0 },  text = { 1.0, 1.0, 1.0, 1.0 } },
    danger        = { bg = { 1.0, 0.30, 0.30, 0.88 },  hover = { 1.0, 0.38, 0.38, 1.0 },   active = { 0.93, 0.27, 0.27, 1.0 },  text = { 0.17, 0.0, 0.0, 1.0 } },
    warning       = { bg = { 1.0, 0.76, 0.24, 0.88 },  hover = { 1.0, 0.76, 0.24, 1.0 },   active = { 0.91, 0.63, 0.23, 1.0 },  text = { 0.16, 0.07, 0.0, 1.0 } },
    update        = { bg = { 0.0, 1.0, 0.70, 0.88 },   hover = { 0.25, 1.0, 0.78, 1.0 },   active = { 0.0, 1.0, 0.70, 0.88 },   text = { 0.0, 0.11, 0.08, 1.0 } },
    disabled      = { bg = { 0.30, 0.30, 0.30, 0.71 }, hover = { 0.30, 0.30, 0.30, 0.71 }, active = { 0.30, 0.30, 0.30, 0.71 }, text = { 0.5, 0.5, 0.5, 1.0 } },
    statusbar     = { bg = { 0.65, 0.7, 1.0, 0.045 },  hover = { 0.65, 0.7, 1.0, 0.045 },  active = { 0.65, 0.7, 1.0, 0.045 },  text = { 1.0, 0.8, 0.0, 0.8 } },
    label         = { bg = { 0.12, 0.26, 0.42, 0.3 },  hover = { 0.12, 0.26, 0.42, 0.45 }, active = { 0.12, 0.26, 0.42, 0.45 }, text = { 1.0, 1.0, 1.0, 1.0 } },
    labelOutlined = { bg = { 0.12, 0.26, 0.42, 0.3 },  hover = { 0.12, 0.26, 0.42, 0.45 }, active = { 0.12, 0.26, 0.42, 0.45 }, text = { 1.0, 1.0, 1.0, 1.0 },          border = true },
}

--------------------------------------------------------------------------------
-- Named Button Styles (direct-call, no lookup overhead)
--------------------------------------------------------------------------------

local t = styles.colors.transparent

function styles.PushButtonActive()          pushButtonColors(styles.buttonDefaults.active) end
function styles.PopButtonActive()           popButtonColors() end
function styles.PushButtonInactive()        pushButtonColors(styles.buttonDefaults.inactive) end
function styles.PopButtonInactive()         popButtonColors() end
function styles.PushButtonDanger()          pushButtonColors(styles.buttonDefaults.danger) end
function styles.PopButtonDanger()           popButtonColors() end
function styles.PushButtonWarning()         pushButtonColors(styles.buttonDefaults.warning) end
function styles.PopButtonWarning()          popButtonColors() end
function styles.PushButtonUpdate()          pushButtonColors(styles.buttonDefaults.update) end
function styles.PopButtonUpdate()           popButtonColors() end
function styles.PushButtonDisabled()        pushButtonColors(styles.buttonDefaults.disabled) end
function styles.PopButtonDisabled()         popButtonColors() end
function styles.PushButtonStatusbar()       pushButtonColors(styles.buttonDefaults.statusbar) end
function styles.PopButtonStatusbar()        popButtonColors() end
function styles.PushButtonLabel()           pushButtonColors(styles.buttonDefaults.label) end
function styles.PopButtonLabel()            popButtonColors() end
function styles.PushButtonLabelOutlined()   pushButtonColorsWithBorder(styles.buttonDefaults.labelOutlined) end
function styles.PopButtonLabelOutlined()    popButtonColorsWithBorder() end

function styles.PushButtonTransparent()
    ImGui.PushStyleVar(ImGuiStyleVar.ItemInnerSpacing, 0, 0)
    ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
    pushColor(ImGuiCol.Button, t)
    pushColor(ImGuiCol.ButtonHovered, t)
    pushColor(ImGuiCol.ButtonActive, t)
end
function styles.PopButtonTransparent()
    ImGui.PopStyleColor(3)
    ImGui.PopStyleVar(2)
end

function styles.PushButtonFrameless()
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)
    pushColor(ImGuiCol.Button, t)
    pushColor(ImGuiCol.ButtonHovered, t)
    pushColor(ImGuiCol.ButtonActive, t)
end
function styles.PopButtonFrameless()
    ImGui.PopStyleColor(3)
    ImGui.PopStyleVar()
end

--------------------------------------------------------------------------------
-- Button Dispatch (for callers with runtime style names)
-- Single flat lookup: name -> {push, pop}
--------------------------------------------------------------------------------

local buttonDispatch = {
    active        = { push = styles.PushButtonActive,        pop = styles.PopButtonActive },
    inactive      = { push = styles.PushButtonInactive,      pop = styles.PopButtonInactive },
    danger        = { push = styles.PushButtonDanger,        pop = styles.PopButtonDanger },
    warning       = { push = styles.PushButtonWarning,       pop = styles.PopButtonWarning },
    update        = { push = styles.PushButtonUpdate,        pop = styles.PopButtonUpdate },
    disabled      = { push = styles.PushButtonDisabled,      pop = styles.PopButtonDisabled },
    statusbar     = { push = styles.PushButtonStatusbar,     pop = styles.PopButtonStatusbar },
    label         = { push = styles.PushButtonLabel,         pop = styles.PopButtonLabel },
    labelOutlined = { push = styles.PushButtonLabelOutlined, pop = styles.PopButtonLabelOutlined },
    transparent   = { push = styles.PushButtonTransparent,   pop = styles.PopButtonTransparent },
    frameless     = { push = styles.PushButtonFrameless,     pop = styles.PopButtonFrameless },
}

--- Push a button style by name or custom color table.
---@param nameOrTable string|table Style name or {bg, hover, active, text, border?}
function styles.PushButton(nameOrTable)
    if type(nameOrTable) == "table" then
        local c = nameOrTable
        ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
        if c.border then
            pushColor(ImGuiCol.Border, styles.colors.frameBorder)
            ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 2.0)
        end
        pushColor(ImGuiCol.Button, c.bg or styles.colors.blue)
        pushColor(ImGuiCol.ButtonHovered, c.hover or styles.colors.blueHover)
        pushColor(ImGuiCol.ButtonActive, c.active or c.hover or styles.colors.blueActive)
        pushColor(ImGuiCol.Text, c.text or styles.colors.textWhite)
        return
    end
    local entry = buttonDispatch[nameOrTable]
    if not entry then
        print("[WindowUtils] PushButton: unrecognized style '" .. tostring(nameOrTable) .. "'")
        return
    end
    entry.push()
end

--- Pop a button style. Must match the name/table passed to PushButton.
---@param nameOrTable string|table
function styles.PopButton(nameOrTable)
    if type(nameOrTable) == "table" then
        ImGui.PopStyleColor(4)
        if nameOrTable.border then
            ImGui.PopStyleVar()
            ImGui.PopStyleColor()
        end
        ImGui.PopStyleVar()
        return
    end
    local entry = buttonDispatch[nameOrTable]
    if not entry then
        print("[WindowUtils] PopButton: unrecognized style '" .. tostring(nameOrTable) .. "'")
        return
    end
    entry.pop()
end

--------------------------------------------------------------------------------
-- Outlined Elements (for sliders, drags, progress bars, inputs, combos)
--------------------------------------------------------------------------------

function styles.PushOutlined()
    pushColor(ImGuiCol.PlotHistogram, styles.colors.blueHover)
    pushColor(ImGuiCol.FrameBg, styles.colors.frameBg)
    pushColor(ImGuiCol.Border, styles.colors.frameBorder)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 2.0)
end

function styles.PopOutlined()
    ImGui.PopStyleVar(1)
    ImGui.PopStyleColor(3)
end

function styles.PushOutlinedDanger()
    pushColor(ImGuiCol.PlotHistogram, styles.colors.red)
    pushColor(ImGuiCol.FrameBg, styles.colors.outlinedDangerBg)
    pushColor(ImGuiCol.Border, styles.colors.outlinedDangerBorder)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 2.0)
end

function styles.PopOutlinedDanger()
    ImGui.PopStyleVar(1)
    ImGui.PopStyleColor(3)
end

function styles.PushOutlinedSuccess()
    pushColor(ImGuiCol.PlotHistogram, styles.colors.green)
    pushColor(ImGuiCol.FrameBg, styles.colors.outlinedSuccessBg)
    pushColor(ImGuiCol.Border, styles.colors.outlinedSuccessBorder)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 2.0)
end

function styles.PopOutlinedSuccess()
    ImGui.PopStyleVar(1)
    ImGui.PopStyleColor(3)
end

--------------------------------------------------------------------------------
-- Drag Color Theming
--------------------------------------------------------------------------------

styles.dragBgBase = { 0.12, 0.26, 0.50 }

styles.dragColors = {
    x = { 0.8, 0.3, 0.3, 1.0 },
    y = { 0.3, 0.7, 0.3, 1.0 },
    z = { 0.3, 0.5, 0.9, 1.0 },
}

---@param color table|nil {r, g, b, a}
---@return boolean pushed
function styles.PushDragColor(color)
    if not color or type(color) ~= "table" or #color ~= 4 then return false end
    local r, g, b, a = color[1], color[2], color[3], color[4]
    local bg = styles.dragBgBase
    ImGui.PushStyleColor(ImGuiCol.FrameBg,        bg[1], bg[2], bg[3], 0.1)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered,  r*0.4,  g*0.4,  b*0.4,  0.4)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive,   r*0.5,  g*0.5,  b*0.5,  0.6)
    ImGui.PushStyleColor(ImGuiCol.Border,          r,      g,      b,      a*0.6)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 2.0)
    return true
end

function styles.PopDragColor()
    ImGui.PopStyleVar(1)
    ImGui.PopStyleColor(4)
end

function styles.PushDragDisabled()
    local bg = styles.dragBgBase
    ImGui.PushStyleColor(ImGuiCol.FrameBg,        bg[1], bg[2], bg[3], 0.1)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered,  bg[1], bg[2], bg[3], 0.2)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive,   bg[1], bg[2], bg[3], 0.3)
    ImGui.PushStyleColor(ImGuiCol.Border,          bg[1]*2, bg[2]*2, bg[3]*1.76, 0.15)
    ImGui.PushStyleColor(ImGuiCol.Button,          bg[1], bg[2], bg[3], 0.1)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered,   bg[1], bg[2], bg[3], 0.2)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive,    bg[1], bg[2], bg[3], 0.3)
    pushColor(ImGuiCol.Text, styles.colors.greyDim)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 0)
end

function styles.PopDragDisabled()
    ImGui.PopStyleVar(1)
    ImGui.PopStyleColor(8)
end

--------------------------------------------------------------------------------
-- Drag Style Selection (push/pop based on disabled/dim/color state)
-- Used by renderDragRow in controls.lua
--------------------------------------------------------------------------------

--- Push drag element styling based on disabled/dim/color state.
---@param el table Element definition (needs .color, .disabled)
---@param dim boolean|string Disabled/dimmed state
---@param wasHovered boolean Whether element was hovered last frame
---@return string styleType "disabled"|"outlined"|"color"
---@return boolean trulyDisabled Whether BeginDisabled was called
function styles.PushDragStyle(el, dim, wasHovered)
    local trulyDisabled = dim == true
    if trulyDisabled then
        ImGui.BeginDisabled(true)
        styles.PushDragDisabled()
        return "disabled", true
    elseif dim then
        if wasHovered and dim == "dimmed" then
            styles.PushOutlined()
            return "outlined", false
        elseif wasHovered and dim == "dimmedColor" and el.color then
            styles.PushDragColor(el.color)
            return "color", false
        else
            styles.PushDragDisabled()
            return "disabled", false
        end
    elseif styles.PushDragColor(el.color) then
        return "color", false
    else
        styles.PushOutlined()
        return "outlined", false
    end
end

--- Pop drag element styling matching a previous PushDragStyle call.
---@param styleType string "disabled"|"outlined"|"color"
---@param trulyDisabled boolean Whether BeginDisabled was called
function styles.PopDragStyle(styleType, trulyDisabled)
    if styleType == "color" then
        styles.PopDragColor()
    elseif styleType == "disabled" then
        styles.PopDragDisabled()
        if trulyDisabled then ImGui.EndDisabled() end
    else
        styles.PopOutlined()
    end
end

--------------------------------------------------------------------------------
-- Text Styles
--------------------------------------------------------------------------------

function styles.PushTextMuted()   pushColor(ImGuiCol.Text, styles.colors.greyLight) end
function styles.PushTextSuccess() pushColor(ImGuiCol.Text, styles.colors.green) end
function styles.PushTextDanger()  pushColor(ImGuiCol.Text, styles.colors.red) end
function styles.PushTextWarning() pushColor(ImGuiCol.Text, styles.colors.yellow) end
function styles.PopTextMuted()    ImGui.PopStyleColor(1) end
function styles.PopTextSuccess()  ImGui.PopStyleColor(1) end
function styles.PopTextDanger()   ImGui.PopStyleColor(1) end
function styles.PopTextWarning()  ImGui.PopStyleColor(1) end

--------------------------------------------------------------------------------
-- Slider / Checkbox Styles
--------------------------------------------------------------------------------

function styles.PushSliderDisabled()
    pushColor(ImGuiCol.SliderGrab, styles.colors.grey)
    pushColor(ImGuiCol.SliderGrabActive, styles.colors.grey)
    pushColor(ImGuiCol.FrameBg, styles.colors.sliderDisabledBg)
end
function styles.PopSliderDisabled() ImGui.PopStyleColor(3) end

function styles.PushCheckboxActive() pushColor(ImGuiCol.CheckMark, styles.colors.green) end
function styles.PopCheckboxActive()  ImGui.PopStyleColor(1) end

--------------------------------------------------------------------------------
-- Scrollbar Styles
--------------------------------------------------------------------------------

---@param opts? table {size?, rounding?, bg?, grab?, hover?, active?}
function styles.PushScrollbar(opts)
    opts = opts or {}
    local size = opts.size or math.max(6, math.floor(ImGui.GetFontSize() * 0.4))
    ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, size)
    ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarRounding, opts.rounding or 10)
    pushColor(ImGuiCol.ScrollbarBg, opts.bg or styles.colors.scrollbarBg)
    pushColor(ImGuiCol.ScrollbarGrab, opts.grab or styles.colors.scrollbarGrab)
    pushColor(ImGuiCol.ScrollbarGrabHovered, opts.hover or styles.colors.scrollbarHover)
    pushColor(ImGuiCol.ScrollbarGrabActive, opts.active or styles.colors.scrollbarActive)
end

function styles.PopScrollbar()
    ImGui.PopStyleColor(4)
    ImGui.PopStyleVar(2)
end

--------------------------------------------------------------------------------
-- External Window Overrides
--------------------------------------------------------------------------------

---@param overrideStyling boolean
---@param disableScrollbar boolean
---@return number varCount, number colorCount
function styles.PushExternalWindow(overrideStyling, disableScrollbar)
    local vars, colors = 0, 0
    if disableScrollbar then
        ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, 0)
        vars = 1
    elseif overrideStyling then
        ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, math.max(6, math.floor(ImGui.GetFontSize() * 0.4)))
        ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarRounding, 10)
        vars = 2
        pushColor(ImGuiCol.ScrollbarBg, styles.colors.scrollbarBg)
        pushColor(ImGuiCol.ScrollbarGrab, styles.colors.scrollbarGrab)
        pushColor(ImGuiCol.ScrollbarGrabHovered, styles.colors.scrollbarHover)
        pushColor(ImGuiCol.ScrollbarGrabActive, styles.colors.scrollbarActive)
        colors = 4
    end
    return vars, colors
end

---@param varCount number
---@param colorCount number
function styles.PopExternalWindow(varCount, colorCount)
    if colorCount > 0 then ImGui.PopStyleColor(colorCount) end
    if varCount > 0 then ImGui.PopStyleVar(varCount) end
end

return styles
