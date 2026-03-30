-- ---------------------------------------------------------------------------
-- WarbandTD — Animations.lua
-- Projectile animations, damage text, hit flash effects.
-- Handled primarily via AnimationGroup in UI.lua pools.
-- This file contains utility functions for triggering animations.
-- ---------------------------------------------------------------------------

local _, ns = ...

--- Show a floating damage number at a position within a lane.
--- @param laneFrame Frame The lane frame to parent the text to.
--- @param x number X position within the lane (pixels from left).
--- @param y number Y position within the lane (pixels from bottom).
--- @param damage number Damage value to display.
--- @param isCrit boolean Whether this was a critical hit.
--- @param color table {r, g, b} color for the text.
function ns.ShowDamageText(laneFrame, x, y, damage, isCrit, color)
    -- Damage text is handled by the pool in UI.lua's _UpdateAllFrames.
    -- This function exists for manual triggers outside the normal tick cycle
    -- (e.g., ability effects, boss mechanics).
    -- For now, the pool is driven by hitEvents in the game state.
end

--- Flash an enemy frame white briefly (hit feedback).
--- @param enemyFrame Frame The enemy frame to flash.
function ns.FlashEnemy(enemyFrame)
    if not enemyFrame or not enemyFrame.body then return end

    -- Save original color
    local r, g, b = enemyFrame.body:GetVertexColor()

    -- Flash white
    enemyFrame.body:SetVertexColor(1, 1, 1, 1)

    -- Restore after a short delay
    C_Timer.After(0.05, function()
        if enemyFrame and enemyFrame.body then
            enemyFrame.body:SetVertexColor(r, g, b, 1)
        end
    end)
end

--- Trigger a screen shake effect on the main frame (for boss impacts).
--- @param intensity number Shake intensity in pixels.
--- @param duration number Shake duration in seconds.
function ns.ScreenShake(intensity, duration)
    local f = ns.mainFrame
    if not f then return end

    intensity = intensity or 3
    duration = duration or 0.2
    local elapsed = 0

    local shakeFrame = CreateFrame("Frame")
    shakeFrame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= duration then
            f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            self:SetScript("OnUpdate", nil)
            return
        end

        local ox = (math.random() - 0.5) * 2 * intensity
        local oy = (math.random() - 0.5) * 2 * intensity
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", ox, oy)
    end)
end
