-- ═══════════════════════════════════════════════════════════════
-- COREX Zombies · Horde (threat signal system)
--
-- When any zombie spots a player, it broadcasts a "sighting pulse"
-- at its own coords. Other zombies within attractionRadius of an
-- unexpired pulse are considered "alerted" — they drop their idle
-- scenario and wake up for pursuit. Creates a natural horde effect
-- where the first contact ripples out to nearby idlers.
--
-- Pulses have a short TTL (Config.Horde.attractionTTL, default 8s)
-- so the ring buffer stays small. Expiry happens lazily on query.
-- ═══════════════════════════════════════════════════════════════

ZX = ZX or {}
ZX.Horde = {}

local pulses = {}

local function Cfg()
    return (Config and Config.Horde) or {}
end

function ZX.Horde.Broadcast(coords)
    if not coords then return end
    local cfg = Cfg()
    local ttl = cfg.attractionTTL or 8000
    pulses[#pulses + 1] = {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        expiresAt = GetGameTimer() + ttl
    }
end

function ZX.Horde.IsAlerted(coords, now)
    if not coords then return false end
    now = now or GetGameTimer()

    local cfg = Cfg()
    local radius = cfg.attractionRadius or 30.0
    local r2 = radius * radius

    -- Walk in reverse so table.remove is safe.
    local alerted = false
    for i = #pulses, 1, -1 do
        local p = pulses[i]
        if now >= p.expiresAt then
            table.remove(pulses, i)
        elseif not alerted then
            local dx, dy, dz = p.x - coords.x, p.y - coords.y, p.z - coords.z
            if (dx*dx + dy*dy + dz*dz) <= r2 then
                alerted = true
                -- Don't break — continue iterating so we still expire stale
                -- entries. The ring is small (<20 in practice).
            end
        end
    end

    return alerted
end

-- Diagnostic helper for debug commands.
function ZX.Horde.Count()
    local now = GetGameTimer()
    local live = 0
    for _, p in ipairs(pulses) do
        if now < p.expiresAt then live = live + 1 end
    end
    return live
end

-- Clear all pulses (used on resource stop).
function ZX.Horde.Clear()
    pulses = {}
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then ZX.Horde.Clear() end
end)
