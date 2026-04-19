COREX = COREX or {}
COREX.Server = COREX.Server or {}

function COREX.Server.GetResourceState(resourceName)
    return GetResourceState(resourceName)
end

function COREX.Server.IsResourceStarted(resourceName)
    return GetResourceState(resourceName) == 'started'
end

function COREX.Server.GetPlayerSources()
    local sources = {}
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src then
            table.insert(sources, src)
        end
    end
    return sources
end

function COREX.Server.KickPlayer(source, reason)
    DropPlayer(source, reason or 'Kicked from server')
    if COREX and COREX.Debug then
        COREX.Debug.Info('[COREX] Player kicked: ' .. source .. ' - ' .. (reason or 'No reason'))
    end
end

function COREX.Server.SendChatMessage(source, author, message, color)
    color = color or {255, 255, 255}
    TriggerClientEvent('chat:addMessage', source, {
        color = color,
        multiline = true,
        args = {author, message}
    })
end

function COREX.Server.Broadcast(author, message, color)
    COREX.Server.SendChatMessage(-1, author, message, color)
end

function COREX.Server.GetPlayerPed(source)
    return GetPlayerPed(source)
end

function COREX.Server.GetPlayerCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function COREX.Server.GetDistanceBetweenPlayers(source1, source2)
    local coords1 = COREX.Server.GetPlayerCoords(source1)
    local coords2 = COREX.Server.GetPlayerCoords(source2)
    if not coords1 or not coords2 then return nil end
    return COREX.Utils.GetDistanceVec(coords1, coords2)
end

function COREX.Server.IsPlayerNearPlayer(source1, source2, maxDistance)
    local dist = COREX.Server.GetDistanceBetweenPlayers(source1, source2)
    return dist ~= nil and dist <= maxDistance
end

function COREX.Server.GetNearbyPlayers(source, maxDistance)
    local nearby = {}
    maxDistance = maxDistance or 5.0

    if not source or source <= 0 then
        return nearby
    end

    for _, otherSource in ipairs(COREX.Server.GetPlayerSources()) do
        if otherSource ~= source then
            local distance = COREX.Server.GetDistanceBetweenPlayers(source, otherSource)
            if distance and distance <= maxDistance then
                nearby[otherSource] = {
                    player = COREX.Functions and COREX.Functions.GetPlayer and COREX.Functions.GetPlayer(otherSource) or nil,
                    distance = distance
                }
            end
        end
    end

    return nearby
end

function COREX.Server.GetUptime()
    return os.time() - (GlobalState.serverStartTime or os.time())
end

function COREX.Server.BroadcastNearby(coords, radius, event, ...)
    if not coords or not event then return end
    radius = radius or 500.0
    local radiusSq = radius * radius
    local cx, cy, cz = coords.x or 0, coords.y or 0, coords.z or 0

    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src then
            local ped = GetPlayerPed(src)
            if ped and ped ~= 0 then
                local pc = GetEntityCoords(ped)
                local dx, dy, dz = pc.x - cx, pc.y - cy, pc.z - cz
                if (dx * dx + dy * dy + dz * dz) <= radiusSq then
                    TriggerClientEvent(event, src, ...)
                end
            end
        end
    end
end

function COREX.Server.BroadcastAll(event, ...)
    TriggerClientEvent(event, -1, ...)
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if not GlobalState.serverStartTime then
        GlobalState.serverStartTime = os.time()
    end
end)

COREX.Functions = COREX.Functions or {}
COREX.Functions.GetNearbyPlayers = COREX.Server.GetNearbyPlayers
COREX.Functions.BroadcastNearby = COREX.Server.BroadcastNearby
COREX.Functions.BroadcastAll = COREX.Server.BroadcastAll

exports('GetNearbyPlayers', function(...) return COREX.Server.GetNearbyPlayers(...) end)
exports('BroadcastNearby', function(...) return COREX.Server.BroadcastNearby(...) end)
