ZX = ZX or {}
ZX.Spawn = {}

local territoryState = {}
local lastSoundTime = 0
local lastMigrationTime = 0
local migrationPositions = nil
local weaponCategoryMap = {}
local IsSafe

local DUMPSTER_MODELS = {
    'prop_dumpster_01a',
    'prop_dumpster_02a',
    'prop_dumpster_03a',
    'prop_dumpster_04a',
}

local function Dist2D(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function Dist3(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function Shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

local function GroundZ(x, y, refZ)
    local baseZ = refZ or 0.0
    local probes = { 25.0, 50.0, 100.0, 250.0, 500.0 }

    for _, offset in ipairs(probes) do
        local found, z = GetGroundZFor_3dCoord(x, y, baseZ + offset, false)
        if found then
            return z
        end
    end

    return nil
end

local function WaterHeight(x, y, z)
    local ok, found, waterZ = pcall(GetWaterHeightNoWaves, x, y, z)
    if ok and found then
        return waterZ
    end

    ok, found, waterZ = pcall(GetWaterHeight, x, y, z)
    if ok and found then
        return waterZ
    end

    return nil
end

local function IsUnderwaterGround(groundZ, waterZ)
    if not waterZ then
        return false
    end

    return (groundZ + 1.25) < waterZ
end

function ZX.Spawn.ValidateSpawnPosition(coords, options)
    options = options or {}

    if not coords then
        return nil
    end

    local playerCoords = options.playerCoords
    if not playerCoords and not options.skipDistanceCheck and Corex and Corex.Functions then
        playerCoords = Corex.Functions.GetCoords()
    end

    if playerCoords and not options.skipDistanceCheck then
        local dist = Dist3(coords, playerCoords)
        local minDist = options.minDistance or (Config.Spawning and Config.Spawning.minDistance) or 30.0
        local maxDist = options.maxDistance or (Config.Spawning and Config.Spawning.maxDistance) or 120.0

        if dist < minDist or dist > maxDist then
            return nil
        end
    end

    local groundZ = GroundZ(coords.x, coords.y, coords.z)
    if not groundZ then
        return nil
    end

    if IsUnderwaterGround(groundZ, WaterHeight(coords.x, coords.y, groundZ + 1.0)) then
        return nil
    end

    local safeCoords, outPosition = GetSafeCoordForPed(coords.x, coords.y, groundZ + 1.0, false, 16)
    if not safeCoords or not outPosition then
        return nil
    end

    local candidate = vector3(outPosition.x, outPosition.y, outPosition.z)
    local resolvedGround = GroundZ(candidate.x, candidate.y, candidate.z)
    if not resolvedGround then
        return nil
    end

    if IsUnderwaterGround(resolvedGround, WaterHeight(candidate.x, candidate.y, resolvedGround + 1.0)) then
        return nil
    end

    if math.abs(candidate.z - resolvedGround) > 2.5 then
        return nil
    end

    local finalPos = vector3(candidate.x, candidate.y, resolvedGround + 0.03)

    if IsSafe(finalPos) then
        return nil
    end

    if options.requireOffRoad and IsPointOnRoad(finalPos.x, finalPos.y, finalPos.z, 0) then
        return nil
    end

    return finalPos
end

IsSafe = function(coords)
    if IsNearSafeZone then
        return IsNearSafeZone(coords)
    end
    return false
end

local function InitWeaponMap()
    local defs = {
        pistol = {
            'WEAPON_PISTOL', 'WEAPON_COMBATPISTOL', 'WEAPON_APPISTOL',
            'WEAPON_PISTOL50', 'WEAPON_SNSPISTOL', 'WEAPON_HEAVYPISTOL',
            'WEAPON_VINTAGEPISTOL', 'WEAPON_MARKSMANPISTOL', 'WEAPON_MACHINEPISTOL',
            'WEAPON_REVOLVER', 'WEAPON_DOUBLEACTION', 'WEAPON_CERAMICPISTOL',
            'WEAPON_PISTOL_MK2', 'WEAPON_REVOLVER_MK2', 'WEAPON_NAVYREVOLVER',
            'WEAPON_GADGETPISTOL', 'WEAPON_TECPISTOL',
        },
        smg = {
            'WEAPON_MICROSMG', 'WEAPON_SMG', 'WEAPON_ASSAULTSMG',
            'WEAPON_MINISMG', 'WEAPON_SMG_MK2', 'WEAPON_COMBATPDW',
            'WEAPON_MG', 'WEAPON_COMBATMG', 'WEAPON_GUSENBERG',
            'WEAPON_COMBATMG_MK2',
        },
        rifle = {
            'WEAPON_RIFLE', 'WEAPON_ASSAULTRIFLE', 'WEAPON_CARBINERIFLE',
            'WEAPON_ADVANCEDRIFLE', 'WEAPON_SPECIALCARBINE', 'WEAPON_BULLPUPRIFLE',
            'WEAPON_COMPACTRIFLE', 'WEAPON_MILITARYRIFLE',
            'WEAPON_ASSAULTRIFLE_MK2', 'WEAPON_CARBINERIFLE_MK2',
            'WEAPON_SPECIALCARBINE_MK2', 'WEAPON_BULLPUPRIFLE_MK2',
        },
        shotgun = {
            'WEAPON_PUMPSHOTGUN', 'WEAPON_SAWNOFFSHOTGUN', 'WEAPON_ASSAULTSHOTGUN',
            'WEAPON_BULLPUPSHOTGUN', 'WEAPON_AUTOSHOTGUN', 'WEAPON_DBSHOTGUN',
            'WEAPON_COMBATSHOTGUN', 'WEAPON_PUMPSHOTGUN_MK2',
            'WEAPON_SWEEPERSHOTGUN', 'WEAPON_MUSKET',
        },
        sniper = {
            'WEAPON_SNIPERRIFLE', 'WEAPON_HEAVYSNIPER', 'WEAPON_MARKSMANRIFLE',
            'WEAPON_HEAVYSNIPER_MK2', 'WEAPON_MARKSMANRIFLE_MK2',
        },
        explosive = {
            'WEAPON_GRENADELAUNCHER', 'WEAPON_RPG', 'WEAPON_HOMINGLAUNCHER',
            'WEAPON_MINIGUN', 'WEAPON_GRENADE', 'WEAPON_STICKYBOMB',
            'WEAPON_PIPEBOMB', 'WEAPON_MOLOTOV', 'WEAPON_PROXMINE',
            'WEAPON_RAILGUN', 'WEAPON_FIREWORK',
        },
    }
    for cat, list in pairs(defs) do
        for _, name in ipairs(list) do
            weaponCategoryMap[GetHashKey(name)] = cat
        end
    end
end

local function GetWeaponSoundRange(weaponHash)
    local cfg = Config.RPSpawning and Config.RPSpawning.soundAttraction
    if not cfg or not cfg.categories then return 0 end
    local cats = cfg.categories

    local cat = weaponCategoryMap[weaponHash]
    if cat then return cats[cat] or 50.0 end

    local dmg = GetWeaponDamageType(weaponHash)
    if dmg == 3 or dmg == 4 then return cats.explosive or 120.0 end
    if dmg == 0 or dmg == 5 then return cats.melee or 10.0 end

    return cats.rifle or 60.0
end

function ZX.Spawn.InitTerritories()
    local cfg = Config.RPSpawning
    if not cfg or not cfg.territories then return end
    for _, t in ipairs(cfg.territories) do
        if t.center and t.radius then
            territoryState[#territoryState + 1] = {
                name       = t.name or 'Unknown',
                center     = t.center,
                radius     = t.radius,
                maxZombies = t.maxZombies or 10,
            }
        end
    end
    if Config.Debug and #territoryState > 0 then
        print(('^2[COREX-ZOMBIES] Loaded %d zombie territories^0'):format(#territoryState))
    end
end

local function CountInTerritory(territory)
    local n = 0
    local r2 = territory.radius * territory.radius
    for _, z in ipairs(activeZombies or {}) do
        if not z.isDead and DoesEntityExist(z.entity) then
            local zc = GetEntityCoords(z.entity)
            local dx = zc.x - territory.center.x
            local dy = zc.y - territory.center.y
            if (dx * dx + dy * dy) <= r2 then n = n + 1 end
        end
    end
    return n
end

local function GetNearbyTerritory(coords)
    local best, bestD = nil, 999999.0
    for _, t in ipairs(territoryState) do
        local d = Dist2D(coords, t.center)
        if d < t.radius + 50.0 and d < bestD then
            best, bestD = t, d
        end
    end
    return best
end

local function TerritorySpawnPos(territory)
    for _ = 1, 20 do
        local a = math.random() * 2 * math.pi
        local d = math.random() * territory.radius
        local x = territory.center.x + math.cos(a) * d
        local y = territory.center.y + math.sin(a) * d
        local pos = ZX.Spawn.ValidateSpawnPosition(vector3(x, y, territory.center.z), {
            requireOffRoad = false
        })
        if pos then return pos end
    end
    return nil
end

local function FindSpawnNearVehicle(coords, radius)
    local veh = GetClosestVehicle(coords.x, coords.y, coords.z, radius, 0, 70)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    if GetEntitySpeed(veh) > 1.0 then return nil end

    local vc = GetEntityCoords(veh)
    local bk = GetEntityForwardVector(veh) * -1
    local sx = vc.x + bk.x * 3.0
    local sy = vc.y + bk.y * 3.0
    local pos = ZX.Spawn.ValidateSpawnPosition(vector3(sx, sy, vc.z), {
        requireOffRoad = false
    })
    if pos then return pos, 'vehicle' end
    return nil
end

local function FindSpawnNearDumpster(coords, radius)
    for _, modelName in ipairs(DUMPSTER_MODELS) do
        local h = GetHashKey(modelName)
        local obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, radius, h, false, false, false)
        if obj and obj ~= 0 and DoesEntityExist(obj) then
            local oc = GetEntityCoords(obj)
            local pos = ZX.Spawn.ValidateSpawnPosition(vector3(oc.x, oc.y, oc.z), {
                requireOffRoad = false
            })
            if pos then return pos, 'dumpster' end
        end
    end
    return nil
end

local function FindSpawnNearBuilding(coords, radius)
    for _ = 1, 6 do
        local a = math.random() * 2 * math.pi
        local d = math.random(10, radius)
        local tx = coords.x + math.cos(a) * d
        local ty = coords.y + math.sin(a) * d
        local tz = GroundZ(tx, ty, coords.z)
        if not tz then goto continue end

        local sideA = a + (math.random() > 0.5 and math.pi / 2 or -math.pi / 2)
        local px = tx + math.cos(sideA) * 4.0
        local py = ty + math.sin(sideA) * 4.0
        local handle = StartShapeTestRay(
            tx, ty, tz + 1.0,
            px, py, tz + 1.0,
            1, 0, 4
        )
        local _, hit, _, _, _ = GetShapeTestResult(handle)
        if hit then
            local pos = ZX.Spawn.ValidateSpawnPosition(vector3(px, py, tz), {
                requireOffRoad = false
            })
            if pos then return pos, 'building' end
        end
        ::continue::
    end
    return nil
end

function ZX.Spawn.FindEnvironmentalSpawn(playerCoords)
    local cfg = Config.RPSpawning and Config.RPSpawning.environmentalSpawn
    if not cfg or not cfg.enabled then return nil end

    local options = {}
    if cfg.cars and cfg.cars.enabled then
        options[#options + 1] = { fn = FindSpawnNearVehicle, r = cfg.cars.searchRadius or 50.0 }
    end
    if cfg.dumpsters and cfg.dumpsters.enabled then
        options[#options + 1] = { fn = FindSpawnNearDumpster, r = cfg.dumpsters.searchRadius or 40.0 }
    end
    if cfg.buildings and cfg.buildings.enabled then
        options[#options + 1] = { fn = FindSpawnNearBuilding, r = cfg.buildings.searchRadius or 50.0 }
    end
    if #options == 0 then return nil end

    Shuffle(options)
    for _, opt in ipairs(options) do
        local pos, kind = opt.fn(playerCoords, opt.r)
        if pos then
            if Config.Debug then
                print(('^5[COREX-ZOMBIES] Environmental spawn: %s at %.0f,%.0f^0'):format(kind, pos.x, pos.y))
            end
            return pos
        end
    end
    return nil
end

function ZX.Spawn.DetectSounds()
    local cfg = Config.RPSpawning and Config.RPSpawning.soundAttraction
    if not cfg or not cfg.enabled then return end

    if not Corex then return end
    local ped = Corex.Functions.GetPed()
    if not IsPedShooting(ped) then return end

    local now = GetGameTimer()
    if now - lastSoundTime < (cfg.throttleMs or 500) then return end
    lastSoundTime = now

    local weapon = GetSelectedPedWeapon(ped)
    local range = GetWeaponSoundRange(weapon)
    if range <= 0 then return end

    local coords = GetEntityCoords(ped)
    ZX.Spawn.BroadcastSound(coords, range)
end

function ZX.Spawn.BroadcastSound(soundCoords, range)
    if Config.Debug then
        print(('^5[COREX-ZOMBIES] Sound: %.0f,%.0f range=%.0fm^0'):format(
            soundCoords.x, soundCoords.y, range))
    end

    local r2 = range * range
    for _, zd in ipairs(activeZombies or {}) do
        if not zd.isDead and zd.state == 'idle_scenario' and DoesEntityExist(zd.entity) then
            if not IsPedDeadOrDying(zd.entity, true) then
                local zc = GetEntityCoords(zd.entity)
                local dx = zc.x - soundCoords.x
                local dy = zc.y - soundCoords.y
                local dz = zc.z - soundCoords.z
                if (dx * dx + dy * dy + dz * dz) <= r2 then
                    zd.scenarioActive = false
                    ClearPedTasks(zd.entity)
                    zd.state = 'idle'
                    if ZX.Horde then ZX.Horde.Broadcast(soundCoords) end
                end
            end
        end
    end
end

function ZX.Spawn.TickMigration(playerCoords, now)
    local cfg = Config.RPSpawning and Config.RPSpawning.hordeMigration
    if not cfg or not cfg.enabled then return end
    if now - lastMigrationTime < (cfg.interval or 120000) then return end
    lastMigrationTime = now

    local minS = cfg.groupSize and cfg.groupSize.min or 4
    local maxS = cfg.groupSize and cfg.groupSize.max or 8
    local size = math.random(minS, maxS)

    local angle = math.random() * 2 * math.pi
    local sx = playerCoords.x + math.cos(angle) * 120.0
    local sy = playerCoords.y + math.sin(angle) * 120.0
    local spawnPos = ZX.Spawn.ValidateSpawnPosition(vector3(sx, sy, playerCoords.z), {
        minDistance = (Config.Spawning and Config.Spawning.minDistance) or 30.0,
        maxDistance = math.max((Config.Spawning and Config.Spawning.maxDistance) or 120.0, 120.0),
        requireOffRoad = false
    })
    if not spawnPos then return end

    local tx = playerCoords.x + math.cos(angle) * 250.0
    local ty = playerCoords.y + math.sin(angle) * 250.0
    local tz = GroundZ(tx, ty, playerCoords.z)
    if not tz then return end

    if Config.Debug then
        print(('^5[COREX-ZOMBIES] Horde: %d zombies %.0f,%.0f -> %.0f,%.0f^0'):format(
            size, sx, sy, tx, ty))
    end

    local positions = {}
    for _ = 1, size do
        local ox = spawnPos.x + math.random(-5, 5)
        local oy = spawnPos.y + math.random(-5, 5)
        local pos = ZX.Spawn.ValidateSpawnPosition(vector3(ox, oy, spawnPos.z), {
            skipDistanceCheck = true,
            requireOffRoad = false
        })
        if pos then
            positions[#positions + 1] = { coords = pos, target = vector3(tx, ty, tz) }
        end
    end

    migrationPositions = positions
end

function ZX.Spawn.GetMigrationPositions()
    local pos = migrationPositions
    migrationPositions = nil
    return pos
end

function ZX.Spawn.GetNextSpawnPosition(playerCoords)
    local cfg = Config.RPSpawning
    if not cfg or not cfg.enabled then return nil end

    if cfg.environmentalSpawn and cfg.environmentalSpawn.enabled then
        if math.random() < (cfg.environmentalSpawn.chance or 0.6) then
            local pos = ZX.Spawn.FindEnvironmentalSpawn(playerCoords)
            if pos then return pos end
        end
    end

    if #territoryState > 0 then
        local territory = GetNearbyTerritory(playerCoords)
        if territory then
            local count = CountInTerritory(territory)
            if count < territory.maxZombies then
                local pos = TerritorySpawnPos(territory)
                if pos then return pos end
            end
        end
    end

    return nil
end

function ZX.Spawn.Init()
    InitWeaponMap()
    ZX.Spawn.InitTerritories()
    lastMigrationTime = GetGameTimer()
    if Config.Debug then
        print('^2[COREX-ZOMBIES] RP Spawn system initialized^0')
    end
end

CreateThread(function()
    while not Corex or not Corex.Functions do Wait(500) end
    ZX.Spawn.Init()
end)
