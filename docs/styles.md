# Styles — WindowUtils Color & Style Presets

Push/pop style helpers for consistent ImGui theming across CET mods.

## Quick Start

```lua
local wu = GetMod("WindowUtils")
local styles = wu.Styles

-- Green "active" button
styles.PushButtonActive()
if ImGui.Button("Save", 120, 0) then save() end
styles.PopButtonActive()

-- By name or custom table
styles.PushButton("danger")
ImGui.Button("Delete", 120, 0)
styles.PopButton("danger")
```

## Color Palette

All colors are `{r, g, b, a}` tables with values 0–1, accessible via `styles.colors.<key>`.

| Key | RGBA | Usage |
|-----|------|-------|
| `green` | 0, 1, 0.7, 1 | Active / success |
| `greenHover` | 0, 0.8, 0.56, 1 | Green hover state |
| `greenActive` | 0.1, 0.8, 0.6, 1 | Green active (pressed) state |
| `blue` | 0.14, 0.27, 0.43, 1 | Default / inactive |
| `blueHover` | 0.26, 0.59, 0.98, 1 | Blue hover state |
| `blueActive` | 0.3, 0.3, 0.3, 1 | Blue active (pressed) state |
| `red` | 1, 0.3, 0.3, 1 | Danger / delete |
| `redHover` | 1, 0.45, 0.45, 1 | Red hover state |
| `redActive` | 1, 0.45, 0.45, 1 | Red active (pressed) state |
| `yellow` | 1, 0.8, 0, 0.8 | Warning |
| `yellowHover` | 1, 0.9, 0.2, 1 | Yellow hover state |
| `yellowActive` | 1, 0.9, 0.2, 1 | Yellow active (pressed) state |
| `orange` | 1, 0.6, 0, 1 | Accent / highlight |
| `orangeHover` | 1, 0.7, 0.1, 1 | Orange hover state |
| `orangeActive` | 0.9, 0.5, 0, 1 | Orange active (pressed) state |
| `grey` | 0.3, 0.3, 0.3, 1 | Disabled |
| `greyHover` | 0.35, 0.35, 0.35, 1 | Grey hover state |
| `greyActive` | 0.35, 0.35, 0.35, 1 | Grey active (pressed) state |
| `greyText` | 0.5, 0.5, 0.5, 1 | Subdued text |
| `greyLight` | 0.6, 0.6, 0.6, 1 | Muted text |
| `textBlack` | 0, 0, 0, 1 | Dark text on bright buttons |
| `textWhite` | 1, 1, 1, 1 | Light text on dark buttons |
| `transparent` | 0, 0, 0, 0 | Invisible |
| `splitterHover` | 0.3, 0.5, 0.7, 0.5 | Splitter bar hover background |
| `splitterDrag` | 0, 1, 0.7, 0.6 | Splitter bar drag background |
| `splitterIcon` | 0.6, 0.6, 0.7, 1 | Splitter bar icon (idle) |
| `splitterIconHi` | 1, 1, 1, 1 | Splitter bar icon (active) |
| `scrollbarBg` | 0, 0, 0, 0 | Scrollbar track background |
| `scrollbarGrab` | 0.8, 0.8, 1, 0.4 | Scrollbar thumb |
| `scrollbarHover` | 0.8, 0.8, 1, 0.6 | Scrollbar thumb hover |
| `scrollbarActive` | 0.8, 0.8, 1, 0.8 | Scrollbar thumb drag |

Colors are passed as RGBA float tables directly to ImGui — no pre-computation needed.

## API Reference

### Button Styles

Each style has a matched `Push`/`Pop` pair. Push sets 4 colors + centered text alignment; Pop reverses them.

| Push | Pop | Colors |
|------|-----|--------|
| `PushButtonActive()` | `PopButtonActive()` | Green bg, black text |
| `PushButtonInactive()` | `PopButtonInactive()` | Blue bg, white text |
| `PushButtonDanger()` | `PopButtonDanger()` | Red bg, black text |
| `PushButtonWarning()` | `PopButtonWarning()` | Yellow bg, black text |
| `PushButtonUpdate()` | `PopButtonUpdate()` | Green bg, dark text |
| `PushButtonDisabled()` | `PopButtonDisabled()` | Grey bg, grey text |
| `PushButtonStatusbar()` | `PopButtonStatusbar()` | Subtle blue bg, yellow text |
| `PushButtonTransparent()` | `PopButtonTransparent()` | Transparent bg, no inner spacing |

Padded variants add `FramePadding` and `ItemSpacing` from `styles.spacing`:

| Push | Pop |
|------|-----|
| `PushButtonActivePadded()` | `PopButtonActivePadded()` |
| `PushButtonInactivePadded()` | `PopButtonInactivePadded()` |

### `PushButton(styleNameOrTable)` / `PopButton(styleNameOrTable)`

Universal button style — accepts a name string or a custom color table.

```lua
-- By name:
styles.PushButton("active")
styles.PopButton("active")

-- By custom table:
styles.PushButton({
    bg = {0.2, 0, 0.5, 1},
    hover = {0.3, 0.1, 0.6, 1},
    active = {0.15, 0, 0.4, 1},  -- pressed state (optional, falls back to hover)
    text = {1, 1, 1, 1},
})
styles.PopButton({ bg = ... })  -- pass same table type to pop
```

Valid names: `"active"`, `"inactive"`, `"danger"`, `"warning"`, `"update"`, `"disabled"`, `"statusbar"`, `"transparent"`.

### `buttonDefaults`

Pre-defined color tables for each named button style. Access via `styles.buttonDefaults.<name>` to read or override individual presets.

```lua
-- Read a preset
local danger = styles.buttonDefaults.danger
-- { bg = {1, 0.3, 0.3, 0.88}, hover = {1, 0.38, 0.38, 1}, active = {0.93, 0.27, 0.27, 1}, text = {0.17, 0, 0, 1} }

-- Override at runtime
styles.buttonDefaults.danger.text = { 1, 1, 1, 1 }
```

Available keys: `active`, `inactive`, `danger`, `warning`, `update`, `disabled`, `statusbar`.

### Outlined Styles

For sliders, progress bars, and other framed elements.

| Push | Pop | Appearance |
|------|-----|------------|
| `PushOutlined()` | `PopOutlined()` | Blue border + dark frame |
| `PushOutlinedDanger()` | `PopOutlinedDanger()` | Red border + red histogram fill |
| `PushOutlinedSuccess()` | `PopOutlinedSuccess()` | Green border + green histogram fill |

### Text Styles

| Push | Pop | Color |
|------|-----|-------|
| `PushTextMuted()` | `PopTextMuted()` | Grey (0.6) |
| `PushTextSuccess()` | `PopTextSuccess()` | Green |
| `PushTextDanger()` | `PopTextDanger()` | Red |
| `PushTextWarning()` | `PopTextWarning()` | Yellow |

### Other Styles

| Push | Pop | Purpose |
|------|-----|---------|
| `PushSliderDisabled()` | `PopSliderDisabled()` | Grey slider grab + faded frame |
| `PushCheckboxActive()` | `PopCheckboxActive()` | Green checkmark |

### Scrollbar Styles

`PushScrollbar(opts?)` / `PopScrollbar()`

Themed scrollbar with transparent track and styled thumb. Call before any scrollable region. `PopScrollbar` takes no arguments — it always pops 4 colors and 2 style vars.

```lua
-- Simple (uses defaults)
styles.PushScrollbar()
ImGui.BeginChild("scroll", 0, 200)
-- scrollable content
ImGui.EndChild()
styles.PopScrollbar()

-- Customized
styles.PushScrollbar({ size = 5, rounding = 4, grab = { 0, 1, 0.7, 0.4 } })
-- scrollable content
styles.PopScrollbar()
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| size | number | fontSize * 0.4 (min 6) | Scrollbar thickness |
| rounding | number | 10 | Thumb corner rounding |
| bg | table | scrollbarBg | Track background color |
| grab | table | scrollbarGrab | Thumb color |
| hover | table | scrollbarHover | Thumb hover color |
| active | table | scrollbarActive | Thumb drag color |

Default colors: transparent background, light blue-white thumb (0.8, 0.8, 1.0) at increasing opacity for rest/hover/active.

### `ToColor(c)`

Convert a `{r, g, b, a}` table to an ImGui U32 color value.

```lua
local u32 = styles.ToColor({1, 0, 0, 1})  -- red
```

## Spacing Defaults

```lua
styles.spacing = {
    framePaddingX = 6,
    framePaddingY = 6,
    itemSpacingX = 6,
    itemSpacingY = 8
}
```

Used by the padded button variants. Modify these before pushing padded styles to change spacing globally.
