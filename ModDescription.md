Window Utils is a universal library and settings overlay for managing ImGui windows in Cyber Engine Tweaks. It gives every CET mod window grid snapping, smooth animations, and a polished feel without requiring mod authors to write any of the plumbing themselves. For end users, it provides a settings panel to customize how all CET windows look and behave.



[img]BANNER_URL_HERE[/img] [color=#f1c232][size=5][b] Description[/b][/size][/color]

Ever opened a dozen CET mod windows and wished they'd just line up? Tired of windows overlapping, jumping around, or looking like they were placed by a caffeinated raccoon? Window Utils brings order to the chaos. It adds a snap grid, smooth animations, visual guides, and background effects to every CET mod window, all from a single settings panel. Mod authors get a drop-in library of styled controls, tooltips, and layout tools so their UIs look consistent without extra effort.

 [b][color=#f1c232][size=5]
Features[/size][/color][/b]
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
[/list]

[color=#f1c232][size=5][b]How to Use[/b][/size][/color]
[list]
[*]Install Window Utils into your CET mods folder.
[*]Open the CET overlay in-game.
[*]The Window Utils settings panel is accessible via the CET overlay or by binding the "Toggle Window Utils GUI" hotkey in CET settings.
[*]Adjust grid size, animation speed, visual effects, and per-window settings to your liking.
[*]All settings persist across sessions automatically.
[/list]

[color=#f1c232][size=5][b]For Mod Authors[/b][/size][/color]

Integrate Window Utils into your mod with a single function call:

[code]
local wu = GetMod("WindowUtils")

-- Inside your onDraw callback, after ImGui.End():
wu.Update("My Window")
[/code]

That's all you need for grid snapping and smooth animations. For styled controls, tooltips, and the full API, see the [b]WindowUtils.md[/b] documentation included with the mod.

[color=#f1c232][size=5][b]Optional Dependencies[/b][/size][/color]
[list]
[*][b]BlurUtils[/b] by CyanideX — Required for background blur effects. Window Utils works fully without it; the blur toggle will appear disabled with a note to install the library.
[*][b]Window Manager[/b] (RedCetWM plugin) — Required for the Window Browser and external window management features. Without it, these features are hidden and all other functionality works normally.
[/list]

[color=#f1c232][size=5][b]FAQ[/b][/size][/color]
[list]
[*][b]Q: Do other mods need to update to use Window Utils?[/b] A: No. With "Override All Windows" enabled and the Window Manager plugin installed, Window Utils can manage any CET mod window automatically. Mod authors can optionally integrate for tighter control.
[*][b]Q: Will this conflict with other mods?[/b] A: Window Utils doesn't modify any game files. It only affects CET ImGui window behavior. No known conflicts.
[*][b]Q: Can I disable it for specific windows?[/b] A: Yes. Use the Window Browser to exclude individual windows, or use per-window configuration overrides.
[*][b]Q: What happens if I uninstall it?[/b] A: Mods that integrated with Window Utils will simply skip the `GetMod("WindowUtils")` call and work as they did before. No permanent changes are made.
[*][b]Q: The blur toggle is greyed out?[/b] A: Install BlurUtils to enable background blur. All other features work without it.
[/list]

[color=#f1c232][size=5][b]Credits[/b][/size][/color]
[list]
[*]Created by CyanideX
[/list]
