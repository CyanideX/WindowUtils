------------------------------------------------------
-- WindowUtils - Styles Module
-- Universal ImGui styling utilities for CET mods
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
    -- Greens (active/success)
    green = { 0.0, 1.0, 0.7, 1.0 },
    greenHover = { 0.0, 0.8, 0.56, 1.0 },
    greenActive = { 0.1, 0.8, 0.6, 1.0 },

    -- Blues (inactive/default)
    blue = { 0.14, 0.27, 0.43, 1.0 },
    blueHover = { 0.26, 0.59, 0.98, 1.0 },
    blueActive = { 0.3, 0.3, 0.3, 1.0 },

    -- Reds (danger/delete)
    red = { 1.0, 0.3, 0.3, 1.0 },
    redHover = { 1.0, 0.45, 0.45, 1.0 },
    redActive = { 1.0, 0.45, 0.45, 1.0 },

    -- Yellows (warning)
    yellow = { 1.0, 0.8, 0.0, 0.8 },
    yellowHover = { 1.0, 0.9, 0.2, 1.0 },
    yellowActive = { 1.0, 0.9, 0.2, 1.0 },

    -- Oranges (update)
    orange = { 1.0, 0.6, 0.0, 1.0 },
    orangeHover = { 1.0, 0.7, 0.1, 1.0 },
    orangeActive = { 0.9, 0.5, 0.0, 1.0 },

    -- Greys (disabled)
    grey = { 0.3, 0.3, 0.3, 1.0 },
    greyHover = { 0.35, 0.35, 0.35, 1.0 },
    greyActive = { 0.35, 0.35, 0.35, 1.0 },
    greyText = { 0.5, 0.5, 0.5, 1.0 },
    greyLight = { 0.6, 0.6, 0.6, 1.0 },

    -- Text
    textBlack = { 0.0, 0.0, 0.0, 1.0 },
    textWhite = { 1.0, 1.0, 1.0, 1.0 },

    -- Transparent
    transparent = { 0.0, 0.0, 0.0, 0.0 },

    -- Splitter
    splitterHover = { 0.3, 0.5, 0.7, 0.5 },
    splitterDrag = { 0.0, 1.0, 0.7, 0.6 },
    splitterIcon = { 0.6, 0.6, 0.7, 1.0 },
    splitterIconHi = { 1.0, 1.0, 1.0, 1.0 },

    -- Scrollbar
    scrollbarBg = { 0, 0, 0, 0 },
    scrollbarGrab = { 0.8, 0.8, 1.0, 0.4 },
    scrollbarHover = { 0.8, 0.8, 1.0, 0.6 },
    scrollbarActive = { 0.8, 0.8, 1.0, 0.8 }
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

--- Convert {r,g,b,a} table to ImGui u32 color.
---@param c table {r, g, b, a} color values (0-1)
---@return number u32color
function styles.ToColor(c)
    return ImGui.GetColorU32(c[1], c[2], c[3], c[4])
end

local function pushColor(col, c)
    ImGui.PushStyleColor(col, c[1], c[2], c[3], c[4])
end

--------------------------------------------------------------------------------
-- Button Color Defaults
--------------------------------------------------------------------------------

styles.buttonDefaults = {
    active   = { bg = { 0.0, 1.0, 0.70, 0.88 },  hover = { 0.26, 1.0, 0.78, 1.0 },  active = { 0.0, 1.0, 0.70, 1.0 },  text = { 0.0, 0.11, 0.08, 1.0 } },
    inactive = { bg = { 0.26, 0.59, 0.98, 0.43 }, hover = { 0.26, 0.59, 0.98, 1.0 },  active = { 0.06, 0.53, 0.98, 1.0 }, text = { 1.0, 1.0, 1.0, 1.0 } },
    danger   = { bg = { 1.0, 0.30, 0.30, 0.88 },  hover = { 1.0, 0.38, 0.38, 1.0 },  active = { 0.93, 0.27, 0.27, 1.0 }, text = { 0.17, 0.0, 0.0, 1.0 } },
    warning  = { bg = { 1.0, 0.76, 0.24, 0.88 },  hover = { 1.0, 0.76, 0.24, 1.0 },  active = { 0.91, 0.63, 0.23, 1.0 }, text = { 0.16, 0.07, 0.0, 1.0 } },
    update   = { bg = { 0.0, 1.0, 0.70, 0.88 },   hover = { 0.25, 1.0, 0.78, 1.0 },  active = { 0.0, 1.0, 0.70, 0.88 },  text = { 0.0, 0.11, 0.08, 1.0 } },
    disabled  = { bg = { 0.30, 0.30, 0.30, 0.71 }, hover = { 0.30, 0.30, 0.30, 0.71 }, active = { 0.30, 0.30, 0.30, 0.71 }, text = { 0.5, 0.5, 0.5, 1.0 } },
    statusbar = { bg = { 0.65, 0.7, 1.0, 0.045 }, hover = { 0.65, 0.7, 1.0, 0.045 }, active = { 0.65, 0.7, 1.0, 0.045 }, text = { 1.0, 0.8, 0.0, 0.8 } },
}

--------------------------------------------------------------------------------
-- Button Styles (delegate to PushButton/PopButton with defaults)
--------------------------------------------------------------------------------

local function pushBtnDef(name)
    return function() styles.PushButton(styles.buttonDefaults[name]) end
end
-- Pop: 4 colors + 1 var (ButtonTextAlign)
local function popBtnDef()
    return function() ImGui.PopStyleColor(4); ImGui.PopStyleVar() end
end

styles.PushButtonActive   = pushBtnDef("active")
styles.PopButtonActive    = popBtnDef()
styles.PushButtonInactive = pushBtnDef("inactive")
styles.PopButtonInactive  = popBtnDef()
styles.PushButtonDanger   = pushBtnDef("danger")
styles.PopButtonDanger    = popBtnDef()
styles.PushButtonWarning  = pushBtnDef("warning")
styles.PopButtonWarning   = popBtnDef()
styles.PushButtonUpdate   = pushBtnDef("update")
styles.PopButtonUpdate    = popBtnDef()
styles.PushButtonDisabled  = pushBtnDef("disabled")
styles.PopButtonDisabled   = popBtnDef()
styles.PushButtonStatusbar = pushBtnDef("statusbar")
styles.PopButtonStatusbar  = popBtnDef()

--- Transparent button (invisible background)
function styles.PushButtonTransparent()
    ImGui.PushStyleVar(ImGuiStyleVar.ItemInnerSpacing, 0, 0)
    ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
    pushColor(ImGuiCol.Button, styles.colors.transparent)
    pushColor(ImGuiCol.ButtonHovered, styles.colors.transparent)
    pushColor(ImGuiCol.ButtonActive, styles.colors.transparent)
end

function styles.PopButtonTransparent()
    ImGui.PopStyleColor(3)
    ImGui.PopStyleVar(2)
end

--------------------------------------------------------------------------------
-- Button with Padding (includes frame and item spacing)
--------------------------------------------------------------------------------

function styles.PushButtonActivePadded()
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, styles.spacing.framePaddingX, styles.spacing.framePaddingY)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, styles.spacing.itemSpacingX, styles.spacing.itemSpacingY)
    styles.PushButtonActive()
end

function styles.PopButtonActivePadded()
    styles.PopButtonActive()
    ImGui.PopStyleVar(2)
end

function styles.PushButtonInactivePadded()
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, styles.spacing.framePaddingX, styles.spacing.framePaddingY)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, styles.spacing.itemSpacingX, styles.spacing.itemSpacingY)
    styles.PushButtonInactive()
end

function styles.PopButtonInactivePadded()
    styles.PopButtonInactive()
    ImGui.PopStyleVar(2)
end

--------------------------------------------------------------------------------
-- Outlined Elements (for sliders, progress bars)
--------------------------------------------------------------------------------

function styles.PushOutlined()
    ImGui.PushStyleColor(ImGuiCol.FrameBg, 0.12, 0.26, 0.42, 0.3)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.24, 0.59, 1.0, 0.35)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 2.0)
end

function styles.PopOutlined()
    ImGui.PopStyleVar(1)
    ImGui.PopStyleColor(2)
end

function styles.PushOutlinedDanger()
    pushColor(ImGuiCol.PlotHistogram, styles.colors.red)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, 0.78, 0.19, 0.19, 0.10)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.78, 0.19, 0.19, 0.47)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 2.0)
end

function styles.PopOutlinedDanger()
    ImGui.PopStyleVar(1)
    ImGui.PopStyleColor(3)
end

function styles.PushOutlinedSuccess()
    pushColor(ImGuiCol.PlotHistogram, styles.colors.green)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, 0.13, 0.79, 0.60, 0.10)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.13, 0.79, 0.59, 0.30)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 2.0)
end

function styles.PopOutlinedSuccess()
    ImGui.PopStyleVar(1)
    ImGui.PopStyleColor(3)
end

--------------------------------------------------------------------------------
-- Text Styles
--------------------------------------------------------------------------------

function styles.PushTextMuted()
    pushColor(ImGuiCol.Text, styles.colors.greyLight)
end

function styles.PopTextMuted()
    ImGui.PopStyleColor(1)
end

function styles.PushTextSuccess()
    pushColor(ImGuiCol.Text, styles.colors.green)
end

function styles.PopTextSuccess()
    ImGui.PopStyleColor(1)
end

function styles.PushTextDanger()
    pushColor(ImGuiCol.Text, styles.colors.red)
end

function styles.PopTextDanger()
    ImGui.PopStyleColor(1)
end

function styles.PushTextWarning()
    pushColor(ImGuiCol.Text, styles.colors.yellow)
end

function styles.PopTextWarning()
    ImGui.PopStyleColor(1)
end

--------------------------------------------------------------------------------
-- Slider Styles
--------------------------------------------------------------------------------

function styles.PushSliderDisabled()
    pushColor(ImGuiCol.SliderGrab, styles.colors.grey)
    pushColor(ImGuiCol.SliderGrabActive, styles.colors.grey)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, 0.65, 0.7, 1.0, 0.045)
end

function styles.PopSliderDisabled()
    ImGui.PopStyleColor(3)
end

--------------------------------------------------------------------------------
-- Checkbox Styles
--------------------------------------------------------------------------------

function styles.PushCheckboxActive()
    pushColor(ImGuiCol.CheckMark, styles.colors.green)
end

function styles.PopCheckboxActive()
    ImGui.PopStyleColor(1)
end

--------------------------------------------------------------------------------
-- Scrollbar Styles
--------------------------------------------------------------------------------

--- Scrollbar styling (transparent bg, themed thumb).
---@param opts? table {size?: number, rounding?: number, bg?: table, grab?: table, hover?: table, active?: table}
function styles.PushScrollbar(opts)
    opts = opts or {}
    local size = opts.size or math.max(6, math.floor(ImGui.GetFontSize() * 0.4))
    local rounding = opts.rounding or 10
    ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, size)
    ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarRounding, rounding)
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
-- External Window Style Overrides
--------------------------------------------------------------------------------

--- Push style overrides for external windows based on settings.
--- Returns the number of style vars and colors pushed (for PopExternalWindow).
---@param overrideStyling boolean Apply WU scrollbar/color styling
---@param disableScrollbar boolean Set scrollbar size to 0
---@return number varCount, number colorCount
function styles.PushExternalWindow(overrideStyling, disableScrollbar)
    local vars = 0
    local colors = 0

    if disableScrollbar then
        ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, 0)
        vars = vars + 1
    elseif overrideStyling then
        local size = math.max(6, math.floor(ImGui.GetFontSize() * 0.4))
        ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, size)
        ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarRounding, 10)
        vars = vars + 2
        pushColor(ImGuiCol.ScrollbarBg, styles.colors.scrollbarBg)
        pushColor(ImGuiCol.ScrollbarGrab, styles.colors.scrollbarGrab)
        pushColor(ImGuiCol.ScrollbarGrabHovered, styles.colors.scrollbarHover)
        pushColor(ImGuiCol.ScrollbarGrabActive, styles.colors.scrollbarActive)
        colors = colors + 4
    end

    return vars, colors
end

--- Pop style overrides pushed by PushExternalWindow.
---@param varCount number
---@param colorCount number
function styles.PopExternalWindow(varCount, colorCount)
    if colorCount > 0 then ImGui.PopStyleColor(colorCount) end
    if varCount > 0 then ImGui.PopStyleVar(varCount) end
end

--------------------------------------------------------------------------------
-- Utility: Apply style by name
--------------------------------------------------------------------------------

local styleMap = {
    active = { push = styles.PushButtonActive, pop = styles.PopButtonActive },
    inactive = { push = styles.PushButtonInactive, pop = styles.PopButtonInactive },
    danger = { push = styles.PushButtonDanger, pop = styles.PopButtonDanger },
    warning = { push = styles.PushButtonWarning, pop = styles.PopButtonWarning },
    update = { push = styles.PushButtonUpdate, pop = styles.PopButtonUpdate },
    disabled = { push = styles.PushButtonDisabled, pop = styles.PopButtonDisabled },
    statusbar = { push = styles.PushButtonStatusbar, pop = styles.PopButtonStatusbar },
    transparent = { push = styles.PushButtonTransparent, pop = styles.PopButtonTransparent }
}

--- Push a button style by name or by custom color table.
---@param styleNameOrTable string|table Style name ("active","inactive","danger","warning","update","disabled","transparent") or {bg, hover, active, text} color table
function styles.PushButton(styleNameOrTable)
    if type(styleNameOrTable) == "table" then
        local c = styleNameOrTable
        ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
        pushColor(ImGuiCol.Button, c.bg or styles.colors.blue)
        pushColor(ImGuiCol.ButtonHovered, c.hover or styles.colors.blueHover)
        pushColor(ImGuiCol.ButtonActive, c.active or c.hover or styles.colors.blueActive)
        pushColor(ImGuiCol.Text, c.text or styles.colors.textWhite)
    else
        local style = styleMap[styleNameOrTable]
        if style then
            style.push()
        end
    end
end

--- Pop a button style by name or table.
---@param styleNameOrTable string|table Must match the value passed to PushButton
function styles.PopButton(styleNameOrTable)
    if type(styleNameOrTable) == "table" then
        ImGui.PopStyleColor(4)
        ImGui.PopStyleVar()
    else
        local style = styleMap[styleNameOrTable]
        if style then
            style.pop()
        end
    end
end

return styles
