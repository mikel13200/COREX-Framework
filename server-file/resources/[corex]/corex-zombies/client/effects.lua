-- ═══════════════════════════════════════════════════════════════
-- COREX Zombies · Effects (lights, eye glow, vignette, heartbeat,
--                           safe-zone exit cue)
--
-- All rendering + screen fx that make the zombies feel scary.
-- Thread is adaptive: Wait(0) only when something is drawing,
-- Wait(250) when idle. Guarded by on-screen / distance checks so
-- we don't light-cast every zombie in the world.
-- ═══════════════════════════════════════════════════════════════

ZX = ZX or {}
ZX.Effects = {}

-- Public flag: set by main.lua's safe-zone exit handler; effects
-- thread picks it up and draws the tint overlay for exitCue.duration.
local exitCueUntil = 0

local function Cfg() return (Config and Config.Fear) or {} end

-- Access to activeZombies / grabbingZombie / isGrabbed comes from main.lua
-- globals. They're defined there; we just read them.

-- ─── Special light draw ─────────────────────────────────────────
-- Per-frame DrawLightWithRange for electric/burning/toxic zombies
-- that are on-screen and within lightDrawMaxDist. Their lightColor
-- was defined in config but never rendered before.
local function DrawSpecialLights(playerCoords)
    local cfg = Cfg()
    local lightMap = cfg.lightDraw
    if not lightMap then return end
    local maxDist = cfg.lightDrawMaxDist or 40.0
    local max2 = maxDist * maxDist
    local now = GetGameTimer()

    for _, z in ipairs(activeZombies or {}) do
        if not z.isDead and DoesEntityExist(z.entity) then
            local td = z.typeData
            local lc = td and td.lightColor
            local lp = lc and lightMap[td.id or '']
            if lc and lp then
                local zc = GetEntityCoords(z.entity)
                local dx, dy, dz = zc.x - playerCoords.x, zc.y - playerCoords.y, zc.z - playerCoords.z
                local d2 = dx*dx + dy*dy + dz*dz
                if d2 <= max2 and IsEntityOnScreen(z.entity) then
                    local intensity = lp.intensity or 6.0
                    local range = lp.range or 4.0

                    if td.id == 'electric' then
                        local flicker = math.sin(now * 0.015) * 0.3 + math.sin(now * 0.037) * 0.2
                        intensity = intensity * (1.0 + flicker)
                    end

                    DrawLightWithRange(
                        zc.x, zc.y, zc.z + 0.9,
                        lc.r or 255, lc.g or 255, lc.b or 255,
                        range, intensity
                    )
                end
            end
        end
    end
end

-- ─── Eye glow at night ─────────────────────────────────────────
-- Tiny red light at head bone for on-screen zombies within a short
-- distance, only during night hours. Subtle but sells the undead feel.
local function DrawEyeGlow(playerCoords)
    local cfg = Cfg()
    local color = cfg.eyeGlowColor
    if not color then return end
    if cfg.eyeGlowNightOnly then
        local h = GetClockHours()
        if h < 22 and h >= 5 then return end
    end

    local maxDist = cfg.eyeGlowMaxDist or 25.0
    local max2 = maxDist * maxDist
    local range = cfg.eyeGlowRange or 1.2
    local intensity = cfg.eyeGlowIntensity or 3.0

    for _, z in ipairs(activeZombies or {}) do
        if not z.isDead and DoesEntityExist(z.entity) then
            local zc = GetEntityCoords(z.entity)
            local dx, dy, dz = zc.x - playerCoords.x, zc.y - playerCoords.y, zc.z - playerCoords.z
            local d2 = dx*dx + dy*dy + dz*dz
            if d2 <= max2 and IsEntityOnScreen(z.entity) then
                -- 0x796E = SKEL_Head bone hash — offset up 8cm for eye level.
                local head = GetPedBoneCoords(z.entity, 0x796E, 0.0, 0.08, 0.0)
                if head then
                    DrawLightWithRange(head.x, head.y, head.z, color.r, color.g, color.b, range, intensity)
                end
            end
        end
    end
end

-- ─── Fear vignette (distance-to-nearest-zombie + heartbeat) ────
-- Shared screen overlay. Max'd with toxic vignette (never stacked).
-- Used as data channel by main.lua's render pass (it draws toxic,
-- we add the fear layer on top once per frame if needed).
local function ComputeFearVignette(playerCoords)
    local cfg = Cfg()
    if cfg.fearVignetteEnabled == false then
        return 0
    end

    local startD = cfg.vignetteStartDist or 5.0     -- ≤ this → max alpha
    local maxD   = cfg.vignetteMaxDist or 30.0      -- ≥ this → 0 alpha
    local maxA   = cfg.vignetteMaxAlpha or 64

    local best = 99999.0
    local best2 = 99999.0 * 99999.0
    local maxD2 = maxD * maxD
    for _, z in ipairs(activeZombies or {}) do
        if not z.isDead and DoesEntityExist(z.entity) then
            local zc = GetEntityCoords(z.entity)
            local dx, dy, dz = zc.x - playerCoords.x, zc.y - playerCoords.y, zc.z - playerCoords.z
            local d2 = dx*dx + dy*dy + dz*dz
            if d2 < best2 then best2 = d2 end
        end
    end

    best = math.sqrt(best2)
    if best >= maxD then return 0 end
    if best <= startD then return maxA end
    -- Linear interpolate maxD→0, startD→maxA
    local t = (maxD - best) / (maxD - startD)
    return math.floor(maxA * t)
end

-- Heartbeat pulse modifier added on top of the base fear vignette.
-- Returns (addAlpha, audioIntensity 0-1) — caller applies both.
local function ComputeHeartbeat(playerCoords, now)
    local cfg = Cfg()
    local radius = cfg.heartbeatRadius or 20.0
    local minCount = cfg.heartbeatMinZombies or 3

    local count = 0
    if CountZombiesNear then
        count = CountZombiesNear(playerCoords, radius)
    end
    if count < minCount then return 0, 0.0 end

    -- Sin oscillation at ~1.1 Hz base, faster as count grows (up to 1.8 Hz).
    local rate = math.min(1.8, 1.1 + (count - minCount) * 0.1)
    local phase = (now * rate * 0.001) % (2 * math.pi)
    local pulse = (math.sin(phase) + 1) * 0.5   -- 0..1

    -- Heartbeat adds up to 32 extra alpha on top of fear vignette.
    return math.floor(pulse * 32), math.min(1.0, (count - minCount) / 6)
end

-- Trigger the safe-zone exit overlay for `Config.Fear.exitCue.duration`.
function ZX.Effects.StartExitCue()
    local cfg = Cfg()
    local d = (cfg.exitCue and cfg.exitCue.duration) or 3000
    exitCueUntil = GetGameTimer() + d
end

-- Render pass ────────────────────────────────────────────────────
CreateThread(function()
    while not Corex or not Corex.Functions do Wait(500) end

    while true do
        -- No active zombies AND no exit cue → idle slow tick.
        local hasZombies = activeZombies and #activeZombies > 0
        local hasExitCue = GetGameTimer() < exitCueUntil
        if not hasZombies and not hasExitCue then
            Wait(250)
            goto continue
        end

        local playerCoords = Corex.Functions.GetCoords()
        local now = GetGameTimer()

        -- Lights & eye glow (only iterate if we have zombies).
        if hasZombies then
            DrawSpecialLights(playerCoords)
            DrawEyeGlow(playerCoords)
        end

        -- Composite screen vignette: fear + heartbeat + exit cue.
        -- Pick max alpha across channels — never sum (would blind).
        local fearEnabled = Cfg().fearVignetteEnabled ~= false
        local baseAlpha = (hasZombies and fearEnabled) and ComputeFearVignette(playerCoords) or 0
        local hbAlpha, hbIntensity = 0, 0.0
        if hasZombies then
            hbAlpha, hbIntensity = ComputeHeartbeat(playerCoords, now)
        end
        local fearAlpha = math.max(baseAlpha, baseAlpha + hbAlpha)
        if fearEnabled and fearAlpha > 0 then
            local cfg = Cfg()
            local c = cfg.vignetteColor or { r = 90, g = 10, b = 10 }
            DrawRect(0.5, 0.5, 2.0, 2.0, c.r, c.g, c.b, fearAlpha)
        end

        -- Exit cue overlay (desaturated warm tint, 3s).
        if hasExitCue then
            local cfg = Cfg()
            local tc = (cfg.exitCue and cfg.exitCue.tintColor) or { r = 40, g = 30, b = 30, a = 45 }
            DrawRect(0.5, 0.5, 2.0, 2.0, tc.r, tc.g, tc.b, tc.a or 45)
        end

        -- Drive heartbeat audio via audio.lua when pulse is significant.
        if hbIntensity > 0.2 and ZX.Audio and ZX.Audio.PlayHeartbeat then
            ZX.Audio.PlayHeartbeat(hbIntensity, now)
        end

        Wait(33)
        ::continue::
    end
end)

-- Hook safe-zone exit to trigger exit cue + distant moan.
AddEventHandler('corex-zones:client:leftSafeZone', function(zone)
    ZX.Effects.StartExitCue()
    if ZX.Audio and ZX.Audio.PlayDistantMoan then
        local cfg = (Config and Config.Fear and Config.Fear.exitCue) or {}
        SetTimeout(cfg.moanDelayMs or 800, function()
            ZX.Audio.PlayDistantMoan()
        end)
    end
end)
