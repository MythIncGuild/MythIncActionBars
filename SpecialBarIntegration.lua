local addonName, ns = ...

local groups = {
    {
        key = "petBar", name = "Pet Bar", native = "PetActionBar",
        carrier = "MythIncActionBarsPetBar", command = "BONUSACTIONBUTTON",
        menu = "MythIncActionBarsPetSettings",
    },
    {
        key = "stanceBar", name = "Stance / Form Bar", native = "StanceBar",
        carrier = "MythIncActionBarsStanceBar", command = "SHAPESHIFTBUTTON",
        menu = "MythIncActionBarsStanceSettings",
    },
}

local overlays = {}
local hovered
local elapsed = 0

local listener = CreateFrame("Frame", nil, UIParent)
listener:EnableKeyboard(false)
listener:SetPropagateKeyboardInput(true)

local function Message(text)
    print("|cff7fd5ffMythInc Action Bars:|r " .. text)
end

local function Settings(group)
    if group.GetSettings then
        return group.GetSettings()
    end

    return ns.db and ns.db[group.key]
end

local function Count(group)
    if group.GetCount then
        return group.GetCount()
    end

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
    local custom = settings
        and settings.keybinds
        and settings.keybinds[overlay.index]

    local inherited = overlay.group.GetInheritedKey
        and overlay.group.GetInheritedKey(overlay.index)
        or (
            overlay.group.command
            and GetBindingKey(overlay.group.command .. overlay.index)
        )

    local key = custom or inherited

    GameTooltip:AddLine(
        "Current: " .. (key and ns.FormatKeybind(key) or "Unbound"),
        1, 1, 1
    )

    GameTooltip:AddLine(
        "Press a key to bind. Delete / Backspace / Escape clears. Move away and press Escape to exit.",
        0.5, 0.85, 1, true
    )

    GameTooltip:Show()
end

local function Conflicts(key, group)
    if not key then
        return false
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

    for _, other in ipairs(groups) do
        local settings = Settings(other)

        if other ~= group and settings and settings.enabled then
            for index = 1, Count(other) do
                if (settings.keybinds or {})[index] == key then
                    return true
                end
            end
        end
    end

    return false
end

function ns.SetSpecialBarBinding(group, index, key)
    if InCombatLockdown() then
        return false
    end

    local settings = Settings(group)

    if not settings
        or not settings.enabled
        or index > Count(group)
    then
        return false
    end

    if Conflicts(key, group) then
        Message("That key belongs to another enabled bar. Clear that binding first.")
        return false
    end

    settings.keybinds = settings.keybinds or {}

    for slot, value in pairs(settings.keybinds) do
        if key and value == key then
            settings.keybinds[slot] = nil
        end
    end

    settings.keybinds[index] = key

    if not key then
        if group.ClearInherited then
            group.ClearInherited(index)
        elseif group.command then
            local inherited = { GetBindingKey(group.command .. index) }
            local changed = false

            for _, inheritedKey in ipairs(inherited) do
                if SetBinding(inheritedKey) then
                    changed = true
                end
            end

            if changed then
                SaveBindings(GetCurrentBindingSet())
            end
        end
    end

    ns.ApplyAllKeybinds()

    if ns.RefreshConfig then
        ns.RefreshConfig()
    end

    for _, targetGroup in ipairs(groups) do
        local menu = _G[targetGroup.menu]

        if menu and menu.Refresh then
            menu:Refresh()
        end
    end

    return true
end

local function Bind(key)
    if InCombatLockdown()
        or not ns.IsKeybindModeActive()
        or not hovered
    then
        return
    end

    local target = hovered
    local carrier = _G[target.group.carrier]

    if not carrier
        or target:GetParent():GetParent() ~= carrier
        or not target:IsVisible()
    then
        return
    end

    if ns.SetSpecialBarBinding(target.group, target.index, key) then
        ShowHint(target)
    end
end

local function CreateOverlay(group, index, button)
    local overlay = CreateFrame("Frame", nil, button, "BackdropTemplate")
    overlay:SetAllPoints(button)
    overlay:SetFrameLevel(button:GetFrameLevel() + 25)
    overlay:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    overlay:SetBackdropBorderColor(0.15, 0.65, 0.68, 0.9)
    overlay:EnableMouse(true)
    overlay:EnableMouseWheel(true)

    overlay.group = group
    overlay.index = index

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
        if mouseButton == "LeftButton" or mouseButton == "RightButton" then
            return
        end

        local base = ns.NormalizeKeybindMouseButton(mouseButton)
        local key = base and ns.BuildCapturedKey(base)

        if key then
            Bind(key)
        end
    end)

    overlay:SetScript("OnMouseWheel", function(_, delta)
        local key = ns.BuildCapturedKey(
            delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"
        )

        if key then
            Bind(key)
        end
    end)

    overlay:Hide()
    overlays[button] = overlay

    return overlay
end

local function RefreshOverlays()
    if InCombatLockdown() then
        return
    end

    local active = ns.IsKeybindModeActive()
    listener:EnableKeyboard(active)

    local wanted = {}

    if not active then
        for _, overlay in pairs(overlays) do
            overlay:Hide()
        end

        return
    end

    for _, group in ipairs(groups) do
        local settings = Settings(group)
        local native = group.native and _G[group.native]
        local carrier = _G[group.carrier]

        local buttons = group.GetButtons
            and group.GetButtons()
            or (native and native.actionButtons)

        if settings and settings.enabled and buttons and carrier then
            for index, button in ipairs(buttons) do
                if index <= Count(group)
                    and button:GetParent() == carrier
                    and button:IsVisible()
                then
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

listener:SetScript("OnKeyDown", function(_, key)
    if not ns.IsKeybindModeActive() then
        return
    end

    if key == "ESCAPE" then
        if hovered then
            Bind(nil)
        else
            ns.SetKeybindMode(false)
        end

        return
    end

    if not hovered then
        return
    end

    if key == "DELETE" or key == "BACKSPACE" then
        Bind(nil)
        return
    end

    local binding = ns.BuildCapturedKey(key)

    if binding then
        Bind(binding)
    end
end)

local setMode = ns.SetKeybindMode

ns.SetKeybindMode = function(enabled, ...)
    if not enabled
        and not InCombatLockdown()
        and ns.IsKeybindModeActive()
        and IsKeyDown("ESCAPE")
    then
        if hovered then
            Bind(nil)
            return true
        end

        for _, focus in ipairs(GetMouseFoci() or {}) do
            local frame = focus

            while frame and frame ~= UIParent do
                if frame.barID and frame.buttonID then
                    ns.ClearButtonKeybind(
                        frame.barID,
                        frame.buttonID,
                        "primary"
                    )

                    if ns.RefreshConfig then
                        ns.RefreshConfig()
                    end

                    return true
                end

                frame = frame:GetParent()
            end
        end
    end

    local success, reason = setMode(enabled, ...)
    RefreshOverlays()

    return success, reason
end

local setButtonKeybind = ns.SetButtonKeybind

ns.SetButtonKeybind = function(barID, buttonID, slot, key)
    if key then
        local normalized = string.upper(key)

        for _, group in ipairs(groups) do
            local settings = Settings(group)

            if settings and settings.enabled then
                for index = 1, Count(group) do
                    if (settings.keybinds or {})[index] == normalized then
                        Message(
                            "That key belongs to the "
                                .. group.name
                                .. ". Clear that binding first."
                        )

                        return false, "conflict"
                    end
                end
            end
        end
    end

    return setButtonKeybind(barID, buttonID, slot, key)
end

local function AddMenuDragging(group)
    local menu = _G[group.menu]

    if not menu or menu.mythIncDragInstalled then
        return
    end

    menu.mythIncDragInstalled = true
    menu:RegisterForDrag("LeftButton")

    menu:SetScript("OnDragStart", function(self)
        local parent = self:GetParent()

        if parent and parent:IsMovable() then
            parent:StartMoving()
        end
    end)

    menu:SetScript("OnDragStop", function(self)
        local parent = self:GetParent()

        if parent then
            parent:StopMovingOrSizing()
        end
    end)

    menu:HookScript("OnHide", function(self)
        local parent = self:GetParent()

        if parent then
            parent:StopMovingOrSizing()
        end
    end)
end

listener:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta

    if elapsed < 0.2 then
        return
    end

    elapsed = 0

    for _, group in ipairs(groups) do
        AddMenuDragging(group)
    end

    if not InCombatLockdown() and ns.IsKeybindModeActive() then
        RefreshOverlays()
    end
end)

listener:RegisterEvent("PLAYER_REGEN_DISABLED")

listener:SetScript("OnEvent", function()
    hovered = nil
    GameTooltip:Hide()
    listener:EnableKeyboard(false)

    for _, overlay in pairs(overlays) do
        overlay:Hide()
    end
end)