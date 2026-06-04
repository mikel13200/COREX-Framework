Config = {}

Config.Debug = false
Config.AllowMultiSession = true

Config.FrameworkName = 'COREX'
Config.Version = '2.0.0'

Config.PlayerStates = {
    'loading',
    'active',
    'dead',
    'spectating'
}

Config.DefaultPlayerState = 'loading'

Config.CallbackTimeout = 10000

Config.EventPrefix = 'corex'

Config.MaxMoney = 999999999

Config.EnableInteractions = true
Config.OverrideWorldSettings = true
Config.WorldSettings = {
    PlayerRetryInterval = 250,
    FrameSuppressionMode = 'strict',
    PedPopulationBudget = 0,
    VehiclePopulationBudget = 0,
    ReducePedModelBudget = true,
    ReduceVehicleModelBudget = true,
    UsePedNonCreationArea = true,
    UseScenarioBlockingArea = true,
    ScenarioBlockingArea = {
        x1 = -10000.0,
        y1 = -10000.0,
        z1 = -1000.0,
        x2 = 10000.0,
        y2 = 10000.0,
        z2 = 2000.0
    },
    SuppressedVehicleModels = {
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
}

Config.Database = {
    Resource = 'oxmysql',
}
