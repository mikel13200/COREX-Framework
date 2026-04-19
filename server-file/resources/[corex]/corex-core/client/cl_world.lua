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

CreateThread(function()
    for i = 1, 15 do
        EnableDispatchService(i, false)
    end

    SetCreateRandomCops(false)
    SetCreateRandomCopsNotOnScenarios(false)
    SetCreateRandomCopsOnScenarios(false)

    SetPoliceIgnorePlayer(PlayerId(), true)
    SetMaxWantedLevel(0)

    SetAudioFlag("PoliceScannerDisabled", true)
    SetAudioFlag("DisableFlightMusic", true)

    for _, scenarioName in ipairs(DisabledVehicleScenarios) do
        SetScenarioTypeEnabled(scenarioName, false)
    end

    if not StartAudioScene("FBI_HEIST_H5_MUTE_AMBIENCE_SCENE") then
        COREX.Debug.Warn("[cl_world] Failed to start audio scene FBI_HEIST_H5")
    end
    if not StartAudioScene("CHARACTER_CHANGE_IN_SKY_SCENE") then
        COREX.Debug.Warn("[cl_world] Failed to start audio scene CHARACTER_CHANGE")
    end

    COREX.Debug.Info("World purge initialized - Emergency services disabled")
end)

CreateThread(function()
    while true do
        Wait(0)

        SetPlayerWantedLevel(PlayerId(), 0, false)
        SetPlayerWantedLevelNow(PlayerId(), false)

        SetPedDensityMultiplierThisFrame(0.0)
        SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)

        SetVehicleDensityMultiplierThisFrame(0.0)
        SetParkedVehicleDensityMultiplierThisFrame(0.0)
        SetRandomVehicleDensityMultiplierThisFrame(0.0)
        SetAmbientVehicleRangeMultiplierThisFrame(0.0)

        SetCreateRandomCops(false)
        SetCreateRandomCopsNotOnScenarios(false)
        SetCreateRandomCopsOnScenarios(false)
        SetGarbageTrucks(false)
        SetRandomBoats(false)
        SetRandomTrains(false)

        DistantCopCarSirens(false)
    end
end)
end

if Config.OverrideWorldSettings then
CreateThread(function()
    local relationshipTypes = {
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

    local hashes = {}
    for i, typeName in ipairs(relationshipTypes) do
        hashes[i] = GetHashKey(typeName)
    end

    for i = 1, #hashes do
        for j = i + 1, #hashes do
            SetRelationshipBetweenGroups(1, hashes[i], hashes[j])
            SetRelationshipBetweenGroups(1, hashes[j], hashes[i])
        end
    end

    COREX.Debug.Info("Relationship groups reset for apocalypse")
end)
end
