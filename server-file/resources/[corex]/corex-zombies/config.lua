Config = {}

Config.Debug = false
Config.DebugAnimations = false
Config.LocalClientZombies = true
Config.ForceTrueZombieModel = false
Config.TrueZombieModel = 'u_m_y_zombie_01'

Config.FallbackModels = { 'u_m_y_zombie_01', 'a_m_m_acult_01', 'a_m_m_afriamer_01' }

Config.FallbackClipsets = {
    'move_m@drunk@verydrunk',
    'move_m@drunk@moderatedrunk',
    'move_m@injured'
}

Config.FallbackAttackDict = 'melee@unarmed@streamed_core'

Config.RPSpawning = {
    enabled = true,

    territories = {
        -- { name = 'Downtown LS', center = vector3(0, 0, 0), radius = 200.0, maxZombies = 15 },
    },

    soundAttraction = {
        enabled = true,
        throttleMs = 500,
        categories = {
            pistol    = 45.0,
            smg       = 55.0,
            rifle     = 70.0,
            shotgun   = 75.0,
            sniper    = 90.0,
            explosive = 120.0,
            melee     = 10.0,
        },
    },

    environmentalSpawn = {
        enabled = true,
        chance = 0.35,
        cars      = { enabled = true, searchRadius = 40.0 },
        dumpsters = { enabled = true, searchRadius = 30.0 },
        buildings = { enabled = true, searchRadius = 40.0 },
    },

    hordeMigration = {
        enabled = true,
        interval = 180000,
        groupSize = { min = 2, max = 4 },
    },
}

Config.Sync = {
    Enabled = true,
    ZombieSyncRadius = 200.0,
    MaxGlobalZombies = 150,
    MaxZombiesPerZone = 25,
    AggroMode = 'lastDamager',
    OwnershipMigrationDelay = 500,
    EventLootLockTimeout = 10000,

    -- Stage 1 rollout:
    -- shared event hordes are synced and suppress local duplicates,
    -- while the legacy ambient local spawner stays available until
    -- the whole shared-world pipeline is moved server-side.
    SharedEventHordes = true,
    DisableAmbientLocalSpawner = false,
    SharedZoneSyncInterval = 10000,
    SharedZoneSuppressionBuffer = 45.0,
}

-- ════════════════════════════════════════════════════════════════
-- Population baseline (ResolveDynamicBudget scales this by distance
-- from safe zone, time of day, weather — see PopulationScaling).
-- ════════════════════════════════════════════════════════════════
Config.PopulationBudget = 18

Config.Spawning = {
    enabled = true,
    minDistance = 35.0,
    maxDistance = 110.0,
    spawnInterval = 5000,
    maxZombiesPerSpawn = 3
}

Config.SafeZoneBuffer = 30.0
Config.DespawnDistance = 120.0

Config.AI = {
    engagementRange = 120.0,
    meleeRange = 2.6,
    stuckThreshold = 0.25,
    stuckTimeMs = 2500,
    climbMaxHeight = 2.5,
    taskRefreshMs = 800,
    brainTickMs = 500,
    scenarioDistance = 180.0,
    scenarioGraceMs = 15000,
}

Config.ZombieCombat = {
    recoveryBaseMs = 400,
    lungeForce = 5.0,
    lungeZForce = 0.4,
    faceTargetSpeed = 10.0
}

Config.ZombieSpawn = {
    enabled = true,
    dict = 'anim@scripted@surv@ig2_zombie_spawn@shambler@',
    anim = 'action_02',
    duration = 2800
}

Config.ZombieMovement = {
    primary = {
        walker   = 'move_m@drunk@verydrunk',
        runner   = 'move_m@drunk@slightlydrunk',
        brute    = 'move_m@drunk@verydrunk',
        grabber  = 'move_m@drunk@moderatedrunk',
        electric = 'move_m@drunk@moderatedrunk',
        burning  = 'move_m@scared@a',
        toxic    = 'move_m@drunk@verydrunk',
        stormbringer = 'move_m@drunk@moderatedrunk'
    }
}

Config.ZombieIdle = {
    { dict = 'special_ped@zombie@monologue_6@monologue_6c', anim = 'iamthevinewoodzombie_2', duration = 8000 },
    { dict = 'anim@ingame@move_m@zombie@core', anim = 'walk_up', duration = 6000 }
}

local ZOMBIE_ATTACK = 'anim@ingame@melee@unarmed@streamed_core_zombie'
local ZOMBIE_ATTACK_VARIATIONS = 'anim@ingame@melee@unarmed@streamed_variations_zombie'

local function ZombieAttack(anim, speed, duration, damageTiming, lungeScale, dict, kind, animFlag)
    return {
        anim = anim,
        speed = speed,
        duration = duration,
        damageTiming = damageTiming,
        lungeScale = lungeScale or 1.0,
        dict = dict or ZOMBIE_ATTACK,
        kind = kind,
        animFlag = animFlag
    }
end

Config.Animations = {
    walker = {
        moveClipset = 'move_m@drunk@verydrunk',
        attackDict = ZOMBIE_ATTACK,
        playbackSpeed = 0.45,
        attackDuration = 1000,
        recoveryMs = 700,
        lungeForce = 4.0,
        lungeZForce = 0.4,
        attackAnims = {
            ZombieAttack('short_-180_punch', 0.40, 1225, 0.64, 0.12, ZOMBIE_ATTACK, 'bite', 'rooted'),
            ZombieAttack('short_90_punch', 0.52, 880, 0.42, 0.72, ZOMBIE_ATTACK, 'stab', 'upper_body'),
            ZombieAttack('heavy_punch_b_var_2', 0.46, 1050, 0.37, 1.18, ZOMBIE_ATTACK_VARIATIONS, 'lunge')
        }
    },
    runner = {
        moveClipset = 'move_m@drunk@slightlydrunk',
        chaseAnim = { dict = 'anim@ingame@move_m@zombie@core', anim = 'sprint', speed = 1.2 },
        attackDict = ZOMBIE_ATTACK,
        playbackSpeed = 0.80,
        attackDuration = 550,
        recoveryMs = 150,
        lungeForce = 12.0,
        lungeZForce = 0.6,
        attackAnims = {
            ZombieAttack('heavy_punch_b_var_2', 0.88, 520, 0.28, 1.40, ZOMBIE_ATTACK_VARIATIONS, 'lunge'),
            ZombieAttack('short_90_punch', 0.92, 470, 0.33, 0.85, ZOMBIE_ATTACK, 'stab', 'upper_body'),
            ZombieAttack('short_-180_punch', 0.74, 700, 0.52, 0.18, ZOMBIE_ATTACK, 'bite', 'rooted')
        }
    },
    brute = {
        moveClipset = 'move_m@drunk@verydrunk',
        attackDict = ZOMBIE_ATTACK,
        playbackSpeed = 0.35,
        attackDuration = 1400,
        recoveryMs = 900,
        lungeForce = 10.0,
        lungeZForce = 0.8,
        attackAnims = {
            ZombieAttack('short_-180_punch', 0.32, 1580, 0.68, 0.08, ZOMBIE_ATTACK, 'bite', 'rooted'),
            ZombieAttack('heavy_punch_b_var_2', 0.40, 1250, 0.42, 1.35, ZOMBIE_ATTACK_VARIATIONS, 'lunge'),
            ZombieAttack('short_90_punch', 0.40, 1225, 0.46, 0.78, ZOMBIE_ATTACK, 'stab', 'upper_body')
        }
    },
    grabber = {
        moveClipset = 'move_m@drunk@moderatedrunk',
        attackDict = ZOMBIE_ATTACK,
        playbackSpeed = 0.55,
        attackDuration = 850,
        recoveryMs = 400,
        lungeForce = 7.0,
        lungeZForce = 0.5,
        attackAnims = {
            ZombieAttack('short_-180_punch', 0.50, 980, 0.62, 0.10, ZOMBIE_ATTACK, 'bite', 'rooted'),
            ZombieAttack('short_90_punch', 0.62, 760, 0.40, 0.74, ZOMBIE_ATTACK, 'stab', 'upper_body'),
            ZombieAttack('heavy_punch_b_var_2', 0.58, 760, 0.34, 1.22, ZOMBIE_ATTACK_VARIATIONS, 'lunge')
        }
    },
    electric = {
        moveClipset = 'move_m@drunk@moderatedrunk',
        attackDict = ZOMBIE_ATTACK,
        playbackSpeed = 0.50,
        attackDuration = 900,
        recoveryMs = 550,
        lungeForce = 5.0,
        lungeZForce = 0.4,
        attackAnims = {
            ZombieAttack('short_90_punch', 0.52, 860, 0.42, 0.76, ZOMBIE_ATTACK, 'stab', 'upper_body'),
            ZombieAttack('heavy_punch_b_var_2', 0.50, 940, 0.38, 1.15, ZOMBIE_ATTACK_VARIATIONS, 'lunge'),
            ZombieAttack('short_-180_punch', 0.44, 1040, 0.62, 0.10, ZOMBIE_ATTACK, 'bite', 'rooted')
        }
    },
    burning = {
        moveClipset = 'move_m@scared@a',
        attackDict = ZOMBIE_ATTACK,
        playbackSpeed = 0.45,
        attackDuration = 950,
        recoveryMs = 500,
        lungeForce = 6.0,
        lungeZForce = 0.5,
        attackAnims = {
            ZombieAttack('short_90_punch', 0.48, 900, 0.41, 0.78, ZOMBIE_ATTACK, 'stab', 'upper_body'),
            ZombieAttack('heavy_punch_b_var_2', 0.52, 860, 0.36, 1.20, ZOMBIE_ATTACK_VARIATIONS, 'lunge'),
            ZombieAttack('short_-180_punch', 0.42, 1060, 0.63, 0.10, ZOMBIE_ATTACK, 'bite', 'rooted')
        }
    },
    toxic = {
        moveClipset = 'move_m@drunk@verydrunk',
        attackDict = ZOMBIE_ATTACK,
        playbackSpeed = 0.40,
        attackDuration = 1000,
        recoveryMs = 600,
        lungeForce = 4.5,
        lungeZForce = 0.4,
        attackAnims = {
            ZombieAttack('short_-180_punch', 0.36, 1150, 0.66, 0.08, ZOMBIE_ATTACK, 'bite', 'rooted'),
            ZombieAttack('short_90_punch', 0.45, 930, 0.43, 0.70, ZOMBIE_ATTACK, 'stab', 'upper_body'),
            ZombieAttack('heavy_punch_b_var_2', 0.42, 980, 0.37, 1.10, ZOMBIE_ATTACK_VARIATIONS, 'lunge')
        }
    },
    stormbringer = {
        moveClipset = 'move_m@drunk@moderatedrunk',
        attackDict = ZOMBIE_ATTACK,
        playbackSpeed = 0.50,
        attackDuration = 850,
        recoveryMs = 450,
        lungeForce = 7.0,
        lungeZForce = 0.5,
        attackAnims = {
            ZombieAttack('heavy_punch_b_var_2', 0.56, 780, 0.33, 1.25, ZOMBIE_ATTACK_VARIATIONS, 'lunge'),
            ZombieAttack('short_90_punch', 0.58, 760, 0.40, 0.82, ZOMBIE_ATTACK, 'stab', 'upper_body'),
            ZombieAttack('short_-180_punch', 0.48, 940, 0.60, 0.12, ZOMBIE_ATTACK, 'bite', 'rooted')
        }
    }
}

-- ════════════════════════════════════════════════════════════════
-- Idle scenario pool — played when zombie is > engagementRange
-- from any player AND not alerted by horde. Keeps world alive
-- without burning combat tasks on distant zombies.
-- ════════════════════════════════════════════════════════════════
Config.IdleScenarios = {
    'WORLD_HUMAN_STUPOR',
    'WORLD_HUMAN_BUM_STANDING',
    'WORLD_HUMAN_DRUG_DEALER_HARD',
    'WORLD_HUMAN_JANITOR'
}

Config.ZombieTypes = {
    {
        id = 'walker',
        label = 'Walker',
        weight = 35,
        health = 150,
        armor = 0,
        damage = 16,
        moveSpeed = 1.0,
        moveRateOverride = 1.05,
        sprintOnSight = false,
        attackRange = 1.8,
        attackCooldown = 900,
        canClimb = true,
        lungeForce = 4.0,
        lungeZForce = 0.4,
        recoveryMs = 700,
        models = { 'G_M_M_Zombie_01' },
        colorTint = { r = 120, g = 180, b = 120 }
    },
    {
        id = 'runner',
        label = 'Runner',
        weight = 22,
        health = 80,
        armor = 0,
        damage = 38,
        moveSpeed = 5.0,
        moveRateOverride = 2.0,
        sprintOnSight = true,
        attackRange = 2.0,
        attackCooldown = 250,
        canClimb = true,
        lungeForce = 14.0,
        lungeZForce = 0.7,
        recoveryMs = 100,
        models = { 'cs_old_man2' },
        colorTint = { r = 220, g = 60, b = 60 }
    },
    {
        id = 'brute',
        label = 'Brute',
        weight = 18,
        health = 550,
        armor = 60,
        damage = 42,
        moveSpeed = 0.9,
        moveRateOverride = 0.85,
        sprintOnSight = false,
        attackRange = 2.4,
        attackCooldown = 1400,
        knockback = true,
        canClimb = true,
        lungeForce = 10.0,
        lungeZForce = 0.8,
        recoveryMs = 900,
        models = { 'G_M_M_Zombie_02' },
        colorTint = { r = 100, g = 140, b = 90 }
    },
    {
        id = 'grabber',
        label = 'Grabber',
        weight = 10,
        health = 180,
        armor = 0,
        damage = 14,
        moveSpeed = 2.2,
        moveRateOverride = 1.25,
        sprintOnSight = true,
        attackRange = 1.7,
        attackCooldown = 700,
        canClimb = true,
        grabPriority = true,
        lungeForce = 7.0,
        lungeZForce = 0.5,
        recoveryMs = 400,
        models = { 'G_M_M_Zombie_01' },
        colorTint = { r = 140, g = 100, b = 160 }
    },
    {
        id = 'electric',
        label = 'Charged',
        weight = 6,
        health = 220,
        armor = 10,
        damage = 24,
        moveSpeed = 1.3,
        moveRateOverride = 1.15,
        sprintOnSight = false,
        attackRange = 2.3,
        attackCooldown = 1200,
        canClimb = true,
        special = 'electric',
        stunOnHit = 1200,
        lungeForce = 5.0,
        lungeZForce = 0.4,
        recoveryMs = 550,
        ptfx = { dict = 'core', name = 'ent_amb_elec_crackle', scale = 0.7, bone = 0 },
        lightColor = { r = 80, g = 180, b = 255 },
        attackPtfx = { dict = 'core', name = 'ent_amb_sparking_wires', scale = 0.5 },
        models = { 'G_M_M_Zombie_01' },
        colorTint = { r = 80, g = 180, b = 255 }
    },
    {
        id = 'burning',
        label = 'Burning',
        weight = 6,
        health = 180,
        armor = 0,
        damage = 28,
        moveSpeed = 1.6,
        moveRateOverride = 1.2,
        sprintOnSight = true,
        attackRange = 2.1,
        attackCooldown = 1100,
        canClimb = true,
        special = 'fire',
        igniteOnHit = true,
        lungeForce = 6.0,
        lungeZForce = 0.5,
        recoveryMs = 500,
        ptfx = { dict = 'core', name = 'fire_ped_body', scale = 0.6, bone = 0 },
        lightColor = { r = 255, g = 120, b = 40 },
        attackPtfx = { dict = 'core', name = 'ent_sht_flame', scale = 0.4 },
        applyZombieTint = true,
        damagePacks = { 'BigHitByVehicle', 'SCR_ZombTerror' },
        models = { 'S_M_Y_Fireman_01' },
        colorTint = { r = 255, g = 120, b = 40 }
    },
    {
        id = 'toxic',
        label = 'Toxic',
        weight = 3,
        health = 260,
        armor = 0,
        damage = 20,
        moveSpeed = 1.0,
        moveRateOverride = 1.0,
        sprintOnSight = false,
        attackRange = 2.2,
        attackCooldown = 1500,
        canClimb = true,
        special = 'toxic',
        lungeForce = 4.5,
        lungeZForce = 0.4,
        recoveryMs = 600,
        aura = {
            radius = 4.5,
            tickInterval = 1000,
            tickDamage = 3
        },
        ptfx = { dict = 'core', name = 'ent_amb_acid_bath', scale = 1.2, bone = 0 },
        lightColor = { r = 70, g = 220, b = 60 },
        attackPtfx = { dict = 'core', name = 'exp_grd_bzgas_smoke', scale = 0.6 },
        applyZombieTint = true,
        damagePacks = { 'SCR_ZombTerror', 'HOSP_01' },
        models = { 'S_M_M_HazmatWorker_01' },
        colorTint = { r = 70, g = 220, b = 60 }
    },
    {
        id = 'stormbringer',
        label = 'Stormbringer',
        weight = 2,
        health = 350,
        armor = 20,
        damage = 32,
        moveSpeed = 1.5,
        moveRateOverride = 1.3,
        sprintOnSight = true,
        attackRange = 2.3,
        attackCooldown = 800,
        canClimb = true,
        lungeForce = 7.0,
        lungeZForce = 0.5,
        recoveryMs = 450,
        models = { 'G_M_M_Zombie_01' },
        colorTint = { r = 150, g = 120, b = 220 },
        applyZombieTint = true,
        damagePacks = { 'SCR_ZombTerror' },
    }
}

-- ════════════════════════════════════════════════════════════════
-- Contexts that force elite-only spawns (no walkers).
-- Checked in PickZombieType via context arg.
-- ════════════════════════════════════════════════════════════════
Config.EliteOnlyContexts = {
    night   = true,   -- game time 22:00-05:00
    redzone = true    -- zombies spawned inside a red zone
}

-- ════════════════════════════════════════════════════════════════
-- Population scaling — the fear ramp.
-- Budget scales by distance-to-safe-zone-boundary, night/weather.
-- ════════════════════════════════════════════════════════════════
Config.PopulationScaling = {
    baseline    = 18,
    absoluteMax = 24,

    bands = {
        { maxDist = 60.0,    mult = 0.25 },
        { maxDist = 150.0,   mult = 0.55 },
        { maxDist = 400.0,   mult = 0.80 },
        { maxDist = 99999.0, mult = 1.00 }
    },

    nightMult   = 1.15,
    weatherMult = 1.10
}

-- ════════════════════════════════════════════════════════════════
-- Horde mechanics — zombies alert each other on sighting.
-- Swarm damage bonus when clustered on the player.
-- ════════════════════════════════════════════════════════════════
Config.Horde = {
    attractionRadius = 30.0,    -- m — sighting broadcast reach
    attractionTTL    = 8000,    -- ms — how long a sighting pulse persists
    multiTargetBias  = 2.0,     -- exponent for distance weighting (closer = much more likely)

    swarmRadius      = 3.0,     -- m — clustering threshold
    swarmCountMin    = 3,       -- this many zombies on player = swarm active
    swarmDamageMult  = 1.25,    -- damage × this when swarming

    knockdownChance  = 0.25     -- brute only — chance to ragdoll on direct hit
}

-- ════════════════════════════════════════════════════════════════
-- Fear / immersion effects
-- ════════════════════════════════════════════════════════════════
Config.Fear = {
    -- Master toggle for the red fullscreen fear overlay.
    fearVignetteEnabled = false,
    renderWaitMs = 0,

    -- Screen vignette that intensifies as zombies get close.
    -- Distance maps linearly: vignetteMaxDist → 0 alpha,
    -- vignetteStartDist → maxAlpha (closer = redder tint).
    vignetteStartDist   = 5.0,
    vignetteMaxDist     = 30.0,
    vignetteMaxAlpha    = 64,
    vignetteColor       = { r = 90, g = 10, b = 10 },

    -- Heartbeat pulse + audio when zombies are close in numbers.
    heartbeatRadius     = 20.0,
    heartbeatMinZombies = 3,

    -- Eye glow — tiny red light at head bone. Night only.
    eyeGlowColor        = { r = 220, g = 20, b = 20 },
    eyeGlowRange        = 1.2,
    eyeGlowIntensity    = 3.0,
    eyeGlowNightOnly    = true,
    eyeGlowMaxDist      = 25.0,    -- m — skip for far zombies

    -- Dynamic light casting for specials (already have lightColor in types).
    lightDraw = {
        electric = { range = 4.0, intensity = 6.0 },
        burning  = { range = 6.0, intensity = 10.0 },
        toxic    = { range = 5.0, intensity = 7.0 }
    },
    lightDrawMaxDist    = 40.0,    -- m — skip far specials

    -- Safe zone exit cinematic cue.
    exitCue = {
        duration     = 3000,
        tintColor    = { r = 40, g = 30, b = 30, a = 45 },
        moanDelayMs  = 800
    },

    -- Ambient per-zombie moan via BUM_STANDING scenario (baked vocals).
    ambientMoan = {
        minInterval = 8000,
        maxInterval = 15000,
        maxRange    = 30.0    -- don't moan if no player within this
    }
}

-- ════════════════════════════════════════════════════════════════
-- Audio bindings (all vanilla frontend sounds; if any fail in
-- practice, wrap TODO to add stream/audio/*.wav drops-ins later).
-- ════════════════════════════════════════════════════════════════
Config.AudioBindings = {
    -- Played once on idle→chasing state transition (sight gained).
    snarl = {
        soundName = 'Growl',
        soundSet  = 'SCRIPT_DOGS_SOUNDS',
        throttleMs = 6000         -- per-zombie cooldown
    },
    -- Played on StartGrab.
    grabShriek = {
        soundName = 'Player_Pain_High',
        soundSet  = 'NY_MINIGAME_SOUNDSET',
        throttleMs = 3000
    },
    -- Short pulse drive when heartbeat active.
    heartbeat = {
        soundName = 'Beat',
        soundSet  = 'WastedSounds',
        cadenceMs = 900           -- time between pulses
    },
    -- Distant moan fired on safe-zone exit.
    distantMoan = {
        soundName = 'Growl',
        soundSet  = 'SCRIPT_DOGS_SOUNDS'
    }
}

Config.ToxicEffect = {
    coughDict = 'mp_player_intdrink',
    coughAnim = 'loop_bottle',
    coughDuration = 2500,
    screenFadeColor = { r = 70, g = 220, b = 60, a = 35 }
}

Config.GrabMechanic = {
    enabled = true,
    grabDistance = 1.7,
    grabChance = 0.35,
    grabDamage = 14,            -- was 8 — +75%
    grabDamageInterval = 900,
    escapeRequired = 10,        -- was 8
    escapeCooldown = 80,        -- was 100 — allows faster mashing
    grabCooldownTime = 6000
}

Config.LootSystem = {
    enabled = true,
    dropChance = 0.6,
    lootTables = {
        common = {
            chance = 0.60,
            items = {
                { name = 'cloth', min = 1, max = 3 },
                { name = 'scrap_metal', min = 1, max = 2 },
                { name = 'dirty_water', min = 1, max = 1 },
                { name = 'raw_meat', min = 1, max = 1 },
                { name = 'bandage', min = 1, max = 2 }
            }
        },
        uncommon = {
            chance = 0.20,
            items = {
                { name = 'herbs', min = 1, max = 2 },
                { name = 'duct_tape', min = 1, max = 1 },
                { name = 'canned_food', min = 1, max = 1 },
                { name = 'clean_water', min = 1, max = 1 },
                { name = 'pistol_ammo', min = 5, max = 15 }
            }
        },
        rare = {
            chance = 0.13,
            items = {
                { name = 'chemicals', min = 1, max = 1 },
                { name = 'antibiotics', min = 1, max = 1 },
                { name = 'painkillers', min = 1, max = 2 },
                { name = 'WEAPON_CERAMICPISTOL', min = 1, max = 1 },
                { name = 'WEAPON_PISTOL_MK2', min = 1, max = 1 }
            }
        },
        epic = {
            chance = 0.05,
            items = {
                { name = 'antidote', min = 1, max = 1 },
                { name = 'WEAPON_COMBATPDW', min = 1, max = 1 },
                { name = 'blueprint_pistol_ammo', min = 1, max = 1 }
            }
        },
        legendary = {
            chance = 0.02,
            items = {
                { name = 'blueprint_antidote', min = 1, max = 1 },
                { name = 'blueprint_medkit', min = 1, max = 1 },
                { name = 'WEAPON_TECPISTOL', min = 1, max = 1 }
            }
        }
    }
}

Config.Cleanup = {
    corpseLifetime = 30000,
}
