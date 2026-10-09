local addonName, ns = ...

ns.Movers = ns.Movers or {}

local unlockedBars = {}
local moveModeActive = false

local function GetBar(barID)
    return ns.Bars and ns.Bars[barID]
end

local function GetSettings(barID)
    return ns.db and ns.db.bars and ns.db.bars[barID]
end

local function GetCursorUIPosition()
    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    if not scale or scale <= 0 then scale = 1 end
    return cursorX / scale, cursorY / scale
end

local function ApplyBarPosition(barID, x, y)
    local bar = GetBar(barID)
    local settings = GetSettings(barID)
    if not bar or not settings then return end

    settings.position = settings.position or {}
    settings.position.point = "CENTER"
    settings.position.relativePoint = "CENTER"
    settings.position.x = x
    settings.position.y = y

    bar:ClearAllPoints()
    bar:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

local function CreateMover(barID)
    local existing = ns.Movers[barID]
    if existing then return existing end

    local bar = GetBar(barID)
    if not bar then return nil end

    local mover = CreateFrame(
        "Frame",
        "MythIncActionBarsMover" .. barID,
        bar,
        "BackdropTemplate"
    )
    mover:SetAllPoints(bar)
    mover:SetFrameLevel(bar:GetFrameLevel() + 50)
    mover:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    mover:SetBackdropColor(0.05, 0.45, 0.60, 0.25)
    mover:SetBackdropBorderColor(0.15, 0.75, 0.90, 1)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")

    local label = mover:CreateFontString(
        nil, "OVERLAY", "GameFontNormalSmall"
    )
    label:SetPoint("CENTER")
    label:SetTextColor(1, 1, 1, 1)
    mover.Label = label

    local dragging = false
    local startCursorX, startCursorY = 0, 0
    local startBarX, startBarY = 0, 0
    local currentX, currentY = 0, 0

    mover:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.05, 0.55, 0.72, 0.35)
        self:SetBackdropBorderColor(0.25, 0.90, 1, 1)
    end)

    mover:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.05, 0.45, 0.60, 0.25)
        self:SetBackdropBorderColor(0.15, 0.75, 0.90, 1)
    end)

    mover:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end

        local settings = GetSettings(barID)
        if not settings or not settings.position then return end

        dragging = true
        startCursorX, startCursorY = GetCursorUIPosition()
        startBarX = tonumber(settings.position.x) or 0
        startBarY = tonumber(settings.position.y) or 0
        currentX, currentY = startBarX, startBarY
    end)

    mover:SetScript("OnUpdate", function()
        if not dragging then return end

        local cursorX, cursorY = GetCursorUIPosition()
        local deltaX = cursorX - startCursorX
        local deltaY = cursorY - startCursorY
        local settings = GetSettings(barID)
        local scale = settings and tonumber(settings.scale) or 1
        if scale <= 0 then scale = 1 end

        currentX = startBarX + deltaX / scale
        currentY = startBarY + deltaY / scale
        ApplyBarPosition(barID, currentX, currentY)
    end)

    mover:SetScript("OnDragStop", function()
        if not dragging then return end
        dragging = false

        currentX = math.floor(currentX + 0.5)
        currentY = math.floor(currentY + 0.5)
        ApplyBarPosition(barID, currentX, currentY)

        if ns.RefreshConfig then ns.RefreshConfig() end
    end)

    mover:Hide()
    ns.Movers[barID] = mover
    return mover
end

function ns.RefreshBarMover(barID)
    local bar = GetBar(barID)
    local settings = GetSettings(barID)

    if not bar or not settings then
        local mover = ns.Movers[barID]
        if mover then mover:Hide() end
        return
    end

    local mover = CreateMover(barID)
    if not mover then return end

    mover:ClearAllPoints()
    mover:SetAllPoints(bar)
    mover:SetFrameLevel(bar:GetFrameLevel() + 50)
    mover.Label:SetText(settings.name or ("Bar " .. barID))

    local shouldShow = unlockedBars[barID]
        and settings.enabled
        and bar:IsShown()

    mover:SetShown(shouldShow and true or false)
end

function ns.IsBarUnlocked(barID)
    return unlockedBars[barID] == true
end

function ns.SetBarUnlocked(barID, unlocked)
    local settings = GetSettings(barID)
    if not settings then return false, "missing" end
    if InCombatLockdown() then return false, "combat" end
    if unlocked and not settings.enabled then
        return false, "disabled"
    end

    unlockedBars[barID] = unlocked and true or nil
    ns.RefreshBarMover(barID)
    return true
end

function ns.IsMoveModeActive()
    return moveModeActive
end

function ns.GetUnlockedBarCount()
    local count = 0
    for barID in pairs(unlockedBars) do
        if ns.IsBarUnlocked(barID) then count = count + 1 end
    end
    return count
end

function ns.AreAllEnabledBarsUnlocked()
    if not ns.db or not ns.db.bars then return false end

    local foundEnabled = false
    for barID, settings in pairs(ns.db.bars) do
        if type(barID) == "number"
            and type(settings) == "table"
            and settings.enabled then
            foundEnabled = true
            if not ns.IsBarUnlocked(barID) then return false end
        end
    end
    return foundEnabled
end

function ns.SetAllBarsUnlocked(unlocked)
    if InCombatLockdown() then return false, "combat" end

    moveModeActive = unlocked and true or false

    for barID, settings in pairs(ns.db.bars) do
        if type(barID) == "number"
            and type(settings) == "table" then
            if unlocked and settings.enabled then
                unlockedBars[barID] = true
            else
                unlockedBars[barID] = nil
            end
            ns.RefreshBarMover(barID)
        end
    end

    if ns.RefreshConfig then ns.RefreshConfig() end
    return true
end

function ns.ToggleAllBarsUnlocked()
    if moveModeActive or ns.AreAllEnabledBarsUnlocked() then
        return ns.SetAllBarsUnlocked(false)
    end
    return ns.SetAllBarsUnlocked(true)
end

function ns.LockAllBars()
    return ns.SetAllBarsUnlocked(false)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:SetScript("OnEvent", function()
    if moveModeActive or ns.GetUnlockedBarCount() > 0 then
        ns.SetAllBarsUnlocked(false)
    end
end)

local function InheritUnlock(barID)
    if not InCombatLockdown() and ns.IsMoveModeActive() then
        local settings = GetSettings(barID)
        if settings and settings.enabled then
            ns.SetBarUnlocked(barID, true)
        end
    end
end

local setBarEnabled = ns.SetBarEnabled
ns.SetBarEnabled = function(barID, enabled)
    local settings = GetSettings(barID)
    local wasEnabled = settings and settings.enabled

    local result, reason = setBarEnabled(barID, enabled)
    if enabled and not wasEnabled then InheritUnlock(barID) end
    return result, reason
end

local addBar = ns.AddBar
ns.AddBar = function(...)
    local barID, reason = addBar(...)
    if type(barID) == "number" then InheritUnlock(barID) end
    return barID, reason
end