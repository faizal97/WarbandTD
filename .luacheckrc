std = "lua51"
max_line_length = false
exclude_files = { "Libs/" }
ignore = { "211", "212" }

globals = {
    "WarbandTD_DB",
    "WarbandTD_OnAddonCompartmentClick",
    "SLASH_WARBANDTD1",
    "SLASH_WARBANDTD2",
    "SlashCmdList",
    "BINDING_NAME_WARBANDTD_TOWER1",
    "BINDING_NAME_WARBANDTD_TOWER2",
    "BINDING_NAME_WARBANDTD_TOWER3",
    "BINDING_NAME_WARBANDTD_TOWER4",
    "BINDING_NAME_WARBANDTD_TOWER5",
    "BINDING_NAME_WARBANDTD_NEXWAVE",
    "WarbandTD_ActivateTower",
    "WarbandTD_NextWave",
}

read_globals = {
    -- WoW API
    "CreateFrame", "UIParent", "GetLocale", "GetBuildInfo",
    "UnitName", "UnitClass", "GetRealmName", "GetAverageItemLevel",
    "C_Timer", "C_AddOns", "hooksecurefunc", "InCombatLockdown",
    "PlaySoundFile", "PlaySound",
    "GameTooltip", "GameFontNormal", "GameFontHighlight",
    "GameFontHighlightLarge", "GameFontNormalHuge",
    "RAID_CLASS_COLORS", "WOW_PROJECT_ID", "WOW_PROJECT_MAINLINE",
    "LibStub", "Settings", "StaticPopupDialogs", "StaticPopup_Show",
    "BackdropTemplateMixin",
    -- Lua globals
    "strsplit", "format", "tinsert", "tremove", "wipe",
    "floor", "ceil", "abs", "min", "max", "random", "sqrt",
    "print", "date", "time", "type", "pairs", "ipairs", "unpack",
    "tostring", "tonumber", "select", "error", "pcall",
    "table", "string", "math",
    "getmetatable", "setmetatable", "rawget", "rawset",
}
