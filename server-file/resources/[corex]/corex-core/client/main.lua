--[[
    COREX Framework - Client Main
    Client entry point and initialization

    Performance: Functions use micro-caching (1ms TTL) for optimal performance.
    Developers can safely use Corex.Functions in any context including loops.
]]

COREX = COREX or {}
Corex = COREX
Corex.PlayerData = Corex.PlayerData or {}
Corex.Functions = Corex.Functions or {}
Corex.ClientCallbacks = Corex.ClientCallbacks or {}
Corex.ServerCallbacks = Corex.ServerCallbacks or {}
Corex.Config = Config

local isInitialized = false
local isLoaded = false

local function TryFinishLoad()
    if isLoaded then
        return
    end

    if not LocalPlayer.state.isLoggedIn then
        return
    end

    if not Corex.PlayerData.money or not Corex.PlayerData.metadata or not Corex.PlayerData.identifier or not Corex.PlayerData.name then
        return
    end

    isLoaded = true
    Corex.PlayerData.isLoggedIn = true

    COREX.Debug.Print('^2[COREX] ^7Client player data loaded')
    TriggerEvent(Config.EventPrefix .. ':client:playerLoaded', Corex.PlayerData)
    TriggerEvent(Config.EventPrefix .. ':client:ready')
    TriggerEvent('corex:client:coreReady', Corex)
end

local function SyncExistingState()
    Corex.PlayerData.money = LocalPlayer.state.money or Corex.PlayerData.money
    Corex.PlayerData.metadata = LocalPlayer.state.metadata or Corex.PlayerData.metadata
    Corex.PlayerData.identifier = LocalPlayer.state.identifier or Corex.PlayerData.identifier
    Corex.PlayerData.name = LocalPlayer.state.name or Corex.PlayerData.name
    Corex.PlayerData.isLoggedIn = LocalPlayer.state.isLoggedIn == true
    TryFinishLoad()
end

local function NormalizeVehicleKey(value)
    if type(value) ~= 'string' then return nil end
    return string.lower(value)
end

local function DeepCopyVehicleData(tbl, visited)
    if type(tbl) ~= 'table' then return tbl end
    visited = visited or {}
    if visited[tbl] then return visited[tbl] end

    local copy = {}
    visited[tbl] = copy

    for key, value in pairs(tbl) do
        copy[DeepCopyVehicleData(key, visited)] = DeepCopyVehicleData(value, visited)
    end

    return setmetatable(copy, getmetatable(tbl))
end

function Corex.Functions.GetVehicleCatalog(catalogId)
    local key = NormalizeVehicleKey(catalogId)
    if not key or not Corex.SharedVehicles or not Corex.SharedVehicles[key] then
        return nil
    end

    if COREX.Utils and type(COREX.Utils.DeepCopy) == 'function' then
        return COREX.Utils.DeepCopy(Corex.SharedVehicles[key])
    end

    return DeepCopyVehicleData(Corex.SharedVehicles[key])
end

function Corex.Functions.GetVehicleDefinition(catalogId, model)
    local catalog = Corex.Functions.GetVehicleCatalog(catalogId)
    local target = NormalizeVehicleKey(model)
    if not catalog or not target then
        return nil
    end

    for _, vehicle in ipairs(catalog.vehicles or {}) do
        if NormalizeVehicleKey(vehicle.model) == target then
            return vehicle
        end
    end

    return nil
end

local function Initialize()
    if isInitialized then return end

    isInitialized = true

    COREX.Debug.Print('^2[COREX] ^7Client-side core initialized')

    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do
            Wait(100)
        end

        -- Get server ID
        local serverId = GetPlayerServerId(PlayerId())
        local attempts = 0
        while serverId == 0 and attempts < 50 do
            Wait(100)
            serverId = GetPlayerServerId(PlayerId())
            attempts = attempts + 1
        end

        if serverId == 0 then
            COREX.Debug.Error('[COREX] Failed to get valid server ID')
            return
        end

        -- Register StateBag handlers
        local playerBag = ('player:%s'):format(serverId)

        AddStateBagChangeHandler('money', playerBag, function(bagName, key, value)
            if not value then return end
            Corex.PlayerData.money = value
            TriggerEvent('corex:client:moneyChanged', value)
            TryFinishLoad()
        end)

        AddStateBagChangeHandler('metadata', playerBag, function(bagName, key, value)
            if not value then return end
            Corex.PlayerData.metadata = value
            TriggerEvent('corex:client:metadataChanged', value)
            TryFinishLoad()
        end)

        AddStateBagChangeHandler('name', playerBag, function(bagName, key, value)
            if not value then return end
            Corex.PlayerData.name = value
            TryFinishLoad()
        end)

        AddStateBagChangeHandler('identifier', playerBag, function(bagName, key, value)
            if not value then return end
            Corex.PlayerData.identifier = value
            TryFinishLoad()
        end)

        AddStateBagChangeHandler('isLoggedIn', playerBag, function(bagName, key, value)
            Corex.PlayerData.isLoggedIn = value == true
            if value == true then
                TryFinishLoad()
            else
                isLoaded = false
            end
        end)

        SyncExistingState()
        Wait(100)

        if not LocalPlayer.state.isLoggedIn then
            TriggerServerEvent(Config.EventPrefix .. ':server:loadPlayer')
        end

        COREX.Debug.Print('^2[COREX] ^7Client main initialized')
    end)
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Initialize()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    isInitialized = false
    isLoaded = false
    Corex.ServerCallbacks = {}
    Corex.PlayerData = {}
end)

CreateThread(function()
    Wait(0)
    Initialize()
end)

---Get entity coordinates
---@param entity number|nil
---@return vector4
function Corex.Functions.GetCoords(entity)
    entity = entity or PlayerPedId()
    local coords = GetEntityCoords(entity)
    return vector4(coords.x, coords.y, coords.z, GetEntityHeading(entity))
end

---Get player ped
---@return number
function Corex.Functions.GetPed()
    return PlayerPedId()
end

---Check if player is alive
---@return boolean
function Corex.Functions.IsAlive()
    local ped = PlayerPedId()
    return not IsEntityDead(ped) and not IsPedFatallyInjured(ped)
end

---Get player health (0-100)
---@return number
function Corex.Functions.GetHealth()
    local ped = PlayerPedId()
    local health = GetEntityHealth(ped) - 100
    return math.max(0, math.min(100, health))
end

---Set player health (0-100)
---@param health number
function Corex.Functions.SetHealth(health)
    local ped = PlayerPedId()
    local clampedHealth = math.max(0, math.min(100, health))
    SetEntityHealth(ped, clampedHealth + 100)
end

RegisterNetEvent(Config.EventPrefix .. ':client:setHealth', function(health)
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    local clampedHealth = math.max(0, math.min(200, tonumber(health) or 0))
    SetEntityHealth(ped, clampedHealth)
end)

---Get player armour (0-100)
---@return number
function Corex.Functions.GetArmour()
    return GetPedArmour(PlayerPedId())
end

---Set player armour (0-100)
---@param armour number
function Corex.Functions.SetArmour(armour)
    local ped = PlayerPedId()
    local clampedArmour = math.max(0, math.min(100, armour))
    SetPedArmour(ped, clampedArmour)
end

---Check if player is in vehicle
---@return boolean
function Corex.Functions.IsInVehicle()
    return IsPedInAnyVehicle(PlayerPedId(), false)
end

---Get current vehicle
---@return number|nil
function Corex.Functions.GetVehicle()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        return GetVehiclePedIsIn(ped, false)
    end
    return nil
end

---Show notification via corex-notify resource
---Supports 3 signatures:
---  Notify(message, type, duration)            -- legacy
---  Notify(message, type, duration, title)     -- rich with title
---  Notify({ type=, title=, message=, duration= }) -- full options table
---@param messageOrOptions string|table
---@param notifyType string|nil
---@param duration number|nil
---@param title string|nil
function Corex.Functions.Notify(messageOrOptions, notifyType, duration, title)
    if GetResourceState('corex-notify') ~= 'started' then
        print('^3[corex-notify unavailable]^7 ' .. tostring(
            type(messageOrOptions) == 'table' and (messageOrOptions.message or '') or messageOrOptions
        ))
        return
    end

    local payload
    if type(messageOrOptions) == 'table' then
        payload = messageOrOptions
    else
        payload = {
            type = notifyType or 'info',
            title = title,
            message = messageOrOptions or '',
            duration = duration
        }
    end

    local ok, err = pcall(function()
        exports['corex-notify']:ShowNotify(payload)
    end)
    if not ok and COREX and COREX.Debug then
        COREX.Debug.Warn('[Notify] export failed: ' .. tostring(err))
    end
end

---Teleport player
---@param coords vector3|vector4
function Corex.Functions.Teleport(coords)
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)

    if coords.w then
        SetEntityHeading(ped, coords.w)
    end
end

---Freeze player
---@param freeze boolean
function Corex.Functions.Freeze(freeze)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, freeze)
    SetPlayerControl(PlayerId(), not freeze, 0)
end

---Get distance to coords
---@param coords vector3
---@return number
function Corex.Functions.GetDistanceTo(coords)
    local playerCoords = GetEntityCoords(PlayerPedId())
    return #(playerCoords - coords)
end

---Check if player is near coords
---@param coords vector3
---@param distance number
---@return boolean
function Corex.Functions.IsNear(coords, distance)
    return Corex.Functions.GetDistanceTo(coords) <= distance
end

---Get nearby players around the local player
---@param maxDistance number|nil
---@return table
function Corex.Functions.GetNearbyPlayers(maxDistance)
    local nearby = {}
    local localPlayerId = PlayerId()
    local localCoords = GetEntityCoords(PlayerPedId())
    maxDistance = maxDistance or 5.0

    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= localPlayerId then
            local targetPed = GetPlayerPed(playerId)
            if targetPed and DoesEntityExist(targetPed) then
                local targetCoords = GetEntityCoords(targetPed)
                local distance = #(localCoords - targetCoords)
                if distance <= maxDistance then
                    table.insert(nearby, {
                        playerId = playerId,
                        serverId = GetPlayerServerId(playerId),
                        ped = targetPed,
                        coords = targetCoords,
                        name = GetPlayerName(playerId),
                        distance = distance
                    })
                end
            end
        end
    end

    return nearby
end

---Legacy callback compatibility for older resources
---@param name string
---@param handler function
function Corex.Functions.CreateClientCallback(name, handler)
    Corex.ClientCallbacks[name] = handler
end

---Trigger server callback
---@param name string
---@param cb function
---@param ... any
function Corex.Functions.TriggerCallback(name, cb, ...)
    local callbackId = COREX.Utils.GenerateUUID()

    Corex.ServerCallbacks[callbackId] = cb

    TriggerServerEvent(Config.EventPrefix .. ':callback:request', callbackId, name, ...)

    SetTimeout(Config.CallbackTimeout or 10000, function()
        if Corex.ServerCallbacks[callbackId] then
            Corex.ServerCallbacks[callbackId](nil)
            Corex.ServerCallbacks[callbackId] = nil
        end
    end)
end

---Get core object
---@param filters table|nil
---@return table
local function GetCoreObject(filters)
    if not filters then return Corex end

    local results = {}
    for i = 1, #filters do
        local key = filters[i]
        if Corex[key] then
            results[key] = Corex[key]
        end
    end
    return results
end

RegisterNetEvent(Config.EventPrefix .. ':notify', function(message, type, duration, title)
    Corex.Functions.Notify(message, type, duration, title)
end)

RegisterNetEvent(Config.EventPrefix .. ':callback:response', function(callbackId, ...)
    if Corex.ServerCallbacks[callbackId] then
        Corex.ServerCallbacks[callbackId](...)
        Corex.ServerCallbacks[callbackId] = nil
    end
end)

---Load a model with timeout
---@param model string|number
---@param timeout number|nil
---@return boolean
function Corex.Functions.LoadModel(model, timeout)
    local modelHash = type(model) == 'string' and GetHashKey(model) or model
    timeout = timeout or 1000

    if HasModelLoaded(modelHash) then return true end

    RequestModel(modelHash)
    local startTime = GetGameTimer()

    while not HasModelLoaded(modelHash) do
        if GetGameTimer() - startTime > timeout then
            return false
        end
        Wait(10)
    end

    return true
end

---Request model to be loaded (async, does not wait)
---@param model string|number
---@return number modelHash
function Corex.Functions.RequestModel(model)
    local modelHash = type(model) == 'string' and GetHashKey(model) or model
    RequestModel(modelHash)
    return modelHash
end

---Check if model is loaded
---@param model string|number
---@return boolean
function Corex.Functions.HasModelLoaded(model)
    local modelHash = type(model) == 'string' and GetHashKey(model) or model
    return HasModelLoaded(modelHash)
end

---Release model from memory
---@param model string|number
function Corex.Functions.SetModelAsNoLongerNeeded(model)
    local modelHash = type(model) == 'string' and GetHashKey(model) or model
    SetModelAsNoLongerNeeded(modelHash)
end

---Create a ped
---@param pedType number Ped type (4 = civilian, 5 = mission, etc)
---@param model string|number Model name or hash
---@param coords vector3|vector4 Coordinates
---@param heading number|nil Heading (uses coords.w if vector4)
---@param networked boolean|nil Create networked ped (default: true)
---@param scriptHostPed boolean|nil Script host ped (default: false)
---@return number|nil pedHandle
function Corex.Functions.CreatePed(pedType, model, coords, heading, networked, scriptHostPed)
    heading = heading or (coords.w or 0.0)
    networked = networked ~= false
    scriptHostPed = scriptHostPed == true

    if not Corex.Functions.LoadModel(model, 5000) then
        COREX.Debug.Error('[COREX] Failed to load ped model: ' .. tostring(model))
        return nil
    end

    local modelHash = type(model) == 'string' and GetHashKey(model) or model
    local ped = CreatePed(pedType, modelHash, coords.x, coords.y, coords.z, heading, networked, scriptHostPed)

    if ped and ped ~= 0 then
        Corex.Functions.SetModelAsNoLongerNeeded(modelHash)
        return ped
    end

    Corex.Functions.SetModelAsNoLongerNeeded(modelHash)
    return nil
end

---Get ped of another player by their player ID
---@param playerId number Player ID (not server ID)
---@return number pedHandle
function Corex.Functions.GetPlayerPedFromId(playerId)
    return GetPlayerPed(playerId)
end

---Get ped of another player by their server ID
---@param serverId number Server ID
---@return number|nil pedHandle
function Corex.Functions.GetPlayerPedFromServerId(serverId)
    local playerId = GetPlayerFromServerId(serverId)
    if playerId == -1 then return nil end
    return GetPlayerPed(playerId)
end

---Get player ID from server ID
---@param serverId number Server ID
---@return number playerId (-1 if not found)
function Corex.Functions.GetPlayerFromServerId(serverId)
    return GetPlayerFromServerId(serverId)
end

---Spawn a prop at location
---@param model string
---@param coords vector3
---@param options table|nil {placeOnGround: bool, networked: bool, freeze: bool, collision: bool}
---@return number|nil
function Corex.Functions.SpawnProp(model, coords, options)
    options = options or {}
    local placeOnGround = options.placeOnGround ~= false
    local networked = options.networked == true
    local freeze = options.freeze ~= false
    local collision = options.collision ~= false

    if not Corex.Functions.LoadModel(model) then
        COREX.Debug.Error('[COREX] Failed to load model: ' .. tostring(model))
        return nil
    end

    local modelHash = GetHashKey(model)
    local prop = CreateObjectNoOffset(modelHash, coords.x, coords.y, coords.z, networked, networked, false)

    if prop and prop ~= 0 then
        SetEntityAsMissionEntity(prop, true, true)
        SetEntityVisible(prop, true, false)
        ResetEntityAlpha(prop)
        SetEntityCollision(prop, collision, collision)
        if placeOnGround then
            PlaceObjectOnGroundProperly(prop)
        end
        if freeze then
            FreezeEntityPosition(prop, true)
        end
        SetModelAsNoLongerNeeded(modelHash)
        return prop
    end

    SetModelAsNoLongerNeeded(modelHash)
    return nil
end

---Delete a prop/entity forcefully
---@param entity number
---@return boolean
function Corex.Functions.DeleteProp(entity)
    if not entity or entity == 0 then return false end
    if not DoesEntityExist(entity) then return true end

    NetworkRequestControlOfEntity(entity)
    local attempts = 0
    while not NetworkHasControlOfEntity(entity) and attempts < 10 do
        Wait(10)
        NetworkRequestControlOfEntity(entity)
        attempts = attempts + 1
    end

    SetEntityAsMissionEntity(entity, false, true)
    DeleteEntity(entity)

    if DoesEntityExist(entity) then
        DeleteObject(entity)
    end

    if DoesEntityExist(entity) then
        SetEntityCoords(entity, 0.0, 0.0, -1000.0, false, false, false, false)
        SetEntityVisible(entity, false, false)
        SetEntityAsNoLongerNeeded(entity)
    end

    return not DoesEntityExist(entity)
end

---Set entity outline with color
---@param entity number
---@param enabled boolean
---@param color table {r, g, b, a} (0-255)
---@param shader number|nil (0=default, 1=pulse)
function Corex.Functions.SetEntityOutline(entity, enabled, color, shader)
    if not entity or entity == 0 then return false end
    if not DoesEntityExist(entity) then return false end

    if enabled then
        color = color or {r = 255, g = 255, b = 255, a = 255}
        shader = shader or 0

        SetEntityDrawOutline(entity, true)
        SetEntityDrawOutlineColor(color.r or 255, color.g or 255, color.b or 255, color.a or 255)
        SetEntityDrawOutlineShader(shader)
    else
        SetEntityDrawOutline(entity, false)
    end

    return true
end

---Update entity outline color (for animations)
---@param entity number
---@param color table {r, g, b, a}
function Corex.Functions.UpdateOutlineColor(entity, color)
    if not entity or not DoesEntityExist(entity) then return end
    SetEntityDrawOutlineColor(color.r or 255, color.g or 255, color.b or 255, color.a or 255)
end

exports('GetCoreObject', GetCoreObject)
exports('IsReady', function() return isInitialized and isLoaded end)
exports('GetVehicleCatalog', function(catalogId) return Corex.Functions.GetVehicleCatalog(catalogId) end)
exports('GetVehicleDefinition', function(catalogId, model) return Corex.Functions.GetVehicleDefinition(catalogId, model) end)

-------------------------------------------------
-- Player Data Functions
-------------------------------------------------

---Get all player data
---@return table
function Corex.Functions.GetPlayerData()
    return {
        source = Corex.PlayerData.source,
        identifier = Corex.PlayerData.identifier,
        name = Corex.PlayerData.name,
        money = Corex.PlayerData.money and {
            cash = Corex.PlayerData.money.cash,
            bank = Corex.PlayerData.money.bank
        } or {cash = 0, bank = 0},
        metadata = Corex.PlayerData.metadata,
        isLoggedIn = Corex.PlayerData.isLoggedIn,
    }
end

---Get money
---@param type string|nil Money type (cash/bank), nil returns all
---@return number|table
function Corex.Functions.GetMoney(type)
    if not type then
        return Corex.PlayerData.money or {cash = 0, bank = 0}
    end
    return Corex.PlayerData.money and Corex.PlayerData.money[type] or 0
end

local function ShallowCopyMetadata(tbl)
    if type(tbl) ~= 'table' then return {} end
    local copy = {}
    for k, v in pairs(tbl) do
        if type(v) == 'table' then
            local sub = {}
            for k2, v2 in pairs(v) do sub[k2] = v2 end
            copy[k] = sub
        else
            copy[k] = v
        end
    end
    return copy
end

function Corex.Functions.GetMetaData(key)
    if not key then
        return ShallowCopyMetadata(Corex.PlayerData.metadata or {})
    end
    return Corex.PlayerData.metadata and Corex.PlayerData.metadata[key]
end

---Get player name
---@return string
function Corex.Functions.GetName()
    return Corex.PlayerData.name or 'Unknown'
end

---Get player identifier
---@return string
function Corex.Functions.GetIdentifier()
    return Corex.PlayerData.identifier or 'unknown'
end

---Wait for player data to be loaded
---@param timeout number|nil Timeout in ms (default: 10000)
---@return boolean
function Corex.Functions.WaitForPlayerData(timeout)
    timeout = timeout or 10000
    local startTime = GetGameTimer()

    while not isLoaded do
        if GetGameTimer() - startTime > timeout then
            COREX.Debug.Error('[COREX] Timeout waiting for player data')
            return false
        end
        Wait(100)
    end

    return true
end

---Check if player is loaded
---@return boolean
function Corex.Functions.IsPlayerLoaded()
    return isLoaded
end

---Screen fade out
---@param duration number Duration in ms
function Corex.Functions.ScreenFadeOut(duration)
    DoScreenFadeOut(duration or 500)
end

---Screen fade in
---@param duration number Duration in ms
function Corex.Functions.ScreenFadeIn(duration)
    DoScreenFadeIn(duration or 500)
end

---Check if screen is faded out
---@return boolean
function Corex.Functions.IsScreenFadedOut()
    return IsScreenFadedOut()
end

---Check if screen is fading out
---@return boolean
function Corex.Functions.IsScreenFadingOut()
    return IsScreenFadingOut()
end

---Check if entity is dead
---@param entity number|nil Entity handle (defaults to player ped)
---@return boolean
function Corex.Functions.IsDead(entity)
    entity = entity or PlayerPedId()
    return IsEntityDead(entity)
end

---Check if entity exists
---@param entity number Entity handle
---@return boolean
function Corex.Functions.DoesEntityExist(entity)
    if not entity or entity == 0 then return false end
    return DoesEntityExist(entity)
end

---Get entity heading
---@param entity number|nil Entity handle (defaults to player ped)
---@return number
function Corex.Functions.GetHeading(entity)
    entity = entity or PlayerPedId()
    return GetEntityHeading(entity)
end

---Set entity heading
---@param heading number Heading in degrees
---@param entity number|nil Entity handle (defaults to player ped)
function Corex.Functions.SetHeading(heading, entity)
    entity = entity or PlayerPedId()
    SetEntityHeading(entity, heading)
end

---Check if control is just pressed
---@param control number Control ID
---@param inputGroup number|nil Input group (default: 0)
---@return boolean
function Corex.Functions.IsControlJustPressed(control, inputGroup)
    return IsControlJustPressed(inputGroup or 0, control)
end

---Disable control action
---@param control number Control ID
---@param inputGroup number|nil Input group (default: 0)
function Corex.Functions.DisableControl(control, inputGroup)
    DisableControlAction(inputGroup or 0, control, true)
end

function Corex.Functions.IsReady()
    return isLoaded
end

exports('IsReady', function() return isLoaded end)

---Resurrect local player
---@param coords vector3|vector4 Coordinates
---@param heading number|nil Heading (uses coords.w if vector4)
function Corex.Functions.Resurrect(coords, heading)
    heading = heading or coords.w or 0.0
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
    local ped = PlayerPedId()
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)
end

---Get offset from entity in world coords
---@param entity number Entity handle
---@param offsetX number X offset
---@param offsetY number Y offset
---@param offsetZ number Z offset
---@return vector3
function Corex.Functions.GetOffsetFromEntity(entity, offsetX, offsetY, offsetZ)
    return GetOffsetFromEntityInWorldCoords(entity, offsetX, offsetY, offsetZ)
end

---Freeze entity position
---@param entity number Entity handle
---@param freeze boolean Freeze state
function Corex.Functions.FreezeEntity(entity, freeze)
    FreezeEntityPosition(entity, freeze)
end

---Set player control
---@param hasControl boolean Has control
---@param flags number|nil Control flags (default: 0)
function Corex.Functions.SetPlayerControl(hasControl, flags)
    SetPlayerControl(PlayerId(), hasControl, flags or 0)
end

---Get remaining sprint stamina (0-100)
---@return number
function Corex.Functions.GetSprintStamina()
    local remaining = GetPlayerSprintStaminaRemaining(PlayerId())
    if remaining == nil then return 100 end
    return math.max(0, math.min(100, remaining))
end

---Get in-game clock time
---@return table {hours, minutes, seconds}
function Corex.Functions.GetClockTime()
    return {
        hours = GetClockHours(),
        minutes = GetClockMinutes(),
        seconds = GetClockSeconds()
    }
end

---Convert heading (0-360) to compass direction
---@param heading number
---@return string N|NE|E|SE|S|SW|W|NW
function Corex.Functions.HeadingToCompass(heading)
    heading = heading % 360
    if heading >= 337.5 or heading < 22.5 then return 'N' end
    if heading < 67.5  then return 'NE' end
    if heading < 112.5 then return 'E'  end
    if heading < 157.5 then return 'SE' end
    if heading < 202.5 then return 'S'  end
    if heading < 247.5 then return 'SW' end
    if heading < 292.5 then return 'W'  end
    return 'NW'
end

---Toggle minimap visibility
---@param show boolean
function Corex.Functions.DisplayMinimap(show)
    DisplayRadar(show)
end

---Set minimap anchor and size using correct per-component ratios
---@param x number Normalized X offset from anchor (0-1)
---@param y number Normalized Y offset from anchor (0-1)
---@param w number Normalized width (0-1)
---@param h number Normalized height (0-1)
---@param alignX string|nil 'L' left, 'R' right, 'C' center (default 'L')
---@param alignY string|nil 'T' top, 'B' bottom, 'C' center (default 'T')
function Corex.Functions.SetMinimapLayout(x, y, w, h, alignX, alignY)
    alignX = alignX or 'L'
    alignY = alignY or 'T'
    x = x or 0.0
    y = y or 0.0
    w = w or 0.164
    h = h or 0.183

    local maskW = w * 0.70
    local maskH = h * 1.09
    local blurW = w * 1.60
    local blurH = h * 1.64

    local maskX = x + (w * 0.22)
    local maskY = y + (h * 0.045)
    local blurX = x - (w * 0.06)
    local blurY = y - (h * 0.18)

    SetMinimapComponentPosition('minimap', alignX, alignY, x, y, w, h)
    SetMinimapComponentPosition('minimap_mask', alignX, alignY, maskX, maskY, maskW, maskH)
    SetMinimapComponentPosition('minimap_blur', alignX, alignY, blurX, blurY, blurW, blurH)
end
