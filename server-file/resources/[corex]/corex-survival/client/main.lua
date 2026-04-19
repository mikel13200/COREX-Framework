local Corex = nil
local isReady = false

local currentHunger = 100
local currentThirst = 100
local currentInfection = 0

local effectsActive = false
local infectionPaused = false

local function InitCore()
    local success, core = pcall(function()
        return exports['corex-core']:GetCoreObject()
    end)
    if not success or not core or not core.Functions then return false end
    Corex = core
    return true
end

local function OnCoreReady()
    Corex.Functions.WaitForPlayerData(15000)

    local metadata = Corex.Functions.GetMetaData()
    if metadata then
        currentHunger = metadata.hunger or 100
        currentThirst = metadata.thirst or 100
        currentInfection = metadata.infection or 0
    end

    isReady = true
    print('[COREX-SURVIVAL] ^2Survival system initialized^0')
end

if not InitCore() then
    AddEventHandler('corex:client:coreReady', function(coreObj)
        if coreObj and coreObj.Functions and not Corex then
            Corex = coreObj
            OnCoreReady()
        end
    end)
    CreateThread(function()
        Wait(15000)
        if not Corex then
            print('[COREX-SURVIVAL] ^1Core init timed out^0')
        end
    end)
else
    CreateThread(function()
        OnCoreReady()
    end)
end

local function GetInfectionStage(level)
    local activeStage = nil
    for _, stage in ipairs(Config.Infection.stages) do
        if level >= stage.threshold then
            activeStage = stage
        end
    end
    return activeStage
end

local function HasEffect(stage, effectName)
    if not stage or not stage.effects then return false end
    for _, eff in ipairs(stage.effects) do
        if eff == effectName then return true end
    end
    return false
end

-- StateBag listeners for stat synchronization
CreateThread(function()
    while not Corex do Wait(100) end

    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(100)
    end

    local serverId = GetPlayerServerId(PlayerId())
    local playerBag = ('player:%s'):format(serverId)

    AddStateBagChangeHandler('metadata', playerBag, function(_, _, value)
        if not value then return end
        currentHunger = value.hunger or currentHunger
        currentThirst = value.thirst or currentThirst
        currentInfection = value.infection or currentInfection
    end)
end)

-- Hunger/Thirst drain tick
CreateThread(function()
    while not isReady do Wait(500) end

    while true do
        Wait(Config.Hunger.tickInterval)

        if not Corex.Functions.IsAlive() then goto continue end

        TriggerServerEvent('corex-survival:server:drainTick')

        ::continue::
    end
end)

-- Low stat effects: screen fx and health damage
CreateThread(function()
    while not isReady do Wait(500) end

    while true do
        Wait(1000)

        if not Corex.Functions.IsAlive() then goto continue end

        local ped = Corex.Functions.GetPed()

        if currentHunger <= Config.Hunger.damageThreshold then
            ApplyDamageToPed(ped, Config.Hunger.damageAmount, false)
        end

        if currentThirst <= Config.Thirst.damageThreshold then
            ApplyDamageToPed(ped, Config.Thirst.damageAmount, false)
        end

        -- Screen effect for low hunger/thirst
        if currentHunger <= Config.Hunger.effectThreshold or currentThirst <= Config.Thirst.effectThreshold then
            local intensity = 1.0 - (math.min(currentHunger, currentThirst) / Config.Hunger.effectThreshold)
            SetTimecycleModifier('hud_def_desat_cold')
            SetTimecycleModifierStrength(math.min(0.6, intensity * 0.6))
        elseif currentInfection <= 0 then
            ClearTimecycleModifier()
        end

        ::continue::
    end
end)

-- Infection effects loop
CreateThread(function()
    while not isReady do Wait(500) end

    local appliedStageIdx = nil

    while true do
        Wait(1000)

        if not Corex.Functions.IsAlive() or currentInfection <= 0 then
            if effectsActive then
                ClearTimecycleModifier()
                ResetPedMovementClipset(Corex.Functions.GetPed(), 0.0)
                StopGameplayCamShaking(true)
                effectsActive = false
                appliedStageIdx = nil
            end
            goto continue
        end

        effectsActive = true
        local stage = GetInfectionStage(currentInfection)
        if not stage then goto continue end
        local ped = Corex.Functions.GetPed()

        -- Shake and clipset naturally decay; reapply only when the stage
        -- actually changes to avoid spamming natives each tick.
        local stageChanged = appliedStageIdx ~= stage.threshold
        appliedStageIdx = stage.threshold

        if HasEffect(stage, 'shake') and stageChanged then
            ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', Config.Effects.shakeIntensity)
        end

        if HasEffect(stage, 'slowness') then
            SetPedMoveRateOverride(ped, Config.Effects.slowMultiplier)
        elseif stageChanged then
            ResetPedMovementClipset(ped, 0.0)
        end

        if HasEffect(stage, 'screenDistort') and stageChanged then
            SetTimecycleModifier('drug_flying_base')
            SetTimecycleModifierStrength(Config.Effects.screenDistortStrength)
        end

        ::continue::
    end
end)

-- Cough animation (separate thread with cooldown)
CreateThread(function()
    while not isReady do Wait(500) end

    local lastCough = 0

    while true do
        Wait(2000)

        if not Corex.Functions.IsAlive() or currentInfection <= 0 then
            goto continue
        end

        local stage = GetInfectionStage(currentInfection)
        if not stage or not HasEffect(stage, 'cough') then goto continue end

        local now = GetGameTimer()
        if now - lastCough < Config.Effects.coughCooldown then goto continue end

        lastCough = now
        local ped = Corex.Functions.GetPed()

        local success = pcall(function()
            RequestAnimDict(Config.Effects.coughDict)
            local loadStart = GetGameTimer()
            while not HasAnimDictLoaded(Config.Effects.coughDict) do
                Wait(10)
                if GetGameTimer() - loadStart > 3000 then return end
            end
            TaskPlayAnim(ped, Config.Effects.coughDict, Config.Effects.coughAnim, 4.0, 4.0, Config.Effects.coughDuration, 49, 0, false, false, false)
            RemoveAnimDict(Config.Effects.coughDict)
        end)

        ::continue::
    end
end)

RegisterNetEvent('corex-survival:client:applyHealthDelta', function(amount)
    if not isReady then return end
    local ped = Corex.Functions.GetPed()
    if not ped or ped == 0 then return end
    local current = GetEntityHealth(ped)
    local clamped = math.max(0, math.min(200, current + (tonumber(amount) or 0)))
    SetEntityHealth(ped, clamped)
end)

RegisterNetEvent('corex-survival:client:zombieHit', function()
    if not isReady or not Config.Infection.enabled then return end
    if currentInfection > 0 then return end

    local roll = math.random()
    if roll <= Config.Infection.biteChance then
        Corex.Functions.Notify('You feel a burning sensation from the bite...', 'warning', 5000)
        TriggerServerEvent('corex-survival:server:zombieHit')
    end
end)

RegisterNetEvent('corex-inventory:client:useItem', function(itemName, itemData)
    if not isReady then return end

    local itemConfig = Config.Items[itemName]
    if not itemConfig then return end

    TriggerServerEvent('corex-survival:server:useItem', itemName)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    ClearTimecycleModifier()
    StopGameplayCamShaking(true)
    ResetPedMovementClipset(Corex.Functions.GetPed(), 0.0)

    effectsActive = false
    isReady = false
end)
