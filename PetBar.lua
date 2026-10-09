local addonName, ns = ...

local defaults = {
    enabled = true, columns = 10, buttonSize = 36, spacing = 4, scale = 1,
    x = 0, y = -150, hideMounted = false, hideVehicle = true,
    combatOnly = false, keybinds = {},
}
ns.defaults.petBar = defaults

local bar, mover, dialog, nativeBar
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
        if dialog and dialog:IsShown() then dialog:Refresh() end
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
    if dialog and dialog:IsShown() then dialog:Refresh() end
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

local function CreateDialog()
    local parent = _G.MythIncActionBarsConfig
    if not parent then return end
    local widgets = ns.ConfigWidgets

    dialog = CreateFrame(
        "Frame", "MythIncActionBarsPetSettings",
        parent, "BackdropTemplate"
    )
    dialog:SetAllPoints(parent)
    dialog:SetFrameLevel(parent:GetFrameLevel() + 100)
    dialog:EnableMouse(true)
    widgets.SetBackdrop(dialog, ns.Media.colors.background)

    widgets.CreateText(
        dialog, "MYTH INC  |  PET ACTION BAR", 18, 24, -20
    )
    widgets.CreateText(
        dialog, "Changes use the main menu's Apply / Revert controls.",
        11, 24, -48, true
    )
    widgets.CreateButton(
        dialog, "Back", 100, 30, 944, -18,
        function() dialog:Hide() end
    )

    local controls = {}
    local function SetValue(key, value)
        if InCombatLockdown() then
            Message("Pet bar settings cannot change during combat.")
            dialog:Refresh()
            return
        end
        Settings()[key] = value
        ns.RefreshPetBar()
    end

    local function Check(label, key, x, y)
        controls[#controls + 1] = widgets.CreateCheckButton(
            dialog, label, x, y,
            function() return Settings()[key] end,
            function(value) SetValue(key, value) end
        )
    end

    Check("Enable Myth Inc pet bar", "enabled", 24, -82)
    Check("Hide while mounted", "hideMounted", 24, -124)
    Check("Hide in vehicles / override states", "hideVehicle", 24, -166)
    Check("Show only in combat", "combatOnly", 24, -208)

    widgets.CreateButton(
        dialog, "Unlock / Lock", 160, 32, 264, -80,
        function() SetUnlocked(not unlocked) end
    )
    widgets.CreateButton(
        dialog, "Reset Position", 160, 32, 264, -122,
        function()
            if InCombatLockdown() then
                Message("Cannot reset position during combat.")
                return
            end
            local settings = Settings()
            settings.x, settings.y = defaults.x, defaults.y
            ns.RefreshPetBar()
        end
    )

    local function Slider(label, key, low, high, step, x, y)
        controls[#controls + 1] = widgets.CreateSlider(
            dialog, label, low, high, step, x, y,
            function() return Settings()[key] end,
            function(value)
                local settings = Settings()
                if key == "scale" and not InCombatLockdown() then
                    local ratio = settings.scale / value
                    settings.x = settings.x * ratio
                    settings.y = settings.y * ratio
                end
                SetValue(key, value)
            end,
            key == "scale" and function(value)
                return string.format("%.2f", value)
            end or nil,
            190
        )
    end

    Slider("Buttons Per Row", "columns", 1, 10, 1, 24, -270)
    Slider("Button Size", "buttonSize", 24, 64, 1, 264, -270)
    Slider("Spacing", "spacing", 0, 20, 1, 24, -364)
    Slider("Scale", "scale", 0.5, 2, 0.05, 264, -364)
    Slider("X Position", "x", -1000, 1000, 1, 24, -458)
    Slider("Y Position", "y", -1000, 1000, 1, 264, -458)

    widgets.CreateText(
        dialog,
        "Pet abilities: left-click to use; right-click to toggle autocast.\n"
            .. "Drag uses Blizzard's action-lock / pickup-modifier rules.",
        11, 24, -572, true
    )
    widgets.CreateText(dialog, "PET KEYBINDS", 14, 550, -86)
    widgets.CreateText(
        dialog,
        "Click a binding, then press a key. Escape cancels.\n"
            .. "Delete / Backspace clears your custom binding.\n"
            .. "Existing Blizzard pet bindings continue to work.",
        11, 550, -116, true
    )

    local bindButtons = {}
    local capturing
    local function StopCapture()
        capturing = nil
        dialog:EnableKeyboard(false)
        dialog:SetPropagateKeyboardInput(true)
    end

    for index = 1, 10 do
        local y = -192 - (index - 1) * 38
        widgets.CreateText(dialog, "Slot " .. index, 11, 550, y - 8)
        bindButtons[index] = widgets.CreateButton(
            dialog, "", 360, 30, 636, y,
            function()
                if InCombatLockdown() then
                    Message("Pet bindings cannot change during combat.")
                    return
                end
                capturing = index
                dialog:EnableKeyboard(true)
                dialog:SetPropagateKeyboardInput(false)
                bindButtons[index].label:SetText(
                    "Press a key... (Escape cancels)"
                )
            end
        )
    end

    dialog:SetScript("OnKeyDown", function(_, key)
        if not capturing then return end
        local index = capturing

        if key == "ESCAPE" then
            StopCapture()
            dialog:Refresh()
            return
        end

        local binding = ns.BuildCapturedKey(key)
        if key == "BACKSPACE" or key == "DELETE" then
            binding = nil
        elseif not binding then
            return
        end

        if InCombatLockdown() then
            StopCapture()
            dialog:Refresh()
            return
        end

        ns.SetNativeBarBinding("petBar", index, binding)
        StopCapture()
        dialog:Refresh()
    end)

    dialog.Refresh = function()
        for _, control in ipairs(controls) do control:Refresh() end
        for index, button in ipairs(bindButtons) do
            local custom = Settings().keybinds[index]
            local key = custom or GetBindingKey("BONUSACTIONBUTTON" .. index)
            local name, _, isToken = GetPetActionInfo(index)
            if isToken then name = _G[name] end

            button.label:SetText(
                (name or "Pet action " .. index) .. "  |  "
                    .. (key and ns.FormatKeybind(key) or "Unbound")
                    .. (custom and "" or " (Blizzard)")
            )
        end
    end

    dialog:SetScript("OnHide", function()
        parent:StopMovingOrSizing()
        StopCapture()
        if mover then mover.StopDrag() end
    end)
    dialog:Hide()
end

function ns.OpenPetBarSettings()
    if _G.MythIncActionBarsStanceSettings then
        _G.MythIncActionBarsStanceSettings:Hide()
    end
    if not _G.MythIncActionBarsConfig
        or not _G.MythIncActionBarsConfig:IsShown() then
        ns.ToggleConfig()
    end
    if not dialog then CreateDialog() end
    if dialog then dialog:Refresh(); dialog:Show() end
end

local createLayout = ns.CreateLayoutConfigPage
ns.CreateLayoutConfigPage = function(parent, context)
    local page = createLayout(parent, context)
    ns.ConfigWidgets.CreateButton(
        page, "Pet Bar Settings", 160, 30, 850, -4,
        ns.OpenPetBarSettings
    )
    return page
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
        if dialog and dialog:IsShown() then dialog:Hide() end
        return
    end
    if event == "PET_BAR_UPDATE" or event == "UPDATE_BINDINGS" then
        ApplyBindings()
        if dialog and dialog:IsShown() then dialog:Refresh() end
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