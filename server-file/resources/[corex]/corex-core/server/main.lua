COREX = COREX or {}
Corex = COREX

Corex.Functions = Corex.Functions or {}
Corex.ServerCallbacks = Corex.ServerCallbacks or {}
Corex.Config = Config

local isInitialized = false
local callbackCooldowns = {}

local function Initialize()
    if isInitialized then return end

    print('^2======================================================^7')
    print('^2           COREX Framework v' .. Config.Version .. '^7')
    print('^2           Zombie Survival Framework^7')
    print('^2======================================================^7')

    isInitialized = true

    if COREX and COREX.Debug then
        COREX.Debug.Print('^2[COREX] ^7Server-side core initialized')
    end

    TriggerEvent(Config.EventPrefix .. ':server:ready')
    TriggerEvent('corex:server:coreReady', Corex)
end

local function NormalizeVehicleKey(value)
    if type(value) ~= 'string' then return nil end
    return string.lower(value)
end

function Corex.Functions.GetVehicleCatalog(catalogId)
    local key = NormalizeVehicleKey(catalogId)
    if not key or not Corex.SharedVehicles or not Corex.SharedVehicles[key] then
        return nil
    end
    return COREX.Utils.DeepCopy(Corex.SharedVehicles[key])
end

function Corex.Functions.GetVehicleDefinition(catalogId, model)
    local catalog = Corex.Functions.GetVehicleCatalog(catalogId)
    local target = NormalizeVehicleKey(model)
    if not catalog or not target then
        return nil
    end

    for _, vehicle in ipairs(catalog.vehicles or {}) do
        if NormalizeVehicleKey(vehicle.model) == target then
            return vehicle
        end
    end

    return nil
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Initialize()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    if COREX.Player and COREX.Player.SaveAll then
        COREX.Player.SaveAll(true)
    end

    if COREX and COREX.Debug then
        COREX.Debug.Print('^3[COREX] ^7Server-side core stopped — all players saved')
    end
end)

function Corex.Functions.GetCoords(entity)
    if not entity or entity == 0 then return vector4(0, 0, 0, 0) end
    local coords = GetEntityCoords(entity)
    local heading = GetEntityHeading(entity)
    return vector4(coords.x, coords.y, coords.z, heading)
end

function Corex.Functions.GetIdentifier(source, idType)
    if Corex.GetIdentifier then
        return Corex.GetIdentifier(source, idType)
    end
    return GetPlayerIdentifierByType(source, idType or 'license')
end

function Corex.Functions.Notify(source, message, type, duration, title)
    TriggerClientEvent(Config.EventPrefix .. ':notify', source, message, type or 'info', duration, title)
end

function Corex.Functions.KickPlayer(source, reason)
    DropPlayer(source, reason or 'Kicked from server')
    if COREX and COREX.Debug then
        COREX.Debug.Info('[COREX] Player kicked: ' .. source .. ' - ' .. (reason or 'No reason'))
    end
end

function Corex.Functions.GetPlayerPed(source)
    return GetPlayerPed(source)
end

function Corex.Functions.SetEntityHealth(entityOrSource, health)
    if not entityOrSource or entityOrSource == 0 then return false end
    local clampedHealth = math.max(0, math.min(200, tonumber(health) or 0))
    TriggerClientEvent(Config.EventPrefix .. ':client:setHealth', entityOrSource, clampedHealth)
    return true
end

function Corex.Functions.SetPlayerHealth(source, health)
    if not source or source == 0 then return false end
    local clampedHealth = math.max(0, math.min(200, tonumber(health) or 0))
    TriggerClientEvent(Config.EventPrefix .. ':client:setHealth', source, clampedHealth)
    return true
end

function Corex.Functions.GetEntityHealth(entity)
    return 0
end

function Corex.Functions.DoesEntityExist(entity)
    if not entity or entity == 0 then return false end
    return DoesEntityExist(entity)
end

function Corex.Functions.GetPlayers()
    return GetPlayers()
end

function Corex.Functions.GetPlayerName(source)
    return GetPlayerName(source)
end

function Corex.Functions.IsPlayerAceAllowed(source, permission)
    return IsPlayerAceAllowed(source, permission)
end

function Corex.Functions.GetGameTimer()
    return GetGameTimer()
end

function Corex.Functions.NetworkGetPlayerIndexFromPed(ped)
    return NetworkGetPlayerIndexFromPed(ped)
end

function Corex.Functions.GetPlayerServerId(playerIndex)
    return GetPlayerServerId(playerIndex)
end

function Corex.Functions.CreateCallback(name, handler)
    Corex.ServerCallbacks[name] = handler
    if COREX and COREX.Debug then
        COREX.Debug.Verbose('[COREX] Registered callback: ' .. name)
    end
end

local pendingServerCallbacks = {}
local serverCallbackCounter = 0

function Corex.Functions.TriggerClientCallback(source, name, cb, ...)
    serverCallbackCounter = serverCallbackCounter + 1
    local callbackId = 'scb_' .. serverCallbackCounter .. '_' .. GetGameTimer()

    if type(cb) == 'function' then
        pendingServerCallbacks[callbackId] = {
            cb = cb,
            expiresAt = GetGameTimer() + 10000,
        }
    end

    TriggerClientEvent(Config.EventPrefix .. ':server:callback', source, callbackId, name, ...)
end

RegisterNetEvent(Config.EventPrefix .. ':server:callback:response', function(callbackId, result)
    local src = source
    if type(callbackId) ~= 'string' then return end
    local entry = pendingServerCallbacks[callbackId]
    if not entry then return end
    pendingServerCallbacks[callbackId] = nil
    if type(entry.cb) == 'function' then
        entry.cb(result)
    end
end)

CreateThread(function()
    while true do
        Wait(30000)
        local now = GetGameTimer()
        for id, entry in pairs(pendingServerCallbacks) do
            if now >= entry.expiresAt then
                if type(entry.cb) == 'function' then
                    entry.cb(nil)
                end
                pendingServerCallbacks[id] = nil
            end
        end
    end
end)

local function GetCoreObject(filters)
    if not filters then return Corex end

    local results = {}
    for i = 1, #filters do
        local key = filters[i]
        if Corex[key] then
            results[key] = Corex[key]
        end
    end
    return results
end

exports('GetCoreObject', GetCoreObject)
exports('IsReady', function() return Corex ~= nil end)
exports('GetVehicleCatalog', function(catalogId) return Corex.Functions.GetVehicleCatalog(catalogId) end)
exports('GetVehicleDefinition', function(catalogId, model) return Corex.Functions.GetVehicleDefinition(catalogId, model) end)

local CALLBACK_RATE_LIMIT_MS = 500

RegisterNetEvent(Config.EventPrefix .. ':callback:request', function(callbackId, name, ...)
    local src = source
    if not src or src == 0 then return end
    if type(callbackId) ~= 'string' or type(name) ~= 'string' then return end

    local now = GetGameTimer()
    local lastCall = callbackCooldowns[src]
    if lastCall and (now - lastCall) < CALLBACK_RATE_LIMIT_MS then
        TriggerClientEvent(Config.EventPrefix .. ':callback:response', src, callbackId, nil)
        return
    end
    callbackCooldowns[src] = now

    if Corex.ServerCallbacks[name] then
        local ok, result = pcall(Corex.ServerCallbacks[name], src, ...)
        if ok then
            TriggerClientEvent(Config.EventPrefix .. ':callback:response', src, callbackId, result)
        else
            if COREX and COREX.Debug then
                COREX.Debug.Error('[Callback] ' .. name .. ' errored: ' .. tostring(result))
            end
            TriggerClientEvent(Config.EventPrefix .. ':callback:response', src, callbackId, nil)
        end
    else
        TriggerClientEvent(Config.EventPrefix .. ':callback:response', src, callbackId, nil)
    end
end)
