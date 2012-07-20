module(..., package.seeall);

function new()
    print("menu loaded")
    
    local localGroup = display.newGroup()
    --local demoLevel = require("DemoLevel")

    local start = display.newText( "Start!", 140, 240, native.systemFont, 16 )
    start:setTextColor(255, 255, 255)
    
    --Add start event listener
    local function pressRed (event)
        if event.phase == "ended" then
            print("Text Pressed")
            director:changeScene("DemoLevel")
            
        end
    end
    start:addEventListener ("touch", pressRed)

    return localGroup
end


