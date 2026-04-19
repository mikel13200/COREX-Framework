ZX = ZX or {}
ZX.Combat = {}

local COMBAT_FLAG_ALLOW_MOVE = 48
local COMBAT_FLAG_UPPER_BODY = 56
local DAMAGE_TIMING = 0.50

local function DCombat(msg)
    if Config and Config.DebugAnimations then
        print(('^6[COREX-ZOMBIES COMBAT] %s^0'):format(msg))
    end
end

local function GetFallbackAttackData()
    local walkerAnimSet = Config and Config.Animations and Config.Animations.walker or {}
    return {
        dict = walkerAnimSet.attackDict or (Config and Config.FallbackAttackDict),
        anim = 'short_90_punch',
        speed = 0.45,
        duration = 1000,
        damageTiming = 0.45,
        lungeScale = 1.0,
        animFlag = COMBAT_FLAG_ALLOW_MOVE,
        kind = 'fallback'
    }
end

local function BuildAttackData(animSet, chosen)
    if type(chosen) == 'table' then
        return {
            dict = chosen.dict or animSet.attackDict,
            anim = chosen.anim,
            speed = chosen.speed or animSet.playbackSpeed,
            duration = chosen.duration or animSet.attackDuration,
            damageTiming = chosen.damageTiming,
            lungeScale = chosen.lungeScale,
            animFlag = chosen.animFlag,
            kind = chosen.kind
        }
    end

    return {
        dict = animSet.attackDict,
        anim = chosen,
        speed = animSet.playbackSpeed,
        duration = animSet.attackDuration
    }
end

local function CloneTypeData(typeData)
    local copy = {}
    for key, value in pairs(typeData or {}) do
        copy[key] = value
    end
    return copy
end

function ZX.Combat.FaceTarget(zombie, targetPed, speed)
    if not DoesEntityExist(zombie) or not DoesEntityExist(targetPed) then return end

    local zombieCoords = GetEntityCoords(zombie)
    local targetCoords = GetEntityCoords(targetPed)
    local targetHeading = GetHeadingFromVector_2d(targetCoords.x - zombieCoords.x, targetCoords.y - zombieCoords.y)
    local currentHeading = GetEntityHeading(zombie)
    local diff = targetHeading - currentHeading

    if diff > 180 then diff = diff - 360 end
    if diff < -180 then diff = diff + 360 end

    local step = math.min(1.0, (speed or 10.0) * 0.016)
    if math.abs(diff) < 5.0 then
        SetEntityHeading(zombie, targetHeading)
    else
        SetEntityHeading(zombie, currentHeading + diff * step)
    end
end

function ZX.Combat.DoLunge(zombie, typeData)
    if not DoesEntityExist(zombie) then return end

    local combatCfg = Config and Config.ZombieCombat or {}
    local force = typeData.lungeForce or combatCfg.lungeForce or 5.0
    local zForce = typeData.lungeZForce or combatCfg.lungeZForce or 0.4
    local fwd = GetEntityForwardVector(zombie)

    SetEntityVelocity(zombie, fwd.x * force, fwd.y * force, zForce)
end

local function PlayAttackPtfx(zombie, typeData)
    if not typeData.attackPtfx then return end

    local dict = typeData.attackPtfx.dict
    local name = typeData.attackPtfx.name
    local scale = typeData.attackPtfx.scale or 0.5
    if not dict or not name then return end

    if not HasNamedPtfxAssetLoaded(dict) then
        RequestNamedPtfxAsset(dict)
        local timeoutAt = GetGameTimer() + 1500
        while not HasNamedPtfxAssetLoaded(dict) do
            if GetGameTimer() > timeoutAt then return end
            Wait(10)
        end
    end

    UseParticleFxAssetNextCall(dict)
    local boneIdx = GetPedBoneIndex(zombie, 0x67F1)
    local handle = StartParticleFxLoopedOnPedBone(name, zombie, 0.0, 0.3, 0.0, 0.0, 0.0, 0.0, boneIdx, scale, false, false, false)
    if handle and handle ~= 0 then
        SetTimeout(800, function()
            if DoesEntityExist(zombie) then
                StopParticleFxLooped(handle, false)
            end
        end)
    end
end

local function PickAttack(typeData)
    local animSet = Config.Animations[typeData.id or 'walker']
    if not animSet then return nil end

    local pool = animSet.attackAnims
    if type(pool) ~= 'table' or #pool == 0 then return nil end

    local chosen = pool[math.random(1, #pool)]
    return BuildAttackData(animSet, chosen)
end

function ZX.Combat.BeginAttack(zombieData, zombie, targetPed, typeData, now)
    local attackData = PickAttack(typeData) or GetFallbackAttackData()
    local dict = attackData.dict
    local anim = attackData.anim
    local speed = attackData.speed or 0.45
    local duration = attackData.duration or 1000

    if not dict or not anim or not RequestAnimDictSafe(dict) then
        DCombat(('BeginAttack fallback for %s'):format(typeData.id or '?'))
        attackData = GetFallbackAttackData()
        dict = attackData.dict
        anim = attackData.anim
        speed = attackData.speed
        duration = attackData.duration

        if not dict or not RequestAnimDictSafe(dict) then
            DCombat('BeginAttack failed: fallback dict missing')
            return false
        end
    end

    DCombat(('Attack: %s | %s | %s:%s speed=%.2f dur=%d'):format(
        typeData.id or '?',
        attackData.kind or 'swing',
        dict,
        anim,
        speed,
        duration
    ))

    ClearPedTasks(zombie)
    ZX.Combat.FaceTarget(zombie, targetPed, 20.0)

    local animFlag = attackData.animFlag or typeData.attackAnimFlag or COMBAT_FLAG_ALLOW_MOVE
    if animFlag == 'upper_body' then
        animFlag = COMBAT_FLAG_UPPER_BODY
    elseif animFlag == 'rooted' then
        animFlag = 0
    end

    TaskPlayAnim(zombie, dict, anim, speed, -speed, duration, animFlag, 0.0, false, false, false)

    local lungeTypeData = typeData
    if attackData.lungeScale and attackData.lungeScale ~= 1.0 then
        lungeTypeData = CloneTypeData(typeData)
        lungeTypeData.lungeForce = (typeData.lungeForce or ((Config.ZombieCombat and Config.ZombieCombat.lungeForce) or 5.0)) * attackData.lungeScale
        lungeTypeData.lungeZForce = (typeData.lungeZForce or ((Config.ZombieCombat and Config.ZombieCombat.lungeZForce) or 0.4))
            * math.min(1.25, 0.9 + ((attackData.lungeScale - 1.0) * 0.6))
    end

    if (attackData.lungeScale or 1.0) > 0.2 then
        ZX.Combat.DoLunge(zombie, lungeTypeData)
    else
        local velocity = GetEntityVelocity(zombie)
        SetEntityVelocity(zombie, 0.0, 0.0, velocity.z)
    end
    PlayAttackPtfx(zombie, typeData)

    if ZX.Audio and ZX.Audio.PlayAttackSound then
        ZX.Audio.PlayAttackSound(typeData.id)
    end

    local safeSpeed = (type(speed) == 'number' and speed > 0.01) and speed or 0.5
    local safeDuration = (type(duration) == 'number' and duration > 0) and duration or 500
    local totalMs = safeDuration / safeSpeed
    local damageTiming = attackData.damageTiming
    if type(damageTiming) ~= 'number' then
        damageTiming = DAMAGE_TIMING
    end
    damageTiming = math.max(0.15, math.min(0.85, damageTiming))

    zombieData.attackPhase = 'attacking'
    zombieData.attackPhaseEnd = now + totalMs
    zombieData.damageApplied = false
    zombieData.damageApplyAt = now + math.floor(totalMs * damageTiming)
    zombieData.currentAnim = anim
    zombieData.currentDict = dict
    zombieData.chosenAttackDict = dict
    zombieData.chosenAttackAnim = anim
    zombieData.currentAttackKind = attackData.kind or 'swing'

    return true
end

function ZX.Combat.TickAttack(zombieData, zombie, targetPed, typeData, now)
    if not DoesEntityExist(zombie) or not DoesEntityExist(targetPed) then
        ZX.Combat.Reset(zombieData)
        return
    end

    if not zombieData.damageApplied and now >= zombieData.damageApplyAt then
        zombieData.damageApplied = true

        local damage = typeData.damage
        local horde = Config.Horde
        if horde and CountZombiesNear then
            local playerCoords = GetEntityCoords(targetPed)
            local swarm = CountZombiesNear(playerCoords, horde.swarmRadius or 3.0)
            if swarm >= (horde.swarmCountMin or 3) then
                damage = math.floor(damage * (horde.swarmDamageMult or 1.25))
            end
        end

        ApplyDamageToPed(targetPed, damage, false)
        TriggerEvent('corex-survival:client:zombieHit', damage, typeData.id or 'walker')
        ApplySpecialOnHit(typeData, targetPed)
        DCombat(('Hit landed: %s dealt %d dmg (%s)'):format(
            typeData.id or '?',
            damage,
            zombieData.currentAttackKind or 'swing'
        ))

        if typeData.id == 'brute' then
            local fwd = GetEntityForwardVector(zombie)
            local knockForce = typeData.lungeForce or 6.0
            ApplyForceToEntity(targetPed, 3, fwd.x * knockForce, fwd.y * knockForce, 1.5, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
            ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.25)
        elseif typeData.knockback then
            local fwd = GetEntityForwardVector(zombie)
            ApplyForceToEntity(targetPed, 3, fwd.x * 5.0, fwd.y * 5.0, 0.8, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
        end

        if typeData.id == 'brute' and horde and math.random() < (horde.knockdownChance or 0.35) then
            SetPedToRagdoll(targetPed, 2000, 2000, 0, false, false, false)
        end

        if typeData.special == 'electric' then
            ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.15)
        elseif typeData.special == 'fire' then
            ShakeGameplayCam('JOLT_SHAKE', 0.1)
        end
    end

    ZX.Combat.FaceTarget(zombie, targetPed, 8.0)

    if now >= zombieData.attackPhaseEnd then
        ZX.Combat.BeginRecovery(zombieData, zombie, typeData, now)
    end
end

function ZX.Combat.BeginRecovery(zombieData, zombie, typeData, now)
    zombieData.attackPhase = 'recovery'

    local recoveryMs = typeData.recoveryMs
    if not recoveryMs then
        local combatCfg = Config.ZombieCombat
        recoveryMs = combatCfg and combatCfg.recoveryBaseMs or 400
    end

    zombieData.attackPhaseEnd = now + recoveryMs
    zombieData.lastAttack = now
end

function ZX.Combat.TickRecovery(zombieData, zombie, targetPed, typeData, now)
    if now >= zombieData.attackPhaseEnd then
        zombieData.attackPhase = 'none'
    end
end

function ZX.Combat.Process(zombieData, zombie, targetPed, typeData, now)
    local phase = zombieData.attackPhase or 'none'

    if phase == 'none' then
        if not ZX.Combat.ShouldAttack(zombieData, typeData, now) then
            return false
        end
        return ZX.Combat.BeginAttack(zombieData, zombie, targetPed, typeData, now)
    elseif phase == 'attacking' then
        ZX.Combat.TickAttack(zombieData, zombie, targetPed, typeData, now)
        return true
    elseif phase == 'recovery' then
        ZX.Combat.TickRecovery(zombieData, zombie, targetPed, typeData, now)
        return true
    end

    return false
end

function ZX.Combat.Reset(zombieData)
    zombieData.attackPhase = 'none'
    zombieData.attackPhaseEnd = 0
    zombieData.damageApplied = false
    zombieData.damageApplyAt = 0
    zombieData.currentAttackKind = nil
end

function ZX.Combat.IsBusy(zombieData)
    local phase = zombieData.attackPhase
    return phase == 'attacking' or phase == 'recovery'
end

function ZX.Combat.ShouldAttack(zombieData, typeData, now)
    if zombieData.attackPhase and zombieData.attackPhase ~= 'none' then
        return true
    end

    if now - (zombieData.lastAttack or 0) < (typeData.attackCooldown or 500) then
        return false
    end

    return true
end
