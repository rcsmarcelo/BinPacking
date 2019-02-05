local objarraytot, capacity
local objarray = {}

-------------------------------------------
----------Reads Falkenauer Instance--------
-------------------------------------------
local function read_problem()
    local file = io.open('Falkenauer_t60_00.txt', 'r')
    objarraytot = file:read'*number'    --amount of objects
    capacity = file:read'*number'   --max capacity of each bin
    while true do
	    local n = file:read'*number'
	    if not n then break end
        objarray[#objarray + 1] = n --obj #objarray+1 has weight 'line'
    end
end

-------------------------------------------
-------Functions for Bin Manipulation------
-------------------------------------------
local function add_object(binarray, weight)
    if not binarray[#binarray] or  
                binarray[#binarray].free - weight < 0 then --empty or wont fit
        local bin = {}
        bin.content = {}
        bin.free = capacity
        table.insert(binarray, bin)
    end

    binarray[#binarray].free = binarray[#binarray].free - weight
    table.insert(binarray[#binarray].content, weight)
end

local function remove_object(binarray, binindex, objindex)
    binarray[binindex].free = binarray[binindex].free + 
        binarray[binindex].content[objindex]
    if binarray[binindex].free == capacity then
        table.remove(binarray, binindex)
        return 
    end

    table.remove(binarray[binindex].content, objindex)
end

local function find_obj(binarray, weight)
    for i, bin in ipairs(binarray) do
        for j, w in ipairs(bin.content) do
            if w == weight then return i, j end
        end
    end
    return false
end


-------------------------------------------
-----Auxiliar Functions for table.sort-----
-------------------------------------------
local function sort_objweight_aux(obj1, obj2)
    if obj1 > obj2 then
        return true
    else return false end
end

local function sort_weight_aux(bin1, bin2)
    if bin1.free > bin2.free then
        return true
    else return false end
end

local function sort_length_aux(bin1, bin2)
    if #bin1 < #bin2 then
        return true
    else return false end
end

-------------------------------------------
----Auxiliar Functions for array copying----
-------------------------------------------
function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-------------------------------------------
----------Neighborhood Functions-----------
-------------------------------------------
local function try_reallocate_smart(binarray, times)
    local ordered = binarray
    table.sort(ordered, sort_weight_aux)
    for t = 1, times do
        if t > #ordered then break end
        local fbin = ordered[t] --find emptiest bin
        local weight = fbin.content[#fbin.content] --get top object
        if not weight then return end

        for i, bin in ipairs(binarray) do --attempt to slot it somewhere
            if bin.free - weight >= 0 and i ~= t then
                table.insert(bin.content, weight)
                bin.free = bin.free - weight
                remove_object(binarray, t, #fbin.content)
                break
            end
        end
    end
end

local function try_reallocate(binarray, times)
    for t = 0, times do
        local index = math.random(#binarray)
        local objindex = math.random(#binarray[index].content)
        local weight = binarray[index].content[objindex]
        if not weight then return end
        for i, bin in ipairs(binarray) do
            if bin.free - weight >= 0 and i ~= index then
                table.insert(bin.content, weight)
                bin.free = bin.free - weight
                remove_object(binarray, index, objindex)
                break
            end
        end
    end
end

local function swap_object(binarray, binindex1, binindex2, 
        objindex1, objindex2)
    local swapper = binarray[binindex1].content[objindex1]
    binarray[binindex1].content[objindex1] = 
        binarray[binindex2].content[objindex2]

    binarray[binindex2].content[objindex2] = swapper

    binarray[binindex1].free = binarray[binindex1].free + 
        swapper - binarray[binindex1].content[objindex1]

    binarray[binindex2].free = binarray[binindex2].free + 
        binarray[binindex1].content[objindex1] - swapper 
end

local function try_swap(binarray, times)
    for t = 0, times do
        local index1 = math.random(#binarray) --get random bins
        local index2 = math.random(#binarray)
        local objindex1 = math.random(#binarray[index1].content) --get random object on each bin
        local objindex2 = math.random(#binarray[index2].content)
        local obj1 = binarray[index1].content[objindex1]
        local obj2 = binarray[index2].content[objindex2]
        
        if binarray[index1].free + obj1 - obj2 >= 0 
                and binarray[index2].free + obj2 - obj1 >=0  then --attempt to swap
            swap_object(binarray, index1, index2, objindex1, objindex2)
        end
    end
end

local function try_worsen(binarray, attempts)
    for i = 0, attempts do
        local index = math.random(#binarray) --get random bin 
        local weight = binarray[index].content[#binarray[index].content]
        local bin = {}
        remove_object(binarray, index, #binarray[index].content) --remove top object
        bin.content = {} --make new bin
        bin.free = capacity
        table.insert(binarray, bin) --add new bin
        binarray[#binarray].free = binarray[#binarray].free - weight
        table.insert(binarray[#binarray].content, weight) --add object to new bin
    end
end

local function gen_neighborhood(binarray, attempts)
    local initFitVal = #binarray
    local solution = deepcopy(binarray)
    local neighborhood = {}
    for i = 0, attempts do --try to make 'attempts' neighbors
        try_swap(solution, 20) --lots of swapping around
        try_reallocate_smart(solution, 25) --lots of moving around
        try_swap(solution, 20) --lots of swapping around
        try_reallocate_smart(solution, 25) --lots of moving around

        table.insert(neighborhood, solution) --add new neighbor to array
	    solution = deepcopy(binarray) --undoes changes to array to make more neighbors
    end

    return neighborhood
end

-------------------------------------------
----------Random Initial Solution----------
-------------------------------------------
local function gen_init_state()
    local binarray = {}
    for i = 1, #objarray do

::retry::
        local index = math.random(#objarray)
        local weight = objarray[index] --get random object
        if weight < 0 then --object has already been used
            goto retry
        end

        add_object(binarray, weight)
        objarray[index] = objarray[index] * (-1) --mark object as used
    end

    for i = 1, #objarray do --resets changes done to array
        objarray[i] = objarray[i] * (-1)
    end

    return binarray
end

-------------------------------------------
------------Basic Hill Climbing------------
-------------------------------------------
local function hill_climbing(attempts)
    local currsolution = gen_init_state() 
    while true do
        local neighborhood = gen_neighborhood(currsolution, attempts) --make neighbors 
	    local chosen = neighborhood[1]

        for i, nb in ipairs(neighborhood) do --find best neighbor
            if #nb <= #chosen then chosen = nb end 
        end
        
        if #chosen >= #currsolution then return currsolution end
        currsolution = chosen
    end
end

-------------------------------------------
----------Persistent Hill Climbing---------
-------------------------------------------
local function hill_climbing_custom(persistence)
    local currsolution = gen_init_state() 
    while true do
        local neighborhood = gen_neighborhood(currsolution, 1) --make a single neighbor 
	    local chosen = neighborhood[1] --stick with it

        if #chosen == #currsolution then persistence = persistence - 1 end --resist ending
        if persistence == 0 then return currsolution end --give up
        currsolution = chosen
    end
end

-------------------------------------------
----------Restart Hill Climbing------------
-------------------------------------------
local function hill_climbing_rand_restart(attempts, restarts)
    local currsolution = gen_init_state() 
    local loopcounter = 0
    while true do
        local neighborhood = gen_neighborhood(currsolution, attempts) --make neighbors 
	    local chosen = neighborhood[1]
        local globalchosen = {}
        for i, nb in ipairs(neighborhood) do --find best neighbor
            if #nb <= #chosen then chosen = nb end 
        end
        
        if #chosen == #currsolution then --check for a loop
	        loopcounter = loopcounter + 1
        else loopcounter = 0 end

        if loopcounter >= 3 then --if inside loop restart
            restarts = restarts - 1
            loopcounter = 0
            table.insert(globalchosen, chosen) 
            currsolution = gen_init_state()
        else
            currsolution = chosen
        end

        if restarts == 0 then --give up
            table.sort(globalchosen, sort_length_aux)
            return globalchosen[1] --return best found solution
        end
    end
end

-------------------------------------------
----------Print Out Solutions--------------
-------------------------------------------
local function display_solution(binarray, duration, method)
    print('------------------------------------------')
    print('Method Used: ' .. method)
    print('Found Solution: ' .. #binarray .. ' bins')
    print('Time Elapsed: ' .. duration .. ' seconds')
    print('------------------------------------------')
    local file = io.open('Solution_' .. method .. '.txt', 'w+')
    file:write(#binarray .. '\n')
	for i, bin in ipairs(binarray) do
		for j, obj in ipairs(bin.content) do
			file:write(obj .. ' ')
		end
		file:write'\n'
	end
end
-------------------x-----------------------

read_problem()
local t = os.clock()
math.randomseed(os.time())
local sol = gen_init_state()
t = os.clock() - t
display_solution(sol, t, 'Randomnly Allocated')

t = os.clock()
sol = hill_climbing(10)
t = os.clock() - t
display_solution(sol, t, 'Hill Climbing')

t = os.clock()
sol = hill_climbing_rand_restart(10, 3)
t = os.clock() - t
display_solution(sol, t, 'Hill Climbing Random-Restart')

t = os.clock()
sol = hill_climbing_custom(150)
t = os.clock() - t
display_solution(sol, t, 'Hill Climbing Custom')

