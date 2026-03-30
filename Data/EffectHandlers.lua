-- ---------------------------------------------------------------------------
-- WarbandTD — Data/EffectHandlers.lua
-- Tower attack processing, enemy modifier processing, and boss mechanics.
-- Ported from tower_effects.dart, enemy_effects.dart, boss_effects.dart.
-- ---------------------------------------------------------------------------

local _, ns = ...

-- ---------------------------------------------------------------------------
-- Helper: find first effect of a given type
-- ---------------------------------------------------------------------------

local function FindEffect(effects, effectType)
    for _, eff in ipairs(effects) do
        if eff.type == effectType then return eff end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Tower Attack Processing
-- ---------------------------------------------------------------------------

ns.TowerEffects = {}

--- Process a single tower attack. Returns a result table with hits, status
--- effects, and flags.
--- @return table {hits, statusEffects, isCharging, didCrit, hasCrossLaneHit}
function ns.TowerEffects.ProcessAttack(params)
    local archetype = params.archetype
    local classDef = params.classDef
    local towerLane = params.towerLane
    local towerPosition = params.towerPosition
    local attackRange = params.attackRange
    local enemies = params.enemies       -- array of {id, hp, position, lane}
    local baseDamage = params.baseDamage
    local attackCount = params.attackCount
    local chargeTimer = params.chargeTimer
    local rng = params.rng or math.random
    local targetingOverride = params.targetingOverride

    -- Support towers don't attack
    if archetype == "support" then
        return { hits = {}, statusEffects = {}, isCharging = false, didCrit = false }
    end

    local passiveEffects = classDef.passive.effects or {}
    local trigger = classDef.passive.trigger or "passive"

    -- 1. Check charge_attack
    local chargeEffect = FindEffect(passiveEffects, "charge_attack")
    if chargeEffect then
        local chargeTime = chargeEffect.chargeTime or 3.0
        if chargeTimer < chargeTime then
            return { hits = {}, statusEffects = {}, isCharging = true, didCrit = false }
        end
    end

    -- 2. Determine active effects this attack
    local activeEffects = {}
    if trigger == "on_attack" then
        for _, e in ipairs(passiveEffects) do activeEffects[#activeEffects + 1] = e end
    elseif trigger == "on_nth_attack" then
        local nth = classDef.passive.nth or 0
        if nth > 0 and attackCount > 0 and attackCount % nth == 0 then
            for _, e in ipairs(passiveEffects) do activeEffects[#activeEffects + 1] = e end
        end
    elseif trigger == "passive" then
        for _, e in ipairs(passiveEffects) do activeEffects[#activeEffects + 1] = e end
    end

    -- 3. Filter candidates by lane (+ cross-lane)
    local crossLane = FindEffect(activeEffects, "cross_lane_attack")
    local crossRange = crossLane and (crossLane.value or 0) or 0

    local candidates = {}
    for _, e in ipairs(enemies) do
        local laneDist = math.abs(e.lane - towerLane)
        if crossRange > 0 then
            if laneDist <= crossRange then
                candidates[#candidates + 1] = e
            end
        else
            if e.lane == towerLane then
                candidates[#candidates + 1] = e
            end
        end
    end

    -- 3b. Filter by attack range
    if attackRange > 0 then
        local ranged = {}
        for _, e in ipairs(candidates) do
            if math.abs(e.position - towerPosition) <= attackRange then
                ranged[#ranged + 1] = e
            end
        end
        candidates = ranged
    end

    if #candidates == 0 then
        return { hits = {}, statusEffects = {}, isCharging = false, didCrit = false }
    end

    -- 4. Check chain_damage (overrides normal targeting)
    local chainEffect = FindEffect(activeEffects, "chain_damage")
    if chainEffect then
        return ns.TowerEffects._ProcessChainDamage(
            chainEffect, candidates, baseDamage, towerLane,
            activeEffects, chargeEffect, rng
        )
    end

    -- 5. Normal targeting based on archetype
    local targets = {}

    if targetingOverride == "highest_hp_any_lane" then
        -- Voidform targeting: highest HP enemy in any lane within range
        local allInRange = {}
        for _, e in ipairs(enemies) do
            if e.hp > 0 and (attackRange <= 0 or math.abs(e.position - towerPosition) <= attackRange) then
                allInRange[#allInRange + 1] = e
            end
        end
        table.sort(allInRange, function(a, b) return a.hp > b.hp end)
        if #allInRange > 0 then targets[1] = allInRange[1] end
    elseif archetype == "melee" then
        table.sort(candidates, function(a, b) return a.position > b.position end)
        targets[1] = candidates[1]
    elseif archetype == "ranged" then
        table.sort(candidates, function(a, b) return a.position < b.position end)
        targets[1] = candidates[1]
    elseif archetype == "aoe" then
        for _, e in ipairs(candidates) do targets[#targets + 1] = e end
    end

    if #targets == 0 then
        return { hits = {}, statusEffects = {}, isCharging = false, didCrit = false }
    end

    -- 6. Apply extra_targets
    local extraEffect = FindEffect(activeEffects, "extra_targets")
    if extraEffect and #targets == 1 then
        local extraCount = math.floor(extraEffect.value or 0)
        local added = 0
        for _, e in ipairs(candidates) do
            if e.id ~= targets[1].id and added < extraCount then
                targets[#targets + 1] = e
                added = added + 1
            end
        end
    end

    -- 7. Compute damage multipliers
    local damage = baseDamage
    local didCrit = false

    if chargeEffect then
        damage = damage * (chargeEffect.multiplier or 1)
    end

    for _, eff in ipairs(activeEffects) do
        if eff.type == "damage_multiplier" then
            damage = damage * (eff.value or 1)
        end
    end

    local critEffect = FindEffect(activeEffects, "crit_chance")
    if critEffect then
        if rng() < (critEffect.chance or 0) then
            damage = damage * (critEffect.multiplier or 2)
            didCrit = true
        end
    end

    -- 8. Build hits
    local hits = {}
    local hasCrossLaneHit = false
    for _, e in ipairs(targets) do
        hits[#hits + 1] = {
            enemyId = e.id,
            damage = damage,
            enemyLane = e.lane,
            enemyPosition = e.position,
        }
        if e.lane ~= towerLane and targetingOverride == nil then
            hasCrossLaneHit = true
        end
    end

    -- 9. Build status effects (slow, dot)
    local statusEffects = {}
    for _, eff in ipairs(activeEffects) do
        if eff.type == "slow_enemy" then
            for _, t in ipairs(targets) do
                statusEffects[#statusEffects + 1] = {
                    type = "slow",
                    sourceId = t.id,
                    value = eff.value or 0,
                    remaining = eff.duration or 0,
                }
            end
        elseif eff.type == "dot" then
            local dotValue = eff.value or 0
            local duration = eff.duration or 3.0
            local ticks = eff.ticks or 3
            local dotDamage = baseDamage * dotValue
            local tickInterval = ticks > 0 and (duration / ticks) or 1.0
            for _, t in ipairs(targets) do
                statusEffects[#statusEffects + 1] = {
                    type = "dot",
                    sourceId = t.id,
                    dotDamage = dotDamage,
                    tickInterval = tickInterval,
                    remaining = duration,
                }
            end
        end
    end

    return {
        hits = hits,
        statusEffects = statusEffects,
        isCharging = false,
        didCrit = didCrit,
        hasCrossLaneHit = hasCrossLaneHit,
    }
end

--- Process chain damage (Shaman).
function ns.TowerEffects._ProcessChainDamage(chainEffect, enemies, baseDamage,
        towerLane, activeEffects, chargeEffect, rng)
    local bounces = chainEffect.bounces or {1.0}
    table.sort(enemies, function(a, b) return a.position > b.position end)

    local damage = baseDamage
    local didCrit = false

    if chargeEffect then
        damage = damage * (chargeEffect.multiplier or 1)
    end

    for _, eff in ipairs(activeEffects) do
        if eff.type == "damage_multiplier" then
            damage = damage * (eff.value or 1)
        end
    end

    local critEffect = FindEffect(activeEffects, "crit_chance")
    if critEffect then
        if rng() < (critEffect.chance or 0) then
            damage = damage * (critEffect.multiplier or 2)
            didCrit = true
        end
    end

    local hits = {}
    for i = 1, math.min(#bounces, #enemies) do
        local e = enemies[i]
        hits[#hits + 1] = {
            enemyId = e.id,
            damage = damage * bounces[i],
            enemyLane = e.lane,
            enemyPosition = e.position,
        }
    end

    return {
        hits = hits,
        statusEffects = {},
        isCharging = false,
        didCrit = didCrit,
        hasCrossLaneHit = false,
    }
end

-- ---------------------------------------------------------------------------
-- Enemy Effect Processing
-- ---------------------------------------------------------------------------

ns.EnemyEffects = {}

--- Initialize modifier state when an enemy spawns.
function ns.EnemyEffects.InitModifierState(modifiers)
    local state = {}
    for _, mod in ipairs(modifiers) do
        if mod.type == "shield" then
            state.shield_hits = mod.hits or 0
        elseif mod.type == "phase" then
            state.phase_timer = 0
            state.phase_invuln = false
        elseif mod.type == "lane_switch" then
            state.has_switched = false
        elseif mod.type == "resurrect" then
            state.has_resurrected = false
        elseif mod.type == "ranged_attack" then
            state.attack_timer = 0
        end
    end
    return state
end

--- Modify incoming damage based on enemy modifiers.
function ns.EnemyEffects.ModifyDamage(modifiers, state, rawDamage, position)
    local damage = rawDamage
    for _, mod in ipairs(modifiers) do
        if mod.type == "spectral" then
            local reduction = mod.dmgReduction or mod.damageReduction or 0.5
            local threshold = mod.untilPosition or 0.5
            if position < threshold then
                damage = damage * (1.0 - reduction)
            end
        elseif mod.type == "shield" then
            local remaining = state.shield_hits or 0
            if remaining > 0 then
                state.shield_hits = remaining - 1
                return 0
            end
        elseif mod.type == "phase" then
            if state.phase_invuln then
                return 0
            end
        end
    end
    return damage
end

-- ---------------------------------------------------------------------------
-- Boss Effect Processing
-- ---------------------------------------------------------------------------

ns.BossEffects = {}

--- Initialize boss state.
function ns.BossEffects.InitState(modifiers)
    local state = {}
    for _, mod in ipairs(modifiers) do
        if mod.type == "fire_zone" then
            state.fire_zone_timer = 0
        elseif mod.type == "teleport_lanes" then
            state.teleport_timer = 0
        elseif mod.type == "enrage" then
            state.enraged = false
        elseif mod.type == "summon_adds" then
            state.summon_timer = 0
        elseif mod.type == "reflect_damage" then
            state.reflect_timer = 0
            state.reflect_active = false
        elseif mod.type == "knockback_tower" then
            state.knockback_timer = 0
        elseif mod.type == "stacking_damage" then
            state.stacking_elapsed = 0
        elseif mod.type == "wind_push" then
            state.wind_timer = 0
        end
    end
    return state
end

--- Process boss mechanics each tick. Returns array of event tables.
function ns.BossEffects.ProcessTick(modifiers, state, bossHpFraction, bossLane,
        towerCount, dt, rng)
    local events = {}
    rng = rng or math.random

    for _, mod in ipairs(modifiers) do
        if mod.type == "fire_zone" then
            local interval = mod.interval or 5.0
            local duration = mod.duration or 3.0
            state.fire_zone_timer = (state.fire_zone_timer or 0) + dt
            if state.fire_zone_timer >= interval then
                state.fire_zone_timer = 0
                events[#events + 1] = {
                    type = "fire_zone",
                    laneIndex = math.random(0, 2),
                    duration = duration,
                }
            end

        elseif mod.type == "teleport_lanes" then
            local interval = mod.interval or 4.0
            state.teleport_timer = (state.teleport_timer or 0) + dt
            if state.teleport_timer >= interval then
                state.teleport_timer = 0
                local newLane
                repeat newLane = math.random(0, 2) until newLane ~= bossLane
                events[#events + 1] = { type = "teleport", newLane = newLane }
            end

        elseif mod.type == "enrage" then
            local threshold = mod.hpThreshold or 0.3
            local speedMult = mod.speedMultiplier or 2.0
            if not state.enraged and bossHpFraction <= threshold then
                state.enraged = true
                state.enrage_speed_mult = speedMult
                events[#events + 1] = { type = "enrage", speedMult = speedMult }
            end

        elseif mod.type == "summon_adds" then
            local interval = mod.interval or 6.0
            local count = mod.count or 2
            local hpFrac = mod.hpFraction or 0.2
            state.summon_timer = (state.summon_timer or 0) + dt
            if state.summon_timer >= interval then
                state.summon_timer = 0
                for _ = 1, count do
                    events[#events + 1] = {
                        type = "spawn_add",
                        hpFraction = hpFrac,
                        speed = 0.10 + rng() * 0.05,
                        laneIndex = math.random(0, 2),
                    }
                end
            end

        elseif mod.type == "reflect_damage" then
            local interval = mod.interval or 6.0
            local duration = mod.duration or 2.0
            state.reflect_timer = (state.reflect_timer or 0) + dt
            if state.reflect_active then
                if state.reflect_timer >= duration then
                    state.reflect_active = false
                    state.reflect_timer = 0
                    events[#events + 1] = { type = "reflect_toggle", active = false }
                end
            else
                if state.reflect_timer >= interval then
                    state.reflect_active = true
                    state.reflect_timer = 0
                    events[#events + 1] = { type = "reflect_toggle", active = true }
                end
            end

        elseif mod.type == "knockback_tower" then
            local interval = mod.interval or 5.0
            state.knockback_timer = (state.knockback_timer or 0) + dt
            if state.knockback_timer >= interval and towerCount > 0 then
                state.knockback_timer = 0
                events[#events + 1] = {
                    type = "knockback_tower",
                    towerIndex = math.random(1, towerCount),
                    newLane = math.random(0, 2),
                }
            end

        elseif mod.type == "wind_push" then
            local interval = mod.interval or 4.0
            local pushAmount = mod.pushAmount or 0.3
            state.wind_timer = (state.wind_timer or 0) + dt
            if state.wind_timer >= interval then
                state.wind_timer = 0
                events[#events + 1] = {
                    type = "wind_push",
                    laneIndex = math.random(0, 2),
                    pushAmount = pushAmount,
                }
            end

        elseif mod.type == "stacking_damage" then
            local dps = mod.damagePerSecond or 2.0
            local rampRate = mod.rampRate or 1.5
            state.stacking_elapsed = (state.stacking_elapsed or 0) + dt
            local currentDps = dps * (1 + state.stacking_elapsed * rampRate * 0.1)
            events[#events + 1] = {
                type = "stacking_damage",
                damagePerTower = currentDps * dt,
            }
        end
    end

    return events
end

--- Process boss death (split_on_death).
function ns.BossEffects.ProcessOnDeath(modifiers, bossMaxHp, bossSpeed, bossLane, bossPosition)
    for _, mod in ipairs(modifiers) do
        if mod.type == "split_on_death" then
            local count = mod.count or 3
            local hpFrac = mod.hpFraction or 0.3
            return {
                type = "split",
                count = count,
                hpEach = bossMaxHp * hpFrac,
                speed = bossSpeed * 1.5,
                laneIndex = bossLane,
                position = bossPosition,
            }
        end
    end
    return nil
end
