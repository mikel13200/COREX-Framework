local counter = 0

local function makeId()
    counter = counter + 1
    return ('n%d_%d'):format(GetGameTimer(), counter)
end

local function sendConfig()
    SendNUIMessage({
        action = 'config',
        config = {
            maxVisible = Config.MaxVisible,
            animationDuration = Config.AnimationDuration,
            stackGap = Config.StackGap,
            width = Config.Width,
            types = Config.Types
        }
    })
end

local function pushNotify(data)
    SendNUIMessage({ action = 'show', notify = data })
end

local function playSound(type)
    if not Config.Sound or not Config.Sound.enabled then return end
    local soundName = Config.Sound.map and Config.Sound.map[type]
    if not soundName then return end
    PlaySoundFrontend(-1, soundName, 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end

local function ShowNotify(opts)
    if type(opts) ~= 'table' then return end

    local ntype = opts.type or 'info'
    if not Config.Types[ntype] then ntype = 'info' end

    local payload = {
        id = opts.id or makeId(),
        type = ntype,
        title = opts.title,
        message = opts.message or '',
        duration = tonumber(opts.duration) or Config.DefaultDuration,
        icon = opts.icon
    }

    pushNotify(payload)
    playSound(ntype)
end

local function DismissNotify(id)
    if not id then return end
    SendNUIMessage({ action = 'dismiss', id = id })
end

local function ClearAllNotifies()
    SendNUIMessage({ action = 'clear' })
end

RegisterNetEvent('corex:client:notify', function(message, ntype, duration, title)
    ShowNotify({
        type = ntype or 'info',
        title = title,
        message = message,
        duration = duration
    })
end)

CreateThread(function()
    Wait(500)
    sendConfig()
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Wait(200)
        sendConfig()
    end
end)

exports('Show', ShowNotify)
exports('ShowNotify', ShowNotify)
exports('Dismiss', DismissNotify)
exports('ClearAll', ClearAllNotifies)

RegisterCommand('testnotify', function(_, args)
    local ntype = args[1] or 'info'
    local title = args[2]
    local message = args[3] or ('Test notification type=' .. ntype)
    ShowNotify({ type = ntype, title = title, message = message })
end, false)
