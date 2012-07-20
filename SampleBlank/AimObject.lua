module(..., package.seeall);



function newAimObject(x,y)
    
    local aim = display.newCircle(x,y,20)
    aim:setFillColor(0,255,255,255)
    physics.addBody( aim,"static", { density=0, friction=0, bounce=0 ,radius=20})
    aim.type = "aimObj"
    
    return aim
end