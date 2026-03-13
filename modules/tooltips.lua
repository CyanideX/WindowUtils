------------------------------------------------------
-- WindowUtils - Tooltips Module
-- Universal tooltip utilities for CET mods
------------------------------------------------------

local settings = require("modules/settings")

local tooltips = {}

--------------------------------------------------------------------------------
-- Basic Tooltips
--------------------------------------------------------------------------------

--- Show a simple tooltip if the previous item is hovered (always shows, ignores settings)
function tooltips.ShowAlways(text)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text(text)
        ImGui.EndTooltip()
    end
end

--- Show a simple tooltip if the previous item is hovered (respects tooltipsEnabled setting)
function tooltips.Show(text)
    if not text then return end
    if not settings.master.tooltipsEnabled then return end

    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text(text)
        ImGui.EndTooltip()
    end
end

--- Show a tooltip with wrapped text for long descriptions
function tooltips.ShowWrapped(text, maxWidth)
    maxWidth = maxWidth or 300

    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.PushTextWrapPos(maxWidth)
        ImGui.TextWrapped(text)
        ImGui.PopTextWrapPos()
        ImGui.EndTooltip()
    end
end

--------------------------------------------------------------------------------
-- Styled Tooltips
--------------------------------------------------------------------------------

--- Show a tooltip with a title and description
function tooltips.ShowTitled(title, description)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text(title)
        if description then
            ImGui.Separator()
            ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0.6, 0.6, 0.6, 1.0))
            ImGui.TextWrapped(description)
            ImGui.PopStyleColor()
        end
        ImGui.EndTooltip()
    end
end

--- Show a tooltip with custom color
function tooltips.ShowColored(text, r, g, b, a)
    a = a or 1.0

    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(r, g, b, a))
        ImGui.Text(text)
        ImGui.PopStyleColor()
        ImGui.EndTooltip()
    end
end

--- Show a muted (grey) tooltip
function tooltips.ShowMuted(text)
    tooltips.ShowColored(text, 0.6, 0.6, 0.6, 1.0)
end

--- Show a success (green) tooltip
function tooltips.ShowSuccess(text)
    tooltips.ShowColored(text, 0.0, 1.0, 0.7, 1.0)
end

--- Show a danger (red) tooltip
function tooltips.ShowDanger(text)
    tooltips.ShowColored(text, 1.0, 0.3, 0.3, 1.0)
end

--- Show a warning (yellow) tooltip
function tooltips.ShowWarning(text)
    tooltips.ShowColored(text, 1.0, 0.8, 0.0, 1.0)
end

--------------------------------------------------------------------------------
-- Conditional Tooltips
--------------------------------------------------------------------------------

--- Show a tooltip only if condition is true
function tooltips.ShowIf(text, condition)
    if condition then
        tooltips.Show(text)
    end
end

--- Show a tooltip only if tooltips are enabled in settings
function tooltips.ShowIfEnabled(text, enabled)
    if enabled then
        tooltips.Show(text)
    end
end

--------------------------------------------------------------------------------
-- Info/Help Tooltips
--------------------------------------------------------------------------------

--- Show a help tooltip with question mark styling
function tooltips.ShowHelp(text)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0.5, 0.7, 1.0, 1.0))
        ImGui.Text("[?]")
        ImGui.PopStyleColor()
        ImGui.SameLine()
        ImGui.PushTextWrapPos(300)
        ImGui.TextWrapped(text)
        ImGui.PopTextWrapPos()
        ImGui.EndTooltip()
    end
end

--- Show a keybind tooltip
function tooltips.ShowKeybind(action, keybind)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text(action)
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0.5, 0.5, 0.5, 1.0))
        ImGui.Text("[" .. keybind .. "]")
        ImGui.PopStyleColor()
        ImGui.EndTooltip()
    end
end

--- Show a tooltip with action hint (commonly used pattern)
function tooltips.ShowWithHint(text, hint)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text(text)
        if hint then
            ImGui.Separator()
            ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0.5, 0.5, 0.5, 1.0))
            ImGui.Text(hint)
            ImGui.PopStyleColor()
        end
        ImGui.EndTooltip()
    end
end

--------------------------------------------------------------------------------
-- Multi-line Tooltips
--------------------------------------------------------------------------------

--- Show a tooltip with multiple lines
function tooltips.ShowLines(lines)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        for _, line in ipairs(lines) do
            ImGui.Text(line)
        end
        ImGui.EndTooltip()
    end
end

--- Show a tooltip with bullet points
function tooltips.ShowBullets(title, bullets)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        if title then
            ImGui.Text(title)
            ImGui.Separator()
        end
        for _, bullet in ipairs(bullets) do
            ImGui.BulletText(bullet)
        end
        ImGui.EndTooltip()
    end
end

return tooltips
