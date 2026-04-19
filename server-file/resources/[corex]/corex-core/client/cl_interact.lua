local activeTargets = {}
local closestTarget = nil
local isInteractUIVisible = false

COREX = COREX or {}
Corex = Corex or COREX

CreateThread(function()
    while true do
        Wait(5000)
        for entityId, target in pairs(activeTargets) do
            if not target.entity or not DoesEntityExist(target.entity) then
                activeTargets[entityId] = nil
                if closestTarget and closestTarget.entityId == entityId then
                    closestTarget = nil
                end
            end
        end
    end
end)

local function ShowInteractUI(text, distance, icon, screenX, screenY)
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
end

local function HideInteractUI()
    if isInteractUIVisible then
        SendNUIMessage({
            action = "hideInteract"
        })
        isInteractUIVisible = false
    end
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

    activeTargets[entity] = {
        entity = entity,
        text = data.text or "Interact",
        icon = data.icon or "fa-hand-paper",
        distance = math.max(0.5, data.distance or 2.5),
        callback = data.callback,
        event = data.event,
        data = data.data or {}
    }

    return true
end

function RemoveTarget(entity)
    activeTargets[entity] = nil

    if closestTarget and closestTarget.entityId == entity then
        closestTarget = nil
        HideInteractUI()
    end
end

function GetClosestTarget()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return nil end
    local coords = GetEntityCoords(ped)
    local px, py, pz = coords.x, coords.y, coords.z

    local closest = nil
    local closestDistSq = 999999.0
    local closestEntityId = nil

    for entityId, target in pairs(activeTargets) do
        if DoesEntityExist(target.entity) then
            local entityCoords = GetEntityCoords(target.entity)
            -- Cheap squared-distance with early-out against target.distance.
            -- Caps the per-target work at two float reads + adds before the sqrt.
            local dx = px - entityCoords.x
            local dy = py - entityCoords.y
            local maxD = target.distance + 1.0
            if dx * dx + dy * dy <= maxD * maxD then
                local dz = pz - entityCoords.z
                local distSq = dx * dx + dy * dy + dz * dz
                local tdSq = target.distance * target.distance
                if distSq <= tdSq and distSq < closestDistSq then
                    closestDistSq = distSq
                    closest = target
                    closestEntityId = entityId
                end
            end
        else
            activeTargets[entityId] = nil
        end
    end

    if closest then
        return {
            target = closest,
            distance = math.sqrt(closestDistSq),
            entityId = closestEntityId
        }
    end

    return nil
end

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(500)
    end

    while true do
        local newClosest = GetClosestTarget()

        if newClosest then
            closestTarget = newClosest

            local entityCoords = GetEntityCoords(newClosest.target.entity)
            local headOffset = vector3(entityCoords.x, entityCoords.y, entityCoords.z + 1.0)

            local onScreen, screenX, screenY = World3dToScreen2d(headOffset.x, headOffset.y, headOffset.z)

            if onScreen then
                ShowInteractUI(newClosest.target.text, newClosest.distance, newClosest.target.icon, screenX, screenY)
            else
                HideInteractUI()
            end

            -- Don't need per-frame updates for a prompt; 50ms keeps UI smooth
            -- without scanning every target every tick.
            Wait(50)
        else
            if closestTarget then
                closestTarget = nil
                HideInteractUI()
            end
            Wait(250)
        end
    end
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(500)
    end

    while true do
        if closestTarget then
            Wait(0)
            if IsControlJustPressed(0, 38) then
                if closestTarget.target.callback then
                    closestTarget.target.callback(closestTarget.target.entity, closestTarget.target.data)
                elseif closestTarget.target.event then
                    TriggerEvent(closestTarget.target.event, closestTarget.target.entity, closestTarget.target.data)
                end
            end
        else
            Wait(100)
        end
    end
end)

exports('AddTarget', AddTarget)
exports('RemoveTarget', RemoveTarget)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    activeTargets = {}
    closestTarget = nil
    isInteractUIVisible = false
end)
