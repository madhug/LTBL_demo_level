CiderRunMode = {};CiderRunMode.runmode = true;CiderRunMode.assertImage = true;require "CiderDebugger";-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------
--Debug the smart way with Cider!
--start coding and press the debug button


display.setStatusBar( display.HiddenStatusBar )

local director = require ("director")
local mainGroup = display.newGroup ()

local function main()
-- Adds main function
    mainGroup:insert(director.directorView)
-- Adds the group from director
    director:changeScene("Menu")
-- Change the scene, no effects
    return true
end

main()