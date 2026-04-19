--[[
    COREX Spawn - Server Side
    Handles player registration and spawn logic
    Functional Lua | No OOP | Zombie Survival Optimized
]]

local spawnedPlayers = {}
local readyForPositionSave = {}
local MAP_BOUNDS = {
    minX = -7000.0,
    maxX = 7000.0,
    minY = -7000.0,
    maxY = 9000.0,
    minZ = -250.0,
    maxZ = 2000.0
}

-- -------------------------------------------------
-- INTERNAL HELPERS
-- -------------------------------------------------

---Get player using new corex-core export
---@param source number
---@return table|nil
local function GetPlayer(source)
    local success, player = pcall(function()
        return exports['corex-core']:GetPlayer(source)
    end)
    if success and player then
        return player
    end
    return nil
end

---Debug logging
---@param level string
---@param msg string
local function Debug(level, msg)
    if not Config.Debug and level ~= 'Error' then return end
    local colors = { Error = '^1', Warn = '^3', Info = '^2', Verbose = '^5' }
    print((colors[level] or '^7') .. '[COREX-SPAWN] ' .. msg .. '^0')
end

local function SetSpawnState(source, state)
    pcall(function()
        exports['corex-core']:SetPlayerState(source, state)
    end)
end

local function GetSpawnState(source)
    local lifecycleState = nil
    local success, err = pcall(function()
        lifecycleState = exports['corex-core']:GetPlayerState(source)
    end)

    if not success then
        if COREX and COREX.Debug then
            COREX.Debug.Warn('[Spawn] GetPlayerState failed for ' .. tostring(source) .. ': ' .. tostring(err))
        else
            print('^3[corex-spawn] GetPlayerState failed for ' .. tostring(source) .. ': ' .. tostring(err) .. '^0')
        end
        return nil
    end

    return lifecycleState
end

local function IsValidSpawnPosition(position)
    if type(position) ~= 'table' then
        return false
    end

    local x = tonumber(position.x)
    local y = tonumber(position.y)
    local z = tonumber(position.z)
    if not x or not y or not z then
        return false
    end

    if x < MAP_BOUNDS.minX or x > MAP_BOUNDS.maxX then
        return false
    end

    if y < MAP_BOUNDS.minY or y > MAP_BOUNDS.maxY then
        return false
    end

    if z < MAP_BOUNDS.minZ or z > MAP_BOUNDS.maxZ then
        return false
    end

    return true
end

local function ClonePosition(position)
    if type(position) ~= 'table' then
        return nil
    end

    return {
        x = tonumber(position.x) or 0.0,
        y = tonumber(position.y) or 0.0,
        z = tonumber(position.z) or 0.0,
        heading = tonumber(position.heading or position.w) or 0.0
    }
end

local function GetConfiguredSpawn()
    local configured = Config.DefaultSpawnLocation or Config.FirstSpawnLocation
    if not IsValidSpawnPosition(configured) then
        return ClonePosition(Config.FirstSpawnLocation)
    end
    return ClonePosition(configured)
end

local function ResolveSpawnPosition(player, options)
    options = options or {}

    if options.isNew then
        return ClonePosition(Config.FirstSpawnLocation or Config.DefaultSpawnLocation)
    end

    if options.useLastPosition and player and player.metadata and IsValidSpawnPosition(player.metadata.lastPosition) then
        return ClonePosition(player.metadata.lastPosition)
    end

    return GetConfiguredSpawn()
end

local function CaptureLivePlayerPosition(source)
    local ok, core = pcall(function()
        return exports['corex-core']:GetCoreObject()
    end)
    if not ok or not core or not core.Functions then
        return nil
    end

    local ped = core.Functions.GetPlayerPed and core.Functions.GetPlayerPed(source)
    if not ped or ped == 0 then
        return nil
    end

    local coords = core.Functions.GetCoords and core.Functions.GetCoords(ped)
    if not coords or coords.x == nil or coords.y == nil or coords.z == nil then
        return nil
    end

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = coords.w
    }
end

local function IsPositionSaveReady(source, player)
    if not Config.SaveLastLocation or not readyForPositionSave[source] or not player then
        return false
    end

    if not player.metadata or not player.metadata.skin then
        return false
    end

    local lifecycleState = GetSpawnState(source)
    if not lifecycleState then
        return false
    end

    return lifecycleState == 'active'
end

---Ensure survival stats exist in metadata
---@param player table
---@return table
local function ValidateSurvivalStats(player)
    if not player or not player.metadata then return player end

    local defaults = { hunger = 100, thirst = 100, stress = 0, infection = 0 }

    for stat, value in pairs(defaults) do
        if player.metadata[stat] == nil then
            pcall(function()
                exports['corex-core']:SetStat(player.source, stat, value)
            end)
            Debug('Warn', 'Initialized missing stat: ' .. stat .. ' for ' .. player.name)
        end
    end

    return player
end

-- -------------------------------------------------
-- SPAWN LOGIC
-- -------------------------------------------------

---@param source number
---@param player table
---@param options table|boolean|nil
function CheckAndSpawnPlayer(source, player, options)
    if not player then
        Debug('Error', 'CheckAndSpawnPlayer called with nil player for source ' .. source)
        return
    end

    if type(options) == 'boolean' then
        options = { isResourceRestart = options }
    end
    options = options or {}

    local isResourceRestart = options.isResourceRestart == true
    local isRespawn = options.isRespawn == true
    local lifecycleState = GetSpawnState(source)

    if lifecycleState == 'dead' and not isRespawn then
        Debug('Info', 'Blocked spawn while player is dead: ' .. tostring(source))
        return
    end

    -- Skip if already spawned (unless resource restart)
    if spawnedPlayers[source] and not isResourceRestart and not isRespawn then
        return
    end

    -- Validate survival stats BEFORE spawn
    player = ValidateSurvivalStats(player)
    readyForPositionSave[source] = false
    SetSpawnState(source, 'loading')

    local skin = player.metadata and player.metadata.skin
    local position = ResolveSpawnPosition(player, {
        isNew = not skin,
        useLastPosition = not isRespawn
    })
    local name = player.name
    local money = player.money

    -- Sync survival stats to statebag BEFORE triggering client spawn
    local pState = Player(source).state
    if pState then
        pState:set('metadata', player.metadata, true)
        pState:set('money', player.money, true)
        pState:set('isLoggedIn', true, true)
    end

    -- Trigger spawn event
    if skin then
        TriggerClientEvent('corex-spawn:client:spawnPlayer', source, {
            isNew = false,
            position = position,
            skin = skin,
            isRespawn = isRespawn,
            isResourceRestart = isResourceRestart or false,
            playerData = {
                name = name,
                money = money,
                metadata = player.metadata -- Send full metadata
            }
        })
    else
        TriggerClientEvent('corex-spawn:client:spawnPlayer', source, {
            isNew = true,
            position = position,
            skin = nil,
            isRespawn = false,
            isResourceRestart = false,
            playerData = nil
        })
    end

    spawnedPlayers[source] = true
    Debug('Info', 'Spawned player: ' .. (name or 'Unknown') .. ' (Source: ' .. source .. ')')
end

-- -------------------------------------------------
-- EVENTS
-- -------------------------------------------------

-- Player ready from corex-core
AddEventHandler('corex:server:playerReady', function(source, player)
    if not player then return end

    CreateThread(function()
        Wait(1500) -- Allow statebag sync
        CheckAndSpawnPlayer(source, player, { isResourceRestart = false })
    end)
end)

-- Client requests check (fallback)
RegisterNetEvent('corex-spawn:server:checkPlayer', function()
    local source = source
    local player = GetPlayer(source)
    if player then
        CheckAndSpawnPlayer(source, player, { isResourceRestart = false })
    end
end)

AddEventHandler('corex-spawn:server:playerDied', function(source)
    readyForPositionSave[source] = false
    spawnedPlayers[source] = nil
end)

RegisterNetEvent('corex-spawn:server:respawnPlayer', function()
    local source = source
    local player = GetPlayer(source)
    if not player then return end

    readyForPositionSave[source] = false
    spawnedPlayers[source] = nil

    CheckAndSpawnPlayer(source, player, {
        isRespawn = true,
        isResourceRestart = false
    })
end)

-- Save skin
RegisterNetEvent('corex-spawn:server:saveSkin', function(skinData)
    local source = source
    if type(skinData) ~= 'table' then return end
    local player = GetPlayer(source)
    if not player then return end

    -- Use new export
    local success = pcall(function()
        exports['corex-core']:SetMetaData(source, 'skin', skinData)
    end)

    if success then
        pcall(function()
            exports['corex-core']:SavePlayer(source, true)
        end)
        TriggerClientEvent('corex-spawn:client:skinSaved', source)
        Debug('Info', 'Saved skin for ' .. player.name)
    end
end)

RegisterNetEvent('corex-spawn:server:markSpawnReady', function(position)
    local source = source
    local player = GetPlayer(source)
    if not player then return end

    if not player.metadata or not player.metadata.skin then
        Debug('Warn', 'Ignored spawn ready for player without skin: ' .. tostring(source))
        return
    end

    readyForPositionSave[source] = true
    SetSpawnState(source, 'active')

    if Config.SaveLastLocation and type(position) == 'table' then
        pcall(function()
            exports['corex-core']:SetMetaData(source, 'lastPosition', position)
        end)
    end

    Debug('Info', 'Player is now ready for position saving: ' .. player.name)
end)

-- Save position
RegisterNetEvent('corex-spawn:server:savePosition', function(position)
    local source = source
    if not Config.SaveLastLocation then return end

    local player = GetPlayer(source)
    if not player then return end

    if not IsPositionSaveReady(source, player) then
        return
    end

    if type(position) ~= 'table' or type(position.x) ~= 'number' or type(position.y) ~= 'number' or type(position.z) ~= 'number' then
        return
    end

    pcall(function()
        exports['corex-core']:SetMetaData(source, 'lastPosition', position)
    end)
end)

-- Player dropped
AddEventHandler('playerDropped', function(reason)
    local source = source
    local player = GetPlayer(source)

    if player then
        local livePosition = CaptureLivePlayerPosition(source)
        if Config.SaveLastLocation and IsPositionSaveReady(source, player) and IsValidSpawnPosition(livePosition) then
            pcall(function()
                exports['corex-core']:SetMetaData(source, 'lastPosition', livePosition)
            end)
        end

        Debug('Info', 'Player ' .. player.name .. ' disconnected: ' .. reason)
        pcall(function()
            exports['corex-core']:SavePlayer(source, true)
        end)
    end

    spawnedPlayers[source] = nil
    readyForPositionSave[source] = nil
end)

-- Auto save position loop — skips entirely when no players are spawned
-- to avoid scanning an empty table every minute.
CreateThread(function()
    while true do
        Wait(60000)

        if next(spawnedPlayers) == nil then
            goto continue
        end

        for source, _ in pairs(spawnedPlayers) do
            local player = GetPlayer(source)
            if IsPositionSaveReady(source, player) then
                TriggerClientEvent('corex-spawn:client:requestPosition', source)
            end
        end

        ::continue::
    end
end)

-- Resource restart handler
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    Wait(2000)

    local ok, coreObj = pcall(function()
        return exports['corex-core']:GetCoreObject()
    end)
    if not ok or not coreObj or not coreObj.Functions then return end

    local players = coreObj.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        local source = tonumber(playerId)
        local player = GetPlayer(source)
        if player then
            CreateThread(function()
                CheckAndSpawnPlayer(source, player, { isResourceRestart = true })
            end)
        end
    end
end)

-- -------------------------------------------------
-- EXPORTS
-- -------------------------------------------------

exports('GetPlayerSkin', function(source)
    local player = GetPlayer(source)
    return player and player.metadata and player.metadata.skin or nil
end)

exports('GetPlayerPosition', function(source)
    local player = GetPlayer(source)
    return player and player.metadata and player.metadata.lastPosition or nil
end)

exports('SetPlayerSkin', function(source, skinData)
    local success = pcall(function()
        exports['corex-core']:SetMetaData(source, 'skin', skinData)
    end)
    return success
end)

-- Debug command
RegisterCommand('resetchar', function(source, args, rawCommand)
    if source == 0 then return end

    local player = GetPlayer(source)
    if not player then return end

    pcall(function()
        exports['corex-core']:SetMetaData(source, 'skin', nil)
        exports['corex-core']:SetMetaData(source, 'lastPosition', nil)
        exports['corex-core']:SavePlayer(source, true)
    end)

    spawnedPlayers[source] = nil
    readyForPositionSave[source] = false
    SetSpawnState(source, 'loading')

    TriggerClientEvent('corex-spawn:client:spawnPlayer', source, {
        isNew = true,
        position = nil,
        skin = nil,
        isResourceRestart = false,
        playerData = nil
    })

    Debug('Info', 'Character reset for ' .. player.name)
end, true)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for source, _ in pairs(spawnedPlayers) do
        pcall(function()
            exports['corex-core']:SavePlayer(source, true)
        end)
    end
    spawnedPlayers = {}
    readyForPositionSave = {}
end)
