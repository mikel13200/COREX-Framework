Config = {}
Config.Debug = false

Config.MaxQueueSize = 3

Config.Categories = {
    { id = 'medical',   label = 'Medical',   icon = 'fa-kit-medical' },
    { id = 'food',      label = 'Food',      icon = 'fa-utensils' },
    { id = 'tools',     label = 'Tools',     icon = 'fa-wrench' },
    { id = 'weapons',   label = 'Weapons',   icon = 'fa-gun' },
    { id = 'ammo',      label = 'Ammo',      icon = 'fa-crosshairs' },
    { id = 'materials', label = 'Materials', icon = 'fa-cubes' }
}

Config.Recipes = {
    {
        id = 'craft_bandage',
        result = { name = 'bandage', count = 2 },
        materials = {
            { name = 'cloth', count = 2 }
        },
        duration = 5000,
        category = 'medical',
        requiresWorkbench = false,
        blueprint = false,
        label = 'Bandage',
        description = 'Basic wound dressing from cloth strips'
    },
    {
        id = 'craft_medkit',
        result = { name = 'medkit', count = 1 },
        materials = {
            { name = 'bandage', count = 2 },
            { name = 'antibiotics', count = 1 },
            { name = 'cloth', count = 1 }
        },
        duration = 15000,
        category = 'medical',
        requiresWorkbench = true,
        blueprint = true,
        label = 'Medkit',
        description = 'Full medical kit for emergency healing'
    },
    {
        id = 'craft_antidote',
        result = { name = 'antidote', count = 1 },
        materials = {
            { name = 'herbs', count = 3 },
            { name = 'chemicals', count = 1 }
        },
        duration = 20000,
        category = 'medical',
        requiresWorkbench = true,
        blueprint = true,
        label = 'Antidote',
        description = 'Cures zombie infection completely'
    },
    {
        id = 'craft_antibiotics',
        result = { name = 'antibiotics', count = 1 },
        materials = {
            { name = 'herbs', count = 2 },
            { name = 'chemicals', count = 1 }
        },
        duration = 12000,
        category = 'medical',
        requiresWorkbench = true,
        blueprint = false,
        label = 'Antibiotics',
        description = 'Reduces infection by 25%'
    },
    {
        id = 'craft_painkillers',
        result = { name = 'painkillers', count = 2 },
        materials = {
            { name = 'herbs', count = 1 },
            { name = 'chemicals', count = 1 }
        },
        duration = 8000,
        category = 'medical',
        requiresWorkbench = false,
        blueprint = false,
        label = 'Painkillers',
        description = 'Pauses infection growth temporarily'
    },
    {
        id = 'craft_clean_water',
        result = { name = 'clean_water', count = 1 },
        materials = {
            { name = 'dirty_water', count = 1 },
            { name = 'cloth', count = 1 }
        },
        duration = 6000,
        category = 'food',
        requiresWorkbench = false,
        blueprint = false,
        label = 'Clean Water',
        description = 'Filter dirty water through cloth'
    },
    {
        id = 'craft_cooked_meat',
        result = { name = 'cooked_meat', count = 1 },
        materials = {
            { name = 'raw_meat', count = 1 }
        },
        duration = 10000,
        category = 'food',
        requiresWorkbench = true,
        blueprint = false,
        label = 'Cooked Meat',
        description = 'Safely cooked meat with no infection risk'
    },
    {
        id = 'craft_pistol_ammo',
        result = { name = 'pistol_ammo', count = 15 },
        materials = {
            { name = 'scrap_metal', count = 2 },
            { name = 'chemicals', count = 1 }
        },
        duration = 12000,
        category = 'ammo',
        requiresWorkbench = true,
        blueprint = true,
        label = 'Pistol Ammo x15',
        description = 'Handcraft pistol ammunition'
    },
    {
        id = 'craft_smg_ammo',
        result = { name = 'smg_ammo', count = 20 },
        materials = {
            { name = 'scrap_metal', count = 3 },
            { name = 'chemicals', count = 1 }
        },
        duration = 15000,
        category = 'ammo',
        requiresWorkbench = true,
        blueprint = true,
        label = 'SMG Ammo x20',
        description = 'Handcraft SMG ammunition'
    },
    {
        id = 'craft_ceramic_pistol',
        result = { name = 'WEAPON_CERAMICPISTOL', count = 1 },
        materials = {
            { name = 'scrap_metal', count = 10 },
            { name = 'chemicals', count = 3 },
            { name = 'duct_tape', count = 2 }
        },
        duration = 45000,
        category = 'weapons',
        requiresWorkbench = true,
        blueprint = false,
        label = 'Ceramic Pistol',
        description = 'Compact firearm assembled from scarce weapon parts'
    },
    {
        id = 'craft_doubleaction',
        result = { name = 'WEAPON_DOUBLEACTION', count = 1 },
        materials = {
            { name = 'scrap_metal', count = 12 },
            { name = 'chemicals', count = 3 },
            { name = 'duct_tape', count = 2 }
        },
        duration = 50000,
        category = 'weapons',
        requiresWorkbench = true,
        blueprint = false,
        label = 'Double-Action Revolver',
        description = 'Reliable revolver with a costly metal frame'
    },
    {
        id = 'craft_gadget_pistol',
        result = { name = 'WEAPON_GADGETPISTOL', count = 1 },
        materials = {
            { name = 'scrap_metal', count = 14 },
            { name = 'chemicals', count = 4 },
            { name = 'duct_tape', count = 3 }
        },
        duration = 60000,
        category = 'weapons',
        requiresWorkbench = true,
        blueprint = false,
        label = 'Perico Pistol',
        description = 'Rare pistol craft requiring extra chemical treatment'
    },
    {
        id = 'craft_pistol_mk2',
        result = { name = 'WEAPON_PISTOL_MK2', count = 1 },
        materials = {
            { name = 'scrap_metal', count = 16 },
            { name = 'chemicals', count = 5 },
            { name = 'duct_tape', count = 3 }
        },
        duration = 70000,
        category = 'weapons',
        requiresWorkbench = true,
        blueprint = false,
        label = 'Pistol Mk II',
        description = 'Advanced pistol platform with a high crafting cost'
    },
    {
        id = 'craft_tecpistol',
        result = { name = 'WEAPON_TECPISTOL', count = 1 },
        materials = {
            { name = 'scrap_metal', count = 20 },
            { name = 'chemicals', count = 6 },
            { name = 'duct_tape', count = 4 }
        },
        duration = 85000,
        category = 'weapons',
        requiresWorkbench = true,
        blueprint = false,
        label = 'Tactical SMG',
        description = 'Fast-firing compact weapon for late survival runs'
    },
    {
        id = 'craft_combat_pdw',
        result = { name = 'WEAPON_COMBATPDW', count = 1 },
        materials = {
            { name = 'scrap_metal', count = 24 },
            { name = 'chemicals', count = 8 },
            { name = 'duct_tape', count = 5 }
        },
        duration = 100000,
        category = 'weapons',
        requiresWorkbench = true,
        blueprint = false,
        label = 'Combat PDW',
        description = 'High-tier firearm assembled from a large parts investment'
    },
    {
        id = 'craft_raypistol',
        result = { name = 'WEAPON_RAYPISTOL', count = 1 },
        materials = {
            { name = 'scrap_metal', count = 30 },
            { name = 'chemicals', count = 10 },
            { name = 'duct_tape', count = 6 }
        },
        duration = 120000,
        category = 'weapons',
        requiresWorkbench = true,
        blueprint = false,
        label = 'Up-n-Atomizer',
        description = 'Experimental weapon craft with extreme resource cost'
    },
    {
        id = 'craft_cloth',
        result = { name = 'cloth', count = 3 },
        materials = {
            { name = 'duct_tape', count = 1 }
        },
        duration = 4000,
        category = 'materials',
        requiresWorkbench = false,
        blueprint = false,
        label = 'Cloth x3',
        description = 'Recycle duct tape into cloth strips'
    }
}

Config.Workbenches = {
    {
        coords = vector3(1525.0, 1690.0, 110.5),
        heading = 180.0,
        radius = 2.5,
        model = 'prop_tool_bench02',
        label = 'Crafting Workbench',
        interactLabel = '[E] Use Workbench',
        icon = 'fa-hammer',
        blip = true
    }
}

Config.Notifications = {
    craftStarted = 'Crafting started...',
    craftComplete = 'Item ready! Open crafting to collect.',
    craftTaken = 'Item collected!',
    missingMaterials = 'Missing required materials',
    queueFull = 'Crafting queue is full (max %d)',
    needsWorkbench = 'This recipe requires a workbench',
    needsBlueprint = 'Blueprint required for this recipe',
    noSpace = 'No inventory space to collect item'
}
