local addonName, ns = ...

local definitions = {
    {
        key = "extraAction", name = "Extra Action",
        native = "ExtraActionBarFrame", x = -110,
    },
    {
        key = "zoneAbility", name = "Zone Ability",
        native = "ZoneAbilityFrame", x = 110,
    },
}

ns.defaults.extraAbilities = {
    extraAction = {
        enabled = true, scale = 1, x = -110, y = -300, keybinds = {},
    },
    zoneAbility = {
        enabled = true, scale = 1, x = 110, y = -300, keybinds = {},
    },
}

local states = {}
local pending = false
local queued = false
local Refresh
local bindingOwner = CreateFrame("Frame")
local ApplyBindings
local RefreshBindingLabels
local bindingGroups = {}

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = Copy(child) end
    return result
end

local function Settings(definition)
    if not ns.db then return end
    ns.db.extraAbilities = ns.db.extraAbilities or {}
    local defaults = ns.defaults.extraAbilities[definition.key]
    local settings = ns.db.extraAbilities[definition.key]

    if type(settings) ~= "table" then
        settings = Copy(defaults)
        ns.db.extraAbilities[definition.key] = settings
    end

    for key, value in pairs(defaults) do
        if settings[key] == nil then settings[key] = Copy(value) end
    end
    return settings
end

local function Message(text)
    print("|cff7fd5ffMythInc Action Bars:|r " .. text)
end

local function QueueRefresh()
    if InCombatLockdown() then pending = true; return end
    if queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        Refresh()
    end)
end

local function SaveNative(frame)
    local saved = {
        scale = frame:GetScale(),
        ignore = frame.ignoreInLayout,
        points = {},
    }
    for index = 1, frame:GetNumPoints() do
        saved.points[index] = { frame:GetPoint(index) }
    end
    return saved
end

local function StopDrag(state)
    if state.dragging then
        state.mover:StopMovingOrSizing()
        local x, y = state.mover:GetCenter()
        local parentX, parentY = UIParent:GetCenter()
        if x and y and parentX and parentY then
            local settings = Settings(state.definition)
            settings.x = math.floor(x - parentX + 0.5)
            settings.y = math.floor(y - parentY + 0.5)
        end
    end
    state.dragging = false
end

local function SetUnlocked(state, value)
    if InCombatLockdown() then
        if value then Message("Unlocking is unavailable during combat.") end
        state.unlocked = false
        StopDrag(state)
        state.mover:Hide()
        return
    end

    state.unlocked = value and Settings(state.definition).enabled
        and true or false
    StopDrag(state)
    Refresh()
end

local function CreateState(definition)
    local state = {
        definition = definition, unlocked = false, owned = false,
    }

    local anchor = CreateFrame(
        "Frame", "MythIncActionBars" .. definition.key .. "Anchor",
        UIParent
    )
    anchor:SetSize(52, 52)
    state.anchor = anchor

    local mover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    mover:SetSize(52, 52)
    mover:SetMovable(true)
    mover:SetFrameStrata("DIALOG")
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
    label:SetText((definition.name:gsub(" ", "\n")))

    mover:SetScript("OnDragStart", function()
        if InCombatLockdown() or not state.unlocked then return end
        state.dragging = true
        mover:StartMoving()
    end)

    mover:SetScript("OnUpdate", function()
        if not state.dragging then return end
        if InCombatLockdown() then
            StopDrag(state)
            pending = true
            return
        end

        local x, y = mover:GetCenter()
        local parentX, parentY = UIParent:GetCenter()
        if not x or not y or not parentX or not parentY then return end

        local settings = Settings(definition)
        settings.x, settings.y = x - parentX, y - parentY
        anchor:ClearAllPoints()
        anchor:SetPoint(
            "CENTER", UIParent, "CENTER", settings.x, settings.y
        )
    end)

    mover:SetScript("OnDragStop", function()
        if not state.dragging then return end
        StopDrag(state)
        if InCombatLockdown() then pending = true; return end

        local settings = Settings(definition)
        settings.x = math.floor(settings.x + 0.5)
        settings.y = math.floor(settings.y + 0.5)
        Refresh()
        if ns.RefreshConfig then ns.RefreshConfig() end
    end)

    mover:SetScript("OnHide", function() StopDrag(state) end)
    mover:Hide()
    state.mover = mover

    local proxy = CreateFrame(
        "Button", "MythIncActionBars" .. definition.key .. "Binding",
        anchor, "SecureActionButtonTemplate"
    )
    proxy:SetSize(52, 52)
    proxy:SetPoint("LEFT", anchor, "LEFT", 0, 0)
    proxy:EnableMouse(false)
    proxy:RegisterForClicks("AnyUp")
    state.proxy = proxy

    state.hotkey = proxy:CreateFontString(
        nil, "OVERLAY", "NumberFontNormalGray"
    )
    state.hotkey:SetPoint("TOPRIGHT", proxy, "TOPRIGHT", -5, -5)
    return state
end

local function Restore(state)
    state.unlocked = false
    StopDrag(state)
    state.mover:Hide()
    if not state.owned then return end

    local frame, saved = state.native, state.saved
    state.owned = false
    frame.ignoreInLayout = saved.ignore
    frame:SetScale(saved.scale)
    frame:ClearAllPoints()
    for _, point in ipairs(saved.points) do
        frame:SetPoint(unpack(point))
    end

    if ExtraAbilityContainer then ExtraAbilityContainer:MarkDirty() end
    state.proxy:SetAttribute("type", nil)

    if frame.button and frame.button.UpdateHotkeys then
        frame.button:UpdateHotkeys()
    end
end

Refresh = function()
    if InCombatLockdown() then pending = true; return end
    if not ns.db then return end
    pending = false

    for _, definition in ipairs(definitions) do
        local state = states[definition.key]
        if not state then
            state = CreateState(definition)
            states[definition.key] = state
        end

        local settings = Settings(definition)
        local frame = _G[definition.native]

        if not settings.enabled then
            Restore(state)
        else
            if frame and not state.native then
                state.native, state.saved = frame, SaveNative(frame)
                frame:HookScript("OnShow", QueueRefresh)

                if definition.key == "zoneAbility"
                    and frame.SpellButtonContainer
                    and frame.SpellButtonContainer.Layout then
                    hooksecurefunc(
                        frame.SpellButtonContainer, "Layout", QueueRefresh
                    )
                end

                if definition.key == "zoneAbility"
                    and frame.UpdateDisplayedZoneAbilities then
                    hooksecurefunc(
                        frame, "UpdateDisplayedZoneAbilities", QueueRefresh
                    )
                end
            end

            local scale = math.max(
                0.5, math.min(2, tonumber(settings.scale) or 1)
            )
            settings.scale = scale

            local width = 52
            if frame and definition.key == "zoneAbility"
                and frame.SpellButtonContainer then
                width = math.max(
                    52, frame.SpellButtonContainer:GetWidth()
                )
            end

            state.anchor:SetSize(width * scale, 52 * scale)
            state.mover:SetSize(width * scale, 52 * scale)
            state.anchor:SetScale(1)
            state.proxy:SetScale(scale)
            state.proxy:SetFrameLevel(math.max(
                state.anchor:GetFrameLevel() + 50,
                frame and frame:GetFrameLevel() + 50 or 0,
                ExtraAbilityContainer
                    and ExtraAbilityContainer:GetFrameLevel() + 50 or 0
            ))

            if not state.dragging then
                state.anchor:ClearAllPoints()
                state.anchor:SetPoint(
                    "CENTER", UIParent, "CENTER",
                    tonumber(settings.x) or definition.x,
                    tonumber(settings.y) or -300
                )
                state.mover:ClearAllPoints()
                state.mover:SetPoint(
                    "CENTER", UIParent, "CENTER",
                    tonumber(settings.x) or definition.x,
                    tonumber(settings.y) or -300
                )
            end

            if frame then
                state.owned = true
                frame.ignoreInLayout = true

                local parent = frame:GetParent()
                local parentScale = parent and parent:GetEffectiveScale()
                    or UIParent:GetEffectiveScale()

                frame:SetScale(
                    scale * UIParent:GetEffectiveScale() / parentScale
                )
                frame:ClearAllPoints()
                frame:SetPoint("CENTER", state.anchor, "CENTER", 0, 0)
            end

            if definition.key == "zoneAbility" then
                local abilities = frame and frame.previousZoneAbilities
                local spellID = abilities and abilities[1]
                    and abilities[1].spellID
                local info = spellID and C_Spell.GetSpellInfo(spellID)

                state.proxy:SetAttribute("type", info and "spell" or nil)
                state.proxy:SetAttribute("spell", info and info.name or nil)
                state.configuredSpell = spellID
            end

            local parent = _G.MythIncActionBarsConfig
            state.mover:SetFrameLevel(
                parent and parent:GetFrameLevel() + 250 or 100
            )
            state.mover:SetShown(state.unlocked)
        end
    end

    ApplyBindings()
end

ns.RefreshExtraAbilities = Refresh

local function UsedElsewhere(key, current)
    for _, settings in pairs(ns.db.bars or {}) do
        if settings.enabled then
            for _, entry in pairs(settings.keybinds or {}) do
                if entry.primary == key or entry.secondary == key then
                    return true
                end
            end
        end
    end

    for _, name in ipairs({ "petBar", "stanceBar" }) do
        local settings = ns.db[name]
        if settings and settings.enabled then
            for _, value in pairs(settings.keybinds or {}) do
                if value == key then return true end
            end
        end
    end

    for _, definition in ipairs(definitions) do
        local settings = Settings(definition)
        if definition ~= current and settings.enabled
            and settings.keybinds[1] == key then
            return true
        end
    end

    return false
end

RefreshBindingLabels = function()
    for _, state in pairs(states) do
        local settings = Settings(state.definition)
        local key = state.appliedKey
        if not key and state.definition.key == "extraAction" then
            key = GetBindingKey("EXTRAACTIONBUTTON1")
        end

        state.hotkey:SetText(key and ns.FormatKeybind(key) or "")

        local nativeHotkey = state.definition.key == "extraAction"
            and state.native and state.native.button
            and state.native.button.HotKey

        if settings.enabled and nativeHotkey then
            nativeHotkey:SetText(key and ns.FormatKeybind(key) or "")
            nativeHotkey:SetShown(key ~= nil)
        end

        state.hotkey:SetShown(
            settings.enabled and key ~= nil and (
                ns.IsKeybindModeActive()
                    or state.unlocked
                    or (not nativeHotkey and state.native
                        and state.native:IsVisible())
            )
        )
    end
end

ApplyBindings = function()
    if InCombatLockdown() then pending = true; return end
    ClearOverrideBindings(bindingOwner)

    for _, definition in ipairs(definitions) do
        local state = states[definition.key]
        local settings = Settings(definition)
        state.appliedKey = nil

        local key = settings.keybinds[1]
        if settings.enabled and type(key) == "string" and key ~= ""
            and not UsedElsewhere(key, definition) then
            if definition.key == "extraAction" then
                SetOverrideBinding(
                    bindingOwner, false, key, "EXTRAACTIONBUTTON1"
                )
            else
                SetOverrideBindingClick(
                    bindingOwner, false, key,
                    state.proxy:GetName(), "LeftButton"
                )
            end
            state.appliedKey = key
        end
    end

    RefreshBindingLabels()
end

for _, definition in ipairs(definitions) do
    local group = {
        key = definition.key,
        name = definition.name,
        carrier = "MythIncActionBars" .. definition.key .. "Anchor",
        menu = "MythIncActionBarsExtraSettings",
        GetSettings = function() return Settings(definition) end,
        GetCount = function() return 1 end,
        GetButtons = function()
            local state = states[definition.key]
            return state and { state.proxy } or {}
        end,
    }

    if definition.key == "extraAction" then
        group.command = "EXTRAACTIONBUTTON"
    end

    bindingGroups[definition.key] = group
    ns.RegisterSpecialBarBindingTarget(group)
end

local applyKeybinds = ns.ApplyAllKeybinds
ns.ApplyAllKeybinds = function(...)
    local success, reason = applyKeybinds(...)
    if next(states) then ApplyBindings() end
    return success, reason
end

local setKeybindMode = ns.SetKeybindMode
ns.SetKeybindMode = function(enabled, ...)
    if not InCombatLockdown() then
        if enabled then
            for _, state in pairs(states) do
                state.unlocked = false
                StopDrag(state)
            end
        end
        Refresh()
    end

    local success, reason = setKeybindMode(enabled, ...)
    RefreshBindingLabels()
    return success, reason
end

function ns.OpenExtraAbilitySettings()
    if InCombatLockdown() then
        Message("Open these settings outside combat.")
        return
    end

    Refresh()
    for _, name in ipairs({
        "MythIncActionBarsPetSettings",
        "MythIncActionBarsStanceSettings",
    }) do
        if _G[name] then _G[name]:Hide() end
    end

    if not _G.MythIncActionBarsConfig
        or not _G.MythIncActionBarsConfig:IsShown() then
        ns.ToggleConfig()
    end
    if not dialog then CreateDialog() end
    if dialog then dialog:Refresh(); dialog:Show() end
end

local refreshProfile = ns.RefreshAllBarsFromProfile
ns.RefreshAllBarsFromProfile = function(...)
    local success, reason = refreshProfile(...)
    if success then
        for _, state in pairs(states) do
            state.unlocked = false
            StopDrag(state)
        end
        Refresh()
    end
    return success, reason
end

local setAllUnlocked = ns.SetAllBarsUnlocked
ns.SetAllBarsUnlocked = function(value)
    local success, reason = setAllUnlocked(value)
    if success then
        Refresh()
        for _, state in pairs(states) do SetUnlocked(state, value) end
    end
    return success, reason
end

SLASH_MYTHINCACTIONBARSEXTRA1 = "/miabextra"
SlashCmdList.MYTHINCACTIONBARSEXTRA = ns.OpenExtraAbilitySettings

local events = CreateFrame("Frame")
local elapsed = 0

events:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.2 then return end
    elapsed = 0
    if ns.db then RefreshBindingLabels() end
end)

for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ADDON_LOADED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED", "UPDATE_BINDINGS",
}) do
    events:RegisterEvent(event)
end

events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        for _, state in pairs(states) do
            state.unlocked = false
            StopDrag(state)
            state.mover:Hide()
        end
        pending = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then Refresh() end
    else
        QueueRefresh()
    end
end)

for _, definition in ipairs(definitions) do
    local target = definition

    ns.SpecialConfigTargets[target.key] = {
        name = target.name,
        GetSettings = function() return Settings(target) end,
        defaults = ns.defaults.extraAbilities[target.key],
        Refresh = Refresh,
        IsUnlocked = function()
            local state = states[target.key]
            return state and state.unlocked
        end,
        SetUnlocked = function(value)
            Refresh()
            local state = states[target.key]
            if state then SetUnlocked(state, value) end
        end,
        Count = function() return 1 end,
        Bind = function(index, key)
            return ns.SetSpecialBarBinding(
                bindingGroups[target.key], index, key
            )
        end,
        Inherited = function()
            if target.key == "extraAction" then
                return GetBindingKey("EXTRAACTIONBUTTON1")
            end
        end,
    }
end

function ns.OpenExtraAbilitySettings()
    ns.SelectConfigBar("extraAction")
end

SlashCmdList.MYTHINCACTIONBARSEXTRA = ns.OpenExtraAbilitySettings