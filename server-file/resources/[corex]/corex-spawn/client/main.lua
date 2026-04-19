--[[
    COREX Spawn - Client Side
    Handles player spawning and character creation UI
    Functional Lua | No OOP | Zombie Survival Optimized
]]

local Corex = nil
local isFirstSpawn = true
local isUIOpen = false
local playerLoaded = false
local currentSkin = {}
local creationCam = nil
local hasSpawned = false
local savedSkin = nil
local spawnReadySent = false
local spawnManagerGuardInstalled = false

-- Wait for corex-core
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
            print('[COREX-SPAWN] ^1Failed to connect to corex-core^0')
            return
        end
    end
    print('[COREX-SPAWN] ^2Connected to corex-core^0')
end)

-- Wait for statebag (isLoggedIn) before proceeding
local function WaitForStateBag()
    local timeout = 0
    while not LocalPlayer.state.isLoggedIn and timeout < 100 do
        Wait(100)
        timeout = timeout + 1
    end
    return LocalPlayer.state.isLoggedIn == true
end

local function ResolveSpawnGroundZ(x, y, z)
    local probeHeights = { 0.0, 1.0, 2.0, 5.0, 10.0, 25.0, 50.0 }

    for _, offset in ipairs(probeHeights) do
        local found, groundZ = GetGroundZFor_3dCoord(x, y, z + offset, false)
        if found then
            return groundZ
        end
    end

    return nil
end

local function InstallSpawnManagerGuard()
    local ok = pcall(function()
        exports.spawnmanager:setAutoSpawnCallback(function()
            if Config.Debug then
                print('[COREX-SPAWN] ^3Blocked default spawnmanager auto-respawn^0')
            end
        end)
    end)

    if ok then
        spawnManagerGuardInstalled = true
    end

    pcall(function()
        exports.spawnmanager:setAutoSpawn(false)
    end)
end

local function NormalizePlayerState()
    local ped = PlayerPedId()

    if creationCam then
        RenderScriptCams(false, true, 0, true, false)
        DestroyCam(creationCam, false)
        creationCam = nil
    else
        RenderScriptCams(false, true, 0, true, false)
    end

    ClearFocus()

    if DoesEntityExist(ped) then
        ResetEntityAlpha(ped)
        SetEntityVisible(ped, true, false)
        SetEntityCollision(ped, true, true)
        FreezeEntityPosition(ped, false)
        SetEntityInvincible(ped, false)
    end

    SetPlayerInvincible(PlayerId(), false)
    SetPlayerControl(PlayerId(), true, 0)

    if NetworkSetInSpectatorMode then
        NetworkSetInSpectatorMode(false, ped)
    end
end

local function ScheduleSpawnStateNormalization()
    CreateThread(function()
        NormalizePlayerState()
        Wait(250)
        NormalizePlayerState()
        Wait(1000)
        NormalizePlayerState()
        Wait(2000)
        NormalizePlayerState()
    end)
end

local function PlacePlayerAtSpawn(spawn, options)
    options = options or {}

    local ped = Corex.Functions.GetPed()
    if not DoesEntityExist(ped) then
        return false
    end

    local heading = spawn.heading or spawn.w or 0.0
    local targetZ = spawn.z + (options.zOffset or 0.0)
    local allowGroundSnap = options.allowGroundSnap ~= false

    SetEntityVisible(ped, false, false)
    Corex.Functions.FreezeEntity(ped, true)
    SetEntityLoadCollisionFlag(ped, true)
    RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
    NewLoadSceneStartSphere(spawn.x, spawn.y, spawn.z, 25.0, 0)

    local collisionLoaded = false
    for _ = 1, 50 do
        Wait(100)
        RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
        if HasCollisionLoadedAroundEntity(ped) then
            collisionLoaded = true
            break
        end
    end

    if allowGroundSnap then
        local groundZ = ResolveSpawnGroundZ(spawn.x, spawn.y, spawn.z)
        if groundZ then
            targetZ = groundZ + 0.03
        elseif collisionLoaded then
            targetZ = spawn.z - 0.05
        end
    end

    SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, targetZ, false, false, false)
    SetEntityHeading(ped, heading)

    for _ = 1, 20 do
        Wait(100)

        if allowGroundSnap then
            local coords = Corex.Functions.GetCoords(ped)
            local currentGroundZ = ResolveSpawnGroundZ(coords.x, coords.y, coords.z)
            if currentGroundZ and math.abs(coords.z - currentGroundZ) > 0.08 then
                SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, currentGroundZ + 0.03, false, false, false)
                SetEntityHeading(ped, heading)
            end
        end

        if not IsEntityInAir(ped) and not IsPedFalling(ped) then
            break
        end
    end

    if allowGroundSnap and (IsEntityInAir(ped) or IsPedFalling(ped)) then
        SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, spawn.z - 0.15, false, false, false)
        SetEntityHeading(ped, heading)
    end

    NewLoadSceneStop()
    SetEntityVisible(ped, true, false)
    Corex.Functions.FreezeEntity(ped, false)
    return true
end

local function SendSpawnReady()
    if spawnReadySent or not playerLoaded or not savedSkin or not savedSkin.model then
        return
    end

    local ped = Corex and Corex.Functions and Corex.Functions.GetPed and Corex.Functions.GetPed()
    if not DoesEntityExist(ped) then
        return
    end

    CreateThread(function()
        local settled = false

        for _ = 1, 50 do
            Wait(200)

            ped = Corex and Corex.Functions and Corex.Functions.GetPed and Corex.Functions.GetPed() or 0
            if DoesEntityExist(ped) and not IsPedFalling(ped) and not IsEntityInAir(ped) then
                local coords = Corex.Functions.GetCoords(ped)
                if coords.z > 0.0 then
                    local groundFound, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 2.0, false)
                    if groundFound and math.abs(coords.z - groundZ) <= 2.5 then
                        settled = true
                        break
                    end
                end
            end
        end

        if not settled then
            return
        end

        local coords = Corex.Functions.GetCoords(ped)
        spawnReadySent = true
        TriggerServerEvent('corex-spawn:server:markSpawnReady', {
            x = coords.x,
            y = coords.y,
            z = coords.z,
            heading = coords.w
        })
    end)
end

-- Disable auto spawn on resource start and load player data
AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    InstallSpawnManagerGuard()

    print('[COREX-SPAWN] ^3Resource started^0')

    CreateThread(function()
        if SetManualShutdownLoadingScreenNui then
            pcall(SetManualShutdownLoadingScreenNui, true)
        end

        Wait(1500)

        if ShutdownLoadingScreenNui then
            pcall(ShutdownLoadingScreenNui)
        end
        if ShutdownLoadingScreen then
            pcall(ShutdownLoadingScreen)
        end

        if not LocalPlayer.state.isLoggedIn then
            TriggerServerEvent('corex:server:loadPlayer')
            print('[COREX-SPAWN] ^2Requested player load^0')
        end
    end)
end)

AddEventHandler('onClientMapStart', function()
    InstallSpawnManagerGuard()

    CreateThread(function()
        Wait(1000)
        InstallSpawnManagerGuard()
    end)
end)

CreateThread(function()
    Wait(3000)
    InstallSpawnManagerGuard()
end)

CreateThread(function()
    Wait(20000)
    if not playerLoaded and not isUIOpen then
        print('[COREX-SPAWN] ^1EMERGENCY: spawn flow stalled after 20s, forcing recovery^0')
        if ShutdownLoadingScreenNui then pcall(ShutdownLoadingScreenNui) end
        if ShutdownLoadingScreen then pcall(ShutdownLoadingScreen) end

        local ped = PlayerPedId()
        if ped and ped ~= 0 then
            SetEntityVisible(ped, true, false)
            ResetEntityAlpha(ped)
            FreezeEntityPosition(ped, false)
            SetPlayerControl(PlayerId(), true, 0)
        end

        if creationCam then
            RenderScriptCams(false, true, 0, true, false)
            DestroyCam(creationCam, false)
            creationCam = nil
        end
        ClearFocus()
        DoScreenFadeIn(500)

        if not LocalPlayer.state.isLoggedIn then
            TriggerServerEvent('corex:server:loadPlayer')
        end
    end
end)

-- Death handling moved to corex-death resource

AddEventHandler('corex-spawn:client:reapplySkin', function()
    if savedSkin then
        ApplySkinToPlayer(savedSkin)
    end
end)

RegisterNetEvent('corex-spawn:client:clearSpawnFlags', function()
    spawnReadySent = false
    hasSpawned = false
    playerLoaded = false
end)

RegisterNetEvent('corex-spawn:client:spawnPlayer', function(data)
    data = data or {}

    -- Wait for Corex to be available
    local waitTime = 0
    while (not Corex or not Corex.Functions) and waitTime < 10000 do
        Wait(100)
        waitTime = waitTime + 100
    end
    
    if not Corex or not Corex.Functions then
        print('[COREX-SPAWN] ^1ERROR: Corex not available!^0')
        return
    end

    -- CRITICAL: Wait for statebag to ensure metadata (hunger, thirst, etc.) is synced
    if not WaitForStateBag() then
        print('[COREX-SPAWN] ^3WARN: StateBag not ready, proceeding anyway^0')
    end
    
    -- Handle resource restart - player already spawned in world
    if data.isResourceRestart then
        local ped = Corex.Functions.GetPed()
        if Corex.Functions.DoesEntityExist(ped) and not Corex.Functions.IsDead(ped) then
            local coords = Corex.Functions.GetCoords(ped)
            if coords.z > 0.0 then
                if data.skin then
                    savedSkin = data.skin
                    ApplySkinToPlayer(data.skin, { skipModelLoad = true })
                end
                playerLoaded = true
                hasSpawned = true
                return
            end
        end
    end
    
    -- Skip if already spawned (prevent duplicates)
    if hasSpawned and playerLoaded and not data.isRespawn then
        return
    end

    spawnReadySent = false
    if data.isRespawn then
        hasSpawned = false
        playerLoaded = false
        TriggerEvent('corex-death:client:prepareRespawn')
    end

    Corex.Functions.ScreenFadeOut(500)
    Wait(1000)
    
    local spawn = data.isNew and Config.FirstSpawnLocation or Config.DefaultSpawnLocation

    if data.position then
        spawn = data.position
    end
    
    local modelName = Config.DefaultMaleModel
    if data.skin and data.skin.model then
        modelName = data.skin.model
    end
    
    LoadAndSetPlayerModel(modelName)
    Wait(500)

    if data.isRespawn then
        local heading = spawn.heading or spawn.w or 0.0
        Corex.Functions.Resurrect(vector4(spawn.x, spawn.y, spawn.z, heading))
        Wait(100)
    end
    
    local ped = Corex.Functions.GetPed()
    PlacePlayerAtSpawn(spawn, {
        allowGroundSnap = not data.isNew,
        zOffset = data.isNew and 0.03 or 0.0
    })
    
    Wait(500)
    
    hasSpawned = true
    
    if data.isNew then
        SetPedDefaultComponentVariation(ped)

        if ShutdownLoadingScreenNui then pcall(ShutdownLoadingScreenNui) end
        if ShutdownLoadingScreen then pcall(ShutdownLoadingScreen) end

        SetEntityVisible(ped, true, false)
        Corex.Functions.FreezeEntity(ped, true)
        Corex.Functions.SetPlayerControl(true)

        Corex.Functions.ScreenFadeIn(500)
        Wait(500)

        SetupCreationCamera()
        OpenClothingUI({
            mode = 'creation',
            allowCancel = false
        })
    else
        if data.skin then
            savedSkin = data.skin
            ApplySkinToPlayer(data.skin, { skipModelLoad = true })
        end

        if data.isRespawn then
            ClearPedBloodDamage(ped)
            SetEntityHealth(ped, 200)
        end

        if ShutdownLoadingScreenNui then pcall(ShutdownLoadingScreenNui) end
        if ShutdownLoadingScreen then pcall(ShutdownLoadingScreen) end

        SetEntityVisible(ped, true, false)
        ResetEntityAlpha(ped)
        SetEntityCollision(ped, true, true)
        SetEntityInvincible(ped, false)

        Corex.Functions.FreezeEntity(ped, false)
        Corex.Functions.SetPlayerControl(true)

        if creationCam then
            RenderScriptCams(false, true, 0, true, false)
            DestroyCam(creationCam, false)
            creationCam = nil
        end
        ClearFocus()

        if SwitchInPlayer then
            pcall(SwitchInPlayer, ped)
        end

        ScheduleSpawnStateNormalization()

        Corex.Functions.ScreenFadeIn(500)
        TriggerEvent('corex-death:client:respawnFinished')

        playerLoaded = true
        SendSpawnReady()
    end
end)

function LoadAndSetPlayerModel(modelName)
    Corex.Functions.LoadModel(modelName)

    local modelHash = GetHashKey(modelName)
    SetPlayerModel(PlayerId(), modelHash)
    Corex.Functions.SetModelAsNoLongerNeeded(modelHash)

    local ped = Corex.Functions.GetPed()
    SetPedDefaultComponentVariation(ped)

    return ped
end

local function IsPedUsingModel(ped, modelName)
    if not ped or ped == 0 or not modelName then
        return false
    end

    return GetEntityModel(ped) == GetHashKey(modelName)
end

function ApplySkinToPlayer(skinData, options)
    if not skinData then return end

    options = options or {}
    local ped = Corex.Functions.GetPed()

    if skinData.model and not options.skipModelLoad and not IsPedUsingModel(ped, skinData.model) then
        LoadAndSetPlayerModel(skinData.model)
        ped = Corex.Functions.GetPed()
    end
    
    if skinData.components then
        for componentId, data in pairs(skinData.components) do
            local id = tonumber(componentId)
            if id and data.drawable and data.texture then
                SetPedComponentVariation(ped, id, data.drawable, data.texture, 0)
            end
        end
    end
    
    if skinData.props then
        for propId, data in pairs(skinData.props) do
            local id = tonumber(propId)
            if id and data.drawable then
                if data.drawable == -1 then
                    ClearPedProp(ped, id)
                else
                    SetPedPropIndex(ped, id, data.drawable, data.texture or 0, true)
                end
            end
        end
    end
end

function SetupCreationCamera()
    local ped = Corex.Functions.GetPed()
    
    local timeout = 0
    while not Corex.Functions.DoesEntityExist(ped) and timeout < 50 do
        Wait(100)
        ped = Corex.Functions.GetPed()
        timeout = timeout + 1
    end
    
    if not Corex.Functions.DoesEntityExist(ped) then
        return
    end
    
    if creationCam then
        DestroyCam(creationCam, false)
    end
    
    local camCoords = Corex.Functions.GetOffsetFromEntity(ped, 0.0, 2.5, 0.5)
    
    creationCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    
    SetCamCoord(creationCam, camCoords.x, camCoords.y, camCoords.z)
    SetCamFov(creationCam, 45.0)
    
    PointCamAtEntity(creationCam, ped, 0.0, 0.0, 0.5, true)
    
    SetCamActive(creationCam, true)
    RenderScriptCams(true, true, 500, true, false)
    
    Corex.Functions.FreezeEntity(ped, true)
end

function DestroyCreationCamera()
    if creationCam then
        RenderScriptCams(false, true, 1000, true, false)
        DestroyCam(creationCam, false)
        creationCam = nil
    end
    
    Corex.Functions.FreezeEntity(Corex.Functions.GetPed(), false)
end

function OpenClothingUI(options)
    options = options or {}
    local uiMode = options.mode or 'creation'
    local allowCancel = options.allowCancel == true

    isUIOpen = true
    SetNuiFocus(true, true)
    
    local clothingData = GetCurrentClothingData()
    
    SendNUIMessage({
        action = 'open',
        clothing = clothingData,
        mode = uiMode,
        allowCancel = allowCancel
    })
end

function CloseClothingUI()
    isUIOpen = false
    SetNuiFocus(false, false)
    
    SendNUIMessage({
        action = 'close'
    })
    
    DestroyCreationCamera()
    playerLoaded = true
    SendSpawnReady()
end

function GetCurrentClothingData()
    local ped = Corex.Functions.GetPed()
    local data = {
        components = {},
        props = {}
    }
    
    for i = 0, 11 do
        data.components[i] = {
            drawable = GetPedDrawableVariation(ped, i),
            texture = GetPedTextureVariation(ped, i),
            maxDrawable = GetNumberOfPedDrawableVariations(ped, i),
            maxTexture = GetNumberOfPedTextureVariations(ped, i, GetPedDrawableVariation(ped, i))
        }
    end
    
    for i = 0, 7 do
        data.props[i] = {
            drawable = GetPedPropIndex(ped, i),
            texture = GetPedPropTextureIndex(ped, i),
            maxDrawable = GetNumberOfPedPropDrawableVariations(ped, i),
            maxTexture = GetNumberOfPedPropTextureVariations(ped, i, GetPedPropIndex(ped, i))
        }
    end
    
    return data
end

RegisterNUICallback('close', function(data, cb)
    CloseClothingUI()
    cb('ok')
end)

RegisterNUICallback('confirm', function(data, cb)
    local ped = Corex.Functions.GetPed()
    
    local skinData = {
        model = GetEntityModel(ped) == GetHashKey(Config.DefaultFemaleModel) and Config.DefaultFemaleModel or Config.DefaultMaleModel,
        components = {},
        props = {}
    }
    
    for i = 0, 11 do
        skinData.components[tostring(i)] = {
            drawable = GetPedDrawableVariation(ped, i),
            texture = GetPedTextureVariation(ped, i)
        }
    end
    
    for i = 0, 7 do
        skinData.props[tostring(i)] = {
            drawable = GetPedPropIndex(ped, i),
            texture = GetPedPropTextureIndex(ped, i)
        }
    end
    
    savedSkin = skinData
    TriggerServerEvent('corex-spawn:server:saveSkin', skinData)
    
    CloseClothingUI()
    cb('ok')
end)

RegisterNUICallback('updateComponent', function(data, cb)
    local ped = Corex.Functions.GetPed()
    local componentId = tonumber(data.component)
    local drawableId = tonumber(data.drawable)
    local textureId = tonumber(data.texture) or 0
    
    if componentId ~= nil and drawableId ~= nil then
        SetPedComponentVariation(ped, componentId, drawableId, textureId, 0)
        
        currentSkin[componentId] = {
            drawable = drawableId,
            texture = textureId
        }
        
        local maxTexture = GetNumberOfPedTextureVariations(ped, componentId, drawableId)
        
        cb({
            success = true,
            maxTexture = maxTexture
        })
    else
        cb({ success = false })
    end
end)

RegisterNUICallback('updateProp', function(data, cb)
    local ped = Corex.Functions.GetPed()
    local propId = tonumber(data.prop)
    local drawableId = tonumber(data.drawable)
    local textureId = tonumber(data.texture) or 0
    
    if propId ~= nil and drawableId ~= nil then
        if drawableId == -1 then
            ClearPedProp(ped, propId)
        else
            SetPedPropIndex(ped, propId, drawableId, textureId, true)
        end

        local maxTexture = 0
        if drawableId ~= -1 then
            maxTexture = GetNumberOfPedPropTextureVariations(ped, propId, drawableId)
        end

        cb({
            success = true,
            maxTexture = maxTexture
        })
    else
        cb({ success = false })
    end
end)

RegisterNUICallback('changeGender', function(data, cb)
    local gender = data.gender
    local model = gender == 'female' and Config.DefaultFemaleModel or Config.DefaultMaleModel
    
    LoadAndSetPlayerModel(model)
    Wait(100)
    
    local ped = Corex.Functions.GetPed()
    SetPedDefaultComponentVariation(ped)
    
    local clothingData = GetCurrentClothingData()
    
    cb({
        success = true,
        clothing = clothingData
    })
end)

RegisterNUICallback('rotateCharacter', function(data, cb)
    local direction = data.direction
    local currentHeading = Corex.Functions.GetHeading()
    
    if direction == 'left' then
        Corex.Functions.SetHeading(currentHeading + 15.0)
    else
        Corex.Functions.SetHeading(currentHeading - 15.0)
    end
    
    cb('ok')
end)

local currentCamFov = 45.0
local minFov = 20.0
local maxFov = 80.0

RegisterNUICallback('zoomCamera', function(data, cb)
    if not creationCam then
        cb('ok')
        return
    end
    
    local direction = data.direction
    local zoomAmount = 5.0
    
    if direction == 'in' then
        currentCamFov = math.max(minFov, currentCamFov - zoomAmount)
    else
        currentCamFov = math.min(maxFov, currentCamFov + zoomAmount)
    end
    
    SetCamFov(creationCam, currentCamFov)
    
    cb('ok')
end)

RegisterNetEvent('corex-spawn:client:requestPosition', function()
    if not playerLoaded or not spawnReadySent or isUIOpen then return end
    
    local coords = Corex.Functions.GetCoords()
    
    TriggerServerEvent('corex-spawn:server:savePosition', {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = coords.w
    })
end)

RegisterNetEvent('corex-spawn:client:skinSaved', function()
    -- Skin saved confirmation
end)
