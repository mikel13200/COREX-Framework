if Config.OverrideWorldSettings then
local DisabledVehicleScenarios = {
    'WORLD_VEHICLE_AMBULANCE',
    'WORLD_VEHICLE_ATTRACTOR',
    'WORLD_VEHICLE_BICYCLE_BMX',
    'WORLD_VEHICLE_BICYCLE_BMX_BALLAS',
    'WORLD_VEHICLE_BICYCLE_BMX_FAMILY',
    'WORLD_VEHICLE_BICYCLE_BMX_HARMONY',
    'WORLD_VEHICLE_BICYCLE_BMX_VAGOS',
    'WORLD_VEHICLE_BICYCLE_MOUNTAIN',
    'WORLD_VEHICLE_BICYCLE_ROAD',
    'WORLD_VEHICLE_BIKE_OFF_ROAD_RACE',
    'WORLD_VEHICLE_BIKER',
    'WORLD_VEHICLE_BOAT_IDLE',
    'WORLD_VEHICLE_BUSINESSMEN',
    'WORLD_VEHICLE_DRIVE_PASSENGERS',
    'WORLD_VEHICLE_DRIVE_PASSENGERS_LIMITED',
    'WORLD_VEHICLE_DRIVE_SOLO',
    'WORLD_VEHICLE_FIRE_TRUCK',
    'WORLD_VEHICLE_MARIACHI',
    'WORLD_VEHICLE_MECHANIC',
    'WORLD_VEHICLE_MILITARY_PLANES_BIG',
    'WORLD_VEHICLE_MILITARY_PLANES_SMALL',
    'WORLD_VEHICLE_POLICE_BIKE',
    'WORLD_VEHICLE_POLICE_CAR',
    'WORLD_VEHICLE_POLICE_NEXT_TO_CAR',
    'WORLD_VEHICLE_SALTON',
    'WORLD_VEHICLE_SALTON_DIRT_BIKE',
    'WORLD_VEHICLE_SECURITY_CAR',
    'WORLD_VEHICLE_STREETRACE',
    'WORLD_VEHICLE_TOURBUS',
    'WORLD_VEHICLE_TOURIST',
    'WORLD_VEHICLE_TRUCK_LOGS',
    'WORLD_VEHICLE_TRUCKS_TRAILERS',
}

local DisabledPedScenarios = {
    'WORLD_HUMAN_AA_COFFEE',
    'WORLD_HUMAN_AA_SMOKE',
    'WORLD_HUMAN_BINOCULARS',
    'WORLD_HUMAN_BUM_FREEWAY',
    'WORLD_HUMAN_BUM_SLUMPED',
    'WORLD_HUMAN_BUM_STANDING',
    'WORLD_HUMAN_CLIPBOARD',
    'WORLD_HUMAN_CONST_DRILL',
    'WORLD_HUMAN_COP_IDLES',
    'WORLD_HUMAN_DRINKING',
    'WORLD_HUMAN_DRUG_DEALER',
    'WORLD_HUMAN_DRUG_DEALER_HARD',
    'WORLD_HUMAN_GARDENER_LEAF_BLOWER',
    'WORLD_HUMAN_GARDENER_PLANT',
    'WORLD_HUMAN_GOLF_PLAYER',
    'WORLD_HUMAN_GUARD_PATROL',
    'WORLD_HUMAN_GUARD_STAND',
    'WORLD_HUMAN_GUARD_STAND_ARMY',
    'WORLD_HUMAN_HANG_OUT_STREET',
    'WORLD_HUMAN_HIKER',
    'WORLD_HUMAN_JANITOR',
    'WORLD_HUMAN_MAID_CLEAN',
    'WORLD_HUMAN_MOBILE_FILM_SHOCKING',
    'WORLD_HUMAN_MUSCLE_FLEX',
    'WORLD_HUMAN_MUSCLE_FREE_WEIGHTS',
    'WORLD_HUMAN_MUSICIAN',
    'WORLD_HUMAN_PAPARAZZI',
    'WORLD_HUMAN_PARTYING',
    'WORLD_HUMAN_PICNIC',
    'WORLD_HUMAN_POWER_WALKER',
    'WORLD_HUMAN_PROSTITUTE_HIGH_CLASS',
    'WORLD_HUMAN_PROSTITUTE_LOW_CLASS',
    'WORLD_HUMAN_PUSH_UPS',
    'WORLD_HUMAN_SEAT_LEDGE',
    'WORLD_HUMAN_SEAT_LEDGE_EATING',
    'WORLD_HUMAN_SEAT_STEPS',
    'WORLD_HUMAN_SEAT_WALL',
    'WORLD_HUMAN_SEAT_WALL_EATING',
    'WORLD_HUMAN_SEAT_WALL_TABLET',
    'WORLD_HUMAN_SECURITY_SHINE_TORCH',
    'WORLD_HUMAN_SIT_UPS',
    'WORLD_HUMAN_SMOKING',
    'WORLD_HUMAN_SMOKING_POT',
    'WORLD_HUMAN_STAND_FIRE',
    'WORLD_HUMAN_STAND_FISHING',
    'WORLD_HUMAN_STAND_IMPATIENT',
    'WORLD_HUMAN_STAND_IMPATIENT_UPRIGHT',
    'WORLD_HUMAN_STAND_MOBILE',
    'WORLD_HUMAN_STAND_MOBILE_UPRIGHT',
    'WORLD_HUMAN_STRIP_WATCH_STAND',
    'WORLD_HUMAN_STUPOR',
    'WORLD_HUMAN_SUNBATHE',
    'WORLD_HUMAN_SUNBATHE_BACK',
    'WORLD_HUMAN_SUPERHERO',
    'WORLD_HUMAN_SWIMMING',
    'WORLD_HUMAN_TENNIS_PLAYER',
    'WORLD_HUMAN_TOURIST_MAP',
    'WORLD_HUMAN_TOURIST_MOBILE',
    'WORLD_HUMAN_VEHICLE_MECHANIC',
    'WORLD_HUMAN_WELDING',
    'WORLD_HUMAN_WINDOW_SHOP_BROWSE',
    'WORLD_HUMAN_YOGA'
}

local RelationshipTypes = {
    "PLAYER",
    "CIVMALE",
    "CIVFEMALE",
    "COP",
    "SECURITY_GUARD",
    "PRIVATE_SECURITY",
    "FIREMAN",
    "GANG_1",
    "GANG_2",
    "GANG_9",
    "GANG_10",
    "AMBIENT_GANG_LOST",
    "AMBIENT_GANG_MEXICAN",
    "AMBIENT_GANG_FAMILY",
    "AMBIENT_GANG_BALLAS",
    "AMBIENT_GANG_MARABUNTE",
    "AMBIENT_GANG_CULT",
    "AMBIENT_GANG_SALVA",
    "AMBIENT_GANG_WEICHENG",
    "AMBIENT_GANG_HILLBILLY"
}

local worldSettings = Config.WorldSettings or {}
local PLAYER_ID_RETRY_MS = math.max(100, tonumber(worldSettings.PlayerRetryInterval) or 250)
local ZERO_DENSITY = 0.0
local FRAME_SUPPRESSION_MODE = worldSettings.FrameSuppressionMode or 'passive'
local cachedPlayerId = nil
local scenarioBlockingHandle = nil
local pedNonCreationAreaActive = false
local SetAmbientPedRangeMultiplierThisFrameNative = SetAmbientPedRangeMultiplierThisFrame
local SetNumberOfParkedVehiclesNative = SetNumberOfParkedVehicles
local SetAllLowPriorityVehicleGeneratorsActiveNative = SetAllLowPriorityVehicleGeneratorsActive
local SetPedNonCreationAreaNative = SetPedNonCreationArea
local ClearPedNonCreationAreaNative = ClearPedNonCreationArea

local DefaultSuppressedVehicleModels = {
    'taco',
    'biff',
    'hauler',
    'phantom',
    'pounder',
    'packer',
    'mule',
    'rubble',
    'tiptruck',
    'tiptruck2'
}

local function RefreshPlayerId()
    cachedPlayerId = (cache and cache.playerId) or PlayerId()
    if cachedPlayerId == nil or cachedPlayerId == -1 then
        return nil
    end

    return cachedPlayerId
end

local function ApplyWorldPopulationFrame()
    SetPedDensityMultiplierThisFrame(ZERO_DENSITY)
    SetScenarioPedDensityMultiplierThisFrame(ZERO_DENSITY, ZERO_DENSITY)
    SetVehicleDensityMultiplierThisFrame(ZERO_DENSITY)

    if FRAME_SUPPRESSION_MODE ~= 'strict' then
        return
    end

    SetParkedVehicleDensityMultiplierThisFrame(ZERO_DENSITY)
    SetRandomVehicleDensityMultiplierThisFrame(ZERO_DENSITY)
    SetAmbientVehicleRangeMultiplierThisFrame(ZERO_DENSITY)

    if SetAmbientPedRangeMultiplierThisFrameNative then
        SetAmbientPedRangeMultiplierThisFrameNative(ZERO_DENSITY)
    end
end

local function ApplyPopulationBudgets()
    if type(SetPedPopulationBudget) == 'function' then
        SetPedPopulationBudget(tonumber(worldSettings.PedPopulationBudget) or 0)
    end

    if type(SetVehiclePopulationBudget) == 'function' then
        SetVehiclePopulationBudget(tonumber(worldSettings.VehiclePopulationBudget) or 0)
    end

    if type(SetReducePedModelBudget) == 'function' then
        SetReducePedModelBudget(worldSettings.ReducePedModelBudget ~= false)
    end

    if type(SetReduceVehicleModelBudget) == 'function' then
        SetReduceVehicleModelBudget(worldSettings.ReduceVehicleModelBudget ~= false)
    end
end

local function ApplyScenarioBlockingArea()
    if worldSettings.UseScenarioBlockingArea == false or scenarioBlockingHandle then
        return
    end

    if type(AddScenarioBlockingArea) ~= 'function' then
        return
    end

    local area = worldSettings.ScenarioBlockingArea or {}
    scenarioBlockingHandle = AddScenarioBlockingArea(
        area.x1 or -10000.0,
        area.y1 or -10000.0,
        area.z1 or -1000.0,
        area.x2 or 10000.0,
        area.y2 or 10000.0,
        area.z2 or 2000.0,
        false,
        true,
        true,
        true
    )
end

local function ApplyPedNonCreationArea()
    if worldSettings.UsePedNonCreationArea == false or pedNonCreationAreaActive then
        return
    end

    if type(SetPedNonCreationAreaNative) ~= 'function' then
        return
    end

    local area = worldSettings.ScenarioBlockingArea or {}
    SetPedNonCreationAreaNative(
        area.x1 or -10000.0,
        area.y1 or -10000.0,
        area.z1 or -1000.0,
        area.x2 or 10000.0,
        area.y2 or 10000.0,
        area.z2 or 2000.0
    )
    pedNonCreationAreaActive = true
end

local function ApplySuppressedVehicleModels()
    if type(SetVehicleModelIsSuppressed) ~= 'function' then
        return
    end

    local models = worldSettings.SuppressedVehicleModels or DefaultSuppressedVehicleModels
    for _, model in ipairs(models) do
        SetVehicleModelIsSuppressed(GetHashKey(model), true)
    end
end

local function ClearScenarioBlockingArea()
    if not scenarioBlockingHandle or type(RemoveScenarioBlockingArea) ~= 'function' then
        return
    end

    RemoveScenarioBlockingArea(scenarioBlockingHandle, false)
    scenarioBlockingHandle = nil
end

local function ClearPedNonCreationArea()
    if not pedNonCreationAreaActive or type(ClearPedNonCreationAreaNative) ~= 'function' then
        return
    end

    ClearPedNonCreationAreaNative()
    pedNonCreationAreaActive = false
end

local function ClearSuppressedVehicleModels()
    if type(SetVehicleModelIsSuppressed) ~= 'function' then
        return
    end

    local models = worldSettings.SuppressedVehicleModels or DefaultSuppressedVehicleModels
    for _, model in ipairs(models) do
        SetVehicleModelIsSuppressed(GetHashKey(model), false)
    end
end

local function ApplyPersistentWorldState(playerId)
    ApplyPopulationBudgets()
    ApplySuppressedVehicleModels()
    SetCreateRandomCops(false)
    SetCreateRandomCopsNotOnScenarios(false)
    SetCreateRandomCopsOnScenarios(false)
    SetGarbageTrucks(false)
    SetRandomBoats(false)
    SetRandomTrains(false)
    DistantCopCarSirens(false)
    SetMaxWantedLevel(0)

    if SetNumberOfParkedVehiclesNative then
        SetNumberOfParkedVehiclesNative(0)
    end

    if SetAllLowPriorityVehicleGeneratorsActiveNative then
        SetAllLowPriorityVehicleGeneratorsActiveNative(false)
    end

    if not playerId then
        return
    end

    SetPoliceIgnorePlayer(playerId, true)

    if GetPlayerWantedLevel(playerId) > 0 then
        SetPlayerWantedLevel(playerId, 0, false)
        SetPlayerWantedLevelNow(playerId, false)
    end
end

local function ReapplyPersistentState()
    local playerId = RefreshPlayerId()
    ApplyPersistentWorldState(playerId)
end

local function ApplyStaticWorldState(playerId)
    ApplyScenarioBlockingArea()
    ApplyPedNonCreationArea()

    for i = 1, 15 do
        EnableDispatchService(i, false)
    end

    for _, scenarioName in ipairs(DisabledVehicleScenarios) do
        SetScenarioTypeEnabled(scenarioName, false)
    end

    for _, scenarioName in ipairs(DisabledPedScenarios) do
        SetScenarioTypeEnabled(scenarioName, false)
    end

    local hashes = {}
    for i, typeName in ipairs(RelationshipTypes) do
        hashes[i] = GetHashKey(typeName)
    end

    for i = 1, #hashes do
        for j = i + 1, #hashes do
            SetRelationshipBetweenGroups(1, hashes[i], hashes[j])
            SetRelationshipBetweenGroups(1, hashes[j], hashes[i])
        end
    end

    if playerId then
        SetPoliceIgnorePlayer(playerId, true)
    end

    SetAudioFlag("PoliceScannerDisabled", true)
    SetAudioFlag("DisableFlightMusic", true)

    if not StartAudioScene("FBI_HEIST_H5_MUTE_AMBIENCE_SCENE") then
        COREX.Debug.Warn("[cl_world] Failed to start audio scene FBI_HEIST_H5")
    end
    if not StartAudioScene("CHARACTER_CHANGE_IN_SKY_SCENE") then
        COREX.Debug.Warn("[cl_world] Failed to start audio scene CHARACTER_CHANGE")
    end

    COREX.Debug.Info("World purge initialized - Emergency services disabled")
    COREX.Debug.Info("Relationship groups reset for apocalypse")
end

CreateThread(function()
    local playerId = RefreshPlayerId()
    while not playerId do
        Wait(PLAYER_ID_RETRY_MS)
        playerId = RefreshPlayerId()
    end

    ApplyStaticWorldState(playerId)
    ApplyPersistentWorldState(playerId)
end)

if FRAME_SUPPRESSION_MODE ~= 'passive' and FRAME_SUPPRESSION_MODE ~= 'off' then
    CreateThread(function()
        while true do
            Wait(0)
            ApplyWorldPopulationFrame()
        end
    end)
end

if lib and lib.onCache then
    lib.onCache('ped', function()
        ReapplyPersistentState()
    end)
end

AddEventHandler('playerSpawned', function()
    ReapplyPersistentState()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    ClearScenarioBlockingArea()
    ClearPedNonCreationArea()
    ClearSuppressedVehicleModels()
end)
end
