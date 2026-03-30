-- ---------------------------------------------------------------------------
-- WarbandTD — Interaction.lua
-- Click handlers, targeting mode, tower placement, keybindings.
-- ---------------------------------------------------------------------------

local _, ns = ...

-- Targeting state
local targetingActive = false
local targetingTowerIndex = nil
local targetingType = nil  -- "enemy", "lane", "tower"

-- ---------------------------------------------------------------------------
-- Tower ability activation
-- ---------------------------------------------------------------------------

function ns.ActivateTowerAbility(towerIndex)
    local state = ns.state
    if not state or state.phase ~= ns.PHASE_PLAYING then return end

    local tower = state.towers[towerIndex]
    if not tower then return end

    local ability = tower.classDef.activeAbility
    if not ability then return end

    -- Check cooldown
    if tower.activeCooldownRemaining > 0 then
        ns.Print(format("%s is on cooldown (%.1fs)",
            ability.name, tower.activeCooldownRemaining))
        return
    end

    if ability.targeting == "instant" then
        -- Instant cast — execute immediately
        ns._ExecuteAbility(towerIndex)
    else
        -- Enter targeting mode
        ns._EnterTargeting(towerIndex, ability.targeting)
    end
end

-- ---------------------------------------------------------------------------
-- Targeting mode
-- ---------------------------------------------------------------------------

function ns._EnterTargeting(towerIndex, targetType)
    targetingActive = true
    targetingTowerIndex = towerIndex
    targetingType = targetType

    local tower = ns.state.towers[towerIndex]
    local ability = tower.classDef.activeAbility
    ns.Print(format("Select %s target for %s — click to confirm, Escape to cancel",
        targetType, ability.name))

    -- TODO: Add visual targeting overlay on lanes/enemies
end

function ns._CancelTargeting()
    if not targetingActive then return end
    targetingActive = false
    targetingTowerIndex = nil
    targetingType = nil
    ns.Print("Targeting cancelled.")
end

function ns._ConfirmTarget(targetData)
    if not targetingActive then return end

    local towerIndex = targetingTowerIndex
    targetingActive = false
    targetingTowerIndex = nil
    targetingType = nil

    ns._ExecuteAbility(towerIndex, targetData)
end

-- ---------------------------------------------------------------------------
-- Ability execution
-- ---------------------------------------------------------------------------

function ns._ExecuteAbility(towerIndex, targetData)
    local state = ns.state
    local tower = state.towers[towerIndex]
    if not tower then return end

    local ability = tower.classDef.activeAbility
    if not ability then return end

    -- Start cooldown
    tower.activeCooldownRemaining = ability.cooldown or 10

    -- Process effects (simplified — full port would use AbilityEffectProcessor)
    for _, effect in ipairs(ability.effects) do
        if effect.type == "damage_multiplier" and targetData and targetData.enemyId then
            -- Apply damage to target enemy
            for _, enemy in ipairs(state.enemies) do
                if enemy.id == targetData.enemyId and not enemy.isDead then
                    local damage = tower.baseDamage * (effect.value or 1)
                    enemy.hp = enemy.hp - damage
                    if enemy.hp <= 0 then
                        enemy.isDead = true
                        state.enemiesKilled = state.enemiesKilled + 1
                    end
                    ns.Print(format("%s hits for %d!",
                        ability.name, math.floor(damage)))
                    break
                end
            end

        elseif effect.type == "pull_to_start" and targetData and targetData.enemyId then
            for _, enemy in ipairs(state.enemies) do
                if enemy.id == targetData.enemyId then
                    enemy.position = 0
                    ns.Print(format("%s pulls enemy back!", ability.name))
                    break
                end
            end

        elseif effect.type == "damage_lane" and targetData and targetData.lane then
            local mult = effect.damage_multiplier or 1
            local damage = tower.baseDamage * mult
            local hitCount = 0
            for _, enemy in ipairs(state.enemies) do
                if enemy.laneIndex == targetData.lane and not enemy.isDead then
                    enemy.hp = enemy.hp - damage
                    hitCount = hitCount + 1
                    if enemy.hp <= 0 then
                        enemy.isDead = true
                        state.enemiesKilled = state.enemiesKilled + 1
                    end
                end
            end
            if hitCount > 0 then
                ns.Print(format("%s hits %d enemies for %d each!",
                    ability.name, hitCount, math.floor(damage)))
            end

        elseif effect.type == "buff_all_towers" then
            local buffType = effect.buff or "damage_multiplier"
            local val = effect.value or 1
            local dur = effect.duration or ability.duration or 6
            for _, t in ipairs(state.towers) do
                t.abilityBuffs[#t.abilityBuffs + 1] = {
                    type = buffType,
                    value = val,
                    remaining = dur,
                }
            end
            ns.Print(format("%s buffs all towers!", ability.name))

        elseif effect.type == "stealth" then
            tower.isStealthed = true
            tower.stealthTimer = effect.duration or 3
            ns.Print(format("%s vanishes!", tower.character.name))

        elseif effect.type == "empower_next_attack" then
            tower.empoweredNextAttackMult = effect.damage_multiplier or 4
            tower.empoweredNextAttackStun = effect.apply_stun
        end
    end
end

-- ---------------------------------------------------------------------------
-- Lane click handler (for targeting + tower placement)
-- ---------------------------------------------------------------------------

function ns.OnLaneClick(laneIndex, slotIndex)
    local state = ns.state
    if not state then return end

    if targetingActive then
        if targetingType == "lane" then
            ns._ConfirmTarget({ lane = laneIndex })
        end
        return
    end

    -- If in setup/between waves, could handle tower placement here
end

function ns.OnEnemyClick(enemyId)
    if targetingActive and targetingType == "enemy" then
        ns._ConfirmTarget({ enemyId = enemyId })
    end
end

-- ---------------------------------------------------------------------------
-- Escape key handler
-- ---------------------------------------------------------------------------

-- Hook escape to cancel targeting before closing
local origEscapeHandler = ns.mainFrame and ns.mainFrame:GetScript("OnKeyDown")

function ns.HandleEscape()
    if targetingActive then
        ns._CancelTargeting()
        return true
    end
    return false
end
