# WindowUtils Docking Module Plan

## Status: READY FOR IMPLEMENTATION

## Key Constraint
**ImGui's native docking API (DockSpace, DockBuilder, etc.) is NOT available in CET's ImGui binding.** This requires building a custom docking system using available ImGui primitives.

---

## Design Decisions

| Question | Decision | Rationale |
|----------|----------|-----------|
| Scope | WindowUtils-managed windows only | Simpler, safer; can extend via `overrideAllWindows` later |
| Tab grouping | **API only** (no drag-to-tab UX) | For single mod with multiple windows; cleaner UX |
| Anchoring | Auto-lock adjacent/touching windows | Natural behavior when windows snap together |
| Edge docking | Snap to screen edges | Standard docking UX |
| Persistence | Yes, saved in settings.json | Layouts should survive game restarts |

---

## Architecture

### New Module: `modules/docking.lua`

```lua
-- Core data structures
local dockedWindows = {}   -- {windowName -> "left"|"right"|"top"|"bottom"}
local windowLocks = {}     -- {windowName -> {left = "OtherWindow", right = nil, ...}}
local tabGroups = {}       -- {groupId -> {windows = {}, activeTab = 1, bounds = {}}}
local dockZones = {}       -- Computed screen edge zones
local currentDropTarget = nil  -- Highlighted zone during drag

-- Key functions
docking.init()                          -- Initialize dock zones from screen size
docking.update(windowName, bounds)      -- Check zones during drag, update dropTarget
docking.onDragEnd(windowName, bounds)   -- Handle dock/lock on release
docking.onDragStart(windowName)         -- Check Ctrl modifier for unlock
docking.checkAdjacency(windowName, bounds) -- Detect touching windows after snap
docking.propagateDrag(windowName, delta)   -- Move all locked windows together
docking.renderOverlays()                -- Draw dock zone indicators
docking.renderTabBars()                 -- Draw tab bars for all groups
docking.save() / docking.load()         -- Persistence
```

---

## Phase 1: Edge Docking (Minimal Viable Feature)

### Behavior
- Drag window near screen edge -> highlight dock zone
- Release in zone -> snap to edge with configured margin
- Edge-docked windows remember their edge binding

### Implementation Steps

1. **Add docking settings** to `settings.lua`:
   ```lua
   dockingEnabled = true,
   dockZoneSize = 40,          -- Pixels from edge to trigger dock
   dockMargin = 10,            -- Margin from edge when docked
   dockShowIndicators = true,  -- Show visual dock zone indicators
   ```

2. **Create `modules/docking.lua`**:
   - Define dock zones (rectangles at screen edges)
   - `checkDockZone(x, y)` - returns zone if cursor is in one
   - `snapToEdge(windowName, zone)` - position window at edge
   - State: `dockedWindows = {windowName -> edge}`

3. **Hook into `core/core.lua`**:
   - In drag detection, call `docking.update(windowName, bounds)`
   - On drag end, call `docking.onDragEnd(windowName, bounds)`
   - Docked windows skip normal grid snapping

4. **Render overlays in `ui.lua`**:
   - During drag, highlight active dock zone
   - Use `ImGui.GetBackgroundDrawList()` for overlays

---

## Phase 2: Adjacent Window Locking

### Behavior
- When two windows snap together (edges touching), they become "locked"
- Locked windows move together when one is dragged
- Dragging with modifier key (Ctrl) unlocks and moves only that window
- Visual indicator shows locked state (subtle connector line?)

### Implementation Steps

1. **Detect adjacency on snap**:
   - After grid snap, check if window edges align with other windows
   - Tolerance: within 1-2 pixels = "touching"
   - Record lock relationship: `{windowA, windowB, side}`

2. **Lock data structure**:
   ```lua
   windowLocks = {
       ["WindowA"] = {
           right = "WindowB",  -- WindowB is to the right of A
       },
       ["WindowB"] = {
           left = "WindowA",   -- WindowA is to the left of B
       }
   }
   ```

3. **Drag propagation**:
   - When locked window is dragged, move all connected windows
   - Build "lock group" (all transitively connected windows)
   - Apply same delta to entire group

4. **Unlock behavior**:
   - **Ctrl+drag** = drag only this window, break all locks for this window
   - Dragging naturally separates windows = break that specific lock
   - Note: Ctrl modifier detected via `ImGui.IsKeyDown(ImGuiKey.LeftCtrl)`

5. **Add settings**:
   ```lua
   dockLockAdjacent = true,     -- Auto-lock touching windows
   dockLockThreshold = 2,       -- Pixels tolerance for "touching"
   ```

---

## Phase 3: Tabbed Groups (API Only)

### Behavior
- Mods call API to group their windows
- Tab bar appears at top of group
- Click tab to switch visible window
- User cannot create tab groups via drag (only mods via API)

### Implementation Steps

1. **Group data structure**:
   ```lua
   tabGroups = {
       ["mymod_group1"] = {
           windows = {"MyMod_Main", "MyMod_Settings", "MyMod_Debug"},
           activeTab = 1,
           bounds = {x, y, width, height}
       }
   }
   ```

2. **Tab bar rendering**:
   - Custom tab bar using `ImGui.BeginChild()` + clickable text
   - Track active tab per group
   - Group assumes size of largest window

3. **Window visibility**:
   - Only active tab's window is rendered
   - Other windows in group are hidden but state maintained

4. **API for mods**:
   ```lua
   docking.createTabGroup(groupId, windowNames)
   docking.addToTabGroup(groupId, windowName)
   docking.removeFromTabGroup(windowName)
   docking.setActiveTab(groupId, windowName)
   docking.destroyTabGroup(groupId)
   ```

---

## Files to Modify

| File | Changes |
|------|---------|
| `modules/docking.lua` | **CREATE** - Core docking logic (~350 lines) |
| `core/settings.lua` | Add: `dockingEnabled`, `dockZoneSize`, `dockMargin`, `dockShowIndicators`, `dockLockAdjacent`, `dockLockThreshold` |
| `core/core.lua` | Call `docking.update()` during drag, `docking.onDragEnd()` on release, check Ctrl modifier |
| `ui/ui.lua` | Add "Docking" settings section, call `docking.renderOverlays()` and `docking.renderTabBars()` |
| `modules/api.lua` | Expose edge docking, window locking, and tab group APIs |
| `init.lua` | Require and initialize docking module |

---

## API Surface (for other mods)

```lua
-- Edge docking
api.DockToEdge(windowName, edge)     -- "left", "right", "top", "bottom"
api.UndockFromEdge(windowName)
api.IsDockedToEdge(windowName)
api.GetDockedEdge(windowName)        -- Returns edge or nil

-- Window locking (adjacent windows)
api.LockWindows(windowA, windowB, side)  -- Manual lock
api.UnlockWindow(windowName)             -- Break all locks for window
api.GetLockedWindows(windowName)         -- Get all windows locked to this one
api.IsLocked(windowName)

-- Tab groups (API only - for mods with multiple windows)
api.CreateTabGroup(groupId, windowNames) -- Create group with initial windows
api.AddToTabGroup(groupId, windowName)
api.RemoveFromTabGroup(windowName)
api.SetActiveTab(groupId, windowName)
api.GetTabGroupWindows(groupId)
api.DestroyTabGroup(groupId)

-- Settings access (existing pattern)
-- s = api.GetSettings()
-- s.dockingEnabled = true
-- s.dockLockAdjacent = true
```

---

## Visual Indicators

### Dock Zone Overlay (during drag)
- Semi-transparent colored rectangles at screen edges
- Highlight when cursor enters zone
- Colors match existing grid theme

### Tab Bar
- Horizontal bar at top of grouped windows
- Active tab highlighted
- Hover effect on inactive tabs
- Small "x" close button per tab

---

## Persistence

Dock state saved in `data/settings.json`:
```json
{
  "dockState": {
    "dockedWindows": {"WindowA": "left", "WindowB": "top"},
    "tabGroups": [
      {"id": "group1", "windows": ["Window1", "Window2"], "activeTab": 0}
    ],
    "anchors": {"WindowC": {"target": "WindowD", "side": "right"}}
  }
}
```

---

## Implementation Order

1. **Phase 1**: Edge docking
   - Settings additions (`dockingEnabled`, `dockZoneSize`, `dockMargin`, `dockShowIndicators`)
   - Create `modules/docking.lua` skeleton
   - Dock zone detection + visual indicators
   - Edge snapping on drop
   - Persistence of docked state

2. **Phase 2**: Adjacent window locking
   - Add `dockLockAdjacent`, `dockLockThreshold` settings
   - Adjacency detection after snap
   - Lock data structure + persistence
   - Drag propagation for locked groups
   - Ctrl+drag unlock behavior
   - Visual lock indicators (optional)

3. **Phase 3**: Tabbed groups (API only)
   - Tab group data structure
   - `createTabGroup()`, `addToTabGroup()`, `setActiveTab()`, etc.
   - Tab bar rendering
   - Window visibility management
   - API exposure in `api.lua`
