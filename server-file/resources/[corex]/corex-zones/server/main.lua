local Corex = nil

print('[COREX-ZONES-SERVER] ^3Initializing...^0')

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
            print('[COREX-ZONES-SERVER] ^2Successfully connected to COREX core^0')
        end
    end)
    CreateThread(function()
        Wait(15000)
        if not Corex then
            print('[COREX-ZONES-SERVER] ^1ERROR: Core init timed out^0')
        end
    end)
else
    print('[COREX-ZONES-SERVER] ^2Successfully connected to COREX core^0')
end

local playersInZones = {}

local function DistanceSq(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return dx * dx + dy * dy + dz * dz
end

local function GetSafeZoneForCoords(coords)
    if not coords or not Config.SafeZones then return nil end

    for _, zone in ipairs(Config.SafeZones) do
        if zone.coords and zone.radius then
            local radius = tonumber(zone.radius) or 0
            if radius > 0 and DistanceSq(coords, zone.coords) <= (radius * radius) then
                return zone
            end
        end
    end

    return nil
end

local function SetPlayerSafeZone(src, zone)
    local zoneName = zone and zone.name or nil
    local oldZone = playersInZones[src]
    if oldZone == zoneName then return end

    if zoneName then
        playersInZones[src] = zoneName
        if Config.Debug then
            print('^2[COREX-ZONES] Server tracked player ' .. src .. ' in zone: ' .. zoneName .. '^0')
        end
    else
        playersInZones[src] = nil
        if oldZone and Config.Debug then
            print('^3[COREX-ZONES] Server tracked player ' .. src .. ' outside zone: ' .. oldZone .. '^0')
        end
    end
end

local function RefreshPlayerSafeZone(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then
        SetPlayerSafeZone(src, nil)
        return
    end

    local coords = GetEntityCoords(ped)
    if not coords or coords.x ~= coords.x or coords.y ~= coords.y or coords.z ~= coords.z then
        SetPlayerSafeZone(src, nil)
        return
    end

    SetPlayerSafeZone(src, GetSafeZoneForCoords(coords))
end

RegisterNetEvent('corex-zones:server:playerEnteredZone', function(zoneName)
    local src = source

    if Config.Debug then
        print('^5[COREX-ZONES] Ignored client enter report from ' .. src .. ': ' .. tostring(zoneName) .. '^0')
    end
end)

RegisterNetEvent('corex-zones:server:playerLeftZone', function(zoneName)
    local src = source

    if Config.Debug then
        print('^5[COREX-ZONES] Ignored client leave report from ' .. src .. ': ' .. tostring(zoneName) .. '^0')
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if playersInZones[src] then
        playersInZones[src] = nil
    end
end)

CreateThread(function()
    local interval = math.max(500, tonumber(Config.CheckInterval) or 500)

    while true do
        Wait(interval)

        for _, srcStr in ipairs(GetPlayers()) do
            local src = tonumber(srcStr)
            if src then
                RefreshPlayerSafeZone(src)
            end
        end
    end
end)

AddEventHandler('entityDamaged', function(victim, attacker, weapon, baseDamage)
    if not Config.Protection or not Config.Protection.antiGlitch then return end
    if not Corex or not Corex.Functions then return end

    local victimEntity = victim
    local attackerEntity = attacker

    if not Corex.Functions.DoesEntityExist(victimEntity) or not Corex.Functions.DoesEntityExist(attackerEntity) then return end

    local attackerPlayer = Corex.Functions.NetworkGetPlayerIndexFromPed(attackerEntity)
    if attackerPlayer == -1 then return end

    local attackerSrc = Corex.Functions.GetPlayerServerId(attackerPlayer)
    if not attackerSrc or attackerSrc <= 0 then return end

    if playersInZones[attackerSrc] then
        CancelEvent()
        if Config.Debug then
            print('^1[COREX-ZONES] Blocked damage from player ' .. attackerSrc .. ' (inside safe zone)^0')
        end
    end
end)

function IsPlayerInSafeZone(src)
    return playersInZones[src] ~= nil
end

function GetPlayerZone(src)
    return playersInZones[src]
end

function GetPlayersInZones()
    local copy = {}
    for src, zoneName in pairs(playersInZones) do
        copy[src] = zoneName
    end
    return copy
end

exports('IsPlayerInSafeZone', IsPlayerInSafeZone)
exports('GetPlayerZone', GetPlayerZone)
exports('GetPlayersInZones', GetPlayersInZones)
