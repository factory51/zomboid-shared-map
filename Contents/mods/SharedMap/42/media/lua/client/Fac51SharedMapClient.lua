-- SharedMap client: reports newly walked map units near the player to the server and
-- reveals units reported by other players. Only "visited" units are reported, never
-- "known" ones, so units revealed by the server are not echoed back.

local MODULE = "SharedMap"
local UNIT = 32               -- squares per map unit (WorldMapVisited.SQUARES_PER_UNIT)
local SCAN_UNITS = 2          -- scan this many units around the player
local SCAN_INTERVAL_TICKS = 120
local DEBUG = false

local reported = {}           -- "ux,uy" already sent this session
local ticks = 0

local function log(msg)
    if DEBUG then print("[SharedMap] " .. msg) end
end

local function scan()
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return end
    local map = WorldMapVisited.getInstance()
    local cx, cy = math.floor(player:getX() / UNIT), math.floor(player:getY() / UNIT)

    local fresh = {}
    for ux = cx - SCAN_UNITS, cx + SCAN_UNITS do
        for uy = cy - SCAN_UNITS, cy + SCAN_UNITS do
            local key = ux .. "," .. uy
            if not reported[key] and map:isVisited(ux * UNIT + 1, uy * UNIT + 1) then
                reported[key] = true
                table.insert(fresh, { ux, uy })
            end
        end
    end
    if #fresh > 0 then
        log("reporting " .. #fresh .. " units")
        sendClientCommand(player, MODULE, "report", { cells = fresh })
    end
end

local function onTick()
    ticks = ticks + 1
    if ticks < SCAN_INTERVAL_TICKS then return end
    ticks = 0
    scan()
end

local function onServerCommand(module, command, args)
    if module ~= MODULE or command ~= "reveal" then return end
    local map = WorldMapVisited.getInstance()
    for _, r in ipairs(args.rects or {}) do
        map:setKnownInSquares(r[1], r[2], r[3], r[4])
    end
    for _, run in ipairs(args.runs or {}) do
        local ux, uy, count = run[1], run[2], run[3]
        map:setKnownInSquares(ux * UNIT, uy * UNIT, (ux + count) * UNIT - 1, (uy + 1) * UNIT - 1)
    end
    log("revealed " .. #(args.runs or {}) .. " runs, " .. #(args.rects or {}) .. " rects")
end

local function onGameStart()
    local player = getSpecificPlayer(0)
    if player then sendClientCommand(player, MODULE, "request", {}) end
end

-- When the player opens a paper map, vanilla reveals its area on their own world map
-- (ISMap:initMapData). Report that area too so the server can share it, if enabled.
if ISMap and ISMap.initMapData then
    local vanillaInit = ISMap.initMapData
    function ISMap:initMapData(...)
        vanillaInit(self, ...)
        local opts = SandboxVars.SharedMap
        if not (opts and opts.Enabled and opts.ShareMaps) then return end
        local api = self.mapAPI
        sendClientCommand(self.character, MODULE, "reportMap", { rects = { {
            api:getMinXInSquares(), api:getMinYInSquares(),
            api:getMaxXInSquares(), api:getMaxYInSquares(),
        } } })
        log("reported paper map area")
    end
end

Events.OnTick.Add(onTick)
Events.OnServerCommand.Add(onServerCommand)
Events.OnGameStart.Add(onGameStart)
