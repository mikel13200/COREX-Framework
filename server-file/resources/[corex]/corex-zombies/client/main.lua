-- Promoted to globals so sibling files (horde.lua, audio.lua,
-- effects.lua) can read the live zombie table and core reference.
Corex = nil
local isReady = false

-- Relationship group — CRITICAL that this is set SYNCHRONOUSLY at module
-- load, BEFORE any zombies can spawn. If set inside a CreateThread with
-- yields, there's a race: the spawn thread can fire first and spawn
-- zombies with ZOMBIE_RELATIONSHIP_HASH == nil, which makes ConfigureZombie
-- silently skip SetPedRelationshipGroupHash and leave the ped on the
-- civilian CIVMALE/CIVFEMALE group → ped flees on sight of player.
local _, ZOMBIE_RELATIONSHIP_HASH = AddRelationshipGroup('COREX_ZOMBIES')
if not ZOMBIE_RELATIONSHIP_HASH then
    ZOMBIE_RELATIONSHIP_HASH = GetHashKey('COREX_ZOMBIES')
end
SetRelationshipBetweenGroups(5, ZOMBIE_RELATIONSHIP_HASH, GetHashKey('PLAYER'))
SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'),       ZOMBIE_RELATIONSHIP_HASH)
SetRelationshipBetweenGroups(5, ZOMBIE_RELATIONSHIP_HASH, GetHashKey('CIVMALE'))
SetRelationshipBetweenGroups(5, ZOMBIE_RELATIONSHIP_HASH, GetHashKey('CIVFEMALE'))
-- Zombies neutral to each other (no infighting).
SetRelationshipBetweenGroups(1, ZOMBIE_RELATIONSHIP_HASH, ZOMBIE_RELATIONSHIP_HASH)

print('[COREX-ZOMBIES] ^3Initializing...^0')

local function InitCore()
    local success, core = pcall(function()
        return exports['corex-core']:GetCoreObject()
    end)
    if not success or not core or not core.Functions then return false end
    Corex = core
    return true
end

if not InitCore() then
    AddEventHandler('corex:client:coreReady', function(coreObj)
        if coreObj and coreObj.Functions and not Corex then
            Corex = coreObj
            isReady = true
            print('[COREX-ZOMBIES] ^2Successfully connected to COREX core^0')
        end
    end)
    CreateThread(function()
        Wait(15000)
        if not Corex then
            print('[COREX-ZOMBIES] ^1ERROR: Core init timed out^0')
        end
    end)
else
    isReady = true
    print('[COREX-ZOMBIES] ^2Successfully connected to COREX core^0')
end

-- Global: sibling helper files iterate this (effects.lua, audio.lua).
activeZombies = {}
local loadedDicts = {}
local loadedPtfxDicts = {}
local loadedClipsets = {}
-- ZOMBIE_RELATIONSHIP_HASH is now declared + initialized at the TOP of the
-- file (synchronously) so spawns never race against its creation.

local isGrabbed = false
local grabbingZombie = nil
local grabDamageTimer = 0
local escapeProgress = 0
local lastEscapePress = 0
local grabCooldown = {}
local sharedSuppressionZones = {}

local isCoughing = false
local lastCoughTime = 0
local lastToxicTick = 0
local currentToxicExposure = 0.0
local renderedToxicExposure = 0.0
local lastToxicRenderTick = nil

local function DLog(msg)
    if Config.Debug then
        print(('^5[COREX-ZOMBIES] %s^0'):format(msg))
    end
end

local function DAnim(msg)
    if Config.DebugAnimations then
        print(('^3[COREX-ZOMBIES·ANIM] %s^0'):format(msg))
    end
end

local function GetZombieTypeDataById(typeId)
    if not typeId then
        return nil
    end

    for _, zombieType in ipairs(Config.ZombieTypes or {}) do
        if zombieType.id == typeId then
            return zombieType
        end
    end

    return nil
end

local function GetDistance(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function GetDistance2D(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function SerializeCoords(coords)
    if not coords then return nil end
    return { x = coords.x, y = coords.y, z = coords.z }
end

local function ToVector3(coords)
    if not coords then return nil end
    return vector3(coords.x or coords[1] or 0.0, coords.y or coords[2] or 0.0, coords.z or coords[3] or 0.0)
end

local function IsInsideSharedSuppressionZone(coords)
    if not coords then
        return false
    end

    for _, zone in pairs(sharedSuppressionZones) do
        if zone.center and GetDistance(coords, zone.center) <= zone.radius then
            return true
        end
    end

    return false
end

local function FindZombieDataByEntity(entity)
    for _, zombieData in ipairs(activeZombies) do
        if zombieData.entity == entity then
            return zombieData
        end
    end

    return nil
end

local function FindZombieDataBySharedId(sharedId)
    if not sharedId then
        return nil
    end

    for _, zombieData in ipairs(activeZombies) do
        if zombieData.sharedId == sharedId then
            return zombieData
        end
    end

    return nil
end

local function GetLastDamageBoneSafe(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return nil
    end

    local success, hasBone, bone = pcall(GetPedLastDamageBone, ped)
    if success and hasBone then
        return bone
    end

    return nil
end

local function UpdateZombieDamageState(zombieData, zombie)
    if not zombieData or not zombie or zombie == 0 or not DoesEntityExist(zombie) then
        return
    end

    local bone = GetLastDamageBoneSafe(zombie)
    if not bone then
        return
    end

    zombieData.lastDamageBone = bone
end

local function IsZombieMovementBlocked(zombie)
    if not zombie or zombie == 0 or not DoesEntityExist(zombie) then
        return false
    end

    return IsPedRagdoll(zombie)
        or IsPedFalling(zombie)
        or IsPedGettingUp(zombie)
        or IsPedRunningRagdollTask(zombie)
end

local function StopZombieHorizontalVelocity(zombie)
    if not zombie or zombie == 0 or not DoesEntityExist(zombie) then
        return
    end

    local velocity = GetEntityVelocity(zombie)
    SetEntityVelocity(zombie, 0.0, 0.0, velocity.z)
end

local function ApplyZombieBehaviorProfile(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return
    end

    SetPedFleeAttributes(ped, 0, 0)

    SetPedCombatAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 1, false)
    SetPedCombatAttributes(ped, 2, false)
    SetPedCombatAttributes(ped, 3, false)
    SetPedCombatAttributes(ped, 5, true)
    SetPedCombatAttributes(ped, 17, false)
    SetPedCombatAttributes(ped, 21, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCombatAttributes(ped, 50, false)
    SetPedCombatAttributes(ped, 58, true)
    SetPedCombatAttributes(ped, 63, false)
    SetPedCombatAttributes(ped, 78, true)

    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanPlayAmbientAnims(ped, false)
    DisablePedPainAudio(ped, true)

    pcall(SetAmbientVoiceName, ped, '')
    pcall(StopCurrentPlayingAmbientSpeech, ped)
    pcall(StopPedSpeaking, ped, true)
end

function RequestAnimDictSafe(dict)
    if not dict then return false end
    if loadedDicts[dict] then return true end
    if HasAnimDictLoaded(dict) then
        loadedDicts[dict] = true
        return true
    end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then
            DAnim(('DICT FAILED: %s'):format(dict))
            return false
        end
        Wait(20)
    end
    loadedDicts[dict] = true
    DAnim(('DICT loaded: %s'):format(dict))
    return true
end

local function RequestClipsetSafe(clipset)
    if not clipset then return false end
    if loadedClipsets[clipset] then return true end
    if HasAnimSetLoaded(clipset) then
        loadedClipsets[clipset] = true
        return true
    end
    RequestAnimSet(clipset)
    local timeout = GetGameTimer() + 3000
    while not HasAnimSetLoaded(clipset) do
        if GetGameTimer() > timeout then
            DAnim(('CLIPSET FAILED: %s'):format(clipset))
            return false
        end
        Wait(20)
    end
    loadedClipsets[clipset] = true
    DAnim(('CLIPSET loaded: %s'):format(clipset))
    return true
end

local function RequestPtfxDictSafe(dict)
    if not dict then return false end
    if loadedPtfxDicts[dict] then return true end
    if HasNamedPtfxAssetLoaded(dict) then
        loadedPtfxDicts[dict] = true
        return true
    end
    RequestNamedPtfxAsset(dict)
    local timeout = GetGameTimer() + 3000
    while not HasNamedPtfxAssetLoaded(dict) do
        if GetGameTimer() > timeout then return false end
        Wait(20)
    end
    loadedPtfxDicts[dict] = true
    return true
end

-- Night check: game hour in (22, 5) — used for "elite only at night".
local function IsNightTime()
    local h = GetClockHours()
    return h >= 22 or h < 5
end

-- Pick a zombie type by weighted random. context.eliteOnly = true
-- filters out walkers (used at night or inside red zones).
local function PickZombieType(context)
    local types = Config.ZombieTypes
    if not types or #types == 0 then return nil end

    local eliteOnly = context and context.eliteOnly
    -- If night is flagged elite-only, apply automatically.
    if not eliteOnly and Config.EliteOnlyContexts and Config.EliteOnlyContexts.night and IsNightTime() then
        eliteOnly = true
    end

    local pool = {}
    local total = 0
    for _, t in ipairs(types) do
        if not (eliteOnly and t.id == 'walker') then
            pool[#pool + 1] = t
            total = total + (t.weight or 0)
        end
    end

    if #pool == 0 or total <= 0 then return nil end

    local roll = math.random() * total
    local accum = 0
    for _, t in ipairs(pool) do
        accum = accum + (t.weight or 0)
        if roll <= accum then return t end
    end
    return pool[#pool]
end

local function GetSafeZones()
    local success, zones = pcall(function()
        return exports['corex-zones']:GetSafeZones()
    end)
    if success and zones then return zones end
    return {}
end

function IsNearSafeZone(coords)
    local safeZones = GetSafeZones()
    local buffer = Config.SafeZoneBuffer or 20.0
    for _, zone in ipairs(safeZones) do
        if GetDistance(coords, zone.coords) <= (zone.radius + buffer) then
            return true
        end
    end
    return false
end

local function GetRandomSpawnPosition()
    if not isReady then return nil end

    local playerCoords = Corex.Functions.GetCoords()
    local minDist = Config.Spawning.minDistance
    local maxDist = Config.Spawning.maxDistance

    for _ = 1, 30 do
        local angle = math.random() * 2 * math.pi
        local distance = minDist + math.random() * (maxDist - minDist)

        local x = playerCoords.x + math.cos(angle) * distance
        local y = playerCoords.y + math.sin(angle) * distance
        if ZX.Spawn and ZX.Spawn.ValidateSpawnPosition then
            local spawn = ZX.Spawn.ValidateSpawnPosition(vector3(x, y, playerCoords.z), {
                playerCoords = playerCoords,
                minDistance = minDist,
                maxDistance = maxDist,
                requireOffRoad = true
            })
            if spawn then
                return spawn
            end
        end
    end
    return nil
end

local function LoadZombieModel(modelName)
    if not modelName then return nil end
    local modelHash = GetHashKey(modelName)
    if not IsModelValid(modelHash) or not IsModelInCdimage(modelHash) then
        DLog(('Model NOT in cdimage: %s'):format(modelName))
        return nil
    end

    RequestModel(modelHash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(modelHash) do
        if GetGameTimer() > timeout then
            DLog(('Model load TIMEOUT: %s'):format(modelName))
            return nil
        end
        Wait(50)
    end
    DLog(('Model loaded OK: %s'):format(modelName))
    return modelHash
end

-- Fisher-Yates shuffle in place (used to vary ped pools per spawn).
local function ShuffleInPlace(t)
    for i = #t, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

local function ResolveZombieModel(typeData)
    if Config.ForceTrueZombieModel ~= false then
        local forcedModelName = Config.TrueZombieModel or 'u_m_y_zombie_01'
        local forcedHash = LoadZombieModel(forcedModelName)
        if forcedHash then
            return forcedHash, forcedModelName
        end
    end

    local candidates = {}

    if typeData and typeData.models then
        for _, m in ipairs(typeData.models) do candidates[#candidates + 1] = m end
    end

    -- Shuffle the type's own pool so each spawn picks a random model;
    -- without this, the first model always wins deterministically.
    ShuffleInPlace(candidates)

    -- Append FallbackModels at the tail (known-good, always last resort).
    for _, m in ipairs(Config.FallbackModels or {}) do
        local already = false
        for _, c in ipairs(candidates) do
            if c == m then
                already = true
                break
            end
        end
        if not already then candidates[#candidates + 1] = m end
    end

    for _, modelName in ipairs(candidates) do
        local hash = LoadZombieModel(modelName)
        if hash then
            return hash, modelName
        end
    end

    return nil, nil
end

local function ApplyVisualTint(ped, tint, typeData)
    if typeData and typeData.applyZombieTint then
        SetPedHeadBlendData(ped, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, false)
        SetPedHeadOverlayColor(ped, 1, 1, 15, 15)
        SetPedHeadOverlayColor(ped, 2, 1, 15, 15)
        SetPedHeadOverlay(ped, 1, 6, 1.0)
        SetPedHeadOverlay(ped, 6, 3, 0.7)
        SetPedHeadOverlay(ped, 7, 5, 0.8)
        SetPedEyeColor(ped, 21)
    elseif tint then
        SetPedHeadBlendData(ped, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, false)
    end

    if typeData and typeData.damagePacks then
        for _, pack in ipairs(typeData.damagePacks) do
            ApplyPedDamagePack(ped, pack, 0.0, 1.0)
        end
    end
end

local function StartSpecialParticle(zombieData)
    local typeData = zombieData.typeData
    if not typeData.ptfx then return end

    local ptfxDict = typeData.ptfx.dict
    if not RequestPtfxDictSafe(ptfxDict) then return end

    UseParticleFxAssetNextCall(ptfxDict)
    local bone = typeData.ptfx.bone or 0
    local boneIndex = GetPedBoneIndex(zombieData.entity, 0x796E)

    local handle = StartParticleFxLoopedOnPedBone(
        typeData.ptfx.name,
        zombieData.entity,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        boneIndex,
        typeData.ptfx.scale or 0.8,
        false, false, false
    )

    if handle and handle ~= 0 then
        zombieData.ptfxHandle = handle
    end
end

local function StopSpecialParticle(zombieData)
    if zombieData.ptfxHandle then
        StopParticleFxLooped(zombieData.ptfxHandle, false)
        zombieData.ptfxHandle = nil
    end
end

local function ConfigureZombie(ped, typeData)
    local typeId = typeData.id or 'walker'

    SetEntityMaxHealth(ped, typeData.health + 100)
    SetEntityHealth(ped, typeData.health + 100)
    SetPedArmour(ped, typeData.armor or 0)
    SetPedAccuracy(ped, 0)

    ApplyZombieBehaviorProfile(ped)

    SetPedCombatRange(ped, 0)
    SetPedCombatAbility(ped, 0)
    SetPedCombatMovement(ped, 0)
    SetPedAlertness(ped, 0)

    SetPedHearingRange(ped, 0.0)
    SetPedSeeingRange(ped, 0.0)

    SetPedDropsWeaponsWhenDead(ped, false)
    SetPedCanRagdollFromPlayerImpact(ped, true)
    SetPedSuffersCriticalHits(ped, false)
    SetPedCanBeTargetted(ped, true)
    SetPedAsEnemy(ped, true)
    SetPedCanEvasiveDive(ped, false)
    SetPedCanBeKnockedOffVehicle(ped, false)
    SetPedConfigFlag(ped, 100, false)

    if ZOMBIE_RELATIONSHIP_HASH then
        SetPedRelationshipGroupHash(ped, ZOMBIE_RELATIONSHIP_HASH)
        SetPedRelationshipGroupDefaultHash(ped, ZOMBIE_RELATIONSHIP_HASH)
    end

    SetPedConfigFlag(ped, 166, true)
    SetPedConfigFlag(ped, 281, true)
    SetPedConfigFlag(ped, 208, true)
    SetPedConfigFlag(ped, 294, true)
    SetPedConfigFlag(ped, 122, true)
    SetPedConfigFlag(ped, 17, false)

    local rateOverride = typeData.moveRateOverride or 1.1
    SetPedMoveRateOverride(ped, rateOverride)

    local animSet = Config.Animations[typeId]
    local chosenClipset = nil

    if Config.ZombieMovement and Config.ZombieMovement.primary then
        local primaryCs = Config.ZombieMovement.primary[typeId]
        if primaryCs and RequestClipsetSafe(primaryCs) then
            SetPedMovementClipset(ped, primaryCs, 1.0)
            chosenClipset = primaryCs
            DAnim(('%s movement: PRIMARY %s OK'):format(typeId, primaryCs))
        end
    end

    if not chosenClipset and animSet and animSet.moveClipset then
        if RequestClipsetSafe(animSet.moveClipset) then
            SetPedMovementClipset(ped, animSet.moveClipset, 1.0)
            chosenClipset = animSet.moveClipset
            DAnim(('%s movement: ANIMSET %s OK'):format(typeId, animSet.moveClipset))
        end
    end

    if not chosenClipset then
        for _, fbCs in ipairs(Config.FallbackClipsets or {}) do
            if RequestClipsetSafe(fbCs) then
                SetPedMovementClipset(ped, fbCs, 1.0)
                chosenClipset = fbCs
                DAnim(('%s movement: FALLBACK %s OK'):format(typeId, fbCs))
                break
            end
        end
    end

    if not chosenClipset then
        DLog(('%s movement: ALL CLIPSETS FAILED'):format(typeId))
    end

    local attackDict = animSet and animSet.attackDict
    if attackDict then
        if not RequestAnimDictSafe(attackDict) then
            DAnim(('%s attack dict FAILED: %s — using fallback'):format(typeId, attackDict))
            attackDict = Config.FallbackAttackDict
            if attackDict then
                RequestAnimDictSafe(attackDict)
            end
        end
    end

    local attackPool = animSet and animSet.attackAnims
    if type(attackPool) == 'table' then
        for _, entry in ipairs(attackPool) do
            if type(entry) == 'table' and entry.dict then
                RequestAnimDictSafe(entry.dict)
            end
        end
    end

    ApplyVisualTint(ped, typeData.colorTint, typeData)

    DLog(('Configured %s | clipset=%s | model=%s'):format(typeId, tostring(chosenClipset), 'ped'))

    return chosenClipset
end

-- Pick a random attack anim from the type's pool. Cached on zombieData
-- at spawn; PlayAttackAnim can also re-roll per swing for extra variety.
local function PickAttackAnim(typeData)
    local animSet = Config.Animations[typeData.id or 'walker']
    if not animSet then return nil, nil end
    local dict = animSet.attackDict
    local pool = animSet.attackAnims
    if type(pool) == 'table' and #pool > 0 then
        if type(pool[1]) == 'table' then
            local chosen = pool[math.random(1, #pool)]
            return chosen.dict or dict, chosen.anim
        end
        return dict, pool[math.random(1, #pool)]
    end
    return dict, nil
end

local function SpawnZombie(forcedCoords, forcedType, spawnOptions)
    -- Defense-in-depth guard: never spawn a zombie until the game session
    -- AND the local player are fully ready. Prevents race-condition spawns
    -- during the critical window where the virginia-october-hydrogen crash
    -- can fire. This also makes the synchronous relationship-group init at
    -- the top of the file safe — if a zombie is somehow requested before
    -- the hash is populated, we bail cleanly.
    if not ZOMBIE_RELATIONSHIP_HASH then return nil end
    if not NetworkIsSessionStarted() then return nil end
    if not NetworkIsPlayerActive(PlayerId()) then return nil end
    local _playerPed = PlayerPedId()
    if not _playerPed or _playerPed == 0 or not DoesEntityExist(_playerPed) then
        return nil
    end

    spawnOptions = spawnOptions or {}
    local coords = forcedCoords
    if not coords and ZX.Spawn and ZX.Spawn.GetNextSpawnPosition then
        local playerCoords = Corex.Functions.GetCoords()
        coords = ZX.Spawn.GetNextSpawnPosition(playerCoords)
    end
    if not coords then
        coords = GetRandomSpawnPosition()
    end
    if not coords then
        return nil
    end

    if ZX.Spawn and ZX.Spawn.ValidateSpawnPosition then
        coords = ZX.Spawn.ValidateSpawnPosition(coords, {
            playerCoords = forcedCoords and nil or Corex.Functions.GetCoords(),
            skipDistanceCheck = forcedCoords ~= nil,
            requireOffRoad = false
        })
    end
    if not coords then
        DLog('Spawn FAILED — invalid position (water / sky / non-walkable)')
        return nil
    end

    if IsNearSafeZone(coords) then
        DLog('Spawn blocked — inside safe zone buffer')
        return nil
    end

    local typeData = forcedType or PickZombieType()
    if not typeData then
        DLog('Spawn FAILED — no zombie type selected')
        return nil
    end

    local modelHash, modelName = ResolveZombieModel(typeData)
    if not modelHash then
        DLog(('Spawn FAILED — all models failed for %s'):format(typeData.id or '?'))
        return nil
    end

    local forceNetworked = spawnOptions.forceNetworked == true
    local networked = forceNetworked

    if not forceNetworked then
        local networkedCount = 0
        for _, zd in ipairs(activeZombies) do
            if not zd.isDead and DoesEntityExist(zd.entity) and NetworkGetEntityIsNetworked(zd.entity) then
                networkedCount = networkedCount + 1
            end
        end
        local maxNetworked = 14
        networked = networkedCount < maxNetworked
    end
    local zombie = CreatePed(4, modelHash, coords.x, coords.y, coords.z, math.random(0, 360), networked, networked)
    if not DoesEntityExist(zombie) then
        DLog(('Spawn FAILED — CreatePed failed for %s'):format(modelName))
        SetModelAsNoLongerNeeded(modelHash)
        return nil
    end

    if ZX.Spawn and ZX.Spawn.ValidateSpawnPosition then
        local validatedCoords = ZX.Spawn.ValidateSpawnPosition(GetEntityCoords(zombie), {
            skipDistanceCheck = true,
            requireOffRoad = false
        })
        if not validatedCoords or IsEntityInWater(zombie) then
            DLog(('Spawn FAILED — ped landed in invalid area for %s'):format(modelName))
            SetModelAsNoLongerNeeded(modelHash)
            DeleteEntity(zombie)
            return nil
        end

        SetEntityCoordsNoOffset(zombie, validatedCoords.x, validatedCoords.y, validatedCoords.z, false, false, false)
    end

    SetEntityAsMissionEntity(zombie, true, false)
    SetPedAsEnemy(zombie, true)
    local chosenClipset = ConfigureZombie(zombie, typeData)
    SetModelAsNoLongerNeeded(modelHash)

    DLog(('Spawned %s | model=%s | clipset=%s'):format(typeData.id, modelName, tostring(chosenClipset)))

    local now = GetGameTimer()
    local spawnCfg = Config.ZombieSpawn
    local isSpawning = false
    local spawnAnimEnd = 0

    if spawnCfg and spawnCfg.enabled then
        if RequestAnimDictSafe(spawnCfg.dict) then
            ClearPedTasks(zombie)
            TaskPlayAnim(zombie, spawnCfg.dict, spawnCfg.anim, 1.0, -1.0, spawnCfg.duration or 2800, 0, 0.0, false, false, false)
            isSpawning = true
            spawnAnimEnd = now + (spawnCfg.duration or 2800)
        end
    end

    if not isSpawning then
        ClearPedTasks(zombie)
        local localPed = Corex and Corex.Functions and Corex.Functions.GetPed and Corex.Functions.GetPed() or 0
        if localPed and localPed ~= 0 and DoesEntityExist(localPed) and not IsPedDeadOrDying(localPed, true) then
            TaskGoToEntity(zombie, localPed, -1, 0.5, 1.5, 1077936128, 0.0)
            SetPedKeepTask(zombie, true)
        end
    end

    local attackDict, attackAnim = PickAttackAnim(typeData)
    local moanCfg = Config.Fear and Config.Fear.ambientMoan
    local nextMoanAt = moanCfg
        and (now + math.random(moanCfg.minInterval or 8000, moanCfg.maxInterval or 15000))
        or 0

    local zombieData = {
        id = spawnOptions.sharedId or ('z_%d_%d_%d'):format(GetPlayerServerId(PlayerId()), now, zombie),
        entity = zombie,
        typeData = typeData,
        spawnTime = now,
        coords = coords,
        isDead = false,
        state = isSpawning and 'spawning' or 'idle',
        lastAttack = 0,
        lastTaskUpdate = 0,
        lastBrainTick = 0,
        lastPosition = coords,
        lastPositionTime = now,
        stuckSince = 0,
        lastClimbAttempt = 0,
        chosenClipset    = chosenClipset,
        chosenAttackDict = attackDict,
        chosenAttackAnim = attackAnim,
        lastSnarlAt      = 0,
        nextMoanAt       = nextMoanAt,
        scenarioActive   = false,
        attackPhase      = 'none',
        attackPhaseEnd   = 0,
        damageApplied    = false,
        damageApplyAt    = 0,
        currentAnim      = nil,
        currentDict      = nil,
        isSpawning       = isSpawning,
        spawnAnimEnd     = spawnAnimEnd,
        sharedId         = spawnOptions.sharedId,
        sharedBatchId    = spawnOptions.sharedBatchId,
        isSharedOwned    = spawnOptions.sharedId ~= nil,
        networkId        = networked and NetworkGetNetworkIdFromEntity(zombie) or nil
    }

    if typeData.ptfx then
        StartSpecialParticle(zombieData)
    end

    table.insert(activeZombies, zombieData)
    return zombie
end

local function CleanupZombie(index)
    local zombieData = activeZombies[index]
    if not zombieData then return end

    StopSpecialParticle(zombieData)

    if DoesEntityExist(zombieData.entity) then
        SetEntityAsNoLongerNeeded(zombieData.entity)
        if not zombieData.sharedId or NetworkHasControlOfEntity(zombieData.entity) then
            DeleteEntity(zombieData.entity)
        end
    end
    table.remove(activeZombies, index)
end

local LOOT_RARITY_ORDER = { 'common', 'uncommon', 'rare', 'epic', 'legendary' }

local function GetLootRarity()
    local roll = math.random()
    local accum = 0
    for _, rarity in ipairs(LOOT_RARITY_ORDER) do
        local data = Config.LootSystem.lootTables[rarity]
        if data then
            accum = accum + data.chance
            if roll <= accum then return rarity, data end
        end
    end
    return 'common', Config.LootSystem.lootTables.common
end

local function DropLoot(coords, zombieId)
    if not Config.LootSystem.enabled then return end
    if not zombieId then return end
    if math.random() > Config.LootSystem.dropChance then return end

    local rarity, lootTable = GetLootRarity()
    if not lootTable or not lootTable.items then return end

    local itemData = lootTable.items[math.random(1, #lootTable.items)]
    local amount = math.random(itemData.min, itemData.max)
    TriggerServerEvent('corex-zombies:server:dropLoot', coords, itemData.name, amount, rarity, zombieId)
end

-- Re-rolls the attack anim from the pool per swing so the same zombie
-- doesn't throw identical punches repeatedly.
local function PlayAttackAnim(zombie, typeData, zombieData)
    local animSet = Config.Animations[typeData.id or 'walker']
    if not animSet then return end
    local pool = animSet.attackAnims
    if type(pool) ~= 'table' or #pool == 0 then return end

    local dict, anim, speed, duration
    if type(pool[1]) == 'table' then
        local chosen = pool[math.random(1, #pool)]
        dict = chosen.dict or animSet.attackDict
        anim = chosen.anim
        speed = chosen.speed or animSet.playbackSpeed or 0.55
        duration = chosen.duration or animSet.attackDuration or 800
    else
        dict = animSet.attackDict
        anim = pool[math.random(1, #pool)]
        speed = animSet.playbackSpeed or 0.55
        duration = animSet.attackDuration or 800
    end

    if not anim or not RequestAnimDictSafe(dict) then return end

    if zombieData then
        zombieData.chosenAttackDict = dict
        zombieData.chosenAttackAnim = anim
    end

    TaskPlayAnim(zombie, dict, anim, speed, -speed, duration, 48, 0.0, false, false, false)
end

function ApplySpecialOnHit(typeData, playerPed)
    if not typeData.special then return end

    if typeData.special == 'electric' and typeData.stunOnHit then
        SetPedToRagdoll(playerPed, typeData.stunOnHit, typeData.stunOnHit, 0, false, false, false)
    elseif typeData.special == 'fire' and typeData.igniteOnHit then
        if not IsEntityOnFire(playerPed) then
            StartEntityFire(playerPed)
            SetTimeout(2500, function()
                if DoesEntityExist(playerPed) and IsEntityOnFire(playerPed) then
                    StopEntityFire(playerPed)
                end
            end)
        end
    end
end

-- Weather hash check — rain/fog/thunder boost zombie density.
local BAD_WEATHER = {
    [GetHashKey('RAIN')] = true,
    [GetHashKey('THUNDER')] = true,
    [GetHashKey('FOGGY')] = true,
}

local function IsBadWeather()
    return BAD_WEATHER[GetPrevWeatherTypeHashName()] == true
        or BAD_WEATHER[GetNextWeatherTypeHashName()] == true
end

-- Compute the current population budget based on distance to nearest
-- safe zone, time of day, and weather. Called from the spawn loop.
local function ResolveDynamicBudget(playerCoords)
    local cfg = Config.PopulationScaling
    if not cfg then return Config.PopulationBudget or 24 end

    -- Distance-to-safe-zone-boundary. Fallback big number if export missing.
    local dist = 99999.0
    local ok, res = pcall(function()
        return exports['corex-zones']:GetSafeZoneDistance(playerCoords)
    end)
    if ok and type(res) == 'number' then dist = res end

    -- Pick first band whose maxDist >= dist (wilderness band is 99999).
    local mult = 1.0
    if cfg.bands then
        for _, band in ipairs(cfg.bands) do
            if dist <= (band.maxDist or 99999) then
                mult = band.mult or 1.0
                break
            end
        end
    end

    if IsNightTime() then
        mult = mult * (cfg.nightMult or 1.25)
    end
    if IsBadWeather() then
        mult = mult * (cfg.weatherMult or 1.15)
    end

    local baseline = cfg.baseline or Config.PopulationBudget or 32
    local absMax   = cfg.absoluteMax or 42
    return math.min(absMax, math.floor(baseline * mult))
end

-- Count live zombies within `radius` of coords. Used for swarm damage bonus,
-- heartbeat audio gating, etc. Squared-distance comparison for perf.
function CountZombiesNear(coords, radius)
    if not coords or not radius then return 0 end
    local r2 = radius * radius
    local n = 0
    for _, z in ipairs(activeZombies) do
        if not z.isDead and DoesEntityExist(z.entity) then
            local zc = GetEntityCoords(z.entity)
            local dx, dy, dz = zc.x - coords.x, zc.y - coords.y, zc.z - coords.z
            if (dx*dx + dy*dy + dz*dz) <= r2 then
                n = n + 1
            end
        end
    end
    return n
end

local function IssueChaseTask(zombie, playerPed, chaseSpeed, typeData)
    if IsZombieMovementBlocked(zombie) then
        StopZombieHorizontalVelocity(zombie)
        return
    end

    local pc = GetEntityCoords(playerPed)
    ClearPedTasks(zombie)
    TaskGoToEntity(zombie, playerPed, -1, 0.5, chaseSpeed or 1.0, 1077936128, 0.0)
    SetPedKeepTask(zombie, true)

    if typeData and typeData.id == 'runner' then
        local animSet = Config.Animations.runner
        if animSet and animSet.chaseAnim then
            local ca = animSet.chaseAnim
            if RequestAnimDictSafe(ca.dict) then
                TaskPlayAnim(zombie, ca.dict, ca.anim, ca.speed or 1.0, -(ca.speed or 1.0), -1, 48, 0.0, false, false, false)
            end
        end
        SetPedMoveRateOverride(zombie, typeData.moveRateOverride or 2.0)
        SetPedConfigFlag(zombie, 184, true)
        SetPedConfigFlag(zombie, 351, true)
    end
end

-- Pick a target player via weighted random across active ped IDs near
-- `zombieCoords`, with weight = 1 / (distance^bias). Closer players are
-- much more likely to be picked, but others still get chances — prevents
-- kiting one player while others are ignored.
local function BuildPlayerCache(localPlayerPed)
    local cache = {}
    for _, pid in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(pid)
        if ped and ped ~= 0 and DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then
            local pc = GetEntityCoords(ped)
            cache[#cache + 1] = { ped = ped, coords = pc, isLocal = (ped == localPlayerPed) }
        end
    end
    return cache
end

local function PickTarget(zombieCoords, engagementRange, playerCache, localPlayerPed, localPlayerCoords)
    local r2 = engagementRange * engagementRange

    if localPlayerPed and localPlayerPed ~= 0 and DoesEntityExist(localPlayerPed) and not IsPedDeadOrDying(localPlayerPed, true) and localPlayerCoords then
        local dx = localPlayerCoords.x - zombieCoords.x
        local dy = localPlayerCoords.y - zombieCoords.y
        local dz = localPlayerCoords.z - zombieCoords.z
        local localD2 = dx*dx + dy*dy + dz*dz
        if localD2 <= r2 then
            return localPlayerPed, localPlayerCoords, math.sqrt(localD2)
        end
    end

    local bestCandidate = nil

    for _, entry in ipairs(playerCache) do
        if not entry.isLocal then
            local pc = entry.coords
            local dx, dy, dz = pc.x - zombieCoords.x, pc.y - zombieCoords.y, pc.z - zombieCoords.z
            local d2 = dx*dx + dy*dy + dz*dz
            if d2 <= r2 then
                local d = math.sqrt(d2)
                if not bestCandidate or d < bestCandidate.dist then
                    bestCandidate = { ped = entry.ped, coords = pc, dist = d }
                end
            end
        end
    end

    if bestCandidate then
        return bestCandidate.ped, bestCandidate.coords, bestCandidate.dist
    end

    return nil, nil, nil
end

-- Put a zombie into an idle scenario (shuffling, mumbling). Cleared
-- on wake via ClearPedTasks. Tracked via zombieData.scenarioActive.
local function EnterIdleScenario(zombieData, zombie)
    if zombieData.scenarioActive then return end

    local zombieIdles = Config.ZombieIdle
    if zombieIdles and #zombieIdles > 0 then
        local idle = zombieIdles[math.random(1, #zombieIdles)]
        if RequestAnimDictSafe(idle.dict) then
            ClearPedTasks(zombie)
            TaskPlayAnim(zombie, idle.dict, idle.anim, 1.0, -1.0, idle.duration or 8000, 1 + 32, 0.0, false, false, false)
            zombieData.scenarioActive = true
            zombieData.state = 'idle_scenario'
            return
        end
    end

    local pool = Config.IdleScenarios
    if not pool or #pool == 0 then return end
    local scenario = pool[math.random(1, #pool)]
    ClearPedTasks(zombie)
    TaskStartScenarioInPlace(zombie, scenario, 0, true)
    zombieData.scenarioActive = true
    zombieData.state = 'idle_scenario'
end

local function ExitIdleScenario(zombieData, zombie)
    if zombieData.scenarioActive then
        ClearPedTasks(zombie)
        zombieData.scenarioActive = false
    end
end

local function UpdateZombieAI(zombieData, playerPed, localPlayerCoords, now, playerCache)
    local zombie = zombieData.entity
    if not DoesEntityExist(zombie) then return end
    if IsPedDeadOrDying(zombie, true) then
        if ZX.Combat then ZX.Combat.Reset(zombieData) end
        return
    end
    if isGrabbed and grabbingZombie == zombie then return end

    UpdateZombieDamageState(zombieData, zombie)

    if zombieData.isSpawning then
        if now < (zombieData.spawnAnimEnd or 0) then return end
        zombieData.isSpawning = false
        zombieData.state = 'idle'
        ClearPedTasks(zombie)
    end

    if IsZombieMovementBlocked(zombie) then
        if ZX.Combat then
            ZX.Combat.Reset(zombieData)
        end

        StopZombieHorizontalVelocity(zombie)
        zombieData.state = 'downed'
        zombieData.lastTaskUpdate = now
        zombieData.lastBrainTick = now
        zombieData.stuckSince = 0
        return
    elseif zombieData.state == 'downed' then
        zombieData.state = 'idle'
        zombieData.lastPosition = GetEntityCoords(zombie)
        zombieData.lastPositionTime = now
    end

    local zombieCoords = GetEntityCoords(zombie)
    local engagementRange = (Config.AI and Config.AI.engagementRange) or 80.0

    -- Multi-player target pick: closest-weighted random across nearby peds.
    -- Falls back to local player if nothing else is around.
    local targetPed, targetCoords, distance = PickTarget(zombieCoords, engagementRange, playerCache, playerPed, localPlayerCoords)
    if not targetPed then
        targetPed, targetCoords = playerPed, localPlayerCoords
        distance = GetDistance(zombieCoords, localPlayerCoords)
    end

    if distance > engagementRange then
        -- Beyond engagement range, but we STILL want the zombie to move
        -- toward the player (not stand still and not wander as a civilian).
        -- Only enter an idle scenario if the zombie is WAY out (>scenarioDistance)
        -- AND has been alive long enough that the grace period expired —
        -- this prevents the "spawned ped immediately looks civilian" problem.
        local scenarioDist = (Config.AI and Config.AI.scenarioDistance) or 180.0
        local graceMs      = (Config.AI and Config.AI.scenarioGraceMs)  or 15000
        local aliveMs      = now - (zombieData.spawnTime or now)

        if distance > scenarioDist and aliveMs > graceMs then
            -- Far + old enough → atmospheric scenario (standing around).
            EnterIdleScenario(zombieData, zombie)
            return
        end

        -- Default: keep pursuing. Clear any scenario and chase.
        ExitIdleScenario(zombieData, zombie)
        if zombieData.state ~= 'chasing' or (now - (zombieData.lastTaskUpdate or 0)) > 1500 then
            IssueChaseTask(zombie, targetPed, zombieData.typeData.moveSpeed or 1.0, zombieData.typeData)
            zombieData.state = 'chasing'
            zombieData.lastTaskUpdate = now
        end
        return
    end

    -- In engagement range — if we were in a scenario, leave it.
    if zombieData.scenarioActive then
        ExitIdleScenario(zombieData, zombie)
    end

    -- State transition idle → chasing: broadcast sighting pulse + snarl.
    if zombieData.state == 'idle' or zombieData.state == 'idle_scenario' or zombieData.state == nil then
        if ZX.Horde then ZX.Horde.Broadcast(zombieCoords) end
        if ZX.Audio and ZX.Audio.PlaySnarl then ZX.Audio.PlaySnarl(zombie, zombieData, now) end
        zombieData.state = 'alerted'
    end

    -- Rebind for the rest of the function (damage/sprite expects these names).
    local playerCoords = targetCoords
    playerPed          = targetPed

    local typeData = zombieData.typeData

    if distance <= typeData.attackRange then
        if zombieData.scenarioActive then
            ExitIdleScenario(zombieData, zombie)
        end

        if zombieData.state ~= 'attacking' and zombieData.state ~= 'combat' then
            zombieData.state = 'attacking'
            zombieData.lastTaskUpdate = now
            if ZX.Horde then ZX.Horde.Broadcast(zombieCoords) end
            if ZX.Audio and ZX.Audio.PlaySnarl then ZX.Audio.PlaySnarl(zombie, zombieData, now) end
        end

        if ZX.Combat then
            ZX.Combat.Process(zombieData, zombie, playerPed, typeData, now)
        end

        zombieData.lastPosition = zombieCoords
        zombieData.lastPositionTime = now
        zombieData.stuckSince = 0
        return
    end

    local chaseSpeed = typeData.moveSpeed or 1.0
    if typeData.sprintOnSight then
        chaseSpeed = math.max(chaseSpeed, 2.0)
    end

    local brainTick = (Config.AI and Config.AI.brainTickMs) or 500
    if now - (zombieData.lastBrainTick or 0) < brainTick then return end
    zombieData.lastBrainTick = now

    local lastPos = zombieData.lastPosition or zombieCoords
    local moved = GetDistance2D(zombieCoords, lastPos)
    local stuckThreshold = (Config.AI and Config.AI.stuckThreshold) or 0.25
    local stuckTimeMs = (Config.AI and Config.AI.stuckTimeMs) or 2500

    if moved < stuckThreshold then
        if zombieData.stuckSince == 0 then
            zombieData.stuckSince = now
        end
    else
        zombieData.stuckSince = 0
        zombieData.lastPosition = zombieCoords
        zombieData.lastPositionTime = now
    end

    local isStuck = zombieData.stuckSince > 0 and (now - zombieData.stuckSince) > stuckTimeMs

    if isStuck then
        if ZX.Combat then ZX.Combat.Reset(zombieData) end
        if typeData.canClimb and (now - (zombieData.lastClimbAttempt or 0)) > 1800 then
            zombieData.lastClimbAttempt = now

            local dx = playerCoords.x - zombieCoords.x
            local dy = playerCoords.y - zombieCoords.y
            local dz = playerCoords.z - zombieCoords.z
            local climbMax = (Config.AI and Config.AI.climbMaxHeight) or 2.5

            if dz > 0.6 and dz <= climbMax then
                TaskClimb(zombie, true)
            else
                ClearPedTasks(zombie)
                TaskGoStraightToCoord(zombie, playerCoords.x, playerCoords.y, playerCoords.z, chaseSpeed, -1, 0.0, 0.0)
            end
        else
            ClearPedTasks(zombie)
            TaskGoStraightToCoord(zombie, playerCoords.x, playerCoords.y, playerCoords.z, chaseSpeed, -1, 0.0, 0.0)
        end

        zombieData.state = 'unstuck'
        zombieData.lastTaskUpdate = now
        zombieData.stuckSince = now  -- arm next cycle
        return
    end

    local taskRefresh = (Config.AI and Config.AI.taskRefreshMs) or 800

    if ZX.Combat and ZX.Combat.IsBusy(zombieData) then
        ZX.Combat.FaceTarget(zombie, playerPed, 5.0)
        return
    end

    if zombieData.state ~= 'chasing' or (now - (zombieData.lastTaskUpdate or 0)) > taskRefresh then
        IssueChaseTask(zombie, playerPed, chaseSpeed, typeData)
        zombieData.state = 'chasing'
        zombieData.lastTaskUpdate = now
    end
end

local function GetGrabConfig()
    return Config.GrabMechanic or { enabled = false }
end

local function CanGrabPlayer(zombieEntity)
    local grabConfig = GetGrabConfig()
    if not grabConfig.enabled then return false end
    if isGrabbed then return false end
    if grabCooldown[zombieEntity] and GetGameTimer() < grabCooldown[zombieEntity] then return false end
    return true
end

local function StartGrab(zombieEntity)
    if not CanGrabPlayer(zombieEntity) then return end

    isGrabbed = true
    grabbingZombie = zombieEntity
    escapeProgress = 0
    grabDamageTimer = GetGameTimer()

    local playerPed = Corex.Functions.GetPed()
    ClearPedTasks(zombieEntity)
    ClearPedTasksImmediately(playerPed)

    local zombieCoords = GetEntityCoords(zombieEntity)
    local playerCoords = Corex.Functions.GetCoords()
    local heading = GetHeadingFromVector_2d(playerCoords.x - zombieCoords.x, playerCoords.y - zombieCoords.y)
    SetEntityHeading(zombieEntity, heading)

    RequestAnimDictSafe('melee@unarmed@streamed_core_fps')
    TaskPlayAnim(zombieEntity, 'melee@unarmed@streamed_core_fps', 'ground_attack_on_top', 3.0, -3.0, -1, 49, 0, false, false, false)
    FreezeEntityPosition(playerPed, true)

    -- Grab shriek — audible, telegraphs grab so bystanders react.
    if ZX.Audio and ZX.Audio.PlayGrabShriek then
        ZX.Audio.PlayGrabShriek(zombieEntity)
    end
end

local function EndGrab(escaped)
    if not isGrabbed then return end
    local grabConfig = GetGrabConfig()
    local playerPed = Corex.Functions.GetPed()

    FreezeEntityPosition(playerPed, false)
    ClearPedTasksImmediately(playerPed)

    if DoesEntityExist(grabbingZombie) then
        ClearPedTasks(grabbingZombie)
        grabCooldown[grabbingZombie] = GetGameTimer() + grabConfig.grabCooldownTime

        for _, zd in ipairs(activeZombies) do
            if zd.entity == grabbingZombie then
                if ZX.Combat then ZX.Combat.Reset(zd) end
                break
            end
        end

        if escaped then
            local playerCoords = Corex.Functions.GetCoords()
            local pushDir = GetEntityForwardVector(playerPed)
            local pushX = playerCoords.x - pushDir.x * 2.0
            local pushY = playerCoords.y - pushDir.y * 2.0
            local pushZ = playerCoords.z
            local found, gz = GetGroundZFor_3dCoord(pushX, pushY, pushZ + 20.0, false)
            if found then pushZ = gz end
            SetEntityCoords(grabbingZombie, pushX, pushY, pushZ, false, false, false, false)
            SetPedToRagdoll(grabbingZombie, 1500, 1500, 0, false, false, false)
        end
    end

    isGrabbed = false
    grabbingZombie = nil
    escapeProgress = 0
end

local function ProcessEscapeInput()
    if not isGrabbed then return end
    local grabConfig = GetGrabConfig()
    local currentTime = GetGameTimer()
    if currentTime - lastEscapePress < grabConfig.escapeCooldown then return end

    if IsControlJustPressed(0, 22) then
        lastEscapePress = currentTime
        escapeProgress = escapeProgress + 1
        if escapeProgress >= grabConfig.escapeRequired then
            EndGrab(true)
        end
    end
end

local function ApplyGrabDamage()
    if not isGrabbed then return end
    local grabConfig = GetGrabConfig()
    local currentTime = GetGameTimer()
    if currentTime - grabDamageTimer >= grabConfig.grabDamageInterval then
        grabDamageTimer = currentTime
        local playerPed = Corex.Functions.GetPed()
        ApplyDamageToPed(playerPed, grabConfig.grabDamage, false)
        TriggerEvent('corex-survival:client:zombieHit', grabConfig.grabDamage, 'grab')
        if GetEntityHealth(playerPed) <= 100 then
            EndGrab(false)
        end
    end
end

local function DrawEscapeUI()
    if not isGrabbed then return end
    local grabConfig = GetGrabConfig()
    local progress = escapeProgress / grabConfig.escapeRequired
    local barWidth, barHeight = 0.15, 0.02
    local barX, barY = 0.5, 0.85

    DrawRect(barX, barY, barWidth + 0.004, barHeight + 0.008, 0, 0, 0, 200)
    DrawRect(barX, barY, barWidth, barHeight, 50, 50, 50, 200)

    local fillWidth = barWidth * progress
    local fillX = barX - (barWidth / 2) + (fillWidth / 2)
    DrawRect(fillX, barY, fillWidth, barHeight, 200, 50, 50, 255)

    SetTextFont(4)
    SetTextScale(0.4, 0.4)
    SetTextColour(255, 255, 255, 255)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName('~r~GRABBED! ~w~Press ~y~SPACE~w~ to escape!')
    EndTextCommandDisplayText(0.5, 0.8)
end

local function PlayCoughAnim(playerPed)
    if isCoughing then return end
    local now = GetGameTimer()
    if now - lastCoughTime < 1500 then return end
    lastCoughTime = now
    isCoughing = true

    local dict = Config.ToxicEffect.coughDict or 'mp_player_intdrink'
    local anim = Config.ToxicEffect.coughAnim or 'loop_bottle'
    local duration = Config.ToxicEffect.coughDuration or 2500

    if RequestAnimDictSafe(dict) then
        TaskPlayAnim(playerPed, dict, anim, 4.0, -4.0, duration, 49, 0.0, false, false, false)
    end

    SetTimeout(duration, function()
        if DoesEntityExist(playerPed) then
            StopAnimTask(playerPed, dict, anim, 1.0)
        end
        isCoughing = false
    end)
end

local function DrawToxicVignette()
    if currentToxicExposure <= 0 and renderedToxicExposure <= 0.01 then return end
    local fade = Config.ToxicEffect.screenFadeColor
    if not fade then return end

    local now = GetGameTimer()
    local dt = lastToxicRenderTick and (now - lastToxicRenderTick) or 16
    lastToxicRenderTick = now

    local blend = math.min(1.0, math.max(0.0, dt / 250.0))
    renderedToxicExposure = renderedToxicExposure + ((currentToxicExposure or 0.0) - renderedToxicExposure) * blend

    if currentToxicExposure <= 0 and renderedToxicExposure <= 0.01 then
        renderedToxicExposure = 0.0
        return
    end

    local alpha = math.floor((fade.a or 40) * math.min(renderedToxicExposure, 1.0))
    DrawRect(0.5, 0.5, 2.0, 2.0, fade.r, fade.g, fade.b, alpha)
end

local function ProcessToxicAura(playerPed, playerCoords, now)
    local insideAura = false
    local closestZombie = nil
    local closestDist2 = 999999.0

    for _, zombieData in ipairs(activeZombies) do
        local typeData = zombieData.typeData
        if typeData and typeData.aura then
            if DoesEntityExist(zombieData.entity) and not IsPedDeadOrDying(zombieData.entity, true) then
                local zCoords = GetEntityCoords(zombieData.entity)
                local dx = zCoords.x - playerCoords.x
                local dy = zCoords.y - playerCoords.y
                local dz = zCoords.z - playerCoords.z
                local d2 = dx * dx + dy * dy + dz * dz
                local r2 = typeData.aura.radius * typeData.aura.radius
                if d2 <= r2 then
                    insideAura = true
                    if d2 < closestDist2 then
                        closestDist2 = d2
                        closestZombie = zombieData
                    end
                end
            end
        end
    end

    if insideAura and closestZombie then
        currentToxicExposure = math.min(1.0, currentToxicExposure + 0.04)
        local aura = closestZombie.typeData.aura
        if now - lastToxicTick >= aura.tickInterval then
            lastToxicTick = now
            ApplyDamageToPed(playerPed, aura.tickDamage, false)
            TriggerEvent('corex-survival:client:zombieHit', aura.tickDamage, 'toxic')
            PlayCoughAnim(playerPed)
        end
    else
        currentToxicExposure = math.max(0.0, currentToxicExposure - 0.02)
    end
end

-- Relationship group is set synchronously at module load above.
-- This thread just pre-warms common anim/clipset/ptfx assets.
CreateThread(function()
    -- Wait for Corex core AND the network session AND player login before
    -- starting the asset pre-warm. `isReady` flips when GetCoreObject() succeeds,
    -- which can happen long before the player is actually spawned. Flooding
    -- the streaming pool with Request* calls during the spawn window is a
    -- contributor to the virginia-october-hydrogen crash.
    while not isReady do Wait(500) end
    while not NetworkIsSessionStarted() do Wait(500) end
    while not LocalPlayer.state.isLoggedIn do Wait(500) end
    -- Additional buffer so PlacePlayerAtSpawn gets uncontested streaming
    -- bandwidth for the critical collision load.
    Wait(3000)

    DLog('Pre-warming assets...')

    -- Wait(0) between every Request* call — lets the streaming scheduler
    -- process each request in its own frame instead of firing dozens in one
    -- frame and stalling the pool.
    for _, typeDef in ipairs(Config.ZombieTypes or {}) do
        local animSet = Config.Animations[typeDef.id]
        if animSet then
            if animSet.moveClipset then
                RequestClipsetSafe(animSet.moveClipset)
                Wait(0)
            end
            if animSet.attackDict then
                RequestAnimDictSafe(animSet.attackDict)
                Wait(0)
            end
            local pool = animSet.attackAnims
            if type(pool) == 'table' then
                for _, entry in ipairs(pool) do
                    if type(entry) == 'table' and entry.dict then
                        RequestAnimDictSafe(entry.dict)
                        Wait(0)
                    end
                end
            end
        end
        if typeDef.ptfx then
            RequestPtfxDictSafe(typeDef.ptfx.dict)
            Wait(0)
        end
        if typeDef.attackPtfx then
            RequestPtfxDictSafe(typeDef.attackPtfx.dict)
            Wait(0)
        end
    end

    for _, fbCs in ipairs(Config.FallbackClipsets or {}) do
        RequestClipsetSafe(fbCs)
        Wait(0)
    end

    if Config.FallbackAttackDict then
        RequestAnimDictSafe(Config.FallbackAttackDict)
        Wait(0)
    end

    if Config.ZombieMovement and Config.ZombieMovement.primary then
        for _, cs in pairs(Config.ZombieMovement.primary) do
            RequestClipsetSafe(cs)
            Wait(0)
        end
    end

    if Config.ZombieSpawn and Config.ZombieSpawn.dict then
        RequestAnimDictSafe(Config.ZombieSpawn.dict)
        Wait(0)
    end

    if Config.ZombieIdle then
        for _, idle in ipairs(Config.ZombieIdle) do
            RequestAnimDictSafe(idle.dict)
            Wait(0)
        end
    end

    DLog('Pre-warm complete')
end)

CreateThread(function()
    -- Gate the spawn loop on full player readiness. `isReady` alone is not
    -- enough — it only confirms corex-core is available, not that the player
    -- ped is loaded. Spawning zombies before player is in the world can
    -- contribute to the spawn-time crash chain.
    while not isReady do Wait(500) end
    while not NetworkIsSessionStarted() do Wait(500) end
    while not LocalPlayer.state.isLoggedIn do Wait(500) end
    Wait(5000)  -- buffer after spawn before first zombie wave

    while true do
        Wait(Config.Spawning.spawnInterval or 5000)
        if not Config.Spawning.enabled then goto continue end

        local playerCoords = Corex.Functions.GetCoords()
        if IsInsideSharedSuppressionZone(playerCoords) then
            goto continue
        end

        local dynamicBudget = ResolveDynamicBudget(playerCoords)
        local currentCount = #activeZombies

        if ZX.Spawn then
            ZX.Spawn.TickMigration(playerCoords, GetGameTimer())
            local migPos = ZX.Spawn.GetMigrationPositions()
            if migPos then
                for _, data in ipairs(migPos) do
                    if currentCount < dynamicBudget then
                        local zombie = SpawnZombie(data.coords)
                        if zombie and DoesEntityExist(zombie) then
                            TaskGoStraightToCoord(zombie, data.target.x, data.target.y, data.target.z, 1.0, -1, 0.0, 0.0)
                            SetPedKeepTask(zombie, true)
                            currentCount = currentCount + 1
                        end
                    end
                end
            end
        end

        if currentCount < dynamicBudget then
            local spawnCount = math.min(Config.Spawning.maxZombiesPerSpawn, dynamicBudget - currentCount)
            for _ = 1, spawnCount do
                SpawnZombie()
            end
        end

        ::continue::
    end
end)

CreateThread(function()
    while not isReady do Wait(500) end

    while true do
        Wait(50)
        local playerPed = Corex.Functions.GetPed()
        if not playerPed or playerPed == 0 or IsPedDeadOrDying(playerPed, true) then goto runnerContinue end
        local playerCoords = Corex.Functions.GetCoords()

        for _, z in ipairs(activeZombies) do
            if not z.isDead and z.typeData and z.typeData.id == 'runner' and DoesEntityExist(z.entity) and not z.isSpawning then
                UpdateZombieDamageState(z, z.entity)

                if IsZombieMovementBlocked(z.entity) then
                    StopZombieHorizontalVelocity(z.entity)
                    goto continueRunner
                end

                local phase = z.attackPhase
                if phase == 'none' then
                    local zc = GetEntityCoords(z.entity)
                    local dx = playerCoords.x - zc.x
                    local dy = playerCoords.y - zc.y
                    local d = math.sqrt(dx * dx + dy * dy)
                    if d > 2.5 then
                        local force = 6.0
                        local vz = GetEntityVelocity(z.entity)
                        SetEntityVelocity(z.entity, (dx / d) * force, (dy / d) * force, vz.z)
                    end
                end
            end

            ::continueRunner::
        end

        ::runnerContinue::
    end
end)

CreateThread(function()
    while not isReady do Wait(500) end

    while true do
        Wait(200)

        local playerPed = Corex.Functions.GetPed()
        local playerCoords = Corex.Functions.GetCoords()
        local now = GetGameTimer()
        local playerCache = BuildPlayerCache(playerPed)

        for _, zombieData in ipairs(activeZombies) do
            if DoesEntityExist(zombieData.entity) and not zombieData.isDead then
                UpdateZombieAI(zombieData, playerPed, playerCoords, now, playerCache)
            end
        end

        ProcessToxicAura(playerPed, playerCoords, now)
    end
end)

CreateThread(function()
    while not isReady do Wait(500) end

    while true do
        Wait(5000)

        for _, zombieData in ipairs(activeZombies) do
            if DoesEntityExist(zombieData.entity) and not zombieData.isDead then
                ApplyZombieBehaviorProfile(zombieData.entity)
            end
        end
    end
end)

CreateThread(function()
    while not isReady do Wait(500) end

    while true do
        Wait(1000)
        local playerCoords = Corex.Functions.GetCoords()

        for i = #activeZombies, 1, -1 do
            local zombieData = activeZombies[i]

            if not DoesEntityExist(zombieData.entity) then
                CleanupZombie(i)
                goto continue
            end

            local zombieCoords = GetEntityCoords(zombieData.entity)

            if not zombieData.sharedId and IsNearSafeZone(zombieCoords) then
                CleanupZombie(i)
                goto continue
            end

            if not zombieData.sharedId and GetDistance(zombieCoords, playerCoords) > (Config.DespawnDistance or 120.0) then
                CleanupZombie(i)
                goto continue
            end

            if IsPedDeadOrDying(zombieData.entity, true) then
                if not zombieData.isDead then
                    zombieData.isDead = true
                    zombieData.deathTime = GetGameTimer()
                    StopSpecialParticle(zombieData)
                    DropLoot(zombieCoords, zombieData.id)
                    if zombieData.sharedId and zombieData.sharedBatchId then
                        TriggerServerEvent('corex-zombies:server:sharedZombieDied', zombieData.sharedBatchId, zombieData.sharedId)
                    end
                    TriggerEvent('corex:client:zombieKill')
                end

                if GetGameTimer() - zombieData.deathTime > Config.Cleanup.corpseLifetime then
                    CleanupZombie(i)
                end
            end

            ::continue::
        end
    end
end)

CreateThread(function()
    while not isReady do Wait(500) end

    while true do
        Wait(250)
        local grabConfig = GetGrabConfig()
        if not grabConfig.enabled then goto continue end

        if isGrabbed then
            if not DoesEntityExist(grabbingZombie) or IsPedDeadOrDying(grabbingZombie, true) then
                EndGrab(false)
            end
            goto continue
        end

        local playerCoords = Corex.Functions.GetCoords()
        for _, zombieData in ipairs(activeZombies) do
            if DoesEntityExist(zombieData.entity) and not IsPedDeadOrDying(zombieData.entity, true) then
                local zombieCoords = GetEntityCoords(zombieData.entity)
                local distance = GetDistance(zombieCoords, playerCoords)

                if distance <= grabConfig.grabDistance and CanGrabPlayer(zombieData.entity) then
                    if math.random() < grabConfig.grabChance then
                        StartGrab(zombieData.entity)
                        break
                    else
                        grabCooldown[zombieData.entity] = GetGameTimer() + 2000
                    end
                end
            end
        end

        ::continue::
    end
end)

CreateThread(function()
    while not isReady do Wait(500) end

    while true do
        -- Tight Wait(0) only when there is actually per-frame work
        -- (grab UI/input or toxic vignette). Otherwise sleep long.
        if isGrabbed or currentToxicExposure > 0 or renderedToxicExposure > 0.01 then
            Wait(0)
        else
            Wait(250)
        end

        if isGrabbed then
            if IsPedDeadOrDying(Corex.Functions.GetPed(), true) then
                EndGrab(false)
            else
                ProcessEscapeInput()
                ApplyGrabDamage()
                DrawEscapeUI()

                DisableControlAction(0, 21, true)
                DisableControlAction(0, 30, true)
                DisableControlAction(0, 31, true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 140, true)
                DisableControlAction(0, 141, true)
                DisableControlAction(0, 142, true)
            end
        end

        if currentToxicExposure > 0 or renderedToxicExposure > 0.01 then
            DrawToxicVignette()
        end
    end
end)

local function UpsertSharedSuppressionZone(batchId, data)
    if not batchId or not data or not data.center then
        return
    end

    sharedSuppressionZones[batchId] = {
        center = ToVector3(data.center),
        radius = tonumber(data.radius) or 120.0,
        eventId = data.eventId,
        hostSource = tonumber(data.hostSource) or nil,
    }
end

local function AttachExistingSharedZombie(sharedMeta)
    if not sharedMeta or not sharedMeta.netId then
        return false
    end

    local entity = NetToPed(sharedMeta.netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false
    end

    local existing = FindZombieDataBySharedId(sharedMeta.id) or FindZombieDataByEntity(entity)
    if existing then
        existing.sharedId = sharedMeta.id
        existing.sharedBatchId = sharedMeta.batchId
        existing.networkId = sharedMeta.netId
        existing.isSharedOwned = true
        return true
    end

    local typeData = GetZombieTypeDataById(sharedMeta.typeId) or GetZombieTypeDataById('walker')
    if not typeData then
        return false
    end

    local now = GetGameTimer()
    local coords = GetEntityCoords(entity)
    local attackDict, attackAnim = PickAttackAnim(typeData)
    local moanCfg = Config.Fear and Config.Fear.ambientMoan

    table.insert(activeZombies, {
        id = sharedMeta.id,
        entity = entity,
        typeData = typeData,
        spawnTime = now,
        coords = coords,
        isDead = IsPedDeadOrDying(entity, true),
        state = 'idle',
        lastAttack = 0,
        lastTaskUpdate = 0,
        lastBrainTick = 0,
        lastPosition = coords,
        lastPositionTime = now,
        stuckSince = 0,
        lastClimbAttempt = 0,
        chosenClipset = nil,
        chosenAttackDict = attackDict,
        chosenAttackAnim = attackAnim,
        lastSnarlAt = 0,
        nextMoanAt = moanCfg
            and (now + math.random(moanCfg.minInterval or 8000, moanCfg.maxInterval or 15000))
            or 0,
        scenarioActive = false,
        attackPhase = 'none',
        attackPhaseEnd = 0,
        damageApplied = false,
        damageApplyAt = 0,
        currentAnim = nil,
        currentDict = nil,
        isSpawning = false,
        spawnAnimEnd = 0,
        sharedId = sharedMeta.id,
        sharedBatchId = sharedMeta.batchId,
        isSharedOwned = true,
        networkId = sharedMeta.netId
    })

    return true
end

RegisterNetEvent('corex-zombies:client:sharedZoneStarted', function(batchId, data)
    UpsertSharedSuppressionZone(batchId, data)
end)

RegisterNetEvent('corex-zombies:client:sharedZoneStopped', function(batchId)
    sharedSuppressionZones[batchId] = nil
end)

RegisterNetEvent('corex-zombies:client:sharedZoneSnapshot', function(snapshot)
    local current = {}

    for _, zone in ipairs(snapshot or {}) do
        current[zone.id] = true
        UpsertSharedSuppressionZone(zone.id, zone)
    end

    for batchId in pairs(sharedSuppressionZones) do
        if not current[batchId] then
            sharedSuppressionZones[batchId] = nil
        end
    end
end)

RegisterNetEvent('corex-zombies:client:spawnSharedBatch', function(batchId, payload)
    UpsertSharedSuppressionZone(batchId, payload)

    local spawned = {}
    for _, entry in ipairs((payload and payload.zombies) or {}) do
        local coords = ToVector3(entry.coords)
        local typeData = GetZombieTypeDataById(entry.typeId)
        if coords and typeData and not FindZombieDataBySharedId(entry.id) then
            local zombie = SpawnZombie(coords, typeData, {
                forceNetworked = true,
                sharedId = entry.id,
                sharedBatchId = batchId,
            })

            if zombie and DoesEntityExist(zombie) then
                local netId = NetworkGetNetworkIdFromEntity(zombie)
                if netId and netId > 0 then
                    local zombieData = FindZombieDataBySharedId(entry.id)
                    if zombieData then
                        zombieData.networkId = netId
                    end

                    spawned[#spawned + 1] = {
                        id = entry.id,
                        netId = netId,
                        coords = SerializeCoords(GetEntityCoords(zombie)),
                    }
                end
            end

            Wait(50)
        end
    end

    TriggerServerEvent('corex-zombies:server:sharedBatchSpawned', batchId, spawned)
end)

RegisterNetEvent('corex-zombies:client:adoptSharedBatch', function(batchId, payload)
    UpsertSharedSuppressionZone(batchId, payload)

    CreateThread(function()
        local pending = {}
        for _, zombie in ipairs((payload and payload.zombies) or {}) do
            zombie.batchId = batchId
            pending[#pending + 1] = zombie
        end

        local deadline = GetGameTimer() + 15000
        while #pending > 0 and GetGameTimer() < deadline do
            for index = #pending, 1, -1 do
                if AttachExistingSharedZombie(pending[index]) then
                    table.remove(pending, index)
                end
            end

            if #pending > 0 then
                Wait(500)
            end
        end
    end)
end)

CreateThread(function()
    while not isReady do Wait(500) end

    while true do
        if Config.Sync and Config.Sync.Enabled then
            TriggerServerEvent('corex-zombies:server:requestSharedZoneSync')
        end

        Wait((Config.Sync and Config.Sync.SharedZoneSyncInterval) or 10000)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    if isGrabbed then EndGrab(false) end

    for i = #activeZombies, 1, -1 do
        CleanupZombie(i)
    end

    grabCooldown = {}
    sharedSuppressionZones = {}
    activeZombies = {}
end)

RegisterNetEvent('corex-zombies:client:forceSpawn', function(count, typeId)
    if source == 0 then return end
    count = math.max(1, math.min(tonumber(count) or 1, 10))

    local forcedType = nil
    if typeId and typeId ~= '' then
        for _, t in ipairs(Config.ZombieTypes) do
            if t.id == typeId then forcedType = t break end
        end
        if not forcedType then
            print('^1[COREX-ZOMBIES] Unknown zombie type: ' .. tostring(typeId) .. '^0')
        end
    end

    local spawned = 0
    for _ = 1, count do
        if SpawnZombie(nil, forcedType) then
            spawned = spawned + 1
        end
    end

    print(('^2[COREX-ZOMBIES] forceSpawn: requested %d %s, succeeded %d^0'):format(
        count, typeId or 'random', spawned))
end)

function GetActiveZombies()
    return activeZombies
end

function GetZombieCount()
    return #activeZombies
end

exports('GetActiveZombies', GetActiveZombies)
exports('GetZombieCount', GetZombieCount)
exports('SpawnZombie', SpawnZombie)
exports('IsPlayerGrabbed', function() return isGrabbed end)
exports('ForceEndGrab', function() EndGrab(true) end)
