module(..., package.seeall);

function new()
    local physics = require ("physics")
    physics.start(true)
    physics.setGravity(0, 0)
    
    local localGroup = display.newGroup()
    
    local _mirrorDock = require("MirrorDock")
    local _light = require("Light")
    local mirrorDock = _mirrorDock.newMirrorDock()
    local light = _light.newLight(80,240,80,80)

    local start = display.newText( "Start Light!", 40, 280, native.systemFont, 16 )
    start:setTextColor(255, 255, 255)
    local function pressStartLight (event)
        if event.phase == "ended" then
            _light:drawLight()
            print("Light Started")
        end
    end
    start:addEventListener ("touch", pressStartLight)
    
    
    --[[
    local line=display.newLine(0,0,200,200)
    r = math.random (0, 255)
    g = math.random ( 0, 255)
    b = math.random (0, 255 )
    line:setColor(r,g,b)
    line:rotate( 40 )
    
    --(Copy paste friendly)


    -- Try swiping mouse over simulator to produce random colored lines

    -- Starts physics

    
    
    physics.setGravity(10, 0)

    -- Ball rolls on Line

    local ball = display.newCircle( 0, 0, 25)
    ball:setFillColor(0, 255, 0)
    ball.x = display.contentHeight/12
    ball.y = display.contentWidth/4

    physics.addBody(ball, {bounce=0.3, radius = 25, friction=0.5})


    -- Draw a line

    local i = 1
    local tempLine
    local ractgangle_hit = {}
    local prevX , prevY
    local function runTouch(event)
        if(event.phase=="began") then
            if(tempLine==nil) then
                tempLine=display.newLine(event.x, event.y, event.x, event.y)

                -- Random Colors for line

                r = math.random (0, 255)
                g = math.random ( 0, 255)
                b = math.random (0, 255 )
                tempLine:setColor(r,g, b)

                prevX = event.x
                prevY = event.y
            end
        elseif(event.phase=="moved") then
            tempLine:append(event.x,event.y-2)
            tempLine.width=tempLine.width+0.9
            ractgangle_hit[i] = display.newLine(prevX, prevY, event.x, event.y)
            ractgangle_hit[i]:setColor(r,g, b)
            ractgangle_hit[i].width = 5

            -- Creates physic joints for line (Turn on draw mode to see the effects) 

            local Width = ractgangle_hit[i].width * 0.6
            local Height = ractgangle_hit[i].height * 0.2

            -- Physic body for the line shape

            local lineShape = {-Width,-Height,Width,-Height,Width,Height,-Width,Height}

            physics.addBody(ractgangle_hit[i], "static", { bounce = -1, density=0.3, friction=0.7, shape = lineShape})
            prevX = event.x
            prevY = event.y
        i = i + 1
        elseif(event.phase=="ended") then
            tempLine.parent.remove(tempLine)
            tempLine=nil
        end
    end
    Runtime:addEventListener("touch", runTouch)
    --]]
    
    
    return localGroup
end