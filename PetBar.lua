local addonName, ns = ...

local defaults = {
    enabled = true, columns = 10, buttonSize = 36, spacing = 4, scale = 1,
    x = 0, y = -150, hideMounted = false, hideVehicle = true,
    combatOnly = false, keybinds = {},
}
ns.defaults.petBar = defaults

local bar, mover, nativeBar
local owned = false
local pending = false
local unlocked = false
local originalParent
local originalButtons = {}
local appliedKeys = {}
local bindingOwner = CreateFrame("Frame")
local hiddenParent = CreateFrame("Frame", nil, UIParent)
hiddenParent:Hide()

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = Copy(child) end
    return result
end

local function Settings()
    if not ns.db then return nil end
    if type(ns.db.petBar) ~= "table" then ns.db.petBar = Copy(defaults) end
    local settings = ns.db.petBar
    for key, value in pairs(defaults) do
        if settings[key] == nil then settings[key] = Copy(value) end
    end
    if type(settings.keybinds) ~= "table" then settings.keybinds = {} end
    return settings
end

local function Message(text)
    print("|cff7fd5ffMythInc Action Bars:|r " .. text)
end

local function UsedByActionBar(key)
    if ns.IsStanceKeybindInUse and ns.IsStanceKeybindInUse(key) then
        return true
    end
    for _, settings in pairs(ns.db.bars or {}) do
        if settings.enabled then
            for _, entry in pairs(settings.keybinds or {}) do
                if entry.primary == key or entry.secondary == key then
                    return true
                end
            end
        end
    end
    return false
end

local function UpdateHotkeys()
    if not owned then return end
    for index, button in ipairs(nativeBar.actionButtons) do
        local key = appliedKeys[index]
            or GetBindingKey("BONUSACTIONBUTTON" .. index)
        button.HotKey:SetText(key and ns.FormatKeybind(key) or "")
        button.HotKey:SetShown(key ~= nil)
    end
end

local function ApplyBindings()
    if InCombatLockdown() then pending = true; return end
    ClearOverrideBindings(bindingOwner)
    wipe(appliedKeys)
    local settings = Settings()
    if settings and settings.enabled and owned then
        for index = 1, 10 do
            local key = settings.keybinds[index]
            if type(key) == "string" and key ~= ""
                and not UsedByActionBar(key) then
                SetOverrideBinding(
                    bindingOwner, false, key,
                    "BONUSACTIONBUTTON" .. index
                )
                appliedKeys[index] = key
            end
        end
    end
    UpdateHotkeys()
end

local function VisibilityDriver(settings)
    local conditions = {}
    if unlocked then conditions[#conditions + 1] = "[nocombat] show" end
    conditions[#conditions + 1] = "[petbattle] hide"
    if settings.hideVehicle then
        conditions[#conditions + 1] = "[vehicleui] hide"
        conditions[#conditions + 1] = "[overridebar] hide"
        conditions[#conditions + 1] = "[possessbar] hide"
    end
    if settings.hideMounted then
        conditions[#conditions + 1] = "[mounted] hide"
    end
    conditions[#conditions + 1] = settings.combatOnly
        and "[pet,combat] show" or "[pet] show"
    conditions[#conditions + 1] = "hide"
    return table.concat(conditions, "; ")
end

local function Layout()
    if InCombatLockdown() then pending = true; return end
    if not owned then return end

    local settings = Settings()
    local columns = math.max(
        1, math.min(10, math.floor(tonumber(settings.columns) or 10))
    )
    local size = math.max(
        24, math.min(64, tonumber(settings.buttonSize) or 36)
    )
    local spacing = math.max(
        0, math.min(20, tonumber(settings.spacing) or 4)
    )
    local scale = math.max(
        0.5, math.min(2, tonumber(settings.scale) or 1)
    )
    local rows = math.ceil(10 / columns)

    bar:SetSize(
        columns * size + (columns - 1) * spacing,
        rows * size + (rows - 1) * spacing
    )
    bar:SetScale(scale)
    bar:ClearAllPoints()
    bar:SetPoint(
        "CENTER", UIParent, "CENTER",
        tonumber(settings.x) or 0,
        tonumber(settings.y) or -150
    )

    for index, button in ipairs(nativeBar.actionButtons) do
        button:ClearAllPoints()
        local saved = originalButtons[index]
        local buttonScale = size / saved.artSize
        button:SetSize(saved.width, saved.height)
        button:SetScale(buttonScale)
        button:SetPoint(
            "CENTER", bar, "TOPLEFT",
            (((index - 1) % columns) * (size + spacing)
                + size / 2) / buttonScale,
            -(math.floor((index - 1) / columns) * (size + spacing)
                + size / 2) / buttonScale
        )
    end

    local moverLevel = bar:GetFrameLevel() + 50
    for _, button in ipairs(nativeBar.actionButtons) do
        moverLevel = math.max(moverLevel, button:GetFrameLevel() + 50)
    end
    mover:SetFrameLevel(moverLevel)
    RegisterStateDriver(bar, "visibility", VisibilityDriver(settings))
    mover:SetShown(unlocked)
end

local function Restore()
    if not owned then return end
    unlocked = false
    UnregisterStateDriver(bar, "visibility")
    mover:Hide()
    bar:Hide()
    owned = false

    for index, button in ipairs(nativeBar.actionButtons) do
        local saved = originalButtons[index]
        button:SetParent(saved.parent)
        button:ClearAllPoints()
        button:SetSize(saved.width, saved.height)
        button:SetScale(saved.scale)
        for _, point in ipairs(saved.points) do
            button:SetPoint(unpack(point))
        end
        button:SetHotkeys()
    end

    nativeBar:SetParent(originalParent)
    if nativeBar.Update then nativeBar:Update() end
    if nativeBar.UpdateShownButtons then nativeBar:UpdateShownButtons() end
end

local function CreateMover()
    mover = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    mover:SetAllPoints(bar)
    mover:SetFrameLevel(bar:GetFrameLevel() + 50)
    mover:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    local function Colors(hover)
        if hover then
            mover:SetBackdropColor(0.05, 0.55, 0.72, 0.35)
            mover:SetBackdropBorderColor(0.25, 0.90, 1, 1)
        else
            mover:SetBackdropColor(0.05, 0.45, 0.60, 0.25)
            mover:SetBackdropBorderColor(0.15, 0.75, 0.90, 1)
        end
    end
    Colors(false)
    mover:SetScript("OnEnter", function() Colors(true) end)
    mover:SetScript("OnLeave", function() Colors(false) end)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")

    local label = mover:CreateFontString(
        nil, "OVERLAY", "GameFontNormalSmall"
    )
    label:SetPoint("CENTER")
    label:SetTextColor(1, 1, 1, 1)
    label:SetText("Pet Bar")
    mover.Label = label
    bar:SetClampedToScreen(true)

    local dragging = false
    local startCursorX, startCursorY, startX, startY
    local function Cursor()
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        return x / scale, y / scale
    end

    mover.StopDrag = function() dragging = false end

    mover:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        local settings = Settings()
        startCursorX, startCursorY = Cursor()
        startX, startY = settings.x, settings.y
        dragging = true
    end)

    mover:SetScript("OnUpdate", function()
        if not dragging then return end
        if InCombatLockdown() then dragging = false; return end

        local x, y = Cursor()
        local settings = Settings()
        local scale = bar:GetScale()
        settings.x = startX + (x - startCursorX) / scale
        settings.y = startY + (y - startCursorY) / scale

        bar:ClearAllPoints()
        bar:SetPoint(
            "CENTER", UIParent, "CENTER", settings.x, settings.y
        )
    end)

    mover:SetScript("OnDragStop", function()
        if not dragging then return end
        dragging = false
        if InCombatLockdown() then pending = true; return end

        local settings = Settings()
        settings.x = math.floor(settings.x + 0.5)
        settings.y = math.floor(settings.y + 0.5)
        Layout()
        if ns.RefreshConfig then ns.RefreshConfig() end
    end)

    mover:Hide()
end

local function TakeOwnership()
    nativeBar = _G.PetActionBar
    if not nativeBar or not nativeBar.actionButtons
        or #nativeBar.actionButtons ~= 10 then
        Message(
            "The Blizzard pet buttons are unavailable; "
                .. "leaving the original pet bar unchanged."
        )
        return false
    end

    if not bar then
        bar = CreateFrame(
            "Frame", "MythIncActionBarsPetBar",
            UIParent, "SecureHandlerStateTemplate"
        )
        bar:SetFrameStrata("MEDIUM")
        CreateMover()
    end

    if not owned then
        originalParent = nativeBar:GetParent()
        for index, button in ipairs(nativeBar.actionButtons) do
            local saved = {
                parent = button:GetParent(),
                width = button:GetWidth(),
                height = button:GetHeight(),
                scale = button:GetScale(),
                points = {},
            }
            saved.artSize = math.max(saved.width, saved.height, 35)
            for _, region in ipairs({
                button.icon, button.NormalTexture,
                button.PushedTexture, button.Border, button.Flash,
            }) do
                saved.artSize = math.max(
                    saved.artSize, region:GetWidth(), region:GetHeight()
                )
            end
            for point = 1, button:GetNumPoints() do
                saved.points[point] = { button:GetPoint(point) }
            end
            originalButtons[index] = saved
            button:SetParent(bar)

            if not button.mythIncPetHotkeyHook then
                hooksecurefunc(button, "SetHotkeys", UpdateHotkeys)
                button.mythIncPetHotkeyHook = true
            end
        end
        owned = true
    end

    nativeBar:SetParent(hiddenParent)
    return true
end

function ns.RefreshPetBar()
    if InCombatLockdown() then pending = true; return false end

    local settings = Settings()
    if not settings then return false end
    pending = false

    if settings.enabled then
        if TakeOwnership() then Layout() end
    else
        Restore()
    end

    ApplyBindings()
    return true
end

local function SetUnlocked(value)
    if InCombatLockdown() then
        if value then
            Message("Pet bar positioning cannot change during combat.")
        else
            unlocked = false
            if mover then mover.StopDrag(); mover:Hide() end
            pending = true
        end
        return
    end

    if not owned then return end
    unlocked = value and true or false
    if not unlocked then mover.StopDrag() end
    Layout()
end

local refreshProfile = ns.RefreshAllBarsFromProfile
ns.RefreshAllBarsFromProfile = function(...)
    local success, reason = refreshProfile(...)
    if success then SetUnlocked(false); ns.RefreshPetBar() end
    return success, reason
end

local applyKeybinds = ns.ApplyAllKeybinds
ns.ApplyAllKeybinds = function(...)
    local success, reason = applyKeybinds(...)
    ApplyBindings()
    return success, reason
end

local setAllUnlocked = ns.SetAllBarsUnlocked
ns.SetAllBarsUnlocked = function(value)
    local success, reason = setAllUnlocked(value)
    if success then SetUnlocked(value) end
    return success, reason
end

SLASH_MYTHINCPETBAR1 = "/miabpet"
SlashCmdList.MYTHINCPETBAR = ns.OpenPetBarSettings

local events = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED", "EDIT_MODE_LAYOUTS_UPDATED",
    "UPDATE_BINDINGS", "PET_BAR_UPDATE",
}) do
    events:RegisterEvent(event)
end

events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        SetUnlocked(false)
        return
    end
    if event == "PET_BAR_UPDATE" or event == "UPDATE_BINDINGS" then
        ApplyBindings()
        return
    end
    if event == "PLAYER_REGEN_ENABLED" and not pending then return end
    ns.RefreshPetBar()
end)

local rangeElapsed = 0
events:SetScript("OnUpdate", function(_, elapsed)
    if not owned or not bar:IsShown() then return end
    rangeElapsed = rangeElapsed + elapsed
    if rangeElapsed < 0.2 then return end
    rangeElapsed = 0

    for index, button in ipairs(nativeBar.actionButtons) do
        local _, _, _, _, _, _, _, checksRange, inRange =
            GetPetActionInfo(index)
        ActionButton_UpdateRangeIndicator(button, checksRange, inRange)
    end
end)

ns.SpecialConfigTargets.petBar = {
    name = "Pet Bar",
    GetSettings = Settings,
    defaults = defaults,
    Refresh = ns.RefreshPetBar,
    IsUnlocked = function() return unlocked end,
    SetUnlocked = SetUnlocked,
    Count = function() return 10 end,
    visibility = true,
    grid = true,
    scaledPosition = true,
    Bind = function(index, key)
        return ns.SetNativeBarBinding("petBar", index, key)
    end,
    Inherited = function(index)
        return GetBindingKey("BONUSACTIONBUTTON" .. index)
    end,
}

function ns.OpenPetBarSettings()
    ns.SelectConfigBar("petBar")
end

SlashCmdList.MYTHINCPETBAR = ns.OpenPetBarSettings