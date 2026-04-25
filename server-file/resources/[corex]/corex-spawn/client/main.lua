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
local creationCamBaseOffset = { x = 0.0, y = 2.5, z = 0.5 }
local defaultCreationCamTargetZ = 0.5
local currentCreationCamTargetZ = defaultCreationCamTargetZ
local minCreationCamTargetZ = -0.9
local maxCreationCamTargetZ = 1.1
local creationCamPanSensitivity = 0.005
local hasSpawned = false
local savedSkin = nil
local spawnReadySent = false
local spawnManagerGuardInstalled = false
local currentCamFov = 45.0
local minFov = 20.0
local maxFov = 80.0

local function SetAppearanceUiSuppression(active)
    TriggerEvent('corex-hud:client:setTemporaryHidden', active == true)
    TriggerEvent('corex-inventory:client:setHotbarVisible', active ~= true)
end

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

local function HoldPlayerBehindLoadingScreen()
    if Corex and Corex.Functions and Corex.Functions.ScreenFadeOut then
        pcall(Corex.Functions.ScreenFadeOut, 0)
    else
        pcall(DoScreenFadeOut, 0)
    end

    local ped = PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        SetEntityVisible(ped, false, false)
        FreezeEntityPosition(ped, true)
    end

    SetPlayerControl(PlayerId(), false, 0)

    if creationCam then
        RenderScriptCams(false, true, 0, true, false)
        DestroyCam(creationCam, false)
        creationCam = nil
    end
    ClearFocus()
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

    -- CRITICAL: do NOT flip visibility unless collision is actually loaded.
    -- Revealing the ped in an un-streamed world causes the
    -- virginia-october-hydrogen crash (GameSkeleton::RunUpdate null deref
    -- on the first physics tick against null collision). If the initial
    -- 5-second wait timed out, run a second 3-second fallback window
    -- that keeps re-requesting collision. If still not loaded, keep the
    -- ped hidden + frozen and return false — the caller must keep the
    -- loading screen up and retry.
    if not collisionLoaded then
        print('[COREX-SPAWN] ^3Collision not ready after primary wait — entering fallback window^0')
        for _ = 1, 30 do
            Wait(100)
            RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
            if HasCollisionLoadedAroundEntity(ped) then
                collisionLoaded = true
                break
            end
        end
    end

    if not collisionLoaded then
        print('[COREX-SPAWN] ^1Collision still not ready — keeping ped hidden, caller must retry^0')
        -- Force screen black so the user doesn't see the void.
        if Corex and Corex.Functions and Corex.Functions.ScreenFadeOut then
            pcall(Corex.Functions.ScreenFadeOut, 0)
        else
            pcall(DoScreenFadeOut, 0)
        end
        -- Leave ped hidden + frozen (already done at lines 132-133).
        return false
    end

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
        -- Tell FiveM we'll shut the NUI loading screen down manually.
        if SetManualShutdownLoadingScreenNui then
            pcall(SetManualShutdownLoadingScreenNui, true)
        end

        Wait(1500)

        -- REMOVED: premature ShutdownLoadingScreenNui / ShutdownLoadingScreen here.
        -- Closing the loading screen before PlacePlayerAtSpawn verified collision
        -- exposes the player to an un-streamed world and is the root cause of
        -- the virginia-october-hydrogen crash at respawn moment. The screen is
        -- now only closed INSIDE the corex-spawn:client:spawnPlayer handler,
        -- after HasCollisionLoadedAroundEntity is confirmed true.

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
    while not playerLoaded and not isUIOpen do
        print('[COREX-SPAWN] ^1Spawn flow stalled; keeping player hidden and retrying safely^0')
        HoldPlayerBehindLoadingScreen()

        if LocalPlayer.state.isLoggedIn then
            TriggerServerEvent('corex-spawn:server:checkPlayer')
        else
            TriggerServerEvent('corex:server:loadPlayer')
        end

        Wait(5000)
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
    local spawnPlaced = PlacePlayerAtSpawn(spawn, {
        allowGroundSnap = not data.isNew,
        zOffset = data.isNew and 0.03 or 0.0
    })

    -- If collision never loaded, PlacePlayerAtSpawn returns false and keeps
    -- the ped hidden + frozen behind a black screen. Schedule a retry and
    -- abort this spawn attempt. The watchdog keeps the player hidden and
    -- asks the server to retry instead of revealing an un-streamed world.
    if not spawnPlaced then
        print('[COREX-SPAWN] ^1Spawn aborted — collision never loaded. Scheduling retry in 2s.^0')
        CreateThread(function()
            Wait(2000)
            TriggerServerEvent('corex:server:loadPlayer')
        end)
        return
    end

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

local ApplyDefaultFreemodeAppearance

function LoadAndSetPlayerModel(modelName)
    Corex.Functions.LoadModel(modelName)

    local modelHash = GetHashKey(modelName)
    SetPlayerModel(PlayerId(), modelHash)
    Corex.Functions.SetModelAsNoLongerNeeded(modelHash)

    local ped = Corex.Functions.GetPed()
    ApplyDefaultFreemodeAppearance(ped, modelName)

    return ped
end

local function IsPedUsingModel(ped, modelName)
    if not ped or ped == 0 or not modelName then
        return false
    end

    return GetEntityModel(ped) == GetHashKey(modelName)
end

local function GetMaxVariationIndex(count, emptyValue)
    count = tonumber(count) or 0
    if count <= 0 then
        return emptyValue or 0
    end

    return count - 1
end

local function ClampVariationIndex(value, minValue, maxValue)
    value = tonumber(value)
    if not value or value ~= value then
        return minValue
    end

    value = math.floor(value)
    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end

local function NormalizeComponentVariation(ped, componentId, drawableId, textureId)
    componentId = tonumber(componentId)
    if not ped or ped == 0 or not componentId then
        return nil, nil, nil, nil
    end

    local maxDrawable = GetMaxVariationIndex(GetNumberOfPedDrawableVariations(ped, componentId), 0)
    local drawable = ClampVariationIndex(drawableId, 0, maxDrawable)
    local maxTexture = GetMaxVariationIndex(GetNumberOfPedTextureVariations(ped, componentId, drawable), 0)
    local texture = ClampVariationIndex(textureId or 0, 0, maxTexture)

    return drawable, texture, maxDrawable, maxTexture
end

local function NormalizePropVariation(ped, propId, drawableId, textureId)
    propId = tonumber(propId)
    if not ped or ped == 0 or not propId then
        return nil, nil, nil, nil
    end

    local maxDrawable = GetMaxVariationIndex(GetNumberOfPedPropDrawableVariations(ped, propId), -1)
    local drawable = ClampVariationIndex(drawableId, -1, maxDrawable)

    if drawable == -1 then
        return drawable, 0, maxDrawable, 0
    end

    local maxTexture = GetMaxVariationIndex(GetNumberOfPedPropTextureVariations(ped, propId, drawable), 0)
    local texture = ClampVariationIndex(textureId or 0, 0, maxTexture)

    return drawable, texture, maxDrawable, maxTexture
end

local FACE_FEATURE_KEYS = {
    'noseWidth',
    'nosePeakHigh',
    'nosePeakSize',
    'noseBoneHigh',
    'nosePeakLowering',
    'noseBoneTwist',
    'eyeBrownHigh',
    'eyeBrownForward',
    'cheeksBoneHigh',
    'cheeksBoneWidth',
    'cheeksWidth',
    'eyesOpening',
    'lipsThickness',
    'jawBoneWidth',
    'jawBoneBackSize',
    'chinBoneLowering',
    'chinBoneLenght',
    'chinBoneSize',
    'chinHole',
    'neckThickness'
}

local HEAD_OVERLAYS = {
    { key = 'blemishes', index = 0 },
    { key = 'beard', index = 1, colorType = 1 },
    { key = 'eyebrows', index = 2, colorType = 1 },
    { key = 'ageing', index = 3 },
    { key = 'makeUp', index = 4, colorType = 2 },
    { key = 'blush', index = 5, colorType = 2 },
    { key = 'complexion', index = 6 },
    { key = 'sunDamage', index = 7 },
    { key = 'lipstick', index = 8, colorType = 2 },
    { key = 'moleAndFreckles', index = 9 },
    { key = 'chestHair', index = 10, colorType = 1 },
    { key = 'bodyBlemishes', index = 11 }
}

local DEFAULT_HEAD_BLEND_BY_MODEL = {
    [Config.DefaultMaleModel] = {
        shapeFirst = 0,
        shapeSecond = 0,
        shapeThird = 0,
        skinFirst = 0,
        skinSecond = 0,
        skinThird = 0,
        shapeMix = 0.0,
        skinMix = 0.0,
        thirdMix = 0.0
    },
    [Config.DefaultFemaleModel] = {
        shapeFirst = 45,
        shapeSecond = 21,
        shapeThird = 0,
        skinFirst = 20,
        skinSecond = 15,
        skinThird = 0,
        shapeMix = 0.3,
        skinMix = 0.1,
        thirdMix = 0.0
    }
}

local EYE_COLOR_MAX = 31

local function RoundToStep(value, decimals)
    decimals = decimals or 0
    return tonumber(string.format('%.' .. decimals .. 'f', tonumber(value) or 0)) or 0
end

local function IsFreemodePed(ped)
    if not ped or ped == 0 then
        return false
    end

    local model = GetEntityModel(ped)
    return model == GetHashKey(Config.DefaultMaleModel)
        or model == GetHashKey(Config.DefaultFemaleModel)
        or model == `mp_m_freemode_01`
        or model == `mp_f_freemode_01`
end

local function GetCurrentModelName(ped)
    if not ped or ped == 0 then
        return Config.DefaultMaleModel
    end

    local model = GetEntityModel(ped)
    if model == GetHashKey(Config.DefaultFemaleModel) then
        return Config.DefaultFemaleModel
    end

    return Config.DefaultMaleModel
end

local function GetDefaultHeadBlend(modelName)
    local defaults = DEFAULT_HEAD_BLEND_BY_MODEL[modelName or Config.DefaultMaleModel] or DEFAULT_HEAD_BLEND_BY_MODEL[Config.DefaultMaleModel]
    local out = {}
    for key, value in pairs(defaults) do
        out[key] = value
    end
    return out
end

local function GetOverlayDefinition(overlayKey)
    for _, overlay in ipairs(HEAD_OVERLAYS) do
        if overlay.key == overlayKey then
            return overlay
        end
    end
    return nil
end

local function GetOverlayColorMax(overlay)
    if not overlay or not overlay.colorType then
        return 0
    end

    if overlay.colorType == 2 then
        return GetMaxVariationIndex(GetNumMakeupColors(), 0)
    end

    return GetMaxVariationIndex(GetNumHairColors(), 0)
end

ApplyDefaultFreemodeAppearance = function(ped, modelName)
    if not IsFreemodePed(ped) then
        return
    end

    local defaults = GetDefaultHeadBlend(modelName)
    SetPedDefaultComponentVariation(ped)
    SetPedHeadBlendData(
        ped,
        defaults.shapeFirst,
        defaults.shapeSecond,
        defaults.shapeThird,
        defaults.skinFirst,
        defaults.skinSecond,
        defaults.skinThird,
        defaults.shapeMix + 0.0,
        defaults.skinMix + 0.0,
        defaults.thirdMix + 0.0,
        false
    )

    for index = 0, #FACE_FEATURE_KEYS - 1 do
        SetPedFaceFeature(ped, index, 0.0)
    end

    for _, overlay in ipairs(HEAD_OVERLAYS) do
        SetPedHeadOverlay(ped, overlay.index, 0, 0.0)
        if overlay.colorType then
            SetPedHeadOverlayColor(ped, overlay.index, overlay.colorType, 0, 0)
        end
    end

    SetPedHairColor(ped, 0, 0)
    SetPedEyeColor(ped, 0)
end

local function GetHeadBlendValues(ped)
    if not IsFreemodePed(ped) then
        return GetDefaultHeadBlend(GetCurrentModelName(ped))
    end

    local shapeFirst, shapeSecond, shapeThird, skinFirst, skinSecond, skinThird, shapeMix, skinMix, thirdMix =
        Citizen.InvokeNative(
            0x2746BD9D88C5C5D0,
            ped,
            Citizen.PointerValueIntInitialized(0),
            Citizen.PointerValueIntInitialized(0),
            Citizen.PointerValueIntInitialized(0),
            Citizen.PointerValueIntInitialized(0),
            Citizen.PointerValueIntInitialized(0),
            Citizen.PointerValueIntInitialized(0),
            Citizen.PointerValueFloatInitialized(0),
            Citizen.PointerValueFloatInitialized(0),
            Citizen.PointerValueFloatInitialized(0)
        )

    shapeMix = math.min(1.0, math.max(0.0, tonumber(string.sub(tostring(shapeMix or 0), 1, 4)) or 0.0))
    skinMix = math.min(1.0, math.max(0.0, tonumber(string.sub(tostring(skinMix or 0), 1, 4)) or 0.0))
    thirdMix = math.min(1.0, math.max(0.0, tonumber(string.sub(tostring(thirdMix or 0), 1, 4)) or 0.0))

    return {
        shapeFirst = ClampVariationIndex(shapeFirst, 0, 45),
        shapeSecond = ClampVariationIndex(shapeSecond, 0, 45),
        shapeThird = ClampVariationIndex(shapeThird, 0, 45),
        skinFirst = ClampVariationIndex(skinFirst, 0, 45),
        skinSecond = ClampVariationIndex(skinSecond, 0, 45),
        skinThird = ClampVariationIndex(skinThird, 0, 45),
        shapeMix = RoundToStep(shapeMix, 1),
        skinMix = RoundToStep(skinMix, 1),
        thirdMix = RoundToStep(thirdMix, 1)
    }
end

local function BuildHeadBlendUiData(ped)
    local values = GetHeadBlendValues(ped)
    local fields = {
        shapeFirst = { min = 0, max = 45, step = 1 },
        shapeSecond = { min = 0, max = 45, step = 1 },
        shapeThird = { min = 0, max = 45, step = 1 },
        skinFirst = { min = 0, max = 45, step = 1 },
        skinSecond = { min = 0, max = 45, step = 1 },
        skinThird = { min = 0, max = 45, step = 1 },
        shapeMix = { min = 0, max = 1, step = 0.1 },
        skinMix = { min = 0, max = 1, step = 0.1 },
        thirdMix = { min = 0, max = 1, step = 0.1 }
    }

    local out = {}
    for key, settings in pairs(fields) do
        out[key] = {
            value = values[key],
            min = settings.min,
            max = settings.max,
            step = settings.step
        }
    end
    return out
end

local function SetPedHeadBlendSafe(ped, headBlend)
    if not IsFreemodePed(ped) then
        return GetHeadBlendValues(ped)
    end

    local current = GetHeadBlendValues(ped)
    local defaults = GetDefaultHeadBlend(GetCurrentModelName(ped))
    local data = headBlend or {}

    local result = {
        shapeFirst = ClampVariationIndex(data.shapeFirst ~= nil and data.shapeFirst or current.shapeFirst or defaults.shapeFirst, 0, 45),
        shapeSecond = ClampVariationIndex(data.shapeSecond ~= nil and data.shapeSecond or current.shapeSecond or defaults.shapeSecond, 0, 45),
        shapeThird = ClampVariationIndex(data.shapeThird ~= nil and data.shapeThird or current.shapeThird or defaults.shapeThird, 0, 45),
        skinFirst = ClampVariationIndex(data.skinFirst ~= nil and data.skinFirst or current.skinFirst or defaults.skinFirst, 0, 45),
        skinSecond = ClampVariationIndex(data.skinSecond ~= nil and data.skinSecond or current.skinSecond or defaults.skinSecond, 0, 45),
        skinThird = ClampVariationIndex(data.skinThird ~= nil and data.skinThird or current.skinThird or defaults.skinThird, 0, 45),
        shapeMix = RoundToStep(math.max(0.0, math.min(1.0, tonumber(data.shapeMix ~= nil and data.shapeMix or current.shapeMix or defaults.shapeMix) or 0.0)), 1),
        skinMix = RoundToStep(math.max(0.0, math.min(1.0, tonumber(data.skinMix ~= nil and data.skinMix or current.skinMix or defaults.skinMix) or 0.0)), 1),
        thirdMix = RoundToStep(math.max(0.0, math.min(1.0, tonumber(data.thirdMix ~= nil and data.thirdMix or current.thirdMix or defaults.thirdMix) or 0.0)), 1)
    }

    SetPedHeadBlendData(
        ped,
        result.shapeFirst,
        result.shapeSecond,
        result.shapeThird,
        result.skinFirst,
        result.skinSecond,
        result.skinThird,
        result.shapeMix + 0.0,
        result.skinMix + 0.0,
        result.thirdMix + 0.0,
        false
    )

    return result
end

local function GetFaceFeatureValues(ped)
    local out = {}
    for index, key in ipairs(FACE_FEATURE_KEYS) do
        out[key] = RoundToStep(GetPedFaceFeature(ped, index - 1), 1)
    end
    return out
end

local function BuildFaceFeaturesUiData(ped)
    local values = GetFaceFeatureValues(ped)
    local out = {}
    for _, key in ipairs(FACE_FEATURE_KEYS) do
        out[key] = {
            value = values[key],
            min = -1,
            max = 1,
            step = 0.1
        }
    end
    return out
end

local function SetPedFaceFeatureValue(ped, featureKey, value)
    for index, key in ipairs(FACE_FEATURE_KEYS) do
        if key == featureKey then
            local safeValue = RoundToStep(math.max(-1.0, math.min(1.0, tonumber(value) or 0.0)), 1)
            SetPedFaceFeature(ped, index - 1, safeValue + 0.0)
            return safeValue
        end
    end
    return nil
end

local function GetHeadOverlayValues(ped)
    local out = {}
    for _, overlay in ipairs(HEAD_OVERLAYS) do
        local _, style, _, color, secondColor, opacity = GetPedHeadOverlayData(ped, overlay.index)
        if style == 255 then
            style = 0
            opacity = 0
        end

        out[overlay.key] = {
            style = ClampVariationIndex(style, 0, GetMaxVariationIndex(GetNumHeadOverlayValues(overlay.index), 0)),
            opacity = RoundToStep(opacity or 0, 1),
            color = ClampVariationIndex(color or 0, 0, GetOverlayColorMax(overlay)),
            secondColor = ClampVariationIndex(secondColor or 0, 0, GetOverlayColorMax(overlay))
        }
    end
    return out
end

local function BuildHeadOverlaysUiData(ped)
    local values = GetHeadOverlayValues(ped)
    local out = {}
    for _, overlay in ipairs(HEAD_OVERLAYS) do
        out[overlay.key] = {
            style = values[overlay.key].style,
            opacity = values[overlay.key].opacity,
            color = values[overlay.key].color,
            secondColor = values[overlay.key].secondColor,
            maxStyle = GetMaxVariationIndex(GetNumHeadOverlayValues(overlay.index), 0),
            maxColor = GetOverlayColorMax(overlay),
            hasColor = overlay.colorType ~= nil
        }
    end
    return out
end

local function SetPedHeadOverlayValue(ped, overlayKey, data)
    local overlay = GetOverlayDefinition(overlayKey)
    if not overlay then
        return nil
    end

    local current = GetHeadOverlayValues(ped)[overlayKey] or {}
    local maxStyle = GetMaxVariationIndex(GetNumHeadOverlayValues(overlay.index), 0)
    local maxColor = GetOverlayColorMax(overlay)
    local style = ClampVariationIndex(data.style ~= nil and data.style or current.style or 0, 0, maxStyle)
    local opacity = RoundToStep(math.max(0.0, math.min(1.0, tonumber(data.opacity ~= nil and data.opacity or current.opacity or 0.0) or 0.0)), 1)

    SetPedHeadOverlay(ped, overlay.index, style, opacity + 0.0)

    local color = ClampVariationIndex(data.color ~= nil and data.color or current.color or 0, 0, maxColor)
    local secondColor = ClampVariationIndex(data.secondColor ~= nil and data.secondColor or current.secondColor or 0, 0, maxColor)

    if overlay.colorType then
        SetPedHeadOverlayColor(ped, overlay.index, overlay.colorType, color, secondColor)
    end

    return {
        style = style,
        opacity = opacity,
        color = color,
        secondColor = secondColor,
        maxStyle = maxStyle,
        maxColor = maxColor,
        hasColor = overlay.colorType ~= nil
    }
end

local function GetHairValues(ped)
    return {
        style = GetPedDrawableVariation(ped, 2),
        texture = GetPedTextureVariation(ped, 2),
        color = ClampVariationIndex(GetPedHairColor(ped), 0, GetMaxVariationIndex(GetNumHairColors(), 0)),
        highlight = ClampVariationIndex(GetPedHairHighlightColor(ped), 0, GetMaxVariationIndex(GetNumHairColors(), 0))
    }
end

local function BuildHairUiData(ped)
    local hair = GetHairValues(ped)
    local maxColor = GetMaxVariationIndex(GetNumHairColors(), 0)
    return {
        color = { value = hair.color, min = 0, max = maxColor, step = 1 },
        highlight = { value = hair.highlight, min = 0, max = maxColor, step = 1 }
    }
end

local function SetPedHairSettings(ped, hair)
    if not hair then
        return GetHairValues(ped)
    end

    local current = GetHairValues(ped)
    local style = current.style
    local texture = current.texture

    if hair.style ~= nil or hair.texture ~= nil then
        style, texture = NormalizeComponentVariation(
            ped,
            2,
            hair.style ~= nil and hair.style or current.style,
            hair.texture ~= nil and hair.texture or current.texture
        )
        SetPedComponentVariation(ped, 2, style, texture, 0)
    end

    local maxColor = GetMaxVariationIndex(GetNumHairColors(), 0)
    local color = ClampVariationIndex(hair.color ~= nil and hair.color or current.color, 0, maxColor)
    local highlight = ClampVariationIndex(hair.highlight ~= nil and hair.highlight or current.highlight, 0, maxColor)
    SetPedHairColor(ped, color, highlight)

    return {
        style = style,
        texture = texture,
        color = color,
        highlight = highlight
    }
end

local function GetEyeColorValue(ped)
    return ClampVariationIndex(GetPedEyeColor(ped), 0, EYE_COLOR_MAX)
end

local function SetPedEyeColorSafe(ped, value)
    local safeValue = ClampVariationIndex(value, 0, EYE_COLOR_MAX)
    SetPedEyeColor(ped, safeValue)
    return safeValue
end

local function BuildColorPaletteFromNative(count, colorGetter)
    local palette = {}

    count = tonumber(count) or 0
    for index = 0, count - 1 do
        local r, g, b = colorGetter(index)
        palette[index + 1] = {
            r = tonumber(r) or 0,
            g = tonumber(g) or 0,
            b = tonumber(b) or 0
        }
    end

    return palette
end

local function GetAppearanceColorPalettes()
    return {
        hair = BuildColorPaletteFromNative(GetNumHairColors(), GetPedHairRgbColor),
        makeUp = BuildColorPaletteFromNative(GetNumMakeupColors(), GetPedMakeupRgbColor)
    }
end

function ApplySkinToPlayer(skinData, options)
    if not skinData then return end

    options = options or {}
    local ped = Corex.Functions.GetPed()

    if skinData.model and not options.skipModelLoad and not IsPedUsingModel(ped, skinData.model) then
        LoadAndSetPlayerModel(skinData.model)
        ped = Corex.Functions.GetPed()
    end

    if skinData.headBlend then
        SetPedHeadBlendSafe(ped, skinData.headBlend)
    end

    if skinData.components then
        for componentId, data in pairs(skinData.components) do
            local id = tonumber(componentId)
            if id and data.drawable and data.texture then
                local drawable, texture = NormalizeComponentVariation(ped, id, data.drawable, data.texture)
                if drawable ~= nil then
                    SetPedComponentVariation(ped, id, drawable, texture, 0)
                end
            end
        end
    end

    if skinData.faceFeatures then
        for featureKey, value in pairs(skinData.faceFeatures) do
            SetPedFaceFeatureValue(ped, featureKey, value)
        end
    end

    if skinData.headOverlays then
        for overlayKey, data in pairs(skinData.headOverlays) do
            SetPedHeadOverlayValue(ped, overlayKey, data)
        end
    end

    if skinData.hair then
        SetPedHairSettings(ped, skinData.hair)
    end

    if skinData.eyeColor ~= nil then
        SetPedEyeColorSafe(ped, skinData.eyeColor)
    end

    if skinData.props then
        for propId, data in pairs(skinData.props) do
            local id = tonumber(propId)
            if id and data.drawable then
                local drawable, texture = NormalizePropVariation(ped, id, data.drawable, data.texture)
                if drawable == -1 then
                    ClearPedProp(ped, id)
                elseif drawable ~= nil then
                    SetPedPropIndex(ped, id, drawable, texture, true)
                end
            end
        end
    end
end

local function RefreshCreationCameraView()
    if not creationCam then
        return
    end

    local ped = Corex.Functions.GetPed()
    if not ped or ped == 0 or not Corex.Functions.DoesEntityExist(ped) then
        return
    end

    local panOffset = (currentCreationCamTargetZ - defaultCreationCamTargetZ) * 0.35
    local camCoords = Corex.Functions.GetOffsetFromEntity(
        ped,
        creationCamBaseOffset.x,
        creationCamBaseOffset.y,
        creationCamBaseOffset.z + panOffset
    )

    SetCamCoord(creationCam, camCoords.x, camCoords.y, camCoords.z)
    SetCamFov(creationCam, currentCamFov)
    PointCamAtEntity(creationCam, ped, 0.0, 0.0, currentCreationCamTargetZ, true)
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

    creationCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    currentCamFov = 45.0
    currentCreationCamTargetZ = defaultCreationCamTargetZ
    RefreshCreationCameraView()
    
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

    currentCamFov = 45.0
    currentCreationCamTargetZ = defaultCreationCamTargetZ
    
    Corex.Functions.FreezeEntity(Corex.Functions.GetPed(), false)
end

function OpenClothingUI(options)
    options = options or {}
    local uiMode = options.mode or 'creation'
    local allowCancel = options.allowCancel == true

    isUIOpen = true
    SetNuiFocus(true, true)
    SetAppearanceUiSuppression(true)
    
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
    SetAppearanceUiSuppression(false)
    
    SendNUIMessage({
        action = 'close'
    })
    
    DestroyCreationCamera()
    playerLoaded = true
    SendSpawnReady()
end

local function BuildSavedSkinData(ped)
    local skinData = {
        model = GetCurrentModelName(ped),
        components = {},
        props = {},
        headBlend = GetHeadBlendValues(ped),
        faceFeatures = GetFaceFeatureValues(ped),
        headOverlays = GetHeadOverlayValues(ped),
        hair = GetHairValues(ped),
        eyeColor = GetEyeColorValue(ped)
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

    return skinData
end

function GetCurrentClothingData()
    local ped = Corex.Functions.GetPed()
    local data = {
        model = GetCurrentModelName(ped),
        components = {},
        props = {},
        headBlend = BuildHeadBlendUiData(ped),
        faceFeatures = BuildFaceFeaturesUiData(ped),
        headOverlays = BuildHeadOverlaysUiData(ped),
        hair = BuildHairUiData(ped),
        colorPalettes = GetAppearanceColorPalettes(),
        eyeColor = {
            value = GetEyeColorValue(ped),
            min = 0,
            max = EYE_COLOR_MAX,
            step = 1
        }
    }

    for i = 0, 11 do
        local drawable = GetPedDrawableVariation(ped, i)
        data.components[i] = {
            drawable = drawable,
            texture = GetPedTextureVariation(ped, i),
            maxDrawable = GetMaxVariationIndex(GetNumberOfPedDrawableVariations(ped, i), 0),
            maxTexture = GetMaxVariationIndex(GetNumberOfPedTextureVariations(ped, i, drawable), 0)
        }
    end

    for i = 0, 7 do
        local drawable = GetPedPropIndex(ped, i)
        data.props[i] = {
            drawable = drawable,
            texture = GetPedPropTextureIndex(ped, i),
            maxDrawable = GetMaxVariationIndex(GetNumberOfPedPropDrawableVariations(ped, i), -1),
            maxTexture = drawable == -1 and 0 or GetMaxVariationIndex(GetNumberOfPedPropTextureVariations(ped, i, drawable), 0)
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
    local skinData = BuildSavedSkinData(ped)
    
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
        local safeDrawable, safeTexture, maxDrawable, maxTexture = NormalizeComponentVariation(ped, componentId, drawableId, textureId)

        SetPedComponentVariation(ped, componentId, safeDrawable, safeTexture, 0)

        currentSkin[componentId] = {
            drawable = safeDrawable,
            texture = safeTexture
        }

        cb({
            success = true,
            drawable = safeDrawable,
            texture = safeTexture,
            maxDrawable = maxDrawable,
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
        local safeDrawable, safeTexture, maxDrawable, maxTexture = NormalizePropVariation(ped, propId, drawableId, textureId)

        if safeDrawable == -1 then
            ClearPedProp(ped, propId)
        else
            SetPedPropIndex(ped, propId, safeDrawable, safeTexture, true)
        end

        cb({
            success = true,
            drawable = safeDrawable,
            texture = safeTexture,
            maxDrawable = maxDrawable,
            maxTexture = maxTexture
        })
    else
        cb({ success = false })
    end
end)

RegisterNUICallback('updateHeadBlend', function(data, cb)
    local ped = Corex.Functions.GetPed()
    local field = data.field or data.key

    if not field then
        cb({ success = false })
        return
    end

    local result = SetPedHeadBlendSafe(ped, {
        [field] = data.value
    })

    cb({
        success = true,
        value = result[field],
        headBlend = BuildHeadBlendUiData(ped)
    })
end)

RegisterNUICallback('updateFaceFeature', function(data, cb)
    local ped = Corex.Functions.GetPed()
    local feature = data.feature or data.key

    if not feature then
        cb({ success = false })
        return
    end

    local value = SetPedFaceFeatureValue(ped, feature, data.value)
    if value == nil then
        cb({ success = false })
        return
    end

    cb({
        success = true,
        value = value
    })
end)

RegisterNUICallback('updateHeadOverlay', function(data, cb)
    local ped = Corex.Functions.GetPed()
    local overlay = data.overlay
    local payload = data.data or data

    if not overlay then
        cb({ success = false })
        return
    end

    local result = SetPedHeadOverlayValue(ped, overlay, payload)
    if not result then
        cb({ success = false })
        return
    end

    cb({
        success = true,
        overlay = result
    })
end)

RegisterNUICallback('updateHairSetting', function(data, cb)
    local ped = Corex.Functions.GetPed()
    local field = data.field or data.key

    if not field then
        cb({ success = false })
        return
    end

    local result = SetPedHairSettings(ped, {
        [field] = data.value
    })

    cb({
        success = true,
        value = result[field],
        hair = BuildHairUiData(ped),
        component = {
            drawable = result.style,
            texture = result.texture,
            maxDrawable = GetMaxVariationIndex(GetNumberOfPedDrawableVariations(ped, 2), 0),
            maxTexture = GetMaxVariationIndex(GetNumberOfPedTextureVariations(ped, 2, result.style), 0)
        }
    })
end)

RegisterNUICallback('updateEyeColor', function(data, cb)
    local ped = Corex.Functions.GetPed()
    local value = SetPedEyeColorSafe(ped, data.value)

    cb({
        success = true,
        value = value,
        eyeColor = {
            value = value,
            min = 0,
            max = EYE_COLOR_MAX,
            step = 1
        }
    })
end)

RegisterNUICallback('changeGender', function(data, cb)
    local gender = data.gender
    local model = gender == 'female' and Config.DefaultFemaleModel or Config.DefaultMaleModel
    
    LoadAndSetPlayerModel(model)
    Wait(100)
    RefreshCreationCameraView()
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
    
    RefreshCreationCameraView()
    
    cb('ok')
end)

RegisterNUICallback('panCamera', function(data, cb)
    if not creationCam then
        cb('ok')
        return
    end

    local deltaY = tonumber(data.deltaY) or 0.0
    if deltaY ~= deltaY then
        deltaY = 0.0
    end

    deltaY = math.max(-50.0, math.min(50.0, deltaY))
    currentCreationCamTargetZ = math.max(
        minCreationCamTargetZ,
        math.min(maxCreationCamTargetZ, currentCreationCamTargetZ - (deltaY * creationCamPanSensitivity))
    )

    RefreshCreationCameraView()
    
    cb('ok')
end)

CreateThread(function()
    while true do
        if isUIOpen then
            HideHudAndRadarThisFrame()
            DisplayRadar(false)
            Wait(0)
        else
            Wait(200)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if isUIOpen then
        SetAppearanceUiSuppression(false)
        SetNuiFocus(false, false)
    end
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
