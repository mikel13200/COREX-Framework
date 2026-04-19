Config = {}

-- Time Settings
Config.Time = {
    EnableTimeCycle = true,
    SecondsPerMinute = 30,      -- 30 real seconds = 1 game minute
    DefaultHour = 21,           -- Start hour (21 = 9 PM)
    DefaultMinute = 0,
    FreezeTime = false,
}

-- Weather Settings
Config.Weather = {
    EnableDynamicWeather = true,
    ChangeInterval = 10,        -- Change weather every 10 minutes
    DefaultWeather = 'OVERCAST',
    TransitionTime = 45.0,
    Blackout = false,
}

-- Weather Probabilities (higher = more likely)
Config.WeatherProbabilities = {
    ['CLEAR']       = 0,
    ['EXTRASUNNY']  = 0,
    ['CLOUDS']      = 10,
    ['OVERCAST']    = 35,
    ['RAIN']        = 15,
    ['CLEARING']    = 0,
    ['THUNDER']     = 15,
    ['SMOG']        = 10,
    ['FOGGY']       = 15,
    ['XMAS']        = 0,
    ['SNOWLIGHT']   = 0,
    ['BLIZZARD']    = 0,
}

-- Admin Permissions
Config.Admins = {}
Config.UseAcePermissions = false