local Corex = nil
local hudVisible = true
local playerName = ''
local playerServerId = 0

local lastHealth = 100
local lastArmor = 0
local lastHunger = 100
local lastThirst = 100
local lastTalking = false

local STATUS_KEYS = { 'infection', 'poison', 'bleeding', 'sick', 'cold' }
local lastStatus = { infection = 0, poison = 0, bleeding = 0, sick = 0, cold = 0 }

local minimapScaleform = nil

local hud3DEnabled = Config.Enable3D
local minimapShown = Config.ShowMinimap

local function loadMinimapKvs()
    local keys = { x = 'corex_hud_minimap_x', y = 'corex_hud_minimap_y',
                   w = 'corex_hud_minimap_w', h = 'corex_hud_minimap_h',
                   alignX = 'corex_hud_minimap_alignX', alignY = 'corex_hud_minimap_alignY' }
    if not Config.Minimap then return end
    for field, key in pairs(keys) do
        local stored = GetResourceKvpString(key)
        if stored and stored ~= '' then
            if field == 'alignX' or field == 'alignY' then
                Config.Minimap[field] = stored
            else
                local n = tonumber(stored)
                if n then Config.Minimap[field] = n end
            end
        end
    end
end

loadMinimapKvs()

local function initializeHud()
    Corex = exports['corex-core']:GetCoreObject()

    if not Corex then
        if COREX and COREX.Debug then
            COREX.Debug.Error('[corex-hud] Failed to get COREX object')
        end
        return false
    end

    return true
end

local function getPlayerName()
    if Corex and Corex.Functions and Corex.Functions.GetName then
        local name = Corex.Functions.GetName()
        if name and name ~= 'Unknown' then
            return name
        end
    end

    return GetPlayerName(PlayerId()) or 'Unknown'
end

local function sendInit()
    SendNUIMessage({
        action = 'init',
        config = {
            showHealth = Config.ShowHealth,
            showArmor = Config.ShowArmor,
            showPlayerName = Config.ShowPlayerName,
            showHunger = Config.ShowHunger,
            showThirst = Config.ShowThirst,
            enable3D = hud3DEnabled,
            tiltAngle = Config.TiltAngle,
            position = Config.Position,
            minimap = Config.Minimap,
            showMinimap = minimapShown,
            hideMinimapHealthArmor = Config.HideMinimapHealthArmor,
            colors = Config.Colors,
            barWidth = Config.BarWidth,
            barHeight = Config.BarHeight
        }
    })
end

local function pushFullUpdate()
    SendNUIMessage({
        action = 'updateHud',
        health = lastHealth,
        armor = lastArmor,
        hunger = lastHunger,
        thirst = lastThirst,
        status = {
            infection = lastStatus.infection,
            poison = lastStatus.poison,
            bleeding = lastStatus.bleeding,
            sick = lastStatus.sick,
            cold = lastStatus.cold
        },
        playerName = playerName,
        playerId = playerServerId,
        talking = lastTalking
    })
end

local function pushPartialUpdate(payload)
    payload.action = 'updateHud'
    SendNUIMessage(payload)
end

local function showHud(visible)
    hudVisible = visible
    SendNUIMessage({
        action = 'setVisible',
        visible = visible
    })
end

local function shouldHideHud()
    if Config.HideWhenDead and Corex.Functions.IsDead() then
        return true
    end

    if Config.HideInVehicle and Corex.Functions.IsInVehicle() then
        return true
    end

    if IsPauseMenuActive() then
        return true
    end

    return false
end

local hudComponents = {
    1, 2, 3, 4, 6, 7, 8, 9, 13, 17, 18, 19, 20, 21, 22
}

local function ShouldShowNativeAmmoHud()
    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return false
    end

    if IsEntityDead(ped) then
        return false
    end

    return IsPedArmed(ped, 4)
end

local function applyRuntimeMinimapLayout()
    if not Config.ShowMinimap or not Config.Minimap then
        return
    end

    local mm = Config.Minimap

    if mm.useTopLeftPreset then
        local offsetX = tonumber(mm.presetOffsetX) or 0.0
        local offsetY = tonumber(mm.presetOffsetY) or 0.0

        SetMinimapComponentPosition('minimap', 'L', 'T', -0.0045 + offsetX, -0.022 + offsetY, 0.210, 0.258888)
        SetMinimapComponentPosition('minimap_mask', 'L', 'B', 0.0 + offsetX, -0.65 - offsetY, 0.210, 0.258888)
        SetMinimapComponentPosition('minimap_blur', 'L', 'T', -0.04 + offsetX, -0.058 + offsetY, 0.370, 0.337)
        return
    end

    if mm.useBottomLeftPreset then
        local offsetX = tonumber(mm.presetOffsetX) or 0.0
        local offsetY = tonumber(mm.presetOffsetY) or 0.0

        SetMinimapComponentPosition('minimap', 'L', 'B', -0.0045 + offsetX, 0.002 + offsetY, 0.150, 0.188888)
        SetMinimapComponentPosition('minimap_mask', 'L', 'B', 0.020 + offsetX, 0.032 + offsetY, 0.111, 0.159)
        SetMinimapComponentPosition('minimap_blur', 'L', 'B', -0.03 + offsetX, 0.022 + offsetY, 0.266, 0.237)
        return
    end

    if mm.useCustomLayout and Corex and Corex.Functions and Corex.Functions.SetMinimapLayout then
        Corex.Functions.SetMinimapLayout(mm.x, mm.y, mm.w, mm.h, mm.alignX, mm.alignY)
    end
end

CreateThread(function()
    -- Gate scaleform request on session + player readiness. Requesting
    -- scaleform before the session is up leaves a half-initialized movie
    -- handle that the HUD subsystem dereferences on its next RunUpdate
    -- tick — one of the known triggers of the virginia-october-hydrogen
    -- crash (GameSkeleton null deref on first post-spawn frame).
    while not NetworkIsSessionStarted() do Wait(100) end
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end
    while not DoesEntityExist(PlayerPedId()) do Wait(100) end

    if Config.HideMinimapHealthArmor then
        minimapScaleform = RequestScaleformMovie('minimap')

        -- Wait(50) instead of Wait(0) — scaleform loads on a background
        -- thread; tight polling just burns frames during spawn.
        local t = GetGameTimer()
        while not HasScaleformMovieLoaded(minimapScaleform) do
            Wait(50)
            if GetGameTimer() - t > 5000 then
                print('[COREX-HUD] ^3scaleform load timeout — bailing^0')
                minimapScaleform = nil
                break
            end
        end

        -- Removed the bigmap double-toggle; the main loop (line ~213)
        -- already handles minimap layout correctly.
    end

    local componentCount = #hudComponents
    while true do
        if hudVisible then
            for i = 1, componentCount do
                HideHudComponentThisFrame(hudComponents[i])
            end

            if ShouldShowNativeAmmoHud() then
                DisplayAmmoThisFrame(true)
            end

            if not minimapShown then
                DisplayRadar(false)
            else
                DisplayRadar(true)
                applyRuntimeMinimapLayout()
                if Config.Minimap and Config.Minimap.forceSmall and IsBigmapActive() then
                    SetBigmapActive(false, false)
                end

                if Config.HideMinimapHealthArmor and minimapScaleform then
                    BeginScaleformMovieMethod(minimapScaleform, 'SETUP_HEALTH_ARMOUR')
                    ScaleformMovieMethodAddParamInt(3)
                    EndScaleformMovieMethod()
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

local function applyMinimapLayout()
    if not minimapShown or not Config.Minimap then return end

    local mm = Config.Minimap

    applyRuntimeMinimapLayout()

    if mm.useCustomLayout or mm.useTopLeftPreset then
        -- Force the radar scaleform to re-read the new component positions.
        SetBigmapActive(true, false)
        Wait(0)
        SetBigmapActive(false, false)
    elseif mm.forceSmall then
        SetBigmapActive(false, false)
    end

    if mm.hideFogOfWar then
        SetMinimapHideFow(true)
    end
end

CreateThread(function()
    while not initializeHud() do
        Wait(1000)
    end

    Wait(2000)

    playerName = getPlayerName()
    playerServerId = GetPlayerServerId(PlayerId())

    sendInit()
    applyMinimapLayout()
    showHud(true)

    local ped = Corex.Functions.GetPed()
    lastHealth = Corex.Functions.GetHealth()
    lastArmor = math.max(0, math.min(100, Corex.Functions.GetArmour()))

    local state = LocalPlayer.state
    lastHunger = tonumber(state.hunger) or 100
    lastThirst = tonumber(state.thirst) or 100
    for _, key in ipairs(STATUS_KEYS) do
        lastStatus[key] = tonumber(state[key]) or 0
    end

    pushFullUpdate()

    while true do
        ped = Corex.Functions.GetPed()

        if shouldHideHud() then
            if hudVisible then
                showHud(false)
            end
        else
            if not hudVisible then
                showHud(true)
            end

            local health = Corex.Functions.GetHealth()
            local armor = math.max(0, math.min(100, Corex.Functions.GetArmour()))
            local hunger = tonumber(LocalPlayer.state.hunger) or lastHunger
            local thirst = tonumber(LocalPlayer.state.thirst) or lastThirst

            local talking = NetworkIsPlayerTalking(PlayerId())
            local dirty = false
            local payload = {}

            if health ~= lastHealth then
                lastHealth = health
                payload.health = health
                dirty = true
            end
            if armor ~= lastArmor then
                lastArmor = armor
                payload.armor = armor
                dirty = true
            end
            if hunger ~= lastHunger then
                lastHunger = hunger
                payload.hunger = hunger
                dirty = true
            end
            if thirst ~= lastThirst then
                lastThirst = thirst
                payload.thirst = thirst
                dirty = true
            end
            if talking ~= lastTalking then
                lastTalking = talking
                payload.talking = talking
                dirty = true
            end

            if dirty then
                pushPartialUpdate(payload)
            end
        end

        Wait(Config.UpdateInterval or 200)
    end
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end

    local serverId = GetPlayerServerId(PlayerId())
    playerServerId = serverId
    local playerBag = ('player:%s'):format(serverId)

    AddStateBagChangeHandler('hunger', playerBag, function(_, _, value)
        if value ~= nil then
            lastHunger = tonumber(value) or 100
            pushPartialUpdate({ hunger = lastHunger })
        end
    end)

    AddStateBagChangeHandler('thirst', playerBag, function(_, _, value)
        if value ~= nil then
            lastThirst = tonumber(value) or 100
            pushPartialUpdate({ thirst = lastThirst })
        end
    end)

    for _, key in ipairs(STATUS_KEYS) do
        local capturedKey = key
        AddStateBagChangeHandler(capturedKey, playerBag, function(_, _, value)
            local v = tonumber(value) or 0
            lastStatus[capturedKey] = v
            local status = {}
            status[capturedKey] = v
            pushPartialUpdate({ status = status })
        end)
    end

    AddStateBagChangeHandler('name', playerBag, function(_, _, value)
        if value then
            playerName = value
            pushPartialUpdate({ playerName = playerName })
        end
    end)
end)

RegisterNetEvent('corex:client:playerLoaded', function()
    Wait(1000)
    playerName = getPlayerName()
    playerServerId = GetPlayerServerId(PlayerId())

    local state = LocalPlayer.state
    lastHunger = tonumber(state.hunger) or 100
    lastThirst = tonumber(state.thirst) or 100
    for _, key in ipairs(STATUS_KEYS) do
        lastStatus[key] = tonumber(state[key]) or 0
    end

    pushFullUpdate()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Wait(500)
        sendInit()
        applyMinimapLayout()
    end
end)

RegisterCommand('togglehud', function()
    showHud(not hudVisible)
end, false)

RegisterCommand('toggle3d', function()
    hud3DEnabled = not hud3DEnabled
    sendInit()
    if Corex and Corex.Functions and Corex.Functions.Notify then
        Corex.Functions.Notify('HUD 3D: ' .. (hud3DEnabled and 'ON' or 'OFF'), 'info', 2000)
    end
end, false)

RegisterCommand('togglemap', function()
    minimapShown = not minimapShown
    sendInit()
    if minimapShown then applyMinimapLayout() end
    if Corex and Corex.Functions and Corex.Functions.Notify then
        Corex.Functions.Notify('Minimap: ' .. (minimapShown and 'ON' or 'OFF'), 'info', 2000)
    end
end, false)

RegisterCommand('mappos', function(_, args)
    local x = tonumber(args[1])
    local y = tonumber(args[2])
    local w = tonumber(args[3])
    local h = tonumber(args[4])
    local ax = args[5] or Config.Minimap.alignX
    local ay = args[6] or Config.Minimap.alignY

    if not x or not y then
        print('^3[HUD]^7 Usage: /mappos <x> <y> [w] [h] [alignX L|R|C] [alignY T|B|C]')
        print(('^3[HUD]^7 Current: x=%.3f y=%.3f w=%.3f h=%.3f align=%s%s'):format(
            Config.Minimap.x, Config.Minimap.y, Config.Minimap.w, Config.Minimap.h,
            Config.Minimap.alignX, Config.Minimap.alignY))
        return
    end

    Config.Minimap.x = x
    Config.Minimap.y = y
    Config.Minimap.w = w or Config.Minimap.w
    Config.Minimap.h = h or Config.Minimap.h
    Config.Minimap.alignX = ax
    Config.Minimap.alignY = ay
    minimapShown = true

    SetResourceKvp('corex_hud_minimap_x', tostring(Config.Minimap.x))
    SetResourceKvp('corex_hud_minimap_y', tostring(Config.Minimap.y))
    SetResourceKvp('corex_hud_minimap_w', tostring(Config.Minimap.w))
    SetResourceKvp('corex_hud_minimap_h', tostring(Config.Minimap.h))
    SetResourceKvp('corex_hud_minimap_alignX', tostring(Config.Minimap.alignX))
    SetResourceKvp('corex_hud_minimap_alignY', tostring(Config.Minimap.alignY))

    sendInit()
    applyMinimapLayout()
    print(('^2[HUD]^7 Minimap set: x=%.3f y=%.3f w=%.3f h=%.3f align=%s%s'):format(
        x, y, Config.Minimap.w, Config.Minimap.h, ax, ay))
end, false)

-- [SECURITY] Dev-only commands below are gated behind Config.Debug.
-- In production (Config.Debug = false) these commands are NOT registered,
-- so players cannot use /heal, /sethealth, /setarmor, /setstatus to cheat.
-- To enable for testing, set Config.Debug = true in corex-hud/config.lua.
if Config and Config.Debug then
    RegisterCommand('setstatus', function(_, args)
        local key = args[1]
        local value = tonumber(args[2]) or 0
        if not key then
            print('^3[HUD]^7 Usage: /setstatus <infection|poison|bleeding|sick|cold> <0-100>')
            return
        end
        local serverId = GetPlayerServerId(PlayerId())
        local playerBag = ('player:%s'):format(serverId)
        Player(serverId).state:set(key, math.max(0, math.min(100, value)), true)
        print(('^2[HUD]^7 Status %s = %d'):format(key, value))
    end, false)

    RegisterCommand("sethealth", function(_, args)
        local amount = tonumber(args[1]) or 100
        Corex.Functions.SetHealth(amount + 100)
    end, false)

    RegisterCommand("setarmor", function(_, args)
        local amount = tonumber(args[1]) or 100
        Corex.Functions.SetArmour(amount)
    end, false)

    RegisterCommand("heal", function()
        Corex.Functions.SetHealth(200)
        Corex.Functions.SetArmour(100)
    end, false)

    RegisterCommand("debughud", function()
        print(('^2[HUD DEBUG]^7 HP:%d AR:%d HU:%d TH:%d'):format(
            lastHealth, lastArmor, lastHunger, lastThirst
        ))
        for _, key in ipairs(STATUS_KEYS) do
            print(('^2[HUD DEBUG]^7 %s=%d'):format(key, lastStatus[key]))
        end
    end, false)
end

RegisterKeyMapping('togglehud', 'Toggle HUD', 'keyboard', 'F7')
RegisterKeyMapping('toggle3d', 'Toggle HUD 3D mode', 'keyboard', '')
RegisterKeyMapping('togglemap', 'Toggle Minimap', 'keyboard', '')

exports('ShowHud', showHud)
exports('IsHudVisible', function() return hudVisible end)
exports('UpdatePlayerName', function(name)
    playerName = name
    pushPartialUpdate({ playerName = playerName })
end)
exports('GetStatus', function(key) return lastStatus[key] or 0 end)
exports('GetAllStatuses', function() return lastStatus end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    SendNUIMessage({ action = 'hide' })
    SetNuiFocus(false, false)
    if minimapScaleform then
        SetScaleformMovieAsNoLongerNeeded(minimapScaleform)
        minimapScaleform = nil
    end
end)
