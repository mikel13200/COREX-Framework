RedZoneEffects = {}

local currentAlpha = 0
local targetAlpha = 0
local audioThreadActive = false
local bannerText = nil
local bannerVisibleUntil = 0
local bannerPersistent = false

local function Lerp(a, b, t)
    return a + (b - a) * t
end

CreateThread(function()
    local lastTick = GetGameTimer()
    while true do
        if currentAlpha == 0 and currentAlpha == targetAlpha and not bannerText then
            Wait(250)
            lastTick = GetGameTimer()
            goto continue
        end

        local isFading = currentAlpha ~= targetAlpha
        Wait(isFading and 0 or 33)
        local now = GetGameTimer()
        local dt = (now - lastTick) / 1000.0
        lastTick = now

        if currentAlpha ~= targetAlpha then
            local fadeMs = targetAlpha > currentAlpha and Config.Vignette.fadeInMs or Config.Vignette.fadeOutMs
            local step = (targetAlpha - currentAlpha) * (dt / (fadeMs / 1000.0))
            if math.abs(step) < 1 then
                currentAlpha = targetAlpha
            else
                currentAlpha = math.floor(currentAlpha + step)
                if (step > 0 and currentAlpha > targetAlpha) or (step < 0 and currentAlpha < targetAlpha) then
                    currentAlpha = targetAlpha
                end
            end
        end

        if currentAlpha > 0 then
            local v = Config.Vignette
            DrawRect(0.5, 0.5, 1.0, 1.0, v.r, v.g, v.b, currentAlpha)
        end

        if bannerText and (bannerPersistent or now < bannerVisibleUntil) then
            local screenW, screenH = 0.5, 0.055
            local x, y = 0.5, 0.06

            DrawRect(x, y, screenW + 0.006, screenH + 0.006, 0, 0, 0, 200)
            DrawRect(x, y, screenW, screenH, 20, 0, 0, 230)
            DrawRect(x, y + (screenH / 2) + 0.001, screenW, 0.002, 200, 0, 0, 255)

            SetTextFont(4)
            SetTextScale(0.0, 0.45)
            SetTextColour(255, 220, 220, 255)
            SetTextCentre(true)
            SetTextDropshadow(1, 0, 0, 0, 200)
            SetTextEntry('STRING')
            AddTextComponentString(bannerText)
            DrawText(x, y - 0.018)
        elseif bannerText and not bannerPersistent and now >= bannerVisibleUntil then
            bannerText = nil
        end

        ::continue::
    end
end)

local function RunAudioLoop()
    if audioThreadActive then return end
    audioThreadActive = true
    CreateThread(function()
        while audioThreadActive do
            pcall(function()
                PlaySoundFrontend(-1, Config.Audio.soundName, Config.Audio.soundSet, true)
            end)
            Wait(Config.Audio.loopInterval)
        end
    end)
end

function RedZoneEffects.Enter(zoneName)
    targetAlpha = Config.Vignette.alpha
    bannerText = 'ENTERED RED ZONE — survival not guaranteed'
    bannerPersistent = true
    RunAudioLoop()
end

function RedZoneEffects.Exit()
    targetAlpha = 0
    audioThreadActive = false
    bannerText = 'Left Red Zone'
    bannerPersistent = false
    bannerVisibleUntil = GetGameTimer() + 3500
end

function RedZoneEffects.ForceClear()
    currentAlpha = 0
    targetAlpha = 0
    audioThreadActive = false
    bannerText = nil
    bannerPersistent = false
end
