local Corex = nil
local isReady = false
local isOpen = false
local nearWorkbench = false
local workbenchBlips = {}
local workbenchProps = {}

local function InitCore()
    local success, core = pcall(function()
        return exports['corex-core']:GetCoreObject()
    end)
    if not success or not core or not core.Functions then return false end
    Corex = core
    return true
end

local function OnCoreReady()
    isReady = true
    print('[COREX-CRAFTING] ^2Connected to corex-core^0')

    Wait(2000)
    CreateWorkbenchBlips()
    SpawnWorkbenches()
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
            print('[COREX-CRAFTING] ^1Core init timed out^0')
        end
    end)
else
    CreateThread(function()
        OnCoreReady()
    end)
end

function CreateWorkbenchBlips()
    for _, blip in ipairs(workbenchBlips) do
        RemoveBlip(blip)
    end
    workbenchBlips = {}

    for _, wb in ipairs(Config.Workbenches) do
        if wb.blip then
            local blip = AddBlipForCoord(wb.coords.x, wb.coords.y, wb.coords.z)
            SetBlipSprite(blip, 566)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, 0.8)
            SetBlipColour(blip, 47)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(wb.label or 'Workbench')
            EndTextCommandSetBlipName(blip)
            workbenchBlips[#workbenchBlips + 1] = blip
        end
    end
end

function SpawnWorkbenches()
    for i, wb in ipairs(Config.Workbenches) do
        local model = wb.model or 'prop_tool_bench02'
        local modelHash = GetHashKey(model)

        RequestModel(modelHash)
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(modelHash) do
            if GetGameTimer() > timeout then
                if Config.Debug then print('[COREX-CRAFTING] ^1Model load timeout: ' .. model .. '^0') end
                goto continue
            end
            Wait(50)
        end

        local prop = CreateObject(modelHash, wb.coords.x, wb.coords.y, wb.coords.z - 0.5, false, false, false)
        if not DoesEntityExist(prop) then
            if Config.Debug then print('[COREX-CRAFTING] ^1Failed to spawn workbench prop^0') end
            SetModelAsNoLongerNeeded(modelHash)
            goto continue
        end

        SetEntityHeading(prop, wb.heading or 0.0)
        FreezeEntityPosition(prop, true)
        SetEntityAsMissionEntity(prop, true, true)
        SetModelAsNoLongerNeeded(modelHash)

        workbenchProps[#workbenchProps + 1] = prop

        local success, result = pcall(function()
            return exports['corex-core']:AddTarget(prop, {
                text = wb.interactLabel or ('[E] ' .. (wb.label or 'Workbench')),
                icon = wb.icon or 'fa-hammer',
                distance = wb.radius or 2.5,
                event = 'corex-crafting:client:openAtWorkbench',
                data = { workbenchIndex = i }
            })
        end)

        if success then
            if Config.Debug then print('[COREX-CRAFTING] ^2Workbench spawned with AddTarget at index ' .. i .. '^0') end
        else
            if Config.Debug then print('[COREX-CRAFTING] ^1AddTarget failed: ' .. tostring(result) .. '^0') end
        end

        ::continue::
    end
end

RegisterNetEvent('corex-crafting:client:openAtWorkbench', function(entity, data)
    OpenCrafting(true)
end)

function OpenCrafting(atWorkbench)
    if isOpen then return end
    if not isReady then return end

    nearWorkbench = atWorkbench or false
    TriggerServerEvent('corex-crafting:server:getState')
end

function CloseCrafting()
    if not isOpen then return end

    isOpen = false
    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
end

RegisterNetEvent('corex-crafting:client:updateState', function(stateData)
    if not stateData then return end

    if not isOpen then
        isOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open', data = stateData })
    else
        SendNUIMessage({ action = 'updateState', data = stateData })
    end
end)

RegisterNetEvent('corex-crafting:client:craftComplete', function(recipeId)
    SendNUIMessage({ action = 'craftComplete', recipeId = recipeId })
    if Corex and Corex.Functions then
        Corex.Functions.Notify('Item ready! Open crafting to collect.', 'success', 4000)
    end
end)

RegisterNUICallback('startCraft', function(data, cb)
    if data and data.recipeId then
        TriggerServerEvent('corex-crafting:server:startCraft', data.recipeId)
    end
    cb('ok')
end)

local function SanitizeQueueIndex(raw)
    local n = tonumber(raw)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    n = math.floor(n)
    if n < 1 or n > 1000 then return nil end
    return n
end

RegisterNUICallback('takeCraft', function(data, cb)
    local idx = data and SanitizeQueueIndex(data.queueIndex)
    if idx then
        TriggerServerEvent('corex-crafting:server:takeCraft', idx)
    end
    cb('ok')
end)

RegisterNUICallback('cancelCraft', function(data, cb)
    local idx = data and SanitizeQueueIndex(data.queueIndex)
    if idx then
        TriggerServerEvent('corex-crafting:server:cancelCraft', idx)
    end
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    CloseCrafting()
    cb('ok')
end)

RegisterCommand('craft', function()
    if not isReady then return end
    if isOpen then
        CloseCrafting()
    else
        OpenCrafting(false)
    end
end, false)

RegisterKeyMapping('craft', 'Open Crafting Menu', 'keyboard', 'F6')

CreateThread(function()
    while true do
        if isOpen then
            Wait(0)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 199, true)

            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 199) then
                CloseCrafting()
            end
        else
            Wait(200)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    if isOpen then
        SendNUIMessage({ action = 'close' })
        SetNuiFocus(false, false)
        isOpen = false
    end

    for _, blip in ipairs(workbenchBlips) do
        RemoveBlip(blip)
    end
    workbenchBlips = {}

    for _, prop in ipairs(workbenchProps) do
        if DoesEntityExist(prop) then
            pcall(function()
                exports['corex-core']:RemoveTarget(prop)
            end)
            DeleteEntity(prop)
        end
    end
    workbenchProps = {}
end)

exports('OpenCrafting', OpenCrafting)
