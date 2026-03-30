-- ---------------------------------------------------------------------------
-- WarbandTD — Data/BalanceConfig.lua
-- All tuning knobs for the TD game. Mirrors balance.json from the Flutter app.
-- ---------------------------------------------------------------------------

local _, ns = ...

ns.BalanceConfig = {
    -- General
    startingLives       = 30,
    totalWaves          = 10,
    miniBossWave        = 5,
    baseEnemyHp         = 260,
    baseEnemySpeed      = 0.10,
    waveHpScalePerWave  = 0.10,
    act2HpBonus         = 0.15,

    -- Boss
    bossHpMultiplier        = 6.0,
    bossSpeed               = 0.04,
    bossAddsCount           = 3,
    bossAddsHpFraction      = 0.4,
    bossAddsSpeedVariance   = 0.05,
    bossAddsStaggerDistance = 0.12,

    -- Mini-boss
    miniBossHpMultiplier        = 4.0,
    miniBossSpeed               = 0.065,
    miniBossAddsCount           = 2,
    miniBossAddsHpFraction      = 0.35,
    miniBossAddsSpeedVariance   = 0.05,
    miniBossAddsStaggerDistance = 0.10,

    -- Enemy spawn
    spawnBaseCount       = 6,
    spawnCountPerWave    = 2,
    spawnMinCount        = 4,
    spawnMaxCount        = 20,
    spawnSpeedVariance   = 0.06,
    spawnStaggerDistance  = 0.10,

    -- Archetype damage multipliers
    meleeDamageMult  = 1.0,
    rangedDamageMult = 1.0,
    aoeDamageMult    = 0.70,

    -- Archetype attack intervals (seconds)
    meleeAttackInterval   = 0.8,
    rangedAttackInterval  = 1.0,
    supportAttackInterval = 2.0,
    aoeAttackInterval     = 0.9,

    -- Archetype attack ranges (0-1 normalized lane distance)
    meleeAttackRange  = 0.30,
    rangedAttackRange = 0.55,
    aoeAttackRange    = 0.40,

    -- Keystone scaling
    linearPhaseEnd      = 20,
    linearRate          = 0.10,
    exponentialBase     = 2.8,
    exponentialLinear   = 0.25,
    exponentialQuadratic = 0.02,

    -- Affix thresholds
    oneAffixLevel   = 4,
    twoAffixLevel   = 7,
    threeAffixLevel = 11,

    -- Affix values
    fortifiedHpMult       = 1.3,
    tyrannicalHpMult      = 1.5,
    bolsteringSpeedBuff   = 1.1,
    burstingDebuffDuration = 2.0,
    sanguinePoolDuration  = 4.0,
    sanguineHealPerSecond = 0.15,
    sanguineHealRange     = 0.05,

    -- Tower
    debuffDamageReduction = 0.5,

    -- Valor
    cleanClearThreshold    = 16,
    standardClearMin       = 8,
    cleanClearReward       = 3,
    standardClearReward    = 2,
    scrapedByReward        = 1,
    depleteReward          = 0,
    sharpenCost            = 1,
    sharpenMaxStacks       = 3,
    sharpenDamageBonus     = 0.15,
    fortifyCost            = 1,
    fortifyBossLeakReduction = 1,
    empowerCost            = 2,
    sixthTowerLevel        = 5,
}

--- Get attack interval for an archetype.
function ns.GetAttackInterval(archetype)
    local cfg = ns.BalanceConfig
    if archetype == "melee" then return cfg.meleeAttackInterval
    elseif archetype == "ranged" then return cfg.rangedAttackInterval
    elseif archetype == "support" then return cfg.supportAttackInterval
    elseif archetype == "aoe" then return cfg.aoeAttackInterval
    end
    return 1.0
end

--- Get attack range for an archetype.
function ns.GetAttackRange(archetype)
    local cfg = ns.BalanceConfig
    if archetype == "melee" then return cfg.meleeAttackRange
    elseif archetype == "ranged" then return cfg.rangedAttackRange
    elseif archetype == "aoe" then return cfg.aoeAttackRange
    end
    return 0
end

--- Get damage multiplier for an archetype.
function ns.GetDamageMult(archetype)
    local cfg = ns.BalanceConfig
    if archetype == "melee" then return cfg.meleeDamageMult
    elseif archetype == "ranged" then return cfg.rangedDamageMult
    elseif archetype == "aoe" then return cfg.aoeDamageMult
    end
    return 0
end

--- HP multiplier for a keystone level.
function ns.KeystoneHpMultiplier(level)
    local cfg = ns.BalanceConfig
    if level <= cfg.linearPhaseEnd then
        return 1.0 + (level - 2) * cfg.linearRate
    end
    local over = level - cfg.linearPhaseEnd
    return cfg.exponentialBase + over * cfg.exponentialLinear
           + over * over * cfg.exponentialQuadratic
end
