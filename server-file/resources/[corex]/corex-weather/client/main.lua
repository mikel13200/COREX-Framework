--[[
    COREX Weather - Client Side
    Weather and time synchronization
]]

local Corex = nil

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
            print('[COREX-WEATHER] ^2Connected to corex-core^0')
        end
    end)
    CreateThread(function()
        Wait(15000)
        if not Corex then
            print('[COREX-WEATHER] ^1Core init timed out^0')
        end
    end)
else
    print('[COREX-WEATHER] ^2Connected to corex-core^0')
end

local Weather = 'OVERCAST'
local Hour = 21
local Minute = 0
local Blackout = false

AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Wait(1000)
        TriggerServerEvent('corex-weather:server:requestSync')
    end
end)

RegisterNetEvent('corex-weather:client:sync', function(data)
    Weather = data.weather or 'OVERCAST'
    Hour = data.hour or 21
    Minute = data.minute or 0
    Blackout = data.blackout or false
end)

-- Combined weather and time sync (optimized)
CreateThread(function()
    while true do
        -- Weather sync
        SetWeatherTypeNow(Weather)
        SetWeatherTypePersist(Weather)
        SetWeatherTypeNowPersist(Weather)
        SetOverrideWeather(Weather)
        SetArtificialLightsState(Blackout)
        
        if Weather == 'XMAS' or Weather == 'SNOWLIGHT' or Weather == 'BLIZZARD' then
            SetForceVehicleTrails(true)
            SetForcePedFootstepsTracks(true)
        else
            SetForceVehicleTrails(false)
            SetForcePedFootstepsTracks(false)
        end
        
        -- Time sync (every 2 seconds is enough)
        NetworkOverrideClockTime(Hour, Minute, 0)
        
        Wait(2000) -- Combined sync every 2 seconds
    end
end)

if Config and Config.Debug then
RegisterCommand('testweather', function()
    Weather = 'THUNDER'
end, false)

RegisterCommand('testtime', function(source, args)
    Hour = tonumber(args[1]) or 21
    Minute = 0
end, false)
end

exports('GetCurrentWeather', function() return Weather end)
exports('GetCurrentTime', function() return Hour, Minute end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    ClearTimecycleModifier()
    SetArtificialLightsState(false)
end)
