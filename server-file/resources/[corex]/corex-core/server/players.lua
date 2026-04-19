COREX = COREX or {}
Corex = COREX
COREX.Functions = COREX.Functions or {}
COREX.Player = COREX.Player or {}
COREX.Players = COREX.Players or {}
local Players = COREX.Players

local DEFAULT_STATS = {
    hunger = 100,
    thirst = 100,
    stress = 0,
    infection = 0
}

local DEFAULT_STATUS_METADATA = {
    poison = 0,
    poisoning = 0,
    bleeding = 0,
    sick = 0,
    cold = 0
}

local DEFAULT_MONEY = {
    cash = 0,
    bank = 0
}

local STAT_LIMITS = {
    hunger = { min = 0, max = 100 },
    thirst = { min = 0, max = 100 },
    stress = { min = 0, max = 100 },
    infection = { min = 0, max = 100 }
}

local STATEBAG_METADATA_KEYS = {
    hunger = true,
    thirst = true,
    stress = true,
    infection = true,
    poison = true,
    poisoning = true,
    bleeding = true,
    sick = true,
    cold = true,
    lifecycleState = true
}

local VALID_MONEY_TYPES = {
    cash = true,
    bank = true
}

local loadingPlayers = {}

local function ShallowCopy(value)
    if type(value) ~= 'table' then
        return value
    end

    local copy = {}
    for key, entry in pairs(value) do
        if type(entry) == 'table' then
            local subCopy = {}
            for subKey, subEntry in pairs(entry) do
                subCopy[subKey] = subEntry
            end
            copy[key] = subCopy
        else
            copy[key] = entry
        end
    end

    return copy
end

local function SafeDecodeTable(rawValue)
    if type(rawValue) == 'table' then
        return ShallowCopy(rawValue)
    end

    if type(rawValue) ~= 'string' or rawValue == '' then
        return {}
    end

    local ok, decoded = pcall(json.decode, rawValue)
    if not ok or type(decoded) ~= 'table' then
        return {}
    end

    return decoded
end

local function GetIdentifier(source, idType)
    idType = idType or 'license'
    local identifiers = GetPlayerIdentifiers(source)
    for _, id in ipairs(identifiers) do
        if string.find(id, idType .. ':') then
            return id
        end
    end
    return nil
end

COREX.Functions.GetIdentifier = GetIdentifier
COREX.GetIdentifier = GetIdentifier

local function ValidateMoney(money)
    money = money or {}
    for moneyType, defaultValue in pairs(DEFAULT_MONEY) do
        local currentValue = money[moneyType]
        if type(currentValue) ~= 'number' or currentValue ~= currentValue then
            money[moneyType] = defaultValue
        elseif currentValue < 0 then
            money[moneyType] = 0
        end
    end
    return money
end

local function ValidatePosition(value)
    if type(value) ~= 'table' then
        return nil
    end

    local x = tonumber(value.x)
    local y = tonumber(value.y)
    local z = tonumber(value.z)
    if not x or not y or not z then
        return nil
    end

    local heading = tonumber(value.heading)
    if not heading then
        heading = tonumber(value.w) or 0.0
    end

    return {
        x = x,
        y = y,
        z = z,
        heading = heading or 0.0
    }
end

local function ValidateMetadata(metadata, isNewPlayer)
    metadata = metadata or {}

    for stat, defaultValue in pairs(DEFAULT_STATS) do
        local currentValue = metadata[stat]
        if type(currentValue) ~= 'number' or currentValue ~= currentValue then
            metadata[stat] = defaultValue
        else
            local limits = STAT_LIMITS[stat]
            metadata[stat] = math.max(limits.min, math.min(limits.max, currentValue))
        end
    end

    if metadata.poisoning == nil and metadata.poison ~= nil then
        metadata.poisoning = ShallowCopy(metadata.poison)
    elseif metadata.poison == nil and metadata.poisoning ~= nil then
        metadata.poison = ShallowCopy(metadata.poisoning)
    end

    for key, defaultValue in pairs(DEFAULT_STATUS_METADATA) do
        if metadata[key] == nil then
            metadata[key] = defaultValue
        end
    end

    metadata.lastPosition = ValidatePosition(metadata.lastPosition)

    if metadata.lifecycleState ~= nil and type(metadata.lifecycleState) ~= 'string' then
        metadata.lifecycleState = nil
    end

    if isNewPlayer and metadata.lifecycleState == nil and Config and Config.DefaultPlayerState then
        metadata.lifecycleState = Config.DefaultPlayerState
    end

    return metadata
end

local function ExtractStateBagValue(key, value)
    if key == 'lifecycleState' then
        return type(value) == 'string' and value or (Config and Config.DefaultPlayerState or 'loading')
    end

    if type(value) == 'number' then
        return value
    end

    if type(value) == 'boolean' then
        return value and 100 or 0
    end

    if type(value) == 'table' then
        local numericKeys = { 'value', 'level', 'amount', 'severity', 'percent' }
        for _, numericKey in ipairs(numericKeys) do
            local entry = tonumber(value[numericKey])
            if entry then
                return entry
            end
        end

        if value.active ~= nil then
            return value.active and 100 or 0
        end

        return next(value) and 100 or 0
    end

    return 0
end

local function SyncMetaStateBagValue(pState, key, value)
    if not pState or not STATEBAG_METADATA_KEYS[key] then
        return
    end

    pState:set(key, ExtractStateBagValue(key, value), true)
end

local function SyncTrackedMetadataState(source, player)
    local pState = Player(source).state
    if not pState then
        return
    end

    for key in pairs(STATEBAG_METADATA_KEYS) do
        SyncMetaStateBagValue(pState, key, player.metadata[key])
    end
end

local function SyncPlayerState(source, player)
    local pState = Player(source).state
    if not pState then return end

    pState:set('identifier', player.identifier, true)
    pState:set('name', player.name, true)
    pState:set('isLoggedIn', true, true)
    pState:set('metadata', ShallowCopy(player.metadata), true)
    pState:set('money', ShallowCopy(player.money), true)

    SyncTrackedMetadataState(source, player)
end

local function MarkDirty(player)
    player.isDirty = true
end

function COREX.Player.Create(source, dbData, isNewPlayer)
    dbData = dbData or {}

    local identifier = dbData.identifier or GetIdentifier(source, 'license')
    if not identifier then
        print('^1[COREX] CRITICAL: Missing identifier for source ' .. source .. '^0')
        return nil
    end

    local money = ValidateMoney(SafeDecodeTable(dbData.money))
    if next(money) == nil then
        money = {
            cash = DEFAULT_MONEY.cash,
            bank = DEFAULT_MONEY.bank
        }
    end

    local metadata = ValidateMetadata(SafeDecodeTable(dbData.metadata), isNewPlayer)

    local newPlayer = {
        source = source,
        identifier = identifier,
        name = dbData.name or GetPlayerName(source),
        money = money,
        metadata = metadata,
        isBusy = false,
        isDirty = false,
        lastSave = os.time()
    }

    Players[source] = newPlayer
    loadingPlayers[source] = nil

    SyncPlayerState(source, newPlayer)

    if COREX.Debug then COREX.Debug.Info('^2[Player] Created: ' .. newPlayer.name .. '^0') end

    TriggerEvent('corex:server:playerReady', source, newPlayer)

    return newPlayer
end

function COREX.Player.Load(source)
    local identifier = GetIdentifier(source, 'license')
    if not identifier then
        print('^1[COREX] Cannot load player ' .. source .. ': No identifier^0')
        return
    end

    if loadingPlayers[source] then
        if COREX.Debug then COREX.Debug.Verbose('[Player] Load already in-flight for source ' .. source) end
        return
    end
    loadingPlayers[source] = true

    exports.oxmysql:query(
        'SELECT * FROM players WHERE identifier = ? LIMIT 1',
        { identifier },
        function(results)
            local dbData = results and results[1] or nil
            local isNewPlayer = false

            if dbData then
                dbData.money = SafeDecodeTable(dbData.money)
                dbData.metadata = SafeDecodeTable(dbData.metadata)
                print('^2[COREX] Loaded existing player: ' .. (dbData.name or identifier) .. '^0')
            else
                isNewPlayer = true
                local rawName = GetPlayerName(source) or 'Unknown'
                if #rawName > 50 then
                    rawName = string.sub(rawName, 1, 50)
                    if COREX.Debug then COREX.Debug.Warn('[Player] Name truncated to 50 chars: ' .. identifier) end
                end

                dbData = {
                    identifier = identifier,
                    name = rawName,
                    money = { cash = 100, bank = 500 },
                    metadata = ValidateMetadata({}, true)
                }

                exports.oxmysql:insert(
                    'INSERT INTO players (identifier, name, money, metadata) VALUES (?, ?, ?, ?)',
                    { identifier, dbData.name, json.encode(dbData.money), json.encode(dbData.metadata) }
                )

                print('^3[COREX] Created new player: ' .. dbData.name .. '^0')
            end

            COREX.Player.Create(source, dbData, isNewPlayer)
        end
    )
end

function COREX.Player.Get(source)
    return Players[source]
end

function COREX.Player.GetByIdentifier(identifier)
    for src, player in pairs(Players) do
        if player.identifier == identifier then
            return player
        end
    end
    return nil
end

function COREX.Player.GetPlayers()
    return Players
end

function COREX.Player.GetCount()
    local count = 0
    for _ in pairs(Players) do
        count = count + 1
    end
    return count
end

function COREX.Player.IsLoaded(source)
    return Players[source] ~= nil
end

function COREX.Player.GetName(source)
    local player = Players[source]
    return player and player.name or nil
end

function COREX.Player.GetPlayerIdentifier(source)
    local player = Players[source]
    return player and player.identifier or nil
end

function COREX.Player.Save(source, force)
    local player = Players[source]
    if not player then return end

    if not force and not player.isDirty then return end

    local safeMoney = json.encode(player.money)
    local safeMetadata = json.encode(ValidateMetadata(ShallowCopy(player.metadata), false))

    exports.oxmysql:execute([[
        INSERT INTO players (identifier, name, money, metadata)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            name = VALUES(name),
            money = VALUES(money),
            metadata = VALUES(metadata)
    ]], {
        player.identifier,
        player.name,
        safeMoney,
        safeMetadata
    }, function(affected)
        if affected then
            player.isDirty = false
            player.lastSave = os.time()
            if COREX.Debug then COREX.Debug.Verbose('[Player] Saved: ' .. player.name) end
        end
    end)
end

function COREX.Player.SaveAll(force)
    if next(Players) == nil then return end
    for src, _ in pairs(Players) do
        COREX.Player.Save(src, force)
    end
end

function COREX.Player.GetMoney(source, moneyType)
    local player = Players[source]
    if not player then
        return moneyType and 0 or ValidateMoney({})
    end

    if not moneyType then
        return {
            cash = player.money.cash,
            bank = player.money.bank
        }
    end

    return player.money[moneyType] or 0
end

function COREX.Player.SetMoney(source, moneyType, amount)
    local player = Players[source]
    if not player or not VALID_MONEY_TYPES[moneyType] then return false end
    if type(amount) ~= 'number' or amount ~= amount then return false end

    local maxMoney = Config.MaxMoney or 999999999
    local nextAmount = math.max(0, math.min(maxMoney, math.floor(amount + 0.0)))
    local oldAmount = player.money[moneyType] or 0
    player.money[moneyType] = nextAmount
    MarkDirty(player)

    local pState = Player(source).state
    if pState then
        pState:set('money', ShallowCopy(player.money), true)
    end

    TriggerEvent('corex:server:playerMoneyChanged', source, moneyType, oldAmount, nextAmount, 'set')
    return true
end

function COREX.Player.AddMoney(source, moneyType, amount)
    if type(amount) ~= 'number' or amount <= 0 or amount ~= amount then
        return false
    end

    local currentAmount = COREX.Player.GetMoney(source, moneyType)
    return COREX.Player.SetMoney(source, moneyType, currentAmount + amount)
end

function COREX.Player.RemoveMoney(source, moneyType, amount)
    if type(amount) ~= 'number' or amount <= 0 or amount ~= amount then
        return false
    end

    local currentAmount = COREX.Player.GetMoney(source, moneyType)
    if currentAmount < amount then
        return false
    end

    return COREX.Player.SetMoney(source, moneyType, currentAmount - amount)
end

function COREX.Player.HasMoney(source, moneyType, amount)
    amount = amount or 0
    return COREX.Player.GetMoney(source, moneyType) >= amount
end

local function IsValidAdminMoneyType(moneyType)
    return VALID_MONEY_TYPES[moneyType] == true
end

local function ParseAdminMoneyArgs(src, args)
    local target = tonumber(args[1])
    local moneyType = args[2]
    local amount = tonumber(args[3])

    if not target and src > 0 then
        target = src
        moneyType = args[1]
        amount = tonumber(args[2])
    end

    if not target or target < 1 then
        return nil, nil, nil, 'Invalid player id'
    end

    if not IsValidAdminMoneyType(moneyType) then
        return nil, nil, nil, 'Money type must be cash or bank'
    end

    if not amount or amount <= 0 or amount ~= amount then
        return nil, nil, nil, 'Amount must be a positive number'
    end

    return target, moneyType, math.floor(amount), nil
end

RegisterCommand('givemoney', function(src, args)
    local target, moneyType, amount, err = ParseAdminMoneyArgs(src, args or {})
    if err then
        print(('[COREX] givemoney failed: %s'):format(err))
        if src > 0 then
            TriggerClientEvent('corex:notify', src, 'Usage: /givemoney [id] cash|bank amount', 'error')
        end
        return
    end

    if not COREX.Player.AddMoney(target, moneyType, amount) then
        print(('[COREX] givemoney failed for player %s'):format(target))
        if src > 0 then
            TriggerClientEvent('corex:notify', src, 'Failed to give money', 'error')
        end
        return
    end

    COREX.Player.Save(target, false)
    print(('[COREX] Added %s %s to player %s'):format(amount, moneyType, target))
    if target > 0 then
        TriggerClientEvent('corex:notify', target, ('Received $%s %s'):format(amount, moneyType), 'money')
    end
end, true)

RegisterCommand('setmoney', function(src, args)
    local target, moneyType, amount, err = ParseAdminMoneyArgs(src, args or {})
    if err then
        print(('[COREX] setmoney failed: %s'):format(err))
        if src > 0 then
            TriggerClientEvent('corex:notify', src, 'Usage: /setmoney [id] cash|bank amount', 'error')
        end
        return
    end

    if not COREX.Player.SetMoney(target, moneyType, amount) then
        print(('[COREX] setmoney failed for player %s'):format(target))
        if src > 0 then
            TriggerClientEvent('corex:notify', src, 'Failed to set money', 'error')
        end
        return
    end

    COREX.Player.Save(target, false)
    print(('[COREX] Set player %s %s to %s'):format(target, moneyType, amount))
    if target > 0 then
        TriggerClientEvent('corex:notify', target, ('%s set to $%s'):format(moneyType, amount), 'money')
    end
end, true)

function COREX.Player.SetBusy(source, state)
    local player = Players[source]
    if player then
        player.isBusy = state
        local pState = Player(source).state
        if pState then
            pState:set('isBusy', state, true)
        end
    end
end

function COREX.Player.TrySetBusy(source)
    local player = Players[source]
    if not player or player.isBusy then
        return false
    end

    COREX.Player.SetBusy(source, true)
    return true
end

function COREX.Player.ClearBusy(source)
    COREX.Player.SetBusy(source, false)
end

function COREX.Player.IsBusy(source)
    local player = Players[source]
    return player and player.isBusy or false
end

function COREX.Player.SetMetaData(source, key, value)
    local player = Players[source]
    if not player or type(key) ~= 'string' then return false end

    local oldValue = player.metadata[key]
    local safeValue = ShallowCopy(value)

    if key == 'lastPosition' then
        safeValue = ValidatePosition(safeValue)
    elseif key == 'lifecycleState' then
        if safeValue ~= nil and type(safeValue) ~= 'string' then
            return false
        end
    elseif STAT_LIMITS[key] then
        if type(safeValue) ~= 'number' or safeValue ~= safeValue then
            return false
        end
        local limits = STAT_LIMITS[key]
        safeValue = math.max(limits.min, math.min(limits.max, safeValue))
    end

    if key == 'poison' or key == 'poisoning' then
        player.metadata.poison = safeValue
        player.metadata.poisoning = safeValue
    else
        player.metadata[key] = safeValue
    end

    player.metadata = ValidateMetadata(player.metadata, false)
    MarkDirty(player)

    local pState = Player(source).state
    if pState then
        pState:set('metadata', ShallowCopy(player.metadata), true)

        if key == 'poison' or key == 'poisoning' then
            SyncMetaStateBagValue(pState, 'poison', player.metadata.poison)
            SyncMetaStateBagValue(pState, 'poisoning', player.metadata.poisoning)
        else
            SyncMetaStateBagValue(pState, key, player.metadata[key])
        end
    end

    TriggerEvent('corex:server:playerMetaDataChanged', source, key, player.metadata[key], oldValue)
    return true
end

function COREX.Player.GetMetaData(source, key)
    local player = Players[source]
    if not player then return nil end

    if key == nil then
        return ShallowCopy(player.metadata)
    end

    return player.metadata[key]
end

function COREX.Player.GetStat(source, statName)
    if not DEFAULT_STATS[statName] then
        return nil
    end

    local player = Players[source]
    if not player then
        return DEFAULT_STATS[statName]
    end

    local currentValue = player.metadata[statName]
    if type(currentValue) ~= 'number' then
        return DEFAULT_STATS[statName]
    end

    return currentValue
end

function COREX.Player.SetStat(source, statName, value)
    local limits = STAT_LIMITS[statName]
    if not limits or type(value) ~= 'number' or value ~= value then
        return false
    end

    local clampedValue = math.max(limits.min, math.min(limits.max, value))
    return COREX.Player.SetMetaData(source, statName, clampedValue)
end

function COREX.Player.AddStat(source, statName, delta)
    if type(delta) ~= 'number' or delta ~= delta then
        return false
    end

    local currentValue = COREX.Player.GetStat(source, statName)
    if currentValue == nil then
        return false
    end

    return COREX.Player.SetStat(source, statName, currentValue + delta)
end

exports('GetPlayer', function(...) return COREX.Player.Get(...) end)
exports('GetPlayers', function(...) return COREX.Player.GetPlayers(...) end)
exports('GetPlayerById', function(...) return COREX.Player.GetByIdentifier(...) end)
exports('GetMoney', function(...) return COREX.Player.GetMoney(...) end)
exports('AddMoney', function(...) return COREX.Player.AddMoney(...) end)
exports('RemoveMoney', function(...) return COREX.Player.RemoveMoney(...) end)
exports('HasMoney', function(...) return COREX.Player.HasMoney(...) end)
exports('GetStat', function(...) return COREX.Player.GetStat(...) end)
exports('SetStat', function(...) return COREX.Player.SetStat(...) end)
exports('AddStat', function(...) return COREX.Player.AddStat(...) end)
exports('SetBusy', function(...) return COREX.Player.SetBusy(...) end)
exports('TrySetBusy', function(...) return COREX.Player.TrySetBusy(...) end)
exports('ClearBusy', function(...) return COREX.Player.ClearBusy(...) end)
exports('IsBusy', function(...) return COREX.Player.IsBusy(...) end)
exports('SavePlayer', function(...) return COREX.Player.Save(...) end)
exports('SetMetaData', function(...) return COREX.Player.SetMetaData(...) end)
exports('GetMetaData', function(...) return COREX.Player.GetMetaData(...) end)

COREX.Functions.GetPlayers = COREX.Player.GetPlayers
COREX.Functions.GetPlayer = COREX.Player.Get
COREX.Functions.GetPlayerByIdentifier = COREX.Player.GetByIdentifier
COREX.Functions.GetPlayerCount = COREX.Player.GetCount
COREX.Functions.IsPlayerLoaded = COREX.Player.IsLoaded
COREX.Functions.GetPlayerName = COREX.Player.GetName
COREX.Functions.GetPlayerIdentifier = COREX.Player.GetPlayerIdentifier
COREX.Functions.GetMoney = COREX.Player.GetMoney
COREX.Functions.SetMoney = COREX.Player.SetMoney
COREX.Functions.AddMoney = COREX.Player.AddMoney
COREX.Functions.RemoveMoney = COREX.Player.RemoveMoney
COREX.Functions.HasMoney = COREX.Player.HasMoney
COREX.Functions.GetStat = COREX.Player.GetStat
COREX.Functions.SetStat = COREX.Player.SetStat
COREX.Functions.AddStat = COREX.Player.AddStat
COREX.Functions.SetBusy = COREX.Player.SetBusy
COREX.Functions.TrySetBusy = COREX.Player.TrySetBusy
COREX.Functions.ClearBusy = COREX.Player.ClearBusy
COREX.Functions.IsBusy = COREX.Player.IsBusy
COREX.Functions.SavePlayer = COREX.Player.Save
COREX.Functions.SetMetaData = COREX.Player.SetMetaData
COREX.Functions.GetMetaData = COREX.Player.GetMetaData

CreateThread(function()
    while true do
        Wait(300000)
        COREX.Player.SaveAll(false)
    end
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    local player = Players[src]
    if player then
        COREX.Player.Save(src, true)
        Players[src] = nil
        loadingPlayers[src] = nil
        print('^3[COREX] Player Dropped: ' .. src .. ' (' .. reason .. ')^0')
    end
end)

AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local src = source
    local identifier = GetIdentifier(src, 'license')

    if not identifier then
        setKickReason('Unable to retrieve player identifier.')
        CancelEvent()
        return
    end

    if not Config.AllowMultiSession then
        local existing = COREX.Player.GetByIdentifier(identifier)
        if existing then
            setKickReason('You are already connected to this server.')
            CancelEvent()
            return
        end
    end
end)

RegisterNetEvent('corex:server:loadPlayer', function()
    local src = source
    if src == 0 or src == nil then return end

    local ids = GetPlayerIdentifiers(src)
    if not ids or #ids == 0 then return end

    if not Config.AllowMultiSession then
        local identifier = GetIdentifier(src, 'license')
        if identifier then
            local existing = COREX.Player.GetByIdentifier(identifier)
            if existing and existing.source ~= src then
                DropPlayer(src, 'Already connected to this server')
                return
            end
        end
    end

    if Players[src] then
        TriggerEvent('corex:server:playerReady', src, Players[src])
    else
        COREX.Player.Load(src)
    end
end)
