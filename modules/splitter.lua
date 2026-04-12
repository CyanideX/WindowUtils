------------------------------------------------------
-- WindowUtils - Splitter Aggregator
-- Re-exports all public API from split, toggle, and core sub-modules
------------------------------------------------------

local core = require("modules/splitter/core")
local split = require("modules/splitter/split")
local toggle = require("modules/splitter/toggle")

local splitter = {}

-- Split layouts
splitter.horizontal = split.horizontal
splitter.vertical = split.vertical
splitter.multi = split.multi
splitter.getSplitPct = split.getSplitPct
splitter.setSplitPct = split.setSplitPct
splitter.reset = split.reset
splitter.resetMulti = split.resetMulti

-- Toggle panels
splitter.toggle = toggle.toggle
splitter.setToggle = toggle.setToggle
splitter.getToggle = toggle.getToggle
splitter.getSavedToggle = toggle.getSavedToggle
splitter.setToggleAnimate = toggle.setToggleAnimate
splitter.getToggleAnimate = toggle.getToggleAnimate
splitter.getExpandConstraint = toggle.getExpandConstraint

-- Core utilities
splitter.getMinSize = core.getMinSize
splitter.destroy = core.destroy

-- Aliases
splitter.h = splitter.horizontal
splitter.v = splitter.vertical
splitter.m = splitter.multi
splitter.t = splitter.toggle

return splitter
