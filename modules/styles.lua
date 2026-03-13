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
    splitterIconHi = { 1.0, 1.0, 1.0, 1.0 }
}

--------------------------------------------------------------------------------
-- Helper: Convert color table to ImGui color
--------------------------------------------------------------------------------

local function toColor(c)
    return ImGui.GetColorU32(c[1], c[2], c[3], c[4])
end

--- Public helper: Convert {r,g,b,a} table to ImGui u32 color
-- @param c table: Color as {r, g, b, a} with values 0-1
-- @return number: ImGui u32 color value
styles.toColor = toColor

--------------------------------------------------------------------------------
-- Color Caching (pre-compute u32 values once per frame for hot loops)
--------------------------------------------------------------------------------

styles.colorsU32 = {}

--- Pre-compute all styles.colors entries as ImGui u32 values.
-- Call once per frame from init.lua onDraw for hot-loop performance.
function styles.ensureCache()
    for key, c in pairs(styles.colors) do
        if type(c) == "table" and #c >= 4 then
            styles.colorsU32[key] = toColor(c)
        end
    end
end

--------------------------------------------------------------------------------
-- Button Styles
--------------------------------------------------------------------------------

--- Active/Success button (green with black text)
function styles.PushButtonActive()
    ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
    ImGui.PushStyleColor(ImGuiCol.Button, toColor(styles.colors.green))
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, toColor(styles.colors.greenHover))
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, toColor(styles.colors.greenActive))
    ImGui.PushStyleColor(ImGuiCol.Text, toColor(styles.colors.textBlack))
end

function styles.PopButtonActive()
    ImGui.PopStyleColor(4)
    ImGui.PopStyleVar()
end

--- Inactive/Default button (blue with white text)
function styles.PushButtonInactive()
    ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
    ImGui.PushStyleColor(ImGuiCol.Button, toColor(styles.colors.blue))
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, toColor(styles.colors.blueHover))
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, toColor(styles.colors.blueActive))
    ImGui.PushStyleColor(ImGuiCol.Text, toColor(styles.colors.textWhite))
end

function styles.PopButtonInactive()
    ImGui.PopStyleColor(4)
    ImGui.PopStyleVar()
end

--- Danger/Delete button (red with black text)
function styles.PushButtonDanger()
    ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
    ImGui.PushStyleColor(ImGuiCol.Button, toColor(styles.colors.red))
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, toColor(styles.colors.redHover))
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, toColor(styles.colors.redActive))
    ImGui.PushStyleColor(ImGuiCol.Text, toColor(styles.colors.textBlack))
end

function styles.PopButtonDanger()
    ImGui.PopStyleColor(4)
    ImGui.PopStyleVar()
end

--- Warning button (yellow with black text)
function styles.PushButtonWarning()
    ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
    ImGui.PushStyleColor(ImGuiCol.Button, toColor(styles.colors.yellow))
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, toColor(styles.colors.yellowHover))
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, toColor(styles.colors.yellowActive))
    ImGui.PushStyleColor(ImGuiCol.Text, toColor(styles.colors.textBlack))
end

function styles.PopButtonWarning()
    ImGui.PopStyleColor(4)
    ImGui.PopStyleVar()
end

--- Update button (orange with black text)
function styles.PushButtonUpdate()
    ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
    ImGui.PushStyleColor(ImGuiCol.Button, toColor(styles.colors.orange))
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, toColor(styles.colors.orangeHover))
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, toColor(styles.colors.orangeActive))
    ImGui.PushStyleColor(ImGuiCol.Text, toColor(styles.colors.textBlack))
end

function styles.PopButtonUpdate()
    ImGui.PopStyleColor(4)
    ImGui.PopStyleVar()
end

--- Disabled button (grey with grey text)
function styles.PushButtonDisabled()
    ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
    ImGui.PushStyleColor(ImGuiCol.Button, toColor(styles.colors.grey))
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, toColor(styles.colors.grey))
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, toColor(styles.colors.grey))
    ImGui.PushStyleColor(ImGuiCol.Text, toColor(styles.colors.greyText))
end

function styles.PopButtonDisabled()
    ImGui.PopStyleColor(4)
    ImGui.PopStyleVar()
end

--- Transparent button (invisible background)
function styles.PushButtonTransparent()
    ImGui.PushStyleVar(ImGuiStyleVar.ItemInnerSpacing, 0, 0)
    ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
    ImGui.PushStyleColor(ImGuiCol.Button, toColor(styles.colors.transparent))
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, toColor(styles.colors.transparent))
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, toColor(styles.colors.transparent))
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
    ImGui.PushStyleColor(ImGuiCol.FrameBg, ImGui.GetColorU32(0.12, 0.26, 0.42, 0.3))
    ImGui.PushStyleColor(ImGuiCol.Border, ImGui.GetColorU32(0.24, 0.59, 1.0, 0.35))
    ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 2.0)
end

function styles.PopOutlined()
    ImGui.PopStyleVar(1)
    ImGui.PopStyleColor(2)
end

--- Red outlined element (for danger/delete progress)
function styles.PushOutlinedDanger()
    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, toColor(styles.colors.red))
    ImGui.PushStyleColor(ImGuiCol.FrameBg, ImGui.GetColorU32(0.12, 0.26, 0.42, 0.1))
    ImGui.PushStyleColor(ImGuiCol.Border, ImGui.GetColorU32(0.8, 0.2, 0.2, 0.3))
    ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 2.0)
end

function styles.PopOutlinedDanger()
    ImGui.PopStyleVar(1)
    ImGui.PopStyleColor(3)
end

--- Green outlined element (for success/active progress)
function styles.PushOutlinedSuccess()
    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, toColor(styles.colors.green))
    ImGui.PushStyleColor(ImGuiCol.FrameBg, ImGui.GetColorU32(0.0, 1.0, 0.7, 0.1))
    ImGui.PushStyleColor(ImGuiCol.Border, ImGui.GetColorU32(0.0, 1.0, 0.7, 0.3))
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
    ImGui.PushStyleColor(ImGuiCol.Text, toColor(styles.colors.greyLight))
end

function styles.PopTextMuted()
    ImGui.PopStyleColor(1)
end

--- Success/green text
function styles.PushTextSuccess()
    ImGui.PushStyleColor(ImGuiCol.Text, toColor(styles.colors.green))
end

function styles.PopTextSuccess()
    ImGui.PopStyleColor(1)
end

--- Danger/red text
function styles.PushTextDanger()
    ImGui.PushStyleColor(ImGuiCol.Text, toColor(styles.colors.red))
end

function styles.PopTextDanger()
    ImGui.PopStyleColor(1)
end

--- Warning/yellow text
function styles.PushTextWarning()
    ImGui.PushStyleColor(ImGuiCol.Text, toColor(styles.colors.yellow))
end

function styles.PopTextWarning()
    ImGui.PopStyleColor(1)
end

--------------------------------------------------------------------------------
-- Slider Styles
--------------------------------------------------------------------------------

--- Disabled slider appearance
function styles.PushSliderDisabled()
    ImGui.PushStyleColor(ImGuiCol.SliderGrab, toColor(styles.colors.grey))
    ImGui.PushStyleColor(ImGuiCol.SliderGrabActive, toColor(styles.colors.grey))
    ImGui.PushStyleColor(ImGuiCol.FrameBg, ImGui.GetColorU32(0.65, 0.7, 1.0, 0.045))
end

function styles.PopSliderDisabled()
    ImGui.PopStyleColor(3)
end

--------------------------------------------------------------------------------
-- Checkbox Styles
--------------------------------------------------------------------------------

--- Active/checked checkbox (green checkmark)
function styles.PushCheckboxActive()
    ImGui.PushStyleColor(ImGuiCol.CheckMark, toColor(styles.colors.green))
end

function styles.PopCheckboxActive()
    ImGui.PopStyleColor(1)
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
-- @param styleNameOrTable string|table: Style name ("active", etc.) or { bg={r,g,b,a}, hover={r,g,b,a}, text={r,g,b,a} }
function styles.PushButton(styleNameOrTable)
    if type(styleNameOrTable) == "table" then
        -- Custom color table: { bg, hover, text }
        local c = styleNameOrTable
        ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
        ImGui.PushStyleColor(ImGuiCol.Button, toColor(c.bg or styles.colors.blue))
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, toColor(c.hover or styles.colors.blueHover))
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, toColor(c.hover or styles.colors.blueActive))
        ImGui.PushStyleColor(ImGuiCol.Text, toColor(c.text or styles.colors.textWhite))
    else
        local style = styleMap[styleNameOrTable]
        if style then
            style.push()
        end
    end
end

--- Pop a button style by name or table
-- @param styleNameOrTable string|table: Must match what was pushed
function styles.PopButton(styleNameOrTable)
    if type(styleNameOrTable) == "table" then
        -- Custom table always pushes 4 colors + 1 var
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
