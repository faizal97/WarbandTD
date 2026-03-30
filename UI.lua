-- ---------------------------------------------------------------------------
-- WarbandTD — UI.lua
-- Frame creation, layout, rendering, and frame pools.
-- ---------------------------------------------------------------------------

local _, ns = ...

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

local GAME_WIDTH = 600
local GAME_HEIGHT = 400
local LANE_COUNT = 3
local HEADER_HEIGHT = 30
local AFFIX_BAR_HEIGHT = 24
local TOWER_BAR_HEIGHT = 50
local LANE_HEIGHT = (GAME_HEIGHT - HEADER_HEIGHT - AFFIX_BAR_HEIGHT - TOWER_BAR_HEIGHT) / LANE_COUNT

local ENEMY_SIZE = 24
local BOSS_SIZE = 36
local TOWER_SIZE = 40
local DAMAGE_TEXT_POOL_SIZE = 15
local ENEMY_POOL_SIZE = 25
local PROJECTILE_POOL_SIZE = 12

-- Colors
local GOLD = {1.0, 0.82, 0.0}
local EPIC_PURPLE = {0.64, 0.21, 0.93}
local BG_DARK = {0.08, 0.08, 0.10, 0.92}
local BORDER_COLOR = {0.30, 0.30, 0.32, 1.0}
local GOAL_RED = {1.0, 0.0, 0.0, 0.30}

-- ---------------------------------------------------------------------------
-- Frame pools
-- ---------------------------------------------------------------------------

local enemyPool = {}
local damageTextPool = {}
local projectilePool = {}

-- ---------------------------------------------------------------------------
-- Build the main UI
-- ---------------------------------------------------------------------------

function ns.BuildUI()
    if ns.mainFrame then return end

    local f = CreateFrame("Frame", "WarbandTD_MainFrame", UIParent, "BackdropTemplate")
    f:SetSize(GAME_WIDTH, GAME_HEIGHT)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4},
    })
    f:SetBackdropColor(unpack(BG_DARK))
    f:SetBackdropBorderColor(unpack(BORDER_COLOR))
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:Hide()

    ns.mainFrame = f

    -- Build sub-frames
    ns._BuildHeader(f)
    ns._BuildAffixBar(f)
    ns._BuildLanes(f)
    ns._BuildTowerBar(f)
    ns._BuildEnemyPool(f)
    ns._BuildDamageTextPool(f)
    ns._BuildProjectilePool(f)

    -- Game loop
    f:SetScript("OnUpdate", function(self, elapsed)
        if ns.state and ns.state.phase == ns.PHASE_PLAYING then
            local dt = math.min(elapsed, 0.5)
            ns.Tick(dt)
            ns._UpdateAllFrames()
        end
    end)
end

function ns.ToggleMainFrame()
    if not ns.mainFrame then return end
    if ns.mainFrame:IsShown() then
        ns.mainFrame:Hide()
    else
        ns.mainFrame:Show()
        -- If no game is running, start setup with roster
        if not ns.state then
            ns._ShowSetup()
        end
    end
end

-- ---------------------------------------------------------------------------
-- Header
-- ---------------------------------------------------------------------------

function ns._BuildHeader(parent)
    local h = CreateFrame("Frame", nil, parent)
    h:SetHeight(HEADER_HEIGHT)
    h:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -4)
    h:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -4)

    -- Title
    h.title = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.title:SetPoint("LEFT", 8, 0)
    h.title:SetText("WarbandTD")
    h.title:SetTextColor(unpack(GOLD))

    -- Wave counter
    h.wave = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.wave:SetPoint("CENTER", 0, 0)
    h.wave:SetTextColor(0.7, 0.7, 0.7)

    -- Lives
    h.lives = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.lives:SetPoint("RIGHT", -30, 0)
    h.lives:SetTextColor(1, 0.3, 0.3)

    -- Close button
    local close = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -2, -2)
    close:SetSize(20, 20)

    parent.header = h
end

-- ---------------------------------------------------------------------------
-- Affix bar
-- ---------------------------------------------------------------------------

function ns._BuildAffixBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(AFFIX_BAR_HEIGHT)
    bar:SetPoint("TOPLEFT", parent.header, "BOTTOMLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", parent.header, "BOTTOMRIGHT", 0, 0)

    bar.icons = {}
    for i = 1, 3 do
        local af = CreateFrame("Frame", nil, bar)
        af:SetSize(60, 18)
        if i == 1 then
            af:SetPoint("LEFT", 8, 0)
        else
            af:SetPoint("LEFT", bar.icons[i - 1], "RIGHT", 6, 0)
        end

        af.text = af:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        af.text:SetPoint("CENTER")
        af.text:SetTextColor(1.0, 0.65, 0.0)
        af.text:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        af:Hide()

        bar.icons[i] = af
    end

    -- Kill count
    bar.kills = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.kills:SetPoint("RIGHT", -8, 0)
    bar.kills:SetTextColor(0.7, 0.7, 0.7)
    bar.kills:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")

    parent.affixBar = bar
end

-- ---------------------------------------------------------------------------
-- Lanes
-- ---------------------------------------------------------------------------

function ns._BuildLanes(parent)
    parent.lanes = {}

    for i = 0, LANE_COUNT - 1 do
        local lane = CreateFrame("Frame", nil, parent)
        lane:SetHeight(LANE_HEIGHT)
        local yOff = -(HEADER_HEIGHT + AFFIX_BAR_HEIGHT + i * LANE_HEIGHT)
        lane:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, yOff)
        lane:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, yOff)

        -- Lane divider
        if i < LANE_COUNT - 1 then
            local div = lane:CreateTexture(nil, "ARTWORK")
            div:SetHeight(1)
            div:SetPoint("BOTTOMLEFT")
            div:SetPoint("BOTTOMRIGHT")
            div:SetColorTexture(0.3, 0.3, 0.3, 0.5)
        end

        -- Goal line (left edge)
        local goal = lane:CreateTexture(nil, "ARTWORK")
        goal:SetWidth(3)
        goal:SetPoint("TOPLEFT")
        goal:SetPoint("BOTTOMLEFT")
        goal:SetColorTexture(unpack(GOAL_RED))

        -- Slot markers (subtle vertical lines at slot positions)
        for s = 1, 3 do
            local marker = lane:CreateTexture(nil, "BACKGROUND")
            marker:SetWidth(1)
            marker:SetHeight(LANE_HEIGHT * 0.6)
            marker:SetPoint("CENTER", lane, "RIGHT",
                -((1.0 - ({0.25, 0.55, 0.85})[s]) * (GAME_WIDTH - 8)), 0)
            marker:SetColorTexture(1, 1, 1, 0.05)
        end

        lane.laneIndex = i
        parent.lanes[i] = lane
    end
end

-- ---------------------------------------------------------------------------
-- Tower bar (bottom)
-- ---------------------------------------------------------------------------

function ns._BuildTowerBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(TOWER_BAR_HEIGHT)
    bar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 4, 4)
    bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -4, 4)

    -- Wave/Begin button
    bar.waveBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    bar.waveBtn:SetSize(100, 24)
    bar.waveBtn:SetPoint("RIGHT", -8, 0)
    bar.waveBtn:SetText("Begin")
    bar.waveBtn:SetScript("OnClick", function()
        if not ns.state then return end
        if ns.state.phase == ns.PHASE_SETUP then
            ns.BeginGame()
        elseif ns.state.phase == ns.PHASE_BETWEEN_WAVES then
            ns.NextWave()
        end
    end)

    -- Tower ability slots (up to 5)
    bar.slots = {}
    for i = 1, 5 do
        local slot = CreateFrame("Button", nil, bar)
        slot:SetSize(36, 36)
        slot:SetPoint("LEFT", 8 + (i - 1) * 42, 0)

        slot.icon = slot:CreateTexture(nil, "ARTWORK")
        slot.icon:SetAllPoints()
        slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        slot.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

        slot.cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
        slot.cooldown:SetAllPoints(slot.icon)
        slot.cooldown:SetDrawEdge(true)

        -- Ultimate charge bar
        slot.ultBar = CreateFrame("StatusBar", nil, slot)
        slot.ultBar:SetSize(36, 3)
        slot.ultBar:SetPoint("BOTTOM", slot, "BOTTOM", 0, -4)
        slot.ultBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        slot.ultBar:SetStatusBarColor(unpack(EPIC_PURPLE))
        slot.ultBar:SetMinMaxValues(0, 1)

        slot:SetScript("OnClick", function()
            ns.ActivateTowerAbility(i)
        end)

        slot:Hide()
        bar.slots[i] = slot
    end

    parent.towerBar = bar
end

-- ---------------------------------------------------------------------------
-- Object pools
-- ---------------------------------------------------------------------------

function ns._BuildEnemyPool(parent)
    for i = 1, ENEMY_POOL_SIZE do
        local f = CreateFrame("Frame", nil, parent)
        f:SetSize(ENEMY_SIZE, ENEMY_SIZE)
        f:SetFrameLevel(parent:GetFrameLevel() + 5)

        -- Body texture
        f.body = f:CreateTexture(nil, "ARTWORK")
        f.body:SetAllPoints()
        f.body:SetColorTexture(1, 0, 0)

        -- HP bar
        f.hpBar = CreateFrame("StatusBar", nil, f)
        f.hpBar:SetSize(ENEMY_SIZE + 4, 3)
        f.hpBar:SetPoint("BOTTOM", f, "TOP", 0, 2)
        f.hpBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        f.hpBar:SetStatusBarColor(1, 0, 0)
        f.hpBar:SetMinMaxValues(0, 1)

        local hpBg = f.hpBar:CreateTexture(nil, "BACKGROUND")
        hpBg:SetAllPoints()
        hpBg:SetColorTexture(0.2, 0, 0, 0.8)

        -- Shield glow
        f.shield = f:CreateTexture(nil, "OVERLAY")
        f.shield:SetPoint("TOPLEFT", -2, 2)
        f.shield:SetPoint("BOTTOMRIGHT", 2, -2)
        f.shield:SetColorTexture(0.31, 0.76, 0.97, 0.4)
        f.shield:Hide()

        f:Hide()
        f.inUse = false
        enemyPool[i] = f
    end
end

function ns._BuildDamageTextPool(parent)
    for i = 1, DAMAGE_TEXT_POOL_SIZE do
        local f = CreateFrame("Frame", nil, parent)
        f:SetSize(60, 20)
        f:SetFrameLevel(parent:GetFrameLevel() + 10)

        f.text = f:CreateFontString(nil, "OVERLAY")
        f.text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        f.text:SetPoint("CENTER")

        -- Animation: float up + fade out
        f.ag = f:CreateAnimationGroup()

        local translate = f.ag:CreateAnimation("Translation")
        translate:SetOffset(0, 30)
        translate:SetDuration(0.8)
        translate:SetSmoothing("OUT")

        local fade = f.ag:CreateAnimation("Alpha")
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0)
        fade:SetDuration(0.8)
        fade:SetSmoothing("IN")

        f.ag:SetScript("OnFinished", function()
            f:Hide()
            f.inUse = false
        end)

        f:Hide()
        f.inUse = false
        damageTextPool[i] = f
    end
end

function ns._BuildProjectilePool(parent)
    for i = 1, PROJECTILE_POOL_SIZE do
        local f = CreateFrame("Frame", nil, parent)
        f:SetSize(8, 3)
        f:SetFrameLevel(parent:GetFrameLevel() + 7)

        f.tex = f:CreateTexture(nil, "OVERLAY")
        f.tex:SetAllPoints()
        f.tex:SetColorTexture(1, 1, 1)

        f.ag = f:CreateAnimationGroup()
        local move = f.ag:CreateAnimation("Translation")
        move:SetDuration(0.15)
        move:SetSmoothing("NONE")
        f.moveAnim = move

        f.ag:SetScript("OnFinished", function()
            f:Hide()
            f.inUse = false
        end)

        f:Hide()
        f.inUse = false
        projectilePool[i] = f
    end
end

--- Get a frame from a pool.
local function GetFromPool(pool)
    for _, f in ipairs(pool) do
        if not f.inUse then
            f.inUse = true
            return f
        end
    end
    return nil -- pool exhausted
end

--- Release all frames in a pool.
local function ReleasePool(pool)
    for _, f in ipairs(pool) do
        f:Hide()
        f.inUse = false
    end
end

-- ---------------------------------------------------------------------------
-- Frame update (called every tick during PLAYING phase)
-- ---------------------------------------------------------------------------

function ns._UpdateAllFrames()
    local state = ns.state
    if not state then return end
    local mf = ns.mainFrame

    -- Update header
    if mf.header then
        local dunName = state.dungeon and state.dungeon.name or "Unknown"
        mf.header.title:SetText(format("%s +%d", dunName:upper(), state.keystoneLevel))
        mf.header.title:SetTextColor(unpack(EPIC_PURPLE))
        mf.header.wave:SetText(format("WAVE %d/%d", state.currentWave, state.totalWaves))
        mf.header.lives:SetText(format("♥ %d", state.lives))

        -- Lives color
        if state.lives > state.maxLives * 0.6 then
            mf.header.lives:SetTextColor(1, 1, 1)
        elseif state.lives > state.maxLives * 0.3 then
            mf.header.lives:SetTextColor(1, 0.65, 0)
        else
            mf.header.lives:SetTextColor(1, 0.2, 0.2)
        end
    end

    -- Update affix bar
    if mf.affixBar then
        for i, af in ipairs(mf.affixBar.icons) do
            if state.affixes[i] then
                af.text:SetText(state.affixes[i]:upper())
                af:Show()
            else
                af:Hide()
            end
        end
        mf.affixBar.kills:SetText(format("☠ %d", state.enemiesKilled))
    end

    -- Release enemy pool, then assign
    ReleasePool(enemyPool)
    for _, enemy in ipairs(state.enemies) do
        if not enemy.isDead and enemy.position >= 0 and enemy.position < 1.0 then
            local lane = mf.lanes[enemy.laneIndex]
            if lane then
                local ef = GetFromPool(enemyPool)
                if ef then
                    local size = enemy.isBoss and BOSS_SIZE or ENEMY_SIZE
                    ef:SetSize(size, size)
                    ef:SetParent(lane)

                    local laneWidth = lane:GetWidth()
                    local x = (1.0 - enemy.position) * (laneWidth - size)
                    local y = (LANE_HEIGHT - size) / 2

                    ef:ClearAllPoints()
                    ef:SetPoint("BOTTOMLEFT", lane, "BOTTOMLEFT", x, y)

                    -- Color
                    local color = enemy.isBoss
                        and (state.dungeon.bossColor or {1, 0.3, 0.2})
                        or (state.dungeon.enemyColor or {1, 0, 0})
                    ef.body:SetColorTexture(color[1], color[2], color[3], 0.7)

                    -- HP bar
                    ef.hpBar:SetMinMaxValues(0, enemy.maxHp)
                    ef.hpBar:SetValue(enemy.hp)
                    ef.hpBar:SetStatusBarColor(color[1], color[2], color[3])

                    -- Shield
                    ef.shield:SetShown((enemy.modifierState.shield_hits or 0) > 0)

                    -- Invulnerability
                    ef:SetAlpha(enemy.modifierState.phase_invuln and 0.4 or 1.0)

                    ef:Show()
                end
            end
        end
    end

    -- Show hit events as damage text
    for _, hit in ipairs(state.hitEvents) do
        local lane = mf.lanes[hit.enemyLane]
        if lane then
            local dtf = GetFromPool(damageTextPool)
            if dtf then
                local dmg = math.floor(hit.damage + 0.5)
                dtf.text:SetText(tostring(dmg))
                dtf.text:SetTextColor(unpack(hit.attackColor or {1, 1, 1}))
                dtf:SetParent(lane)
                dtf:ClearAllPoints()
                local laneWidth = lane:GetWidth()
                local x = (1.0 - hit.enemyX) * laneWidth
                dtf:SetPoint("CENTER", lane, "BOTTOMLEFT", x, LANE_HEIGHT / 2)
                dtf:Show()
                dtf.ag:Stop()
                dtf.ag:Play()
            end
        end
    end

    -- Update tower bar
    if mf.towerBar then
        local btnText = "Begin"
        if state.phase == ns.PHASE_PLAYING then
            btnText = "Fighting..."
            mf.towerBar.waveBtn:Disable()
        elseif state.phase == ns.PHASE_BETWEEN_WAVES then
            btnText = "Next Wave"
            mf.towerBar.waveBtn:Enable()
        elseif state.phase == ns.PHASE_SETUP then
            btnText = "Begin"
            mf.towerBar.waveBtn:Enable()
        elseif state.phase == ns.PHASE_VICTORY then
            btnText = format("Victory! ★%d", ns.GetStarRating())
            mf.towerBar.waveBtn:Disable()
        elseif state.phase == ns.PHASE_DEFEAT then
            btnText = "Defeated"
            mf.towerBar.waveBtn:Disable()
        end
        mf.towerBar.waveBtn:SetText(btnText)

        -- Update tower ability slots
        for i, slot in ipairs(mf.towerBar.slots) do
            local tower = state.towers[i]
            if tower and tower.classDef.activeAbility then
                slot.icon:SetTexture(tower.classDef.activeAbility.icon
                    or "Interface\\Icons\\INV_Misc_QuestionMark")
                slot:Show()

                -- Cooldown sweep
                if tower.activeCooldownRemaining > 0 then
                    local ability = tower.classDef.activeAbility
                    slot.cooldown:SetCooldown(
                        GetTime() - ((ability.cooldown or 10) - tower.activeCooldownRemaining),
                        ability.cooldown or 10
                    )
                end

                -- Ultimate charge bar
                if tower.classDef.ultimateAbility and tower.classDef.ultimateAbility.charge then
                    local charge = tower.classDef.ultimateAbility.charge
                    slot.ultBar:SetMinMaxValues(0, charge.max or 10)
                    slot.ultBar:SetValue(tower.ultimateCharge or 0)
                    slot.ultBar:Show()
                else
                    slot.ultBar:Hide()
                end
            else
                slot:Hide()
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Setup screen (roster → tower selection)
-- ---------------------------------------------------------------------------

function ns._ShowSetup()
    -- Quick start: use the first dungeon and first 5 roster chars
    local roster = ns.GetRoster()
    if #roster == 0 then
        ns.Print("No characters in your warband! Log into alts to register them.")
        return
    end

    local selected = {}
    for i = 1, math.min(5, #roster) do
        selected[i] = roster[i]
    end

    local dungeons = ns.GetRotationDungeons()
    local dungeon = dungeons[1]
    if not dungeon then
        ns.Print("No dungeons available.")
        return
    end

    local level = ns.db.keystoneLevel or 2
    ns.StartRun(selected, level, dungeon)

    -- Auto-place towers in default positions
    for i, tower in ipairs(ns.state.towers) do
        local lane = ((i - 1) % LANE_COUNT)
        local slot = math.ceil(i / LANE_COUNT)
        ns.MoveTower(i, lane, math.min(slot, 3))
    end

    ns._UpdateAllFrames()
end
