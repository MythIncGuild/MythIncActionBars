local addonName, ns = ...

local BUTTON_SIZE = 36
local BUTTONS_PER_PAGE = 12
local DIRECTIONS = { UP = true, DOWN = true, LEFT = true, RIGHT = true }

local flyoutErrorPrinted = false

local function FlyoutError(message)
    if flyoutErrorPrinted then return end
    flyoutErrorPrinted = true
    print("|cff7fd5ffMythInc Action Bars:|r Flyout: " .. tostring(message))
end

function ns.InitializeButtonFlyout(button, resolveActionType)
    if not button then return end

    if type(button.WrapScript) ~= "function" then
        FlyoutError("SecureHandlerStateTemplate is missing from a button.")
        button.UpdateFlyout = function() end
        return
    end

    local popup = CreateFrame(
        "Frame", nil, UIParent, "SecureHandlerStateTemplate"
    )
    popup:SetSize(BUTTON_SIZE + 16, BUTTON_SIZE + 16)
    popup:SetFrameStrata("DIALOG")
    popup:Hide()

    local children = {}

    ns.MIABFlyoutPopups =
        ns.MIABFlyoutPopups or setmetatable({}, { __mode = "k" })
    ns.MIABFlyoutPopups[popup] = true

    if not ns.CloseMIABFlyouts then
        function ns.CloseMIABFlyouts(except)
            if InCombatLockdown() then return end
            for other in pairs(ns.MIABFlyoutPopups) do
                if other ~= except and other:IsShown() then
                    other:Hide()
                end
            end
        end

        if WorldFrame then
            WorldFrame:HookScript("OnMouseDown", function()
                ns.CloseMIABFlyouts()
            end)
        end
    end

    if not ns.MIABSecureFlyoutManager then
        ns.MIABSecureFlyoutManager = CreateFrame(
            "Frame", nil, UIParent, "SecureHandlerStateTemplate"
        )
    end

    local manager = ns.MIABSecureFlyoutManager
    button:SetFrameRef("miab-manager", manager)
    button:SetFrameRef("miab-popup", popup)
    popup:SetFrameRef("miab-owner", button)

    button:WrapScript(button, "OnClick", [[
        local flyout = self:GetAttribute("miab-secure-flyout")
        local shouldClick = down == (self:GetAttribute("useOnKeyDown") == true)
        local actionType = self:GetAttribute("type")

        if flyout and shouldClick and actionType then
            self:SetAttribute("miab-restore-type", actionType)
            self:SetAttribute("miab-flyout-click", true)
            self:SetAttribute("type", nil)
            return nil, true
        else
            self:SetAttribute("miab-flyout-click", nil)
        end
    ]], [[
        if self:GetAttribute("miab-flyout-click") then
            self:SetAttribute("miab-flyout-click", nil)
            self:SetAttribute("type", self:GetAttribute("miab-restore-type"))

            local popup = self:GetFrameRef("miab-popup")
            local manager = self:GetFrameRef("miab-manager")

            if popup and manager then
                local active = manager:GetFrameRef("miab-active")
                if active and active ~= popup then
                    active:Hide()
                end

                if popup:IsShown() then
                    popup:Hide()
                    manager:SetFrameRef("miab-active", nil)
                else
                    popup:Show()
                    manager:SetFrameRef("miab-active", popup)
                end
            end
        end
    ]])

    local function AddChild(index)
        local child = CreateFrame(
            "CheckButton",
            nil,
            popup,
            "SecureActionButtonTemplate,SecureHandlerStateTemplate"
        )

        child:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        child:RegisterForClicks("AnyDown", "AnyUp")
        child:SetAttribute("type", "spell")
        child:SetAttribute("useOnKeyDown", false)

        local bg = child:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.06, 0.06, 0.06, 0.94)

        local icon = child:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", -2, 2)
        child.icon = icon

        local border = child:CreateTexture(nil, "OVERLAY")
        border:SetAllPoints()
        border:SetAtlas("UI-HUD-ActionBar-IconFrame")

        local cooldown = CreateFrame(
            "Cooldown", nil, child, "CooldownFrameTemplate"
        )
        cooldown:SetAllPoints(icon)
        child.cooldown = cooldown

        child.UpdateCooldown = function(self)
            local spellID = self.MIABSpellID

            if not spellID then
                self.cooldown:Clear()
                return
            end

            local duration = C_Spell.GetSpellCooldownDuration(spellID)
            if duration then
                self.cooldown:SetCooldownFromDurationObject(duration)
            else
                self.cooldown:Clear()
            end
        end

        child:SetScript("OnShow", function(self)
            self:UpdateCooldown()
        end)

        child:HookScript("PostClick", function(self)
            self:UpdateCooldown()
        end)

        child:SetFrameRef("miab-manager", manager)

        -- Close only after Blizzard's secure spell action has executed.
        popup:WrapScript(child, "OnClick", "", [[
            local owner = self:GetParent()
            if owner then
                owner:Hide()
            end

            local manager = self:GetFrameRef("miab-manager")
            if manager then
                manager:SetFrameRef("miab-active", nil)
            end
        ]])

        child:SetScript("OnEnter", function(self)
            local spellID = self:GetAttribute("spell")
            if not spellID then return end

            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(spellID)
            GameTooltip:Show()
        end)

        child:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        children[index] = child
        return child
    end

    local arrow = button.Arrow
        or button:CreateTexture(nil, "OVERLAY", nil, 5)

    arrow:SetSize(12, 8)
    button.Arrow = arrow

    if not button.BorderShadow then
        button.BorderShadow = button:CreateTexture(nil, "BACKGROUND")
        button.BorderShadow:SetAllPoints(button)
        button.BorderShadow:SetColorTexture(0, 0, 0, 0.35)
        button.BorderShadow:Hide()
    end

    button.arrowMainAxisSize = 12
    button.arrowCrossAxisSize = 8
    button.closedArrowOffset = 1
    button.openArrowOffset = 3
    button.popupOffset = 4
    button.popupCrossAxisSize = BUTTON_SIZE
    button.arrowNormalTexture = "UI-HUD-ActionBar-Flyout"
    button.arrowOverTexture = "UI-HUD-ActionBar-Flyout"
    button.arrowDownTexture = "UI-HUD-ActionBar-Flyout"

    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")

    local configuredID, configuredDirection

    button.UpdateFlyout = function(self)
        if InCombatLockdown() then return end

        local kind, id = resolveActionType()
        if kind ~= "flyout" then
            id = nil
        end

        if not id and kind == "flyout" and self.actionSlot then
            local actionKind, actionID = GetActionInfo(self.actionSlot)
            if actionKind == "flyout" then
                id = actionID
            end
        end

        if not id and kind == "flyout" then
            id = self:GetAttribute("spell")
        end

        local direction = self:GetAttribute("flyoutDirection")
        if not DIRECTIONS[direction] then
            direction = "UP"
        end

        if configuredID == id and configuredDirection == direction then
            return
        end

        configuredID, configuredDirection = id, direction
        popup:Hide()
        self:SetAttribute("miab-secure-flyout", nil)

        arrow:SetShown(id ~= nil)

        if direction == "UP" then
            arrow:SetRotation(math.pi / 2)
        elseif direction == "DOWN" then
            arrow:SetRotation(-math.pi / 2)
        elseif direction == "LEFT" then
            arrow:SetRotation(math.pi)
        else
            arrow:SetRotation(0)
        end

        arrow:ClearAllPoints()

        if direction == "UP" then
            arrow:SetPoint("TOP", self, "TOP", 0, 0)
        elseif direction == "DOWN" then
            arrow:SetPoint("BOTTOM", self, "BOTTOM", 0, 0)
        elseif direction == "LEFT" then
            arrow:SetPoint("LEFT", self, "LEFT", 0, 0)
        else
            arrow:SetPoint("RIGHT", self, "RIGHT", 0, 0)
        end

        if not id or not GetFlyoutInfo or not GetFlyoutSlotInfo then
            return
        end

        local _, _, count, known = GetFlyoutInfo(id)
        if not known or not count or count == 0 then return end

        local valid = {}

        for i = 1, count do
            local spellID, overrideID, isKnown =
                GetFlyoutSlotInfo(id, i)

            if isKnown and spellID then
                valid[#valid + 1] = {
                    spellID,
                    overrideID or spellID,
                }
            end
        end

        for i, data in ipairs(valid) do
            local child = children[i] or AddChild(i)

            child:SetAttribute("spell", data[2])
            child.MIABSpellID = data[2]
            child.icon:SetTexture(C_Spell.GetSpellTexture(data[2]))
            child:UpdateCooldown()
            child:ClearAllPoints()

            local offset = (i - 1) * (BUTTON_SIZE + 4)

            if direction == "UP" then
                child:SetPoint(
                    "BOTTOM", popup, "BOTTOM", 0, 8 + offset
                )
            elseif direction == "DOWN" then
                child:SetPoint(
                    "TOP", popup, "TOP", 0, -8 - offset
                )
            elseif direction == "LEFT" then
                child:SetPoint(
                    "RIGHT", popup, "RIGHT", -8 - offset, 0
                )
            else
                child:SetPoint(
                    "LEFT", popup, "LEFT", 8 + offset, 0
                )
            end

            child:Show()
        end

        for i = #valid + 1, #children do
            children[i]:Hide()
        end

        if #valid == 0 then return end

        local length =
            16 + #valid * BUTTON_SIZE + (#valid - 1) * 4

        if direction == "UP" or direction == "DOWN" then
            popup:SetSize(BUTTON_SIZE + 16, length)
        else
            popup:SetSize(length, BUTTON_SIZE + 16)
        end

        popup:ClearAllPoints()

        if direction == "UP" then
            popup:SetPoint("BOTTOM", self, "TOP", 0, 4)
        elseif direction == "DOWN" then
            popup:SetPoint("TOP", self, "BOTTOM", 0, -4)
        elseif direction == "LEFT" then
            popup:SetPoint("RIGHT", self, "LEFT", -4, 0)
        else
            popup:SetPoint("LEFT", self, "RIGHT", 4, 0)
        end

        self:SetAttribute("miab-secure-flyout", id)
    end

    local cooldownEvents = CreateFrame("Frame")
    cooldownEvents:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    cooldownEvents:RegisterEvent("SPELL_UPDATE_CHARGES")
    cooldownEvents:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")

    cooldownEvents:SetScript("OnEvent", function()
        if not popup:IsShown() then return end

        for _, child in ipairs(children) do
            if child:IsShown() then
                child:UpdateCooldown()
            end
        end
    end)

    button:UpdateFlyout()
end

-- Shared button interaction settings.
ns.InteractionButtons = ns.InteractionButtons or {}

function ns.GetButtonInteractionSettings()
    local settings = ns.db and ns.db.buttonInteraction or nil

    return not settings or settings.lockContents ~= false,
        settings and settings.activateOnPress == true or false
end

function ns.RefreshButtonInteraction()
    if InCombatLockdown() then return end

    for button in pairs(ns.InteractionButtons) do
        if button and button.ApplyButtonInteraction then
            button:ApplyButtonInteraction()
        end
    end
end

local interactionEvents = CreateFrame("Frame")
interactionEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
interactionEvents:RegisterEvent("MODIFIER_STATE_CHANGED")

interactionEvents:SetScript("OnEvent", function(_, event, key)
    if event == "PLAYER_REGEN_ENABLED"
        or key == "LSHIFT"
        or key == "RSHIFT"
    then
        ns.RefreshButtonInteraction()
    end
end)

ns.DragHighlightState = ns.DragHighlightState or {
    activeButton = nil,
}

function ns.SetDragHighlight(button, shown)
    local state = ns.DragHighlightState

    if shown then
        local previous = state.activeButton

        if previous
            and previous ~= button
            and previous.DragHighlight
        then
            previous.DragHighlight:Hide()
        end

        if button and button.DragHighlight then
            button.DragHighlight:Show()
            state.activeButton = button
        end
        return
    end

    if button and button.DragHighlight then
        button.DragHighlight:Hide()
    end

    if state.activeButton == button then
        state.activeButton = nil
    end
end

function ns.ClearDragHighlight()
    local state = ns.DragHighlightState
    local button = state.activeButton

    if button and button.DragHighlight then
        button.DragHighlight:Hide()
    end

    state.activeButton = nil
end

local dragCursorFrame = CreateFrame("Frame")
dragCursorFrame:RegisterEvent("CURSOR_CHANGED")

dragCursorFrame:SetScript("OnEvent", function()
    if not GetCursorInfo() then
        ns.ClearDragHighlight()
    end
end)

function ns.CreateActionButton(parent, name, actionSlot)
    local button = CreateFrame(
        "CheckButton",
        name,
        parent,
        "SecureActionButtonTemplate,SecureHandlerStateTemplate"
    )

    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetAttribute("type", "action")
    button:SetAttribute("action", actionSlot)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("useOnKeyDown", false)

    button.ApplyButtonInteraction = function(self)
        if InCombatLockdown() then return end

        local locked, onPress = ns.GetButtonInteractionSettings()

        self:SetAttribute(
            "useOnKeyDown",
            onPress and locked and not IsShiftKeyDown()
        )
    end

    ns.InteractionButtons[button] = true
    button:ApplyButtonInteraction()
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.08, 0.08, 0.08, 0.85)
    button.Background = background

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    button.icon = icon

    local cooldown = CreateFrame(
        "Cooldown", nil, button, "CooldownFrameTemplate"
    )
    cooldown:SetAllPoints(icon)
    button.cooldown = cooldown

    local count = button:CreateFontString(
        nil, "OVERLAY", "NumberFontNormal"
    )
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.Count = count

    local hotKey = button:CreateFontString(
        nil, "OVERLAY", "NumberFontNormalSmall"
    )
    hotKey:SetDrawLayer("OVERLAY", 7)
    hotKey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
    hotKey:SetJustifyH("RIGHT")
    hotKey:SetText("")
    button.HotKey = hotKey

    local checked = button:CreateTexture(nil, "OVERLAY")
    checked:SetAllPoints(icon)
    checked:SetColorTexture(1, 0.82, 0, 0.25)
    button:SetCheckedTexture(checked)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetAllPoints()
    border:SetAtlas("UI-HUD-ActionBar-IconFrame")
    button.Border = border

    local dragHighlight = button:CreateTexture(
        nil, "OVERLAY", nil, 6
    )
    dragHighlight:SetPoint(
        "TOPLEFT", button, "TOPLEFT", 2, -2
    )
    dragHighlight:SetPoint(
        "BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2
    )
    dragHighlight:SetColorTexture(0.15, 0.8, 0.78, 0.32)
    dragHighlight:Hide()
    button.DragHighlight = dragHighlight

    local function UpdateDragHighlight()
        if InCombatLockdown() then
            ns.SetDragHighlight(button, false)
            return
        end

        local cursorType = GetCursorInfo()

        local validCursor =
            cursorType == "spell"
            or cursorType == "item"
            or cursorType == "macro"
            or cursorType == "action"
            or cursorType == "mount"
            or cursorType == "battlepet"
            or cursorType == "flyout"

        ns.SetDragHighlight(button, validCursor)
    end

    local buttonID =
        ((actionSlot - 1) % BUTTONS_PER_PAGE) + 1

    local modifierPages = {
        shift = { enabled = false, page = 2 },
        ctrl = { enabled = false, page = 3 },
        alt = { enabled = false, page = 4 },
    }

    local automaticPaging = parent.barID == 1
    local currentActionSlot = actionSlot
    local usableState = true
    local resourceState = false
    local outOfRangeState = false
    local UpdateAll

    local function GetPageSlot(page)
        return ((page - 1) * BUTTONS_PER_PAGE) + buttonID
    end

    local function ResolveActionSlot(shiftHeld, ctrlHeld, altHeld)
        if altHeld and modifierPages.alt.enabled then
            return GetPageSlot(modifierPages.alt.page)
        end

        if ctrlHeld and modifierPages.ctrl.enabled then
            return GetPageSlot(modifierPages.ctrl.page)
        end

        if shiftHeld and modifierPages.shift.enabled then
            return GetPageSlot(modifierPages.shift.page)
        end

        return actionSlot
    end

    local function GetEffectiveActionSlot()
        if automaticPaging then
            local page =
                tonumber(button:GetAttribute("miab-page")) or 1
            return GetPageSlot(page)
        end

        return ResolveActionSlot(
            IsShiftKeyDown(),
            IsControlKeyDown(),
            IsAltKeyDown()
        )
    end

    local function GetAppearance()
        local barID = parent.barID

        if not barID or not ns.db or not ns.db.bars then
            return nil
        end

        local settings = ns.db.bars[barID]
        return settings and settings.appearance
    end

    local function RefreshKeybindText()
        if not C_ActionBar.HasAction(currentActionSlot) then
            hotKey:SetText("")
            return
        end

        if not ns.GetDisplayKeybindForActionSlot
            or not ns.FormatKeybind
        then
            hotKey:SetText("")
            return
        end

        local key

        if automaticPaging and ns.GetButtonKeybind then
            key = ns.GetButtonKeybind(1, buttonID, "primary")
                or ns.GetButtonKeybind(1, buttonID, "secondary")
        else
            key = ns.GetDisplayKeybindForActionSlot(
                currentActionSlot
            )
        end

        hotKey:SetText(ns.FormatKeybind(key))
    end

    local function ApplyColor()
        local appearance = GetAppearance()

        local rangeColoring =
            not appearance
            or appearance.rangeColoring ~= false

        local usabilityColoring =
            not appearance
            or appearance.usabilityColoring ~= false

        local desaturateUnusable =
            appearance
            and appearance.desaturateUnusable == true

        if rangeColoring and outOfRangeState then
            icon:SetVertexColor(1, 0.25, 0.25)
        elseif usabilityColoring then
            if usableState then
                icon:SetVertexColor(1, 1, 1)
            elseif resourceState then
                icon:SetVertexColor(0.5, 0.5, 1)
            else
                icon:SetVertexColor(0.4, 0.4, 0.4)
            end
        else
            icon:SetVertexColor(1, 1, 1)
        end

        if icon.SetDesaturated then
            icon:SetDesaturated(
                desaturateUnusable and not usableState
            )
        end
    end

    local function UpdateIcon()
        local texture =
            C_ActionBar.GetActionTexture(currentActionSlot)

        if texture then
            icon:SetTexture(texture)
            icon:Show()
        else
            icon:SetTexture(nil)
            icon:Hide()
        end
    end

    local function UpdateCooldown()
        local duration =
            C_ActionBar.GetActionCooldownDuration(
                currentActionSlot
            )

        cooldown:SetCooldownFromDurationObject(duration)
    end

    local function UpdateCount()
        if not C_ActionBar.HasAction(currentActionSlot) then
            count:SetText("")
            return
        end

        count:SetText(
            C_ActionBar.GetActionDisplayCount(currentActionSlot)
        )
    end

    local function UpdateUsability()
        local usable, lackingResources =
            C_ActionBar.IsUsableAction(currentActionSlot)

        usableState = usable
        resourceState = lackingResources
        ApplyColor()
    end

    local function UpdateCheckedState()
        if not C_ActionBar.HasAction(currentActionSlot) then
            button:SetChecked(false)
            return
        end

        button:SetChecked(
            C_ActionBar.IsCurrentAction(currentActionSlot)
        )
    end

    UpdateAll = function()
        if button.UpdateFlyout then
            button:UpdateFlyout()
        end

        UpdateIcon()
        UpdateCooldown()
        UpdateCount()
        UpdateUsability()
        UpdateCheckedState()
        RefreshKeybindText()
    end

    button.actionSlot = currentActionSlot

    ns.InitializeButtonFlyout(button, function()
        return GetActionInfo(currentActionSlot)
    end)

    button:HookScript("PostClick", function()
        if not InCombatLockdown() then
            local kind = GetActionInfo(currentActionSlot)
            if kind ~= "flyout" then
                ns.CloseMIABFlyouts()
            end
        end
    end)

    local function RefreshEffectiveActionSlot()
        local newSlot = GetEffectiveActionSlot()

        if newSlot == currentActionSlot then
            RefreshKeybindText()
            return
        end

        currentActionSlot = newSlot
        button.actionSlot = currentActionSlot
        outOfRangeState = false

        C_ActionBar.RegisterActionUIButton(
            button, currentActionSlot, cooldown
        )
        C_ActionBar.EnableActionRangeCheck(
            currentActionSlot, true
        )

        UpdateAll()
    end

    local function SetModifierAttribute(
        attribute, shiftHeld, ctrlHeld, altHeld
    )
        button:SetAttribute(
            attribute,
            ResolveActionSlot(
                shiftHeld, ctrlHeld, altHeld
            )
        )
    end

    local automaticPageHandler = [[
        local page = tonumber(newstate) or 1
        local slot = (page - 1) * 12
            + self:GetAttribute("miab-button-id")

        self:SetAttribute("action", slot)
        self:SetAttribute("shift-action*", slot)
        self:SetAttribute("ctrl-action*", slot)
        self:SetAttribute("alt-action*", slot)
        self:SetAttribute("ctrl-shift-action*", slot)
        self:SetAttribute("alt-shift-action*", slot)
        self:SetAttribute("alt-ctrl-action*", slot)
        self:SetAttribute("alt-ctrl-shift-action*", slot)
        self:SetAttribute("miab-page", page)
    ]]

    local function ConfigureAutomaticPaging()
        if not automaticPaging then return end

        local conditions = {
            "[vehicleui] 1",
            "[overridebar] 1",
            "[possessbar] 1",
        }

        for _, modifier in ipairs({ "alt", "ctrl", "shift" }) do
            local entry = modifierPages[modifier]

            if entry.enabled then
                conditions[#conditions + 1] =
                    "[mod:" .. modifier .. "] " .. entry.page
            end
        end

        for page = 2, 6 do
            conditions[#conditions + 1] =
                "[bar:" .. page .. "] " .. page
        end

        for offset = 1, 4 do
            conditions[#conditions + 1] =
                "[bonusbar:" .. offset .. "] " .. (offset + 6)
        end

        conditions[#conditions + 1] = "1"

        UnregisterStateDriver(button, "page")
        button:SetAttribute("_onstate-page", automaticPageHandler)
        button:SetAttribute("miab-button-id", buttonID)
        button:SetAttribute("state-page", nil)

        RegisterStateDriver(
            button, "page", table.concat(conditions, "; ")
        )
    end

    local function ConfigureActionPages(settings)
        if InCombatLockdown() then return false end

        settings = settings or {}

        local shift = settings.shift or {}
        local ctrl = settings.ctrl or {}
        local alt = settings.alt or {}

        modifierPages.shift.enabled =
            shift.enabled and true or false
        modifierPages.shift.page = math.max(
            1, math.min(15, tonumber(shift.page) or 2)
        )

        modifierPages.ctrl.enabled =
            ctrl.enabled and true or false
        modifierPages.ctrl.page = math.max(
            1, math.min(15, tonumber(ctrl.page) or 3)
        )

        modifierPages.alt.enabled =
            alt.enabled and true or false
        modifierPages.alt.page = math.max(
            1, math.min(15, tonumber(alt.page) or 4)
        )

        button:SetAttribute("action", actionSlot)

        SetModifierAttribute(
            "shift-action*", true, false, false
        )
        SetModifierAttribute(
            "ctrl-action*", false, true, false
        )
        SetModifierAttribute(
            "alt-action*", false, false, true
        )
        SetModifierAttribute(
            "ctrl-shift-action*", true, true, false
        )
        SetModifierAttribute(
            "alt-shift-action*", true, false, true
        )
        SetModifierAttribute(
            "alt-ctrl-action*", false, true, true
        )
        SetModifierAttribute(
            "alt-ctrl-shift-action*", true, true, true
        )

        ConfigureAutomaticPaging()
        RefreshEffectiveActionSlot()
        return true
    end

    button:HookScript(
        "OnAttributeChanged",
        function(_, attribute, value)
            if automaticPaging
                and attribute == "miab-page"
                and value
            then
                RefreshEffectiveActionSlot()
            end
        end
    )

    button:SetScript("OnEnter", function(self)
        UpdateDragHighlight()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetAction(currentActionSlot)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        ns.SetDragHighlight(button, false)
        GameTooltip:Hide()
    end)

    local dragged = false
    local placementPending = false
    local buttonHeld = false

    local function RefreshSoon()
        C_Timer.After(0, function()
            UpdateAll()
        end)
    end

    button:SetScript("OnDragStart", function()
        if InCombatLockdown() or GetCursorInfo() then
            return
        end

        local locked = ns.GetButtonInteractionSettings()
        if locked and not IsShiftKeyDown() then
            return
        end

        dragged = true
        PickupAction(currentActionSlot)
        UpdateDragHighlight()
        RefreshSoon()
    end)

    button:SetScript("OnReceiveDrag", function()
        if InCombatLockdown() or not GetCursorInfo() then
            return
        end

        dragged = true
        placementPending = true
        C_ActionBar.PutActionInSlot(currentActionSlot)
        ns.SetDragHighlight(button, false)
        RefreshSoon()
    end)

    button:HookScript("PreClick", function(
        self, mouseButton, down
    )
        if InCombatLockdown() then return end

        if down then
            buttonHeld = true
            dragged = false
            placementPending = GetCursorInfo() ~= nil

            if placementPending then
                self:SetAttribute("type", nil)
            end

            return
        end

        buttonHeld = false

        if dragged or placementPending or GetCursorInfo() then
            self:SetAttribute("type", nil)

            if not dragged and GetCursorInfo() then
                C_ActionBar.PutActionInSlot(currentActionSlot)
                ns.ClearDragHighlight()
                RefreshSoon()
            end
        end
    end)

    button:HookScript("PostClick", function(
        self, mouseButton, down
    )
        if InCombatLockdown() then return end

        if not down then
            self:SetAttribute("type", "action")
            placementPending = false
            dragged = false
            buttonHeld = false
        end

        UpdateCheckedState()
    end)

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    eventFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("ACTIONBAR_UPDATE_STATE")
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
    eventFrame:RegisterEvent("ACTION_USABLE_CHANGED")
    eventFrame:RegisterEvent("ACTION_RANGE_CHECK_UPDATE")
    eventFrame:RegisterEvent("MODIFIER_STATE_CHANGED")

    eventFrame:SetScript("OnEvent", function(
        _, event, arg1, arg2, arg3
    )
        if event == "MODIFIER_STATE_CHANGED" then
            RefreshEffectiveActionSlot()
            return
        end

        if event == "ACTION_USABLE_CHANGED" then
            local changes = arg1 or {}

            for _, change in ipairs(changes) do
                if change.slot == currentActionSlot then
                    usableState = change.usable
                    resourceState = change.noMana
                    ApplyColor()
                end
            end

            return
        end

        if event == "ACTION_RANGE_CHECK_UPDATE" then
            local action = arg1
            local inRange = arg2
            local checksRange = arg3

            if action == currentActionSlot then
                outOfRangeState =
                    checksRange and not inRange
                ApplyColor()
            end

            return
        end

        if event == "ACTIONBAR_SLOT_CHANGED" then
            if arg1 ~= 0 and arg1 ~= currentActionSlot then
                return
            end
        end

        UpdateAll()
    end)

    C_ActionBar.RegisterActionUIButton(
        button, currentActionSlot, cooldown
    )
    C_ActionBar.EnableActionRangeCheck(
        currentActionSlot, true
    )

    button.UpdateAll = UpdateAll
    button.RefreshVisualState = ApplyColor
    button.RefreshKeybindText = RefreshKeybindText
    button.ConfigureActionPages = ConfigureActionPages

    button.GetCurrentActionSlot = function()
        return currentActionSlot
    end

    button.SetKeybindText = function(text)
        hotKey:SetText(text or "")
    end

    button.baseActionSlot = actionSlot
    button.actionSlot = currentActionSlot
    button.eventFrame = eventFrame

    UpdateAll()
    return button
end