local Corex = nil
local isDead = false
local deathCoords = nil
local respawnRequested = false
local respawnRequestedAt = 0
local deathScreenOpenedAt = 0
local nuiFocusGuardActive = false
local respawnInProgress = false

local RESPAWN_TIMEOUT_MS = 10000
local FOCUS_GUARD_DURATION_MS = 1500
local FOCUS_GUARD_INTERVAL_MS = 50

CreateThread(function()
    local attempts = 0
    while not Corex or not Corex.Functions do
        Wait(100)
        attempts = attempts + 1
        local success, core = pcall(function()
            return exports['corex-core']:GetCoreObject()
        end)
        if success and core then
            Corex = core
        end
        if attempts >= 100 then
            print('[COREX-DEATH] ^1Failed to connect to corex-core^0')
            return
        end
    end
    print('[COREX-DEATH] ^2Connected to corex-core^0')
end)

local function DisableMovementAndCombat()
    -- Only disable specific controls needed to prevent the dead ped from
    -- moving / attacking. Never blanket-disable group 0 or 1 while NUI is
    -- focused - some cursor / accept controls live in those groups and can
    -- interfere with NUI input on certain game builds.
    DisableControlAction(0, 21, true)  -- sprint
    DisableControlAction(0, 22, true)  -- jump
    DisableControlAction(0, 23, true)  -- enter vehicle
    DisableControlAction(0, 24, true)  -- attack
    DisableControlAction(0, 25, true)  -- aim
    DisableControlAction(0, 30, true)  -- move LR
    DisableControlAction(0, 31, true)  -- move UD
    DisableControlAction(0, 32, true)  -- move up
    DisableControlAction(0, 33, true)  -- move down
    DisableControlAction(0, 34, true)  -- move left
    DisableControlAction(0, 35, true)  -- move right
    DisableControlAction(0, 140, true) -- melee light
    DisableControlAction(0, 141, true) -- melee heavy
    DisableControlAction(0, 142, true) -- melee alt
    DisableControlAction(0, 257, true) -- attack2
    DisableControlAction(0, 263, true) -- melee attack1
    DisableControlAction(0, 264, true) -- melee attack2
end

local function ApplyRagdoll()
    if not Config.Ragdoll.enabled then return end

    local ped = Corex.Functions.GetPed()
    SetPedToRagdoll(ped, Config.Ragdoll.duration, Config.Ragdoll.duration, 0, true, true, false)
end

local function StartNuiFocusGuard()
    if nuiFocusGuardActive then return end
    nuiFocusGuardActive = true

    CreateThread(function()
        local startedAt = GetGameTimer()
        while nuiFocusGuardActive and isDead and (GetGameTimer() - startedAt) < FOCUS_GUARD_DURATION_MS do
            if not IsNuiFocused() then
                SetNuiFocus(true, true)
                if Config.Debug then
                    print('[COREX-DEATH] ^3Re-asserted NUI focus (was stolen)^0')
                end
            end
            Wait(FOCUS_GUARD_INTERVAL_MS)
        end
        nuiFocusGuardActive = false
    end)
end

local function OpenDeathScreen()
    deathScreenOpenedAt = GetGameTimer()

    SendNUIMessage({
        action = 'showDeathScreen',
        duration = Config.DeathScreen.duration
    })
    SetNuiFocus(true, true)
    StartNuiFocusGuard()
end

local function CloseDeathScreen()
    nuiFocusGuardActive = false
    SendNUIMessage({ action = 'hideDeathScreen' })
    SetNuiFocus(false, false)
end

local function EnterDeathState(coords, options)
    options = options or {}

    if isDead or respawnInProgress then
        return
    end

    isDead = true
    respawnRequested = false
    respawnRequestedAt = 0
    deathCoords = coords

    if options.applyRagdoll then
        ApplyRagdoll()
    end

    OpenDeathScreen()
end

local function ResetDeathState()
    isDead = false
    respawnRequested = false
    respawnRequestedAt = 0
    deathCoords = nil
    deathScreenOpenedAt = 0
    nuiFocusGuardActive = false
end

CreateThread(function()
    while true do
        Wait(200)

        if not Corex or not Corex.Functions then
            goto continue
        end

        if isDead or respawnInProgress then
            goto continue
        end

        local ped = Corex.Functions.GetPed()
        if Corex.Functions.IsDead(ped) then
            local coords = Corex.Functions.GetCoords(ped)
            EnterDeathState(coords, { applyRagdoll = true })

            TriggerServerEvent('corex-death:server:playerDied', {
                x = coords.x,
                y = coords.y,
                z = coords.z
            })

            if Config.Debug then
                print('[COREX-DEATH] Player died at: ' .. tostring(coords))
            end
        end

        ::continue::
    end
end)

CreateThread(function()
    while true do
        if isDead then
            Wait(0)
            DisableMovementAndCombat()
        else
            Wait(500)
        end
    end
end)

local function SendRespawnRequest(reason)
    if not isDead then return end
    if respawnRequested then
        if Config.Debug then
            print('[COREX-DEATH] ^3Respawn already requested, ignoring duplicate (' .. tostring(reason) .. ')^0')
        end
        return
    end

    respawnRequested = true
    respawnRequestedAt = GetGameTimer()

    if Config.Debug then
        print('[COREX-DEATH] ^2Respawn requested via ' .. tostring(reason) .. '^0')
    end

    TriggerServerEvent('corex-death:server:requestRespawn', deathCoords and {
        x = deathCoords.x,
        y = deathCoords.y,
        z = deathCoords.z
    } or nil)

    SendNUIMessage({ action = 'respawnPending' })
end

RegisterNUICallback('requestRespawn', function(_, cb)
    cb('ok')
    SendRespawnRequest('button')
end)

RegisterNUICallback('debugLog', function(data, cb)
    cb('ok')
    if Config.Debug and data and type(data.message) == 'string' then
        local msg = string.sub(data.message, 1, 200)
        print('[COREX-DEATH][NUI] ' .. msg)
    end
end)

-- Keyboard fallback: Enter or Space triggers respawn once the countdown has
-- elapsed. Also serves as an escape hatch if the button itself is unclickable.
CreateThread(function()
    while true do
        if isDead and not respawnRequested then
            Wait(0)
            local elapsed = GetGameTimer() - deathScreenOpenedAt
            if elapsed >= Config.DeathScreen.duration then
                -- Control 18 = INPUT_FRONTEND_ACCEPT (Enter), 22 = INPUT_JUMP
                -- (Space). Use IsControlJustPressed with group 0 - these still
                -- fire even while NUI is focused because we check raw control.
                if IsControlJustPressed(0, 18) or IsControlJustPressed(0, 201) then
                    SendRespawnRequest('keyboard:enter')
                elseif IsControlJustPressed(0, 38) then
                    SendRespawnRequest('keyboard:e')
                elseif IsControlJustPressed(0, 22) then
                    SendRespawnRequest('keyboard:space')
                end
            end
        else
            Wait(500)
        end
    end
end)

-- Safety net: if the server never replies to the respawn request, allow the
-- player to retry by resetting the request flag and re-opening focus.
CreateThread(function()
    while true do
        Wait(1000)
        if isDead and respawnRequested and respawnRequestedAt > 0 then
            local elapsed = GetGameTimer() - respawnRequestedAt
            if elapsed > RESPAWN_TIMEOUT_MS then
            if Config.Debug then
                print('[COREX-DEATH] ^1Respawn request timed out after ' ..
                    tostring(elapsed) .. 'ms, re-enabling button^0')
            end
                respawnRequested = false
                respawnRequestedAt = 0
                -- Re-assert focus in case something stole it during the wait.
                SetNuiFocus(true, true)
                StartNuiFocusGuard()
                SendNUIMessage({ action = 'respawnFailed' })
            end
        end
    end
end)

RegisterNetEvent('corex-death:client:prepareRespawn', function()
    respawnInProgress = true
    CloseDeathScreen()
    ResetDeathState()
end)

RegisterNetEvent('corex-death:client:resumeDeath', function()
    respawnInProgress = false
    EnterDeathState(nil, { applyRagdoll = false })
end)

RegisterNetEvent('corex-death:client:respawnFinished', function()
    respawnInProgress = false
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(100)
    end

    local serverId = GetPlayerServerId(PlayerId())
    local playerBag = ('player:%s'):format(serverId)

    AddStateBagChangeHandler('lifecycleState', playerBag, function(_, _, value)
        if value == 'dead' then
            respawnInProgress = false
            EnterDeathState(nil, { applyRagdoll = false })
        end
    end)

    if LocalPlayer.state.lifecycleState == 'dead' then
        EnterDeathState(nil, { applyRagdoll = false })
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    if isDead then
        CloseDeathScreen()
        ResetDeathState()
    end
end)
