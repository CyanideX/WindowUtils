------------------------------------------------------
-- Echo Position List Sample
-- Reference implementation showing how to use WindowUtils Lists module
-- to replicate Echo's saved position list with edit/tangent modes.
-- This file is NOT a runnable mod. It's a reference for the Echo migration.
------------------------------------------------------

-- This sample assumes:
--   local wu = GetMod("WindowUtils")
--   local controls = wu.Controls
--   local styles = wu.Styles
--   local lists = wu.Lists

------------------------------------------------------
-- State (create once, persist across frames)
------------------------------------------------------

local positions = {
    { label = "Start",    x = 100.5,  y = 200.3,  z = 50.0,  yaw = 45,  tilt = 0,   roll = 0,   fov = 70, rollRotations = 0, tangentStrength = 1.0, tangentBias = 0.0, tangentAsymmetry = 0.0, boundaryAngle = 0.0 },
    { label = "Bridge",   x = -340.2, y = 180.7,  z = 120.5, yaw = 90,  tilt = -5,  roll = 10,  fov = 80, rollRotations = 0, tangentStrength = 1.0, tangentBias = 0.0, tangentAsymmetry = 0.0, boundaryAngle = 0.0 },
    -- ... more positions
}
local listState = {}
local dragStates = {}
local editMode = false
local curveEditor = false
local relativeMode = false
local showValues = false

------------------------------------------------------
-- Renderer (called per-item by lists.render)
------------------------------------------------------

local function positionRenderer(item, index, state)
    local isActive = state.activeIndex == index
    local useDisabled = state.activeIndex ~= nil and state.activeIndex ~= index
    local spacing = ImGui.GetStyle().ItemSpacing.x

    if not dragStates[index] then dragStates[index] = {} end
    local ds = dragStates[index]
    if not ds.row2 then ds.row2 = {} end
    if not ds.row2roll then ds.row2roll = {} end
    if not ds.row3 then ds.row3 = {} end
    if not ds.row4 then ds.row4 = {} end

    -- Row 1: Load, Update(hold, external), Delete(hold, external), then label or progress
    local buttonsStartX = ImGui.GetCursorPosX()

    if useDisabled then
        ImGui.Button(IconGlyphs.Upload .. "##load_" .. index, 0, 0)
        ImGui.SameLine()
        ImGui.Button(IconGlyphs.Refresh .. "##upd_" .. index, 0, 0)
        ImGui.SameLine()
        ImGui.Button(IconGlyphs.TrashCanOutline .. "##del_" .. index, 0, 0)
    else
        if ImGui.Button(IconGlyphs.Upload .. "##load_" .. index, 0, 0) then
            state.focusIndex = index
            -- Teleport/load logic here
        end
        ImGui.SameLine()
        controls.HoldButton("lst_upd_" .. index, IconGlyphs.Refresh, {
            duration = 1.0, style = "inactive", progressDisplay = "external",
            onHold = function()
                -- Update position from current camera
            end,
            onClick = function() end,
        })
        ImGui.SameLine()
        controls.HoldButton("lst_del_" .. index, IconGlyphs.TrashCanOutline, {
            duration = 1.0, style = "danger", progressDisplay = "external",
            onHold = function()
                -- Mark for deferred deletion (don't table.remove inside renderer)
                pendingDelete = index
            end,
            onClick = function() end,
        })
    end

    ImGui.SameLine()
    local buttonsEndX = ImGui.GetCursorPosX()
    local buttonsWidth = buttonsEndX - buttonsStartX - spacing

    -- Hold progress or position label
    local showedProgress = false
    if not useDisabled then
        showedProgress = controls.ShowFirstActiveHoldProgress(
            { "lst_upd_" .. index, "lst_del_" .. index },
            ImGui.GetContentRegionAvail(), "danger"
        )
    end
    if not showedProgress then
        local posLabel = string.format("%d: x=%.1f, y=%.1f, z=%.1f", index, item.x, item.y, item.z)
        if useDisabled then styles.PushDragDisabled() else styles.PushOutlined() end
        ImGui.SetNextItemWidth(ImGui.GetContentRegionAvail())
        ImGui.DragFloat("##lbl_" .. index, 0, 0, 0, 0, posLabel)
        if useDisabled then styles.PopDragDisabled() else styles.PopOutlined() end
    end

    -- Edit mode rows
    if editMode then
        local disabledMode = useDisabled and true or nil
        local function lbl(name) if showValues then return nil end return name end

        -- Row 2: ACTIVE/spacer, Roll(DragInt), X, Y, Z
        if isActive then
            styles.PushButton("active")
            ImGui.Button("ACTIVE", buttonsWidth, 0)
            styles.PopButton("active")
        else
            ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(0, 0, 0, 0))
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(0, 0, 0, 0))
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(0, 0, 0, 0))
            ImGui.Button("##spacer_" .. index, buttonsWidth, 0)
            ImGui.PopStyleColor(3)
        end
        ImGui.SameLine()

        local row2Avail = ImGui.GetContentRegionAvail()
        local row2W = math.floor((row2Avail - spacing * 3) / 4)

        -- Roll rotations (disabled on first item)
        if index == 1 then
            ImGui.BeginDisabled(true)
            ImGui.SetNextItemWidth(row2W)
            ImGui.DragInt("##rollRot_" .. index, 0, 0.1, 0, 0, "--")
            ImGui.EndDisabled()
        else
            local _, rollChanged = controls.DragIntRow(nil, "ri_" .. index, {
                { value = item.rollRotations or 0, label = lbl("Roll"), default = 0, min = -10, max = 10, width = row2W },
            }, { speed = 0.1, state = ds.row2roll, disabled = disabledMode })
            if rollChanged then item.rollRotations = _[1] end
        end
        ImGui.SameLine()

        -- XYZ (global or delta mode)
        local xyzDrags
        if relativeMode then
            xyzDrags = {
                { value = 0, color = styles.dragColors.x, label = lbl("X"), min = -2000, max = 2000, default = 0,
                  onChange = function(_, delta) item.x = item.x + delta end },
                { value = 0, color = styles.dragColors.y, label = lbl("Y"), min = -2000, max = 2000, default = 0,
                  onChange = function(_, delta) item.y = item.y + delta end },
                { value = 0, color = styles.dragColors.z, label = lbl("Z"), min = -2000, max = 2000, default = 0,
                  onChange = function(_, delta) item.z = item.z + delta end },
            }
        else
            xyzDrags = {
                { value = item.x, color = styles.dragColors.x, label = lbl("X"), min = -2000, max = 2000, default = 0 },
                { value = item.y, color = styles.dragColors.y, label = lbl("Y"), min = -2000, max = 2000, default = 0 },
                { value = item.z, color = styles.dragColors.z, label = lbl("Z"), min = -2000, max = 2000, default = 0 },
            }
        end

        local xyzVals, xyzChanged = controls.DragFloatRow(nil, "r2_" .. index, xyzDrags, {
            speed = 0.1, state = ds.row2, disabled = disabledMode,
            mode = relativeMode and "delta" or nil,
        })
        if xyzChanged and not relativeMode then
            item.x = xyzVals[1]; item.y = xyzVals[2]; item.z = xyzVals[3]
        end

        -- Row 3: spacer, FOV, Yaw, Tilt, Roll
        ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(0, 0, 0, 0))
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(0, 0, 0, 0))
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(0, 0, 0, 0))
        ImGui.Button("##sp3_" .. index, buttonsWidth, 0)
        ImGui.PopStyleColor(3)
        ImGui.SameLine()

        local row3Vals, row3Changed = controls.DragFloatRow(nil, "r3_" .. index, {
            { value = item.fov or 70, label = lbl("FOV"), min = 20, max = 130, default = 70 },
            { value = item.yaw or 0, label = lbl("Yaw"), default = 0 },
            { value = item.tilt or 0, label = lbl("Tilt"), min = -90, max = 90, default = 0 },
            { value = item.roll or 0, label = lbl("Roll"), min = -360, max = 360, default = 0 },
        }, { speed = 0.1, state = ds.row3, disabled = disabledMode })
        if row3Changed then
            item.fov = row3Vals[1]; item.yaw = row3Vals[2]; item.tilt = row3Vals[3]; item.roll = row3Vals[4]
        end

        -- Row 4: tangent controls (curve editor mode)
        if curveEditor then
            ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(0, 0, 0, 0))
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(0, 0, 0, 0))
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(0, 0, 0, 0))
            ImGui.Button("##sp4_" .. index, buttonsWidth, 0)
            ImGui.PopStyleColor(3)
            ImGui.SameLine()

            local isBoundary = index == 1 or index == #positions
            local row4Drags = {}
            if isBoundary then
                table.insert(row4Drags, { value = item.boundaryAngle or 0, label = lbl("Angle"), min = -180, max = 180, default = 0, speed = 1.0 })
            else
                table.insert(row4Drags, { value = 0, disabled = true, label = "--" })
            end
            table.insert(row4Drags, { value = item.tangentStrength or 1.0, label = lbl("Str"), min = 0, max = 10, default = 1.0, format = "%.2f" })
            table.insert(row4Drags, { value = item.tangentBias or 0.0, label = lbl("Bias"), min = -1, max = 1, default = 0.0, format = "%.2f" })
            table.insert(row4Drags, { value = item.tangentAsymmetry or 0.0, label = lbl("Asym"), min = -1, max = 1, default = 0.0, format = "%.2f" })

            local row4Vals, row4Changed = controls.DragFloatRow(nil, "r4_" .. index, row4Drags, {
                speed = 0.1, state = ds.row4, disabled = disabledMode,
            })
            if row4Changed then
                if isBoundary then
                    item.boundaryAngle = row4Vals[1]; item.tangentStrength = row4Vals[2]
                    item.tangentBias = row4Vals[3]; item.tangentAsymmetry = row4Vals[4]
                else
                    item.tangentStrength = row4Vals[1]; item.tangentBias = row4Vals[2]; item.tangentAsymmetry = row4Vals[3]
                end
            end
        end
    end
end

------------------------------------------------------
-- Usage (inside onDraw)
------------------------------------------------------

-- lists.render(positions, positionRenderer, listState, {
--     showCount = true,
--     reorderable = true,
--     placeholder = "No saved positions.",
--     onReorder = function(from, to)
--         local moved = table.remove(dragStates, from)
--         table.insert(dragStates, to, moved or {})
--     end,
-- })
--
-- -- Handle deferred deletion after render
-- if pendingDelete then
--     table.remove(positions, pendingDelete)
--     table.remove(dragStates, pendingDelete)
--     if listState.focusIndex and listState.focusIndex > #positions then
--         listState.focusIndex = #positions > 0 and #positions or nil
--     end
--     pendingDelete = nil
-- end
