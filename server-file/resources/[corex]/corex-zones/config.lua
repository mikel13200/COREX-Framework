Config = {}

Config.Debug = false

Config.SafeZones = {
    {
        name = "Main Safe Zone",
        coords = vector3(1523.8441, 1685.2471, 110.1167),
        radius = 200.0,
        blip = {
            enabled = true,
            sprite = 487,
            color = 2,
            scale = 1.0,
            label = "Safe Zone"
        }
    }
}

Config.Protection = {
    godMode = true,
    disableWeapons = true,
    disablePVP = true,
    antiGlitch = true
}

Config.CheckInterval = 500
