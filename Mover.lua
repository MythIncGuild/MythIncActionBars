local addonName, ns = ...

ns.Movers = ns.Movers or {}

local function GetScreenPosition(frame)
    local frameX, frameY = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()

    if not frameX
        or not frameY
        or not parentX
        or not parentY
    then
        return 0, 0
    end

    return frameX - parentX, frameY - parentY
end

local function UpdateStoredPosition(barID, mover)
    local x, y = GetScreenPosition(mover)

    local settings =
        ns.db.bars[barID].position

    settings.point = "CENTER"
    settings.relativePoint = "CENTER"
    settings.x = math.floor(x + 0.5)
    settings.y = math.floor(y + 0.5)

    if ns.RefreshConfig then
        ns.RefreshConfig()
    end
end

local function ApplyBarToMover(barID, mover)
    local bar = ns.GetBar(barID)

    if not bar then
        return
    end

    bar:ClearAllPoints()
    bar:SetPoint("CENTER", mover, "CENTER")
end

local function SavePosition(barID, mover)
    local bar = ns.GetBar(barID)

    if not bar then
        return
    end

    UpdateStoredPosition(barID, mover)

    local settings =
        ns.db.bars[barID].position

    bar:ClearAllPoints()

    bar:SetPoint(
        "CENTER",
        UIParent,
        "CENTER",
        settings.x,
        settings.y
    )
end

local function SyncMoverToBar(barID, mover)
    local bar = ns.GetBar(barID)

    if not bar then
        return
    end

    mover:ClearAllPoints()
    mover:SetPoint("CENTER", bar, "CENTER")
    mover:SetSize(
        bar:GetWidth(),
        bar:GetHeight()
    )
end

local function CreateMover(barID)
    if ns.Movers[barID] then
        return ns.Movers[barID]
    end

    local mover = CreateFrame(
        "Frame",
        "MythIncActionBarsBar"
            .. barID
            .. "Mover",
        UIParent,
        "BackdropTemplate"
    )

    mover.barID = barID
    mover.moving = false
    mover.updateElapsed = 0

    mover:SetFrameStrata("DIALOG")
    mover:SetMovable(true)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetClampedToScreen(true)
    mover:Hide()

    mover:SetBackdrop({
        bgFile =
            "Interface\\Buttons\\WHITE8X8",
        edgeFile =
            "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })

    mover:SetBackdropColor(
        0.1,
        0.55,
        0.85,
        0.10
    )

    mover:SetBackdropBorderColor(
        0.25,
        0.75,
        1,
        0.95
    )

    local label = mover:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )

    label:SetPoint("CENTER")
    label:SetText(
        ns.db.bars[barID].name
    )

    label:SetTextColor(
        0.85,
        0.95,
        1
    )

    label:SetShadowColor(0, 0, 0, 1)
    label:SetShadowOffset(1, -1)

    mover.label = label

    mover:SetScript(
        "OnDragStart",
        function(self)
            if InCombatLockdown() then
                return
            end

            self.moving = true
            self.updateElapsed = 0

            self:StartMoving()

            ApplyBarToMover(
                barID,
                self
            )
        end
    )

    mover:SetScript(
        "OnDragStop",
        function(self)
            self:StopMovingOrSizing()

            self.moving = false

            SavePosition(
                barID,
                self
            )

            SyncMoverToBar(
                barID,
                self
            )
        end
    )

    mover:SetScript(
        "OnUpdate",
        function(self, elapsed)
            if not self.moving then
                return
            end

            self.updateElapsed =
                self.updateElapsed +
                elapsed

            if self.updateElapsed < 0.05 then
                return
            end

            self.updateElapsed = 0

            UpdateStoredPosition(
                barID,
                self
            )
        end
    )

    ns.Movers[barID] = mover

    return mover
end

function ns.SetBarUnlocked(barID, unlocked)
    local bar = ns.GetBar(barID)

    if not bar then
        return
    end

    if InCombatLockdown() then
        return
    end

    local settings = ns.db.bars[barID]

    if unlocked and not settings.enabled then
        return
    end

    local mover = CreateMover(barID)

    if unlocked then
        mover.label:SetText(settings.name)

        SyncMoverToBar(
            barID,
            mover
        )

        mover:Show()
    else
        if mover.moving then
            mover:StopMovingOrSizing()

            mover.moving = false

            SavePosition(
                barID,
                mover
            )
        end

        mover:Hide()
    end
end

function ns.IsBarUnlocked(barID)
    local mover = ns.Movers[barID]

    return mover
        and mover:IsShown()
        or false
end

function ns.RefreshBarMover(barID)
    local mover = ns.Movers[barID]

    if not mover
        or not mover:IsShown()
        or mover.moving
    then
        return
    end

    mover.label:SetText(
        ns.db.bars[barID].name
    )

    SyncMoverToBar(
        barID,
        mover
    )
end