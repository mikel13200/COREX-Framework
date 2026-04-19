local Corex = nil

local infectionTimers = {}
local painkillerTimers = {}
local lastDrainTick = {}
local lastUseItem = {}
local USE_ITEM_COOLDOWN = 500

local function InitCore()
    local success, core = pcall(function()
        return exports['corex-core']:GetCoreObject()
    end)
    if not success or not core or not core.Functions then return false end
    Corex = core
    return true
end

local function OnCoreReady()
    if Config.Debug then print('[COREX-SURVIVAL] ^2Server survival system initialized^0') end
end

if not InitCore() then
    AddEventHandler('corex:server:coreReady', function(coreObj)
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
    OnCoreReady()
end

local function SyncStat(source, statName, value)
    local pState = Player(source).state
    if not pState then return end
    pState:set(statName, value, true)
end

local function GetStat(source, statName)
    if not Corex then return 0 end
    return Corex.Functions.GetStat(source, statName) or 0
end

local function SetStat(source, statName, value)
    if not Corex then return false end
    return Corex.Functions.SetStat(source, statName, value)
end

local function StartInfectionGrowth(source)
    -- Marker only — a single consolidated thread below ticks all infected players.
    -- Previously this spawned one CreateThread per infected player; at 20 infected
    -- players that was 20 independent scheduler entries. Now it's one.
    infectionTimers[source] = true
end

local function StopInfectionGrowth(source)
    infectionTimers[source] = nil
end

-- Consolidated infection tick — single thread iterates all infected players.
CreateThread(function()
    while not Corex do Wait(500) end

    while true do
        Wait(Config.Infection.growthInterval)

        for source, active in pairs(infectionTimers) do
            if active then
                local player = Corex.Functions.GetPlayer(source)
                if not player then
                    infectionTimers[source] = nil
                elseif not painkillerTimers[source] then
                    local infection = GetStat(source, 'infection')
                    if infection <= 0 then
                        infectionTimers[source] = nil
                    else
                        local newInfection = math.min(100, infection + Config.Infection.growthRate)
                        SetStat(source, 'infection', newInfection)

                        if newInfection >= 100 then
                            Corex.Functions.SetPlayerHealth(source, 0)
                            Corex.Functions.Notify(source, 'The infection has consumed you...', 'error', 5000)
                            infectionTimers[source] = nil
                        end
                    end
                end
            end
        end
    end
end)

local function StartPainkillerTimer(source, duration)
    painkillerTimers[source] = true

    CreateThread(function()
        Wait(duration)
        painkillerTimers[source] = nil
        local player = Corex.Functions.GetPlayer(source)
        if player then
            Corex.Functions.Notify(source, 'Painkillers are wearing off...', 'warning', 3000)
        end
    end)
end

-- Anti-cheat: minimum interval between drain ticks (80% of configured interval)
local MIN_DRAIN_INTERVAL = Config.Hunger.tickInterval * 0.8

RegisterNetEvent('corex-survival:server:drainTick', function()
    local src = source
    if not Corex then return end

    local player = Corex.Functions.GetPlayer(src)
    if not player then return end

    local now = Corex.Functions.GetGameTimer()
    if lastDrainTick[src] and (now - lastDrainTick[src]) < MIN_DRAIN_INTERVAL then
        return
    end
    lastDrainTick[src] = now

    local hunger = GetStat(src, 'hunger')
    local thirst = GetStat(src, 'thirst')

    local newHunger = math.max(0, hunger - Config.Hunger.drainRate)
    local newThirst = math.max(0, thirst - Config.Thirst.drainRate)

    SetStat(src, 'hunger', newHunger)
    SetStat(src, 'thirst', newThirst)
end)

local lastZombieHit = {}
local ZOMBIE_HIT_COOLDOWN = 2000

RegisterNetEvent('corex-survival:server:zombieHit', function()
    local src = source
    if not Corex or not Config.Infection.enabled then return end

    local now = Corex.Functions.GetGameTimer()
    if lastZombieHit[src] and (now - lastZombieHit[src]) < ZOMBIE_HIT_COOLDOWN then return end
    lastZombieHit[src] = now

    local player = Corex.Functions.GetPlayer(src)
    if not player then return end

    local currentInfection = GetStat(src, 'infection')
    if currentInfection > 0 then return end

    local startValue = Config.Infection.growthRate
    SetStat(src, 'infection', startValue)
    Corex.Functions.Notify(src, 'You have been infected!', 'error', 5000)
    StartInfectionGrowth(src)
end)

RegisterNetEvent('corex-survival:server:useItem', function(itemName)
    local src = source
    if not Corex then return end
    if type(itemName) ~= 'string' then return end

    local now = Corex.Functions.GetGameTimer()
    if lastUseItem[src] and (now - lastUseItem[src]) < USE_ITEM_COOLDOWN then return end
    lastUseItem[src] = now

    local player = Corex.Functions.GetPlayer(src)
    if not player then return end

    local itemConfig = Config.Items[itemName]
    if not itemConfig then return end

    if itemConfig.stat == 'hunger' then
        local current = GetStat(src, 'hunger')
        local newVal = math.min(Config.Hunger.maxValue, current + itemConfig.amount)
        SetStat(src, 'hunger', newVal)
        Corex.Functions.Notify(src, 'Hunger restored (+' .. itemConfig.amount .. ')', 'success', 2000)

    elseif itemConfig.stat == 'thirst' then
        local current = GetStat(src, 'thirst')
        local newVal = math.min(Config.Thirst.maxValue, current + itemConfig.amount)
        SetStat(src, 'thirst', newVal)
        Corex.Functions.Notify(src, 'Thirst restored (+' .. itemConfig.amount .. ')', 'success', 2000)

    elseif itemConfig.stat == 'health' then
        if itemConfig.fullHeal then
            Corex.Functions.SetPlayerHealth(src, 200)
            Corex.Functions.Notify(src, 'Fully healed', 'success', 2000)
        else
            local amount = tonumber(itemConfig.amount) or 0
            TriggerClientEvent('corex-survival:client:applyHealthDelta', src, amount)
            Corex.Functions.Notify(src, 'Health restored (+' .. amount .. ')', 'success', 2000)
        end

    elseif itemConfig.stat == 'infection' then
        if itemConfig.cure then
            SetStat(src, 'infection', 0)
            StopInfectionGrowth(src)
            painkillerTimers[src] = nil
            Corex.Functions.Notify(src, 'Infection cured!', 'success', 3000)

        elseif itemConfig.pause then
            StartPainkillerTimer(src, itemConfig.pause)
            Corex.Functions.Notify(src, 'Painkillers active - infection paused', 'info', 3000)

        elseif itemConfig.reduce then
            local current = GetStat(src, 'infection')
            local newVal = math.max(0, current - itemConfig.reduce)
            SetStat(src, 'infection', newVal)
            if newVal <= 0 then
                StopInfectionGrowth(src)
            end
            Corex.Functions.Notify(src, 'Infection reduced (-' .. itemConfig.reduce .. ')', 'success', 3000)
        end
    end

    pcall(function()
        exports['corex-inventory']:RemoveItem(src, itemName, 1)
    end)

    if itemConfig.infectionRisk and Config.Infection.enabled then
        local roll = math.random()
        if roll <= itemConfig.infectionRisk then
            local currentInfection = GetStat(src, 'infection')
            if currentInfection <= 0 then
                SetStat(src, 'infection', Config.Infection.growthRate)
                Corex.Functions.Notify(src, 'You feel sick...', 'warning', 4000)
                StartInfectionGrowth(src)
            end
        end
    end
end)

-- Player ready: start infection growth if already infected
AddEventHandler('corex:server:playerReady', function(source, player)
    if not Config.Infection.enabled then return end

    local infection = player.metadata and player.metadata.infection or 0
    if infection > 0 then
        StartInfectionGrowth(source)
    end
end)

-- Cleanup on player drop
AddEventHandler('playerDropped', function()
    local src = source
    infectionTimers[src] = nil
    painkillerTimers[src] = nil
    lastDrainTick[src] = nil
    lastUseItem[src] = nil
    lastZombieHit[src] = nil
end)

-- Admin commands
RegisterCommand('setstat', function(source, args)
    local src = source
    if src > 0 and not (Corex.Functions.IsPlayerAceAllowed(src, 'corex.admin') or Corex.Functions.IsPlayerAceAllowed(src, 'corex.survival.admin')) then return end

    local targetId = tonumber(args[1])
    local statName = args[2]
    local value = tonumber(args[3])

    if not targetId or not statName or not value then
        if src > 0 then
            Corex.Functions.Notify(src, 'Usage: /setstat [id] [hunger/thirst/infection] [value]', 'info')
        else
            print('Usage: setstat [id] [hunger/thirst/infection] [value]')
        end
        return
    end

    if not Corex.Functions.GetPlayer(targetId) then
        local msg = 'Player ' .. targetId .. ' not found'
        if src > 0 then Corex.Functions.Notify(src, msg, 'error') else print(msg) end
        return
    end

    local success = SetStat(targetId, statName, value)
    if success then
        local msg = 'Set ' .. statName .. ' to ' .. value .. ' for player ' .. targetId
        if src > 0 then Corex.Functions.Notify(src, msg, 'success') else print(msg) end

        if statName == 'infection' then
            if value > 0 then
                StartInfectionGrowth(targetId)
            else
                StopInfectionGrowth(targetId)
                painkillerTimers[targetId] = nil
            end
        end
    end
end, true)

exports('GetPlayerHunger', function(source) return GetStat(source, 'hunger') end)
exports('GetPlayerThirst', function(source) return GetStat(source, 'thirst') end)
exports('GetPlayerInfection', function(source) return GetStat(source, 'infection') end)
exports('SetPlayerHunger', function(source, value) return SetStat(source, 'hunger', value) end)
exports('SetPlayerThirst', function(source, value) return SetStat(source, 'thirst', value) end)
exports('SetPlayerInfection', function(source, value)
    local result = SetStat(source, 'infection', value)
    if result then
        if value > 0 then
            StartInfectionGrowth(source)
        else
            StopInfectionGrowth(source)
        end
    end
    return result
end)
exports('IsInfectionPaused', function(source) return painkillerTimers[source] == true end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    infectionTimers = {}
    painkillerTimers = {}
    lastDrainTick = {}
    lastUseItem = {}
end)
