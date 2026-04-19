local Corex = nil
local lootedZombies = {}
local lootedZombiesOrder = {}
local MAX_LOOTED_TRACKED = 5000
local sharedZombieBatches = {}
local sharedZombieIndex = {}
local lastSharedZoneSync = {}

print('[COREX-ZOMBIES-SERVER] ^3Initializing...^0')

local function SerializeVec3(coords)
    if not coords then return nil end
    return { x = coords.x, y = coords.y, z = coords.z }
end

local function DSync(msg)
    if Config.Debug then
        print(('^6[COREX-ZOMBIES-SYNC] %s^0'):format(msg))
    end
end

local function GetPlayerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then
        return nil
    end

    return GetEntityCoords(ped)
end

local function Dist(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function BroadcastSharedZone(batch)
    if not batch or not batch.center then
        return
    end

    exports['corex-core']:BroadcastNearby(
        batch.center,
        batch.radius + 150.0,
        'corex-zombies:client:sharedZoneStarted',
        batch.id,
        {
            center = SerializeVec3(batch.center),
            radius = batch.radius,
            eventId = batch.eventId,
            hostSource = batch.hostSource,
        }
    )
end

local function StopSharedZone(batch)
    if not batch or not batch.center then
        return
    end

    exports['corex-core']:BroadcastNearby(
        batch.center,
        batch.radius + 150.0,
        'corex-zombies:client:sharedZoneStopped',
        batch.id
    )
end

local function PickWeightedZombieTypeId()
    local pool = Config.ZombieTypes or {}
    local total = 0

    for _, zombieType in ipairs(pool) do
        total = total + (zombieType.weight or 0)
    end

    if total <= 0 or #pool == 0 then
        return pool[1] and pool[1].id or 'walker'
    end

    local roll = math.random() * total
    local accum = 0

    for _, zombieType in ipairs(pool) do
        accum = accum + (zombieType.weight or 0)
        if roll <= accum then
            return zombieType.id
        end
    end

    return pool[#pool].id
end

local function PickNearestPlayer(coords, maxDist, excludeSource)
    local bestSource, bestDistance = nil, maxDist or 600.0

    for _, srcStr in ipairs(GetPlayers()) do
        local src = tonumber(srcStr)
        if src and src ~= excludeSource then
            local playerCoords = GetPlayerCoords(src)
            if playerCoords then
                local distance = Dist(playerCoords, coords)
                if distance < bestDistance then
                    bestDistance = distance
                    bestSource = src
                end
            end
        end
    end

    return bestSource, bestDistance
end

local function CountBatchZombies(batch)
    local count = 0
    for _ in pairs(batch.zombies or {}) do
        count = count + 1
    end
    return count
end

local function GetSharedZoneSnapshotForPlayer(src)
    local snapshot = {}
    local playerCoords = GetPlayerCoords(src)
    if not playerCoords then
        return snapshot
    end

    for batchId, batch in pairs(sharedZombieBatches) do
        if batch.center and Dist(playerCoords, batch.center) <= (batch.radius + 200.0) then
            snapshot[#snapshot + 1] = {
                id = batchId,
                center = SerializeVec3(batch.center),
                radius = batch.radius,
                eventId = batch.eventId,
                hostSource = batch.hostSource,
            }
        end
    end

    return snapshot
end

local function AdoptSharedBatch(batch)
    if not batch or not batch.center then
        return false
    end

    local newHost = PickNearestPlayer(batch.center, batch.radius + 250.0, batch.hostSource)
    if not newHost then
        batch.hostSource = nil
        DSync(('batch=%s lost host and no replacement was found'):format(batch.id))
        return false
    end

    batch.hostSource = newHost

    local payload = {
        center = SerializeVec3(batch.center),
        radius = batch.radius,
        eventId = batch.eventId,
        zombies = {},
    }

    for zombieId, zombie in pairs(batch.zombies) do
        payload.zombies[#payload.zombies + 1] = {
            id = zombieId,
            netId = zombie.netId,
            typeId = zombie.typeId,
            coords = SerializeVec3(zombie.coords),
        }
    end

    TriggerClientEvent('corex-zombies:client:adoptSharedBatch', newHost, batch.id, payload)
    BroadcastSharedZone(batch)
    DSync(('batch=%s adopted by src=%d with %d zombies'):format(batch.id, newHost, #payload.zombies))
    return true
end

local function ClearSharedBatch(batchId, reason)
    local batch = sharedZombieBatches[batchId]
    if not batch then
        return
    end

    for zombieId in pairs(batch.zombies or {}) do
        sharedZombieIndex[zombieId] = nil
    end

    StopSharedZone(batch)
    sharedZombieBatches[batchId] = nil
    DSync(('cleared batch=%s reason=%s'):format(batchId, tostring(reason or 'unknown')))
end

local function CreateSharedBatch(eventId, center, count, spread)
    local syncCfg = Config.Sync or {}
    if not syncCfg.Enabled or not syncCfg.SharedEventHordes then
        return false, 'sync disabled'
    end

    if type(eventId) ~= 'string' or eventId == '' or not center then
        return false, 'invalid batch request'
    end

    if sharedZombieBatches[eventId] then
        return true, sharedZombieBatches[eventId].hostSource
    end

    local hostSource, hostDistance = PickNearestPlayer(center, 650.0)
    if not hostSource then
        return false, 'no host nearby'
    end

    local maxPerZone = syncCfg.MaxZombiesPerZone or 25
    count = math.max(1, math.min(tonumber(count) or 1, maxPerZone))
    spread = math.max(20.0, tonumber(spread) or 55.0)

    local batch = {
        id = eventId,
        eventId = eventId,
        center = center,
        radius = spread + (syncCfg.SharedZoneSuppressionBuffer or 45.0),
        hostSource = hostSource,
        createdAt = os.time(),
        zombies = {},
    }

    local payload = {
        center = SerializeVec3(center),
        radius = batch.radius,
        eventId = eventId,
        zombies = {},
    }

    for index = 1, count do
        local angle = math.random() * math.pi * 2
        local distance = math.random() * spread
        local coords = vector3(
            center.x + math.cos(angle) * distance,
            center.y + math.sin(angle) * distance,
            center.z
        )
        local zombieId = ('%s:shared:%d'):format(eventId, index)
        local typeId = PickWeightedZombieTypeId()

        batch.zombies[zombieId] = {
            id = zombieId,
            coords = coords,
            typeId = typeId,
            netId = nil,
            batchId = eventId,
            ownerSource = hostSource,
        }

        payload.zombies[#payload.zombies + 1] = {
            id = zombieId,
            coords = SerializeVec3(coords),
            typeId = typeId,
        }
    end

    sharedZombieBatches[eventId] = batch
    BroadcastSharedZone(batch)
    TriggerClientEvent('corex-zombies:client:spawnSharedBatch', hostSource, eventId, payload)

    DSync(('created batch=%s host=%d dist=%.0fm count=%d radius=%.1f'):format(
        eventId,
        hostSource,
        hostDistance or -1.0,
        count,
        batch.radius
    ))

    return true, hostSource
end

local function InitCore()
    local success, core = pcall(function()
        return exports['corex-core']:GetCoreObject()
    end)
    if not success or not core or not core.Functions then return false end
    Corex = core
    return true
end

if not InitCore() then
    AddEventHandler('corex:server:coreReady', function(coreObj)
        if coreObj and coreObj.Functions and not Corex then
            Corex = coreObj
            print('[COREX-ZOMBIES-SERVER] ^2Successfully connected to COREX core^0')
        end
    end)
    CreateThread(function()
        Wait(15000)
        if not Corex then
            print('[COREX-ZOMBIES-SERVER] ^1ERROR: Core init timed out^0')
        end
    end)
else
    print('[COREX-ZOMBIES-SERVER] ^2Successfully connected to COREX core^0')
end

local function ValidateLootItem(itemName, amount)
    if type(itemName) ~= 'string' or #itemName == 0 then return false end
    if type(amount) ~= 'number' or amount < 1 or amount > 100 then return false end
    if not Config.LootSystem or not Config.LootSystem.lootTables then return true end

    for _, tier in pairs(Config.LootSystem.lootTables) do
        for _, item in ipairs(tier.items or {}) do
            if item.name == itemName then
                if amount < item.min or amount > (item.max * 3) then
                    return false
                end
                return true
            end
        end
    end
    return false
end

RegisterNetEvent('corex-zombies:server:dropLoot', function(coords, itemName, amount, rarity, zombieId)
    local src = source
    if not src or src == 0 then return end

    if type(zombieId) ~= 'string' or #zombieId == 0 or #zombieId > 64 then
        if Config.Debug then print('^1[COREX-ZOMBIES] dropLoot REJECTED: missing zombieId^0') end
        return
    end

    if lootedZombies[zombieId] then
        if Config.Debug then print('^1[COREX-ZOMBIES] dropLoot REJECTED: zombie already looted ' .. zombieId .. '^0') end
        return
    end

    if not ValidateLootItem(itemName, amount) then
        if Config.Debug then
            print(('^1[COREX-ZOMBIES] dropLoot REJECTED: invalid item %s x%d^0'):format(tostring(itemName), tonumber(amount) or 0))
        end
        return
    end

    local ped = Corex.Functions.GetPlayerPed(src)
    if not ped or ped == 0 then return end

    local playerCoords = Corex.Functions.GetCoords(ped)
    local dx = playerCoords.x - (coords and coords.x or 0)
    local dy = playerCoords.y - (coords and coords.y or 0)
    local dz = playerCoords.z - (coords and coords.z or 0)
    local distSq = dx * dx + dy * dy + dz * dz
    if distSq > 22500.0 then
        if Config.Debug then
            print(('^1[COREX-ZOMBIES] dropLoot REJECTED: player %d too far (%.0fm)^0'):format(src, math.sqrt(distSq)))
        end
        return
    end

    lootedZombies[zombieId] = os.time()
    lootedZombiesOrder[#lootedZombiesOrder + 1] = zombieId

    if #lootedZombiesOrder > MAX_LOOTED_TRACKED then
        local evictId = table.remove(lootedZombiesOrder, 1)
        lootedZombies[evictId] = nil
    end

    TriggerEvent('corex-inventory:server:addLootItem', src, itemName, amount, coords)

    if Config.Debug then
        print('^2[COREX-ZOMBIES] Dropped loot: ' .. itemName .. ' x' .. amount .. ' (' .. tostring(rarity) .. ')^0')
    end
end)

RegisterNetEvent('corex-zombies:server:sharedBatchSpawned', function(batchId, spawnedZombies)
    local src = source
    local batch = sharedZombieBatches[batchId]
    if not batch or batch.hostSource ~= src or type(spawnedZombies) ~= 'table' then
        return
    end

    local spawnedIds = {}

    for _, zombie in ipairs(spawnedZombies) do
        local sharedId = zombie and zombie.id
        local batchZombie = sharedId and batch.zombies[sharedId]
        local netId = zombie and tonumber(zombie.netId)

        if batchZombie and netId and netId > 0 then
            batchZombie.netId = netId
            batchZombie.ownerSource = src
            batchZombie.coords = vector3(
                tonumber(zombie.coords and zombie.coords.x) or batchZombie.coords.x,
                tonumber(zombie.coords and zombie.coords.y) or batchZombie.coords.y,
                tonumber(zombie.coords and zombie.coords.z) or batchZombie.coords.z
            )
            sharedZombieIndex[sharedId] = batchZombie
            spawnedIds[sharedId] = true
        end
    end

    for sharedId in pairs(batch.zombies) do
        if not spawnedIds[sharedId] then
            batch.zombies[sharedId] = nil
            sharedZombieIndex[sharedId] = nil
        end
    end

    if next(batch.zombies) == nil then
        ClearSharedBatch(batchId, 'spawn_failed')
        return
    end

    DSync(('batch=%s registered %d shared network zombies'):format(batchId, CountBatchZombies(batch)))
end)

RegisterNetEvent('corex-zombies:server:sharedZombieDied', function(batchId, zombieId)
    local src = source
    local batch = sharedZombieBatches[batchId]
    if not batch or type(zombieId) ~= 'string' then
        return
    end

    local zombie = batch.zombies[zombieId]
    if not zombie then
        return
    end

    if batch.hostSource and src ~= batch.hostSource and src ~= zombie.ownerSource then
        return
    end

    batch.zombies[zombieId] = nil
    sharedZombieIndex[zombieId] = nil

    DSync(('batch=%s zombie=%s removed by src=%d'):format(batchId, zombieId, src))

    if next(batch.zombies) == nil then
        ClearSharedBatch(batchId, 'all_dead')
    end
end)

RegisterNetEvent('corex-zombies:server:requestSharedZoneSync', function()
    local src = source
    local now = GetGameTimer()
    if lastSharedZoneSync[src] and (now - lastSharedZoneSync[src]) < 3000 then
        return
    end

    lastSharedZoneSync[src] = now

    local playerCoords = GetPlayerCoords(src)
    if playerCoords then
        for _, batch in pairs(sharedZombieBatches) do
            if not batch.hostSource and batch.center and Dist(playerCoords, batch.center) <= (batch.radius + 150.0) then
                batch.hostSource = src

                local payload = {
                    center = SerializeVec3(batch.center),
                    radius = batch.radius,
                    eventId = batch.eventId,
                    zombies = {},
                }

                for zombieId, zombie in pairs(batch.zombies) do
                    payload.zombies[#payload.zombies + 1] = {
                        id = zombieId,
                        netId = zombie.netId,
                        typeId = zombie.typeId,
                        coords = SerializeVec3(zombie.coords),
                    }
                end

                TriggerClientEvent('corex-zombies:client:adoptSharedBatch', src, batch.id, payload)
                BroadcastSharedZone(batch)
            end
        end
    end

    TriggerClientEvent('corex-zombies:client:sharedZoneSnapshot', src, GetSharedZoneSnapshotForPlayer(src))
end)

CreateThread(function()
    while true do
        Wait(300000)
        local now = os.time()
        local kept = {}
        for i, id in ipairs(lootedZombiesOrder) do
            local t = lootedZombies[id]
            if t and (now - t) < 1800 then
                kept[#kept + 1] = id
            else
                lootedZombies[id] = nil
            end
        end
        lootedZombiesOrder = kept
    end
end)

RegisterCommand('spawnzombie', function(source, args, rawCommand)
    if source ~= 0 then
        if not Corex.Functions.IsPlayerAceAllowed(source, 'corex.admin') then
            TriggerClientEvent('corex:notify', source, 'No permission', 'error', 3000)
            return
        end
    end

    local count = math.min(tonumber(args[1]) or 1, 10)
    local typeId = args[2]

    if source == 0 then
        for _, playerId in ipairs(Corex.Functions.GetPlayers()) do
            TriggerClientEvent('corex-zombies:client:forceSpawn', tonumber(playerId), count, typeId)
        end
        print('^2[COREX-ZOMBIES] Spawning ' .. count .. ' ' .. (typeId or 'random') .. ' zombies^0')
    else
        TriggerClientEvent('corex-zombies:client:forceSpawn', source, count, typeId)
        TriggerClientEvent('corex:notify', source, 'Spawning ' .. count .. ' ' .. (typeId or 'random') .. ' zombies', 'success', 3000)
    end
end, true)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    zombieLootCooldowns = {}
    activeZombieCount = 0
    sharedZombieBatches = {}
    sharedZombieIndex = {}
    lastSharedZoneSync = {}
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastSharedZoneSync[src] = nil

    for _, batch in pairs(sharedZombieBatches) do
        if batch.hostSource == src then
            SetTimeout((Config.Sync and Config.Sync.OwnershipMigrationDelay) or 500, function()
                local liveBatch = sharedZombieBatches[batch.id]
                if liveBatch and liveBatch.hostSource == src then
                    AdoptSharedBatch(liveBatch)
                end
            end)
        end
    end
end)

exports('CreateSharedBatch', CreateSharedBatch)
exports('ClearSharedBatch', ClearSharedBatch)
