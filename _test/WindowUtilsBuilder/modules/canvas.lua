------------------------------------------------------
-- WindowUtils Builder - Canvas
-- Live WIP preview window
------------------------------------------------------

local renderer = require("modules/renderer")

local canvas = {}

local controls, styles, dd, notify
local renamingId = nil
local renameBuffer = ""

-- DragDrop state for top-level reordering
local ddState = nil

-- Selection highlight color
local HIGHLIGHT_COLOR = 0xFF44AAFF

-- Context menu state
local contextMenuId = nil

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

function canvas.init(wu)
    controls = wu.Controls
    styles = wu.Styles
    dd = wu.DragDrop
    notify = wu.Notify
    renderer.init(wu)
    ddState = dd.createState()
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------

function canvas.draw(project)
    if not controls then return end

    renderer.setProject(project)

    local config = project.getConfig()
    local windowTitle = config.windowTitle or "My Mod"

    ImGui.SetNextWindowSize(config.windowWidth or 400, config.windowHeight or 300, ImGuiCond.FirstUseEver)
    if ImGui.Begin(windowTitle) then
        local elements = project.getElements()

        -- Collect top-level elements
        local topLevel = {}
        for _, el in ipairs(elements) do
            if el.parentId == nil then
                topLevel[#topLevel + 1] = el
            end
        end

        if #topLevel == 0 then
            ImGui.TextWrapped("Add elements from the Element Library to get started.")
        else
            local selected = project.getSelected()
            local drawList = ImGui.GetWindowDrawList()

            -- Track which element is being dragged
            local draggingIdx = dd.getDraggingIndex(ddState)
            local draggingEl = draggingIdx and topLevel[draggingIdx] or nil
            renderer.setDraggingId(draggingEl and draggingEl.id or nil)

            for i, el in ipairs(topLevel) do
                local ctx = dd.getItemContext(i, ddState)

                if ddState.draggingIndex then
                    dd.drawSeparator(ctx.dropAbove)
                end

                dd.pushItemStyles(ctx)

                ImGui.PushID("canvas_el_" .. el.id)

                -- Inline rename
                if renamingId == el.id then
                    ImGui.SetNextItemWidth(-1)
                    local newName, confirmed = ImGui.InputText("##rename_" .. el.id, renameBuffer, 256, ImGuiInputTextFlags.EnterReturnsTrue)
                    renameBuffer = newName
                    if confirmed or (not ImGui.IsItemActive() and ImGui.IsItemDeactivated and ImGui.IsItemDeactivated()) then
                        if renameBuffer ~= "" then
                            project.setProperty(el.id, "name", renameBuffer)
                        end
                        renamingId = nil
                        renameBuffer = ""
                    end
                else
                    -- Wrap in a group so GetItemRect covers the entire element (including containers)
                    ImGui.BeginGroup()
                    renderer.render(el)
                    ImGui.EndGroup()

                    local hasZones = el.zones ~= nil

                    -- Selection: only for leaf (non-container) top-level elements
                    if not hasZones and ImGui.IsItemClicked(0) then
                        project.setSelected(el.id)
                    end

                    -- Selection highlight (only for leaf elements, containers use zone orange outline)
                    if selected and selected.id == el.id and not hasZones then
                        local minX, minY = ImGui.GetItemRectMin()
                        local maxX, maxY = ImGui.GetItemRectMax()
                        ImGui.ImDrawListAddRect(drawList, minX, minY, maxX, maxY, HIGHLIGHT_COLOR, 0, 0, 2.0)
                    end

                    -- DragDrop reorder
                    local shouldReorder, fromIdx, toIdx = dd.handleDrag(i, #topLevel, ddState)
                    if shouldReorder and fromIdx and toIdx then
                        -- Convert top-level indices to project element indices
                        local fromElIdx = project.getElementIndex(topLevel[fromIdx].id)
                        local toElIdx = project.getElementIndex(topLevel[toIdx].id)
                        if fromElIdx and toElIdx then
                            project.reorderElement(fromElIdx, toElIdx)
                        end
                    end

                    -- Context menu (works for both leaf and container elements)
                    -- For containers, open manually via mouse hit test on right-click,
                    -- but skip if a child element's context menu was opened
                    local ctxId = "##ctx_" .. el.id
                    local childWasRightClicked = renderer.wasChildRightClicked()
                    if hasZones and ImGui.IsMouseClicked(1) and not childWasRightClicked then
                        local cMinX, cMinY = ImGui.GetItemRectMin()
                        local cMaxX, cMaxY = ImGui.GetItemRectMax()
                        local mx, my = ImGui.GetMousePos()
                        if mx >= cMinX and mx <= cMaxX and my >= cMinY and my <= cMaxY then
                            ImGui.OpenPopup(ctxId)
                        end
                    end
                    if ImGui.BeginPopupContextItem(ctxId) then
                        contextMenuId = el.id

                        if ImGui.MenuItem("Rename") then
                            renamingId = el.id
                            renameBuffer = el.name
                        end

                        if ImGui.MenuItem("Duplicate") then
                            local dup = project.duplicateElement(el.id)
                            if dup and notify then
                                notify.info("Duplicated " .. el.name)
                            end
                        end

                        local canMoveUp = i > 1
                        local canMoveDown = i < #topLevel
                        if ImGui.MenuItem("Move Up", "", false, canMoveUp) then
                            project.moveElement(el.id, "up")
                        end
                        if ImGui.MenuItem("Move Down", "", false, canMoveDown) then
                            project.moveElement(el.id, "down")
                        end

                        ImGui.Separator()

                        if ImGui.MenuItem("Delete") then
                            local name = el.name
                            project.removeElement(el.id)
                            renderer.clearState(el.id)
                            if notify then
                                notify.warn("Deleted " .. name)
                            end
                        end

                        ImGui.EndPopup()
                    end
                end

                ImGui.PopID()

                dd.popItemStyles(ctx)

                if ddState.draggingIndex then
                    dd.drawSeparator(ctx.dropBelow)
                end
            end

            dd.updateCursor(ddState)

            -- Consume click on child elements inside containers
            local clickedChild = renderer.getClickedChild()
            if clickedChild then
                project.setSelected(clickedChild)
            end

            -- Consume reparent from renderer
            local reparent = renderer.consumeReparent()
            if reparent then
                project.reparentElement(reparent.elementId, reparent.containerId, reparent.zoneIdx)
            end
        end
    end
    ImGui.End()
end

return canvas
