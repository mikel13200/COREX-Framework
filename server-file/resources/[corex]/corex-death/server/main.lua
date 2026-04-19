local function GetPlayer(src)
    local success, player = pcall(function()
        return exports['corex-core']:GetPlayer(src)
    end)
    return success and player or nil
end

local function SetStat(src, stat, value)
    pcall(function()
        exports['corex-core']:SetStat(src, stat, value)
    end)
end

local function SavePlayer(src)
    pcall(function()
        exports['corex-core']:SavePlayer(src, true)
    end)
end

local function SetPlayerState(src, state)
    pcall(function()
        exports['corex-core']:SetPlayerState(src, state)
    end)
end

local function SyncStateBag(src, key, value)
    local pState = Player(src).state
    if pState then
        pState:set(key, value, true)
    end
end

local function DropRandomItems(src, coords)
    if not coords then return end

    local success, inventory = pcall(function()
        return exports['corex-inventory']:GetInventory(src)
    end)
    if not success or not inventory then return end

    local items = {}
    for slot, item in pairs(inventory) do
        if item and item.name and item.count and item.count > 0 then
            items[#items + 1] = { slot = slot, name = item.name, count = item.count }
        end
    end

    if #items == 0 then return end

    local dropCount = math.max(1, math.floor(#items * Config.Penalties.loseItemsPercent))

    local shuffled = {}
    for i, v in ipairs(items) do
        shuffled[i] = v
    end
    for i = #shuffled, 2, -1 do
        local j = math.random(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    for i = 1, math.min(dropCount, #shuffled) do
        local item = shuffled[i]
        pcall(function()
            exports['corex-inventory']:DropItem(
                src,
                item.name,
                item.count,
                item.slot,
                vector3(coords.x, coords.y, coords.z)
            )
        end)

        if Config.Debug then
            print(('[COREX-DEATH] Dropped %dx %s from player %d'):format(item.count, item.name, src))
        end
    end
end

local lastDeathLog = {}
local DEATH_LOG_RATE_MS = 5000

RegisterNetEvent('corex-death:server:playerDied', function(coords)
    local src = source
    local player = GetPlayer(src)
    if not player then return end

    if type(coords) ~= 'table' and type(coords) ~= 'vector3' then return end
    local cx = tonumber(coords.x) or 0
    local cy = tonumber(coords.y) or 0
    local cz = tonumber(coords.z) or 0

    local now = GetGameTimer()
    if lastDeathLog[src] and (now - lastDeathLog[src]) < DEATH_LOG_RATE_MS then return end
    lastDeathLog[src] = now

    SetPlayerState(src, 'dead')
    TriggerEvent('corex-spawn:server:playerDied', src)

    if Config.Debug then
        print(('[COREX-DEATH] %s (ID: %d) died at %.1f, %.1f, %.1f'):format(
            player.name, src, cx, cy, cz
        ))
    end
end)

AddEventHandler('playerDropped', function()
    lastDeathLog[source] = nil
end)

AddEventHandler('corex:server:playerReady', function(source, player)
    if not player or not player.metadata then
        return
    end

    if player.metadata.lifecycleState ~= 'dead' then
        return
    end

    CreateThread(function()
        Wait(1500)
        TriggerClientEvent('corex-death:client:resumeDeath', source)
    end)
end)

RegisterNetEvent('corex-death:server:requestRespawn', function(deathCoords)
    local src = source
    local player = GetPlayer(src)
    if not player then return end

    if Config.Penalties.loseItems and deathCoords then
        DropRandomItems(src, deathCoords)
    end

    SetStat(src, 'hunger', Config.Penalties.resetHunger)
    SetStat(src, 'thirst', Config.Penalties.resetThirst)
    SetStat(src, 'infection', Config.Penalties.resetInfection)

    SyncStateBag(src, 'hunger', Config.Penalties.resetHunger)
    SyncStateBag(src, 'thirst', Config.Penalties.resetThirst)
    SyncStateBag(src, 'infection', Config.Penalties.resetInfection)

    SetPlayerState(src, 'loading')
    SavePlayer(src)
    TriggerClientEvent('corex-death:client:prepareRespawn', src)
    TriggerClientEvent('corex-spawn:client:clearSpawnFlags', src)
    TriggerClientEvent('corex-spawn:client:spawnPlayer', src, {
        isNew = false,
        position = nil,
        skin = player.metadata and player.metadata.skin or nil,
        isRespawn = true,
        isResourceRestart = false,
        playerData = {
            name = player.name,
            money = player.money,
            metadata = player.metadata
        }
    })

    if Config.Debug then
        print(('[COREX-DEATH] %s (ID: %d) respawned'):format(player.name, src))
    end
end)
