local addonName, ns = ...

local function Normalize(key)
    if type(key) ~= "string" then return nil end
    key = key:upper():gsub("%s+", "")
    return key ~= "" and key or nil
end

local function SpecialSettings()
    local result = {}
    if not ns.db then return result end

    for _, name in ipairs({
        "petBar", "stanceBar", "vehicleControls",
    }) do
        if type(ns.db[name]) == "table" then
            result[#result + 1] = ns.db[name]
        end
    end

    local extra = ns.db.extraAbilities
    if type(extra) == "table" then
        for _, name in ipairs({ "extraAction", "zoneAbility" }) do
            if type(extra[name]) == "table" then
                result[#result + 1] = extra[name]
            end
        end
    end

    return result
end

local function RefreshMenus()
    if ns.RefreshKeybindDisplay then
        ns.RefreshKeybindDisplay()
    end
    if ns.RefreshConfig then
        ns.RefreshConfig()
    end
    if ns.RefreshSpecialBarBindingTargets then
        ns.RefreshSpecialBarBindingTargets()
    end

    for _, name in ipairs({
        "MythIncActionBarsPetSettings",
        "MythIncActionBarsStanceSettings",
        "MythIncActionBarsExtraSettings",
        "MythIncActionBarsVehicleSettings",
    }) do
        local menu = _G[name]
        if menu and menu:IsShown() and menu.Refresh then
            menu:Refresh()
        end
    end
end

local function Transfer(key, assign)
    if InCombatLockdown() then return false, "combat" end

    key = Normalize(key)
    if not key then return assign(nil) end

    -- Keep enough information to restore bindings if assignment fails.
    local removed = {}

    local function Remove(container, slot)
        if Normalize(container[slot]) == key then
            removed[#removed + 1] = {
                container, slot, container[slot],
            }
            container[slot] = nil
        end
    end

    -- Include disabled bars so enabling them later cannot reclaim this key.
    for _, settings in pairs(ns.db.bars or {}) do
        for _, entry in pairs(settings.keybinds or {}) do
            if type(entry) == "table" then
                Remove(entry, "primary")
                Remove(entry, "secondary")
            end
        end
    end

    for _, settings in ipairs(SpecialSettings()) do
        for slot in pairs(settings.keybinds or {}) do
            Remove(settings.keybinds, slot)
        end
    end

    local inherited = GetBindingAction(key) or ""
    local nativeChanged = inherited ~= ""
    local nativeCleared = not nativeChanged or SetBinding(key)

    local success, reason
    if nativeCleared then
        success, reason = assign(key)
    else
        reason = "invalid"
    end

    if not success then
        for _, entry in ipairs(removed) do
            entry[1][entry[2]] = entry[3]
        end

        if nativeChanged and nativeCleared then
            SetBinding(key, inherited)
        end

        ns.ApplyAllKeybinds()
    elseif nativeChanged then
        SaveBindings(GetCurrentBindingSet())
    end

    RefreshMenus()
    return success, reason
end

local setButtonKeybind = ns.SetButtonKeybind
ns.SetButtonKeybind = function(barID, buttonID, slot, key)
    if InCombatLockdown() then return false, "combat" end

    if slot ~= "primary" and slot ~= "secondary" then
        return false, "invalid"
    end

    if not ns.db or not ns.db.bars or not ns.db.bars[barID] then
        return false, "missing"
    end

    return Transfer(key, function(value)
        return setButtonKeybind(barID, buttonID, slot, value)
    end)
end

local setSpecialBinding = ns.SetSpecialBarBinding
ns.SetSpecialBarBinding = function(group, index, key)
    if InCombatLockdown() then return false, "combat" end

    local settings = group.GetSettings and group.GetSettings()
        or (ns.db and ns.db[group.key])

    local count = group.GetCount and group.GetCount()
        or (group.key == "stanceBar" and GetNumShapeshiftForms() or 10)

    if not settings or not settings.enabled
        or type(index) ~= "number"
        or index < 1
        or index ~= math.floor(index)
        or index > count then
        return false, "invalid"
    end

    return Transfer(key, function(value)
        return setSpecialBinding(group, index, value)
    end)
end

-- Give the existing pet and stance settings the same assignment path as /kb.
local menuGroups = {
    MythIncActionBarsPetSettings = {
        key = "petBar",
        command = "BONUSACTIONBUTTON",
        GetCount = function() return 10 end,
    },
    MythIncActionBarsStanceSettings = {
        key = "stanceBar",
        command = "SHAPESHIFTBUTTON",
        GetCount = function()
            return math.min(10, GetNumShapeshiftForms() or 0)
        end,
    },
}

local capture = setmetatable({}, { __mode = "k" })

local function InstallMenuCapture(menu)
    if menu.mythIncAssignmentCaptureInstalled then return end

    local original = menu:GetScript("OnKeyDown")
    if not original then return end

    menu.mythIncAssignmentCaptureInstalled = true

    menu:SetScript("OnKeyDown", function(self, key)
        local target = capture[self]
        if not target then
            return original(self, key)
        end

        if key == "ESCAPE" then
            capture[self] = nil
            return original(self, key)
        end

        local binding
        if key ~= "DELETE" and key ~= "BACKSPACE" then
            binding = ns.BuildCapturedKey(key)
            if not binding then return end
        end

        if not InCombatLockdown() then
            ns.SetSpecialBarBinding(
                target.group, target.index, binding
            )
        end

        capture[self] = nil
        original(self, "ESCAPE")
    end)

    menu:HookScript("OnHide", function(self)
        capture[self] = nil
    end)
end

local createButton = ns.ConfigWidgets.CreateButton
ns.ConfigWidgets.CreateButton = function(
    parent, text, width, height, x, y, onClick
)
    local group = parent and menuGroups[parent:GetName()]

    -- The existing pet and stance menus use this column for slot bindings.
    local index = group and text == "" and x == 636
        and type(y) == "number"
        and ((-192 - y) / 38 + 1)

    if index and index == math.floor(index)
        and index >= 1 and index <= 10 then
        local originalClick = onClick

        onClick = function(...)
            local settings = ns.db and ns.db[group.key]
            if InCombatLockdown()
                or not settings
                or not settings.enabled
                or index > group.GetCount() then
                return
            end

            InstallMenuCapture(parent)
            originalClick(...)
            capture[parent] = {
                group = group,
                index = index,
            }
        end
    end

    return createButton(
        parent, text, width, height, x, y, onClick
    )
end

local function InheritUnlock(barID)
    if not InCombatLockdown() and ns.IsMoveModeActive() then
        local settings = ns.db and ns.db.bars
            and ns.db.bars[barID]
        if settings and settings.enabled then
            ns.SetBarUnlocked(barID, true)
        end
    end
end

local setBarEnabled = ns.SetBarEnabled
ns.SetBarEnabled = function(barID, enabled)
    local settings = ns.db and ns.db.bars
        and ns.db.bars[barID]
    local wasEnabled = settings and settings.enabled

    local result, reason = setBarEnabled(barID, enabled)

    if enabled and not wasEnabled then
        InheritUnlock(barID)
    end

    return result, reason
end

local addBar = ns.AddBar
ns.AddBar = function(...)
    local barID, reason = addBar(...)
    if type(barID) == "number" then
        InheritUnlock(barID)
    end
    return barID, reason
end