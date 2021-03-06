local
math_floor, table_insert, table_sort, table_remove
=
math.floor, table.insert, table.sort, table.remove

local ffi = require("ffi")

print("\n")

print("loaded")

--[[
remember

c arrays start at 0

even though you can utilize 8 and 16 bits, they will be padded out to 32/64 in your ram

maps utilize unsigned integers, no negativity, badum tss

count base 0, a single shift is a row toggle right, an X overflow moves into next column

0,0|1,0|2,0|3,0|etc
0,1|1,1|2,1|3,1|etc
etc

]]--

-- function to simplify memory assignment
local function megabytes(input_value)
    return(1048576 * input_value)
end

-- this is a test, move it to tests when it's in it's own repo
assert(268435456 ==  megabytes(256), "SOMETHING HAS GONE WRONG WITH MEGABYTES CALCULATION!!")

-- simple helper tables
local data_converted = {
    [8]  = 1,
    [16] = 2,
    [32] = 4
}
local data_to_string = {
    [8]  = "uint8_t*",
    [16] = "uint16_t*",
    [32] = "uint32_t*"
}

-- function to allow EXACT memory assignment
local function values_to_bytes(data_type, number_of_values)
    assert(data_type == 8 or data_type == 16 or data_type == 32, "data_type must be a C unsigned whole number, up to 32 bits")
    return(data_converted[data_type] * number_of_values)
end

-- this is a test, move it into tests when it's in it's own repo
-- 10 values, 32 bit, 4 bytes in each memory cell
assert(10 * 4 == values_to_bytes(32, 10), "EXTREME error in detect_architecture")


-- map class
map = {}

-- creates individual signatures with identical maps
local id = 0

-- map constructor
function map:new(bits, size_x, size_y, optional_preset, optional_default_value)

    assert(bits == 8 or bits == 16 or bits == 32, "bits must be 8, 16, or 32 depending on your needs")

    assert(size_x, "size_x not defined")
    assert(size_y, "size_y not defined")

    assert(size_x > 1, "size_x must be greater than 1")
    assert(size_y > 1, "size_y must be greater than 1")

    local object = {}

    -- this makes it easier to work with in lua
    object.size_x = size_x - 1
    object.size_y = size_y - 1

    object.__internal_size_x = size_x
    object.__internal_size_y = size_y

    object.linear_size = size_x * size_y

    object.bits = bits

    object.memory = love.data.newByteData(values_to_bytes(bits, size_x * size_y))

    object.pointer = ffi.cast(data_to_string[bits], object.memory:getFFIPointer())

    object.walkable_ids = {}

    object.id = id

    id = id + 1

    -- set set defined map OR default value
    if optional_preset then
        -- take in first come first serve values
        local predefined_y_size = #optional_preset
        local predefined_x_size = #optional_preset[1]

        assert(predefined_y_size == object.__internal_size_y, "PREDEFINED MAP Y (left/right) IS NOT THE SAME SIZE AS DEFINITION!\nRecieved " .. tostring(predefined_y_size) .. " height instead of defined " .. tostring(object.size_y))
        assert(predefined_x_size == object.__internal_size_x, "PREDEFINED MAP X (up/down) IS NOT THE SAME SIZE AS DEFINITION!\nRecieved " .. tostring(predefined_x_size) .. " width instead of defined " .. tostring(object.size_x))

        -- reconfigure them to intake literal spacial definition as it appears in code
        for y = 1,predefined_y_size do
            for x = 1,predefined_x_size do
                local injecting_value = optional_preset[y][x]
                assert(injecting_value ~= nil, "predefined map is probably uneven, error at X: " .. tostring(x) .. " | Y: " .. tostring(y))
                object.pointer[object:convert_2d_to_1d(x - 1, y - 1)] = injecting_value
            end
        end
    elseif optional_default_value then
        for i = 0,object.linear_size do
            object.pointer[i] = optional_default_value
        end
    else
        assert("nil" == 5, "AN OPTIONAL VALUE MUST BE PRESENT FOR A MAP!")
    end

    setmetatable(object, self)

    self.__index = self

    return object
end

-- allows users to destroy the map
function map:close()
    self.memory:release()
    self = nil
end

-- allows users to define which nodes are walkable
function map:add_walkables(walkables_table)
    for _,value in ipairs(walkables_table) do
        if not self.walkable_ids[value] then
            self.walkable_ids[value] = true
        end
    end
end

-- map helper - base 0
-- 1d to 2d calcultion
function map:convert_1d_to_2d(i)
    return({math_floor(i % self.__internal_size_x), math_floor(i / self.__internal_size_x)})
end
-- 2d to 1d calculation
function map:convert_2d_to_1d(x,y)
    return math_floor((y * self.__internal_size_x) + x)
end

-- map integer overflow protection
function map:overflow_protection(new_value)
    assert(new_value > 0, "INTEGER UNDERFLOW DETECTED!")
    if self.bits == 8 then
        assert(new_value <= 255, "INTEGER OVERFLOW DETECTED!")
    elseif self.bits == 16 then
        assert(new_value <= 65535, "INTEGER OVERFLOW DETECTED!")
    elseif self.bits == 32 then
        assert(new_value <= 4294967295, "INTEGER OVERFLOW DETECTED!")
    end
end

-- getter 1D
function map:get_1d(i)
    assert(i >= 0 and i < self.linear_size, "MAP 1D GETTER MUST BE BETWEEN 0 AND " .. tostring(self.linear_size) .. "!")
    return self.pointer[i]
end

-- getter 2D
function map:get_2d(x,y)
    assert(x >= 0 and x < self.__internal_size_x, "trying to get map location out of bounds on X: " .. tostring(x))
    assert(y >= 0 and y < self.__internal_size_y, "trying to get map location out of bounds on Y: " .. tostring(y))
    return self.pointer[self:convert_2d_to_1d(x,y)]
end

-- setter 1D
function map:set_1d(i, new_value)
    assert(i >= 0 and i < self.linear_size, "MAP 1D GETTER MUST BE BETWEEN 0 AND " .. tostring(self.linear_size) .. "!")
    self:overflow_protection(new_value)
    self.pointer[i] = new_value
end

-- setter 2D
function map:set_2d(x, y, new_value)
    assert(x >= 0 and x < self.__internal_size_x, "trying to get map location out of bounds on X: " .. tostring(x))
    assert(y >= 0 and y < self.__internal_size_y, "trying to get map location out of bounds on Y: " .. tostring(y))
    self:overflow_protection(new_value)
    self.pointer[self:convert_2d_to_1d(x,y)] = new_value
end


------------------ begin path finding algorithm --------------------------------------------

-- https://github.com/wesleywerner/lua-star/blob/master/src/lua-star.lua MIT

-- I'm (jordan4ibanez) going to try to leave the comments alone, they explain it pretty well

--- Provides easy A* path finding.
-- @map lua-star


-- (Internal) Return the distance between two points.
-- This method doesn't bother getting the square root of s, it is faster
-- and it still works for our use.
local function distance(x1, y1, x2, y2)
  local x = x1 - x2
  local y = y1 - y2
  return(x * x + y * y)
end

-- (Internal) Return the score of a node.
-- G is the cost from START to this node.
-- H is a heuristic cost, in this case the distance from this node to the goal.
-- Returns F, the sum of G and H.
local function calculateScore(previous, node, goal)

    local G = previous.score + 1
    local H = distance(node.x, node.y, goal.x, goal.y)
    return G + H, G, H

end


local runner_test = 0
-- (Internal) Returns true if the given list contains the specified item.
local function listContains(list, item)
    runner_test = runner_test + 1
    for _, test in ipairs(list) do
        if test.x == item.x and test.y == item.y then
            return true
        end
    end
    return false
end

-- (Internal) Returns the item in the given list.
local function listItem(list, item)
    for _, test in ipairs(list) do
        if test.x == item.x and test.y == item.y then
            return test
        end
    end
end

local positions = {
    0, -1, -- top
    -1, 0, -- left
    0,  1, -- bottom
    1,  0  -- right
}

-- (Internal) Requests adjacent map values around the given node.
function map:getAdjacent(node)

    local result = {}

    local node_x = node.x
    local node_y = node.y

    local insertions = 1

    for i = 1,4 do
        local x = positions[(i * 2) - 1]
        local y = positions[i * 2]

        local new_node_x = node_x + x
        local new_node_y = node_y + y

        -- inlined clamp function
        local px = new_node_x < 1 and 1 or (new_node_x > self.size_x and self.size_x or new_node_x)
        local py = new_node_y < 1 and 1 or (new_node_y > self.size_y and self.size_y or new_node_y)

        if self:is_walkable( px, py ) then
            -- numerical insert
            result[insertions] = { x = px, y = py}
            insertions = insertions + 1
        end
    end

    return result

end

-- a bolt on, internal handler to see if position is walkable
function map:is_walkable(x,y)
    return self.walkable_ids[self.pointer[self:convert_2d_to_1d(x,y)]] ~= nil
end

-- Returns the path from start to goal, or false if no path exists.
function map:find_path(start, goal, excludeDiagonalMoving)

    local start_time = love.timer.getTime()

    local success = false

    -- these are the EXTREME problem tables
    local open = {}
    local closed = {}

    local open_hash = {}
    local closed_hash = {}

    start.score = 0
    start.G = 0
    start.H = distance(start.x, start.y, goal.x, goal.y)
    start.parent = { x = 0, y = 0 }

    local goal_hash = goal.x .. " | " .. goal.y

    -- inserts initial value
    table_insert(open, start)

    -- continue until found or out of options
    while not success and #open > 0 do

        -- sort by score: high to low
        table_sort(open,
            function(a, b)
                return a.score > b.score
            end
        )

        -- pops beginning of queue from the open queue
        local current = table_remove(open)

        -- create hash key for table
        local current_hash = current.x .. " | " .. current.y

        -- removes the open hash key
        open_hash[current_hash] = nil

                
        -- inserts the current value into the end of the closed queue
        -- previous function: table_insert(closed, current)
        closed[#closed+1] = current

        -- inserts a hash key into the closed hash table
        closed_hash[current_hash] = true

        -- checks if the current goal has successfully inserted the finish node
        -- previous function: listContains(closed, goal)
        success = closed_hash[goal_hash]

        -- only run if not found
        if not success then

            -- check local neighbor nodes
            for _, adjacent in ipairs(self:getAdjacent(current)) do

                -- create a hash key for the adjacent node
                local adjacent_hash = adjacent.x .. " | " .. adjacent.y

                -- check if neighbor is not in closed queue
                if not closed_hash[adjacent_hash] then

                    -- check if neighbor is not in open queue
                    -- previous function: listContains(open, adjacent)
                    if not open_hash[adjacent_hash] then

                        -- add the neighbor to the open queue with score and parent node
                        adjacent.score = calculateScore(current, adjacent, goal)
                        adjacent.parent = current

                        -- finally insert it into the open table
                        -- previous function: table_insert(open, adjacent)
                        open_hash[adjacent_hash] = true
                        open[#open+1] = adjacent

                    end

                end

            end

        end

    end

    local result = love.timer.getTime() - start_time

    print( string.format( "It took %.3f milliseconds to calculate!", result * 1000 ))

    if not success then
        return false
    end

    -- traverse the parents from the last point to get the path
    local node = listItem(closed, closed[#closed])
    local path = { }

    while node do

        table_insert(path, 1, { x = node.x, y = node.y } )
        node = listItem(closed, node.parent)

    end

    -- reverse the closed list to get the solution
    return path

end