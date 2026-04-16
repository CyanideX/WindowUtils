# Controls

Grid-based layout, styled buttons, sliders, inputs, hold-to-confirm buttons, bound controls, and layout helpers.

## Controls Reference

All controls are accessed via `controls.*` (or `wu.Controls.*` from external mods).

| Control | Description |
|---------|-------------|
| `controls.Button(label, style?, width?, height?)` | Styled button |
| `controls.ToggleButton(label, isActive, width?, height?)` | Active/inactive toggle button |
| `controls.FullWidthButton(label, style?)` | Button filling available width |
| `controls.DisabledButton(label, width?, height?)` | Non-interactive greyed-out button |
| `controls.DynamicButton(label, icon, opts?)` | Adaptive button (text, truncated, or icon) |
| `controls.StatusBar(label, value?, opts?)` | Non-interactive status display |
| `controls.ButtonRow(defs, opts?)` | Row of buttons with auto width distribution |
| `controls.SliderFloat(icon, id, value, min, max, opts?)` | Float slider with icon |
| `controls.SliderInt(icon, id, value, min, max, opts?)` | Integer slider with icon |
| `controls.SliderDisabled(icon?, label)` | Greyed-out slider placeholder |
| `controls.TimeSlider(icon, id, value, opts?)` | Time-of-day slider (AM/PM format) |
| `controls.DragFloat(icon, id, value, min, max, opts?)` | Float drag with Shift precision |
| `controls.DragInt(icon, id, value, min, max, opts?)` | Integer drag with Shift precision |
| `controls.DragFloatRow(icon, id, drags, opts?)` | Multi-drag float row with theming |
| `controls.DragIntRow(icon, id, drags, opts?)` | Multi-drag integer row with theming |
| `controls.InputText(icon, id, text, opts?)` | Text input with icon |
| `controls.InputFloat(icon, id, value, opts?)` | Float input with step buttons |
| `controls.InputInt(icon, id, value, opts?)` | Integer input with step buttons |
| `controls.Checkbox(label, value, opts?)` | Checkbox with icon and reset |
| `controls.Combo(icon, id, index, items, opts?)` | Dropdown with icon |
| `controls.SearchBar(state, opts?)` | Search input with magnify/clear icon |
| `controls.SearchBarPlain(state, opts?)` | Search input with placeholder text |
| `controls.ProgressBar(fraction, width?, height?, overlay?, style?)` | Styled progress bar |
| `controls.ColorEdit4(icon, id, color, opts?)` | Color picker with icon |
| `controls.SwatchGrid(id, colors, selectedHex, onSelect, config?)` | Color swatch grid |
| `controls.HoldButton(id, label, opts?)` | Hold-to-confirm button |
| `controls.ActionButton(id, label, opts?)` | Primary click + secondary hold button |
| `controls.Panel(id, contentFn, opts?)` | Styled child window panel |
| `controls.PanelGroup(id, contentFn, opts?)` | Group-based panel (no nested scroll) |
| `controls.BeginFillChild(id, opts?)` | Fill remaining vertical space |
| `controls.EndFillChild(id)` | End fill child region |
| `controls.Row(id, defs, opts?)` | Horizontal child window layout |
| `controls.MultiRow(id, rows, defs, opts?)` | Multi-row cell layout |
| `controls.Column(id, defs, opts?)` | Vertical child window layout |
| `controls.Separator(spacingBefore?, spacingAfter?)` | Horizontal separator |
| `controls.SectionHeader(label, spacingBefore?, spacingAfter?, iconGlyph?)` | Separator + label |
| `controls.HeaderIconGlyph(opts)` | Right-justified icon on current line |
| `controls.TextMuted(text)` | Grey text |
| `controls.TextSuccess(text)` | Green text |
| `controls.TextDanger(text)` | Red text |
| `controls.TextWarning(text)` | Yellow text |
| `controls.bind(data, defaults?, onSave?, opts?)` | Create bound control context |
| `controls.unbind(ctx)` | Return bind context to pool |
| `controls.ColWidth(cols, gap?, hasIcon?)` | Column grid width calculator |
| `controls.RemainingWidth(offset?)` | Remaining available width |
| `controls.Scaled(value)` | Scale 1080p value to current resolution |

## Architecture

The controls module is split into focused sub-modules under `modules/controls/`:

| Sub-Module | Contents |
|------------|----------|
| `core.lua` | Shared foundation: frameCache, Scaled, ColWidth, IconButton, time helpers |
| `display.lua` | ProgressBar, ColorEdit4, SwatchGrid, Text*, Separator, SectionHeader |
| `buttons.lua` | Button, ToggleButton, FullWidthButton, DisabledButton, StatusBar, DynamicButton, ButtonRow |
| `sliders.lua` | SliderFloat, SliderInt, SliderDisabled, TimeSlider |
| `holdbuttons.lua` | HoldButton, ActionButton, hold progress helpers |
| `inputs.lua` | InputText, InputFloat, InputInt, Checkbox, Combo, SearchBar, SearchBarPlain |
| `drags.lua` | DragFloat, DragInt, DragFloatRow, DragIntRow |
| `layout.lua` | Row, MultiRow, Column, BeginFillChild, EndFillChild |
| `panels.lua` | PanelGroup, Panel |
| `bind.lua` | bind/unbind, bindMethods |

A thin aggregator at `modules/controls.lua` re-exports all sub-module APIs into a single `controls` table. No API changes for consumers: all `controls.*` calls work identically.

SearchBar and SearchBarPlain (previously in `search.lua`) are now part of the controls system in `inputs.lua`. See [search.md](search.md) for the updated search module scope.

## Quick Start

```lua
local wu = GetMod("WindowUtils")
local c = wu.Controls

-- Slider with icon, 8-column width, right-click reset
local val, changed = c.SliderFloat(IconGlyphs.Reload, "mySlider", value, 0, 100, {
    format = "%.1f", cols = 8, default = 50, tooltip = "Brightness"
})

-- Full-width styled button
if c.Button("Apply", "active", -1) then apply(val) end
```

## Grid System

Controls uses a 12-column grid (Bootstrap-style) to calculate widths relative to available space.

### `ColWidth(cols, gap?, hasIcon?)`

Calculate pixel width for a column span.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| cols | number | 12 | Columns to span (1-12) |
| gap | number | ItemSpacing.x | Gap between elements in pixels |
| hasIcon | boolean | false | Adjust for icon prefix width |

**Returns:** `number`  - width in pixels (minimum 20px)

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
| label | string |  - | Button label |
| styleName | string | "inactive" | Style name (see Styles module) |
| width | number | 0 | Width (0 = auto, negative = fill available width) |
| height | number | 0 | Height (0 = auto, negative = fill available height) |

**Returns:** `boolean`  - true if clicked

### `ToggleButton(label, isActive, width?, height?)`

Switches between "active" and "inactive" styles based on state.

### `FullWidthButton(label, styleName?)`

Button that fills available width.

### `DisabledButton(label, width?, height?)`

Non-interactive greyed-out button.

### `IconButton(icon, clickable?)`

Transparent button displaying an icon glyph. Used internally as slider/input labels.

### `StatusBar(label, value?, opts?)`

Non-interactive status bar with a label and optional value.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| label | string |  - | Left-side label (rendered inside button) |
| value | any\|nil | nil | Right-side value (rendered via `SameLine()`) |
| opts.widthFraction | number | 1 | Divides available width (2 = half width) |
| opts.style | string | "statusbar" | Button style name |

```lua
c.StatusBar("FPS", tostring(fps))
c.StatusBar("Mode", "Fixed", { widthFraction = 2 })
```

### `DynamicButton(label, icon, opts?)`

Button that adapts content based on available width. Full text at normal widths, truncated with "..." when narrow, icon-only when very narrow.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| label | string |  - | Full button label |
| icon | string\|nil |  - | Icon glyph for narrow display |
| opts.style | string | "inactive" | Button style |
| opts.width | number | available | Button width |
| opts.height | number | 0 | Button height |
| opts.minChars | number | 3 | Min visible chars before switching to icon |
| opts.iconThreshold | number\|nil | nil | Explicit pixel threshold for icon switch |
| opts.iconFallback | string | "?" | Fallback if icon resolves to nil |
| opts.tooltip | string\|nil | label | Tooltip when truncated or icon mode |

**Returns:** `boolean`  - true if clicked

```lua
-- Adapts from "Save Changes" → "Sav..." → icon
c.DynamicButton("Save Changes", IconGlyphs.ContentSave, {
    style = "active", width = c.ColWidth(4),
})
```

## Sliders

### `SliderFloat(icon, id, value, min, max, opts?)`

Float slider with optional icon prefix, column width, right-click reset, and tooltip.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| icon | string\|nil |  - | IconGlyph (nil = no icon) |
| id | string |  - | Unique slider ID |
| value | number |  - | Current value |
| min | number |  - | Minimum |
| max | number |  - | Maximum |
| opts.format | string | "%.2f" | Display format |
| opts.cols | number\|nil | nil | Grid columns (nil = fill remaining) |
| opts.default | number\|nil | nil | Right-click reset value |
| opts.tooltip | string\|nil | nil | Always-visible icon tooltip |

**Returns:** `number, boolean`  - new value, whether changed

```lua
local brightness, changed = c.SliderFloat(
    IconGlyphs.Reload, "brightness", settings.brightness,
    0.1, 10.0, { format = "%.1f", default = 1.0, tooltip = "Brightness" }
)
```

### `SliderInt(icon, id, value, min, max, opts?)`

Same as SliderFloat but for integers. Default format: `"%d"`.

### `SliderDisabled(icon?, label)`

Greyed-out non-interactive slider placeholder.

### `TimeSlider(icon, id, value, opts?)`

Time-of-day slider. Value is seconds since midnight (0-86399). Displays as "h:MM AM/PM". Drag adjusts in minute increments. Double-click to type a time string.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| icon | string\|nil |  - | IconGlyph (nil = no icon) |
| id | string |  - | Unique slider ID |
| value | number |  - | Seconds since midnight (0-86399) |
| opts.cols | number\|nil | nil | Grid columns (nil = fill remaining) |
| opts.default | number\|nil | nil | Right-click reset value (seconds) |
| opts.tooltip | string\|nil | nil | Always-visible icon tooltip |

**Returns:** `number, boolean` - new value in seconds, whether changed

Text input accepts: "1:45 PM", "13:45", "1345", "945", "9:45", or raw seconds.

```lua
local tod, changed = c.TimeSlider(
    IconGlyphs.ClockOutline, "gameTime", settings.timeOfDay,
    { default = 43200, tooltip = "Game time" }
)
```

Also available as `type = "time"` in DragFloatRow/DragIntRow entries (see Drag Controls).

## Drag Controls

Drag controls use `ImGui.DragFloat`/`ImGui.DragInt` instead of sliders. The value changes by dragging left/right with configurable speed. Hold Shift for precision mode (reduced drag speed).

### `DragFloat(icon, id, value, min, max, opts?)`

Float drag with optional icon prefix, column width, right-click reset, tooltip, and Shift precision.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| icon | string\|nil |  - | IconGlyph (nil = no icon) |
| id | string |  - | Unique drag ID |
| value | number |  - | Current value |
| min | number |  - | Minimum |
| max | number |  - | Maximum |
| opts.speed | number | (max-min)/200 | Base drag speed |
| opts.format | string | "%.2f" | Display format |
| opts.cols | number\|nil | nil | Grid columns (nil = fill remaining) |
| opts.default | number\|nil | nil | Right-click reset value |
| opts.tooltip | string\|nil | nil | Always-visible icon tooltip |
| opts.precisionMultiplier | number | 0.1 | Shift precision factor (lower = slower) |
| opts.noPrecision | boolean | false | Disable Shift precision for this control |

**Returns:** `number, boolean` - new value, whether changed

Shift precision: ImGui natively multiplies drag speed by 10x when Shift is held. `DragFloat` counters that and applies `precisionMultiplier`, giving an effective speed of `baseSpeed * 0.1 * precisionMultiplier` when Shift is held.

```lua
local val, changed = c.DragFloat(
    IconGlyphs.Speedometer, "myDrag", settings.speed,
    0.0, 10.0, { speed = 0.05, default = 1.0, tooltip = "Drag speed" }
)
```

### `DragInt(icon, id, value, min, max, opts?)`

Same as DragFloat but for integers. Default format: `"%d"`, default speed: `0.5`.

```lua
local val, changed = c.DragInt(
    IconGlyphs.Counter, "quality", settings.quality,
    1, 100, { tooltip = "Quality level" }
)
```

### `DragFloatRow(icon, id, drags, opts?)`

Compound control that renders multiple float drag inputs (and optionally buttons) on a single horizontal line. Supports per-drag color theming, width weighting, label-to-value display, and delta mode.

| Parameter | Type | Description |
|-----------|------|-------------|
| icon | string\|nil | IconGlyph prefix (nil = no icon) |
| id | string | Base ImGui ID (each drag appends its index) |
| drags | table | Array of Drag_Definitions and/or Button_Definitions |
| opts | table\|nil | Row-level options |

**opts fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| cols | number\|nil | nil | Grid columns for row width |
| speed | number\|nil | (max-min)/200 | Default base drag speed |
| min | number\|nil | nil | Default min for all drags |
| max | number\|nil | nil | Default max for all drags |
| precisionMultiplier | number\|nil | 0.1 | Shift precision factor |
| noPrecision | boolean\|nil | false | Disable Shift precision |
| tooltip | string\|nil | nil | Icon tooltip |
| spacing | number\|nil | itemSpacingX | Gap between elements |
| mode | string\|nil | "absolute" | `"absolute"` (value in/out) or `"delta"` (always 0 in, delta out) |
| onChange | function\|nil | nil | `(index, newValue, key)` callback when a drag changes |
| onReset | function\|nil | nil | `(index, key)` callback on right-click in delta mode |
| disabled | boolean\|string\|nil | nil | `true` = fully faded, `"dimmed"` = faded with outlined on hover, `"dimmedColor"` = faded with color border on hover |
| state | table\|nil | nil | Caller-owned state table for unbound rows (enables hover tracking and delta accumulation across frames) |
| id | string\|nil | nil | Unique suffix for bound rows sharing the same first key on the same bind context |

**Returns:** `table, boolean` - values array (one per drag, buttons excluded), whether any drag changed

**Drag_Definition fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| value | number | required | Current value |
| min | number\|nil | opts.min | Minimum |
| max | number\|nil | opts.max | Maximum |
| color | table\|nil | nil | Base `{r,g,b,a}` color theme |
| format | string\|nil | "%.2f" | Display format |
| label | string\|nil | nil | Idle display text, switches to value on hover |
| tooltip | string\|nil | nil | Hover tooltip |
| default | number\|nil | nil | Right-click reset value |
| speed | number\|nil | opts.speed | Per-drag speed override |
| width | number\|nil | nil | Fixed pixel width |
| widthPercent | number\|nil | nil | Fixed width as percentage of display width (e.g., 5 = 5% of screen) |
| fitLabel | boolean\|nil | nil | Auto-size width to fit the label text with padding |
| weight | number\|nil | 1 | Flex weight for remaining space (ignored when width/widthPercent/fitLabel is set) |
| disabled | boolean\|string\|nil | nil | Per-drag disabled style override (same values as opts.disabled) |
| onChange | function\|nil | nil | Per-drag `(newValue, key)` callback |
| widthFrom | string\|nil | nil | Use cached width from a button group (see `getButtonGroupWidth`) |
| groupId | string\|nil | nil | Group ID for width caching (buttons with same groupId have widths summed) |
| progressFrom | string\|nil | nil | Replace with progress bar when the named hold button is active |
| progressStyle | string\|nil | "danger" | Style for cross-element progress bar |
| mode | string\|nil | nil | Per-element `"delta"` override |

**Button_Definition fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| type | string | required | Must be `"button"` |
| icon | string\|nil | nil | Icon name (resolved via `utils.resolveIcon`) |
| label | string\|nil | nil | Button text |
| hoverLabel | string\|nil | nil | Text shown on hover (label-to-value pattern) |
| style | string | "inactive" | Button style |
| tooltip | string\|nil | nil | Hover tooltip |
| onClick | function\|nil | nil | Click callback `(index)` |
| holdDuration | number\|nil | nil | Hold-to-confirm duration |
| progressDisplay | string\|nil | nil | Hold progress display mode |
| progressFrom | string\|nil | nil | Show progress bar from another hold button |
| progressStyle | string\|nil | "danger" | Progress bar style |
| width | number\|nil | auto | Fixed pixel width |
| weight | number\|nil | nil | Flex weight (participates in remaining space distribution) |
| disabled | boolean\|nil | nil | Disable the button |
| id | string\|nil | nil | Custom button ID (for hold buttons) |

Elements without `type` (or `type = "drag"`) are treated as drags. Elements with `type = "button"` render as buttons. Elements with `type = "int"` render as integer drags. Elements with `type = "time"` render as time-of-day sliders. All elements are laid out left-to-right with `SameLine()`. Fixed-width elements (`width`, `widthPercent`, `fitLabel`) and buttons are subtracted from available space first; remaining space is divided proportionally by `weight` among weighted drags.

**Time_Definition fields** (`type = "time"`):

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| type | string | required | Must be `"time"` |
| value | number | 0 | Seconds since midnight (0-86399) |
| default | number\|nil | nil | Right-click reset value (seconds) |
| tooltip | string\|nil | nil | Hover tooltip |
| onChange | function\|nil | nil | `(newSeconds, key)` callback |
| onRelease | function\|nil | nil | Called when slider is released after dragging |
| disabled | boolean\|nil | nil | Disable the control |
| weight | number\|nil | 1 | Flex weight for width distribution |
| width | number\|nil | nil | Fixed pixel width |

Displays "h:MM AM/PM" format. Drag adjusts in minute increments. Double-click to type a time string ("1:45 PM", "13:45", "1345").

Color theming: a single `{r, g, b, a}` base color derives four ImGui style colors with a shared faded blue FrameBg background and axis-colored hover, active, and border. Drags without a color use the default outlined style.

Disabled styles: `disabled = true` renders a fully faded blue style. `"dimmed"` shows faded at rest but reveals the normal outlined style on hover. `"dimmedColor"` shows faded at rest but reveals the full color border on hover (requires `color` on each drag). Can be set per-drag or at the row level via opts.

Label-to-value: when a drag has a `label`, it displays the label text when idle and switches to the numeric value on hover or active drag. Requires a persistent state table (automatic for bound rows, pass `opts.state` for unbound rows).

```lua
-- Three colored float drags
local values, changed = c.DragFloatRow(nil, "pos", {
    { value = pos.x, color = c.DragColors.x, label = "X", min = -2000, max = 2000 },
    { value = pos.y, color = c.DragColors.y, label = "Y", min = -2000, max = 2000 },
    { value = pos.z, color = c.DragColors.z, label = "Z", min = -2000, max = 2000 },
}, { speed = 0.1 })

-- Mixed buttons + drags
local values, changed = c.DragFloatRow(nil, "posRow", {
    { type = "button", icon = "Upload", tooltip = "Load", onClick = function() loadPos() end },
    { type = "button", icon = "Refresh", tooltip = "Update", holdDuration = 1.0, onClick = function() updatePos() end },
    { value = pos.x, color = c.DragColors.x, label = "X", min = -2000, max = 2000 },
    { value = pos.y, color = c.DragColors.y, label = "Y", min = -2000, max = 2000 },
    { value = pos.z, color = c.DragColors.z, label = "Z", min = -2000, max = 2000 },
}, { speed = 0.1 })

-- Delta mode (drags always show 0, onChange receives deltas)
c.DragFloatRow(nil, "posRelative", {
    { value = 0, color = c.DragColors.x, label = "X", min = -10000, max = 10000 },
    { value = 0, color = c.DragColors.y, label = "Y", min = -10000, max = 10000 },
    { value = 0, color = c.DragColors.z, label = "Z", min = -10000, max = 10000 },
}, {
    mode = "delta",
    speed = 0.1,
    onChange = function(index, delta)
        local axes = { right, forward, up }
        local axis = axes[index]
        pos.x = pos.x + delta * axis.x
        pos.y = pos.y + delta * axis.y
        pos.z = pos.z + delta * axis.z
    end,
})

-- Width weighting (3 equal-weight + 1 fixed-width)
c.DragFloatRow(nil, "camera", {
    { value = cam.yaw,  label = "Yaw",  min = -180, max = 180 },
    { value = cam.tilt, label = "Tilt", min = -90,  max = 90 },
    { value = cam.roll, label = "Roll", min = -360, max = 360 },
    { value = cam.fov,  label = "FOV",  width = 80, min = 20, max = 130 },
}, { speed = 0.5 })
```

### `DragIntRow(icon, id, drags, opts?)`

Identical to `DragFloatRow` but uses `ImGui.DragInt`. Default format: `"%d"`, default speed: `0.5`.

```lua
local values, changed = c.DragIntRow("TuneVariant", "stats", {
    { value = stats.quality, label = "Quality" },
    { value = stats.priority, label = "Priority", width = 60 },
    { value = stats.count, label = "Count", width = 60 },
}, { min = 0, max = 100 })
```

### Preset Colors: `styles.dragColors`

Convenience color presets for common XYZ axis theming. Located in `modules/styles.lua`.

```lua
styles.dragColors = {
    x = { 0.8, 0.3, 0.3, 1.0 },   -- red
    y = { 0.3, 0.7, 0.3, 1.0 },   -- green
    z = { 0.3, 0.5, 0.9, 1.0 },   -- blue
}
```

Custom RGBA tables are also accepted anywhere a color is expected.

### `styles.PushDragColor(color)` / `styles.PopDragColor()`

Push/pop colored drag style with faded blue FrameBg and axis-colored hover, active, and border. Returns `false` if color is nil or invalid. Located in `modules/styles.lua`.

### `styles.PushDragDisabled()` / `styles.PopDragDisabled()`

Push/pop the faded blue disabled drag style. Renders faded blue backgrounds, no colored border, and muted white text. Located in `modules/styles.lua`.

## Input Fields

### `InputText(icon, id, text, opts?)`

Text input with optional icon, column width, and tooltip.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| icon | string\|nil |  - | IconGlyph |
| id | string |  - | Unique input ID |
| text | string |  - | Current text |
| opts.maxLength | number | 256 | Max characters |
| opts.cols | number\|nil | nil | Grid columns |
| opts.tooltip | string\|nil | nil | Icon tooltip |
| opts.alwaysShowTooltip | boolean | false | Show tooltip always (not just on hover) |

**Returns:** `string, boolean`  - new text, whether changed

### `InputFloat(icon, id, value, opts?)`

Float input with +/- step buttons.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| opts.step | number | 0.1 | Small step |
| opts.stepFast | number | 1.0 | Large step (holding Ctrl) |
| opts.format | string | "%.2f" | Display format |
| opts.cols | number\|nil | nil | Grid columns |
| opts.tooltip | string\|nil | nil | Icon tooltip |
| opts.alwaysShowTooltip | boolean | false | Show tooltip always (not just on hover) |

**Returns:** `number, boolean`  - new value, whether changed

### `InputInt(icon, id, value, opts?)`

Integer input with +/- step buttons.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| opts.step | number | 1 | Small step |
| opts.stepFast | number | 10 | Large step |
| opts.cols | number\|nil | nil | Grid columns |
| opts.tooltip | string\|nil | nil | Icon tooltip |
| opts.alwaysShowTooltip | boolean | false | Show tooltip always (not just on hover) |

**Returns:** `number, boolean`  - new value, whether changed

## Combo/Dropdown

### `Combo(icon, id, currentIndex, items, opts?)`

Dropdown with optional icon, column width, right-click reset.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| icon | string\|nil |  - | IconGlyph |
| id | string |  - | Unique combo ID |
| currentIndex | number |  - | Selected index (0-based) |
| items | table |  - | Array of item strings |
| opts.cols | number\|nil | nil | Grid columns |
| opts.default | number\|nil | nil | Right-click reset index |
| opts.tooltip | string\|nil | nil | Icon tooltip |

**Returns:** `number, boolean`  - new index, whether changed

## Checkboxes

### `Checkbox(label, value, opts?)`

Checkbox with optional icon prefix, right-click reset, and tooltip.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| label | string |  - | Checkbox label |
| value | boolean |  - | Current checked state |
| opts.icon | string\|nil | nil | Icon prefix (replaces the old `CheckboxWithIcon`) |
| opts.default | boolean\|nil | nil | Right-click reset value |
| opts.tooltip | string\|nil | nil | Tooltip text |
| opts.alwaysShowTooltip | boolean | false | Show tooltip always |

**Returns:** `boolean, boolean`  - new value, whether changed

```lua
-- Simple checkbox
local enabled, changed = c.Checkbox("Enable Feature", settings.enabled)

-- With icon prefix and right-click reset
local v, ch = c.Checkbox("Show Grid", settings.gridEnabled, {
    icon = IconGlyphs.Grid, default = true, tooltip = "Toggle grid overlay"
})
```

## Progress Bars

### `ProgressBar(fraction, width?, height?, overlay?, styleName?)`

Styled progress bar.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| fraction | number |  - | Progress 0-1 |
| width | number\|nil | full width | Bar width |
| height | number | 0 | Bar height |
| overlay | string | "" | Overlay text |
| styleName | string\|table | "default" | "default", "danger", "success", or custom color table |

Custom color table: `{ fill = {r,g,b,a}, frameBg = {r,g,b,a}, border = {r,g,b,a}, borderSize = 2.0 }`

## Color Picker

### `ColorEdit4(icon, id, color, opts?)`

Color picker with icon prefix and right-click reset.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| icon | string\|nil |  - | IconGlyph |
| id | string |  - | Unique picker ID |
| color | table |  - | RGBA color `{r,g,b,a}` |
| opts.label | string\|nil | nil | Text label before the picker |
| opts.default | table\|nil | nil | Right-click reset color |
| opts.tooltip | string\|nil | nil | Icon tooltip |

**Returns:** `table, boolean`  - new `{r,g,b,a}` color, whether changed

## Swatch Grid

### `SwatchGrid(id, colors, selectedHex, onSelect, config?)`

Grid of colored swatch buttons with dynamic column layout, optional hue sorting, and category grouping. All pixel values are specified at 1080p baseline and scaled internally to the current display resolution.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| id | string |  - | Unique ImGui ID for this grid instance |
| colors | table |  - | Array of Color_Entry tables |
| selectedHex | string\|nil | nil | Hex of the currently selected color (for highlight) |
| onSelect | function |  - | Callback: `onSelect(entry)` called when a swatch is clicked |
| config | table\|nil | nil | Swatch_Config overrides (merged with defaults) |

Returns immediately without rendering if `colors` is nil or empty.

**Color_Entry format:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | string | Yes | Unique identifier for this color |
| hex | string | Yes | 6-character hex code (no `#` prefix) |
| displayName | string | No | Tooltip label (defaults to `name`) |
| category | string | No | Grouping key; entries with the same category are grouped with a labeled separator |

**Swatch_Config options:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| swatchSize | number | 24 | Base swatch size (1080p px, scaled internally). Max is always 2x this value. |
| swatchSpacing | number | 4 | Gap between swatches (1080p px) |
| borderSize | number | 2 | Selection highlight border thickness (supports floats) |
| scaleBorder | boolean | false | Scale border proportionally with swatch size (baseline: borderSize at size 24) |
| sortMode | string\|boolean | false | Sort mode: `false`/`"none"`, `"hue"`, or `"lightness"` |

Caller-provided config fields override defaults; missing fields use defaults.

```lua
local myColors = {
    { name = "Sunset Orange", hex = "FD9E51", category = "warm" },
    { name = "Cherry Red",    hex = "CC2244", category = "warm" },
    { name = "Ocean Blue",    hex = "2266AA", category = "cool" },
    { name = "Forest Green",  hex = "228844", category = "cool" },
    { name = "Slate Grey",    hex = "778899", category = "neutral" },
}

c.SwatchGrid("myGrid", myColors, selectedHex, function(entry)
    selectedHex = entry.hex
end, { sortMode = "hue" })
```

## Hold-to-Confirm Button

### `HoldButton(id, label, opts?)`

Button that requires holding to trigger. Prevents accidental destructive actions.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| id | string |  - | Unique button ID |
| label | string |  - | Display label |
| opts.duration | number | 2.0 | Hold duration in seconds |
| opts.style | string | "danger" | Button style name |
| opts.width | number | 0 | Button width (negative = fill) |
| opts.progressDisplay | string | "overlay" | "overlay", "replace", or "external" |
| opts.progressStyle | string | "danger" | Progress bar style (for replace mode) |
| opts.disabled | boolean | false | Disable the button |
| opts.tooltip | string\|nil | nil | Tooltip text |
| opts.overlayColor | table\|nil | nil | Custom overlay fill color `{r,g,b,a}` |
| opts.onClick | function\|nil | nil | Callback on early release (click) |
| opts.onHold | function\|nil | nil | Callback on hold completion |

**Returns:** `boolean, boolean`  - `triggered` (hold completed), `clicked` (released early)

Progress display modes:
- **overlay**  - rect fills over the button as you hold
- **replace**  - button is replaced by a progress bar while held
- **external**  - no visual on the button itself; use `ShowHoldProgress()` elsewhere

```lua
local held, clicked = c.HoldButton("delete_all", "Delete All", {
    duration = 1.5, style = "danger",
    onHold = function() deleteAll() end,
    onClick = function() wu.Notify.info("Hold to confirm") end,
})
```

### `getHoldProgress(id)`

**Returns:** `number|nil`  - progress 0-1, or nil if not holding

### `ShowHoldProgress(sourceId, width?, progressStyle?)`

Renders a progress bar showing another button's hold state. Use with `progressDisplay = "external"`.

**Returns:** `boolean`  - true if progress bar is showing

### `getFirstActiveHoldProgress(ids)`

Return the progress and source ID of the first actively-held button from a list.

**Returns:** `number|nil, string|nil`  - progress 0-1 and source ID, or nil if none active

### `ShowFirstActiveHoldProgress(ids, width?, progressStyle?)`

Renders a progress bar for the first active hold source in a list of button IDs.

**Returns:** `boolean`  - true if a progress bar was rendered

### `ActionButton(id, label, opts?)`

Compound button: primary click + secondary hold-to-confirm with cross-element progress.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| opts.onPrimary | function\|nil |  - | Primary click callback |
| opts.onSecondary | function\|nil |  - | Secondary hold callback |
| opts.secondaryIcon | string | trash icon | Secondary button icon |
| opts.secondaryDuration | number | 1.0 | Hold duration |
| opts.secondaryStyle | string | "danger" | Secondary button style |
| opts.progressStyle | string | "danger" | Progress bar style |
| opts.style | string | "inactive" | Primary button style |
| opts.isActive | boolean\|nil | nil | Override to "active" style |
| opts.width | number\|nil | full width | Total width |

**Returns:** `table`  - `{ primaryClicked, secondaryTriggered }`

```lua
c.ActionButton("preset_1", "My Preset", {
    onPrimary = function() loadPreset(1) end,
    onSecondary = function() deletePreset(1) end,
    isActive = currentPreset == 1,
})
```

### `resetHoldState(id)` / `resetAllHoldStates()`

Clear hold button state for cleanup.

## ButtonRow

### `ButtonRow(defs, opts?)`

Row of buttons with automatic width distribution. Icon-only buttons auto-size; text buttons share remaining space by weight.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| defs | table |  - | Array of button definitions |
| opts.gap | number | ItemSpacing.x | Gap between buttons |
| opts.id | string\|nil | nil | ID for min-width caching |

**Button definition fields:**

| Field | Type | Description |
|-------|------|-------------|
| label | string\|nil | Button text |
| icon | string\|nil | Icon glyph (if no label, auto-sizes to icon width) |
| style | string | Style name (default "inactive") |
| weight | number | Flex weight for text buttons (default 1) |
| width | number\|nil | Fixed width override |
| height | number\|nil | Button height |
| disabled | boolean\|string\|nil | Disable the button. `true` = soft disable (uses "disabled" style, suppresses clicks, keeps hover for tooltips). `"hard"` = hard disable (uses `ImGui.BeginDisabled`, blocks all interaction including tooltips). |
| tooltip | string\|nil | Tooltip text |
| onClick | function\|nil | Click callback |
| onHold | function\|nil | Hold callback (turns button into HoldButton) |
| holdDuration | number | Hold duration (default 2.0) |
| progressFrom | string\|nil | Show progress from another button's hold state |
| progressStyle | string | Progress bar style |
| progressDisplay | string | Progress display mode |
| id | string\|nil | Custom button ID (for hold buttons) |

```lua
c.ButtonRow({
    { label = "Save", style = "active", onClick = save },
    { label = "Reset", style = "warning", onClick = reset },
    { icon = IconGlyphs.TrashCanOutline, style = "danger", onHold = deleteAll },
})
```

### `getButtonRowMinWidth(id)`

Get cached minimum width for a ButtonRow (when `opts.id` is set).

**Returns:** `number|nil`  - minimum width in pixels

### `getButtonGroupWidth(groupId)`

Get cached combined width of a button group from a previous `DragFloatRow`/`DragIntRow`. Buttons with the same `groupId` have their widths + spacing summed and cached.

**Returns:** `number|nil`  - combined pixel width

## Bound Controls

The bind system is the easiest way to build a settings UI. Instead of manually reading values, checking for changes, writing them back, and handling right-click reset for every control, you create a "bound context" that does all of that automatically.

### The Problem bind() Solves

Without bind, every control needs manual plumbing:

```lua
-- Without bind: lots of repetitive code
local val, changed = controls.SliderFloat(icon, "brightness", settings.brightness, 0, 10)
if changed then
    settings.brightness = val
    saveSettings()
end
-- ...repeat for every single control
```

With bind, you wire it up once and every control just works:

```lua
-- With bind: one setup, then just declare controls
local ctx = controls.bind(settings, defaults, saveSettings)
ctx:SliderFloat(icon, "brightness", 0, 10)  -- reads, writes, resets, saves automatically
```

### Basic Example

```lua
local wu = GetMod("WindowUtils")
local controls = wu.Controls

-- Your settings table (the data you want to edit)
local settings = { brightness = 1.0, volume = 50, showHUD = true }
local defaults = { brightness = 1.0, volume = 50, showHUD = true }

-- Create a bound context (once per frame, or cache it)
local ctx = controls.bind(settings, defaults, function() saveToFile() end)

-- Now just declare your controls. That's it.
ctx:SliderFloat(nil, "brightness", 0.1, 10.0)   -- edits settings.brightness
ctx:SliderInt(nil, "volume", 0, 100)             -- edits settings.volume
ctx:Checkbox("Show HUD", "showHUD")              -- edits settings.showHUD
```

Every bound control:
- Reads its value from `settings[key]`
- Writes the new value back to `settings[key]` when changed
- Resets to `defaults[key]` on right-click
- Calls your save function after any change

### Adding Icons and Tooltips

```lua
ctx:SliderFloat(IconGlyphs.Brightness6, "brightness", 0.1, 10.0, {
    format = "%.1f",
    tooltip = "Screen brightness multiplier",
})

ctx:Checkbox("Show HUD", "showHUD", {
    icon = IconGlyphs.Monitor,
    tooltip = "Toggle the heads-up display",
})

ctx:Combo(IconGlyphs.Palette, "colorMode", { "RGB", "HSL", "HSV" })
```

### ID Prefix

If your mod has multiple bind contexts (e.g., different settings pages), use `idPrefix` to avoid ImGui ID collisions:

```lua
local ctx = controls.bind(settings, defaults, save, { idPrefix = "mymod_" })
```

### Available Bound Methods

| Method | What it edits |
|--------|---------------|
| `ctx:SliderFloat(icon, key, min, max, opts?)` | Float slider |
| `ctx:SliderInt(icon, key, min, max, opts?)` | Integer slider |
| `ctx:DragFloat(icon, key, min, max, opts?)` | Float drag (Shift for precision) |
| `ctx:DragInt(icon, key, min, max, opts?)` | Integer drag |
| `ctx:DragFloatRow(icon, keys, min, max, opts?)` | Row of float drags |
| `ctx:DragIntRow(icon, keys, min, max, opts?)` | Row of integer drags |
| `ctx:Checkbox(label, key, opts?)` | Boolean checkbox |
| `ctx:ColorEdit4(icon, key, opts?)` | RGBA color picker |
| `ctx:SwatchGrid(key, colors, opts?)` | Color swatch grid |
| `ctx:Combo(icon, key, items, opts?)` | Dropdown selector |
| `ctx:InputText(icon, key, opts?)` | Text input |
| `ctx:InputFloat(icon, key, opts?)` | Float input with +/- buttons |
| `ctx:InputInt(icon, key, opts?)` | Integer input with +/- buttons |
| `ctx:ToggleButtonRow(defs, opts?)` | Row of boolean toggle buttons |

All methods use `key` (a string) to look up the value in your data table. The second argument is always the key, except for `Checkbox` where the first argument is the visible label.

### DragFloatRow (Bound)

The bound version takes a `keys` array instead of a `drags` array. Values are read from `data[key]` for each key.

```lua
-- Simple: just keys and range
ctx:DragFloatRow(nil, {"x", "y", "z"}, -2000, 2000)

-- With colored labels that show values on hover
ctx:DragFloatRow(nil, {"x", "y", "z"}, -2000, 2000, {
    speed = 0.1,
    drags = {
        { color = styles.dragColors.x, label = "X" },
        { color = styles.dragColors.y, label = "Y" },
        { color = styles.dragColors.z, label = "Z" },
    },
})
```

### ToggleButtonRow (Bound)

Row of toggle buttons, each bound to a boolean key. Left-click toggles, right-click resets.

```lua
ctx:ToggleButtonRow({
    { key = "showGrid",    icon = IconGlyphs.Grid,        tooltip = "Grid" },
    { key = "showGuides",  icon = IconGlyphs.RulerSquare, tooltip = "Guides" },
    { key = "snapEnabled", icon = IconGlyphs.Magnet,      tooltip = "Snap" },
})
```

### SwatchGrid (Bound)

Reads `data[key]` as the selected hex string, writes back on click. Right-click resets.

```lua
ctx:SwatchGrid("accentColor", myColors, {
    config = { sortMode = "hue" },
    onChange = function() refreshTheme() end,
})
```

### Transform Option

Convert between storage format and display format. Useful when your data stores values differently than the slider shows them.

```lua
-- Data stores 0.0-1.0, slider shows 0-100%
ctx:SliderFloat(nil, "opacity", 0, 100, {
    transform = {
        read = function(v) return v * 100 end,
        write = function(v) return v / 100 end,
    },
    percent = true,
})

-- Data stores 1-based index, ImGui combo uses 0-based
ctx:Combo(nil, "theme", { "Light", "Dark", "Auto" }, {
    transform = {
        read = function(v) return v - 1 end,
        write = function(v) return v + 1 end,
    },
})
```

### Search Integration

When combined with the search module, bound controls automatically dim when they don't match the search query. See [search.md](search.md) for setup details.

```lua
local searchState = wu.Search.new("my_settings")

local ctx = controls.bind(settings, defaults, save, {
    search = searchState,
    defs = {
        brightness = { label = "Brightness", category = "visuals" },
        volume     = { label = "Volume",     category = "audio" },
    },
})

-- Search bar at the top
controls.SearchBar(searchState, { cols = 12 })

-- Headers dim when no controls in their category match
ctx:Header("Visuals", "visuals")
ctx:SliderFloat(nil, "brightness", 0, 10)

ctx:SectionHeader("Audio", "audio", 10, 0)
ctx:SliderFloat(nil, "volume", 0, 100)
```

### `ctx:Header(text, category, iconGlyph?)`

Text header that auto-dims when no controls in the category match the search query.

### `ctx:SectionHeader(text, category, spacingBefore?, spacingAfter?, iconGlyph?)`

Separator + label that auto-dims based on category match.

### `ctx:BeginDim(key)` / `ctx:EndDim(dimmed)`

Manual dimming for custom controls that aren't part of the bind system but should still participate in search filtering.

```lua
local dimmed = ctx:BeginDim("myCustomKey")
-- render your custom ImGui controls here
ctx:EndDim(dimmed)
```

### `unbind(ctx)`

Return a bind context to the internal pool for reuse. Optional. Without this, contexts are garbage collected normally.

### Advanced: Def-Driven Controls

When you pass `defs` to the bind context, controls can pull their configuration (icon, min, max, tooltip, format, items) from the defs table instead of passing them inline. This keeps your draw code minimal and your configuration centralized.

```lua
local defs = {
    brightness = {
        label = "Brightness",
        icon = "Brightness6",
        min = 0.1, max = 10.0,
        format = "%.1f",
        tooltip = "Screen brightness multiplier",
        category = "visuals",
    },
    quality = {
        label = "Quality",
        icon = "TuneVariant",
        items = { "Low", "Medium", "High", "Ultra" },
        tooltip = "Rendering quality preset",
        category = "visuals",
    },
}

local ctx = controls.bind(settings, defaults, save, {
    defs = defs,
    search = searchState,  -- optional: enables auto-dimming
})

-- These pull icon, min, max, format, tooltip from defs automatically.
-- You only need to specify the key.
ctx:SliderFloat(nil, "brightness")
ctx:Combo(nil, "quality")
```

Any value you pass inline overrides the def. So `ctx:SliderFloat(nil, "brightness", 0, 5)` would use min=0, max=5 instead of the def's 0.1 and 10.0.

### Advanced: Per-Control onChange

Every bound method supports an `onChange` callback in opts that fires after the value is written. Useful for triggering side effects without polling.

```lua
ctx:Checkbox("Enable Grid", "gridEnabled", {
    onChange = function(newValue, key)
        if newValue then showGrid() else hideGrid() end
    end,
})

ctx:SliderFloat(nil, "volume", 0, 100, {
    onChange = function(newValue, key)
        setAudioVolume(newValue)
    end,
})
```

You can also put `onChange` in the defs table so it fires regardless of where the control is rendered.

### Advanced: Delta Mode DragRows

Normal drag rows read and write absolute values. Delta mode is for controls where you want to apply relative changes (like moving a camera). The drags always display 0 and report the delta on each frame.

```lua
ctx:DragFloatRow(nil, {"x", "y", "z"}, -10000, 10000, {
    mode = "delta",
    speed = 0.1,
    drags = {
        { color = styles.dragColors.x, label = "X" },
        { color = styles.dragColors.y, label = "Y" },
        { color = styles.dragColors.z, label = "Z" },
    },
    onChange = function(values, keys)
        -- values[1], values[2], values[3] are the deltas this frame
        entity:Move(values[1], values[2], values[3])
    end,
})
```

In delta mode, right-click calls `onReset` instead of writing a default value, since there's no absolute value to reset.

### Advanced: Cross-Element Progress Bars

Buttons and drags in a DragRow can show a progress bar from another element's hold state. This lets you replace a control with a visual progress indicator while a hold-to-confirm action is in progress. This uses the standalone `controls.DragFloatRow` (not the bound version) since it supports mixed drag + button elements.

```lua
controls.DragFloatRow(nil, "pos", {
    { value = pos.x, color = styles.dragColors.x, label = "X", progressFrom = "reset_pos" },
    { value = pos.y, color = styles.dragColors.y, label = "Y", progressFrom = "reset_pos" },
    { value = pos.z, color = styles.dragColors.z, label = "Z", progressFrom = "reset_pos" },
    { type = "button", icon = "Refresh", holdDuration = 1.0, id = "reset_pos",
      onClick = function() resetPosition() end },
}, { speed = 0.1 })
```

When the user holds the reset button, all three drag inputs are replaced by a single progress bar spanning their combined width.

### Advanced: Width Weighting in DragRows

Elements in a DragRow share available space by weight. Fixed-width elements are subtracted first, then remaining space is divided proportionally.

```lua
ctx:DragFloatRow(nil, {"yaw", "tilt", "roll", "fov"}, nil, nil, {
    speed = 0.5,
    drags = {
        { label = "Yaw",  min = -180, max = 180 },              -- weight 1 (default)
        { label = "Tilt", min = -90,  max = 90 },               -- weight 1
        { label = "Roll", min = -360, max = 360 },              -- weight 1
        { label = "FOV",  min = 20,   max = 130, width = 80 },  -- fixed 80px
    },
})
```

Other width options: `weight = 2` (double share), `widthPercent = 5` (5% of screen), `fitLabel = true` (auto-size to label text).

## Fill Child

### `BeginFillChild(id, opts?)`

Child region that fills remaining vertical space.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| id | string |  - | Child window ID (## prefix added automatically if missing) |
| opts.footerHeight | number | 0 | Reserve space at bottom |
| opts.border | boolean | false | Show border |
| opts.flags | number | 0 | Extra ImGui window flags |
| opts.bg | table\|nil | nil | Background color `{r,g,b,a}` |

**Returns:** `boolean`  - true if the child region is visible

### `EndFillChild(id)`

End fill child. Pass the same `id` used in `BeginFillChild` so the background color can be popped correctly.

| Parameter | Type | Description |
|-----------|------|-------------|
| id | string | Child ID passed to `BeginFillChild` |

```lua
c.BeginFillChild("scrollArea", { footerHeight = 30, bg = {0.1, 0.1, 0.1, 0.5} })
-- scrollable content
c.EndFillChild("scrollArea")
ImGui.Button("Footer Button", c.RemainingWidth(), 0)
```

## Panel

### `Panel(id, contentFn, opts?)`

Child region with optional background color and border. Always has internal padding (`AlwaysUseWindowPadding`). A simpler alternative to `BeginFillChild`/`EndFillChild` for non-expanding regions.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| id | string |  - | Child window ID (auto-prefixed with `##` if needed) |
| contentFn | function |  - | Renders panel content |
| opts.bg | table\|false | subtle blue | Background color `{r,g,b,a}` or `false` for none |
| opts.border | boolean | false | Show border |
| opts.borderOnHover | boolean | false | Show border only when hovered |
| opts.width | number | 0 | Panel width (0 = fill available) |
| opts.height | number\|"auto" | 0 | Panel height (0 = auto-fit, `"auto"` = measured from content) |
| opts.flags | number | 0 | Extra ImGui window flags |

```lua
c.Panel("info", function()
    ImGui.Text("Panel content")
end)

c.Panel("interactive", function()
    ImGui.Text("Hover me")
end, { borderOnHover = true })

c.Panel("fixed", drawContent, { width = 300, height = 200 })
```

## PanelGroup

### `PanelGroup(id, contentFn, opts?)`

Visual panel wrapper using `BeginGroup`/`EndGroup` + DrawList instead of `BeginChild`. No explicit height is needed; content flows in the parent scroll region. Background and border are drawn via DrawList with padding and rounding.

Use this instead of `Panel` when you need a styled panel inside a scrollable region without creating a nested scroll context.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| id | string |  - | Unique identifier (for hover state tracking) |
| contentFn | function\|nil | nil | Callback that renders panel content |
| opts.bg | table\|false | subtle blue | Background color `{r,g,b,a}` or `false` for none |
| opts.border | boolean | false | Show border |
| opts.borderOnHover | boolean | false | Show border only when hovered (with tooltip) |

```lua
c.PanelGroup("info", function()
    ImGui.Text("This panel scrolls with its parent")
    ImGui.Text("No nested scroll context")
end)

c.PanelGroup("hover_panel", function()
    ImGui.Text("Hover to see border")
end, { borderOnHover = true })
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

### `SectionHeader(label, spacingBefore?, spacingAfter?, iconGlyph?)`

Separator + label text with optional spacing and right-justified icon glyph.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| label | string |  - | Section title text |
| spacingBefore | number\|nil | nil | Vertical spacing before separator |
| spacingAfter | number\|nil | nil | Vertical spacing after label |
| iconGlyph | table\|nil | nil | HeaderIconGlyph opts table (see below) |

### `HeaderIconGlyph(opts)`

Renders a right-justified icon glyph on the current ImGui line. Intended for use after header or section header text to show contextual icons, warnings, or info indicators.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| icon | string |  - | IconGlyphs key name (e.g. `"AlertBox"`) or raw glyph string |
| tooltip | string\|nil | nil | Tooltip text shown on hover |
| color | table\|nil | nil | RGBA color `{r, g, b, a}` applied to the icon text |
| visible | boolean\|nil | true | If `false`, skips rendering entirely |
| onClick | function\|nil | nil | Click callback (renders as a frameless button instead of text) |
| alwaysShowTooltip | boolean\|nil | false | Show tooltip even when `tooltipsEnabled` is off |

When `onClick` is provided, the icon renders as a frameless button (via `styles.PushButtonFrameless`) so clicks register in CET. When `onClick` is nil, it renders as plain `ImGui.Text`.

If `IconGlyphs` is nil (CET not fully loaded), the function returns immediately without error.

```lua
-- Info icon with tooltip
controls.SectionHeader("Settings", 10, 0, {
    icon = "InformationBox",
    tooltip = "Hover for details about this section",
    alwaysShowTooltip = true,
})

-- Warning icon with click handler
controls.SectionHeader("Experimental", 10, 0, {
    icon = "AlertBox",
    tooltip = "Click to review disclaimer",
    onClick = function() openDisclaimer() end,
})

-- Conditional visibility
controls.SectionHeader("Constraints", 10, 0, {
    icon = "AlertCircleOutline",
    tooltip = "Active constraints detected",
    color = { 1, 0.8, 0, 1 },
    visible = hasConstraints,
})
```

## Row Layout

### `Row(id, defs, opts?)`

Horizontal row of child windows that fills available width.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| id | string |  - | Unique row ID |
| defs | table |  - | Array of child definitions |
| opts.height | number\|nil | nil | Row height (nil = auto) |
| opts.gap | number\|nil | ItemSpacing.x | Gap between children |

**Child definition fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| content | function |  - | Renders child content |
| width | number\|nil | nil | Fixed width in pixels |
| cols | number\|nil | nil | Width from ColWidth grid (1-12) |
| flex | number\|nil | 1 | Proportional share of remaining space |
| border | boolean | false | Show child border |
| flags | number | 0 | Extra ImGui window flags |
| bg | table\|nil | nil | Background color `{r,g,b,a}` |

```lua
c.Row("layout", {
    { width = 200, content = drawSidebar },
    { content = drawMainContent },
})
```

## MultiRow Layout

### `MultiRow(id, rows, defs, opts?)`

Horizontal row of child windows where cells can span the full vertical height or stack multiple rows of normal-height controls. Useful for placing a tall button alongside stacked controls.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| id | string | - | Unique row ID prefix |
| rows | number | - | Number of visual rows (determines region height) |
| defs | table | - | Array of cell definitions |
| opts.gap | number\|nil | ItemSpacing.x | Horizontal spacing between cells |

**Height calculation:**

Region height = `rows * (frameCache.frameHeight + frameCache.itemSpacingY)`

**Cell definition fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| width | number\|nil | nil | Fixed width in pixels |
| cols | number\|nil | nil | Width from ColWidth grid (1-12) |
| flex | number\|nil | 1 | Proportional share of remaining space |
| span | boolean\|nil | nil | If true, single child at full region height |
| rows | table\|nil | nil | Array of content functions for stacked rows |
| content | function\|nil | nil | Single content function |
| bg | table\|nil | nil | Background color `{r,g,b,a}` |
| border | boolean | false | Show child border |
| flags | number | 0 | Extra ImGui window flags |

**Cell type resolution** (first match wins):

1. `span = true` - Span cell: single child window at full region height, calls `content()`
2. `rows` is a non-empty array - Stack cell: each function rendered in its own nested child window
3. `content` is a function - Single content cell at full region height
4. None of the above - Empty child window

Stack row height = `floor((regionHeight - (N - 1) * itemSpacingY) / N)` where N is the number of stacked rows.

**Error handling:**

- `defs` nil or empty: returns immediately (silent)
- `rows` not a number or < 1: logs error, returns
- Cell has both `span` and `rows`: logs warning, treats as span

**Span cell with tall button:**

```lua
c.MultiRow("demo", 2, {
    { cols = 3, span = true, content = function()
        local _, h = ImGui.GetContentRegionAvail()
        c.Button("Tall", "active", -1, h)
    end },
    { rows = {
        function() c.Button("Top", "inactive", -1) end,
        function() c.Button("Bottom", "inactive", -1) end,
    } },
})
```

**Stack cell with three rows:**

```lua
c.MultiRow("stack", 3, {
    { rows = {
        function() c.Button("Row 1", "inactive", -1) end,
        function() c.Button("Row 2", "inactive", -1) end,
        function() c.Button("Row 3", "inactive", -1) end,
    } },
})
```

**Mixed layout with flex widths:**

```lua
c.MultiRow("mixed", 2, {
    { flex = 1, span = true, content = function()
        local _, h = ImGui.GetContentRegionAvail()
        c.Button("Span", "active", -1, h)
    end },
    { flex = 2, rows = {
        function() c.Button("A", "inactive", -1) end,
        function() c.Button("B", "inactive", -1) end,
    } },
    { flex = 1, content = function()
        c.Button("Single", "inactive", -1)
    end },
})
```

**Background and border:**

```lua
c.MultiRow("styled", 2, {
    { bg = { 0.2, 0.4, 0.8, 0.15 }, border = true, span = true, content = function()
        local _, h = ImGui.GetContentRegionAvail()
        c.Button("Highlighted", "active", -1, h)
    end },
    { rows = {
        function() c.Button("Normal 1", "inactive", -1) end,
        function() c.Button("Normal 2", "inactive", -1) end,
    } },
})
```

**Grid layout inside stack rows (Row/ColWidth for per-row column spans):**

```lua
c.MultiRow("grid", 3, {
    { rows = {
        function()
            c.Row("r1", {
                { cols = 3, content = function() c.Button("1", "inactive", -1) end },
                { cols = 6, content = function() c.Button("2-wide", "active", -1) end },
                { cols = 3, content = function() c.Button("1", "inactive", -1) end },
            })
        end,
        function()
            c.Row("r2", {
                { content = function() c.Button("Left", "inactive", -1) end },
                { content = function() c.Button("Right", "active", -1) end },
            })
        end,
        function()
            c.SliderInt("TuneVariant", "slider", val, 0, 100)
        end,
    } },
})
```

## Column Layout

### `Column(id, defs, opts?)`

Vertical column of child windows that fills available height. Children can be flex (proportional), fixed height, or auto-sized.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| id | string |  - | Unique column ID |
| defs | table |  - | Array of child definitions |
| opts.gap | number\|nil | ItemSpacing.y x 2 | Gap between children (0 = flush) |

**Child definition fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| content | function |  - | Renders child content |
| flex | number\|nil | 1 | Proportional share of remaining height |
| height | number\|nil | nil | Fixed height (auto-adds `NoScrollbar`) |
| auto | boolean\|nil | nil | Auto-size to content (no child window) |
| border | boolean | false | Show child border |
| flags | number | 0 | Extra ImGui window flags |
| bg | table\|nil | nil | Background color `{r,g,b,a}` |

```lua
c.Column("page", {
    { flex = 1, content = drawTopPanel },
    { flex = 1, content = drawBottomPanel },
    { auto = true, content = function()
        if c.Button("Reset", "inactive") then reset() end
    end },
})
```

## Frame Cache

### `cacheFrameState()`

Populates the per-frame style/metric cache. Called automatically once per `onDraw` frame by WindowUtils before any control rendering. You do not need to call this yourself unless you are using Controls outside of the standard WindowUtils draw loop.

### `getFrameCache()`

Returns the cached frame metrics table. Useful for dynamic sizing that scales with font/DPI.

**Returns:** `table` with fields:

| Field | Source | Description |
|-------|--------|-------------|
| itemSpacingX | Style.ItemSpacing.x | Horizontal spacing between items |
| itemSpacingY | Style.ItemSpacing.y | Vertical spacing between items |
| framePaddingX | Style.FramePadding.x | Horizontal frame padding |
| windowPaddingX | Style.WindowPadding.x | Horizontal window padding |
| windowPaddingY | Style.WindowPadding.y | Vertical window padding |
| frameHeight | GetFrameHeight() | Height of a framed widget |
| textLineHeight | GetTextLineHeightWithSpacing() | Text line height with spacing |
| minIconButtonWidth | Computed | Minimum icon button width (icon + 2x framePadding) |
| charWidth | CalcTextSize("M") | Width of reference character "M" |
| ellipsisWidth | CalcTextSize("...") | Width of truncation ellipsis |
| displayWidth | GetDisplayResolution() | Screen width in pixels |
| displayHeight | GetDisplayResolution() | Screen height in pixels |

```lua
local cache = c.getFrameCache()
local headerH = cache.frameHeight  -- scales with font/DPI
```
