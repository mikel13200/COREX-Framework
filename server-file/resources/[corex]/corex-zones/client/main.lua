local Corex = nil
local isReady = false

print('[COREX-ZONES] ^3Initializing...^0')

local function InitCore()
    local success, core = pcall(function()
        return exports['corex-core']:GetCoreObject()
    end)
    if not success or not core or not core.Functions then return false end
    Corex = core
    return true
end

if not InitCore() then
    AddEventHandler('corex:client:coreReady', function(coreObj)
        if coreObj and coreObj.Functions and not Corex then
            Corex = coreObj
            isReady = true
            print('[COREX-ZONES] ^2Successfully connected to COREX core^0')
        end
    end)
    CreateThread(function()
        Wait(15000)
        if not Corex then
            print('[COREX-ZONES] ^1ERROR: Core init timed out^0')
        end
    end)
else
    isReady = true
    print('[COREX-ZONES] ^2Successfully connected to COREX core^0')
end

local currentZone = nil
local isInSafeZone = false
local spawnedBlips = {}

local function GetDistance(coords1, coords2)
    local dx = coords1.x - coords2.x
    local dy = coords1.y - coords2.y
    local dz = coords1.z - coords2.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function IsPlayerInZone(zone)
    if not isReady then return false end

    local ped = Corex.Functions.GetPed()
    local coords = Corex.Functions.GetCoords()

    local distance = GetDistance(coords, zone.coords)
    return distance <= zone.radius
end

local function GetNearestZone()
    if not isReady then return nil end

    local coords = Corex.Functions.GetCoords()
    local nearestZone = nil
    local nearestDistance = 999999.0

    for _, zone in ipairs(Config.SafeZones) do
        local distance = GetDistance(coords, zone.coords)
        if distance < nearestDistance then
            nearestDistance = distance
            nearestZone = zone
        end
    end

    return nearestZone, nearestDistance
end

local function ApplyProtection()
    if not isReady or not Config.Protection then return end

    local ped = Corex.Functions.GetPed()

    if Config.Protection.godMode then
        SetEntityInvincible(ped, true)
    end

    -- Weapon-disable controls must be re-asserted per-frame since
    -- DisableControlAction only affects the current frame.
    if Config.Protection.disableWeapons then
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 140, true)
        DisableControlAction(0, 141, true)
        DisableControlAction(0, 142, true)
        DisableControlAction(0, 257, true)
    end
end

local lastForceUnarmed = 0
local function ForceUnarmedInterval(ped)
    -- SetCurrentPedWeapon is expensive; only reassert periodically
    -- rather than every frame.
    local now = GetGameTimer()
    if now - lastForceUnarmed < 500 then return end
    lastForceUnarmed = now
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
end

local function RemoveProtection()
    if not isReady then return end

    local ped = Corex.Functions.GetPed()
    SetEntityInvincible(ped, false)
end

local function CreateZoneBlips()
    for _, zone in ipairs(Config.SafeZones) do
        if zone.blip and zone.blip.enabled then
            local blip = AddBlipForRadius(zone.coords.x, zone.coords.y, zone.coords.z, zone.radius)
            SetBlipHighDetail(blip, true)
            SetBlipColour(blip, zone.blip.color)
            SetBlipAlpha(blip, 128)

            local centerBlip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
            SetBlipSprite(centerBlip, zone.blip.sprite)
            SetBlipDisplay(centerBlip, 4)
            SetBlipScale(centerBlip, zone.blip.scale)
            SetBlipColour(centerBlip, zone.blip.color)
            SetBlipAsShortRange(centerBlip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(zone.blip.label)
            EndTextCommandSetBlipName(centerBlip)

            table.insert(spawnedBlips, blip)
            table.insert(spawnedBlips, centerBlip)
        end
    end
end

CreateThread(function()
    while not isReady do
        Wait(500)
    end

    CreateZoneBlips()
end)

CreateThread(function()
    while not isReady do
        Wait(1000)
    end

    while true do
        Wait(Config.CheckInterval or 500)

        local nearestZone, distance = GetNearestZone()

        if nearestZone and distance <= nearestZone.radius then
            if not isInSafeZone then
                isInSafeZone = true
                currentZone = nearestZone
                TriggerEvent('corex-zones:client:enteredSafeZone', nearestZone)
                TriggerServerEvent('corex-zones:server:playerEnteredZone', nearestZone.name)
            end
        else
            if isInSafeZone then
                isInSafeZone = false
                local oldZone = currentZone
                currentZone = nil
                TriggerEvent('corex-zones:client:leftSafeZone', oldZone)
                TriggerServerEvent('corex-zones:server:playerLeftZone', oldZone.name)
            end
        end
    end
end)

CreateThread(function()
    while not isReady do
        Wait(1000)
    end

    while true do
        if isInSafeZone then
            Wait(0)
            ApplyProtection()
            if Config.Protection and Config.Protection.disableWeapons then
                ForceUnarmedInterval(Corex.Functions.GetPed())
            end
        else
            Wait(500)
        end
    end
end)

AddEventHandler('corex-zones:client:enteredSafeZone', function(zone)
    if Config.Debug then
        print('^2[COREX-ZONES] Entered safe zone: ' .. zone.name .. '^0')
    end
    Corex.Functions.Notify('Entered Safe Zone: ' .. zone.name, 'success', 3000)
end)

AddEventHandler('corex-zones:client:leftSafeZone', function(zone)
    if Config.Debug then
        print('^3[COREX-ZONES] Left safe zone: ' .. zone.name .. '^0')
    end
    Corex.Functions.Notify('Left Safe Zone', 'warning', 3000)
    RemoveProtection()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    for _, blip in ipairs(spawnedBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
end)

function IsPlayerInSafeZone()
    return isInSafeZone
end

function GetNearestSafeZone()
    return GetNearestZone()
end

function GetSafeZones()
    return Config.SafeZones
end

-- Distance from coords to the NEAREST safe-zone boundary.
-- Returns (meters, zone). Negative when coords are inside the zone.
-- Used by corex-zombies to drive the population-scaling fear ramp.
function GetSafeZoneDistance(coords)
    if not coords or not Config.SafeZones then return 99999.0, nil end
    local best, bestZone = 99999.0, nil
    for _, zone in ipairs(Config.SafeZones) do
        local d = GetDistance(coords, zone.coords) - (zone.radius or 0)
        if d < best then
            best = d
            bestZone = zone
        end
    end
    return best, bestZone
end
