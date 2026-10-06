local addonName, ns = ...

local mover
local moving = false
local updateElapsed = 0

local function GetScreenPosition(frame)
    local frameX, frameY = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()

    if not frameX or not frameY or not parentX or not parentY then
        return 0, 0
    end

    return frameX - parentX, frameY - parentY
end

local function UpdateStoredPosition()
    if not mover then
        return
    end

    local x, y = GetScreenPosition(mover)
    local settings = ns.db.bars.bar1.position

    settings.point = "CENTER"
    settings.relativePoint = "CENTER"
    settings.x = math.floor(x + 0.5)
    settings.y = math.floor(y + 0.5)

    if ns.RefreshConfig then
        ns.RefreshConfig()
    end
end

local function ApplyBarToMover()
    if not mover or not ns.Bar1 then
        return
    end

    ns.Bar1:ClearAllPoints()
    ns.Bar1:SetPoint("CENTER", mover, "CENTER")
end

local function SavePosition()
    if not mover or not ns.Bar1 then
        return
    end

    UpdateStoredPosition()

    local settings = ns.db.bars.bar1.position

    ns.Bar1:ClearAllPoints()
    ns.Bar1:SetPoint(
        "CENTER",
        UIParent,
        "CENTER",
        settings.x,
        settings.y
    )
end

local function SyncMoverToBar()
    if not mover or not ns.Bar1 then
        return
    end

    mover:ClearAllPoints()
    mover:SetPoint("CENTER", ns.Bar1, "CENTER")
    mover:SetSize(ns.Bar1:GetWidth(), ns.Bar1:GetHeight())
end

local function CreateMover()
    if mover then
        return mover
    end

    mover = CreateFrame(
        "Frame",
        "MythIncActionBarsBar1Mover",
        UIParent,
        "BackdropTemplate"
    )

    mover:SetFrameStrata("DIALOG")
    mover:SetMovable(true)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetClampedToScreen(true)
    mover:Hide()

    mover:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })

    mover:SetBackdropColor(.1, 0.55, 0.85, 0.10)
    mover:SetBackdropBorderColor(0.25, 0.75, 1, 0.95)

    local label = mover:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )

    label:SetPoint("CENTER")
    label:SetText("BAR 1")
    label:SetTextColor(0.85, 0.95, 1)
    label:SetShadowColor(0, 0, 0, 1)
    label:SetShadowOffset(1, -1)

    mover:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then
            return
        end

        moving = true
        updateElapsed = 0

        self:StartMoving()
        ApplyBarToMover()
    end)

    mover:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()

        moving = false

        SavePosition()
        SyncMoverToBar()
    end)

    mover:SetScript("OnUpdate", function(_, elapsed)
        if not moving then
            return
        end

        updateElapsed = updateElapsed + elapsed

        if updateElapsed < 0.05 then
            return
        end

        updateElapsed = 0
        UpdateStoredPosition()
    end)

    return mover
end

function ns.SetBar1Unlocked(unlocked)
    local frame = CreateMover()

    if not ns.Bar1 then
        return
    end

    if InCombatLockdown() then
        return
    end

    if unlocked then
        SyncMoverToBar()
        frame:Show()
    else
        if moving then
            frame:StopMovingOrSizing()
            moving = false
            SavePosition()
        end

        frame:Hide()
    end
end

function ns.IsBar1Unlocked()
    return mover and mover:IsShown() or false
end

function ns.RefreshBar1Mover()
    if mover and mover:IsShown() and not moving then
        SyncMoverToBar()
    end
end