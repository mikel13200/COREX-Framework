--[[
    COREX Weather - Server Side (v2.0)
    Weather and time synchronization system
]]

local CurrentWeather = Config.Weather.DefaultWeather
local CurrentHour = Config.Time.DefaultHour
local CurrentMinute = Config.Time.DefaultMinute
local Blackout = Config.Weather.Blackout
local TimeFreeze = Config.Time.FreezeTime ~= false

local function IsPlayerAdmin(src)
    if IsPlayerAceAllowed(src, 'corex.admin') then return true end
    if Config.UseAcePermissions then
        return IsPlayerAceAllowed(src, 'corex.weather.admin')
    end

    local player = COREX and COREX.Functions and COREX.Functions.GetPlayer and COREX.Functions.GetPlayer(src)

    local playerIdentifiers = {}
    if player then
        playerIdentifiers[1] = player.identifier
    else
        playerIdentifiers[1] = GetPlayerIdentifierByType(src, 'license')
        playerIdentifiers[2] = GetPlayerIdentifierByType(src, 'fivem')
        playerIdentifiers[3] = GetPlayerIdentifierByType(src, 'discord')
        playerIdentifiers[4] = GetPlayerIdentifierByType(src, 'steam')
    end

    for _, adminId in ipairs(Config.Admins) do
        for _, playerId in ipairs(playerIdentifiers) do
            if playerId and playerId == adminId then
                return true
            end
        end
    end
    return false
end

local function Notify(src, message, type)
    if COREX and COREX.Functions and COREX.Functions.GetPlayer then
        local Player = COREX.Functions.GetPlayer(src)
        if Player then
            TriggerClientEvent('corex:notify', src, message, type or 'info')
            return
        end
    end

    TriggerClientEvent('chat:addMessage', src, {
        color = {100, 200, 255},
        args = {'[Weather]', message}
    })
end

local function NotifyAll(message)
    TriggerClientEvent('chat:addMessage', -1, {
        color = {100, 200, 255},
        multiline = true,
        args = {'[Weather]', message}
    })
end

local function GetRandomWeather()
    local totalWeight = 0
    for weather, weight in pairs(Config.WeatherProbabilities) do
        totalWeight = totalWeight + weight
    end

    if totalWeight == 0 then return 'CLEAR' end

    local random = math.random(1, totalWeight)
    local cumulative = 0

    for weather, weight in pairs(Config.WeatherProbabilities) do
        cumulative = cumulative + weight
        if random <= cumulative and weight > 0 then
            return weather
        end
    end

    return 'CLEAR'
end

local function SyncWeatherTime()
    TriggerClientEvent('corex-weather:client:sync', -1, {
        weather = CurrentWeather,
        hour = CurrentHour,
        minute = CurrentMinute,
        blackout = Blackout,
        transitionTime = Config.Weather.TransitionTime
    })
end

-- Time advancer — ticks per in-game minute, but only broadcasts to all
-- clients every N in-game minutes (the client interpolates between syncs).
-- This replaces a TriggerClientEvent(-1) every 30s with one every 5 minutes,
-- cutting weather broadcasts by ~10x on a typical server.
local TIME_BROADCAST_INTERVAL = 5   -- in-game minutes between full syncs
local minutesSinceBroadcast = 0

CreateThread(function()
    while true do
        Wait(Config.Time.SecondsPerMinute * 1000)

        if Config.Time.EnableTimeCycle and not TimeFreeze then
            CurrentMinute = CurrentMinute + 1

            if CurrentMinute >= 60 then
                CurrentMinute = 0
                CurrentHour = CurrentHour + 1

                if CurrentHour >= 24 then
                    CurrentHour = 0
                end

                if Config.Time.SkipDaylight and CurrentHour == 6 then
                    CurrentHour = 21
                    SyncWeatherTime()
                end
            end

            if COREX and COREX.Debug then
                COREX.Debug.Verbose('[WEATHER] Time: ' .. string.format('%02d:%02d', CurrentHour, CurrentMinute))
            end

            minutesSinceBroadcast = minutesSinceBroadcast + 1
            if minutesSinceBroadcast >= TIME_BROADCAST_INTERVAL then
                minutesSinceBroadcast = 0
                SyncWeatherTime()
            end
        end
    end
end)

CreateThread(function()
    Wait(5000)
    SyncWeatherTime()

    if COREX and COREX.Debug then
        COREX.Debug.Info('[WEATHER] Weather system initialized')
    else
        print('[WEATHER] ^2Weather system initialized^0')
    end

    while true do
        Wait(Config.Weather.ChangeInterval * 60 * 1000)

        if Config.Weather.EnableDynamicWeather then
            local newWeather = GetRandomWeather()

            local attempts = 0
            while newWeather == CurrentWeather and attempts < 3 do
                newWeather = GetRandomWeather()
                attempts = attempts + 1
            end

            CurrentWeather = newWeather

            if COREX and COREX.Debug then
                COREX.Debug.Info('[WEATHER] Dynamic weather changed to: ' .. newWeather)
            else
                print('[WEATHER] ^3Dynamic weather changed to: ^7' .. newWeather)
            end
            SyncWeatherTime()
        end
    end
end)

RegisterNetEvent('corex-weather:server:requestSync', function()
    local src = source
    if not src or src == 0 then return end
    TriggerClientEvent('corex-weather:client:sync', src, {
        weather = CurrentWeather,
        hour = CurrentHour,
        minute = CurrentMinute,
        blackout = Blackout,
        transitionTime = 0.0
    })
end)

RegisterCommand('setweather', function(source, args)
    local src = source

    if src > 0 and not IsPlayerAdmin(src) then
        Notify(src, 'No permission!', 'error')
        return
    end

    local weather = args[1] and string.upper(args[1]) or nil

    if not weather then
        Notify(src, 'Usage: /setweather [FOGGY/THUNDER/RAIN/OVERCAST/CLOUDS]', 'info')
        return
    end

    if Config.WeatherProbabilities[weather] == nil then
        Notify(src, 'Invalid weather type!', 'error')
        return
    end

    CurrentWeather = weather
    SyncWeatherTime()
    print('[WEATHER] ^2Admin set weather to: ^7' .. weather)
    NotifyAll('Weather changed: ' .. weather)
end, true)

RegisterCommand('settime', function(source, args)
    local src = source

    if src > 0 and not IsPlayerAdmin(src) then
        Notify(src, 'No permission!', 'error')
        return
    end

    local hour = tonumber(args[1])
    local minute = tonumber(args[2]) or 0

    if not hour or hour < 0 or hour > 23 then
        Notify(src, 'Usage: /settime [0-23] [0-59]', 'error')
        return
    end

    if minute < 0 or minute > 59 then minute = 0 end

    CurrentHour = hour
    CurrentMinute = minute
    SyncWeatherTime()
    print('[WEATHER] ^2Admin set time to: ^7' .. string.format('%02d:%02d', hour, minute))
    NotifyAll('Time changed: ' .. string.format('%02d:%02d', hour, minute))
end, true)

RegisterCommand('freezetime', function(source)
    local src = source
    if src > 0 and not IsPlayerAdmin(src) then return end

    TimeFreeze = not TimeFreeze
    print('[WEATHER] ^3Time freeze: ^7' .. (TimeFreeze and 'enabled' or 'disabled'))
    NotifyAll('Time cycle: ' .. (TimeFreeze and 'frozen' or 'running'))
end, true)

RegisterCommand('blackout', function(source)
    local src = source
    if src > 0 and not IsPlayerAdmin(src) then return end

    Blackout = not Blackout
    SyncWeatherTime()
    print('[WEATHER] ^3Blackout: ^7' .. (Blackout and 'enabled' or 'disabled'))
    NotifyAll('Blackout: ' .. (Blackout and 'enabled' or 'disabled'))
end, true)

RegisterCommand('night', function(source)
    local src = source
    if src > 0 and not IsPlayerAdmin(src) then return end

    CurrentHour = 22
    CurrentMinute = 0
    CurrentWeather = 'FOGGY'
    SyncWeatherTime()
    print('[WEATHER] ^2Night mode activated^0')
    NotifyAll('Night mode with fog activated')
end, true)

exports('GetCurrentWeather', function() return CurrentWeather end)
exports('GetCurrentTime', function() return CurrentHour, CurrentMinute end)
exports('SetWeather', function(weather)
    if Config.WeatherProbabilities[weather] ~= nil then
        CurrentWeather = weather
        SyncWeatherTime()
        return true
    end
    return false
end)
exports('SetTime', function(hour, minute)
    if hour >= 0 and hour <= 23 then
        CurrentHour = hour
        CurrentMinute = minute or 0
        SyncWeatherTime()
        return true
    end
    return false
end)
exports('SetBlackout', function(state)
    Blackout = state
    SyncWeatherTime()
end)
exports('IsBlackout', function() return Blackout end)
exports('IsTimeFrozen', function() return TimeFreeze end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Blackout = false
    TimeFreeze = false
end)
