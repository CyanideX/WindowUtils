# Styles

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

All colors are `{r, g, b, a}` tables with values 0-1, accessible via `styles.colors.<key>`.

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
| `greyDim` | 0.7, 0.7, 0.7, 1 | Dimmed text |
| `textBlack` | 0, 0, 0, 1 | Dark text on bright buttons |
| `textWhite` | 1, 1, 1, 1 | Light text on dark buttons |
| `transparent` | 0, 0, 0, 0 | Invisible |
| `frameBg` | 0.12, 0.26, 0.42, 0.3 | Outlined control background |
| `frameBorder` | 0.24, 0.59, 1, 0.35 | Outlined control border |
| `outlinedDangerBg` | 0.78, 0.19, 0.19, 0.10 | Danger outlined background |
| `outlinedDangerBorder` | 0.78, 0.19, 0.19, 0.47 | Danger outlined border |
| `outlinedSuccessBg` | 0.13, 0.79, 0.60, 0.10 | Success outlined background |
| `outlinedSuccessBorder` | 0.13, 0.79, 0.59, 0.30 | Success outlined border |
| `sliderDisabledBg` | 0.65, 0.7, 1, 0.045 | Disabled slider background |
| `splitterHover` | 0.3, 0.5, 0.7, 0.5 | Splitter bar hover background |
| `splitterDrag` | 0, 1, 0.7, 0.6 | Splitter bar drag background |
| `splitterIcon` | 0.6, 0.6, 0.7, 1 | Splitter bar icon (idle) |
| `splitterIconHi` | 1, 1, 1, 1 | Splitter bar icon (active) |
| `scrollbarBg` | 0, 0, 0, 0 | Scrollbar track background |
| `scrollbarGrab` | 0.8, 0.8, 1, 0.4 | Scrollbar thumb |
| `scrollbarHover` | 0.8, 0.8, 1, 0.6 | Scrollbar thumb hover |
| `scrollbarActive` | 0.8, 0.8, 1, 0.8 | Scrollbar thumb drag |

## API Reference

### Button Styles

Each named style has a matched `Push`/`Pop` pair. Push sets 4 colors + centered text alignment; Pop reverses them.

| Push | Pop | Colors |
|------|-----|--------|
| `PushButtonActive()` | `PopButtonActive()` | Green bg, black text |
| `PushButtonInactive()` | `PopButtonInactive()` | Blue bg, white text |
| `PushButtonDanger()` | `PopButtonDanger()` | Red bg, black text |
| `PushButtonWarning()` | `PopButtonWarning()` | Yellow bg, black text |
| `PushButtonUpdate()` | `PopButtonUpdate()` | Green bg, dark text |
| `PushButtonDisabled()` | `PopButtonDisabled()` | Grey bg, grey text |
| `PushButtonStatusbar()` | `PopButtonStatusbar()` | Subtle blue bg, yellow text |
| `PushButtonLabel()` | `PopButtonLabel()` | Dark blue bg, white text |
| `PushButtonLabelOutlined()` | `PopButtonLabelOutlined()` | Dark blue bg, white text, blue border |
| `PushButtonTransparent()` | `PopButtonTransparent()` | Transparent bg, no inner spacing |
| `PushButtonFrameless()` | `PopButtonFrameless()` | Transparent bg, zero frame padding |

### `PushButton(styleNameOrTable)` / `PopButton(styleNameOrTable)`

Universal button style - accepts a name string or a custom color table.

```lua
-- By name:
styles.PushButton("active")
styles.PopButton("active")

-- By custom table:
styles.PushButton({
    bg = {0.2, 0, 0.5, 1},
    hover = {0.3, 0.1, 0.6, 1},
    active = {0.15, 0, 0.4, 1},
    text = {1, 1, 1, 1},
    border = true,  -- optional, adds blue border
})
styles.PopButton({ border = true })  -- pass same table type to pop
```

Valid names: `"active"`, `"inactive"`, `"danger"`, `"warning"`, `"update"`, `"disabled"`, `"statusbar"`, `"label"`, `"labelOutlined"`, `"transparent"`, `"frameless"`.

### `buttonDefaults`

Pre-defined color tables for each named button style. Access via `styles.buttonDefaults.<name>`.

```lua
local danger = styles.buttonDefaults.danger
-- { bg = {1, 0.3, 0.3, 0.88}, hover = {1, 0.38, 0.38, 1}, ... }
```

Available keys: `active`, `inactive`, `danger`, `warning`, `update`, `disabled`, `statusbar`, `label`, `labelOutlined`.

### Outlined Styles

For sliders, progress bars, and other framed elements.

| Push | Pop | Appearance |
|------|-----|------------|
| `PushOutlined()` | `PopOutlined()` | Blue border + dark frame |
| `PushOutlinedDanger()` | `PopOutlinedDanger()` | Red border + red histogram fill |
| `PushOutlinedSuccess()` | `PopOutlinedSuccess()` | Green border + green histogram fill |

### Drag Color Theming

#### `dragBgBase`

Base background color for drag controls: `{ 0.12, 0.26, 0.50 }`.

#### `dragColors`

Preset axis colors for `DragFloatRow`/`DragIntRow`:

```lua
styles.dragColors = {
    x = { 0.8, 0.3, 0.3, 1.0 },   -- red
    y = { 0.3, 0.7, 0.3, 1.0 },   -- green
    z = { 0.3, 0.5, 0.9, 1.0 },   -- blue
}
```

#### `PushDragColor(color)` / `PopDragColor()`

Push colored drag style with faded blue FrameBg and axis-colored hover, active, and border. Returns `false` if color is nil or invalid.

#### `PushDragDisabled()` / `PopDragDisabled()`

Faded blue disabled drag style. Pushes 8 colors + 1 var (FrameBorderSize 0).

#### `PushDragStyle(el, dim, wasHovered)` / `PopDragStyle(styleType, trulyDisabled)`

High-level drag style selection used by `DragFloatRow`/`DragIntRow`. Chooses between disabled, outlined, or colored styles based on element state.

| Parameter | Type | Description |
|-----------|------|-------------|
| el | table | Element definition (needs `.color`, `.disabled`) |
| dim | boolean\|string | `true` = fully disabled, `"dimmed"` = outlined on hover, `"dimmedColor"` = color on hover |
| wasHovered | boolean | Whether element was hovered last frame |

**Returns (Push):** `string, boolean` - styleType (`"disabled"`, `"outlined"`, `"color"`), trulyDisabled

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

Themed scrollbar with transparent track and styled thumb.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| size | number | fontSize * 0.4 (min 6) | Scrollbar thickness |
| rounding | number | 10 | Thumb corner rounding |
| bg | table | scrollbarBg | Track background color |
| grab | table | scrollbarGrab | Thumb color |
| hover | table | scrollbarHover | Thumb hover color |
| active | table | scrollbarActive | Thumb drag color |

### External Window Styles

`PushExternalWindow(overrideStyling, disableScrollbar)` / `PopExternalWindow(varCount, colorCount)`

Push/pop style overrides for externally managed windows.

**Returns (Push):** `number, number` - varCount, colorCount (pass both to Pop)

### `ToColor(c)`

Convert a `{r, g, b, a}` table to an ImGui U32 color value.

## Spacing Defaults

```lua
styles.spacing = {
    framePaddingX = 6,
    framePaddingY = 6,
    itemSpacingX = 6,
    itemSpacingY = 8
}
```
