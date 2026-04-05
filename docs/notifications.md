# Notifications

Screen-edge toast notifications with level-based styling, auto-dismiss, and fade-out.

## Quick Start

```lua
local wu = GetMod("WindowUtils")
local notify = wu.Notify

notify.info("Settings loaded")
notify.success("Preset saved!")
notify.warn("Missing configuration key")
notify.error("Failed to connect")
```

Notifications appear at the configured screen edge, auto-dismiss after a timeout, and fade out smoothly.

## API Reference

### `info(message, opts?)`

Show an info notification (blue icon).

### `success(message, opts?)`

Show a success notification (green icon).

### `warn(message, opts?)`

Show a warning notification (yellow icon).

### `error(message, opts?)`

Show an error notification (red icon).

### `show(message, level?, opts?)`

Show a notification with a specific level.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| message | string |  - | Notification text |
| level | string | "info" | "info", "success", "warn", "error" |
| opts.ttl | number | 3.0 | Seconds before fade starts |
| opts.fadeOut | number | 0.5 | Fade-out duration in seconds |

```lua
notify.show("Custom timing", "success", { ttl = 5.0, fadeOut = 1.0 })
```

### `configure(opts)`

Change notification defaults.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| position | string | "topRight" | "topRight", "topLeft", "bottomRight", "bottomLeft" |
| maxVisible | number | 5 | Maximum visible toasts |
| ttl | number | 3.0 | Default time-to-live (seconds) |
| fadeOut | number | 0.5 | Default fade duration (seconds) |
| offsetX | number | 20 | Pixels from screen edge (horizontal) |
| offsetY | number | 20 | Pixels from screen edge (vertical) |
| toastWidth | number | 300 | Toast window width |
| toastPadding | number | 8 | Internal padding |
| spacing | number | 6 | Vertical gap between toasts |
| windowRounding | number | 4.0 | Corner rounding |
| windowBorderSize | number | 1.0 | Border thickness |

```lua
notify.configure({
    position = "bottomRight",
    maxVisible = 3,
    ttl = 5.0,
    toastWidth = 350,
})
```

### `clear()`

Remove all pending notifications immediately.

### `count()`

**Returns:** `number`  - current notification count in the queue

### `draw()`

Render all active notifications. Called automatically each frame by WindowUtils  - you do not need to call this yourself.

## Examples

### Per-notification Timing

```lua
-- Quick flash
notify.info("Copied!", { ttl = 1.0, fadeOut = 0.3 })

-- Long-lasting warning
notify.warn("Connection unstable", { ttl = 10.0, fadeOut = 2.0 })
```

### Position Configuration

```lua
-- Move to bottom-left corner
notify.configure({ position = "bottomLeft", offsetX = 40 })
```

## Icons

Notifications display level-appropriate icons when IconGlyphs is available:

| Level | Glyph | Fallback |
|-------|-------|----------|
| info | InformationOutline | `i` |
| success | CheckCircleOutline | `ok` |
| warn | AlertOutline | `!` |
| error | AlertOctagonOutline | `X` |
