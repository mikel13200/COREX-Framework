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

RegisterNetEvent('corex-zones:server:playerEnteredZone', function(zoneName)
    local src = source
    playersInZones[src] = zoneName

    if Config.Debug then
        print('^2[COREX-ZONES] Player ' .. src .. ' entered zone: ' .. zoneName .. '^0')
    end
end)

RegisterNetEvent('corex-zones:server:playerLeftZone', function(zoneName)
    local src = source
    playersInZones[src] = nil

    if Config.Debug then
        print('^3[COREX-ZONES] Player ' .. src .. ' left zone: ' .. zoneName .. '^0')
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if playersInZones[src] then
        playersInZones[src] = nil
    end
end)

AddEventHandler('entityDamaged', function(victim, attacker, weapon, baseDamage)
    if not Config.Protection or not Config.Protection.antiGlitch then return end

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
    return playersInZones
end

exports('IsPlayerInSafeZone', IsPlayerInSafeZone)
exports('GetPlayerZone', GetPlayerZone)
exports('GetPlayersInZones', GetPlayersInZones)
