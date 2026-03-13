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

--- Convert {r,g,b,a} table to ImGui u32 color
function styles.ToColor(c)
    return ImGui.GetColorU32(c[1], c[2], c[3], c[4])
end

--- Push a style color from an RGBA table
local function pushColor(col, c)
    ImGui.PushStyleColor(col, c[1], c[2], c[3], c[4])
end

--------------------------------------------------------------------------------
-- Button Styles
--------------------------------------------------------------------------------

--- Active/Success button (green with black text)
function styles.PushButtonActive()
    ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
    pushColor(ImGuiCol.Button, styles.colors.green)
    pushColor(ImGuiCol.ButtonHovered, styles.colors.greenHover)
    pushColor(ImGuiCol.ButtonActive, styles.colors.greenActive)
    pushColor(ImGuiCol.Text, styles.colors.textBlack)
end

function styles.PopButtonActive()
    ImGui.PopStyleColor(4)
    ImGui.PopStyleVar()
end

--- Inactive/Default button (blue with white text)
function styles.PushButtonInactive()
    ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
    pushColor(ImGuiCol.Button, styles.colors.blue)
    pushColor(ImGuiCol.ButtonHovered, styles.colors.blueHover)
    pushColor(ImGuiCol.ButtonActive, styles.colors.blueActive)
    pushColor(ImGuiCol.Text, styles.colors.textWhite)
end

function styles.PopButtonInactive()
    ImGui.PopStyleColor(4)
    ImGui.PopStyleVar()
end

--- Danger/Delete button (red with black text)
function styles.PushButtonDanger()
    ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
    pushColor(ImGuiCol.Button, styles.colors.red)
    pushColor(ImGuiCol.ButtonHovered, styles.colors.redHover)
    pushColor(ImGuiCol.ButtonActive, styles.colors.redActive)
    pushColor(ImGuiCol.Text, styles.colors.textBlack)
end

function styles.PopButtonDanger()
    ImGui.PopStyleColor(4)
    ImGui.PopStyleVar()
end

--- Warning button (yellow with black text)
function styles.PushButtonWarning()
    ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
    pushColor(ImGuiCol.Button, styles.colors.yellow)
    pushColor(ImGuiCol.ButtonHovered, styles.colors.yellowHover)
    pushColor(ImGuiCol.ButtonActive, styles.colors.yellowActive)
    pushColor(ImGuiCol.Text, styles.colors.textBlack)
end

function styles.PopButtonWarning()
    ImGui.PopStyleColor(4)
    ImGui.PopStyleVar()
end

--- Update button (orange with black text)
function styles.PushButtonUpdate()
    ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
    pushColor(ImGuiCol.Button, styles.colors.orange)
    pushColor(ImGuiCol.ButtonHovered, styles.colors.orangeHover)
    pushColor(ImGuiCol.ButtonActive, styles.colors.orangeActive)
    pushColor(ImGuiCol.Text, styles.colors.textBlack)
end

function styles.PopButtonUpdate()
    ImGui.PopStyleColor(4)
    ImGui.PopStyleVar()
end

--- Disabled button (grey with grey text)
function styles.PushButtonDisabled()
    ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
    pushColor(ImGuiCol.Button, styles.colors.grey)
    pushColor(ImGuiCol.ButtonHovered, styles.colors.grey)
    pushColor(ImGuiCol.ButtonActive, styles.colors.grey)
    pushColor(ImGuiCol.Text, styles.colors.greyText)
end

function styles.PopButtonDisabled()
    ImGui.PopStyleColor(4)
    ImGui.PopStyleVar()
end

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

--- Active button with standard padding
function styles.PushButtonActivePadded()
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, styles.spacing.framePaddingX, styles.spacing.framePaddingY)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, styles.spacing.itemSpacingX, styles.spacing.itemSpacingY)
    styles.PushButtonActive()
end

function styles.PopButtonActivePadded()
    styles.PopButtonActive()
    ImGui.PopStyleVar(2)
end

--- Inactive button with standard padding
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

--- Blue outlined element
function styles.PushOutlined()
    ImGui.PushStyleColor(ImGuiCol.FrameBg, 0.12, 0.26, 0.42, 0.3)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.24, 0.59, 1.0, 0.35)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 2.0)
end

function styles.PopOutlined()
    ImGui.PopStyleVar(1)
    ImGui.PopStyleColor(2)
end

--- Red outlined element (for danger/delete progress)
function styles.PushOutlinedDanger()
    pushColor(ImGuiCol.PlotHistogram, styles.colors.red)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, 0.12, 0.26, 0.42, 0.1)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.8, 0.2, 0.2, 0.3)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 2.0)
end

function styles.PopOutlinedDanger()
    ImGui.PopStyleVar(1)
    ImGui.PopStyleColor(3)
end

--- Green outlined element (for success/active progress)
function styles.PushOutlinedSuccess()
    pushColor(ImGuiCol.PlotHistogram, styles.colors.green)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, 0.0, 1.0, 0.7, 0.1)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.0, 1.0, 0.7, 0.3)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 2.0)
end

function styles.PopOutlinedSuccess()
    ImGui.PopStyleVar(1)
    ImGui.PopStyleColor(3)
end

--------------------------------------------------------------------------------
-- Text Styles
--------------------------------------------------------------------------------

--- Grey/muted text
function styles.PushTextMuted()
    pushColor(ImGuiCol.Text, styles.colors.greyLight)
end

function styles.PopTextMuted()
    ImGui.PopStyleColor(1)
end

--- Success/green text
function styles.PushTextSuccess()
    pushColor(ImGuiCol.Text, styles.colors.green)
end

function styles.PopTextSuccess()
    ImGui.PopStyleColor(1)
end

--- Danger/red text
function styles.PushTextDanger()
    pushColor(ImGuiCol.Text, styles.colors.red)
end

function styles.PopTextDanger()
    ImGui.PopStyleColor(1)
end

--- Warning/yellow text
function styles.PushTextWarning()
    pushColor(ImGuiCol.Text, styles.colors.yellow)
end

function styles.PopTextWarning()
    ImGui.PopStyleColor(1)
end

--------------------------------------------------------------------------------
-- Slider Styles
--------------------------------------------------------------------------------

--- Disabled slider appearance
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

--- Active/checked checkbox (green checkmark)
function styles.PushCheckboxActive()
    pushColor(ImGuiCol.CheckMark, styles.colors.green)
end

function styles.PopCheckboxActive()
    ImGui.PopStyleColor(1)
end

--------------------------------------------------------------------------------
-- Scrollbar Styles
--------------------------------------------------------------------------------

--- Scrollbar styling (transparent bg, themed thumb)
function styles.PushScrollbar(opts)
    opts = opts or {}
    local size = opts.size or ImGui.GetStyle().ScrollbarSize
    ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, size)
    if opts.rounding then
        ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarRounding, opts.rounding)
    end
    pushColor(ImGuiCol.ScrollbarBg, opts.bg or styles.colors.scrollbarBg)
    pushColor(ImGuiCol.ScrollbarGrab, opts.grab or styles.colors.scrollbarGrab)
    pushColor(ImGuiCol.ScrollbarGrabHovered, opts.hover or styles.colors.scrollbarHover)
    pushColor(ImGuiCol.ScrollbarGrabActive, opts.active or styles.colors.scrollbarActive)
end

function styles.PopScrollbar(opts)
    ImGui.PopStyleColor(4)
    ImGui.PopStyleVar(opts and opts.rounding and 2 or 1)
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
    transparent = { push = styles.PushButtonTransparent, pop = styles.PopButtonTransparent }
}

--- Push a button style by name or by custom color table
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

--- Pop a button style by name or table
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
