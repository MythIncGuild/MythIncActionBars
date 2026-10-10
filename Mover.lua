local addonName, ns = ...

ns.Movers = ns.Movers or {}
local unlockedBars = {}
local moveModeActive = false
local placementReference
local SNAP_DISTANCE, BAR_GAP = 10, 4

local function GetBar(barID)
    return ns.Bars and ns.Bars[barID]
end

local function GetSettings(barID)
    return ns.db and ns.db.bars and ns.db.bars[barID]
end

local function Scale(bar)
    local scale = bar:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return scale > 0 and scale or 1
end

local function Rect(bar)
    local x, y = bar:GetCenter()
    if not x or not y then return end

    local scale = Scale(bar)
    local width = bar:GetWidth() * scale
    local height = bar:GetHeight() * scale
    x, y = x * scale, y * scale

    return {
        x = x,
        y = y,
        width = width,
        height = height,
        left = x - width / 2,
        right = x + width / 2,
        bottom = y - height / 2,
        top = y + height / 2,
    }
end

local function ApplyBarPosition(barID, x, y)
    local bar, settings = GetBar(barID), GetSettings(barID)
    if not bar or not settings or InCombatLockdown() then
        return false
    end

    settings.position = settings.position or {}
    local position = settings.position
    position.point, position.relativePoint = "CENTER", "CENTER"
    position.x, position.y = x, y
    position.hasBeenActivated = true

    bar:ClearAllPoints()
    bar:SetPoint("CENTER", UIParent, "CENTER", x, y)
    return true
end

local function PlaceCenter(barID, x, y)
    local bar = GetBar(barID)
    if not bar then return false, "missing" end
    if InCombatLockdown() then return false, "combat" end

    local parentX, parentY = UIParent:GetCenter()
    local scale = Scale(bar)
    local success = ApplyBarPosition(
        barID, (x - parentX) / scale, (y - parentY) / scale
    )

    if success and ns.RefreshBarMover then
        ns.RefreshBarMover(barID)
    end
    if success and ns.RefreshConfig then
        ns.RefreshConfig()
    end
    return success
end

function ns.GetPositionReferenceBars(barID)
    local result = {}

    for otherID, settings in pairs(ns.db and ns.db.bars or {}) do
        local bar = GetBar(otherID)
        if type(otherID) == "number"
            and otherID ~= barID
            and settings.enabled
            and bar
            and bar:IsShown()
            and Rect(bar) then
            result[#result + 1] = otherID
        end
    end

    table.sort(result)
    return result
end

function ns.SetBarPlacementReference(barID)
    placementReference = barID
end

function ns.GetBarSnapEnabled(barID)
    local settings = GetSettings(barID)
    if not settings then return false end
    settings.position = settings.position or {}
    return settings.position.snapEnabled ~= false
end

function ns.SetBarSnapEnabled(barID, enabled)
    if InCombatLockdown() then return false, "combat" end

    local settings = GetSettings(barID)
    if not settings then return false, "missing" end

    settings.position = settings.position or {}
    settings.position.snapEnabled = enabled and true or false
    return true
end

function ns.GetBarSnapDistance(barID)
    local settings = GetSettings(barID)
    local value = settings
        and settings.position
        and tonumber(settings.position.snapDistance)

    return math.max(1, math.min(40, value or SNAP_DISTANCE))
end

function ns.SetBarSnapDistance(barID, value)
    if InCombatLockdown() then return false, "combat" end

    local settings = GetSettings(barID)
    value = tonumber(value)
    if not settings or not value then return false, "invalid" end

    settings.position = settings.position or {}
    settings.position.snapDistance =
        math.max(1, math.min(40, math.floor(value + 0.5)))
    return true
end

function ns.AlignBar(barID, referenceID, mode)
    if InCombatLockdown() then return false, "combat" end

    local bar = GetBar(barID)
    local current = bar and Rect(bar)
    if not current then return false, "missing" end

    local x, y = current.x, current.y
    local centerX, centerY = UIParent:GetCenter()

    if mode == "screenX" then
        x = centerX
    elseif mode == "screenY" then
        y = centerY
    else
        local reference = GetBar(referenceID)
        local other = reference and Rect(reference)
        local settings = GetSettings(referenceID)

        if referenceID == barID
            or not other
            or not settings
            or not settings.enabled
            or not reference:IsShown() then
            return false, "reference"
        end

        if mode == "above" then
            x = other.left + current.width / 2
            y = other.top + BAR_GAP + current.height / 2
        elseif mode == "below" then
            x = other.left + current.width / 2
            y = other.bottom - BAR_GAP - current.height / 2
        elseif mode == "left" then
            x = other.left - BAR_GAP - current.width / 2
            y = other.top - current.height / 2
        elseif mode == "right" then
            x = other.right + BAR_GAP + current.width / 2
            y = other.top - current.height / 2
        elseif mode == "alignLeft" then
            x = other.left + current.width / 2
        elseif mode == "alignRight" then
            x = other.right - current.width / 2
        elseif mode == "alignTop" then
            y = other.top - current.height / 2
        elseif mode == "alignBottom" then
            y = other.bottom + current.height / 2
        else
            return false, "invalid"
        end
    end

    return PlaceCenter(barID, x, y)
end

local function SnapPosition(barID, x, y)
    local SNAP_DISTANCE = ns.GetBarSnapDistance(barID)
    local bar = GetBar(barID)

    if not ns.GetBarSnapEnabled(barID) or IsShiftKeyDown() then
        return x, y, false
    end

    local scale = Scale(bar)
    local parentX, parentY = UIParent:GetCenter()
    local cx, cy = parentX + x * scale, parentY + y * scale
    local halfWidth = bar:GetWidth() * scale / 2
    local halfHeight = bar:GetHeight() * scale / 2
    local bestX, bestY = cx, cy
    local distanceX, distanceY = SNAP_DISTANCE + 0.001, SNAP_DISTANCE + 0.001

    local function ConsiderX(value)
        local distance = math.abs(value - cx)
        if distance <= SNAP_DISTANCE and distance < distanceX then
            bestX, distanceX = value, distance
        end
    end

    local function ConsiderY(value)
        local distance = math.abs(value - cy)
        if distance <= SNAP_DISTANCE and distance < distanceY then
            bestY, distanceY = value, distance
        end
    end

    ConsiderX(parentX)
    ConsiderY(parentY)
    ConsiderX(halfWidth)
    ConsiderX(UIParent:GetWidth() - halfWidth)
    ConsiderY(halfHeight)
    ConsiderY(UIParent:GetHeight() - halfHeight)

    for _, otherID in ipairs(ns.GetPositionReferenceBars(barID)) do
        local other = Rect(GetBar(otherID))

        if cy + halfHeight >= other.bottom - SNAP_DISTANCE
            and cy - halfHeight <= other.top + SNAP_DISTANCE then
            ConsiderX(other.left + halfWidth)
            ConsiderX(other.right - halfWidth)
            ConsiderX(other.x)
            ConsiderX(other.left - BAR_GAP - halfWidth)
            ConsiderX(other.right + BAR_GAP + halfWidth)
        end

        if cx + halfWidth >= other.left - SNAP_DISTANCE
            and cx - halfWidth <= other.right + SNAP_DISTANCE then
            ConsiderY(other.bottom + halfHeight)
            ConsiderY(other.top - halfHeight)
            ConsiderY(other.y)
            ConsiderY(other.bottom - BAR_GAP - halfHeight)
            ConsiderY(other.top + BAR_GAP + halfHeight)
        end
    end

    return (bestX - parentX) / scale,
        (bestY - parentY) / scale,
        distanceX <= SNAP_DISTANCE or distanceY <= SNAP_DISTANCE
end

local function AutoPlace(barID, referenceID)
    local bar = GetBar(barID)
    local current = bar and Rect(bar)
    if not current then return end

    local references = ns.GetPositionReferenceBars(barID)
    for index, id in ipairs(references) do
        if id == referenceID then
            table.remove(references, index)
            table.insert(references, 1, id)
            break
        end
    end

    local width, height = current.width, current.height

    local function Free(x, y)
        local left, right = x - width / 2, x + width / 2
        local bottom, top = y - height / 2, y + height / 2

        if left < 0 or right > UIParent:GetWidth()
            or bottom < 0 or top > UIParent:GetHeight() then
            return false
        end

        for _, id in ipairs(references) do
            local other = Rect(GetBar(id))
            if left < other.right + BAR_GAP - 0.01
                and right > other.left - BAR_GAP + 0.01
                and bottom < other.top + BAR_GAP - 0.01
                and top > other.bottom - BAR_GAP + 0.01 then
                return false
            end
        end
        return true
    end

    for _, id in ipairs(references) do
        local other = Rect(GetBar(id))
        local candidates = {
            {
                other.left + width / 2,
                other.bottom - BAR_GAP - height / 2,
            },
            {
                other.left + width / 2,
                other.top + BAR_GAP + height / 2,
            },
            {
                other.right + BAR_GAP + width / 2,
                other.top - height / 2,
            },
            {
                other.left - BAR_GAP - width / 2,
                other.top - height / 2,
            },
        }

        for _, position in ipairs(candidates) do
            if Free(position[1], position[2]) then
                PlaceCenter(barID, position[1], position[2])
                return
            end
        end
    end

    for y = UIParent:GetHeight() - height / 2,
        height / 2, -(height + BAR_GAP) do
        for x = width / 2,
            UIParent:GetWidth() - width / 2, width + BAR_GAP do
            if Free(x, y) then
                PlaceCenter(barID, x, y)
                return
            end
        end
    end

    print(
        "|cff7fd5ffMythInc Action Bars:|r "
        .. "No free position found for the new bar. "
        .. "Unlock it to place it manually."
    )
end

local function Cursor()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    if not scale or scale <= 0 then scale = 1 end
    return x / scale, y / scale
end

local function CreateMover(barID)
    if ns.Movers[barID] then return ns.Movers[barID] end

    local bar = GetBar(barID)
    if not bar then return end

    local mover = CreateFrame(
        "Frame", "MythIncActionBarsMover" .. barID, bar, "BackdropTemplate"
    )
    mover:SetAllPoints(bar)
    mover:SetFrameLevel(bar:GetFrameLevel() + 50)
    mover:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    local function Colors(hover)
        mover:SetBackdropColor(
            0.05,
            hover and 0.55 or 0.45,
            hover and 0.72 or 0.60,
            hover and 0.35 or 0.25
        )
        mover:SetBackdropBorderColor(
            hover and 0.25 or 0.15,
            hover and 0.90 or 0.75,
            hover and 1 or 0.90,
            1
        )
    end

    Colors(false)
    mover:SetScript("OnEnter", function() Colors(true) end)
    mover:SetScript("OnLeave", function() Colors(false) end)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")

    mover.Label = mover:CreateFontString(
        nil, "OVERLAY", "GameFontNormalSmall"
    )
    mover.Label:SetPoint("CENTER")
    mover.Label:SetTextColor(1, 1, 1, 1)

    local dragging, snapped = false, false
    local startCursorX, startCursorY
    local startX, startY, currentX, currentY

    mover:SetScript("OnDragStart", function()
        if InCombatLockdown() or not ns.IsBarUnlocked(barID) then return end

        local settings = GetSettings(barID)
        if not settings or not settings.position then return end

        startCursorX, startCursorY = Cursor()
        startX = tonumber(settings.position.x) or 0
        startY = tonumber(settings.position.y) or 0
        currentX, currentY = startX, startY
        dragging = true
    end)

    mover:SetScript("OnUpdate", function()
        if not dragging then return end
        if InCombatLockdown() then
            dragging = false
            return
        end

        local x, y = Cursor()
        local scale = Scale(bar)
        currentX, currentY, snapped = SnapPosition(
            barID,
            startX + (x - startCursorX) / scale,
            startY + (y - startCursorY) / scale
        )
        ApplyBarPosition(barID, currentX, currentY)
    end)

    mover:SetScript("OnDragStop", function()
        if not dragging then return end
        dragging = false
        if InCombatLockdown() then return end

        if not snapped then
            currentX = math.floor(currentX + 0.5)
            currentY = math.floor(currentY + 0.5)
        end

        ApplyBarPosition(barID, currentX, currentY)
        if ns.RefreshConfig then ns.RefreshConfig() end
    end)

    mover:SetScript("OnHide", function() dragging = false end)
    mover:Hide()
    ns.Movers[barID] = mover
    return mover
end

function ns.RefreshBarMover(barID)
    local bar, settings = GetBar(barID), GetSettings(barID)
    if not bar or not settings then
        if ns.Movers[barID] then ns.Movers[barID]:Hide() end
        return
    end

    local mover = CreateMover(barID)
    mover:ClearAllPoints()
    mover:SetAllPoints(bar)
    mover:SetFrameLevel(bar:GetFrameLevel() + 50)
    mover.Label:SetText(settings.name or ("Bar " .. barID))
    mover:SetShown(
        unlockedBars[barID] and settings.enabled and bar:IsShown()
        and true or false
    )
end

function ns.IsBarUnlocked(barID)
    return unlockedBars[barID] == true
end

function ns.SetBarUnlocked(barID, unlocked)
    local settings = GetSettings(barID)
    if not settings then return false, "missing" end
    if InCombatLockdown() then return false, "combat" end
    if unlocked and not settings.enabled then return false, "disabled" end

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

    local found = false
    for id, settings in pairs(ns.db.bars) do
        if type(id) == "number"
            and type(settings) == "table"
            and settings.enabled then
            found = true
            if not ns.IsBarUnlocked(id) then return false end
        end
    end
    return found
end

function ns.SetAllBarsUnlocked(unlocked)
    if InCombatLockdown() then return false, "combat" end
    moveModeActive = unlocked and true or false

    for id, settings in pairs(ns.db.bars) do
        if type(id) == "number" and type(settings) == "table" then
            unlockedBars[id] = unlocked and settings.enabled and true or nil
            ns.RefreshBarMover(id)
        end
    end

    if ns.RefreshConfig then ns.RefreshConfig() end
    return true
end

function ns.ToggleAllBarsUnlocked()
    return ns.SetAllBarsUnlocked(
        not (moveModeActive or ns.AreAllEnabledBarsUnlocked())
    )
end

function ns.LockAllBars()
    return ns.SetAllBarsUnlocked(false)
end

local function InheritUnlock(barID)
    local settings = GetSettings(barID)
    if not InCombatLockdown() and moveModeActive
        and settings and settings.enabled then
        ns.SetBarUnlocked(barID, true)
    end
end

local function HasSavedBarPosition(barID, settings)
    local position = settings and settings.position
    if not position then return false end
    if position.hasBeenActivated then return true end

    -- Preserve changed positions saved before activation tracking existed.
    if not ns.CreateDefaultBarSettings then return true end

    local defaults = ns.CreateDefaultBarSettings(
        barID, false, settings.source
    )
    local original = defaults.position

    return position.point ~= original.point
        or position.relativePoint ~= original.relativePoint
        or (tonumber(position.x) or 0) ~= (tonumber(original.x) or 0)
        or (tonumber(position.y) or 0) ~= (tonumber(original.y) or 0)
end

local setBarEnabled = ns.SetBarEnabled
ns.SetBarEnabled = function(barID, enabled)
    local settings = GetSettings(barID)
    local wasEnabled = settings and settings.enabled
    local previouslyPlaced = wasEnabled or HasSavedBarPosition(barID, settings)

    local result, reason = setBarEnabled(barID, enabled)

    if settings and wasEnabled then
        settings.position = settings.position or {}
        settings.position.hasBeenActivated = true
    end

    if enabled and not wasEnabled and settings and settings.enabled then
        if not previouslyPlaced then
            AutoPlace(barID, placementReference)
        end

        settings.position = settings.position or {}
        settings.position.hasBeenActivated = true
        InheritUnlock(barID)
    end

    return result, reason
end

local addBar = ns.AddBar
ns.AddBar = function(...)
    local reference = placementReference
    local barID, reason = addBar(...)

    if type(barID) == "number" then
        AutoPlace(barID, reference)

        local settings = GetSettings(barID)
        if settings then
            settings.position = settings.position or {}
            settings.position.hasBeenActivated = true
        end

        InheritUnlock(barID)
    end

    return barID, reason
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function()
    if moveModeActive or ns.GetUnlockedBarCount() > 0 then
        ns.SetAllBarsUnlocked(false)
    end
end)

-- Visual guide only; does not capture mouse input or move bars.
local alignmentGrid = CreateFrame("Frame", nil, UIParent)
alignmentGrid:SetAllPoints(UIParent)
alignmentGrid:SetFrameStrata("BACKGROUND")
alignmentGrid:EnableMouse(false)
alignmentGrid:Hide()

local gridLines = {}
local gridWidth, gridHeight, gridScale, gridSpacing = 0, 0, 0, 0

function ns.IsAlignmentGridEnabled()
    return ns.db and ns.db.showAlignmentGrid == true
end

function ns.SetAlignmentGridEnabled(enabled)
    if ns.db then
        ns.db.showAlignmentGrid = enabled and true or false
    end
end

function ns.GetAlignmentGridSpacing()
    local value = ns.db and tonumber(ns.db.alignmentGridSpacing)
    return math.max(8, math.min(128, math.floor((value or 32) + 0.5)))
end

function ns.SetAlignmentGridSpacing(value)
    value = tonumber(value)
    if not value or not ns.db then return false end

    ns.db.alignmentGridSpacing =
        math.max(8, math.min(128, math.floor(value + 0.5)))
    return true
end

local function BuildAlignmentGrid()
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    local scale = UIParent:GetEffectiveScale()
    if not scale or scale <= 0 then return end

    local spacing = ns.GetAlignmentGridSpacing()
    if width == gridWidth and height == gridHeight
        and scale == gridScale and spacing == gridSpacing then
        return
    end

    gridWidth, gridHeight, gridScale, gridSpacing =
        width, height, scale, spacing

    for _, line in ipairs(gridLines) do line:Hide() end

    local used = 0
    local pixelWidth = math.floor(width * scale + 0.5)
    local pixelHeight = math.floor(height * scale + 0.5)
    local centerX = math.floor(pixelWidth / 2)
    local centerY = math.floor(pixelHeight / 2)

    local function Line(vertical, pixel)
        used = used + 1
        local texture = gridLines[used]

        if not texture then
            texture = alignmentGrid:CreateTexture(nil, "BACKGROUND")
            gridLines[used] = texture
        end

        texture:ClearAllPoints()

        if vertical then
            texture:SetPoint(
                "BOTTOMLEFT", alignmentGrid, "BOTTOMLEFT", pixel / scale, 0
            )
            texture:SetSize(1 / scale, height)
        else
            texture:SetPoint(
                "BOTTOMLEFT", alignmentGrid, "BOTTOMLEFT", 0, pixel / scale
            )
            texture:SetSize(width, 1 / scale)
        end

        texture:SetColorTexture(0.65, 0.85, 0.90, 0.55)
        texture:Show()
    end

    for pixel = centerX % spacing, pixelWidth - 1, spacing do
        Line(true, pixel)
    end

    for pixel = centerY % spacing, pixelHeight - 1, spacing do
        Line(false, pixel)
    end
end

local gridWatcher = CreateFrame("Frame")
local gridElapsed = 0

local function UpdateAlignmentGrid()
    for _, settings in pairs(ns.db and ns.db.bars or {}) do
        if type(settings) == "table" and settings.enabled then
            settings.position = settings.position or {}
            settings.position.hasBeenActivated = true
        end
    end

    local unlocked = ns.GetUnlockedBarCount() > 0

    for _, target in pairs(ns.SpecialConfigTargets or {}) do
        if target.GetSettings().enabled and target.IsUnlocked() then
            unlocked = true
        end
    end

    local visible = ns.IsAlignmentGridEnabled()
        and unlocked and not InCombatLockdown()

    if visible then BuildAlignmentGrid() end
    alignmentGrid:SetShown(visible and true or false)
end

gridWatcher:SetScript("OnUpdate", function(_, elapsed)
    gridElapsed = gridElapsed + elapsed
    if gridElapsed < 0.1 then return end
    gridElapsed = 0
    UpdateAlignmentGrid()
end)

gridWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
gridWatcher:SetScript("OnEvent", function()
    alignmentGrid:Hide()
end)