local addonName, ns = ...

local groups = {
    {
        key = "petBar",
        name = "Pet Bar",
        native = "PetActionBar",
        carrier = "MythIncActionBarsPetBar",
        command = "BONUSACTIONBUTTON",
        menu = "MythIncActionBarsPetSettings",
    },
    {
        key = "stanceBar",
        name = "Stance / Form Bar",
        native = "StanceBar",
        carrier = "MythIncActionBarsStanceBar",
        command = "SHAPESHIFTBUTTON",
        menu = "MythIncActionBarsStanceSettings",
    },
}

local overlays = {}
local hovered
local elapsed = 0

local listener = CreateFrame("Frame", nil, UIParent)
listener:SetFrameStrata("TOOLTIP")
listener:SetFrameLevel(1000)
listener:EnableKeyboard(false)
listener:SetPropagateKeyboardInput(true)

local function Settings(group)
    if group.GetSettings then return group.GetSettings() end
    return ns.db and ns.db[group.key]
end

local function Count(group)
    if group.GetCount then return group.GetCount() end
    if group.key == "stanceBar" then
        return math.max(0, math.min(10, GetNumShapeshiftForms() or 0))
    end
    return 10
end

local function ShowHint(overlay)
    GameTooltip:SetOwner(overlay, "ANCHOR_TOP")
    GameTooltip:SetText(
        overlay.group.name .. " - Button " .. overlay.index
    )

    local settings = Settings(overlay.group)
    local custom = settings and settings.keybinds
        and settings.keybinds[overlay.index]

    local inherited = overlay.group.GetInheritedKey
        and overlay.group.GetInheritedKey(overlay.index)
        or (overlay.group.command
            and GetBindingKey(overlay.group.command .. overlay.index))

    local key = custom or inherited

    GameTooltip:AddLine(
        "Current: " .. (key and ns.FormatKeybind(key) or "Unbound"),
        1, 1, 1
    )
    GameTooltip:AddLine(
        "Press a key to bind. Delete / Backspace / Escape clears. "
            .. "Move away and press Escape to exit.",
        0.5, 0.85, 1, true
    )
    GameTooltip:Show()
end

local function Normalize(key)
    if type(key) ~= "string" then return nil end
    key = key:upper():gsub("%s+", "")
    return key ~= "" and key or nil
end

local function RefreshBindingUI()
    if ns.RefreshKeybindDisplay then ns.RefreshKeybindDisplay() end
    if ns.RefreshConfig then ns.RefreshConfig() end

    for _, group in ipairs(groups) do
        local menu = _G[group.menu]
        if menu and menu:IsShown() and menu.Refresh then
            menu:Refresh()
        end
    end
end

local function Transfer(key, assign)
    if InCombatLockdown() then return false, "combat" end

    key = Normalize(key)
    if not key then return assign(nil) end

    local removed = {}

    local function Remove(container, slot)
        if Normalize(container[slot]) == key then
            removed[#removed + 1] = {
                container, slot, container[slot],
            }
            container[slot] = nil
        end
    end

    -- Include disabled bars so they cannot reclaim a transferred key later.
    for _, settings in pairs(ns.db.bars or {}) do
        for _, entry in pairs(settings.keybinds or {}) do
            if type(entry) == "table" then
                Remove(entry, "primary")
                Remove(entry, "secondary")
            end
        end
    end

    for _, group in ipairs(groups) do
        local settings = Settings(group)
        if settings then
            for slot in pairs(settings.keybinds or {}) do
                Remove(settings.keybinds, slot)
            end
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

    RefreshBindingUI()
    return success, reason
end

local function SetSpecialBinding(group, index, key)
    if InCombatLockdown() then return false end

    local settings = Settings(group)
    if not settings or not settings.enabled
        or index < 1 or index > Count(group) then
        return false
    end

    settings.keybinds = settings.keybinds or {}

    for otherIndex, value in pairs(settings.keybinds) do
        if key and value == key then
            settings.keybinds[otherIndex] = nil
        end
    end
    settings.keybinds[index] = key

    if not key then
        if group.ClearInherited then
            group.ClearInherited(index)
        elseif group.command then
            local inherited = {
                GetBindingKey(group.command .. index),
            }
            local changed = false

            for _, inheritedKey in ipairs(inherited) do
                if SetBinding(inheritedKey) then changed = true end
            end

            if changed then
                SaveBindings(GetCurrentBindingSet())
            end
        end
    end

    ns.ApplyAllKeybinds()
    if ns.RefreshConfig then ns.RefreshConfig() end

    for _, other in ipairs(groups) do
        local menu = _G[other.menu]
        if menu and menu.Refresh then menu:Refresh() end
    end

    return true
end

function ns.SetSpecialBarBinding(group, index, key)
    if InCombatLockdown() then return false, "combat" end

    local settings = Settings(group)
    if not settings or not settings.enabled
        or type(index) ~= "number"
        or index < 1
        or index ~= math.floor(index)
        or index > Count(group) then
        return false, "invalid"
    end

    return Transfer(key, function(value)
        return SetSpecialBinding(group, index, value)
    end)
end

function ns.SetNativeBarBinding(name, index, key)
    for _, group in ipairs(groups) do
        if group.key == name then
            return ns.SetSpecialBarBinding(group, index, key)
        end
    end
    return false, "missing"
end

local function Bind(key)
    if InCombatLockdown()
        or not ns.IsKeybindModeActive()
        or not hovered then
        return
    end

    local target = hovered
    local carrier = _G[target.group.carrier]

    if not carrier
        or target:GetParent():GetParent() ~= carrier
        or not target:IsVisible() then
        return
    end

    if ns.SetSpecialBarBinding(target.group, target.index, key) then
        ShowHint(target)
    end
end

local function CreateOverlay(group, index, button)
    local overlay = CreateFrame(
        "Frame", nil, button, "BackdropTemplate"
    )
    overlay:SetAllPoints(button)
    overlay:SetFrameLevel(button:GetFrameLevel() + 25)
    overlay:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    overlay:SetBackdropBorderColor(0.15, 0.65, 0.68, 0.9)
    overlay:EnableMouse(true)
    overlay:EnableMouseWheel(true)
    overlay.group, overlay.index = group, index

    overlay:SetScript("OnEnter", function(self)
        hovered = self
        self:SetBackdropBorderColor(0.2, 0.9, 0.9, 1)
        listener:SetPropagateKeyboardInput(false)
        ShowHint(self)
    end)

    overlay:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.15, 0.65, 0.68, 0.9)
        if hovered == self then
            hovered = nil
            listener:SetPropagateKeyboardInput(true)
            GameTooltip:Hide()
        end
    end)

    overlay:SetScript("OnHide", function(self)
        if hovered == self then
            hovered = nil
            listener:SetPropagateKeyboardInput(true)
            GameTooltip:Hide()
        end
    end)

    overlay:SetScript("OnMouseDown", function(_, mouseButton)
        if mouseButton == "LeftButton"
            or mouseButton == "RightButton" then
            return
        end

        local base = ns.NormalizeKeybindMouseButton(mouseButton)
        local key = base and ns.BuildCapturedKey(base)
        if key then Bind(key) end
    end)

    overlay:SetScript("OnMouseWheel", function(_, delta)
        local key = ns.BuildCapturedKey(
            delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"
        )
        if key then Bind(key) end
    end)

    overlay:Hide()
    overlays[button] = overlay
    return overlay
end

local function RefreshOverlays()
    if InCombatLockdown() then return end

    local active = ns.IsKeybindModeActive()
    listener:EnableKeyboard(active)
    local wanted = {}

    if not active then
        for _, overlay in pairs(overlays) do overlay:Hide() end
        return
    end

    for _, group in ipairs(groups) do
        local settings = Settings(group)
        local native = group.native and _G[group.native]
        local carrier = _G[group.carrier]
        local buttons = group.GetButtons and group.GetButtons()
            or (native and native.actionButtons)

        if settings and settings.enabled and buttons and carrier then
            for index, button in ipairs(buttons) do
                if index <= Count(group)
                    and button:GetParent() == carrier
                    and button:IsVisible() then
                    local overlay = overlays[button]
                        or CreateOverlay(group, index, button)
                    overlay:SetFrameLevel(button:GetFrameLevel() + 25)
                    wanted[overlay] = true
                end
            end
        end
    end

    for _, overlay in pairs(overlays) do
        overlay:SetShown(wanted[overlay] == true)
    end
end

function ns.RegisterSpecialBarBindingTarget(group)
    groups[#groups + 1] = group
end

ns.RefreshSpecialBarBindingTargets = RefreshOverlays

local function ActionTargetUnderMouse()
    for _, focus in ipairs(GetMouseFoci() or {}) do
        local frame = focus
        while frame and frame ~= UIParent do
            if frame.barID and frame.buttonID then
                return frame.barID, frame.buttonID
            end
            frame = frame:GetParent()
        end
    end
end

listener:SetScript("OnKeyDown", function(self, key)
    if not ns.IsKeybindModeActive() or InCombatLockdown() then
        self:SetPropagateKeyboardInput(true)
        return
    end

    if key == "ESCAPE" then
        if hovered then
            Bind(nil)
        else
            local barID, buttonID = ActionTargetUnderMouse()
            if barID then
                ns.ClearButtonKeybind(barID, buttonID, "primary")
                ns.ClearButtonKeybind(barID, buttonID, "secondary")
                RefreshBindingUI()
            else
                ns.SetKeybindMode(false)
            end
        end

        self:SetPropagateKeyboardInput(false)
        return
    end

    self:SetPropagateKeyboardInput(not hovered)
    if not hovered then return end

    if key == "DELETE" or key == "BACKSPACE" then
        Bind(nil)
        return
    end

    local binding = ns.BuildCapturedKey(key)
    if binding then Bind(binding) end
end)

local setMode = ns.SetKeybindMode
ns.SetKeybindMode = function(enabled, ...)
    local success, reason = setMode(enabled, ...)
    listener:SetPropagateKeyboardInput(true)
    RefreshOverlays()
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

local function AddMenuDragging(group)
    local menu = _G[group.menu]
    if not menu or menu.mythIncDragInstalled then return end

    menu.mythIncDragInstalled = true
    menu:RegisterForDrag("LeftButton")

    menu:SetScript("OnDragStart", function(self)
        local parent = self:GetParent()
        if parent and parent:IsMovable() then parent:StartMoving() end
    end)

    menu:SetScript("OnDragStop", function(self)
        local parent = self:GetParent()
        if parent then parent:StopMovingOrSizing() end
    end)

    menu:HookScript("OnHide", function(self)
        local parent = self:GetParent()
        if parent then parent:StopMovingOrSizing() end
    end)
end

listener:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.2 then return end
    elapsed = 0

    for _, group in ipairs(groups) do AddMenuDragging(group) end

    if not InCombatLockdown() and ns.IsKeybindModeActive() then
        RefreshOverlays()
    end
end)

listener:RegisterEvent("PLAYER_REGEN_DISABLED")
listener:SetScript("OnEvent", function()
    hovered = nil
    GameTooltip:Hide()
    listener:EnableKeyboard(false)
    for _, overlay in pairs(overlays) do overlay:Hide() end
end)