# Tabs — WindowUtils Tab Bars

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
| id | string | — | Unique tab bar ID |
| tabDefs | table | — | Array of tab definitions (see below) |
| opts.flags | number | 0 | ImGuiTabBarFlags |

**Returns:** `number` — index of the currently active tab (1-based), or 0 if tabDefs is empty

#### Tab Definition

Each entry in `tabDefs` is a table:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| label | string | — | Tab label text |
| content | function\|nil | nil | Callback to render tab content |
| badge | boolean\|number\|nil | nil | Badge indicator (see below) |
| disabled | boolean | false | Grey out and prevent selection |
| tooltip | string\|nil | nil | Tooltip on tab hover |

#### Badges

- `badge = true` — small green dot indicator
- `badge = 3` — red circle with number "3" (notification count)
- `badge = nil` — no badge

### `select(id, index)`

Programmatically select a tab by 1-based index. Takes effect on the next frame.

### `getSelected(id)`

Get the currently selected tab index.

**Returns:** `number` — 1-based index, or 1 if not initialized

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
