module(...,package.seeall)

function newMirrorDock()
    --local mirrorGroup = diplay.newGroup()
    local planeMirror = display.newRect(400, 70, 20, 80)
    planeMirror.strokeWidth = 3
    planeMirror:setFillColor(140, 140, 140)
    planeMirror:setStrokeColor(180, 180, 180)
    planeMirror:rotate( 30 )
           
    physics.addBody( planeMirror, "static", { density=0, friction=1, bounce=1} )
    planeMirror:setLinearVelocity(lightDirectionX, lightDirectionY)

    local label = display.newText( "Select Mirror", 360, 10, native.systemFont, 16 )
    label:setTextColor(0, 255, 255)
    local dockBg = display.newRect(350,0,130,320 )
    
    --physics.addBody(planeMirror,{density=0,bounce=0.3,friction=0.5} )
    
    local function dragMirror (event)
        if event.phase == "started" then
            display.getCurrentStage():setFocus(nil)
            planeMirror.isFocus = true
        end
        if event.phase == "moved" then
            planeMirror.x = event.x
            planeMirror.y = event.y
        end    
        
        if event.phase == "ended" then
            if planeMirror.x >= 350 then
                planeMirror.x = 400
                planeMirror.y = 70
                print("Mirror Restored") 
             end
            print("Mirror Placed") 
        end
    end
    planeMirror:addEventListener ("touch", dragMirror)
    
    
    return planeMirror
end