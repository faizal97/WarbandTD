-- ---------------------------------------------------------------------------
-- WarbandTD — Data/ClassDefs.lua
-- Class definitions ported from assets/td/classes.json
-- ---------------------------------------------------------------------------

local _, ns = ...

ns.ClassDefs = {
    warrior = {
        archetype = "melee",
        attackColor = {0.78, 0.61, 0.43},
        passive = {
            name = "Cleave",
            description = "Attacks hit an additional nearby enemy.",
            trigger = "on_attack",
            effects = {{ type = "extra_targets", value = 1 }},
        },
        empoweredPassive = {
            name = "Mighty Cleave",
            description = "Attacks hit 2 additional enemies.",
            trigger = "on_attack",
            effects = {{ type = "extra_targets", value = 2 }},
        },
        activeAbility = {
            name = "Execute",
            icon = "Interface\\Icons\\INV_Sword_48",
            description = "Deal 3x damage to an enemy below 30% HP. Instant kill below 10%.",
            targeting = "enemy",
            cooldown = 10.0,
            initialCooldownPct = 0.33,
            effects = {
                { type = "damage_multiplier", value = 3.0, condition = { target_hp_below_pct = 0.30 }},
                { type = "instant_kill", condition = { target_hp_below_pct = 0.10 }},
            },
        },
        ultimateAbility = {
            name = "Bladestorm",
            icon = "Interface\\Icons\\Ability_Whirlwind",
            description = "Deal heavy damage to ALL enemies in ALL lanes for 4s.",
            targeting = "instant",
            duration = 4.0,
            charge = { trigger = "on_attack", amount = 1, max = 15 },
            effects = {
                { type = "damage_all_lanes", damage_multiplier = 1.5, tick_interval = 0.5 },
            },
        },
    },

    rogue = {
        archetype = "melee",
        attackColor = {1.00, 0.96, 0.41},
        passive = {
            name = "Ambush",
            description = "Every 4th attack deals 3.5x damage.",
            trigger = "on_nth_attack", nth = 4,
            effects = {{ type = "damage_multiplier", value = 3.5 }},
        },
        empoweredPassive = {
            name = "Shadowstrike",
            description = "Every 3rd attack deals 3.5x damage.",
            trigger = "on_nth_attack", nth = 3,
            effects = {{ type = "damage_multiplier", value = 3.5 }},
        },
        activeAbility = {
            name = "Vanish",
            icon = "Interface\\Icons\\Ability_Vanish",
            description = "Disappear for 3s: immune. Next attack: 4x damage + 1.5s stun.",
            targeting = "instant",
            cooldown = 10.0,
            initialCooldownPct = 0.33,
            effects = {
                { type = "stealth", duration = 3.0 },
                { type = "empower_next_attack", damage_multiplier = 4.0, apply_stun = 1.5 },
            },
        },
        ultimateAbility = {
            name = "Shadow Blades",
            icon = "Interface\\Icons\\INV_Knife_1H_GarrisonB01_Alliance",
            description = "For 8s: 2x damage, build combo points. At 5 points, auto-Eviscerate for 6x.",
            targeting = "instant",
            duration = 8.0,
            charge = { trigger = "on_nth_attack", amount = 3, max = 15 },
            effects = {
                { type = "damage_multiplier", value = 2.0 },
                { type = "combo_points", gain_per_attack = 1, threshold = 5, finisher_damage_multiplier = 6.0 },
            },
        },
    },

    deathknight = {
        archetype = "melee",
        attackColor = {0.77, 0.12, 0.23},
        passive = {
            name = "Frost Fever",
            description = "Attacks slow enemies by 30% for 2.5 seconds.",
            trigger = "on_attack",
            effects = {{ type = "slow_enemy", value = 0.3, duration = 2.5 }},
        },
        empoweredPassive = {
            name = "Remorseless Winter",
            description = "Attacks slow enemies by 30% for 2.5s and apply a 10% damage DoT.",
            trigger = "on_attack",
            effects = {
                { type = "slow_enemy", value = 0.3, duration = 2.5 },
                { type = "dot", damageType = "percentDamage", value = 0.1, duration = 2.5, ticks = 2 },
            },
        },
        activeAbility = {
            name = "Death Grip",
            icon = "Interface\\Icons\\Spell_DeathKnight_Strangulate",
            description = "Pull target enemy back to the start of its lane.",
            targeting = "enemy",
            cooldown = 15.0,
            initialCooldownPct = 0.33,
            effects = {
                { type = "pull_to_start" },
            },
        },
        ultimateAbility = {
            name = "Army of the Dead",
            icon = "Interface\\Icons\\Spell_DeathKnight_ArmyOfTheDead",
            description = "Summon ghouls that block all movement in a lane for 6s. Blocked enemies take DoT.",
            targeting = "lane",
            duration = 6.0,
            charge = { trigger = "on_enemy_debuffed", amount = 1, max = 18 },
            effects = {
                { type = "block_lane", duration = 6.0 },
                { type = "dot", damageType = "percentDamage", value = 0.15, duration = 6.0, ticks = 6 },
            },
        },
    },

    paladin = {
        archetype = "melee",
        attackColor = {0.96, 0.55, 0.73},
        passive = {
            name = "Judgment",
            description = "Buffs adjacent towers' damage by 15%.",
            trigger = "passive",
            effects = {{ type = "buff_adjacent_damage", value = 0.15 }},
        },
        empoweredPassive = {
            name = "Greater Judgment",
            description = "Buffs adjacent towers' damage by 25%.",
            trigger = "passive",
            effects = {{ type = "buff_adjacent_damage", value = 0.25 }},
        },
        activeAbility = {
            name = "Blessing of Kings",
            icon = "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings",
            description = "All towers gain +20% damage for 6s.",
            targeting = "instant",
            cooldown = 16.0,
            initialCooldownPct = 0.33,
            effects = {
                { type = "buff_all_towers", buff = "damage_multiplier", value = 1.20, duration = 6.0 },
            },
        },
        ultimateAbility = {
            name = "Guardian of Ancient Kings",
            icon = "Interface\\Icons\\Spell_Holy_AvengingWrath",
            description = "For 8s: ALL towers gain +25% damage.",
            targeting = "instant",
            duration = 8.0,
            charge = { trigger = "on_attack", amount = 1, max = 20 },
            effects = {
                { type = "buff_all_towers", buff = "damage_multiplier", value = 1.25, duration = 8.0 },
            },
        },
    },

    monk = {
        archetype = "melee",
        attackColor = {0.00, 1.00, 0.60},
        passive = {
            name = "Flurry",
            description = "Attacks 60% faster than normal.",
            trigger = "passive",
            effects = {{ type = "attack_speed_multiplier", value = 0.625 }},
        },
        empoweredPassive = {
            name = "Storm, Earth, and Fire",
            description = "Attacks 80% faster than normal.",
            trigger = "passive",
            effects = {{ type = "attack_speed_multiplier", value = 0.556 }},
        },
        activeAbility = {
            name = "Fists of Fury",
            icon = "Interface\\Icons\\Monk_ability_fistoffury",
            description = "Channel rapid attacks for 3s: 5 hits at 0.6x damage each.",
            targeting = "instant",
            cooldown = 12.0,
            initialCooldownPct = 0.33,
            effects = {
                { type = "channel_attack", duration = 3.0, hits = 5, damage_per_hit = 0.6, immune_during = true },
            },
        },
        ultimateAbility = {
            name = "Touch of Death",
            icon = "Interface\\Icons\\Ability_Monk_TouchOfDeath",
            description = "Instantly kill any non-boss enemy. Deal 15% max HP to bosses.",
            targeting = "enemy",
            charge = { trigger = "on_attack", amount = 1, max = 15 },
            effects = {
                { type = "instant_kill", condition = { not_boss = true }},
                { type = "percent_hp_damage", value = 0.15, condition = { is_boss = true }},
            },
        },
    },

    demonhunter = {
        archetype = "melee",
        attackColor = {0.64, 0.19, 0.79},
        passive = {
            name = "Momentum",
            description = "Can attack adjacent lanes. +15% damage per reachable lane.",
            trigger = "passive",
            effects = {
                { type = "cross_lane_attack", value = 1 },
                { type = "lane_count_damage", value = 0.15 },
            },
        },
        empoweredPassive = {
            name = "Havoc",
            description = "Can attack ALL lanes. +15% damage per reachable lane.",
            trigger = "passive",
            effects = {
                { type = "cross_lane_attack", value = 2 },
                { type = "lane_count_damage", value = 0.15 },
            },
        },
        activeAbility = {
            name = "Eye Beam",
            icon = "Interface\\Icons\\Ability_DemonHunter_EyeBeam",
            description = "Channel a fel beam down a lane for 3s, dealing continuous AoE.",
            targeting = "lane",
            cooldown = 14.0,
            initialCooldownPct = 0.33,
            effects = {
                { type = "damage_lane", damage_multiplier = 0.5, tick_interval = 0.3, duration = 3.0 },
            },
        },
        ultimateAbility = {
            name = "Metamorphosis",
            icon = "Interface\\Icons\\Ability_DemonHunter_Metamorphosis",
            description = "Transform for 8s: +50% damage, +50% atk speed, hits ALL lanes.",
            targeting = "instant",
            duration = 8.0,
            charge = { trigger = "on_kill", amount = 2, max = 20 },
            effects = {
                { type = "damage_multiplier", value = 1.5 },
                { type = "attack_speed_multiplier", value = 0.667 },
                { type = "cross_lane_attack", value = 99 },
            },
        },
    },

    mage = {
        archetype = "ranged",
        attackColor = {0.25, 0.78, 0.92},
        passive = {
            name = "Hot Streak",
            description = "30% chance to critically strike for 2.5x damage.",
            trigger = "on_attack",
            effects = {{ type = "crit_chance", chance = 0.3, multiplier = 2.5 }},
        },
        empoweredPassive = {
            name = "Pyroblast",
            description = "30% chance to critically strike for 3.5x damage.",
            trigger = "on_attack",
            effects = {{ type = "crit_chance", chance = 0.3, multiplier = 3.5 }},
        },
        activeAbility = {
            name = "Meteor",
            icon = "Interface\\Icons\\Spell_Mage_Meteor",
            description = "AoE lane damage + burn zone for 4s.",
            targeting = "lane",
            cooldown = 14.0,
            initialCooldownPct = 0.33,
            effects = {
                { type = "damage_lane", damage_multiplier = 5.0 },
                { type = "burn_zone", damage_per_tick = 0.3, tick_interval = 1.0, duration = 4.0 },
            },
        },
        ultimateAbility = {
            name = "Combustion",
            icon = "Interface\\Icons\\Spell_Fire_SealOfFire",
            description = "For 8s: ALL attacks auto-crit at 2.5x and splash.",
            targeting = "instant",
            duration = 8.0,
            charge = { trigger = "on_crit", amount = 2, max = 20 },
            effects = {
                { type = "guaranteed_crit", multiplier = 2.5 },
                { type = "splash_damage", splash_pct = 0.5 },
            },
        },
    },

    hunter = {
        archetype = "ranged",
        attackColor = {0.67, 0.83, 0.45},
        passive = {
            name = "Multi-Shot",
            description = "Attacks hit an additional nearby enemy.",
            trigger = "on_attack",
            effects = {{ type = "extra_targets", value = 1 }},
        },
        empoweredPassive = {
            name = "Volley",
            description = "Attacks hit 2 additional enemies.",
            trigger = "on_attack",
            effects = {{ type = "extra_targets", value = 2 }},
        },
        activeAbility = {
            name = "Aimed Shot",
            icon = "Interface\\Icons\\INV_Spear_07",
            description = "4x damage. Ignores shield and phase modifiers.",
            targeting = "enemy",
            cooldown = 10.0,
            initialCooldownPct = 0.33,
            effects = {
                { type = "damage_multiplier", value = 4.0 },
                { type = "ignore_modifiers", modifiers = {"shield", "phase"} },
            },
        },
        ultimateAbility = {
            name = "Bestial Wrath",
            icon = "Interface\\Icons\\Ability_Hunter_BestialWrath",
            description = "Summon a spirit beast for 8s. Tower gains +30% atk speed.",
            targeting = "instant",
            duration = 8.0,
            charge = { trigger = "on_attack", amount = 1, max = 14 },
            effects = {
                { type = "summon_pet", targeting = "furthest_any_lane", attack_interval = 0.5, damage_multiplier = 1.5, duration = 8.0 },
                { type = "attack_speed_multiplier", value = 0.77 },
            },
        },
    },

    warlock = {
        archetype = "ranged",
        attackColor = {0.53, 0.53, 0.93},
        passive = {
            name = "Corruption",
            description = "Attacks apply a DoT dealing 50% damage over 4 seconds.",
            trigger = "on_attack",
            effects = {{ type = "dot", damageType = "percentDamage", value = 0.5, duration = 4.0, ticks = 4 }},
        },
        empoweredPassive = {
            name = "Agony",
            description = "Attacks apply DoT (50% over 4s) and slow enemies 15%.",
            trigger = "on_attack",
            effects = {
                { type = "dot", damageType = "percentDamage", value = 0.5, duration = 4.0, ticks = 4 },
                { type = "slow_enemy", value = 0.15, duration = 4.0 },
            },
        },
        activeAbility = {
            name = "Chaos Bolt",
            icon = "Interface\\Icons\\Ability_Warlock_ChaosBolt",
            description = "4x damage, always crits. Spreads DoTs to 2 nearby enemies.",
            targeting = "enemy",
            cooldown = 14.0,
            initialCooldownPct = 0.33,
            effects = {
                { type = "damage_multiplier", value = 4.0 },
                { type = "guaranteed_crit" },
                { type = "dot_spread", count = 2 },
            },
        },
        ultimateAbility = {
            name = "Summon Infernal",
            icon = "Interface\\Icons\\Spell_Shadow_SummonInfernal",
            description = "Stuns enemies 2s on impact, then pulses AoE for 8s.",
            targeting = "lane",
            duration = 8.0,
            charge = { trigger = "on_enemy_debuffed", amount = 1, max = 22 },
            effects = {
                { type = "stun_enemies", duration = 2.0, scope = "lane" },
                { type = "summon_pet", targeting = "all_in_lane", attack_interval = 1.0, damage_multiplier = 1.0, duration = 8.0 },
            },
        },
    },

    evoker = {
        archetype = "ranged",
        attackColor = {0.20, 0.58, 0.50},
        passive = {
            name = "Charged Blast",
            description = "Charges for 3s then unleashes a blast for 5x damage.",
            trigger = "passive",
            effects = {{ type = "charge_attack", chargeTime = 3.0, multiplier = 5.0 }},
        },
        empoweredPassive = {
            name = "Dragonrage",
            description = "Charges for 2.5s then unleashes a blast for 7x damage.",
            trigger = "passive",
            effects = {{ type = "charge_attack", chargeTime = 2.5, multiplier = 7.0 }},
        },
        activeAbility = {
            name = "Fire Breath",
            icon = "Interface\\Icons\\Ability_Evoker_FireBreath",
            description = "Breathe fire down a lane. Damage scales with charge (1x-3x).",
            targeting = "lane",
            cooldown = 10.0,
            initialCooldownPct = 0.33,
            effects = {
                { type = "damage_lane", damage_multiplier_from_charge = true, min_multiplier = 1.0, max_multiplier = 3.0 },
                { type = "dot", damageType = "percentDamage", value = 0.2, duration = 3.0, ticks = 3 },
            },
        },
        ultimateAbility = {
            name = "Deep Breath",
            icon = "Interface\\Icons\\Ability_Evoker_DeepBreath",
            description = "Fly over a lane dealing massive damage + knockback + 50% slow.",
            targeting = "lane",
            charge = { trigger = "on_attack", amount = 3, max = 24 },
            effects = {
                { type = "damage_lane", damage_multiplier = 6.0 },
                { type = "knockback", value = 0.3 },
                { type = "slow_enemy", value = 0.5, duration = 4.0 },
            },
        },
    },

    priest = {
        archetype = "support",
        attackColor = {1.00, 1.00, 1.00},
        passive = {
            name = "Power Word: Fortitude",
            description = "Increases damage of adjacent towers by 35%.",
            trigger = "passive",
            effects = {{ type = "buff_adjacent_damage", value = 0.35 }},
        },
        empoweredPassive = {
            name = "Voidform",
            description = "Increases damage of adjacent towers by 50%.",
            trigger = "passive",
            effects = {{ type = "buff_adjacent_damage", value = 0.5 }},
        },
        activeAbility = {
            name = "Power Infusion",
            icon = "Interface\\Icons\\Spell_Holy_PowerInfusion",
            description = "Grant a tower +50% attack speed for 6s.",
            targeting = "tower",
            cooldown = 15.0,
            initialCooldownPct = 0.33,
            effects = {
                { type = "buff_tower", buff = "attack_speed_multiplier", value = 0.667, duration = 6.0 },
            },
        },
        ultimateAbility = {
            name = "Voidform",
            icon = "Interface\\Icons\\Spell_Priest_VoidForm",
            description = "Transform for 10s: ranged archetype, targets highest-HP enemy, +10% stacking damage.",
            targeting = "instant",
            duration = 10.0,
            charge = { trigger = "on_buff_ally", amount = 1, max = 20 },
            effects = {
                { type = "transform", archetype = "ranged", targeting = "highest_hp_any_lane", stacking_damage_per_hit = 0.10 },
            },
        },
    },

    druid = {
        archetype = "support",
        attackColor = {1.00, 0.49, 0.04},
        passive = {
            name = "Nature's Swiftness",
            description = "Increases attack speed of adjacent towers by 30%.",
            trigger = "passive",
            effects = {{ type = "buff_adjacent_speed", value = 0.3 }},
        },
        empoweredPassive = {
            name = "Incarnation",
            description = "Increases attack speed of adjacent towers by 40%.",
            trigger = "passive",
            effects = {{ type = "buff_adjacent_speed", value = 0.4 }},
        },
        activeAbility = {
            name = "Shapeshift",
            icon = "Interface\\Icons\\Ability_Druid_CatForm",
            description = "Toggle forms. Bear: +50% fortify. Cat: +40% atk speed +20% crit. Reverts after 6s.",
            targeting = "instant",
            cooldown = 8.0,
            initialCooldownPct = 0.33,
            duration = 6.0,
            effects = {
                {
                    type = "shapeshift",
                    forms = {
                        bear = {
                            archetype = "melee",
                            effects = {{ type = "fortify_multiplier", value = 1.5 }},
                        },
                        cat = {
                            archetype = "melee",
                            effects = {
                                { type = "attack_speed_multiplier", value = 0.714 },
                                { type = "crit_chance", chance = 0.2, multiplier = 2.0 },
                            },
                        },
                    },
                    revert_after = 6.0,
                },
            },
        },
        ultimateAbility = {
            name = "Convoke the Spirits",
            icon = "Interface\\Icons\\Ability_Ardenweald_Druid",
            description = "Channel 4s: 16 random effects — damage, DoTs, cleanses, buffs — across ALL lanes.",
            targeting = "instant",
            duration = 4.0,
            charge = { trigger = "on_time", amount = 1, interval = 2.0, max = 30 },
            effects = {
                {
                    type = "random_cast",
                    count = 16,
                    interval = 0.25,
                    pool = {
                        { type = "damage_random_enemy", damage_multiplier = 2.0, weight = 4 },
                        { type = "dot_random_enemy", value = 0.3, duration = 3.0, ticks = 3, weight = 3 },
                        { type = "cleanse_random_tower", weight = 3 },
                        { type = "buff_random_tower", buff = "damage_multiplier", value = 1.2, duration = 4.0, weight = 3 },
                        { type = "buff_random_tower", buff = "attack_speed_multiplier", value = 0.8, duration = 4.0, weight = 3 },
                    },
                },
            },
        },
    },

    shaman = {
        archetype = "aoe",
        attackColor = {0.00, 0.44, 0.87},
        passive = {
            name = "Chain Lightning",
            description = "Attacks bounce to 4 enemies with diminishing damage.",
            trigger = "on_attack",
            effects = {{ type = "chain_damage", bounces = {1.0, 0.8, 0.6, 0.4} }},
        },
        empoweredPassive = {
            name = "Stormkeeper",
            description = "Attacks bounce to 5 enemies with less diminishing.",
            trigger = "on_attack",
            effects = {{ type = "chain_damage", bounces = {1.0, 0.9, 0.8, 0.7, 0.6} }},
        },
        activeAbility = {
            name = "Lava Burst",
            icon = "Interface\\Icons\\Spell_Shaman_LavaBurst",
            description = "Guaranteed-crit lava bolt dealing 4x (6x if target has DoT).",
            targeting = "enemy",
            cooldown = 12.0,
            initialCooldownPct = 0.33,
            effects = {
                { type = "guaranteed_crit" },
                { type = "damage_multiplier", value = 4.0, value_if_dotted = 6.0 },
            },
        },
        ultimateAbility = {
            name = "Bloodlust",
            icon = "Interface\\Icons\\Spell_Nature_Bloodlust",
            description = "ALL towers gain +30% atk speed for 10s. All CDs reduced by 50%.",
            targeting = "instant",
            duration = 10.0,
            charge = { trigger = "on_time", amount = 1, interval = 2.0, max = 30 },
            effects = {
                { type = "buff_all_towers", buff = "attack_speed_multiplier", value = 0.77, duration = 10.0 },
                { type = "reduce_all_cooldowns", reduction_pct = 0.5 },
            },
        },
    },
}

--- Fallback class definition for unknown classes.
ns.FallbackClassDef = {
    archetype = "ranged",
    attackColor = {0.53, 0.60, 0.67},
    passive = {
        name = "Basic Attack",
        description = "No special passive ability.",
        trigger = "passive",
        effects = {},
    },
}

--- Get a class definition by WoW class file name (lowercase).
--- Maps WoW API class tokens (e.g. "WARRIOR") to our keys.
local CLASS_TOKEN_MAP = {
    warrior = "warrior",
    paladin = "paladin",
    hunter = "hunter",
    rogue = "rogue",
    priest = "priest",
    deathknight = "deathknight",
    shaman = "shaman",
    mage = "mage",
    warlock = "warlock",
    monk = "monk",
    druid = "druid",
    demonhunter = "demonhunter",
    evoker = "evoker",
    -- Handle space-separated names from the Flutter app
    ["death knight"] = "deathknight",
    ["demon hunter"] = "demonhunter",
}

function ns.GetClassDef(classFile)
    local key = CLASS_TOKEN_MAP[classFile:lower()] or classFile:lower()
    return ns.ClassDefs[key] or ns.FallbackClassDef
end
