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

Config.OverrideWorldSettings = true

Config.Database = {
    Resource = 'oxmysql',
}
