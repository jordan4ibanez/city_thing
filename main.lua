require("libraries.map")
require("libraries.dump")

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end

-- map needs to warmup
local warmup = 0.0
local music
local scale = 5

-- 0 nothing
-- 1 wall
local test_map = {
    {1,1,1,1,1,1,1,1,1,1},
    {1,0,1,0,0,0,1,0,0,1},
    {1,0,1,0,1,0,1,0,0,1},
    {1,0,0,0,1,1,1,1,0,1},
    {1,1,0,0,1,0,0,0,0,1},
    {1,0,0,0,0,0,0,1,0,1},
    {1,0,1,1,0,1,1,1,0,1},
    {1,0,0,1,0,1,0,1,0,1},
    {1,0,0,1,0,1,0,0,0,1},
    {1,1,1,1,1,1,1,1,1,1},
}

local debug_map = map:new(16, 128, 128, nil, 0)--, test_map)

debug_map:add_walkables({0})


local pathy

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest", 16)
    music = love.audio.newSource("sounds/Lightless Dawn.ogg", "stream")
end

local function randomize_map()
    for i = 0,debug_map.linear_size do
        local value = 0

        if math.random() > 0.7 then
            value = 1
        end
        debug_map.pointer[i] = value
    end
end

function love.update(delta)
    if warmup < 1 then
        warmup = warmup + delta
    else
        
        if not music:isPlaying() then
            music:play()
        end
        

        randomize_map()
        -- print("STARTING PATH FIND")

        -- local start_time = love.timer.getTime()
        pathy = debug_map:find_path({ x = 1,y=1}, {x=127,y=127}, true)

        --[[
        local result = love.timer.getTime() - start_time

        if pathy then
            print( string.format( "It took %.3f milliseconds to calculate the path!", result * 1000 ))
        else
            print("PATH FIND FAILED!")
            print(string.format( "It took %.3f milliseconds to FAIL!", result * 1000 ))
        end
        ]]--
        -- warmup = -50000000000
        -- love.event.quit()
    end
end

function love.draw()
    for x = 0,debug_map.size_x do
        for y = 0,debug_map.size_y do

            local value = debug_map:get_2d(x,y)

            if value == nil then
                -- print(x,y)
            end

            
            if value > 0 then

                if value == 1 then
                    love.graphics.setColor(0.5,0.5,0.5,1)
                elseif value == 2 then
                    love.graphics.setColor(1,0,0,1)
                elseif value == 3 then
                    love.graphics.setColor(0,0,1,1)
                end
                love.graphics.rectangle("fill", x * scale, y * scale, scale - 1,scale - 1)
            end
            
        end
    end

    if pathy then
        love.graphics.setColor(1,0,0,1)
        for _,position in ipairs(pathy) do
            love.graphics.rectangle("fill", position.x * scale, position.y * scale, scale - 1, scale - 1)
        end
    end

    love.graphics.setColor(1,0,0,1)
    love.graphics.print("fps: " .. tostring(love.timer.getFPS()), 700,50)
    love.graphics.print("path found: " .. tostring(pathy ~= false), 640,80)

end