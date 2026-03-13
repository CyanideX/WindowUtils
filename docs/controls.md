# Controls — WindowUtils UI Control Library

Grid-based layout system, styled buttons, sliders, inputs, hold-to-confirm buttons, and layout helpers.

## Quick Start

```lua
local wu = GetMod("WindowUtils")
local c = wu.Controls

-- 3-column layout: slider takes 8 cols, button takes 4 cols
local val, changed = c.SliderFloat(IconGlyphs.Reload, "mySlider", value, 0, 100, "%.1f", 8)
ImGui.SameLine()
if c.Button("Apply", "active", c.ColWidth(4)) then apply(val) end
```

## Grid System

Controls uses a 12-column grid (Bootstrap-style) to calculate widths relative to available space.

### `ColWidth(cols, gap?, hasIcon?)`

Calculate pixel width for a column span.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| cols | number | 12 | Columns to span (1–12) |
| gap | number | ItemSpacing.x | Gap between elements in pixels |
| hasIcon | boolean | false | Adjust for icon prefix width |

**Returns:** `number` — width in pixels (minimum 20px)

```lua
-- Half-width button
c.Button("Save", "active", c.ColWidth(6))

-- Three equal buttons on one line
for i, label in ipairs({"A", "B", "C"}) do
    if i > 1 then ImGui.SameLine() end
    c.Button(label, "inactive", c.ColWidth(4))
end
```

### `RemainingWidth(offset?)`

Returns available width minus optional offset.

## Buttons

### `Button(label, styleName?, width?, height?)`

Styled button with automatic push/pop.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| label | string | — | Button label |
| styleName | string | "inactive" | Style name (see Styles module) |
| width | number | 0 | Width (0 = auto) |
| height | number | 0 | Height |

**Returns:** `boolean` — true if clicked

### `ToggleButton(label, isActive, width?, height?)`

Switches between "active" and "inactive" styles based on state.

### `FullWidthButton(label, styleName?)`

Button that fills available width.

### `DisabledButton(label, width?, height?)`

Non-interactive greyed-out button.

### `IconButton(icon, clickable?)`

Transparent button displaying an icon glyph. Used internally as slider/input labels.

## Sliders

### `SliderFloat(icon, id, value, min, max, format?, cols?, defaultValue?, tooltip?)`

Float slider with optional icon prefix, column width, right-click reset, and tooltip.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| icon | string\|nil | — | IconGlyph (nil = no icon) |
| id | string | — | Unique slider ID |
| value | number | — | Current value |
| min | number | — | Minimum |
| max | number | — | Maximum |
| format | string | "%.2f" | Display format |
| cols | number\|nil | nil | Grid columns (nil = fill remaining) |
| defaultValue | number\|nil | nil | Right-click reset value |
| tooltip | string\|nil | nil | Always-visible icon tooltip |

**Returns:** `number, boolean` — new value, whether changed

```lua
local brightness, changed = c.SliderFloat(
    IconGlyphs.Reload, "brightness", settings.brightness,
    0.1, 10.0, "%.1f", nil, 1.0, "Brightness"
)
```

### `SliderInt(icon, id, value, min, max, format?, cols?, defaultValue?, tooltip?)`

Same as SliderFloat but for integers. Default format: `"%d"`.

### `SliderDisabled(icon?, label)`

Greyed-out non-interactive slider placeholder.

## Input Fields

### `InputText(icon, id, text, maxLength?, cols?, tooltip?, alwaysShowTooltip?)`

Text input with optional icon, column width, and tooltip.

**Returns:** `string, boolean` — new text, whether changed

### `InputFloat(icon, id, value, step?, stepFast?, format?, cols?, tooltip?, alwaysShowTooltip?)`

Float input with +/- step buttons.

**Returns:** `number, boolean` — new value, whether changed

### `InputInt(icon, id, value, step?, stepFast?, cols?, tooltip?, alwaysShowTooltip?)`

Integer input with +/- step buttons.

**Returns:** `number, boolean` — new value, whether changed

## Combo/Dropdown

### `Combo(icon, id, currentIndex, items, cols?, defaultIndex?, tooltip?)`

Dropdown with optional icon, column width, right-click reset.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| currentIndex | number | — | Selected index (0-based) |
| items | table | — | Array of item strings |
| defaultIndex | number\|nil | nil | Right-click reset index |

**Returns:** `number, boolean` — new index, whether changed

## Checkboxes

### `Checkbox(label, value, defaultValue?, tooltip?, alwaysShowTooltip?)`

Standard checkbox with optional right-click reset and tooltip.

**Returns:** `boolean, boolean` — new value, whether changed

### `CheckboxWithIcon(icon, label, value, defaultValue?, tooltip?, alwaysShowTooltip?)`

Checkbox with icon prefix. Tooltip shows on both icon and checkbox hover.

## Progress Bars

### `ProgressBar(fraction, width?, height?, overlay?, styleName?)`

Styled progress bar.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| fraction | number | — | Progress 0–1 |
| width | number\|nil | full width | Bar width |
| overlay | string | "" | Overlay text |
| styleName | string | "default" | "default", "danger", or "success" |

## Color Picker

### `ColorEdit4(icon, id, color, label?, defaultColor?, tooltip?)`

Color picker with icon prefix and right-click reset.

**Returns:** `table, boolean` — new `{r,g,b,a}` color, whether changed

## Hold-to-Confirm Button

### `HoldButton(id, label, opts?)`

Button that requires holding to trigger. Prevents accidental destructive actions.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| id | string | — | Unique button ID |
| label | string | — | Display label |
| opts.duration | number | 2.0 | Hold duration in seconds |
| opts.style | string | "danger" | Button style name |
| opts.width | number | 0 | Button width |
| opts.progressDisplay | string | "overlay" | "overlay", "replace", or "external" |
| opts.progressStyle | string | "danger" | Progress bar style (for replace/external) |

**Returns:** `boolean` — true only when hold completes

Progress display modes:
- **overlay** — white rect fills over the button as you hold
- **replace** — button is replaced by a progress bar while held
- **external** — no visual on the button itself; use `ShowHoldProgress()` elsewhere

```lua
if c.HoldButton("delete_all", "Delete All", { duration = 1.5, style = "danger" }) then
    deleteAll()
end
```

### `getHoldProgress(id)`

**Returns:** `number|nil` — progress 0–1, or nil if not holding

### `ShowHoldProgress(sourceId, width?, progressStyle?)`

Renders a progress bar showing another button's hold state. Use with `progressDisplay = "external"`.

**Returns:** `boolean` — true if progress bar is showing (caller should skip normal content)

### `ActionButton(id, label, opts?)`

Compound button: primary click + secondary hold-to-confirm with cross-element progress.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| opts.onPrimary | function\|nil | — | Primary click callback |
| opts.onSecondary | function\|nil | — | Secondary hold callback |
| opts.secondaryIcon | string | trash icon | Secondary button icon |
| opts.secondaryDuration | number | 1.0 | Hold duration |
| opts.secondaryStyle | string | "danger" | Secondary button style |
| opts.progressStyle | string | "danger" | Progress bar style |
| opts.style | string | "inactive" | Primary button style |
| opts.isActive | boolean\|nil | nil | Override to "active" style |
| opts.width | number\|nil | full width | Total width |

**Returns:** `table` — `{ primaryClicked, secondaryTriggered }`

```lua
c.ActionButton("preset_1", "My Preset", {
    onPrimary = function() loadPreset(1) end,
    onSecondary = function() deletePreset(1) end,
    isActive = currentPreset == 1,
    width = c.ColWidth(12),
})
```

### `resetHoldState(id)` / `resetAllHoldStates()`

Clear hold button state for cleanup.

## Collapsing Section

### `CollapsingSection(label, id?, defaultOpen?)`

Animated collapsible section with arrow toggle.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| label | string | — | Header label |
| id | string\|nil | label | Unique ID |
| defaultOpen | boolean\|nil | true | Default state |

**Returns:** `boolean` — true if content should be rendered

Must be paired with `EndCollapsingSection(id)`:

```lua
if c.CollapsingSection("Advanced Settings", "adv") then
    -- render content here
    c.EndCollapsingSection("adv")
end
```

## Fill Child

### `BeginFillChild(id, opts?)`

Child region that fills remaining vertical space.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| id | string | — | Child window ID |
| opts.footerHeight | number | 0 | Reserve space at bottom |
| opts.border | boolean | false | Show border |
| opts.flags | number | 0 | Extra ImGui window flags |
| opts.bg | table\|nil | nil | Background color `{r,g,b,a}` |

### `EndFillChild(opts?)`

End fill child. Pass `{ bg = true }` if a background color was set.

```lua
c.BeginFillChild("scrollArea", { footerHeight = 30, bg = {0.1, 0.1, 0.1, 0.5} })
-- scrollable content
c.EndFillChild({ bg = true })
ImGui.Button("Footer Button", c.RemainingWidth(), 0)
```

## Text Display

| Function | Color |
|----------|-------|
| `TextMuted(text)` | Grey |
| `TextSuccess(text)` | Green |
| `TextDanger(text)` | Red |
| `TextWarning(text)` | Yellow |

## Layout Helpers

### `Separator(spacingBefore?, spacingAfter?)`

Horizontal separator with optional spacing.

### `SectionHeader(label, spacingBefore?, spacingAfter?)`

Separator + label text with optional spacing.

## Frame Cache

`controls.cacheFrameState()` is called automatically each frame by WindowUtils. It caches `ImGui.GetStyle()` values (`ItemSpacing`, `FramePadding`, `WindowPadding`) to avoid repeated lookups.
