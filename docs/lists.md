# Lists - WindowUtils Scrollable List Container

Scrollable list rendering with per-item callbacks, focus tracking, dimming, auto-scroll, clipper optimization, and optional drag-drop reorder.

## Quick Start

```lua
local wu = GetMod("WindowUtils")
local lists = wu.Lists

local items = { "Alpha", "Beta", "Gamma" }
local state = {}

lists.render(items, function(item, index, state)
    ImGui.Text(item)
end, state)
```

## API Reference

### `render(items, renderer, state, opts?)`

Render a scrollable list of items with per-item callbacks. Handles ID scoping, hover detection, focus dimming, auto-scroll, clipper optimization, and optional drag-drop reorder.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| items | table\|nil | - | Array of items to render (nil or empty shows placeholder) |
| renderer | function | - | `function(item, index, state)` called for each visible item |
| state | table | - | Caller-owned state table (mutated each frame) |
| opts | table\|nil | `{}` | Configuration options (see opts table below) |

**Returns:** nil

If `renderer` or `state` is nil, a warning is logged and the function returns immediately.

### opts Table

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| id | string | `"##list"` | ImGui child region ID |
| height | number\|`"fill"` | `"fill"` | Fixed pixel height, or `"fill"` to consume remaining space |
| footerHeight | number | 0 | Space to reserve below the list (fill mode only) |
| bg | table\|nil | panel default | Background color `{r,g,b,a}` for the child region |
| placeholder | string | `"No items"` | Text shown when items is nil or empty |
| dimAlpha | number | 0.4 | Alpha for non-focused items when focusIndex is set |
| itemHeight | number\|nil | nil | Fixed item height for ImGuiListClipper (nil = no clipper) |
| showCount | boolean | false | Show item count above the list |
| countFormat | string | `"%d items"` | Format string for count display |
| reorderable | boolean | false | Enable drag-drop reordering |
| onReorder | function\|nil | nil | `function(fromIndex, toIndex)` called after reorder |
| dragHandle | string | `"DragHorizontalVariant"` | IconGlyph name for the drag handle |
| dragColors | table\|nil | nil | Colors for drag/hover styles `{dragAlpha?, hover?}` |
| unhighlightDelay | number | 0.3 | Seconds before clearing activeIndex after hover exit |
| onActiveChange | function\|nil | nil | `function(index\|nil)` called when activeIndex changes |
| disableStyleFn | function\|nil | `styles.PushDragDisabled` | Custom push style for non-active items |
| disableStylePopFn | function\|nil | `styles.PopDragDisabled` | Custom pop style for non-active items |

### State Table

The caller creates a plain table and passes it every frame. The module reads and writes these fields:

| Field | Type | Description |
|-------|------|-------------|
| focusIndex | number\|nil | Currently focused item index (caller sets, module clamps) |
| scrollTarget | number\|nil | Item index to scroll into view (caller sets, module clears after scroll) |
| hoveredIndex | number\|nil | Item index currently hovered (module writes each frame) |
| activeIndex | number\|nil | Item index currently active/highlighted (module manages with delayed unhighlight) |
| _hoverExitTime | number\|nil | Internal timer for delayed unhighlight (do not modify) |
| _dragdrop | table\|nil | Internal dragdrop state (auto-created when reorderable is true) |

Active index tracking: when hovering an item, `activeIndex` is set immediately. When the mouse leaves, a delay timer starts (default 0.3s). If the mouse re-enters any item or a drag is active before the timer expires, the timer resets. Non-active items receive disabled styling (`styles.PushDragDisabled` by default) so the active item stands out visually.

### Renderer Callback

```lua
---@param item any       The item value from the items array
---@param index number   1-based index of the item
---@param state table    The state table (read focusIndex, hoveredIndex, etc.)
function renderer(item, index, state)
    -- Render ImGui content for this item.
    -- PushID/PopID and BeginGroup/EndGroup are handled by the list module.
end
```

The renderer can read `state.focusIndex` and compare to `index` to customize rendering for the focused item. `state.hoveredIndex` is available after the frame completes.

## Examples

### Basic List

```lua
local items = { "One", "Two", "Three" }
local state = {}

lists.render(items, function(item, index, state)
    ImGui.Text(index .. ". " .. item)
end, state)
```

### Focus Tracking with Dimming

```lua
local items = { "Alpha", "Beta", "Gamma" }
local state = { focusIndex = nil }

lists.render(items, function(item, index, state)
    if ImGui.Selectable(item, state.focusIndex == index, 0, 0, 0) then
        state.focusIndex = index
    end
end, state, {
    dimAlpha = 0.3,
})
```

### Hover Highlighting with Delayed Unhighlight

Non-active items automatically receive disabled styling when any item is hovered. The highlight persists for 0.3s after the mouse leaves (configurable via `unhighlightDelay`), and stays active while dragging controls inside an item.

```lua
local items = { {x=0, y=0, z=0}, {x=1, y=2, z=3} }
local state = {}

lists.render(items, function(item, index, state)
    local vals, changed = controls.DragFloatRow(nil, "row_" .. index, {
        { value = item.x, color = styles.dragColors.x, label = "X" },
        { value = item.y, color = styles.dragColors.y, label = "Y" },
        { value = item.z, color = styles.dragColors.z, label = "Z" },
    }, { speed = 0.1 })
    if changed then
        item.x, item.y, item.z = vals[1], vals[2], vals[3]
    end
end, state, {
    onActiveChange = function(index)
        -- React to hover changes (e.g. highlight a 3D marker)
    end,
})
```

### Auto-Scroll

```lua
local items = {}
for i = 1, 100 do items[i] = "Item " .. i end
local state = {}

-- Scroll to item 50 on button click
if ImGui.Button("Scroll to #50") then
    state.scrollTarget = 50
end

lists.render(items, function(item, index, state)
    ImGui.Text(item)
end, state)
```

### Clipper for Large Lists

```lua
local items = {}
for i = 1, 1000 do items[i] = "Row " .. i end
local state = {}

lists.render(items, function(item, index, state)
    ImGui.Text(item)
end, state, {
    itemHeight = 24,
})
```

### Drag-Drop Reorder

```lua
local items = { "First", "Second", "Third" }
local state = {}

lists.render(items, function(item, index, state)
    ImGui.Text(item)
end, state, {
    reorderable = true,
    onReorder = function(from, to)
        print("Moved from " .. from .. " to " .. to)
    end,
})
```

### Empty State

```lua
local items = {}
local state = {}

lists.render(items, function(item, index, state)
    ImGui.Text(item)
end, state, {
    placeholder = "No saved positions. Click 'Add' to create one.",
})
```
