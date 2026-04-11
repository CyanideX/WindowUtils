# Search

Search/filter system that dims non-matching controls when a query is active.

## Quick Start

```lua
local wu = GetMod("WindowUtils")
local search = wu.Search
local controls = wu.Controls

-- 1. Create a search state (once, in onInit)
local searchState = search.new("my_settings")

-- 2. Define your settings with search metadata
local defs = {
    volume    = { label = "Volume", category = "audio", searchTerms = "sound level" },
    subtitles = { label = "Show Subtitles", category = "audio", searchTerms = "text captions" },
    fov       = { label = "Field of View", category = "video", searchTerms = "camera angle",
                  icon = "Eye", min = 60, max = 120, format = "%.0f" },
}

-- 3. Create a bind context with search enabled
local c = controls.bind(data, defaults, onSave, {
    search = searchState,
    defs = defs,
})

-- 4. Render search bar + controls (in onDraw)
controls.SearchBar(searchState, { cols = 12 })
c:Checkbox("Show Subtitles", "subtitles")
c:SliderFloat(nil, "fov")  -- icon, min, max, format from defs
```

When the user types in the search bar, non-matching controls automatically dim. No `beginDim`/`endDim` wrapping needed.

## How It Works

1. The search state tracks the current query and caches match results
2. The bind context checks each control's def (label + searchTerms) against the query
3. Non-matching controls get a reduced alpha style pushed before rendering and popped after
4. Headers and sidebar entries can check category-level matches

The label passed to the control (e.g., "Show Subtitles") is automatically included in search matching. You only need `searchTerms` for extra keywords not in the label.

## Setting Definitions

Each key in the defs table maps to a setting key in your data table:

```lua
local defs = {
    myKey = {
        label = "Display Label",        -- included in search matching automatically
        category = "section.subsection", -- for header/sidebar dimming
        searchTerms = "extra keywords",  -- additional search terms
        tooltip = "Hover text",          -- shown on icon hover
        icon = "IconName",               -- IconGlyphs key name (string)
        min = 0, max = 100,              -- slider range
        format = "%.1f",                 -- slider format string
        percent = true,                  -- display as percentage
        items = {"A", "B", "C"},         -- combo dropdown items
        alwaysShowTooltip = true,        -- tooltip visible even when tooltips disabled
        transform = {                    -- value conversion for display
            read = function(v) return v end,
            write = function(v) return v end,
        },
    },
}
```

All fields are optional. Only include what you need.

## Search Bar

SearchBar and SearchBarPlain have moved to the controls module. They are now available as `controls.SearchBar()` and `controls.SearchBarPlain()`. See [controls.md](controls.md) for the full controls API.

```lua
controls.SearchBar(searchState, { cols = 12 })
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| cols | number | 12 | Column width (1-12 grid) |
| width | number | nil | Explicit pixel width (overrides cols) |

## Bind Context Options

```lua
local c = controls.bind(data, defaults, onSave, {
    search = searchState,       -- search state from search.new()
    defs = defs,                -- setting definitions table
    searchTooltips = false,     -- include tooltip text in search (default false)
})
```

When `search` and `defs` are provided, all bind methods (`c:Checkbox`, `c:SliderFloat`, etc.) automatically handle search dimming.

When `searchTooltips` is true, tooltip text is included in search matching for all controls. When false (default), tooltips are only included for controls without a text label (icon-only sliders, combos).

## Search-Aware Headers

The bind context provides header methods that dim based on category matches:

```lua
-- Plain text header, dims when no controls in "audio" category match
c:Header("Audio Settings", "audio")

-- Section header with separator, dims when no "video" controls match
c:SectionHeader("Video", "video", 10, 4)
```

## Categories

Categories support dot-separated hierarchies for granular header control:

```lua
local defs = {
    masterVol = { label = "Master Volume", category = "audio.master" },
    musicVol  = { label = "Music Volume",  category = "audio.music" },
    sfxVol    = { label = "SFX Volume",    category = "audio.sfx" },
}

-- Checks all sub-categories: audio.master, audio.music, audio.sfx
c:Header("Audio", "audio")

-- Only checks audio.music
c:SectionHeader("Music", "audio.music", 10, 0)
```

The sidebar can use the parent category to check if any sub-category has matches:

```lua
local dimmed = not searchState:isEmpty()
    and not searchState:categoryHasMatch("audio", defs)
if dimmed then ImGui.PushStyleVar(ImGuiStyleVar.Alpha, searchState.dimAlpha) end
-- render sidebar button
if dimmed then ImGui.PopStyleVar() end
```

## Separate Definitions File

For larger mods, keep definitions in a separate module:

```lua
-- modules/mydefs.lua
local mydefs = {}

function mydefs.init()
    return {
        volume    = { label = "Volume", category = "audio", searchTerms = "sound level",
                      icon = "VolumeHigh", min = 0, max = 100, format = "%.0f%%",
                      tooltip = "Master volume level" },
        subtitles = { label = "Show Subtitles", category = "audio",
                      searchTerms = "text captions",
                      tooltip = "Display subtitle text" },
    }
end

return mydefs
```

```lua
-- init.lua
local mydefs = require("modules/mydefs")

registerForEvent("onInit", function()
    myDefs = mydefs.init()  -- call after IconGlyphs is available
end)
```

## Plain Search Bar (Placeholder Text)

A variant without the magnifying glass icon. Uses `InputTextWithHint` to show placeholder text inside the input that disappears when the user starts typing.

```lua
controls.SearchBarPlain(searchState, {
    cols = 12,
    placeholder = "Search vehicles...",
})
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| cols | number | 12 | Column width (1-12 grid) |
| placeholder | string | "Search..." | Hint text shown when input is empty |
| maxLength | number | 256 | Maximum input length |
| clearIcon | boolean | false | Show a clear (X) icon when query is active |
| width | number | nil | Explicit pixel width (overrides cols) |

With `clearIcon = true`, a close button appears to the left of the input when the query is non-empty:

```lua
controls.SearchBarPlain(searchState, {
    placeholder = "Filter items...",
    clearIcon = true,
})
```

Both variants drive the same `SearchState`, so all dimming, caching, and category matching work identically.

## API Reference

The search module exports only state management. SearchBar and SearchBarPlain rendering has moved to the controls module (`controls.SearchBar()` and `controls.SearchBarPlain()`).

### `search.new(id, opts?)`

Create a new search state.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| id | string | - | Unique identifier |
| opts.dimAlpha | number | 0.25 | Alpha for non-matching items |

### `search.get(id)`

Retrieve an existing search state by id, or nil.

### SearchState Methods

### `state:matches(key, terms)`

Test if a key matches the current query. Terms is a space-separated string. Results are cached per query change.

### `state:categoryHasMatch(category, defs, includeTooltips?)`

Test if any def in the category (or sub-categories) matches. Supports prefix matching with dot-separated categories.

### `state:isEmpty()`

Returns true if the query is empty.

### `state:getQuery()`

Returns the current query string.

### `state:setQuery(text)`

Set the query string. Invalidates cache if changed.

### `state:clear()`

Clear the query and invalidate cache.
