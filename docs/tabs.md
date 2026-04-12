# Tabs

Styled tab bars with badge indicators, disabled tabs, and programmatic selection.

## Quick Start

```lua
local wu = GetMod("WindowUtils")
local tabs = wu.Tabs

tabs.bar("myTabs", {
    { label = "General", content = function()
        ImGui.Text("General settings here")
    end },
    { label = "Advanced", content = function()
        ImGui.Text("Advanced settings here")
    end },
})
```

## API Reference

### `bar(id, tabDefs, opts?)`

Render a tab bar with content callbacks.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| id | string |  - | Unique tab bar ID |
| tabDefs | table |  - | Array of tab definitions (see below) |
| opts.flags | number | 0 | ImGuiTabBarFlags |

**Returns:** `number, boolean`  - `selected` (1-based active tab index, or 0 if empty), `changed` (true on the frame the user clicked a different tab)

#### Tab Definition

Each entry in `tabDefs` is a table:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| label | string |  - | Tab label text |
| content | function\|nil | nil | Callback to render tab content |
| badge | boolean\|number\|nil | nil | Badge indicator (see below) |
| disabled | boolean | false | Grey out and prevent selection |
| tooltip | string\|nil | nil | Tooltip on tab hover |
| noScroll | boolean | false | Wrap content in a no-scroll child that fills available space (for tabs managing their own layout with splitters/panels) |

#### Badges

- `badge = true`  - small green dot indicator
- `badge = 3`  - red circle with number "3" (notification count)
- `badge = nil`  - no badge

### `select(id, index)`

Programmatically select a tab by 1-based index. Takes effect on the next frame.

### `getSelected(id)`

Get the currently selected tab index.

**Returns:** `number`  - 1-based index, or 1 if not initialized

### `destroy(id)`

Remove internal state for a tab bar ID. Call when dynamically created tab bars are no longer needed.

## Examples

### Tabs with Badges and Disabled State

```lua
tabs.bar("settings", {
    { label = "General", content = drawGeneral },
    { label = "Notifications", badge = unreadCount, content = drawNotifications },
    { label = "Debug", disabled = not debugMode, tooltip = "Enable debug mode first",
      content = drawDebug },
    { label = "Status", badge = isConnected, content = drawStatus },
})
```

### Clearing Badges on Tab Select

```lua
local selected, changed = tabs.bar("settings", {
    { label = "General", content = drawGeneral },
    { label = "Inbox", badge = unreadCount > 0 and unreadCount or nil, content = drawInbox },
})
if changed and selected == 2 then
    unreadCount = 0  -- clear badge when user clicks the tab
end
```

### Programmatic Tab Selection

```lua
-- Switch to tab 2 when a condition is met
if shouldShowAdvanced then
    tabs.select("settings", 2)
end

-- Read which tab is active
local current = tabs.getSelected("settings")
```

### Using Tab Bar Flags

```lua
tabs.bar("fitted", tabDefs, {
    flags = ImGuiTabBarFlags.FittingPolicyResizeDown
})
```
