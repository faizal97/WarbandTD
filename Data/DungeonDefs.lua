-- ---------------------------------------------------------------------------
-- WarbandTD — Data/DungeonDefs.lua
-- Dungeon definitions ported from assets/td/dungeons.json
-- ---------------------------------------------------------------------------

local _, ns = ...

ns.DungeonDefs = {
    windrunner_spire = {
        name = "Windrunner Spire",
        shortName = "WS",
        theme = "The ancestral home of the Windrunner family, haunted by spectral echoes.",
        enemyColor = {0.61, 0.55, 0.48},
        bossColor = {1.00, 0.42, 0.21},
        hpMultiplier = 1.0,
        speedMultiplier = 1.0,
        enemyCountModifier = 0,
        lanePattern = { type = "drift", switchChance = 0.3 },
        enemyModifiers = {
            { type = "spectral", dmgReduction = 0.3, untilPosition = 0.5 },
        },
        miniBossName = "Emberdawn",
        miniBossColor = {1.00, 0.55, 0.00},
        miniBossModifiers = {
            { type = "wind_push", pushAmount = 0.15, interval = 6.0 },
        },
        bossModifiers = {
            { type = "fire_zone", duration = 3.0, interval = 5.0 },
        },
        modifierScaling = {
            [7] = {
                enemyModifiers = {
                    { type = "spectral", dmgReduction = 0.4, untilPosition = 0.6 },
                },
            },
            [11] = {
                enemyModifiers = {
                    { type = "spectral", dmgReduction = 0.5, untilPosition = 0.7 },
                },
            },
        },
    },

    murder_row = {
        name = "Murder Row",
        shortName = "MR",
        theme = "The seedy underbelly of Silvermoon, teeming with rogues and assassins.",
        enemyColor = {0.42, 0.56, 0.14},
        bossColor = {0.55, 0.00, 0.00},
        hpMultiplier = 0.7,
        speedMultiplier = 1.1,
        enemyCountModifier = 2,
        lanePattern = { type = "zerg" },
        enemyModifiers = {
            { type = "ranged_attack", damage = 5.0, interval = 3.0 },
        },
        miniBossName = "Zaen Bladesorrow",
        miniBossColor = {0.80, 0.00, 0.00},
        miniBossModifiers = {
            { type = "knockback_tower", interval = 5.0 },
        },
        bossModifiers = {
            { type = "teleport_lanes", interval = 4.0 },
        },
    },
}

--- Current rotation (dungeon keys available this season).
ns.DungeonRotation = {
    "windrunner_spire",
    "murder_row",
}

--- Get a dungeon definition by key.
function ns.GetDungeonDef(key)
    return ns.DungeonDefs[key]
end

--- Get all rotation dungeon definitions.
function ns.GetRotationDungeons()
    local list = {}
    for _, key in ipairs(ns.DungeonRotation) do
        local def = ns.DungeonDefs[key]
        if def then
            def.key = key
            list[#list + 1] = def
        end
    end
    return list
end

--- Get enemy modifiers for a dungeon scaled to keystone level.
function ns.GetEnemyModifiers(dungeonDef, keystoneLevel)
    if not dungeonDef.modifierScaling then
        return dungeonDef.enemyModifiers or {}
    end
    local bestLevel = 0
    local best = nil
    for level, tier in pairs(dungeonDef.modifierScaling) do
        if level <= keystoneLevel and level > bestLevel and tier.enemyModifiers then
            bestLevel = level
            best = tier.enemyModifiers
        end
    end
    return best or dungeonDef.enemyModifiers or {}
end

--- Get boss modifiers for a dungeon scaled to keystone level.
function ns.GetBossModifiers(dungeonDef, keystoneLevel)
    if not dungeonDef.modifierScaling then
        return dungeonDef.bossModifiers or {}
    end
    local bestLevel = 0
    local best = nil
    for level, tier in pairs(dungeonDef.modifierScaling) do
        if level <= keystoneLevel and level > bestLevel and tier.bossModifiers then
            bestLevel = level
            best = tier.bossModifiers
        end
    end
    return best or dungeonDef.bossModifiers or {}
end
