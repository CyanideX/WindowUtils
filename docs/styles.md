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
| `blue` | 0.14, 0.27, 0.43, 1 | Default / inactive |
| `blueHover` | 0.26, 0.59, 0.98, 1 | Blue hover state |
| `red` | 1, 0.3, 0.3, 1 | Danger / delete |
| `redHover` | 1, 0.45, 0.45, 1 | Red hover state |
| `yellow` | 1, 0.8, 0, 0.8 | Warning |
| `orange` | 1, 0.6, 0, 1 | Update |
| `grey` | 0.3, 0.3, 0.3, 1 | Disabled |
| `greyLight` | 0.6, 0.6, 0.6, 1 | Muted text |
| `transparent` | 0, 0, 0, 0 | Invisible |
| `textBlack` | 0, 0, 0, 1 | Dark text on bright buttons |
| `textWhite` | 1, 1, 1, 1 | Light text on dark buttons |

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
| `PushButtonUpdate()` | `PopButtonUpdate()` | Orange bg, black text |
| `PushButtonDisabled()` | `PopButtonDisabled()` | Grey bg, grey text |
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
styles.PushButton({ bg = {0.2, 0, 0.5, 1}, hover = {0.3, 0.1, 0.6, 1}, text = {1,1,1,1} })
styles.PopButton({ bg = ... })  -- pass same table type to pop
```

Valid names: `"active"`, `"inactive"`, `"danger"`, `"warning"`, `"update"`, `"disabled"`, `"transparent"`.

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
