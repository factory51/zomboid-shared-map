-- SharedMap server: keeps the union of every player's walked map units in global ModData
-- and relays it to all clients. The map is a grid of 32x32-square units; a cell is {ux, uy}.

local MODULE = "SharedMap"
local DATA_KEY = "Fac51SharedMap"
local MAX_CELLS_PER_MESSAGE = 200
local MAX_RUNS_PER_MESSAGE = 400

local function enabled()
    return not SandboxVars.SharedMap or SandboxVars.SharedMap.Enabled
end

local function store()
    local data = ModData.getOrCreate(DATA_KEY)
    data.cells = data.cells or {}
    return data.cells
end

-- Turn a list of "ux,uy" keys into horizontal runs {ux, uy, count, ...} flattened.
local function toRuns(keys)
    local rows = {}
    for _, key in ipairs(keys) do
        local ux, uy = key:match("(-?%d+),(-?%d+)")
        ux, uy = tonumber(ux), tonumber(uy)
        rows[uy] = rows[uy] or {}
        table.insert(rows[uy], ux)
    end
    local runs = {}
    for uy, xs in pairs(rows) do
        table.sort(xs)
        local start, last = xs[1], xs[1]
        for i = 2, #xs do
            if xs[i] ~= last + 1 then
                table.insert(runs, { start, uy, last - start + 1 })
                start = xs[i]
            end
            last = xs[i]
        end
        table.insert(runs, { start, uy, last - start + 1 })
    end
    return runs
end

local function sendRuns(player, runs)
    local batch = {}
    local function flush()
        if #batch == 0 then return end
        if player then
            sendServerCommand(player, MODULE, "reveal", { runs = batch })
        else
            sendServerCommand(MODULE, "reveal", { runs = batch })
        end
        batch = {}
    end
    for _, run in ipairs(runs) do
        table.insert(batch, run)
        if #batch >= MAX_RUNS_PER_MESSAGE then flush() end
    end
    flush()
end

local function onClientCommand(module, command, player, args)
    if module ~= MODULE or not enabled() then return end
    local cells = store()

    if command == "report" then
        local added = {}
        local list = args.cells or {}
        for i = 1, math.min(#list, MAX_CELLS_PER_MESSAGE) do
            local c = list[i]
            local ux, uy = tonumber(c[1]), tonumber(c[2])
            if ux and uy then
                local key = ux .. "," .. uy
                if not cells[key] then
                    cells[key] = true
                    table.insert(added, key)
                end
            end
        end
        if #added > 0 then sendRuns(nil, toRuns(added)) end

    elseif command == "request" then
        local keys = {}
        for key in pairs(cells) do table.insert(keys, key) end
        sendRuns(player, toRuns(keys))
    end
end

Events.OnClientCommand.Add(onClientCommand)
