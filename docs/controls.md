# Controls  - WindowUtils UI Control Library

Grid-based layout system, styled buttons, sliders, inputs, hold-to-confirm buttons, bound controls, and layout helpers.

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
| width | number | 0 | Width (0 = auto, negative = fill available) |
| height | number | 0 | Height |

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
| disabled | boolean | Disable the button |
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

## Bound Controls

### `bind(data, defaults?, onSave?, bindOpts?)`

Create a bound context that auto-reads values from a data table, auto-resets on right-click from defaults, and auto-saves on change.

| Parameter | Type | Description |
|-----------|------|-------------|
| data | table | Data table to read/write |
| defaults | table\|nil | Default values for right-click reset |
| onSave | function\|nil | Callback after any value change |
| bindOpts.idPrefix | string | Prefix for ImGui IDs (default "") |

**Returns:** bound context with these methods:

| Method | Signature |
|--------|-----------|
| `ctx:SliderFloat` | `(icon, key, min, max, opts?)` |
| `ctx:SliderInt` | `(icon, key, min, max, opts?)` |
| `ctx:Checkbox` | `(label, key, opts?)` |
| `ctx:ColorEdit4` | `(icon, key, opts?)` |
| `ctx:Combo` | `(icon, key, items, opts?)` |
| `ctx:InputText` | `(icon, key, opts?)` |
| `ctx:InputFloat` | `(icon, key, opts?)` |
| `ctx:InputInt` | `(icon, key, opts?)` |
| `ctx:ToggleButtonRow` | `(defs, opts?)` |

Bound methods use `key` to read `data[key]`, reset to `defaults[key]` on right-click, and call `onSave()` on change.

```lua
local c = wu.Controls
local ctx = c.bind(settings.master, settings.defaults, settings.save, {
    idPrefix = "mymod_"
})

ctx:SliderFloat(IconGlyphs.Brightness, "brightness", 0.1, 10.0, {
    format = "%.1f", tooltip = "Light brightness"
})

ctx:Checkbox("Enable shadows", "shadowsEnabled", {
    icon = IconGlyphs.Shadow
})

ctx:Combo(IconGlyphs.Palette, "colorMode", { "RGB", "HSL", "HSV" })
```

#### Transform Option

Bound sliders (`SliderFloat`, `SliderInt`) and `Combo` support a `transform` option for value conversion between display and storage:

```lua
ctx:SliderFloat(icon, "gamma", 0, 100, {
    transform = {
        read = function(v) return v * 100 end,   -- storage → display
        write = function(v) return v / 100 end,   -- display → storage
    },
    percent = true,  -- show as "50%" format
})

ctx:Combo(IconGlyphs.Palette, "themeIndex", { "Light", "Dark", "Auto" }, {
    transform = {
        read = function(v) return v - 1 end,   -- 1-based storage → 0-based ImGui index
        write = function(v) return v + 1 end,   -- 0-based ImGui index → 1-based storage
    },
})
```

| Field | Type | Description |
|-------|------|-------------|
| transform.read | function | Converts storage value → display value |
| transform.write | function | Converts display value → storage value |

#### Percent Option

Bound `SliderFloat` and `SliderInt` support a `percent` option that auto-formats the slider label as a percentage of the slider range:

```lua
ctx:SliderFloat(icon, "opacity", 0, 1, {
    percent = true,  -- displays "50%" when value is 0.5
})
```

#### `ctx:ToggleButtonRow(defs, opts?)`

Row of toggle buttons bound to boolean keys in data. Left-click toggles, right-click resets to default.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| def.key | string |  - | Data table key for this toggle |
| def.icon | string\|nil | nil | Icon glyph (auto-sizes if no label) |
| def.label | string\|nil | nil | Button text label |
| def.weight | number | 1 | Flex weight for text buttons |
| def.width | number\|nil | nil | Fixed width override |
| def.tooltip | string\|nil | nil | Tooltip text |
| def.onChange | function\|nil | nil | Callback `(newValue)` after toggle |
| opts.gap | number | ItemSpacing.x | Gap between buttons |
| opts.id | string\|nil | nil | ID for min-width caching |

```lua
ctx:ToggleButtonRow({
    { key = "showGrid", icon = IconGlyphs.Grid, tooltip = "Grid" },
    { key = "showGuides", icon = IconGlyphs.RulerSquare, tooltip = "Guides" },
    { key = "snapEnabled", icon = IconGlyphs.Magnet, tooltip = "Snap" },
})
```

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
| opts.height | number | 0 | Panel height (0 = auto-fit content) |
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

### `SectionHeader(label, spacingBefore?, spacingAfter?)`

Separator + label text with optional spacing.

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
