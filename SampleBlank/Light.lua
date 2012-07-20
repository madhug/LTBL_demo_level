module(..., package.seeall);

local lightX,lightY
local lightBall
local preX, preY
local lightLine

function newLight(_lightX,_lightY,aimX,aimY) 
    lightX = _lightX
    lightY = _lightY
    local lightSource = display.newCircle( _lightX, _lightY, 20 )
    lightSource:setFillColor( 255, 255, 0, 255 )

    local _aim = require("AimObject")
    local aim = _aim.newAimObject(aimX,aimY)
    
    return lightSource
end

function drawLight()
    local lightDirectionX = 500
    local lightDirectionY = 0
    lightBall = display.newCircle(lightX, lightY, 4)
    lightBall:setFillColor(255, 255, 0, 255)
    physics.addBody( lightBall, { density=0, friction=1, bounce=1 ,radius=1})
    lightBall:setLinearVelocity(lightDirectionX, lightDirectionY)     
    lightBall:addEventListener( "collision", lightCollideAim)
    
    preX = lightX
    preY = lightY
    timer.performWithDelay(10, drawLines, 0)
end

function drawLines()
    --print("light ball X = ",lightBall.x,", Y = ",lightBall.y)
    if(lightLine==nil) then
        lightLine=display.newLine(preX, preY, lightBall.x, lightBall.y)
        lightLine:setColor(255,0,0)
    else
        lightLine:append(lightBall.x,lightBall.y)
        lightLine.width= 5
        preX = lightBall.x
        preY = lightBall.y
    end 
end

function lightCollideAim(event)
    if ( event.phase == "began" ) then
        if (event.other.type == "aimObj") then
            lightBall:setLinearVelocity(0, 0)
            print("Collide, Win")
        end
    end
end

