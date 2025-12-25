------------------------------------------------------
-- WindowUtils - Controls Module
-- Universal ImGui control helpers for CET mods
------------------------------------------------------

local styles = require("modules/styles")
local tooltips = require("modules/tooltips")

local controls = {}

--------------------------------------------------------------------------------
-- Grid System (Bootstrap-style columns)
--------------------------------------------------------------------------------

-- Approximate icon button width (glyph + padding)
local ICON_WIDTH = 24

--- Calculate width for a column ratio (1-12 out of 12 columns)
-- @param cols number: Number of columns (1-12)
-- @param gap number: Gap between elements in pixels (optional, default 8)
-- @param hasIcon boolean: Whether an icon precedes this control (optional, default false)
-- @return number: Width in pixels
function controls.ColWidth(cols, gap, hasIcon)
    cols = math.max(1, math.min(12, cols or 12))
    gap = gap or 8
    local availWidth = ImGui.GetContentRegionAvail()
    -- If called after icon placement, add icon width back for accurate column calculation
    if hasIcon then
        availWidth = availWidth + ICON_WIDTH + gap
    end
    local colWidth = (availWidth - (gap * 11)) / 12
    local targetWidth = (colWidth * cols) + (gap * (cols - 1))
    -- Subtract icon space if present
    if hasIcon then
        targetWidth = targetWidth - ICON_WIDTH - gap
    end
    return math.max(targetWidth, 20)  -- Minimum 20px
end

--- Get remaining width after current cursor position
-- @param offset number: Additional offset to subtract (optional)
-- @return number: Available width
function controls.RemainingWidth(offset)
    offset = offset or 0
    return ImGui.GetContentRegionAvail() - offset
end

--------------------------------------------------------------------------------
-- Icon Button (Invisible button with icon for labels)
--------------------------------------------------------------------------------

--- Create an invisible button with an icon (for use as slider/input labels)
-- @param icon string: IconGlyph to display
-- @param clickable boolean: If true, returns click state; if false, just displays
-- @return boolean: True if clicked (only meaningful if clickable=true)
function controls.IconButton(icon, clickable)
    clickable = clickable or false

    styles.PushButtonTransparent()
    local clicked = ImGui.Button(icon)
    styles.PopButtonTransparent()

    if clickable then
        return clicked
    end
    return false
end

--------------------------------------------------------------------------------
-- Styled Buttons
--------------------------------------------------------------------------------

--- Create a styled button with automatic push/pop
-- @param label string: Button label
-- @param styleName string: Style name ("active", "inactive", "danger", "warning", "update", "disabled", "transparent")
-- @param width number: Button width (optional, 0 = auto)
-- @param height number: Button height (optional)
-- @return boolean: True if clicked
function controls.Button(label, styleName, width, height)
    styleName = styleName or "inactive"
    width = width or 0
    height = height or 0

    styles.PushButton(styleName)
    local clicked = ImGui.Button(label, width, height)
    styles.PopButton(styleName)

    return clicked
end

--- Create a toggle button that switches between active/inactive styles
-- @param label string: Button label
-- @param isActive boolean: Current toggle state
-- @param width number: Button width (optional)
-- @param height number: Button height (optional)
-- @return boolean: True if clicked
function controls.ToggleButton(label, isActive, width, height)
    local styleName = isActive and "active" or "inactive"
    return controls.Button(label, styleName, width, height)
end

--- Create a full-width button (fills available width)
-- @param label string: Button label
-- @param styleName string: Style name (optional, default "inactive")
-- @return boolean: True if clicked
function controls.FullWidthButton(label, styleName)
    return controls.Button(label, styleName, ImGui.GetContentRegionAvail())
end

--- Create a disabled button that cannot be clicked
-- @param label string: Button label
-- @param width number: Button width (optional)
-- @param height number: Button height (optional)
function controls.DisabledButton(label, width, height)
    width = width or 0
    height = height or 0

    styles.PushButtonDisabled()
    ImGui.Button(label, width, height)
    styles.PopButtonDisabled()
end

--------------------------------------------------------------------------------
-- Sliders with Icon (Shift-style: icon on left, slider fills remaining width)
--------------------------------------------------------------------------------

--- Create a float slider with icon on left, fills remaining width
-- Pattern: [Icon] [=====Slider=====]
-- @param icon string: IconGlyph to display on left
-- @param id string: Unique ID for the slider (used with ## prefix)
-- @param value number: Current value
-- @param min number: Minimum value
-- @param max number: Maximum value
-- @param format string: Display format (optional, default "%.2f")
-- @param cols number: Grid columns 1-12 (optional, nil = fill remaining width)
-- @param defaultValue number: Default value for right-click reset (optional)
-- @param tooltip string: Tooltip text shown on icon hover (optional, always shows)
-- @return number, boolean: New value and whether changed
function controls.SliderFloat(icon, id, value, min, max, format, cols, defaultValue, tooltip)
    format = format or "%.2f"

    -- Icon button (non-clickable label)
    controls.IconButton(icon, false)

    -- Icon tooltips always show (serve as labels)
    if tooltip then
        tooltips.ShowAlways(tooltip)
    end

    ImGui.SameLine()

    -- Calculate width: either column-based or fill remaining
    local width
    if cols then
        width = controls.ColWidth(cols, nil, true)  -- hasIcon = true
    else
        width = ImGui.GetContentRegionAvail()
    end

    ImGui.SetNextItemWidth(width)
    styles.PushOutlined()
    local newValue, changed = ImGui.SliderFloat("##" .. id, value, min, max, format)
    styles.PopOutlined()

    -- Right-click to reset to default
    if defaultValue ~= nil and ImGui.IsItemClicked(1) then
        newValue = defaultValue
        changed = true
    end

    return newValue, changed
end

--- Create an integer slider with icon on left
-- @param icon string: IconGlyph to display on left
-- @param id string: Unique ID for the slider
-- @param value number: Current value
-- @param min number: Minimum value
-- @param max number: Maximum value
-- @param format string: Display format (optional, default "%d")
-- @param cols number: Grid columns 1-12 (optional)
-- @param defaultValue number: Default value for right-click reset (optional)
-- @param tooltip string: Tooltip text shown on icon hover (optional, always shows)
-- @return number, boolean: New value and whether changed
function controls.SliderInt(icon, id, value, min, max, format, cols, defaultValue, tooltip)
    format = format or "%d"

    controls.IconButton(icon, false)

    -- Icon tooltips always show (serve as labels)
    if tooltip then
        tooltips.ShowAlways(tooltip)
    end

    ImGui.SameLine()

    local width
    if cols then
        width = controls.ColWidth(cols, nil, true)  -- hasIcon = true
    else
        width = ImGui.GetContentRegionAvail()
    end

    ImGui.SetNextItemWidth(width)
    styles.PushOutlined()
    local newValue, changed = ImGui.SliderInt("##" .. id, value, min, max, format)
    styles.PopOutlined()

    -- Right-click to reset to default
    if defaultValue ~= nil and ImGui.IsItemClicked(1) then
        newValue = defaultValue
        changed = true
    end

    return newValue, changed
end

--- Create a disabled slider appearance (greyed out)
-- @param icon string: IconGlyph (optional)
-- @param label string: Display label/placeholder
function controls.SliderDisabled(icon, label)
    if icon then
        controls.IconButton(icon, false)
        ImGui.SameLine()
    end

    ImGui.SetNextItemWidth(ImGui.GetContentRegionAvail())
    styles.PushSliderDisabled()
    ImGui.BeginDisabled(true)
    ImGui.SliderFloat(label, 0, 0, 0, "%.2f", 0)
    ImGui.EndDisabled()
    styles.PopSliderDisabled()
end

--------------------------------------------------------------------------------
-- Checkboxes (standard ImGui styling - no custom colors)
--------------------------------------------------------------------------------

--- Create a standard checkbox with optional tooltip
-- @param label string: Checkbox label
-- @param value boolean: Current value
-- @param defaultValue boolean: Default value for right-click reset (optional)
-- @param tooltip string: Tooltip text (optional, shows on checkbox hover)
-- @param alwaysShowTooltip boolean: Always show tooltip (optional, default false)
-- @return boolean, boolean: New value and whether changed
function controls.Checkbox(label, value, defaultValue, tooltip, alwaysShowTooltip)
    if alwaysShowTooltip == nil then alwaysShowTooltip = false end

    local newValue, changed = ImGui.Checkbox(label, value)

    if tooltip then
        if alwaysShowTooltip then
            tooltips.ShowAlways(tooltip)
        else
            tooltips.Show(tooltip)
        end
    end

    -- Right-click to reset to default
    if defaultValue ~= nil and ImGui.IsItemClicked(1) then
        newValue = defaultValue
        changed = true
    end

    return newValue, changed
end

--- Create a checkbox with icon prefix
-- @param icon string: IconGlyph to display before checkbox
-- @param label string: Checkbox label
-- @param value boolean: Current value
-- @param defaultValue boolean: Default value for right-click reset (optional)
-- @param tooltip string: Tooltip text (optional, shows on icon and checkbox hover)
-- @param alwaysShowTooltip boolean: Always show tooltip (optional, default false)
-- @return boolean, boolean: New value and whether changed
function controls.CheckboxWithIcon(icon, label, value, defaultValue, tooltip, alwaysShowTooltip)
    if alwaysShowTooltip == nil then alwaysShowTooltip = false end

    controls.IconButton(icon, false)

    if tooltip then
        if alwaysShowTooltip then
            tooltips.ShowAlways(tooltip)
        else
            tooltips.Show(tooltip)
        end
    end

    ImGui.SameLine()
    local newValue, changed = ImGui.Checkbox(label, value)

    -- Tooltip on checkbox too
    if tooltip then
        if alwaysShowTooltip then
            tooltips.ShowAlways(tooltip)
        else
            tooltips.Show(tooltip)
        end
    end

    -- Right-click to reset to default
    if defaultValue ~= nil and ImGui.IsItemClicked(1) then
        newValue = defaultValue
        changed = true
    end

    return newValue, changed
end

--------------------------------------------------------------------------------
-- Progress Bars
--------------------------------------------------------------------------------

--- Create a styled progress bar
-- @param fraction number: Progress value (0-1)
-- @param width number: Bar width (nil for full width)
-- @param height number: Bar height (optional)
-- @param overlay string: Overlay text (optional)
-- @param styleName string: Style ("default", "danger", "success")
function controls.ProgressBar(fraction, width, height, overlay, styleName)
    width = width or ImGui.GetContentRegionAvail()
    height = height or 0
    overlay = overlay or ""
    styleName = styleName or "default"

    if styleName == "danger" then
        styles.PushOutlinedDanger()
    elseif styleName == "success" then
        styles.PushOutlinedSuccess()
    else
        styles.PushOutlined()
    end

    ImGui.ProgressBar(fraction, width, height, overlay)

    if styleName == "danger" then
        styles.PopOutlinedDanger()
    elseif styleName == "success" then
        styles.PopOutlinedSuccess()
    else
        styles.PopOutlined()
    end
end

--------------------------------------------------------------------------------
-- Color Picker
--------------------------------------------------------------------------------

--- Create a color picker with icon on left
-- @param icon string: IconGlyph to display on left (optional, pass nil for no icon)
-- @param id string: Unique ID for the color picker
-- @param color table: Current color as {r, g, b, a} (values 0-1)
-- @param label string: Label text (optional)
-- @param defaultColor table: Default color for right-click reset (optional)
-- @param tooltip string: Tooltip text (optional, always shows on icon)
-- @return table, boolean: New color and whether changed
function controls.ColorEdit4(icon, id, color, label, defaultColor, tooltip)
    local hasIcon = icon ~= nil

    if hasIcon then
        controls.IconButton(icon, false)

        if tooltip then
            tooltips.ShowAlways(tooltip)
        end

        ImGui.SameLine()
    end

    ImGui.SetNextItemWidth(ImGui.GetContentRegionAvail())
    local newColor, changed = ImGui.ColorEdit4(label or ("##" .. id), color, ImGuiColorEditFlags.NoOptions)

    -- Right-click to reset to default
    if defaultColor and ImGui.IsItemClicked(1) then
        newColor = {defaultColor[1], defaultColor[2], defaultColor[3], defaultColor[4]}
        changed = true
    end

    return newColor, changed
end

--------------------------------------------------------------------------------
-- Text Display
--------------------------------------------------------------------------------

--- Display muted/grey text
function controls.TextMuted(text)
    styles.PushTextMuted()
    ImGui.Text(text)
    styles.PopTextMuted()
end

--- Display success/green text
function controls.TextSuccess(text)
    styles.PushTextSuccess()
    ImGui.Text(text)
    styles.PopTextSuccess()
end

--- Display danger/red text
function controls.TextDanger(text)
    styles.PushTextDanger()
    ImGui.Text(text)
    styles.PopTextDanger()
end

--- Display warning/yellow text
function controls.TextWarning(text)
    styles.PushTextWarning()
    ImGui.Text(text)
    styles.PopTextWarning()
end

--------------------------------------------------------------------------------
-- Combo/Dropdown with Icon
--------------------------------------------------------------------------------

--- Create a combo dropdown with icon on left
-- @param icon string: IconGlyph to display on left (optional, pass nil for no icon)
-- @param id string: Unique ID for the combo
-- @param currentIndex number: Current selected index (0-based)
-- @param items table: Array of item strings
-- @param cols number: Grid columns 1-12 (optional)
-- @param defaultIndex number: Default index for right-click reset (optional)
-- @param tooltip string: Tooltip text shown on icon hover (optional, always shows)
-- @return number, boolean: New index and whether changed
function controls.Combo(icon, id, currentIndex, items, cols, defaultIndex, tooltip)
    local hasIcon = icon ~= nil

    if hasIcon then
        controls.IconButton(icon, false)

        -- Icon tooltips always show (serve as labels)
        if tooltip then
            tooltips.ShowAlways(tooltip)
        end

        ImGui.SameLine()
    end

    local width
    if cols then
        width = controls.ColWidth(cols, nil, hasIcon)
    else
        width = ImGui.GetContentRegionAvail()
    end

    ImGui.SetNextItemWidth(width)
    styles.PushOutlined()
    local newIndex, changed = ImGui.Combo("##" .. id, currentIndex, items, #items)
    styles.PopOutlined()

    -- Right-click to reset to default
    if defaultIndex ~= nil and ImGui.IsItemClicked(1) then
        newIndex = defaultIndex
        changed = true
    end

    return newIndex, changed
end

--------------------------------------------------------------------------------
-- Input Fields with Icon
--------------------------------------------------------------------------------

--- Create an input text field with icon on left
-- @param icon string: IconGlyph (optional, pass nil for no icon)
-- @param id string: Unique ID
-- @param text string: Current text
-- @param maxLength number: Maximum text length (optional, default 256)
-- @param cols number: Grid columns 1-12 (optional)
-- @param tooltip string: Tooltip text (optional)
-- @param alwaysShowTooltip boolean: Always show tooltip (optional, default false)
-- @return string, boolean: New text and whether changed
function controls.InputText(icon, id, text, maxLength, cols, tooltip, alwaysShowTooltip)
    maxLength = maxLength or 256
    if alwaysShowTooltip == nil then alwaysShowTooltip = false end
    local hasIcon = icon ~= nil

    if hasIcon then
        controls.IconButton(icon, false)

        if tooltip then
            if alwaysShowTooltip then
                tooltips.ShowAlways(tooltip)
            else
                tooltips.Show(tooltip)
            end
        end

        ImGui.SameLine()
    end

    local width
    if cols then
        width = controls.ColWidth(cols, nil, hasIcon)
    else
        width = ImGui.GetContentRegionAvail()
    end

    ImGui.SetNextItemWidth(width)
    styles.PushOutlined()
    local newText, changed = ImGui.InputText("##" .. id, text, maxLength)
    styles.PopOutlined()

    return newText, changed
end

--- Create an input float field with icon on left
-- @param icon string: IconGlyph (optional)
-- @param id string: Unique ID
-- @param value number: Current value
-- @param step number: Step amount (optional)
-- @param stepFast number: Fast step amount (optional)
-- @param format string: Display format (optional)
-- @param cols number: Grid columns 1-12 (optional)
-- @param tooltip string: Tooltip text (optional)
-- @param alwaysShowTooltip boolean: Always show tooltip (optional, default false)
-- @return number, boolean: New value and whether changed
function controls.InputFloat(icon, id, value, step, stepFast, format, cols, tooltip, alwaysShowTooltip)
    step = step or 0.1
    stepFast = stepFast or 1.0
    format = format or "%.2f"
    if alwaysShowTooltip == nil then alwaysShowTooltip = false end
    local hasIcon = icon ~= nil

    if hasIcon then
        controls.IconButton(icon, false)

        if tooltip then
            if alwaysShowTooltip then
                tooltips.ShowAlways(tooltip)
            else
                tooltips.Show(tooltip)
            end
        end

        ImGui.SameLine()
    end

    local width
    if cols then
        width = controls.ColWidth(cols, nil, hasIcon)
    else
        width = ImGui.GetContentRegionAvail()
    end

    ImGui.SetNextItemWidth(width)
    styles.PushOutlined()
    local newValue, changed = ImGui.InputFloat("##" .. id, value, step, stepFast, format)
    styles.PopOutlined()

    return newValue, changed
end

--- Create an input int field with icon on left
-- @param icon string: IconGlyph (optional)
-- @param id string: Unique ID
-- @param value number: Current value
-- @param step number: Step amount (optional)
-- @param stepFast number: Fast step amount (optional)
-- @param cols number: Grid columns 1-12 (optional)
-- @param tooltip string: Tooltip text (optional)
-- @param alwaysShowTooltip boolean: Always show tooltip (optional, default false)
-- @return number, boolean: New value and whether changed
function controls.InputInt(icon, id, value, step, stepFast, cols, tooltip, alwaysShowTooltip)
    step = step or 1
    stepFast = stepFast or 10
    if alwaysShowTooltip == nil then alwaysShowTooltip = false end
    local hasIcon = icon ~= nil

    if hasIcon then
        controls.IconButton(icon, false)

        if tooltip then
            if alwaysShowTooltip then
                tooltips.ShowAlways(tooltip)
            else
                tooltips.Show(tooltip)
            end
        end

        ImGui.SameLine()
    end

    local width
    if cols then
        width = controls.ColWidth(cols, nil, hasIcon)
    else
        width = ImGui.GetContentRegionAvail()
    end

    ImGui.SetNextItemWidth(width)
    styles.PushOutlined()
    local newValue, changed = ImGui.InputInt("##" .. id, value, step, stepFast)
    styles.PopOutlined()

    return newValue, changed
end

--------------------------------------------------------------------------------
-- Layout Helpers
--------------------------------------------------------------------------------

--- Create a separator with optional spacing
function controls.Separator(spacingBefore, spacingAfter)
    if spacingBefore then
        ImGui.Dummy(0, spacingBefore)
    end
    ImGui.Separator()
    if spacingAfter then
        ImGui.Dummy(0, spacingAfter)
    end
end

--- Create a labeled section header
function controls.SectionHeader(label, spacingBefore, spacingAfter)
    if spacingBefore then
        ImGui.Dummy(0, spacingBefore)
    end
    ImGui.Separator()
    ImGui.Text(label)
    if spacingAfter then
        ImGui.Dummy(0, spacingAfter)
    end
end

return controls
