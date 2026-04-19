--[[
    COREX Spawn - Configuration
]]

Config = {}
Config.Debug = false

-------------------------------------------------
-- Spawn Settings
-------------------------------------------------

-- موقع السبون للاعبين الجدد (أول مرة)  
Config.FirstSpawnLocation = {
    x = 1533.3060,
    y = 1688.2556,
    z = 113.3729,
    heading = 84.3444
}


-- موقع السبون العادي (بعد الموت أو إعادة الاتصال)
Config.DefaultSpawnLocation = {
    x = 1533.3060,
    y = 1688.2556,
    z = 113.3729,
    heading = 84.3444
}

-- هل يتم حفظ آخر موقع للاعب؟
Config.SaveLastLocation = true

-- الكاميرا يتم حسابها تلقائياً بناءً على موقع اللاعب

-------------------------------------------------
-- Character Model Defaults
-------------------------------------------------
Config.DefaultMaleModel = 'mp_m_freemode_01'
Config.DefaultFemaleModel = 'mp_f_freemode_01'

-------------------------------------------------
-- Clothing Categories (للربط مع UI)
-------------------------------------------------
Config.ClothingCategories = {
    { id = 'face', label = 'الوجه', icon = 'face' },
    { id = 'masks', label = 'الأقنعة', icon = 'masks' },
    { id = 'torso', label = 'الجذع', icon = 'accessibility_new' },
    { id = 'legs', label = 'الأرجل', icon = 'nordic_walking' },
    { id = 'shoes', label = 'الأحذية', icon = 'hiking' },
    { id = 'accessories', label = 'الإكسسوارات', icon = 'watch' }
}

-------------------------------------------------
-- Clothing Component IDs (GTA V)
-------------------------------------------------
-- 0 = Face, 1 = Mask, 2 = Hair, 3 = Torso, 4 = Legs
-- 5 = Bag, 6 = Shoes, 7 = Accessory, 8 = Undershirt
-- 9 = Kevlar, 10 = Badge, 11 = Overlay

Config.ClothingComponents = {
    face = 0,
    mask = 1,
    hair = 2,
    torso = 3,
    legs = 4,
    bags = 5,
    shoes = 6,
    accessory = 7,
    undershirt = 8,
    kevlar = 9,
    badge = 10,
    overlay = 11
}

-- Props (الإكسسوارات)
-- 0 = Hats, 1 = Glasses, 2 = Ears, 6 = Watches, 7 = Bracelets
Config.PropComponents = {
    hats = 0,
    glasses = 1,
    ears = 2,
    watches = 6,
    bracelets = 7
}
