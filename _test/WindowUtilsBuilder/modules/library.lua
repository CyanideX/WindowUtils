------------------------------------------------------
-- WindowUtils Builder - Element Library
-- Categorized control catalog with search
------------------------------------------------------

local element_defs = require("modules/element_defs")
local exportMod = require("modules/export")

local library = {}

local controls, styles, splitter, searchMod, notify
local searchState = nil
local selectedCategory = 1

--------------------------------------------------------------------------------
-- Settings panel state
--------------------------------------------------------------------------------

local settingsOpen = false

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

function library.init(wu)
    controls = wu.Controls
    styles = wu.Styles
    splitter = wu.Splitter
    searchMod = wu.Search
    notify = wu.Notify

    searchState = searchMod.new("builder_library")
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------

function library.draw(project)
    if not controls then return end

    ImGui.SetNextWindowSize(280, 500, ImGuiCond.FirstUseEver)
    if ImGui.Begin("Element Library") then
        -- Search bar
        controls.SearchBar(searchState, { cols = 12 })

        ImGui.Spacing()

        local categories = element_defs.getCategories()

        splitter.horizontal("builder_library_split", function()
            -- Category sidebar
            for i, cat in ipairs(categories) do
                if controls.ToggleButton(cat.name, selectedCategory == i, -1, 0) then
                    selectedCategory = i
                end
            end
        end, function()
            -- Element type list
            local cat = categories[selectedCategory]
            if cat then
                for _, typeName in ipairs(cat.types) do
                    if searchState:matches(typeName, typeName) then
                        if controls.Button(typeName, "inactive", -1, 0) then
                            local newEl = project.addElement(typeName)
                            if newEl then
                                -- If a container is selected, reparent into its target zone
                                local sel = project.getSelected()
                                if sel and sel.zones then
                                    local zoneIdx = project.getSelectedZone()
                                    project.reparentElement(newEl.id, sel.id, zoneIdx)
                                end
                                if notify then
                                    notify.info("Added " .. typeName)
                                end
                            end
                        end
                    end
                end
            end
        end, { defaultPct = 0.35, minPct = 0.2, maxPct = 0.5 })

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        -- Collapsible Project Settings
        if ImGui.CollapsingHeader("Project Settings") then
            local config = project.getConfig()

            -- Window title
            ImGui.Text("Window Title")
            ImGui.SetNextItemWidth(-1)
            local title, titleChanged = ImGui.InputText("##proj_title", config.windowTitle or "", 256)
            if titleChanged then
                project.setConfig("windowTitle", title)
            end

            -- Mod folder
            ImGui.Text("Mod Folder")
            ImGui.SetNextItemWidth(-1)
            local folder, folderChanged = ImGui.InputText("##proj_folder", config.modFolderName or "", 256)
            if folderChanged then
                project.setConfig("modFolderName", folder)
            end

            -- Width
            ImGui.Text("Window Width")
            ImGui.SetNextItemWidth(-1)
            local w, wChanged = ImGui.DragInt("##proj_width", config.windowWidth or 400, 1, 100, 4000, "%d")
            if wChanged then
                project.setConfig("windowWidth", w)
            end

            -- Height
            ImGui.Text("Window Height")
            ImGui.SetNextItemWidth(-1)
            local h, hChanged = ImGui.DragInt("##proj_height", config.windowHeight or 300, 1, 100, 4000, "%d")
            if hChanged then
                project.setConfig("windowHeight", h)
            end
        end

        ImGui.Spacing()

        -- Export button
        if controls.Button("Export", "active", -1, 0) then
            exportMod.write(project, notify)
        end
    end
    ImGui.End()
end

return library
