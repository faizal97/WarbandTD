-- ---------------------------------------------------------------------------
-- WarbandTD — Core.lua
-- Addon lifecycle, event handling, slash commands, and namespace setup.
-- ---------------------------------------------------------------------------

local addonName, ns = ...

-- ---------------------------------------------------------------------------
-- Namespace setup
-- ---------------------------------------------------------------------------

ns.version = "@project-version@"
ns.db = nil          -- SavedVariables reference (set in ADDON_LOADED)
ns.mainFrame = nil   -- Main game window (created in UI.lua)

-- Game phase constants
ns.PHASE_SETUP         = "setup"
ns.PHASE_PLAYING       = "playing"
ns.PHASE_BETWEEN_WAVES = "betweenWaves"
ns.PHASE_VICTORY       = "victory"
ns.PHASE_DEFEAT        = "defeat"

-- ---------------------------------------------------------------------------
-- Utility
-- ---------------------------------------------------------------------------

function ns.Print(msg)
    print("|cFF00CCFF[WarbandTD]|r " .. tostring(msg))
end

--- Deep-merge defaults into a table (non-destructive).
local function ApplyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            if type(v) == "table" then
                target[k] = {}
                ApplyDefaults(target[k], v)
            else
                target[k] = v
            end
        elseif type(v) == "table" and type(target[k]) == "table" then
            ApplyDefaults(target[k], v)
        end
    end
end

-- ---------------------------------------------------------------------------
-- SavedVariables defaults
-- ---------------------------------------------------------------------------

local DB_DEFAULTS = {
    keystoneLevel = 2,
    valor = 0,
    upgrades = {},
    roster = {},
    settings = {
        scale = 1.0,
        locked = false,
        showCombatLog = true,
        sfxEnabled = true,
        sfxVolume = 0.7,
    },
    stats = {
        totalRuns = 0,
        totalClears = 0,
        highestKey = 2,
        totalKills = 0,
    },
}

-- ---------------------------------------------------------------------------
-- Character registration
-- ---------------------------------------------------------------------------

function ns.RegisterCurrentCharacter()
    local name = UnitName("player")
    local realm = GetRealmName()
    local _, classFile = UnitClass("player")
    local _, ilvl = GetAverageItemLevel()

    local key = name .. "-" .. realm
    ns.db.roster[key] = {
        name = name,
        realm = realm,
        class = classFile:lower(),
        ilvl = math.floor(ilvl or 0),
    }
end

--- Get all roster characters sorted by ilvl (highest first).
function ns.GetRoster()
    local list = {}
    for key, char in pairs(ns.db.roster) do
        char.key = key
        list[#list + 1] = char
    end
    table.sort(list, function(a, b) return (a.ilvl or 0) > (b.ilvl or 0) end)
    return list
end

-- ---------------------------------------------------------------------------
-- Event handling
-- ---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= addonName then return end

        -- Initialize SavedVariables
        WarbandTD_DB = WarbandTD_DB or {}
        ApplyDefaults(WarbandTD_DB, DB_DEFAULTS)
        ns.db = WarbandTD_DB

        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        -- Register current character into warband roster
        ns.RegisterCurrentCharacter()

        -- Build the UI (hidden by default)
        ns.BuildUI()

        ns.Print("v" .. ns.version .. " loaded. Type |cFFFFD700/td|r to play!")

    elseif event == "PLAYER_LOGOUT" then
        -- Update current character's ilvl on logout
        ns.RegisterCurrentCharacter()
    end
end)

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------

SLASH_WARBANDTD1 = "/warbandtd"
SLASH_WARBANDTD2 = "/td"

SlashCmdList["WARBANDTD"] = function(msg)
    local cmd = (msg or ""):lower():match("^%s*(%S*)") or ""

    if cmd == "config" or cmd == "settings" then
        ns.Print("Settings panel coming soon.")
    elseif cmd == "reset" then
        StaticPopup_Show("WARBANDTD_RESET_CONFIRM")
    elseif cmd == "roster" then
        local roster = ns.GetRoster()
        if #roster == 0 then
            ns.Print("No characters registered. Log into your alts!")
        else
            ns.Print("Warband roster (" .. #roster .. " characters):")
            for _, c in ipairs(roster) do
                local color = ns.ClassColor(c.class)
                ns.Print(format("  %s%s|r (%s) — ilvl %d",
                    color, c.name, c.class, c.ilvl or 0))
            end
        end
    elseif cmd == "" then
        ns.ToggleMainFrame()
    else
        ns.Print("Commands:")
        ns.Print("  |cFFFFD700/td|r — open game")
        ns.Print("  |cFFFFD700/td roster|r — show characters")
        ns.Print("  |cFFFFD700/td config|r — settings")
        ns.Print("  |cFFFFD700/td reset|r — reset all data")
    end
end

-- ---------------------------------------------------------------------------
-- Reset confirmation dialog
-- ---------------------------------------------------------------------------

StaticPopupDialogs["WARBANDTD_RESET_CONFIRM"] = {
    text = "Reset ALL WarbandTD data? This cannot be undone.",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function()
        wipe(WarbandTD_DB)
        ApplyDefaults(WarbandTD_DB, DB_DEFAULTS)
        ns.db = WarbandTD_DB
        ns.RegisterCurrentCharacter()
        ns.Print("All data has been reset.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- ---------------------------------------------------------------------------
-- Minimap compartment
-- ---------------------------------------------------------------------------

function WarbandTD_OnAddonCompartmentClick()
    ns.ToggleMainFrame()
end

-- ---------------------------------------------------------------------------
-- Class color helper
-- ---------------------------------------------------------------------------

--- Map lowercase class file names to WoW color codes.
local CLASS_COLOR_MAP = {
    warrior     = "|cFFC69B6D",
    paladin     = "|cFFF48CBA",
    hunter      = "|cFFAAD372",
    rogue       = "|cFFFFF468",
    priest      = "|cFFFFFFFF",
    deathknight = "|cFFC41E3A",
    shaman      = "|cFF0070DD",
    mage        = "|cFF3FC7EB",
    warlock     = "|cFF8788EE",
    monk        = "|cFF00FF98",
    druid       = "|cFFFF7C0A",
    demonhunter = "|cFFA330C9",
    evoker      = "|cFF33937F",
}

function ns.ClassColor(classFile)
    return CLASS_COLOR_MAP[classFile:lower():gsub(" ", "")] or "|cFFFFFFFF"
end

function ns.ClassColorRGB(classFile)
    local colors = {
        warrior     = {0.78, 0.61, 0.43},
        paladin     = {0.96, 0.55, 0.73},
        hunter      = {0.67, 0.83, 0.45},
        rogue       = {1.00, 0.96, 0.41},
        priest      = {1.00, 1.00, 1.00},
        deathknight = {0.77, 0.12, 0.23},
        shaman      = {0.00, 0.44, 0.87},
        mage        = {0.25, 0.78, 0.92},
        warlock     = {0.53, 0.53, 0.93},
        monk        = {0.00, 1.00, 0.60},
        druid       = {1.00, 0.49, 0.04},
        demonhunter = {0.64, 0.19, 0.79},
        evoker      = {0.20, 0.58, 0.50},
    }
    return colors[classFile:lower():gsub(" ", "")] or {1, 1, 1}
end

-- ---------------------------------------------------------------------------
-- Keybinding globals
-- ---------------------------------------------------------------------------

BINDING_NAME_WARBANDTD_TOWER1 = "Tower 1 Ability"
BINDING_NAME_WARBANDTD_TOWER2 = "Tower 2 Ability"
BINDING_NAME_WARBANDTD_TOWER3 = "Tower 3 Ability"
BINDING_NAME_WARBANDTD_TOWER4 = "Tower 4 Ability"
BINDING_NAME_WARBANDTD_TOWER5 = "Tower 5 Ability"
BINDING_NAME_WARBANDTD_NEXWAVE = "Next Wave"

function WarbandTD_ActivateTower(index)
    if ns.state then
        ns.ActivateTowerAbility(index)
    end
end

function WarbandTD_NextWave()
    if ns.state and ns.state.phase == ns.PHASE_BETWEEN_WAVES then
        ns.NextWave()
    end
end
