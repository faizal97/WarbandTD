-- ---------------------------------------------------------------------------
-- WarbandTD — GameState.lua
-- Core game engine: tick loop, waves, spawning, combat, and win/lose.
-- Ported from td_game_state.dart.
-- ---------------------------------------------------------------------------

local _, ns = ...

-- ---------------------------------------------------------------------------
-- Game state table
-- ---------------------------------------------------------------------------

--- Create a new game state instance.
function ns.NewGameState()
    return {
        phase = ns.PHASE_SETUP,
        config = ns.BalanceConfig,

        -- Run parameters
        keystoneLevel = 2,
        dungeon = nil,      -- DungeonDef table
        affixes = {},       -- list of affix strings

        -- Towers & enemies
        towers = {},        -- array of tower tables
        enemies = {},       -- array of enemy tables
        sanguinePools = {}, -- array of pool tables
        fireZones = {},     -- array of fire zone tables
        summonedPets = {},
        laneBlocks = {},
        burnZones = {},

        -- Combat state
        currentWave = 0,
        totalWaves = 10,
        lives = 30,
        maxLives = 30,
        enemiesKilled = 0,
        enemyIdCounter = 0,

        -- Tower cooldowns (indexed by tower position in towers array)
        towerCooldowns = {},

        -- Boss state
        bossState = {},
        bossReflecting = false,

        -- Lane stun timers
        laneStunTimers = {[0] = 0, [1] = 0, [2] = 0},

        -- Wave preview
        nextWaveLaneCounts = {0, 0, 0},

        -- Hit events (for visual rendering)
        hitEvents = {},
    }
end

-- Expose state to namespace
ns.state = nil

-- ---------------------------------------------------------------------------
-- Affix list
-- ---------------------------------------------------------------------------

local ALL_AFFIXES = {"fortified", "tyrannical", "bolstering", "bursting", "sanguine"}

-- ---------------------------------------------------------------------------
-- Start a run
-- ---------------------------------------------------------------------------

function ns.StartRun(roster, keystoneLevel, dungeonDef)
    local state = ns.NewGameState()
    local cfg = state.config

    state.keystoneLevel = keystoneLevel
    state.dungeon = dungeonDef
    state.totalWaves = cfg.totalWaves
    state.lives = cfg.startingLives
    state.maxLives = cfg.startingLives

    -- Generate affixes
    local shuffled = {}
    for _, a in ipairs(ALL_AFFIXES) do shuffled[#shuffled + 1] = a end
    for i = #shuffled, 2, -1 do
        local j = math.random(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    local affixCount = 0
    if keystoneLevel >= cfg.threeAffixLevel then affixCount = 3
    elseif keystoneLevel >= cfg.twoAffixLevel then affixCount = 2
    elseif keystoneLevel >= cfg.oneAffixLevel then affixCount = 1
    end
    for i = 1, affixCount do
        state.affixes[#state.affixes + 1] = shuffled[i]
    end

    -- Create towers from roster characters
    for i, char in ipairs(roster) do
        local classDef = ns.GetClassDef(char.class)
        state.towers[i] = ns.NewTower(char, classDef, i)
    end

    ns.state = state
    return state
end

-- ---------------------------------------------------------------------------
-- Tower creation
-- ---------------------------------------------------------------------------

--- Normalize ilvl to damage (same formula as Flutter).
local function NormalizedDamage(ilvl)
    local raw = ilvl or 100
    if raw > 300 then
        return 40 + math.min(math.max(raw - 500, 0), 200) / 200 * 30
    else
        return 40 + math.min(math.max(raw - 60, 0), 80) / 80 * 30
    end
end

function ns.NewTower(char, classDef, index)
    return {
        index = index,
        character = char,
        classDef = classDef,
        archetype = classDef.archetype,
        laneIndex = -1,     -- -1 = unassigned
        slotIndex = -1,

        baseDamage = NormalizedDamage(char.ilvl),
        isDebuffed = false,
        debuffTimer = 0,
        attackCount = 0,
        chargeTimer = 0,

        -- Active ability state
        activeCooldownRemaining = 0,
        activeAbilityActive = false,
        activeAbilityTimer = 0,

        -- Ultimate state
        ultimateCharge = 0,
        ultimateActive = false,
        ultimateTimer = 0,
        ultimateChargeTickTimer = 0,

        -- Ability buffs
        abilityBuffs = {},
        isStealthed = false,
        stealthTimer = 0,
        empoweredNextAttackMult = nil,
        empoweredNextAttackStun = nil,
        comboPoints = 0,

        -- Shapeshift
        currentForm = nil,
        shapeshiftTimer = 0,

        -- Transform (Voidform)
        transformArchetype = nil,
        transformTargeting = nil,
        transformTimer = 0,
        transformStackingDmgPerHit = 0,
        transformStackingBonus = 0,

        -- Internal
        abilitiesInitialized = false,
    }
end

-- Slot positions along the lane (0=front near spawn, 2=back near goal)
local SLOT_POSITIONS = {0.25, 0.55, 0.85}

--- Get a tower's normalized position in the lane based on slot.
function ns.GetTowerPosition(tower)
    if tower.slotIndex >= 1 and tower.slotIndex <= 3 then
        return SLOT_POSITIONS[tower.slotIndex]
    end
    return 0.85
end

--- Move a tower to a lane and slot.
function ns.MoveTower(towerIndex, newLane, slot)
    local state = ns.state
    if not state then return false end
    local tower = state.towers[towerIndex]
    if not tower then return false end

    tower.laneIndex = math.min(math.max(newLane, 0), 2)
    tower.slotIndex = math.min(math.max(slot or 2, 1), 3)
    return true
end

-- ---------------------------------------------------------------------------
-- Wave management
-- ---------------------------------------------------------------------------

function ns.BeginGame()
    local state = ns.state
    if not state or state.phase ~= ns.PHASE_SETUP then return end

    state.phase = ns.PHASE_PLAYING
    state.currentWave = 1
    ns._SpawnWave()
end

function ns.NextWave()
    local state = ns.state
    if not state or state.phase ~= ns.PHASE_BETWEEN_WAVES then return end

    state.currentWave = state.currentWave + 1
    state.phase = ns.PHASE_PLAYING
    ns._SpawnWave()
end

--- Spawn enemies for the current wave.
function ns._SpawnWave()
    local state = ns.state
    local cfg = state.config
    local wave = state.currentWave
    local dungeon = state.dungeon

    -- Initialize tower ability cooldowns
    for _, tower in ipairs(state.towers) do
        if not tower.abilitiesInitialized then
            tower.abilitiesInitialized = true
            local active = tower.classDef.activeAbility
            if active then
                tower.activeCooldownRemaining = active.cooldown or 10
            end
        end
    end

    -- Determine enemy count
    local count = cfg.spawnBaseCount + wave * cfg.spawnCountPerWave
            + (dungeon.enemyCountModifier or 0)
    count = math.min(math.max(count, cfg.spawnMinCount), cfg.spawnMaxCount)

    -- HP scaling
    local baseHp = cfg.baseEnemyHp * (1 + (wave - 1) * cfg.waveHpScalePerWave)
    if wave > cfg.miniBossWave then
        baseHp = baseHp * (1 + cfg.act2HpBonus)
    end
    baseHp = baseHp * ns.KeystoneHpMultiplier(state.keystoneLevel)
    baseHp = baseHp * (dungeon.hpMultiplier or 1.0)

    -- Affix HP multipliers
    local hasFortified = false
    local hasTyrannical = false
    for _, a in ipairs(state.affixes) do
        if a == "fortified" then hasFortified = true end
        if a == "tyrannical" then hasTyrannical = true end
    end

    -- Boss wave or mini-boss wave?
    local isBossWave = (wave == state.totalWaves)
    local isMiniBossWave = (wave == cfg.miniBossWave)

    if isBossWave or isMiniBossWave then
        -- Spawn boss/mini-boss + adds
        local bossHp, bossSpeed, addsCount, addsHpFrac
        if isBossWave then
            bossHp = baseHp * cfg.bossHpMultiplier
            bossSpeed = cfg.bossSpeed * (dungeon.speedMultiplier or 1.0)
            addsCount = cfg.bossAddsCount
            addsHpFrac = cfg.bossAddsHpFraction
            if hasTyrannical then bossHp = bossHp * cfg.tyrannicalHpMult end
        else
            bossHp = baseHp * cfg.miniBossHpMultiplier
            bossSpeed = cfg.miniBossSpeed * (dungeon.speedMultiplier or 1.0)
            addsCount = cfg.miniBossAddsCount
            addsHpFrac = cfg.miniBossAddsHpFraction
        end

        -- Boss
        local bossLane = math.random(0, 2)
        state.enemyIdCounter = state.enemyIdCounter + 1
        local modifiers = isBossWave
            and ns.GetBossModifiers(dungeon, state.keystoneLevel)
            or (dungeon.miniBossModifiers or {})

        state.enemies[#state.enemies + 1] = {
            id = "e" .. state.enemyIdCounter,
            maxHp = bossHp,
            hp = bossHp,
            position = 0,
            speed = bossSpeed,
            laneIndex = bossLane,
            isBoss = true,
            speedMultiplier = 1.0,
            modifiers = modifiers,
            modifierState = ns.EnemyEffects.InitModifierState(modifiers),
            statusEffects = {},
        }

        -- Initialize boss state
        if isBossWave then
            state.bossState = ns.BossEffects.InitState(modifiers)
        end

        -- Adds
        for i = 1, addsCount do
            state.enemyIdCounter = state.enemyIdCounter + 1
            local addHp = bossHp * addsHpFrac
            if hasFortified then addHp = addHp * cfg.fortifiedHpMult end
            local addSpeed = bossSpeed * (1 + math.random() * 0.1)
            local eMods = ns.GetEnemyModifiers(dungeon, state.keystoneLevel)
            state.enemies[#state.enemies + 1] = {
                id = "e" .. state.enemyIdCounter,
                maxHp = addHp,
                hp = addHp,
                position = -(i * 0.12), -- stagger
                speed = addSpeed,
                laneIndex = math.random(0, 2),
                isBoss = false,
                speedMultiplier = 1.0,
                modifiers = eMods,
                modifierState = ns.EnemyEffects.InitModifierState(eMods),
                statusEffects = {},
            }
        end
    else
        -- Normal wave: spawn regular enemies
        local eMods = ns.GetEnemyModifiers(dungeon, state.keystoneLevel)
        for i = 1, count do
            state.enemyIdCounter = state.enemyIdCounter + 1
            local hp = baseHp
            if hasFortified then hp = hp * cfg.fortifiedHpMult end
            local speed = (cfg.baseEnemySpeed + (math.random() - 0.5) * cfg.spawnSpeedVariance)
                          * (dungeon.speedMultiplier or 1.0)

            state.enemies[#state.enemies + 1] = {
                id = "e" .. state.enemyIdCounter,
                maxHp = hp,
                hp = hp,
                position = -((i - 1) * cfg.spawnStaggerDistance),
                speed = speed,
                laneIndex = math.random(0, 2),
                isBoss = false,
                speedMultiplier = 1.0,
                modifiers = eMods,
                modifierState = ns.EnemyEffects.InitModifierState(eMods),
                statusEffects = {},
            }
        end
    end
end

-- ---------------------------------------------------------------------------
-- Main tick loop
-- ---------------------------------------------------------------------------

function ns.Tick(dt)
    local state = ns.state
    if not state or state.phase ~= ns.PHASE_PLAYING then return end

    -- Clear per-frame data
    wipe(state.hitEvents)

    -- Tick towers (cooldowns, attacks)
    ns._TickTowers(dt)

    -- Move enemies
    ns._TickEnemies(dt)

    -- Check for leaks
    ns._CheckLeaks()

    -- Check wave completion
    ns._CheckWaveComplete()
end

-- ---------------------------------------------------------------------------
-- Tower tick — attack cycle
-- ---------------------------------------------------------------------------

function ns._TickTowers(dt)
    local state = ns.state
    local cfg = state.config

    for i, tower in ipairs(state.towers) do
        if tower.laneIndex < 0 then goto continueTower end

        -- Tick cooldowns
        if tower.activeCooldownRemaining > 0 then
            tower.activeCooldownRemaining = tower.activeCooldownRemaining - dt
        end

        -- Tick ability buffs
        for j = #tower.abilityBuffs, 1, -1 do
            tower.abilityBuffs[j].remaining = tower.abilityBuffs[j].remaining - dt
            if tower.abilityBuffs[j].remaining <= 0 then
                table.remove(tower.abilityBuffs, j)
            end
        end

        -- Attack interval
        local archetype = tower.transformArchetype or tower.archetype
        local interval = ns.GetAttackInterval(archetype)

        -- Apply passive attack speed effects
        if not tower.transformArchetype then
            for _, eff in ipairs(tower.classDef.passive.effects) do
                if eff.type == "attack_speed_multiplier" then
                    interval = interval * eff.value
                end
            end
        end

        -- Apply ability speed buffs
        for _, buff in ipairs(tower.abilityBuffs) do
            if buff.type == "attack_speed_multiplier" then
                interval = interval * buff.value
            end
        end

        -- Tower cooldown (attack timer)
        local cd = state.towerCooldowns[i] or 0
        cd = cd + dt
        tower.chargeTimer = tower.chargeTimer + dt

        if cd >= interval then
            state.towerCooldowns[i] = 0

            -- Build enemy snapshot for attack processing
            local enemySnap = {}
            for _, e in ipairs(state.enemies) do
                if not e.isDead and e.position >= 0 then
                    enemySnap[#enemySnap + 1] = {
                        id = e.id,
                        hp = e.hp,
                        position = e.position,
                        lane = e.laneIndex,
                    }
                end
            end

            local towerPos = ns.GetTowerPosition(tower)
            local attackRange = ns.GetAttackRange(archetype)

            -- Compute base damage with archetype multiplier
            local dmgMult = ns.GetDamageMult(archetype)
            local baseDmg = tower.baseDamage * (dmgMult > 0 and dmgMult or 1)
            if tower.isDebuffed then baseDmg = baseDmg * cfg.debuffDamageReduction end

            -- Apply ability damage buffs
            for _, buff in ipairs(tower.abilityBuffs) do
                if buff.type == "damage_multiplier" then
                    baseDmg = baseDmg * buff.value
                end
            end

            local result = ns.TowerEffects.ProcessAttack({
                archetype = archetype,
                classDef = tower.classDef,
                towerLane = tower.laneIndex,
                towerPosition = towerPos,
                attackRange = attackRange,
                enemies = enemySnap,
                baseDamage = baseDmg,
                attackCount = tower.attackCount,
                chargeTimer = tower.chargeTimer,
                rng = math.random,
                targetingOverride = tower.transformTargeting,
            })

            if result.isCharging then
                state.towerCooldowns[i] = cd
            else
                tower.attackCount = tower.attackCount + 1
                tower.chargeTimer = 0

                -- Apply hits
                for _, hit in ipairs(result.hits) do
                    ns._ApplyHit(hit, tower)
                end

                -- Apply status effects
                for _, se in ipairs(result.statusEffects) do
                    ns._ApplyStatusEffect(se)
                end

                -- Ultimate charge
                if tower.classDef.ultimateAbility and tower.classDef.ultimateAbility.charge then
                    local charge = tower.classDef.ultimateAbility.charge
                    if charge.trigger == "on_attack" then
                        tower.ultimateCharge = math.min(
                            (tower.ultimateCharge or 0) + (charge.amount or 1),
                            charge.max or 10
                        )
                    elseif charge.trigger == "on_crit" and result.didCrit then
                        tower.ultimateCharge = math.min(
                            (tower.ultimateCharge or 0) + (charge.amount or 1),
                            charge.max or 10
                        )
                    end
                end
            end
        else
            state.towerCooldowns[i] = cd
        end

        ::continueTower::
    end
end

--- Apply a single hit to an enemy.
function ns._ApplyHit(hit, tower)
    local state = ns.state
    for _, enemy in ipairs(state.enemies) do
        if enemy.id == hit.enemyId and not enemy.isDead then
            -- Modify damage through enemy modifiers
            local damage = ns.EnemyEffects.ModifyDamage(
                enemy.modifiers, enemy.modifierState,
                hit.damage, enemy.position
            )
            enemy.hp = enemy.hp - damage

            -- Create hit event for visual rendering
            local towerPos = ns.GetTowerPosition(tower)
            state.hitEvents[#state.hitEvents + 1] = {
                towerLane = tower.laneIndex,
                towerX = towerPos,
                enemyId = enemy.id,
                enemyLane = enemy.laneIndex,
                enemyX = enemy.position,
                damage = damage,
                archetype = tower.archetype,
                attackColor = tower.classDef.attackColor,
            }

            -- Check death
            if enemy.hp <= 0 then
                enemy.isDead = true
                state.enemiesKilled = state.enemiesKilled + 1
            end
            break
        end
    end
end

--- Apply a status effect to an enemy.
function ns._ApplyStatusEffect(se)
    local state = ns.state
    for _, enemy in ipairs(state.enemies) do
        if enemy.id == se.sourceId and not enemy.isDead then
            enemy.statusEffects[#enemy.statusEffects + 1] = {
                type = se.type,
                value = se.value,
                dotDamage = se.dotDamage,
                tickInterval = se.tickInterval,
                remaining = se.remaining,
                tickTimer = 0,
            }
            break
        end
    end
end

-- ---------------------------------------------------------------------------
-- Enemy tick — movement + status effects
-- ---------------------------------------------------------------------------

function ns._TickEnemies(dt)
    local state = ns.state
    for _, enemy in ipairs(state.enemies) do
        if enemy.isDead then goto continueEnemy end

        -- Apply speed from status effects (slows)
        local speedMult = enemy.speedMultiplier or 1.0
        for _, se in ipairs(enemy.statusEffects) do
            if se.type == "slow" then
                speedMult = speedMult * (1.0 - (se.value or 0))
            end
        end

        -- Check lane stun
        local stunTimer = state.laneStunTimers[enemy.laneIndex] or 0
        if stunTimer <= 0 then
            enemy.position = enemy.position + enemy.speed * speedMult * dt
        end

        -- Tick status effects
        for j = #enemy.statusEffects, 1, -1 do
            local se = enemy.statusEffects[j]
            se.remaining = se.remaining - dt

            -- DoT ticks
            if se.type == "dot" then
                se.tickTimer = (se.tickTimer or 0) + dt
                if se.tickTimer >= (se.tickInterval or 1) then
                    se.tickTimer = 0
                    enemy.hp = enemy.hp - (se.dotDamage or 0)
                    if enemy.hp <= 0 then
                        enemy.isDead = true
                        state.enemiesKilled = state.enemiesKilled + 1
                    end
                end
            end

            if se.remaining <= 0 then
                table.remove(enemy.statusEffects, j)
            end
        end

        ::continueEnemy::
    end

    -- Tick lane stun timers
    for lane = 0, 2 do
        if state.laneStunTimers[lane] > 0 then
            state.laneStunTimers[lane] = state.laneStunTimers[lane] - dt
        end
    end
end

-- ---------------------------------------------------------------------------
-- Leak check
-- ---------------------------------------------------------------------------

function ns._CheckLeaks()
    local state = ns.state
    for i = #state.enemies, 1, -1 do
        local enemy = state.enemies[i]
        if not enemy.isDead and enemy.position >= 1.0 then
            state.lives = state.lives - (enemy.isBoss and 5 or 1)
            table.remove(state.enemies, i)

            if state.lives <= 0 then
                state.lives = 0
                state.phase = ns.PHASE_DEFEAT
                return
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Wave completion check
-- ---------------------------------------------------------------------------

function ns._CheckWaveComplete()
    local state = ns.state
    if state.phase ~= ns.PHASE_PLAYING then return end

    -- Check if all enemies are dead or leaked
    for _, enemy in ipairs(state.enemies) do
        if not enemy.isDead and enemy.position < 1.0 then
            return -- still active enemies
        end
    end

    -- Wave complete
    if state.currentWave >= state.totalWaves then
        state.phase = ns.PHASE_VICTORY
    else
        state.phase = ns.PHASE_BETWEEN_WAVES
        -- Clean up dead enemies
        wipe(state.enemies)
    end
end

-- ---------------------------------------------------------------------------
-- Star rating
-- ---------------------------------------------------------------------------

function ns.GetStarRating()
    local state = ns.state
    if not state or state.phase ~= ns.PHASE_VICTORY then return 0 end
    if state.lives >= state.maxLives then return 3 end
    if state.lives >= state.maxLives * 0.75 then return 2 end
    return 1
end
