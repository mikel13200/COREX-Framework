local activeTargets = {}
local closestTarget = nil
local isInteractUIVisible = false
local interactionsEnabled = Config.EnableInteractions ~= false
local INTERACT_EXIT_BUFFER = 0.45
local INTERACT_SCAN_ACTIVE_MS = 50
local INTERACT_SCAN_IDLE_MS = 250
local INTERACT_SCAN_EMPTY_MS = 1000
local INTERACT_SCAN_FAR_MS = 1500
local INTERACT_UI_UPDATE_MS = 33
local INTERACT_UI_IDLE_MS = 1000
local INTERACT_INPUT_IDLE_MS = 1000
local INTERACT_UI_POSITION_EPSILON = 0.0015
local TARGET_COORD_REFRESH_MS = 2500
local TARGET_GRID_SIZE = 64.0
local lastInteractUiUpdateAt = 0
local lastInteractUiState = nil
local activeTargetCount = 0
local activeMaxTargetDistance = 2.5
local targetBuckets = {}
local dynamicTargets = {}
local HideInteractUI

COREX = COREX or {}
Corex = Corex or COREX

if not interactionsEnabled then
    function AddTarget()
        return false
    end

    function RemoveTarget()
        return false
    end

    exports('AddTarget', AddTarget)
    exports('RemoveTarget', RemoveTarget)
    return
end

local function GetCachedPlayerPed()
    return (cache and cache.ped) or PlayerPedId()
end

local function GetCachedPlayerId()
    return (cache and cache.playerId) or PlayerId()
end

local function GetTargetBucketKey(coords)
    return ('%d:%d'):format(math.floor(coords.x / TARGET_GRID_SIZE), math.floor(coords.y / TARGET_GRID_SIZE))
end

local function AddTargetToBucket(entityId, target)
    if target.dynamic then
        dynamicTargets[entityId] = target
        return
    end

    local bucketKey = GetTargetBucketKey(target.coords)
    target.bucketKey = bucketKey
    targetBuckets[bucketKey] = targetBuckets[bucketKey] or {}
    targetBuckets[bucketKey][entityId] = target
end

local function RemoveTargetFromBucket(entityId, target)
    if not target then
        return
    end

    dynamicTargets[entityId] = nil

    local bucketKey = target.bucketKey
    if bucketKey and targetBuckets[bucketKey] then
        targetBuckets[bucketKey][entityId] = nil
        if next(targetBuckets[bucketKey]) == nil then
            targetBuckets[bucketKey] = nil
        end
    end

    target.bucketKey = nil
end

local function RecalculateMaxTargetDistance()
    local maxDistance = 2.5
    for _, target in pairs(activeTargets) do
        if target.distance and target.distance > maxDistance then
            maxDistance = target.distance
        end
    end
    activeMaxTargetDistance = maxDistance
end

local function RemoveTargetInternal(entityId, hideUi)
    local target = activeTargets[entityId]
    if not target then
        return false
    end

    RemoveTargetFromBucket(entityId, target)
    activeTargets[entityId] = nil
    activeTargetCount = math.max(0, activeTargetCount - 1)

    if target.distance and target.distance >= activeMaxTargetDistance then
        RecalculateMaxTargetDistance()
    end

    if closestTarget and closestTarget.entityId == entityId then
        closestTarget = nil
        if hideUi then
            HideInteractUI()
        end
    end

    return true
end

CreateThread(function()
    while true do
        if activeTargetCount > 0 then
            for entityId, target in pairs(activeTargets) do
                if not target.entity or not DoesEntityExist(target.entity) then
                    RemoveTargetInternal(entityId, false)
                end
            end
        end

        Wait(activeTargetCount > 0 and 15000 or 30000)
    end
end)

local function CacheInteractUIState(text, icon, distance, screenX, screenY)
    lastInteractUiUpdateAt = GetGameTimer()
    lastInteractUiState = {
        text = text,
        icon = icon,
        distance = distance,
        x = screenX,
        y = screenY
    }
end

local function ShowInteractUI(text, distance, icon, screenX, screenY)
    local now = GetGameTimer()
    if isInteractUIVisible and lastInteractUiState then
        local textChanged = lastInteractUiState.text ~= text or lastInteractUiState.icon ~= icon
        local movedEnough = math.abs((lastInteractUiState.x or 0.0) - screenX) >= INTERACT_UI_POSITION_EPSILON
            or math.abs((lastInteractUiState.y or 0.0) - screenY) >= INTERACT_UI_POSITION_EPSILON

        if not textChanged then
            if not movedEnough then
                return
            end

            if (now - lastInteractUiUpdateAt) < INTERACT_UI_UPDATE_MS then
                return
            end
        end
    end

    if not isInteractUIVisible then
        SendNUIMessage({
            action = "showInteract",
            text = text,
            icon = icon,
            distance = distance,
            x = screenX,
            y = screenY
        })
        isInteractUIVisible = true
    else
        SendNUIMessage({
            action = "updateInteract",
            text = text,
            icon = icon,
            distance = distance,
            x = screenX,
            y = screenY
        })
    end

    CacheInteractUIState(text, icon, distance, screenX, screenY)
end

function HideInteractUI()
    if isInteractUIVisible then
        SendNUIMessage({
            action = "hideInteract"
        })
        isInteractUIVisible = false
    end

    lastInteractUiState = nil
    lastInteractUiUpdateAt = 0
end

function AddTarget(entity, data)
    if not DoesEntityExist(entity) then
        return false
    end

    if not data then
        return false
    end

    if type(data.callback) ~= 'function' and type(data.event) ~= 'string' then
        return false
    end

    local entityCoords = GetEntityCoords(entity)
    local oldTarget = activeTargets[entity]
    if not oldTarget then
        activeTargetCount = activeTargetCount + 1
    else
        RemoveTargetFromBucket(entity, oldTarget)
    end

    local target = {
        entity = entity,
        text = data.text or "Interact",
        icon = data.icon or "fa-hand-paper",
        distance = math.max(0.5, data.distance or 2.5),
        callback = data.callback,
        event = data.event,
        data = data.data or {},
        coords = entityCoords,
        dynamic = data.dynamic == true,
        lastCoordRefresh = GetGameTimer()
    }

    activeTargets[entity] = target
    AddTargetToBucket(entity, target)
    if target.distance > activeMaxTargetDistance then
        activeMaxTargetDistance = target.distance
    end

    return true
end

function RemoveTarget(entity)
    RemoveTargetInternal(entity, true)
end

function GetClosestTarget()
    local ped = GetCachedPlayerPed()
    if not ped or ped == 0 then return nil end
    local coords = GetEntityCoords(ped)
    local px, py, pz = coords.x, coords.y, coords.z

    local closest = nil
    local closestDistSq = 999999.0
    local closestEntityId = nil
    local candidateCount = 0
    local now = GetGameTimer()

    local function checkTarget(entityId, target)
        candidateCount = candidateCount + 1

        if DoesEntityExist(target.entity) then
            local entityCoords = target.coords
            if target.dynamic or not entityCoords or (now - (target.lastCoordRefresh or 0)) >= TARGET_COORD_REFRESH_MS then
                entityCoords = GetEntityCoords(target.entity)
                target.coords = entityCoords
                target.lastCoordRefresh = now

                if not target.dynamic then
                    local nextBucketKey = GetTargetBucketKey(entityCoords)
                    if nextBucketKey ~= target.bucketKey then
                        RemoveTargetFromBucket(entityId, target)
                        AddTargetToBucket(entityId, target)
                    end
                end
            end

            local dx = px - entityCoords.x
            local dy = py - entityCoords.y
            local maxD = target.distance + 1.0
            if dx * dx + dy * dy <= maxD * maxD then
                if not target.dynamic then
                    entityCoords = GetEntityCoords(target.entity)
                    target.coords = entityCoords
                    target.lastCoordRefresh = now
                    dx = px - entityCoords.x
                    dy = py - entityCoords.y
                end

                local dz = pz - entityCoords.z
                local distSq = dx * dx + dy * dy + dz * dz
                local activeDistance = target.distance
                if closestTarget and closestTarget.entityId == entityId then
                    activeDistance = activeDistance + INTERACT_EXIT_BUFFER
                end

                local tdSq = activeDistance * activeDistance
                if distSq <= tdSq and distSq < closestDistSq then
                    closestDistSq = distSq
                    closest = target
                    closestEntityId = entityId
                end
            end
        else
            RemoveTargetInternal(entityId, false)
        end
    end

    local bucketRadius = math.max(1, math.ceil((activeMaxTargetDistance + INTERACT_EXIT_BUFFER + 1.0) / TARGET_GRID_SIZE))
    local playerBucketX = math.floor(px / TARGET_GRID_SIZE)
    local playerBucketY = math.floor(py / TARGET_GRID_SIZE)

    for bx = playerBucketX - bucketRadius, playerBucketX + bucketRadius do
        for by = playerBucketY - bucketRadius, playerBucketY + bucketRadius do
            local bucket = targetBuckets[('%d:%d'):format(bx, by)]
            if bucket then
                for entityId, target in pairs(bucket) do
                    checkTarget(entityId, target)
                end
            end
        end
    end

    for entityId, target in pairs(dynamicTargets) do
        checkTarget(entityId, target)
    end

    if closestTarget and activeTargets[closestTarget.entityId] then
        local target = activeTargets[closestTarget.entityId]
        if target and not dynamicTargets[closestTarget.entityId] then
            checkTarget(closestTarget.entityId, target)
        end
    end

    if closest then
        return {
            target = closest,
            distance = math.sqrt(closestDistSq),
            entityId = closestEntityId
        }, candidateCount
    end

    return nil, candidateCount
end

CreateThread(function()
    while not NetworkIsPlayerActive(GetCachedPlayerId()) do
        Wait(500)
    end

    while true do
        if activeTargetCount <= 0 then
            if closestTarget then
                closestTarget = nil
            end
            if isInteractUIVisible then
                HideInteractUI()
            end
            Wait(INTERACT_SCAN_EMPTY_MS)
        else
            local newClosest, candidateCount = GetClosestTarget()
            if newClosest then
                closestTarget = newClosest
                Wait(INTERACT_SCAN_ACTIVE_MS)
            else
                if closestTarget then
                    closestTarget = nil
                end
                if isInteractUIVisible then
                    HideInteractUI()
                end
                Wait(candidateCount > 0 and INTERACT_SCAN_IDLE_MS or INTERACT_SCAN_FAR_MS)
            end
        end
    end
end)

CreateThread(function()
    while not NetworkIsPlayerActive(GetCachedPlayerId()) do
        Wait(500)
    end

    while true do
        if closestTarget then
            local currentTarget = closestTarget
            local targetEntity = currentTarget.target and currentTarget.target.entity

            if not targetEntity or not DoesEntityExist(targetEntity) then
                closestTarget = nil
                HideInteractUI()
            else
                local entityCoords = GetEntityCoords(targetEntity)
                local headOffset = vector3(entityCoords.x, entityCoords.y, entityCoords.z + 1.0)
                local onScreen, screenX, screenY = World3dToScreen2d(headOffset.x, headOffset.y, headOffset.z)

                if onScreen then
                    ShowInteractUI(currentTarget.target.text, currentTarget.distance, currentTarget.target.icon, screenX, screenY)
                else
                    HideInteractUI()
                end
            end

            Wait(INTERACT_UI_UPDATE_MS)
        else
            if isInteractUIVisible then
                HideInteractUI()
            end
            Wait(INTERACT_UI_IDLE_MS)
        end
    end
end)

CreateThread(function()
    while not NetworkIsPlayerActive(GetCachedPlayerId()) do
        Wait(500)
    end

    while true do
        if closestTarget then
            Wait(0)
            if IsControlJustPressed(0, 38) then
                local currentTarget = closestTarget
                if currentTarget and currentTarget.target then
                    if currentTarget.target.callback then
                        currentTarget.target.callback(currentTarget.target.entity, currentTarget.target.data)
                    elseif currentTarget.target.event then
                        TriggerEvent(currentTarget.target.event, currentTarget.target.entity, currentTarget.target.data)
                    end
                end
            end
        else
            Wait(INTERACT_INPUT_IDLE_MS)
        end
    end
end)

exports('AddTarget', AddTarget)
exports('RemoveTarget', RemoveTarget)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    activeTargets = {}
    targetBuckets = {}
    dynamicTargets = {}
    activeTargetCount = 0
    activeMaxTargetDistance = 2.5
    closestTarget = nil
    isInteractUIVisible = false
end)
