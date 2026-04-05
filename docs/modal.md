# Modal

Centered modal popups with percent-based sizing, button configuration, hold-to-confirm, and a styled variant.

## Quick Start

```lua
local wu = GetMod("WindowUtils")
local modal = wu.Modal

-- Simple confirmation
modal.confirm("my_confirm", {
    title = "Delete Preset",
    body = "Are you sure?",
    onConfirm = function()
        deletePreset()
    end,
})

-- Alert
modal.alert("my_alert", {
    title = "Error",
    body = "Failed to save settings.",
})

-- Info
modal.info("my_info", {
    title = "About",
    body = "My Mod v1.0 by Author",
})
```

Modals are centered on screen, auto-sized to content, and close when any button is clicked. Call `modal.draw()` once per frame (WindowUtils does this automatically).

## How It Works

Call any modal function (e.g. `modal.confirm(...)`) to open a popup. The call is typically made inside a button click handler or event callback during your `onDraw`:

```lua
registerForEvent("onDraw", function()
    if not wu or not overlayOpen then return end

    if ImGui.Begin("My Mod") then
        -- Button that opens a modal when clicked
        if wu.Controls.Button("  Delete  ", "danger") then
            wu.Modal.confirm("delete_confirm", {
                title = "Delete Item",
                body = "This cannot be undone.",
                onConfirm = function()
                    deleteItem()
                end,
            })
        end
    end
    ImGui.End()
end)
```

You do not need to call `modal.draw()` yourself. WindowUtils calls it automatically each frame after your UI renders. The modal appears centered on screen and blocks interaction with content behind it until dismissed.

To close a modal programmatically (e.g. from a timer or external event):

```lua
modal.close("delete_confirm")
```

To check if a modal is currently open:

```lua
if modal.isOpen("delete_confirm") then
    -- modal is visible
end
```

## Convenience Functions

### `confirm(id, opts)`

Two-button dialog: Confirm + Cancel.

```lua
modal.confirm("delete_all", {
    title = "Delete All Data",
    body = "This cannot be undone.",
    onConfirm = function() wipeData() end,
})
```

### `alert(id, opts)`

Single OK button.

```lua
modal.alert("save_error", {
    title = "Save Failed",
    body = "Check file permissions.",
})
```

### `info(id, opts)`

Single Close button.

```lua
modal.info("about", {
    title = "About My Mod",
    body = "Version 2.1 - Thanks for using this mod!",
})
```

### `styled(id, opts)`

Centered title (no title bar), body wrapped in a panel background. Accepts custom `buttons`.

```lua
modal.styled("status", {
    title = "System Status",
    body = "All systems operational.",
    widthPercent = 35,
})
```

## Core Function

### `open(id, opts)`

Full control over modal configuration. All convenience functions call this internally.

```lua
modal.open("my_modal", {
    title = "Custom Modal",
    body = "Some text above the content.",
    content = function(innerWidth)
        ImGui.Text("Arbitrary ImGui here")
    end,
    buttons = {
        { label = "Save", style = "active", onClick = function() save() end },
        { label = "Cancel", style = "inactive" },
    },
})
```

### `close(id)`

Close a modal programmatically.

### `isOpen(id)`

Returns `true` if the modal is currently open.

## Options Reference

### Modal Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| title | string | id | Window title (or centered heading in styled mode) |
| body | string | nil | Text rendered above content callback |
| content | function | nil | Callback `function(innerWidth)` for custom ImGui |
| buttons | table[] | varies | Button definitions (see below) |
| widthPercent | number | 33 | Modal width as % of screen width |
| heightPercent | number | nil | Fixed height as % of screen height (nil = auto) |
| maxHeightPercent | number | 50 | Maximum height as % of screen height |
| paddingPercent | number | nil | Inner padding as % of screen size |
| styled | boolean | false | Centered title + panel background mode |
| panelBg | table | {0.65, 0.7, 1.0, 0.0225} | Panel background RGBA (styled mode only) |

### Confirm-Specific Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| onConfirm | function | - | Callback when confirmed |
| holdToConfirm | boolean | false | Require hold instead of click |
| holdDuration | number | 1.5 | Hold duration in seconds |

### Button Definition

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| label | string | - | Button text |
| icon | string | nil | IconGlyphs key (icon-only button) |
| style | string | "inactive" | "active", "inactive", "danger", "warning" |
| onClick | function | nil | Click callback |
| onHold | function | nil | Hold callback (makes it a HoldButton) |
| holdDuration | number | 2.0 | Hold duration in seconds |
| progressDisplay | string | nil | "overlay", "replace", "external" |
| closesModal | boolean | true | Set false to keep modal open after click/hold |
| weight | number | nil | Relative width in ButtonRow |
| disabled | boolean | false | Grey out and disable interaction |

## Sizing Examples

### Dynamic (default)

Auto-height, 33% width, grows to fit content:

```lua
modal.info("dynamic", { title = "Dynamic", body = "Grows to fit." })
```

### Fixed Dimensions

```lua
modal.open("fixed", {
    title = "Fixed Size",
    body = "50% wide, 35% tall",
    widthPercent = 50,
    heightPercent = 35,
    buttons = { { label = "Close", style = "inactive" } },
})
```

### With Padding

```lua
modal.info("padded", {
    title = "Padded",
    body = "Extra breathing room around content.",
    widthPercent = 40,
    paddingPercent = 3,
})
```

## Hold-to-Confirm

### Via Convenience Function

```lua
modal.confirm("danger_action", {
    title = "Reset All Settings",
    body = "Hold to confirm reset.",
    holdToConfirm = true,
    holdDuration = 2.0,
    onConfirm = function() resetAll() end,
})
```

### Via Custom Buttons

```lua
modal.open("custom_hold", {
    title = "Delete Preset",
    body = "Hold the delete button to confirm.",
    buttons = {
        { label = "  Hold to Delete  ", style = "danger",
          onHold = function() deletePreset() end,
          holdDuration = 1.5, progressDisplay = "overlay" },
        { label = "Cancel", style = "inactive" },
    },
})
```

## Styled Modals

The styled variant hides the ImGui title bar and renders a centered title with body/content inside a panel background.

```lua
modal.styled("about", {
    title = "About My Mod",
    body = "Version 2.0\nBuilt with WindowUtils.",
    widthPercent = 35,
})
```

### Styled with Content Callback

```lua
modal.styled("status", {
    title = "System Status",
    widthPercent = 35,
    content = function(innerWidth)
        controls.ProgressBar(0.9, innerWidth, 0, "90%", "success")
    end,
    buttons = {
        { label = "Refresh", style = "active", closesModal = false,
          onClick = function() refresh() end },
        { label = "Close", style = "inactive" },
    },
})
```

### Styled with Hold-to-Confirm

```lua
modal.confirm("styled_delete", {
    title = "Delete Everything",
    body = "This action is irreversible.",
    styled = true,
    widthPercent = 35,
    holdToConfirm = true,
    holdDuration = 2.0,
    onConfirm = function() deleteAll() end,
})
```

### Custom Panel Background

```lua
modal.styled("custom_bg", {
    title = "Custom Colors",
    body = "Green-tinted panel background.",
    widthPercent = 35,
    panelBg = { 0.2, 0.8, 0.5, 0.06 },
})
```

## Changelog Preset

A built-in preset for displaying version history with a sidebar version list and scrollable changes panel.

### Basic Usage

```lua
modal.changelog("my_changelog", {
    title = "Changelog",
    versions = {
        { version = "2.0.0", date = "2026-04-01", changes = {
            "Added new feature X",
            "Fixed bug Y",
            "Improved performance of Z",
        }},
        { version = "1.0.0", date = "2026-01-15", changes = {
            "Initial release",
        }},
    },
})
```

Versions are displayed in array order (put newest first). Each version entry has:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| version | string | yes | Version label shown in sidebar |
| date | string | no | Date shown next to version header |
| changes | string[] | yes | Array of change descriptions (rendered as bullet points) |

### Changelog Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| title | string | "Changelog" | Modal title |
| versions | table[] | {} | Array of version entries |
| widthPercent | number | 30 | Modal width |
| heightPercent | number | 75 | Modal height (fixed) |
| maxHeightPercent | number | 80 | Max height cap |
| buttons | table[] | Close button | Custom buttons |

### Loading from JSON

```lua
local file = io.open("data/changelog.json", "r")
if file then
    local versions = json.decode(file:read("*a"))
    file:close()
    modal.changelog("my_changelog", {
        title = "Changelog",
        versions = versions,
    })
end
```

JSON format:
```json
[
    {
        "version": "2.0.0",
        "date": "2026-04-01",
        "changes": ["Added feature X", "Fixed bug Y"]
    }
]
```
