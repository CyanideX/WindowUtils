# Icon Browser

Browsable, searchable icon picker for CET mods. Renders a filterable grid of all `IconGlyphs` with category filtering, search, and an optional preview panel.

## Quick Start

```lua
local wu = GetMod("WindowUtils")
local iconbrowser = wu.IconBrowser

-- Inline icon picker (in onDraw)
selected = iconbrowser.draw("my_picker", selected, function(name, glyph)
    print("Selected:", name, glyph)
end)
```

The browser indexes all `IconGlyphs` keys at load time, assigns categories via prefix matching, and renders a virtualized grid that handles 7000+ icons at 60fps.

## How It Works

1. On first use, all `IconGlyphs` keys are indexed and categorized by prefix matching against a built-in prefix-to-category map
2. The prefix map is sorted longest-first so the most specific match wins (e.g. "AccountMultiple" before "Account")
3. Icons that don't match any prefix are assigned to "Other"
4. The grid uses manual row-skipping (only visible rows are rendered) for performance with large icon sets
5. Per-instance state is tracked by ID, so multiple browsers can coexist independently

## draw(id, selected, onSelect, opts?)

Render an inline icon browser. Creates/retrieves per-instance state keyed by `id`.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| id | string | - | Unique instance ID |
| selected | string\|nil | nil | Currently selected icon name |
| onSelect | function\|nil | nil | Callback: `onSelect(name, glyph)` |
| opts | table\|nil | nil | Configuration overrides |

**Returns:** `string|nil` - updated selected icon name

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| cellSize | number | 28 | Icon cell size (1080p baseline pixels) |
| showSearch | boolean | true | Show the search bar |
| showCategory | boolean | true | Show the category dropdown |
| showPreview | boolean | false | Show the preview panel below the grid |
| showCount | boolean | true | Show the filtered icon count |
| layout | string | "fill" | `"fill"` (expand to fill space) or `"fixed"` (resizable panel) |
| gridHeight | number | 300 | Grid height when layout is "fixed" |
| defaultCategory | string\|nil | nil | Pre-select a category on first creation |

### Layout Modes

**fill** (default): The grid expands to fill all remaining vertical space, reserving room for the preview panel if enabled.

**fixed**: The grid renders inside a resizable panel with a configurable height. Useful for embedding in a larger layout.

```lua
-- Fixed-height embedded browser
iconbrowser.draw("embedded", selected, onSelect, {
    layout = "fixed",
    gridHeight = 200,
    showPreview = false,
})
```

### Preview Panel

When `showPreview = true`, a panel below the grid shows the selected icon's glyph, name, code reference, and category. Middle-click or right-click the preview icon to copy the code reference to clipboard.

```lua
iconbrowser.draw("picker", selected, onSelect, {
    showPreview = true,
})
```

### Search and Filtering

The search bar filters icons by name and category (case-insensitive substring match). The category dropdown filters to a single category. Both can be used together.

```lua
-- Browser with search but no category dropdown
iconbrowser.draw("simple", selected, onSelect, {
    showCategory = false,
})
```

## Category Queries

### getCategories()

Get sorted list of all category names.

**Returns:** `table` - sorted array of category name strings

### getCategory(name)

Get the category for a given icon name.

| Parameter | Type | Description |
|-----------|------|-------------|
| name | string | Icon name (PascalCase key from IconGlyphs) |

**Returns:** `string` - category name, or "Other" if unknown

```lua
local cat = iconbrowser.getCategory("AccountCircle")  -- "Account / User"
```

## Categories

Icons are categorized by prefix matching against a built-in map of ~60 categories. Categories include:

Account / User, Agriculture, Alert / Error, Alpha / Numeric, Animal, Arrange, Arrow, Audio, Automotive, Banking, Battery, Brand / Logo, Cellphone / Phone, Cloud, Clothing, Color, Currency, Database, Date / Time, Developer / Languages, Device / Tech, Drawing / Art, Edit / Modify, Emoji, Files / Folders, Food / Drink, Form, Gaming / RPG, Geographic Information System, Hardware / Tools, Health / Beauty, Holiday, Home Automation, Lock, Math, Medical / Hospital, Music, Nature, Navigation, Notification, People / Family, Photography, Places, Printer, Religion, Science, Settings, Shape, Shopping, Social Media, Sport, Text / Content / Format, Tooltip, Transportation, Vector, Video / Movie, View, Weather, and Other (fallback).
