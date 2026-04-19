-- ═══════════════════════════════════════════════════════════════
-- COREX Zombies · Audio (snarl, grab shriek, ambient moan,
--                        heartbeat, distant moan)
--
-- All PlaySound* calls are wrapped in pcall — vanilla sound set
-- names can vary by game build, and we'd rather no-op than crash.
--
-- TODO: When adding stream/audio/*.wav custom vocals, wire them
-- through ZX.Audio.* so call sites don't have to change.
-- ═══════════════════════════════════════════════════════════════

ZX = ZX or {}
ZX.Audio = {}

local function Cfg() return (Config and Config.AudioBindings) or {} end

local lastHeartbeatAt = 0

local TYPE_SOUNDS = {
    brute = { name = 'Explosion_1', set = 'HD_LIFE_SOUNDSET' },
    electric = { name = 'Spark_1', set = 'GTAO_FM_Events_Soundset' },
    burning = { name = 'Fire', set = 'HUD_FIRE_SOUNDSET' },
    toxic = { name = 'Cough_1', set = 'HUD_WASTED_SOUNDSET' }
}

function ZX.Audio.PlayAttackSound(typeId)
    local bind = TYPE_SOUNDS[typeId]
    if not bind then return end
    pcall(function()
        PlaySoundFrontend(-1, bind.name, bind.set, false)
    end)
end

-- ─── Snarl on sight ─────────────────────────────────────────────
-- Fires once when a zombie transitions idle → chasing. Per-zombie
-- throttle prevents spam when the player breaks/regains line of sight.
function ZX.Audio.PlaySnarl(zombie, zombieData, now)
    if not zombie or not DoesEntityExist(zombie) then return end
    local bind = Cfg().snarl
    if not bind then return end
    now = now or GetGameTimer()

    local throttle = bind.throttleMs or 6000
    if zombieData and (now - (zombieData.lastSnarlAt or 0)) < throttle then return end
    if zombieData then zombieData.lastSnarlAt = now end

    pcall(function()
        PlaySoundFromEntity(-1, bind.soundName, zombie, bind.soundSet, false, 0)
    end)
end

-- ─── Grab shriek ───────────────────────────────────────────────
-- One-shot on StartGrab. Audible at range.
function ZX.Audio.PlayGrabShriek(zombie)
    if not zombie or not DoesEntityExist(zombie) then return end
    local bind = Cfg().grabShriek
    if not bind then return end
    pcall(function()
        PlaySoundFromEntity(-1, bind.soundName, zombie, bind.soundSet, false, 0)
    end)
end

-- ─── Heartbeat pulse ───────────────────────────────────────────
-- Called by effects.lua when zombie swarm is close. Intensity 0..1
-- shortens cadence. Ignored if cadence hasn't elapsed yet.
function ZX.Audio.PlayHeartbeat(intensity, now)
    local bind = Cfg().heartbeat
    if not bind then return end
    now = now or GetGameTimer()
    local cadence = bind.cadenceMs or 900
    -- Higher intensity → shorter cadence (down to ~500ms).
    cadence = math.floor(cadence - (intensity or 0) * 400)
    if cadence < 400 then cadence = 400 end

    if (now - lastHeartbeatAt) < cadence then return end
    lastHeartbeatAt = now

    pcall(function()
        PlaySoundFrontend(-1, bind.soundName, bind.soundSet, false)
    end)
end

-- ─── Distant moan ──────────────────────────────────────────────
-- Fired on safe-zone exit. One-shot, plays as frontend so volume
-- is consistent regardless of camera position.
function ZX.Audio.PlayDistantMoan()
    local bind = Cfg().distantMoan
    if not bind then return end
    pcall(function()
        PlaySoundFrontend(-1, bind.soundName, bind.soundSet, false)
    end)
end

-- ─── Ambient per-zombie moan thread ────────────────────────────
-- Every 8-15s per zombie (seeded at spawn as zombieData.nextMoanAt),
-- if a player is within ambientMoan.maxRange, drop the zombie's
-- current task into WORLD_HUMAN_BUM_STANDING for ~2s then restore.
-- The scenario plays baked-in vocal mumbles — no stream needed.
CreateThread(function()
    while not Corex or not Corex.Functions do Wait(500) end

    while true do
        Wait(2000)

        local moan = (Config and Config.Fear and Config.Fear.ambientMoan) or nil
        if not moan then goto continue end
        if not activeZombies or #activeZombies == 0 then goto continue end

        local pc = Corex.Functions.GetCoords()
        local now = GetGameTimer()
        local maxRange2 = (moan.maxRange or 30.0) ^ 2

        for _, z in ipairs(activeZombies) do
            if not z.isDead and DoesEntityExist(z.entity) then
                -- ONLY moan when the main AI has explicitly put the zombie
                -- in 'idle_scenario' state. Do NOT run on 'idle' or nil —
                -- those are TRANSIENT states for fresh spawns and between
                -- tick boundaries. Running on those would hijack combat
                -- intent with a civilian scenario (WORLD_HUMAN_BUM_STANDING)
                -- and make the zombie stand around like an NPC.
                if z.state == 'idle_scenario' and now >= (z.nextMoanAt or 0) then
                    local zc = GetEntityCoords(z.entity)
                    local dx, dy, dz = zc.x - pc.x, zc.y - pc.y, zc.z - pc.z
                    if (dx*dx + dy*dy + dz*dz) <= maxRange2 then
                        -- Ped is already in a scenario (set by main.lua
                        -- EnterIdleScenario). Just reschedule the next check.
                        z.nextMoanAt = now + math.random(
                            moan.minInterval or 8000,
                            moan.maxInterval or 15000
                        )
                    else
                        z.nextMoanAt = now + math.random(6000, 12000)
                    end
                end
            end
        end

        ::continue::
    end
end)
