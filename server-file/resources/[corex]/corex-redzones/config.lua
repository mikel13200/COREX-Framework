Config = {}
Config.Debug = false

Config.CheckInterval = 500
Config.CrateModel = 'prop_mil_crate_01'
Config.CrateInteractDistance = 2.5

Config.RefillMinutes = { min = 30, max = 60 }

Config.HealthDrain = {
    enabled = true,
    tickInterval = 4000,
    amountPerTick = 1
}

Config.Vignette = {
    r = 120, g = 0, b = 0,
    alpha = 60,
    fadeInMs = 600,
    fadeOutMs = 3000
}

Config.Audio = {
    loopInterval = 1500,
    soundSet = 'GENERIC_FRONTEND_SOUNDSET',
    soundName = 'Radio_Static_Loop'
}

Config.StrongZombieTypes = {
    {
        id = 'brute', label = 'Brute', weight = 18,
        health = 650, armor = 80, damage = 48,
        moveSpeed = 1.0, moveRateOverride = 0.85, sprintOnSight = false,
        attackRange = 2.6, attackCooldown = 1200, knockback = true, canClimb = true,
        models = { 'G_M_M_Zombie_02' },
        colorTint = { r = 100, g = 140, b = 90 }
    },
    {
        id = 'runner', label = 'Runner', weight = 20,
        health = 120, armor = 0, damage = 38,
        moveSpeed = 3.2, moveRateOverride = 1.55, sprintOnSight = true,
        attackRange = 2.0, attackCooldown = 250, canClimb = true,
        models = { 'cs_old_man2' },
        colorTint = { r = 220, g = 60, b = 60 }
    },
    {
        id = 'grabber', label = 'Grabber', weight = 12,
        health = 220, armor = 0, damage = 16,
        moveSpeed = 2.2, moveRateOverride = 1.25, sprintOnSight = true,
        attackRange = 2.0, attackCooldown = 800, canClimb = true, grabPriority = true,
        models = { 'G_M_M_Zombie_01' },
        colorTint = { r = 140, g = 100, b = 160 }
    },
    {
        id = 'electric', label = 'Charged', weight = 10,
        health = 280, armor = 15, damage = 28,
        moveSpeed = 1.3, moveRateOverride = 1.15, sprintOnSight = false,
        attackRange = 2.4, attackCooldown = 1000, canClimb = true,
        special = 'electric', stunOnHit = 1500,
        ptfx = { dict = 'core', name = 'ent_amb_elec_crackle', scale = 0.7, bone = 0 },
        lightColor = { r = 80, g = 180, b = 255 },
        models = { 'G_M_M_Zombie_01' },
        colorTint = { r = 80, g = 180, b = 255 }
    },
    {
        id = 'burning', label = 'Burning', weight = 10,
        health = 220, armor = 0, damage = 32,
        moveSpeed = 1.6, moveRateOverride = 1.2, sprintOnSight = true,
        attackRange = 2.2, attackCooldown = 900, canClimb = true,
        special = 'fire', igniteOnHit = true,
        ptfx = { dict = 'core', name = 'fire_ped_body', scale = 0.6, bone = 0 },
        lightColor = { r = 255, g = 120, b = 40 },
        applyZombieTint = true,
        damagePacks = { 'BigHitByVehicle', 'SCR_ZombTerror' },
        models = { 'S_M_Y_Fireman_01' },
        colorTint = { r = 255, g = 120, b = 40 }
    },
    {
        id = 'toxic', label = 'Toxic', weight = 8,
        health = 320, armor = 0, damage = 22,
        moveSpeed = 1.0, moveRateOverride = 1.0, sprintOnSight = false,
        attackRange = 2.3, attackCooldown = 1200, canClimb = true,
        special = 'toxic',
        aura = { radius = 5.0, tickInterval = 800, tickDamage = 5 },
        ptfx = { dict = 'core', name = 'ent_amb_acid_bath', scale = 1.2, bone = 0 },
        lightColor = { r = 70, g = 220, b = 60 },
        applyZombieTint = true,
        damagePacks = { 'SCR_ZombTerror', 'HOSP_01' },
        models = { 'S_M_M_HazmatWorker_01' },
        colorTint = { r = 70, g = 220, b = 60 }
    },
    {
        id = 'stormbringer', label = 'Stormbringer', weight = 8,
        health = 400, armor = 30, damage = 35,
        moveSpeed = 1.8, moveRateOverride = 1.3, sprintOnSight = true,
        attackRange = 2.5, attackCooldown = 800, canClimb = true,
        special = 'electric', stunOnHit = 2000,
        ptfx = { dict = 'core', name = 'ent_amb_elec_crackle', scale = 1.0, bone = 0 },
        lightColor = { r = 150, g = 50, b = 255 },
        attackPtfx = { dict = 'core', name = 'ent_amb_sparking_wires', scale = 0.7 },
        aura = { radius = 6.0, tickInterval = 1500, tickDamage = 4 },
        applyZombieTint = true,
        damagePacks = { 'SCR_ZombTerror', 'BigHitByVehicle' },
        models = { 'G_M_M_Zombie_01' },
        colorTint = { r = 150, g = 50, b = 255 }
    }
}

Config.ZombieDensity = {
    min = 30,
    max = 45,
    refillInterval = 6000,
    spawnRingMin = 35.0,
    spawnRingMax = 90.0
}

Config.LootItemsPerCrate = { min = 5, max = 10 }

Config.LootTiers = {
    { chance = 0.45, items = {
        { name = 'rifle_ammo',     min = 30, max = 60 },
        { name = 'smg_ammo',       min = 30, max = 60 },
        { name = 'shotgun_ammo',   min = 15, max = 30 },
        { name = 'medkit',         min = 2,  max = 3  },
        { name = 'antidote',       min = 1,  max = 3  },
        { name = 'antibiotics',    min = 2,  max = 4  },
        { name = 'painkillers',    min = 2,  max = 4  },
        { name = 'clean_water',    min = 2,  max = 5  },
        { name = 'canned_food',    min = 2,  max = 5  }
    }},
    { chance = 0.35, items = {
        { name = 'WEAPON_CARBINERIFLE',     min = 1, max = 1 },
        { name = 'WEAPON_ASSAULTRIFLE_MK2', min = 1, max = 1 },
        { name = 'WEAPON_SPECIALCARBINE',   min = 1, max = 1 },
        { name = 'WEAPON_COMBATSHOTGUN',    min = 1, max = 1 },
        { name = 'WEAPON_SMG_MK2',          min = 1, max = 1 },
        { name = 'rifle_ammo',              min = 40, max = 80 },
        { name = 'smg_ammo',                min = 40, max = 80 }
    }},
    { chance = 0.15, items = {
        { name = 'blueprint_medkit',      min = 1, max = 1 },
        { name = 'blueprint_antidote',    min = 1, max = 1 },
        { name = 'blueprint_smg_ammo',    min = 1, max = 1 },
        { name = 'blueprint_pistol_ammo', min = 1, max = 1 },
        { name = 'WEAPON_TECPISTOL',      min = 1, max = 1 }
    }},
    { chance = 0.05, items = {
        { name = 'WEAPON_MINIGUN',           min = 1, max = 1 },
        { name = 'WEAPON_RPG',               min = 1, max = 1 },
        { name = 'blueprint_rifle_ammo',     min = 1, max = 1 },
        { name = 'blueprint_shotgun_ammo',   min = 1, max = 1 }
    }}
}

Config.BigLootBox = {
    model = 'prop_mil_crate_02',
    itemsPerBox = { min = 5, max = 10 },
    tiers = {
        { chance = 0.40, items = {
            { name = 'rifle_ammo',     min = 40, max = 80 },
            { name = 'smg_ammo',       min = 40, max = 80 },
            { name = 'shotgun_ammo',   min = 20, max = 40 },
            { name = 'medkit',         min = 2,  max = 4  },
            { name = 'antidote',       min = 2,  max = 3  },
            { name = 'antibiotics',    min = 3,  max = 5  }
        }},
        { chance = 0.35, items = {
            { name = 'WEAPON_CARBINERIFLE',     min = 1, max = 1 },
            { name = 'WEAPON_COMBATSHOTGUN',    min = 1, max = 1 },
            { name = 'WEAPON_ASSAULTRIFLE_MK2', min = 1, max = 1 },
            { name = 'rifle_ammo',              min = 50, max = 100 }
        }},
        { chance = 0.20, items = {
            { name = 'blueprint_medkit',      min = 1, max = 1 },
            { name = 'blueprint_antidote',    min = 1, max = 1 },
            { name = 'WEAPON_TECPISTOL',      min = 1, max = 1 },
            { name = 'blueprint_rifle_ammo',  min = 1, max = 1 }
        }},
        { chance = 0.05, items = {
            { name = 'WEAPON_MINIGUN',        min = 1, max = 1 },
            { name = 'WEAPON_RPG',            min = 1, max = 1 },
            { name = 'blueprint_shotgun_ammo', min = 1, max = 1 }
        }}
    }
}

Config.Zones = {
    {
        id = 'zancudo',
        name = 'Fort Zancudo',
        coords = vector3(-2300.0, 3400.0, 32.0),
        radius = 150.0,
        crates = {
            vector3(-2285.6, 3385.1, 32.81),
            vector3(-2318.4, 3409.7, 32.81),
            vector3(-2267.0, 3420.3, 32.81),
            vector3(-2302.5, 3368.8, 32.81)
        },
        bigBox = vector3(-2300.0, 3395.0, 32.81)
    },
    {
        id = 'humane_labs',
        name = 'Humane Labs',
        coords = vector3(3600.0, 3700.0, 30.0),
        radius = 150.0,
        crates = {
            vector3(3612.8, 3706.5, 30.0),
            vector3(3584.2, 3689.1, 30.1),
            vector3(3620.5, 3680.9, 30.0)
        },
        bigBox = vector3(3605.0, 3695.0, 30.0)
    },
    {
        id = 'chiliad_peak',
        name = 'Mount Chiliad Peak',
        coords = vector3(450.0, 5570.0, 780.0),
        radius = 120.0,
        crates = {
            vector3(455.2, 5566.8, 781.2),
            vector3(440.1, 5580.4, 780.5),
            vector3(462.7, 5558.2, 780.8)
        },
        bigBox = vector3(452.0, 5568.0, 781.0)
    },
    {
        id = 'smuggler_port',
        name = 'Smuggler Port',
        coords = vector3(1200.0, -3100.0, 5.0),
        radius = 150.0,
        crates = {
            vector3(1210.4, -3093.1, 5.9),
            vector3(1188.7, -3111.6, 5.9),
            vector3(1215.8, -3120.2, 5.9),
            vector3(1195.3, -3085.5, 5.9)
        },
        bigBox = vector3(1202.0, -3102.0, 5.9)
    },
    {
        id = 'paleto_bunker',
        name = 'Paleto Forest Bunker',
        coords = vector3(-800.0, 5800.0, 35.0),
        radius = 140.0,
        crates = {
            vector3(-788.5, 5808.2, 35.6),
            vector3(-812.3, 5792.1, 35.4),
            vector3(-795.0, 5780.9, 35.7)
        },
        bigBox = vector3(-798.0, 5795.0, 35.5)
    }
}

Config.Blip = {
    centerSprite = 303,
    centerScale = 1.1,
    centerColor = 1,
    radiusColor = 1,
    radiusAlpha = 80,
    labelPrefix = 'RED ZONE — '
}
