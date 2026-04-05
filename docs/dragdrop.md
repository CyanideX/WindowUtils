# DragDrop

Drag-and-drop reordering for ImGui lists with visual feedback and drop indicators.

## Quick Start

```lua
local wu = GetMod("WindowUtils")
local dd = wu.DragDrop

local items = { "First", "Second", "Third" }

dd.list("myList", items, function(item, index, ctx)
    ImGui.Selectable(item, false, ImGuiSelectableFlags.None, 0, 0)
end, function(from, to)
    print("Moved item from " .. from .. " to " .. to)
end)
```

## Convenience API

### `list(id, items, renderFn, onReorder?, opts?)`

Render a reorderable list with all state, visuals, and array mutation handled internally.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| id | string |  - | Unique list ID |
| items | table |  - | Array to reorder in-place on drop |
| renderFn | function |  - | `function(item, index, ctx)`  - render each item |
| onReorder | function\|nil | nil | `function(fromIndex, toIndex)`  - called after reorder |
| opts.colors | table\|nil | nil | Custom colors (see below) |
| opts.showHandle | boolean | false | Show a drag handle icon before each item |
| opts.handleIcon | string | "DragVertical" | IconGlyph name for the drag handle |
| opts.handleColor | table | {0.5, 0.5, 0.5, 1} | Handle icon color `{r,g,b,a}` |

The `renderFn` must include an interactive ImGui element (Selectable, Button, etc.) that can be clicked and dragged.

The `ctx` parameter passed to `renderFn` contains:

| Field | Type | Description |
|-------|------|-------------|
| isDragged | boolean | This item is being dragged |
| isHoverTarget | boolean | Another item is being dragged over this one |
| dropAbove | boolean | Drop indicator should show above |
| dropBelow | boolean | Drop indicator should show below |

### Custom Colors

```lua
dd.list("myList", items, renderFn, onReorder, {
    colors = {
        dragAlpha = 0.4,                     -- opacity of dragged item
        hover = { 0.3, 0.5, 0.8, 0.3 },     -- hover highlight color
        separator = { 0.2, 0.6, 1.0, 1.0 }, -- drop indicator color
    }
})
```

## Advanced API

For full control over rendering and state, use the manual API.

### `createState()`

Create a new drag-drop state object.

**Returns:** `table`  - state with `draggingIndex`, `hoverIndex`, `dropPosition` fields

### `resetState(state)`

Reset all drag state fields to nil.

### `getItemContext(index, state)`

Get drag context for an item at the given index.

**Returns:** `table`  - `{ isDragged, isHoverTarget, dropAbove, dropBelow }`

### `handleDrag(index, totalCount, state)`

Process drag interaction for an item. Call after the interactive ImGui element.

**Returns:** `boolean, number|nil, number|nil`  - shouldReorder, fromIndex, toIndex

### `isDragging(state)`

Check whether a drag is in progress.

**Returns:** `boolean`

### `getDraggingIndex(state)`

Get the index of the item currently being dragged.

**Returns:** `number|nil`  - 1-based index, or nil if not dragging

### Visual Helpers

### `pushItemStyles(ctx, colors?)`

Push alpha/color changes for dragged or hovered items.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| colors.dragAlpha | number | 0.4 | Opacity of the dragged item |
| colors.hover | table | blueHover at 0.3 alpha | Highlight color for hover target `{r,g,b,a}` |

### `popItemStyles(ctx)`

Pop styles pushed by `pushItemStyles`. Must match.

### `drawSeparator(show, color?)`

Draw a colored separator as a drop indicator.

### `updateCursor(state)`

Set hand cursor when dragging over a valid target. Call once after the list loop.

### `reorderArray(array, fromIndex, toIndex)`

Move an element in an array from one index to another (mutates in-place).

## Examples

### Advanced Manual Control

```lua
local state = dd.createState()
local items = { "Alpha", "Beta", "Gamma" }

for i = 1, #items do
    local ctx = dd.getItemContext(i, state)
    dd.drawSeparator(ctx.dropAbove)
    dd.pushItemStyles(ctx)

    ImGui.PushID("item_" .. i)
    ImGui.Selectable(items[i], false, 0, 0, 0)
    local reorder, from, to = dd.handleDrag(i, #items, state)
    ImGui.PopID()

    dd.popItemStyles(ctx)
    dd.drawSeparator(ctx.dropBelow)

    if reorder then
        dd.reorderArray(items, from, to)
    end
end
dd.updateCursor(state)
```
