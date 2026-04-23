local Corex = nil
local OccupiedZones = {}
local PlayersInZones = {}
local lastCrateRequest = {}
local ScheduleCrateRefill
local ScheduleBigBoxRefill
local ZONE_EXIT_BUFFER = 5.0

local function Debug(level, msg)
    if not Config.Debug and level ~= 'Error' then return end
    local colors = { Error = '^1', Warn = '^3', Info = '^2', Verbose = '^5' }
    print((colors[level] or '^7') .. '[COREX-REDZONES] ' .. msg .. '^0')
end

local function InitCorex()
    local attempts = 0
    while not Corex and attempts < 30 do
        local ok, result = pcall(function()
            return exports['corex-core']:GetCoreObject()
        end)
        if ok and result then
            Corex = result
            Debug('Info', 'Core object acquired')
            return true
        end
        attempts = attempts + 1
        Wait(1000)
    end
    Debug('Error', 'Failed to acquire core object')
    return false
end

local function GetZoneById(zoneId)
    for _, zone in ipairs(Config.Zones) do
        if zone.id == zoneId then return zone end
    end
    return nil
end

local function IsCoordsInZone(coords, zone, extraRadius)
    if not coords or not zone or not zone.coords then return false end
    if type(zone.coords.x) ~= 'number' or type(zone.coords.y) ~= 'number' then return false end
    if type(zone.radius) ~= 'number' or zone.radius <= 0 then return false end

    local radius = zone.radius + (extraRadius or 0.0)
    local dx = coords.x - zone.coords.x
    local dy = coords.y - zone.coords.y
    return (dx * dx + dy * dy) <= (radius * radius)
end

local function CrateIdFor(zoneId, crateIndex)
    return ('redzone_%s_crate_%d'):format(zoneId, crateIndex)
end

local function BigBoxIdFor(zoneId)
    return ('redzone_%s_bigbox'):format(zoneId)
end

local function NotifyCrateLootState(containerId, hasLoot)
    TriggerClientEvent('corex-redzones:client:setCrateLootState', -1, containerId, hasLoot == true)
end

local function RollTier(tiers)
    local roll = math.random()
    local cumulative = 0.0
    for _, tier in ipairs(tiers) do
        cumulative = cumulative + tier.chance
        if roll <= cumulative then return tier.items end
    end
    return tiers[1].items
end

local function GenerateLoot()
    local count = math.random(Config.LootItemsPerCrate.min, Config.LootItemsPerCrate.max)
    local items = {}
    for _ = 1, count do
        local tier = RollTier(Config.LootTiers)
        if tier and #tier > 0 then
            local pick = tier[math.random(1, #tier)]
            items[#items + 1] = {
                name = pick.name,
                count = math.random(pick.min, pick.max)
            }
        end
    end
    if #items == 0 then
        items[1] = { name = 'rifle_ammo', count = 30 }
    end
    return items
end

local function GenerateBigBoxLoot()
    local cfg = Config.BigLootBox
    local count = math.random(cfg.itemsPerBox.min, cfg.itemsPerBox.max)
    local items = {}
    for _ = 1, count do
        local tier = RollTier(cfg.tiers)
        if tier and #tier > 0 then
            local pick = tier[math.random(1, #tier)]
            items[#items + 1] = {
                name = pick.name,
                count = math.random(pick.min, pick.max)
            }
        end
    end
    if #items == 0 then
        items[1] = { name = 'rifle_ammo', count = 50 }
    end
    return items
end

local function RegisterCrate(zoneId, crateIndex)
    local crateId = CrateIdFor(zoneId, crateIndex)
    local zone = GetZoneById(zoneId)
    local crateCoords = zone and zone.crates and zone.crates[crateIndex] or nil

    pcall(function()
        exports['corex-loot']:UnregisterDynamicContainer(crateId)
    end)

    local ok, err = pcall(function()
        return exports['corex-loot']:RegisterDynamicContainer(crateId, GenerateLoot(), {
            label = 'Military Supply Crate',
            onDepleted = function(containerId, src)
                Debug('Verbose', ('Crate %s depleted by %s — scheduling refill'):format(containerId, tostring(src)))
                NotifyCrateLootState(containerId, false)
                ScheduleCrateRefill(zoneId, crateIndex)
            end,
            coords = crateCoords,
            interactDistance = 3.0
        })
    end)

    if not ok then
        Debug('Error', 'Failed to register crate ' .. crateId .. ': ' .. tostring(err))
    else
        NotifyCrateLootState(crateId, true)
        Debug('Verbose', 'Registered crate ' .. crateId)
    end
end

local function RegisterBigBox(zoneId)
    local boxId = BigBoxIdFor(zoneId)
    local zone = GetZoneById(zoneId)

    pcall(function()
        exports['corex-loot']:UnregisterDynamicContainer(boxId)
    end)

    local ok, err = pcall(function()
        return exports['corex-loot']:RegisterDynamicContainer(boxId, GenerateBigBoxLoot(), {
            label = 'Big Loot Box',
            onDepleted = function(containerId, src)
                Debug('Verbose', ('BigBox %s depleted by %s — scheduling refill'):format(containerId, tostring(src)))
                NotifyCrateLootState(containerId, false)
                ScheduleBigBoxRefill(zoneId)
            end,
            coords = zone and zone.bigBox or nil,
            interactDistance = 3.5
        })
    end)

    if not ok then
        Debug('Error', 'Failed to register big box ' .. boxId .. ': ' .. tostring(err))
    else
        NotifyCrateLootState(boxId, true)
        Debug('Verbose', 'Registered big box ' .. boxId)
    end
end

local pendingRefills = {}

ScheduleCrateRefill = function(zoneId, crateIndex)
    local crateId = CrateIdFor(zoneId, crateIndex)
    if pendingRefills[crateId] then return end
    local minutes = math.random(Config.RefillMinutes.min, Config.RefillMinutes.max)
    pendingRefills[crateId] = {
        fn = function() RegisterCrate(zoneId, crateIndex) end,
        refillAt = os.time() + (minutes * 60),
    }
    Debug('Info', ('Crate %s will refill in %d minutes'):format(crateId, minutes))
end

ScheduleBigBoxRefill = function(zoneId)
    local boxId = BigBoxIdFor(zoneId)
    if pendingRefills[boxId] then return end
    local minutes = math.random(Config.RefillMinutes.min, Config.RefillMinutes.max)
    pendingRefills[boxId] = {
        fn = function() RegisterBigBox(zoneId) end,
        refillAt = os.time() + (minutes * 60),
    }
    Debug('Info', ('BigBox %s will refill in %d minutes'):format(boxId, minutes))
end

CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        local refilled = 0
        for id, entry in pairs(pendingRefills) do
            if now >= entry.refillAt then
                pendingRefills[id] = nil
                entry.fn()
                Debug('Info', ('Refilled %s'):format(id))
                refilled = refilled + 1
                if refilled >= 3 then break end
            end
        end
    end
end)

local function InitializeCrates()
    for _, zone in ipairs(Config.Zones) do
        for crateIndex = 1, #zone.crates do
            RegisterCrate(zone.id, crateIndex)
        end
        if zone.bigBox then
            RegisterBigBox(zone.id)
        end
    end
    Debug('Info', 'Initialized all red-zone crates and big boxes')
end

local function BuildZoneManifest()
    local manifest = {}
    for _, zone in ipairs(Config.Zones) do
        local zoneEntry = {
            id = zone.id,
            name = zone.name,
            coords = zone.coords,
            radius = zone.radius,
            crates = {}
        }
        for i, coords in ipairs(zone.crates) do
            local crateId = CrateIdFor(zone.id, i)
            zoneEntry.crates[i] = {
                crateId = crateId,
                coords = coords,
                hasLoot = pendingRefills[crateId] == nil
            }
        end
        if zone.bigBox then
            local boxId = BigBoxIdFor(zone.id)
            zoneEntry.bigBox = {
                crateId = boxId,
                coords = zone.bigBox,
                hasLoot = pendingRefills[boxId] == nil
            }
        end
        manifest[#manifest + 1] = zoneEntry
    end
    return manifest
end

local function PickSpawnHost(zoneId)
    local occupants = OccupiedZones[zoneId]
    if not occupants or not next(occupants) then return nil end
    local lowest = nil
    for src, _ in pairs(occupants) do
        if lowest == nil or src < lowest then
            lowest = src
        end
    end
    return lowest
end

local function ReassignSpawnHost(zoneId)
    local host = PickSpawnHost(zoneId)
    local occupants = OccupiedZones[zoneId] or {}

    for src, _ in pairs(occupants) do
        TriggerClientEvent('corex-redzones:client:setSpawnHost', src, zoneId, src == host)
    end

    if host then
        Debug('Verbose', ('Zone %s spawn host -> %d'):format(zoneId, host))
    end
end

local function HandlePlayerEnterZone(src, zoneId)
    local zone = GetZoneById(zoneId)
    if not zone then return end

    local player = Corex and Corex.Functions.GetPlayer(src)
    if not player then return end

    PlayersInZones[src] = zoneId
    OccupiedZones[zoneId] = OccupiedZones[zoneId] or {}
    OccupiedZones[zoneId][src] = true

    Debug('Info', ('Player %d entered red zone %s'):format(src, zoneId))
    ReassignSpawnHost(zoneId)
end

local function HandlePlayerLeaveZone(src)
    local zoneId = PlayersInZones[src]
    if not zoneId then return end

    PlayersInZones[src] = nil
    lastCrateRequest[src] = nil
    if OccupiedZones[zoneId] then
        OccupiedZones[zoneId][src] = nil
        if not next(OccupiedZones[zoneId]) then
            OccupiedZones[zoneId] = nil
            Debug('Verbose', ('Zone %s is now empty'):format(zoneId))
        else
            ReassignSpawnHost(zoneId)
        end
    end

    Debug('Info', ('Player %d left red zone %s'):format(src, zoneId))
end

local function DetermineZoneForPlayer(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local pc = GetEntityCoords(ped)
    if not pc or pc.x ~= pc.x or pc.y ~= pc.y or pc.z ~= pc.z then return nil end

    local trackedZone = GetZoneById(PlayersInZones[src])
    if trackedZone and IsCoordsInZone(pc, trackedZone, ZONE_EXIT_BUFFER) then
        return trackedZone.id
    end

    local zones = (Config and Config.Zones) or {}
    for _, zone in ipairs(zones) do
        if IsCoordsInZone(pc, zone, 0.0) then
            return zone.id
        end
    end
    return nil
end

CreateThread(function()
    while true do
        Wait(2000)
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            if src then
                local currentZone = DetermineZoneForPlayer(src)
                local trackedZone = PlayersInZones[src]

                if currentZone ~= trackedZone then
                    if trackedZone then
                        HandlePlayerLeaveZone(src)
                    end
                    if currentZone then
                        HandlePlayerEnterZone(src, currentZone)
                    end
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    HandlePlayerLeaveZone(src)
end)

exports('GetZoneManifest', BuildZoneManifest)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for _, zone in ipairs(Config.Zones) do
        for crateIndex = 1, #zone.crates do
            local crateId = CrateIdFor(zone.id, crateIndex)
            pcall(function()
                exports['corex-loot']:UnregisterDynamicContainer(crateId)
            end)
        end
        if zone.bigBox then
            local boxId = BigBoxIdFor(zone.id)
            pcall(function()
                exports['corex-loot']:UnregisterDynamicContainer(boxId)
            end)
        end
    end
end)

RegisterNetEvent('corex-redzones:server:requestManifest', function()
    local src = source
    TriggerClientEvent('corex-redzones:client:manifest', src, BuildZoneManifest())
end)

CreateThread(function()
    Wait(1500)
    if not InitCorex() then return end
    InitializeCrates()
    Debug('Info', ('Red Zones online — %d zones registered'):format(#Config.Zones))
end)
