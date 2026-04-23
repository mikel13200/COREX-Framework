local Corex = nil
local isReady = false
local manifest = nil
local currentZone = nil
local spawnedBlips = {}
local crateProps = {}
local bigBoxProps = {}
local crateEntriesById = {}
local spawnHostZones = {}
local activeSpawnedZombies = {}
local ZONE_EXIT_BUFFER = 5.0
local FLARE_DRAW_DISTANCE = Config.FlareDrawDistance or 220.0
local FLARE_RESTART_INTERVAL = Config.FlareRestartInterval or 2500
local CRATE_GROUND_SNAP_DISTANCE = Config.CrateGroundSnapDistance or 350.0
local CRATE_GROUND_RESNAP_MS = Config.CrateGroundResnapMs or 2000
local ZONE_EXIT_GRACE_MS = Config.ZoneExitGraceMs or 2500
local zoneExitStartedAt = nil

local function Debug(level, msg)
    if not Config.Debug and level ~= 'Error' then return end
    local colors = { Error = '^1', Warn = '^3', Info = '^2', Verbose = '^5' }
    print((colors[level] or '^7') .. '[COREX-REDZONES] ' .. msg .. '^0')
end

local function InitCorex()
    local attempts = 0
    while not Corex and attempts < 60 do
        local ok, result = pcall(function()
            return exports['corex-core']:GetCoreObject()
        end)
        if ok and result then
            Corex = result
            Debug('Info', 'Core object acquired')
            return true
        end
        attempts = attempts + 1
        Wait(1000)
    end
    Debug('Error', 'Failed to acquire core object after 60 attempts')
    return false
end

local function OnSearchCrate(entity, data)
    if not Corex then return end
    if Corex.Functions.IsDead(Corex.Functions.GetPed()) then return end
    if not data or type(data.crateId) ~= 'string' then return end
    TriggerServerEvent('corex-loot:server:requestContainer', data.crateId)
end

RegisterNetEvent('corex-redzones:client:searchCrate', function(entity, data)
    OnSearchCrate(entity, data)
end)

local function CreateBlipsFromManifest()
    for _, blip in ipairs(spawnedBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    spawnedBlips = {}

    if not manifest then return end

    for _, zone in ipairs(manifest) do
        local centerBlip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
        SetBlipSprite(centerBlip, Config.Blip.centerSprite)
        SetBlipScale(centerBlip, Config.Blip.centerScale)
        SetBlipColour(centerBlip, Config.Blip.centerColor)
        SetBlipAsShortRange(centerBlip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.Blip.labelPrefix .. zone.name)
        EndTextCommandSetBlipName(centerBlip)
        spawnedBlips[#spawnedBlips + 1] = centerBlip

        local radiusBlip = AddBlipForRadius(zone.coords.x, zone.coords.y, zone.coords.z, zone.radius)
        SetBlipColour(radiusBlip, Config.Blip.radiusColor)
        SetBlipAlpha(radiusBlip, Config.Blip.radiusAlpha)
        spawnedBlips[#spawnedBlips + 1] = radiusBlip
    end

    Debug('Info', 'Created ' .. #spawnedBlips .. ' blips for ' .. #manifest .. ' zones')
end

local function IsCoordsInZone(coords, zone, extraRadius)
    if not coords or not zone or not zone.coords or not zone.radius then return false end
    local radius = (tonumber(zone.radius) or 0.0) + (extraRadius or 0.0)
    if radius <= 0.0 then return false end

    local cx, cy = coords.x, coords.y
    local dx = cx - zone.coords.x
    local dy = cy - zone.coords.y
    return dx * dx + dy * dy <= radius * radius
end

local function FindZoneByCoords(coords, extraRadius)
    if not manifest then return nil end
    for _, zone in ipairs(manifest) do
        if IsCoordsInZone(coords, zone, extraRadius) then
            return zone
        end
    end
    return nil
end

local function LoadNamedPtfx(asset, timeoutMs)
    if HasNamedPtfxAssetLoaded(asset) then
        return true
    end

    RequestNamedPtfxAsset(asset)
    local startedAt = GetGameTimer()
    while not HasNamedPtfxAssetLoaded(asset) do
        Wait(10)
        if GetGameTimer() - startedAt > (timeoutMs or 3000) then
            return false
        end
    end

    return true
end

local function ResolveGroundZ(x, y, zGuess)
    local base = zGuess or 0.0
    local probes = {
        base + 5.0,
        base + 25.0,
        base + 50.0,
        base + 100.0,
        base + 250.0,
        1000.0,
    }

    for _, probe in ipairs(probes) do
        local found, groundZ = GetGroundZFor_3dCoord(x, y, probe, false)
        if found then
            return groundZ, true
        end
    end

    return nil, false
end

local function SnapPropToGround(prop, targetCoords, maxAttempts)
    if not prop or not DoesEntityExist(prop) or not targetCoords then
        return nil
    end

    local groundZ = nil
    for _ = 1, (maxAttempts or 12) do
        RequestCollisionAtCoord(targetCoords.x, targetCoords.y, targetCoords.z)
        groundZ = ResolveGroundZ(targetCoords.x, targetCoords.y, targetCoords.z)
        if groundZ then break end
        Wait(75)
    end

    if not groundZ then
        return nil
    end

    local minDim = vector3(0.0, 0.0, 0.0)
    local ok, modelMin = pcall(function()
        local mn = GetModelDimensions(GetEntityModel(prop))
        return mn
    end)
    if ok and modelMin then
        minDim = modelMin
    end

    local baseOffset = math.max(0.0, -(minDim.z or 0.0))
    local z = groundZ + baseOffset + 0.02

    FreezeEntityPosition(prop, false)
    SetEntityCollision(prop, true, true)

    for _ = 1, 8 do
        RequestCollisionAtCoord(targetCoords.x, targetCoords.y, z)
        SetEntityCoordsNoOffset(prop, targetCoords.x, targetCoords.y, z, false, false, false)
        PlaceObjectOnGroundProperly(prop)
        Wait(50)
    end

    FreezeEntityPosition(prop, true)
    local finalCoords = GetEntityCoords(prop)
    return vector3(finalCoords.x, finalCoords.y, finalCoords.z)
end

local function StartCrateFlare(coords)
    if not coords then return nil end

    local effects = {
        { asset = 'core', name = 'exp_grd_flare', scale = 1.35 },
        { asset = 'scr_rcbarry2', name = 'scr_clown_appears', scale = 1.8 },
    }

    for _, effect in ipairs(effects) do
        if LoadNamedPtfx(effect.asset) then
            UseParticleFxAssetNextCall(effect.asset)
            local handle = StartParticleFxLoopedAtCoord(
                effect.name,
                coords.x,
                coords.y,
                coords.z + 0.35,
                0.0,
                0.0,
                0.0,
                effect.scale,
                false,
                false,
                false,
                false
            )

            if handle and handle ~= 0 then
                return handle
            end
        end
    end

    return nil
end

local function StopCrateFlare(entry)
    if entry and entry.ptfx then
        StopParticleFxLooped(entry.ptfx, false)
        entry.ptfx = nil
    end
    if entry then
        entry.nextFlareRestartAt = nil
    end
end

local function EnsureCrateGrounded(entry, playerCoords)
    if not entry or not entry.prop or not DoesEntityExist(entry.prop) then return end
    local sourceCoords = entry.sourceCoords or entry.coords
    if not sourceCoords or not playerCoords then return end

    local dx = sourceCoords.x - playerCoords.x
    local dy = sourceCoords.y - playerCoords.y
    local dz = sourceCoords.z - playerCoords.z
    local maxDist = CRATE_GROUND_SNAP_DISTANCE
    if dx * dx + dy * dy + dz * dz > maxDist * maxDist then
        return
    end

    local now = GetGameTimer()
    if entry.groundSnapped and now < (entry.nextGroundCheckAt or 0) then
        return
    end
    if not entry.groundSnapped and now < (entry.nextGroundRetryAt or 0) then
        return
    end

    local placedCoords = SnapPropToGround(entry.prop, sourceCoords)
    if placedCoords then
        entry.coords = placedCoords
        entry.groundSnapped = true
        entry.nextGroundCheckAt = now + 30000
    else
        entry.groundSnapped = false
        entry.nextGroundRetryAt = now + CRATE_GROUND_RESNAP_MS
    end
end

local function UpdateCrateFlare(entry, playerCoords)
    if not entry then return end
    if not entry.hasLoot then
        StopCrateFlare(entry)
        return
    end

    local coords = entry.coords
    if entry.prop and DoesEntityExist(entry.prop) then
        coords = GetEntityCoords(entry.prop)
    end
    if not coords or not playerCoords then
        StopCrateFlare(entry)
        return
    end

    local dx = coords.x - playerCoords.x
    local dy = coords.y - playerCoords.y
    local dz = coords.z - playerCoords.z
    local maxDist = FLARE_DRAW_DISTANCE

    if dx * dx + dy * dy + dz * dz <= maxDist * maxDist then
        local now = GetGameTimer()
        if not entry.ptfx or now >= (entry.nextFlareRestartAt or 0) then
            StopCrateFlare(entry)
            entry.ptfx = StartCrateFlare(coords)
            entry.nextFlareRestartAt = now + FLARE_RESTART_INTERVAL
        end
    else
        StopCrateFlare(entry)
    end
end

local function SetCrateLootState(crateId, hasLoot)
    local entry = crateEntriesById[crateId]
    if not entry then return end

    entry.hasLoot = hasLoot == true
    if not entry.hasLoot then
        StopCrateFlare(entry)
    else
        entry.nextFlareRestartAt = nil
    end
end

local function CleanupCrateEntry(entry)
    if not entry then return end

    StopCrateFlare(entry)

    if entry.prop and DoesEntityExist(entry.prop) then
        pcall(function() exports['corex-core']:RemoveTarget(entry.prop) end)
        if Corex then
            pcall(function() Corex.Functions.DeleteProp(entry.prop) end)
        end
    end

    if entry.crateId then
        crateEntriesById[entry.crateId] = nil
    end
end

local function ClearCrateProps()
    for _, entry in ipairs(crateProps) do
        CleanupCrateEntry(entry)
    end
    crateProps = {}

    for _, entry in ipairs(bigBoxProps) do
        CleanupCrateEntry(entry)
    end
    bigBoxProps = {}

    crateEntriesById = {}
end

local function PickStrongZombieType()
    local types = Config.StrongZombieTypes
    if not types or #types == 0 then return nil end
    local totalWeight = 0
    for _, t in ipairs(types) do
        totalWeight = totalWeight + (t.weight or 1)
    end
    local roll = math.random() * totalWeight
    local cum = 0
    for _, t in ipairs(types) do
        cum = cum + (t.weight or 1)
        if roll <= cum then return t end
    end
    return types[#types]
end

local function SpawnCrateProps()
    if not manifest then return end
    ClearCrateProps()

    for _, zone in ipairs(manifest) do
        for _, crate in ipairs(zone.crates) do
            local prop = Corex.Functions.SpawnProp(Config.CrateModel, crate.coords, {
                placeOnGround = false,
                networked = false,
                freeze = false
            })
            if prop then
                local placedCoords = SnapPropToGround(prop, crate.coords, 1) or crate.coords
                local ok = pcall(function()
                    exports['corex-core']:AddTarget(prop, {
                        text = '[E] Search Military Crate',
                        icon = 'fa-briefcase-medical',
                        distance = Config.CrateInteractDistance,
                        event = 'corex-redzones:client:searchCrate',
                        data = { crateId = crate.crateId }
                    })
                end)
                if not ok then
                    Debug('Warn', 'AddTarget failed for crate ' .. crate.crateId)
                end
                local entry = {
                    prop = prop,
                    crateId = crate.crateId,
                    sourceCoords = crate.coords,
                    coords = placedCoords,
                    hasLoot = crate.hasLoot ~= false,
                    groundSnapped = placedCoords ~= nil
                }
                crateProps[#crateProps + 1] = entry
                crateEntriesById[crate.crateId] = entry
                SetCrateLootState(crate.crateId, entry.hasLoot)
            else
                Debug('Warn', 'Failed to spawn crate prop at ' .. crate.crateId)
            end
        end

        if zone.bigBox and Config.BigLootBox then
            local box = Corex.Functions.SpawnProp(Config.BigLootBox.model, zone.bigBox.coords, {
                placeOnGround = false,
                networked = false,
                freeze = false
            })
            if box then
                local placedCoords = SnapPropToGround(box, zone.bigBox.coords, 1) or zone.bigBox.coords
                local boxId = zone.bigBox.crateId
                pcall(function()
                    exports['corex-core']:AddTarget(box, {
                        text = '[E] Open Big Loot Box',
                        icon = 'fa-box-open',
                        distance = Config.CrateInteractDistance + 0.5,
                        event = 'corex-redzones:client:searchCrate',
                        data = { crateId = boxId }
                    })
                end)
                local entry = {
                    prop = box,
                    crateId = boxId,
                    sourceCoords = zone.bigBox.coords,
                    coords = placedCoords,
                    hasLoot = zone.bigBox.hasLoot ~= false,
                    groundSnapped = placedCoords ~= nil
                }
                bigBoxProps[#bigBoxProps + 1] = entry
                crateEntriesById[boxId] = entry
                SetCrateLootState(boxId, entry.hasLoot)
                Debug('Info', 'Big loot box spawned at ' .. zone.id .. ' (' .. boxId .. ')')
            else
                Debug('Warn', 'Failed to spawn big loot box at ' .. zone.id)
            end
        end
    end
    Debug('Info', ('Spawned %d crate props, %d big boxes'):format(#crateProps, #bigBoxProps))
end

local function CountLivingHostedZombies()
    local count = 0
    for i = #activeSpawnedZombies, 1, -1 do
        local z = activeSpawnedZombies[i]
        if not z or not DoesEntityExist(z) or IsEntityDead(z) then
            table.remove(activeSpawnedZombies, i)
        else
            count = count + 1
        end
    end
    return count
end

local function GetRandomSpawnCoordsInZone(zone)
    local angle = math.random() * math.pi * 2
    local dist = math.random() * (Config.ZombieDensity.spawnRingMax - Config.ZombieDensity.spawnRingMin)
        + Config.ZombieDensity.spawnRingMin
    local x = zone.coords.x + math.cos(angle) * dist
    local y = zone.coords.y + math.sin(angle) * dist
    local found, z = GetGroundZFor_3dCoord(x, y, (zone.coords.z or 0) + 50.0, false)
    if not found then z = zone.coords.z end
    return vector3(x, y, z)
end

local GLOBAL_ZOMBIE_BUDGET = 30

local function HostSpawnTickForZone(zoneId)
    local zone
    for _, z in ipairs(manifest or {}) do
        if z.id == zoneId then zone = z break end
    end
    if not zone then return end

    local living = CountLivingHostedZombies()
    if living >= Config.ZombieDensity.max then return end

    local globalCount = 0
    local ok, count = pcall(function()
        return exports['corex-zombies']:GetZombieCount()
    end)
    if ok and type(count) == 'number' then
        globalCount = count
    end

    local globalBudget = math.max(0, GLOBAL_ZOMBIE_BUDGET - globalCount)
    if globalBudget <= 0 then
        Debug('Verbose', ('Host tick: zone=%s budget exhausted (global=%d)'):format(zoneId, globalCount))
        return
    end

    local target = math.random(
        math.min(Config.ZombieDensity.min, globalBudget),
        math.min(Config.ZombieDensity.max, globalBudget)
    )
    local needed = target - living
    if needed <= 0 then return end

    local toSpawnThisTick = math.min(needed, 4, globalBudget)
    for _ = 1, toSpawnThisTick do
        local coords = GetRandomSpawnCoordsInZone(zone)
        local typeData = PickStrongZombieType()

        local ok, spawned = pcall(function()
            return exports['corex-zombies']:SpawnZombie(coords, typeData)
        end)
        if ok and spawned then
            activeSpawnedZombies[#activeSpawnedZombies + 1] = spawned
        end
        Wait(50)
    end

    if Config.Debug then
        Debug('Verbose', ('Host tick: zone=%s living=%d target=%d spawned=%d global=%d'):format(
            zoneId, living, target, toSpawnThisTick, globalCount))
    end
end

CreateThread(function()
    while true do
        Wait(Config.ZombieDensity.refillInterval)
        for zoneId, isHost in pairs(spawnHostZones) do
            if isHost and currentZone and currentZone.id == zoneId then
                HostSpawnTickForZone(zoneId)
            end
        end
    end
end)

local function CleanupHostedZombies()
    -- corex-zombies owns the peds we spawn via its export and handles cleanup
    -- via its DespawnDistance / corpse lifetime logic. We only drop our tracking
    -- references so the host tick doesn't double-count stale entries.
    activeSpawnedZombies = {}
end

local function ApplyHealthDrain()
    if not Corex then return end
    local health = Corex.Functions.GetHealth()
    if health <= 0 then return end
    local newHealth = math.max(1, health - Config.HealthDrain.amountPerTick)
    Corex.Functions.SetHealth(newHealth)
end

CreateThread(function()
    while true do
        Wait(Config.HealthDrain.tickInterval)
        if Config.HealthDrain.enabled and currentZone then
            ApplyHealthDrain()
        end
    end
end)

local function EnterZone(zone)
    zoneExitStartedAt = nil
    currentZone = zone
    RedZoneEffects.Enter(zone.name)
    TriggerServerEvent('corex-redzones:server:enteredZone', zone.id)
    Corex.Functions.Notify('Entered Red Zone: ' .. zone.name, 'error', 5000)
    Debug('Info', 'Entered zone: ' .. zone.id)
end

local function LeaveZone()
    if not currentZone then return end
    zoneExitStartedAt = nil
    local oldId = currentZone.id
    currentZone = nil
    RedZoneEffects.Exit()
    TriggerServerEvent('corex-redzones:server:leftZone')
    Corex.Functions.Notify('Left Red Zone', 'warning', 3000)
    spawnHostZones[oldId] = nil
    CleanupHostedZombies()
    Debug('Info', 'Left zone: ' .. oldId)
end

CreateThread(function()
    while not isReady do Wait(500) end
    while true do
        Wait(Config.CheckInterval)
        if manifest and Corex then
            local coords = Corex.Functions.GetCoords()
            local zone = nil

            if currentZone and IsCoordsInZone(coords, currentZone, ZONE_EXIT_BUFFER) then
                zone = currentZone
            else
                zone = FindZoneByCoords(coords, 0.0)
            end

            if zone then
                zoneExitStartedAt = nil
            end

            if zone and (not currentZone or currentZone.id ~= zone.id) then
                if currentZone then LeaveZone() end
                EnterZone(zone)
            elseif not zone and currentZone then
                local now = GetGameTimer()
                zoneExitStartedAt = zoneExitStartedAt or now
                if now - zoneExitStartedAt >= ZONE_EXIT_GRACE_MS then
                    LeaveZone()
                end
            end
        end
    end
end)

RegisterNetEvent('corex-redzones:client:manifest', function(data)
    manifest = data
    CreateBlipsFromManifest()
    SpawnCrateProps()
    Debug('Info', 'Manifest received and applied')
end)

RegisterNetEvent('corex-redzones:client:setSpawnHost', function(zoneId, isHost)
    spawnHostZones[zoneId] = isHost
    Debug('Verbose', ('Spawn host for %s: %s'):format(zoneId, tostring(isHost)))
end)

RegisterNetEvent('corex-redzones:client:setCrateLootState', function(crateId, hasLoot)
    SetCrateLootState(crateId, hasLoot)
end)

CreateThread(function()
    while true do
        if not next(crateEntriesById) then
            Wait(1500)
        else
            local ped = PlayerPedId()
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                local playerCoords = GetEntityCoords(ped)
                for _, entry in pairs(crateEntriesById) do
                    EnsureCrateGrounded(entry, playerCoords)
                    UpdateCrateFlare(entry, playerCoords)
                end
            end
            Wait(1000)
        end
    end
end)

CreateThread(function()
    Wait(500)
    if not InitCorex() then
        Debug('Error', 'Core init failed')
        return
    end
    Corex.Functions.WaitForPlayerData(15000)
    isReady = true
    TriggerServerEvent('corex-redzones:server:requestManifest')
    Debug('Info', 'Client ready — requested manifest')

    Wait(5000)
    if not manifest then
        Debug('Warn', 'Manifest not received — retrying')
        TriggerServerEvent('corex-redzones:server:requestManifest')
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    for _, blip in ipairs(spawnedBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    spawnedBlips = {}

    ClearCrateProps()

    if RedZoneEffects then RedZoneEffects.ForceClear() end
end)
