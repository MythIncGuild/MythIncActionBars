local addonName, ns = ...

local CreateCustomActionButton = ns.CreateCustomActionButton

local function IsReadable(value)
    return not issecretvalue or not issecretvalue(value)
end

local function GetMountAssignment(button)
    local settings =
        ns.db
        and ns.db.bars
        and ns.db.bars[button.barID]

    local assignment =
        settings
        and settings.assignments
        and settings.assignments[button.buttonID]

    if assignment and assignment.type == "mount" then
        return assignment
    end
end

function ns.CreateCustomActionButton(parent, name, barID, buttonID)
    local button = CreateCustomActionButton(
        parent,
        name,
        barID,
        buttonID
    )

    local overlay = CreateFrame("Frame", nil, button)

    overlay:SetAllPoints(button.icon)
    overlay:SetFrameLevel(button.cooldown:GetFrameLevel() + 2)
    overlay:EnableMouse(false)

    local fill = overlay:CreateTexture(nil, "OVERLAY")

    fill:SetColorTexture(1, 0.72, 0.12, 0.32)
    fill:SetPoint("TOPLEFT", overlay, "TOPLEFT")
    fill:SetPoint("TOPRIGHT", overlay, "TOPRIGHT")

    local edge = overlay:CreateTexture(nil, "OVERLAY", nil, 1)

    edge:SetColorTexture(1, 0.86, 0.4, 0.9)
    edge:SetHeight(2)

    local castStart
    local castEnd
    local mountID

    local function StopCast()
        castStart = nil
        castEnd = nil
        mountID = nil

        overlay:Hide()
    end

    local function UpdateCast()
        if not castStart or not castEnd then
            return
        end

        local assignment = GetMountAssignment(button)

        if not assignment or assignment.id ~= mountID then
            StopCast()
            return
        end

        local now = GetTime()

        if now >= castEnd then
            StopCast()
            return
        end

        local progress = math.max(
            0,
            math.min(
                1,
                (now - castStart) / (castEnd - castStart)
            )
        )

        local height = math.max(
            0.01,
            overlay:GetHeight() * progress
        )

        fill:SetHeight(height)

        edge:ClearAllPoints()
        edge:SetPoint(
            "TOPLEFT",
            overlay,
            "TOPLEFT",
            0,
            -height
        )

        edge:SetPoint(
            "TOPRIGHT",
            overlay,
            "TOPRIGHT",
            0,
            -height
        )
    end

    local function StartCast(eventSpellID)
        if not IsReadable(eventSpellID) then
            return
        end

        local assignment = GetMountAssignment(button)

        if not assignment then
            return
        end

        local _, mountSpellID =
            C_MountJournal.GetMountInfoByID(assignment.id)

        if not mountSpellID or eventSpellID ~= mountSpellID then
            return
        end

        local _, _, _, startMS, endMS = UnitCastingInfo("player")

        if not IsReadable(startMS) or not IsReadable(endMS) then
            return
        end

        if type(startMS) ~= "number"
            or type(endMS) ~= "number"
            or endMS <= startMS
        then
            return
        end

        castStart = startMS / 1000
        castEnd = endMS / 1000
        mountID = assignment.id

        overlay:Show()
        UpdateCast()
    end

    overlay:SetScript("OnUpdate", UpdateCast)
    overlay:Hide()

    button:HookScript("OnHide", StopCast)
    button.CustomCastOverlay = overlay

    local events = CreateFrame("Frame")

    events:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
    events:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player")
    events:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    events:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
    events:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")

    events:SetScript(
        "OnEvent",
        function(_, event, unit, castGUID, spellID)
            if event == "PLAYER_ENTERING_WORLD" then
                StopCast()
                return
            end

            if unit ~= "player" then
                return
            end

            if event == "UNIT_SPELLCAST_START"
                or event == "UNIT_SPELLCAST_DELAYED"
            then
                StartCast(spellID)
            else
                StopCast()
            end
        end
    )

    return button
end