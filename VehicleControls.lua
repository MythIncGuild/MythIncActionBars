local addonName, ns = ...

local defaults = {
    enabled = true, mainBarPaging = true,
    scale = 1, x = 290, y = -300, keybinds = {},
}
ns.defaults.vehicleControls = defaults

local carrier, button, mover
local unlocked, dragging, pending, queued = false, false, false, false
local bindingOwner = CreateFrame("Frame")
local Refresh
local group

local function Settings()
    if not ns.db then return end
    if type(ns.db.vehicleControls) ~= "table" then
        ns.db.vehicleControls = {}
    end
    local settings = ns.db.vehicleControls
    for key, value in pairs(defaults) do
        if settings[key] == nil then
            settings[key] = type(value) == "table" and {} or value
        end
    end
    return settings
end

local function Message(text)
    print("|cff7fd5ffMythInc Action Bars:|r " .. text)
end

local function PageDriver(settings)
    local conditions = {
        "[vehicleui] " .. C_ActionBar.GetVehicleBarIndex(),
        "[overridebar] " .. C_ActionBar.GetOverrideBarIndex(),
        "[possessbar] " .. C_ActionBar.GetVehicleBarIndex(),
        "[shapeshift] " .. C_ActionBar.GetTempShapeshiftBarIndex(),
        "[bonusbar:5] 11",
    }
    for _, modifier in ipairs({ "alt", "ctrl", "shift" }) do
        local entry = settings and settings[modifier]
        if entry and entry.enabled then
            local page = math.max(1, math.min(15, tonumber(entry.page) or 1))
            conditions[#conditions + 1] = "[mod:" .. modifier .. "] " .. page
        end
    end
    for page = 2, 6 do
        conditions[#conditions + 1] = "[bar:" .. page .. "] " .. page
    end
    for offset = 1, 4 do
        conditions[#conditions + 1] = "[bonusbar:" .. offset .. "] " .. (offset + 6)
    end
    conditions[#conditions + 1] = "1"
    return table.concat(conditions, "; ")
end

local function InstallPaging(actionButton)
    if actionButton.mythIncVehiclePagingInstalled
        or not actionButton.ConfigureActionPages then
        return
    end
    actionButton.mythIncVehiclePagingInstalled = true
    local configure = actionButton.ConfigureActionPages
    actionButton.ConfigureActionPages = function(settings)
        local success = configure(settings)
        local vehicleSettings = Settings()
        if success and not InCombatLockdown()
            and vehicleSettings and vehicleSettings.mainBarPaging then
            -- Retain the existing secure handler and modifier attributes.
            UnregisterStateDriver(actionButton, "page")
            actionButton:SetAttribute("state-page", nil)
            RegisterStateDriver(actionButton, "page", PageDriver(settings))
        end
        return success
    end
end

local createActionButton = ns.CreateActionButton
ns.CreateActionButton = function(parent, ...)
    local result = createActionButton(parent, ...)
    if parent.barID == 1 then InstallPaging(result) end
    return result
end

local function StopDrag()
    if not dragging then return end
    mover:StopMovingOrSizing()
    local x, y = mover:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if x and y and parentX and parentY then
        local settings = Settings()
        settings.x = math.floor(x - parentX + 0.5)
        settings.y = math.floor(y - parentY + 0.5)
    end
    dragging = false
end

local function CreateControls()
    carrier = CreateFrame("Frame", "MythIncActionBarsVehicleControl", UIParent)
    carrier:SetSize(32, 32)

    button = CreateFrame(
        "Button", "MythIncActionBarsVehicleExitButton",
        carrier, "SecureActionButtonTemplate"
    )
    button:SetSize(32, 32)
    button:SetFrameLevel(carrier:GetFrameLevel() + 50)
    button:SetPoint("CENTER", carrier, "CENTER")
    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext", "/leavevehicle")
    button:SetAttribute("useOnKeyDown", false)
    button:RegisterForClicks("AnyUp")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexture("Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up")
    icon:SetTexCoord(0.140625, 0.859375, 0.140625, 0.859375)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    button.HotKey = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalGray")
    button.HotKey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Exit Vehicle")
        GameTooltip:AddLine(
            "Leave your current vehicle when exiting is allowed.",
            1, 1, 1, true
        )
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    mover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    mover:SetMovable(true)
    mover:SetFrameStrata("DIALOG")
    mover:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1,
    })
    local function Colors(hover)
        mover:SetBackdropColor(
            0.05, hover and 0.55 or 0.45,
            hover and 0.72 or 0.60, hover and 0.35 or 0.25
        )
        mover:SetBackdropBorderColor(
            hover and 0.25 or 0.15,
            hover and 0.90 or 0.75, hover and 1 or 0.90, 1
        )
    end
    Colors(false)
    mover:SetScript("OnEnter", function() Colors(true) end)
    mover:SetScript("OnLeave", function() Colors(false) end)

    local label = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    label:SetText("Exit")
    label:SetTextColor(1, 1, 1, 1)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")

    mover:SetScript("OnDragStart", function()
        if InCombatLockdown() or not unlocked then return end
        dragging = true
        mover:StartMoving()
    end)
    mover:SetScript("OnUpdate", function()
        if not dragging then return end
        if InCombatLockdown() then
            StopDrag()
            pending = true
            return
        end
        local x, y = mover:GetCenter()
        local parentX, parentY = UIParent:GetCenter()
        if x and y and parentX and parentY then
            local settings = Settings()
            settings.x, settings.y = x - parentX, y - parentY
            carrier:ClearAllPoints()
            carrier:SetPoint("CENTER", UIParent, "CENTER", settings.x, settings.y)
        end
    end)
    mover:SetScript("OnDragStop", function()
        StopDrag()
        Refresh()
        if ns.RefreshConfig then ns.RefreshConfig() end
    end)
    mover:SetScript("OnHide", StopDrag)
    mover:Hide()
end

local function ApplyBinding()
    if InCombatLockdown() then pending = true; return end
    ClearOverrideBindings(bindingOwner)
    local settings = Settings()
    local key = settings.enabled and settings.keybinds[1]
    if type(key) ~= "string" or key == "" then key = nil end
    if key then
        SetOverrideBindingClick(
            bindingOwner, false, key, button:GetName(), "LeftButton"
        )
    end
    button.HotKey:SetText(key and ns.FormatKeybind(key) or "")
    button.HotKey:SetShown(key ~= nil and key ~= false)
end

Refresh = function()
    if InCombatLockdown() then pending = true; return end
    if not ns.db then return end
    pending = false
    if not carrier then CreateControls() end

    local settings = Settings()
    local main = ns.Bars and ns.Bars[1]
    local mainSettings = ns.db.bars and ns.db.bars[1]
    if main and mainSettings then
        for _, actionButton in ipairs(main.buttons or {}) do
            InstallPaging(actionButton)
            actionButton.ConfigureActionPages(mainSettings.actionPages)
        end
    end

    local scale = math.max(0.5, math.min(2, tonumber(settings.scale) or 1))
    settings.scale = scale
    carrier:SetSize(32 * scale, 32 * scale)
    button:SetScale(scale)
    if not dragging then
        carrier:ClearAllPoints()
        carrier:SetPoint("CENTER", UIParent, "CENTER", settings.x, settings.y)
        mover:ClearAllPoints()
        mover:SetPoint("CENTER", UIParent, "CENTER", settings.x, settings.y)
    end
    mover:SetSize(32 * scale, 32 * scale)
    local parent = _G.MythIncActionBarsConfig
    mover:SetFrameLevel(parent and parent:GetFrameLevel() + 250 or 100)

    if not settings.enabled then unlocked = false end
    mover:SetShown(unlocked)

    local driver = "hide"
    if settings.enabled then
        driver = "[petbattle] hide; "
        if unlocked or ns.IsKeybindModeActive() then
            driver = driver .. "[nocombat] show; "
        end
        driver = driver .. "[canexitvehicle] show; hide"
    end
    RegisterStateDriver(button, "visibility", driver)
    ApplyBinding()
end

local function SetUnlocked(value)
    StopDrag()
    unlocked = value and true or false
    if InCombatLockdown() then
        unlocked = false
        if mover then mover:Hide() end
        pending = true
        return
    end
    Refresh()
end

group = {
    key = "vehicleControls", name = "Exit Vehicle",
    carrier = "MythIncActionBarsVehicleControl",
    menu = "MythIncActionBarsVehicleSettings", GetSettings = Settings,
    GetCount = function() return 1 end,
    GetButtons = function() return button and { button } or {} end,
}
ns.RegisterSpecialBarBindingTarget(group)

local applyKeybinds = ns.ApplyAllKeybinds
ns.ApplyAllKeybinds = function(...)
    local success, reason = applyKeybinds(...)
    if button then ApplyBinding() end
    return success, reason
end

local setMode = ns.SetKeybindMode
ns.SetKeybindMode = function(enabled, ...)
    if enabled then unlocked = false; StopDrag() end
    local success, reason = setMode(enabled, ...)
    Refresh()
    if not InCombatLockdown() then ns.RefreshSpecialBarBindingTargets() end
    return success, reason
end

local refreshProfile = ns.RefreshAllBarsFromProfile
ns.RefreshAllBarsFromProfile = function(...)
    StopDrag()
    unlocked = false
    local success, reason = refreshProfile(...)
    if success then Refresh() end
    return success, reason
end

local setAllUnlocked = ns.SetAllBarsUnlocked
ns.SetAllBarsUnlocked = function(value)
    local success, reason = setAllUnlocked(value)
    if success then SetUnlocked(value) end
    return success, reason
end

SLASH_MYTHINCACTIONBARSVEHICLE1 = "/miabvehicle"
SlashCmdList.MYTHINCACTIONBARSVEHICLE = ns.OpenVehicleSettings

local events = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED", "UPDATE_BINDINGS", "UI_SCALE_CHANGED",
}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        StopDrag()
        unlocked = false
        if mover then mover:Hide() end
        pending = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then Refresh() end
    elseif not queued then
        queued = true
        C_Timer.After(0, function()
            queued = false
            Refresh()
        end)
    end
end)

ns.SpecialConfigTargets.vehicleControls = {
    name = "Vehicle Exit",
    GetSettings = Settings,
    defaults = defaults,
    Refresh = Refresh,
    IsUnlocked = function() return unlocked end,
    SetUnlocked = SetUnlocked,
    Count = function() return 1 end,
    paging = true,
    Bind = function(index, key)
        return ns.SetSpecialBarBinding(group, index, key)
    end,
}

function ns.OpenVehicleSettings()
    ns.SelectConfigBar("vehicleControls")
end

SlashCmdList.MYTHINCACTIONBARSVEHICLE = ns.OpenVehicleSettings