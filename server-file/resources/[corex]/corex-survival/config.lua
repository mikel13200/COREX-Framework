Config = {}
Config.Debug = false

Config.Hunger = {
    maxValue = 100,
    drainRate = 0.15,
    tickInterval = 30000,
    effectThreshold = 25,
    damageThreshold = 5,
    damageAmount = 3
}

Config.Thirst = {
    maxValue = 100,
    drainRate = 0.20,
    tickInterval = 30000,
    effectThreshold = 25,
    damageThreshold = 5,
    damageAmount = 4
}

Config.Infection = {
    enabled = true,
    biteChance = 0.15,
    growthRate = 0.5,
    growthInterval = 60000,
    stages = {
        { threshold = 25, effects = {'shake'} },
        { threshold = 50, effects = {'shake', 'slowness'} },
        { threshold = 75, effects = {'shake', 'slowness', 'cough', 'screenDistort'} },
        { threshold = 100, effects = {'death'} }
    },
}

Config.Effects = {
    shakeIntensity = 0.3,
    slowMultiplier = 0.7,
    screenDistortStrength = 0.3,
    coughDict = 'mp_player_intdrink',
    coughAnim = 'loop_bottle',
    coughDuration = 2000,
    coughCooldown = 15000,
}

Config.Items = {
    ['canned_food']  = { stat = 'hunger',    amount = 35 },
    ['raw_meat']     = { stat = 'hunger',    amount = 15,  infectionRisk = 0.10 },
    ['cooked_meat']  = { stat = 'hunger',    amount = 50 },
    ['clean_water']  = { stat = 'thirst',    amount = 40 },
    ['dirty_water']  = { stat = 'thirst',    amount = 20,  infectionRisk = 0.10 },
    ['energy_drink'] = { stat = 'thirst',    amount = 25 },
    ['bread']        = { stat = 'hunger',    amount = 20 },
    ['antidote']     = { stat = 'infection', cure = true },
    ['painkillers']  = { stat = 'infection', pause = 300000 },
    ['antibiotics']  = { stat = 'infection', reduce = 25 },
    ['bandage']      = { stat = 'health',    amount = 25 },
    ['medkit']       = { stat = 'health',    amount = 100, fullHeal = true },
}
