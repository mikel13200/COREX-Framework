local Corex = nil
local isReady = false
local manifest = nil
local currentZone = nil
local spawnedBlips = {}
local crateProps = {}
local bigBoxProps = {}
local spawnHostZones = {}
local activeSpawnedZombies = {}

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
    TriggerServerEvent('corex-redzones:server:searchCrate', data.crateId)
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

local function FindZoneByCoords(coords)
    if not manifest then return nil end
    local cx, cy, cz = coords.x, coords.y, coords.z
    for _, zone in ipairs(manifest) do
        local dx = cx - zone.coords.x
        local dy = cy - zone.coords.y
        local dz = cz - zone.coords.z
        if dx * dx + dy * dy + dz * dz <= zone.radius * zone.radius then
            return zone
        end
    end
    return nil
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
    for _, zone in ipairs(manifest) do
        for _, crate in ipairs(zone.crates) do
            local prop = Corex.Functions.SpawnProp(Config.CrateModel, crate.coords, {
                placeOnGround = true,
                networked = false,
                freeze = true
            })
            if prop then
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
                crateProps[#crateProps + 1] = {
                    prop = prop,
                    crateId = crate.crateId
                }
            else
                Debug('Warn', 'Failed to spawn crate prop at ' .. crate.crateId)
            end
        end

        if zone.bigBox and Config.BigLootBox then
            local box = Corex.Functions.SpawnProp(Config.BigLootBox.model, zone.bigBox.coords, {
                placeOnGround = true,
                networked = false,
                freeze = true
            })
            if box then
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
                bigBoxProps[#bigBoxProps + 1] = {
                    prop = box,
                    crateId = boxId
                }
                Debug('Info', 'Big loot box spawned at ' .. zone.id .. ' (' .. boxId .. ')')
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
    currentZone = zone
    RedZoneEffects.Enter(zone.name)
    TriggerServerEvent('corex-redzones:server:enteredZone', zone.id)
    Corex.Functions.Notify('Entered Red Zone: ' .. zone.name, 'error', 5000)
    Debug('Info', 'Entered zone: ' .. zone.id)
end

local function LeaveZone()
    if not currentZone then return end
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
            local zone = FindZoneByCoords(coords)
            if zone and (not currentZone or currentZone.id ~= zone.id) then
                if currentZone then LeaveZone() end
                EnterZone(zone)
            elseif not zone and currentZone then
                LeaveZone()
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

    for _, entry in ipairs(crateProps) do
        if entry.prop and DoesEntityExist(entry.prop) then
            pcall(function() exports['corex-core']:RemoveTarget(entry.prop) end)
            if Corex then pcall(function() Corex.Functions.DeleteProp(entry.prop) end) end
        end
    end
    crateProps = {}

    for _, entry in ipairs(bigBoxProps) do
        if entry.prop and DoesEntityExist(entry.prop) then
            pcall(function() exports['corex-core']:RemoveTarget(entry.prop) end)
            if Corex then pcall(function() Corex.Functions.DeleteProp(entry.prop) end) end
        end
    end
    bigBoxProps = {}

    if RedZoneEffects then RedZoneEffects.ForceClear() end
end)
