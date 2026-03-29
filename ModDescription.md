Window Utils is a universal library and settings overlay for managing ImGui windows in Cyber Engine Tweaks. It gives every CET mod window grid snapping, smooth animations, and a polished feel without requiring mod authors to write any of the plumbing themselves. For end users, it provides a settings panel to customize how all CET windows look and behave.





[color=#f1c232][size=5][b]Description[/b][/size][/color]

Ever opened a dozen CET mod windows and wished they'd just line up? Tired of windows overlapping, jumping around, or looking like they were placed by a caffeinated raccoon? Window Utils brings order to the chaos. It adds a snap grid, smooth animations, visual guides, and background effects to every CET mod window, all from a single settings panel. Mod authors get a drop-in library of styled controls, tooltips, and layout tools so their UIs look consistent without extra effort.
[b][color=#f1c232][size=5]
Features
[/size][/color][/b]
[list]
[*][b]Grid Snapping:[/b] Windows snap to a configurable pixel grid when dragged. Grid size is adjustable and automatically validated against your display resolution for pixel-perfect alignment.
[*][b]Smooth Animations:[/b] Windows glide to their snap positions with configurable easing. Choose from Linear, Ease In, Ease Out, Ease In-Out, or Bounce. Adjust duration to taste.
[*][b]Feathered Grid Overlay:[/b] A visual grid overlay fades smoothly around your windows with configurable radius, padding, and curve. See exactly where things will snap.
[*][b]Alignment Guides:[/b] Full-brightness guide lines appear at snapped window edges while the rest of the grid dims. Hold Shift while dragging to lock movement to one axis.
[*][b]Background Dimming:[/b] Dim the game world behind the grid and windows for better contrast while arranging your layout. Configurable opacity and drag-only mode.
[*][b]Background Blur:[/b] Blur the game world when the CET overlay is open or while dragging windows. Adjustable intensity with smooth fade-in/fade-out transitions. Requires BlurUtils (optional).
[*][b]Window Browser:[/b] Browse all discovered CET windows in one place. See window status, enable/disable individual windows, and toggle close buttons. Requires Window Manager plugin (optional).
[*][b]External Window Management:[/b] Automatically apply grid snapping and animations to other mods' windows, no integration needed. Probe system detects active and empty windows with zero flicker. Batch or sequential auto-removal of stale windows.
[*][b]Collapse-Safe Sizing:[/b] Window size constraints work correctly when windows are collapsed and expanded. Constraint animations smoothly transition between size states.
[*][b]Per-Window Settings:[/b] Override grid, animation, and other settings on a per-window basis. Priority chain: Master Override > Per-Window > External Settings > Defaults.
[*][b]Right-Click Reset:[/b] Right-click any slider, checkbox, combo, or color picker to reset it to its default value.
[*][b]UI Controls Library:[/b] A complete set of styled ImGui controls for mod authors: buttons, sliders, checkboxes, combos, color pickers, inputs, text displays, progress bars, and a 12-column layout grid. All with built-in tooltip support.
[*][b]Tooltips System:[/b] Drop-in tooltip helpers with styled, colored, titled, wrapped, multi-line, and keybind variants. Respects a global enable/disable toggle across all mods.
[*][b]Styles Library:[/b] Consistent color presets and Push/Pop style functions for buttons, text, sliders, outlines, and checkboxes. Seven button style families with hover and active states.
[*][b]Splitter Layouts:[/b] Draggable panel dividers for two-panel, multi-panel, and collapsible toggle layouts. Supports horizontal and vertical splits, edge toggle panels, double-click collapse, Ctrl+drag snapping, and Shift+drag proportional scaling.
[*][b]Expand Panels:[/b] Automatic window resizing when toggle panels open or close. Three sizing modes (fixed, flex, auto) with constraint animation, drag-to-resize, and position anchoring for left/top panels.
[*][b]Tab Bars:[/b] Styled tab bars with badge indicators (numeric counts and dot markers), disabled tab support, and programmatic tab selection.
[*][b]Drag-and-Drop Lists:[/b] Reorderable lists with visual drop indicators, drag handles, and automatic array mutation. Both a convenience API and a manual advanced API.
[*][b]Toast Notifications:[/b] Screen-edge toast notifications with level-based styling (info, success, warning, error), auto-dismiss, configurable position, and smooth fade-out.
[*][b]Window Registration API:[/b] Register windows with metadata (close button support) so external window management handles them correctly without empty-shell detection issues.
[/list]

[color=#f1c232][size=5][b]How to Use
[/b][/size][/color]
[list]
[*]Install Window Utils into your CET mods folder.
[*]Open the CET overlay in-game.
[*]The Window Utils settings panel is accessible via the CET overlay or by binding the "Toggle Window Utils GUI" hotkey in CET settings.
[*]Adjust grid size, animation speed, visual effects, and per-window settings to your liking.
[*]All settings persist across sessions automatically.
[/list]

[color=#f1c232][size=5][b]For Mod Authors[/b][/size][/color]

Integrate Window Utils into your mod with a single function call:

[quote]local wu = GetMod("WindowUtils")

-- Inside your onDraw callback, after ImGui.Begin/End:
if ImGui.Begin("My Window") then
    -- your content here
    wu.Update("My Window")
end
ImGui.End()[/quote]
That's all you need for grid snapping and smooth animations.

For styled controls, use the Controls and Styles modules:

[quote]local wu = GetMod("WindowUtils")
local c = wu.Controls
local styles = wu.Styles

-- Styled button
if c.Button("Save", "active", -1) then save() end

-- Slider with icon, right-click reset
local val, changed = c.SliderFloat(IconGlyphs.Brightness, "brightness", value, 0, 100, {
    format = "%.1f", default = 50, tooltip = "Brightness"
})

-- Bound controls (auto-read, auto-save, auto-reset)
local ctx = c.bind(settings, defaults, save)
ctx:Checkbox("Enable Feature", "enabled")
ctx:SliderFloat(IconGlyphs.Timer, "duration", 0.1, 5.0)[/quote]
For splitters, tabs, drag-drop, notifications, and the full API, see the [b]WindowUtils.md[/b] documentation included with the mod.

[color=#f1c232][size=5][b]Window Manager Plugin (RedCetWM)[/b][/size][/color]

The Window Manager plugin is a RED4ext plugin that exposes window layout data to CET mods. Window Utils uses it for two features:

[list]
[*][b]Override All Windows:[/b] Automatically apply grid snapping and animations to every CET mod window without any integration from the mod author. Enable this in the Experimental section of the settings panel.
[*][b]Window Browser:[/b] Browse, search, and manage all discovered CET windows. Toggle close buttons, hide windows, or ignore them entirely.
[/list]

[b]Requirements:[/b]
[list]
[*]RED4ext must be installed (the plugin loader for Cyberpunk 2077).
[*]Place the [b]RedCetWM.dll[/b] file in your RED4ext plugins folder: [code]Cyberpunk 2077/red4ext/plugins/CET Window Manager/RedCetWM.dll[/code]
[*]Window Utils detects the plugin automatically. When present, the "Override All Windows" checkbox and Window Browser become available in the Experimental settings section.
[*]Without the plugin, all other Window Utils features (grid snapping, animations, controls library, etc.) work normally. The external window management features simply won't appear.
[/list]

[b]How it works:[/b] The plugin provides a [b]RedCetWM.GetWindowLayout()[/b] function that returns a string describing all ImGui windows (name, position, size, collapsed state). Window Utils parses this each frame to discover and manage external windows. A probe system detects which windows are actively rendered vs. empty shells, preventing flicker and ghost windows.

[color=#f1c232][size=5][b]Optional Dependencies
[/b][/size][/color]
[list]
[*][b]BlurUtils[/b] (CET mod by CyanideX): Required for background blur effects. Window Utils works fully without it; the blur toggle will appear disabled with a note to install the library.
[*][b]Window Manager[/b] (RedCetWM RED4ext plugin): Required for the Window Browser and "Override All Windows" external window management. Requires RED4ext to be installed. Without it, these features are hidden and all other functionality works normally. See the Window Manager Plugin section above for installation details.
[/list]
[color=#f1c232][size=5][b]FAQ
[/b][/size][/color]
[list]
[*][b]Q: Do other mods need to update to use Window Utils?[/b] A: No. With "Override All Windows" enabled and the Window Manager plugin installed, Window Utils can manage any CET mod window automatically. Mod authors can optionally integrate for tighter control.
[*][b]Q: Will this conflict with other mods?[/b] A: Window Utils doesn't modify any game files. It only affects CET ImGui window behavior. No known conflicts.
[*][b]Q: Can I disable it for specific windows?[/b] A: Yes. Use the Window Browser to exclude individual windows, or use per-window configuration overrides.
[*][b]Q: What happens if I uninstall it?[/b] A: Mods that integrated with Window Utils will simply skip the `GetMod("WindowUtils")` call and work as they did before. No permanent changes are made.
[*][b]Q: The blur toggle is greyed out?[/b] A: Install BlurUtils to enable background blur. All other features work without it.
[*][b]Q: My window flickers or gets detected as an empty shell?[/b] A: Use the Window Browser to toggle the Close Button setting for your window. Mod authors can also call `wu.API.RegisterWindow("My Window", { hasCloseButton = true })` to declare that a window uses pOpen, which bypasses the empty-shell probe entirely.
[/list]