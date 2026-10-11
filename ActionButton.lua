
local addonName, ns = ...

local BUTTON_SIZE = 36
local BUTTONS_PER_PAGE = 12
local DIRECTIONS = {
    UP = true,
    DOWN = true,
    LEFT = true,
    RIGHT = true,
}

local flyoutErrorPrinted = false

local function FlyoutError(message)
    if flyoutErrorPrinted then return end
    flyoutErrorPrinted = true
    print("|cff7fd5ffMythInc Action Bars:|r Flyout: " .. tostring(message))
end

local castingButtons = setmetatable({}, { __mode = "k" })

local function ModifierCondition(action)
    local key = GetModifiedClick(action)
    if not key or key == "NONE" then return nil end

    local conditions = {}

    for modifier in key:lower():gmatch("[^%-]+") do
        if modifier ~= "alt"
            and modifier ~= "ctrl"
            and modifier ~= "shift"
        then
            return nil
        end

        conditions[#conditions + 1] = "mod:" .. modifier
    end

    if #conditions > 0 then
        return table.concat(conditions, ",")
    end
end

function ns.InitializeSpellCasting(button, resolveSpellID)
    button.RefreshCasting = function(self)
        if InCombatLockdown() then return end

        local spellID = resolveSpellID()
        local parts = {}

        if spellID then
            local helpful = C_Spell.IsSpellHelpful(spellID)
            local harmful = C_Spell.IsSpellHarmful(spellID)

            if GetCVarBool("enableMouseoverCast") then
                local key = GetModifiedClick("MOUSEOVERCAST")
                local modifier = ModifierCondition("MOUSEOVERCAST")

                if key == "NONE" or modifier then
                    local prefix = modifier and (modifier .. ",") or ""

                    if helpful then
                        parts[#parts + 1] =
                            "[" .. prefix .. "@mouseover,help] mouseover"
                    end

                    if harmful then
                        parts[#parts + 1] =
                            "[" .. prefix .. "@mouseover,harm] mouseover"
                    end
                end
            end

            local selfCast = ModifierCondition("SELFCAST")
            local focusCast = ModifierCondition("FOCUSCAST")

            if selfCast then
                parts[#parts + 1] = "[" .. selfCast .. "] player"
            end

            if focusCast then
                parts[#parts + 1] = "[" .. focusCast .. "] focus"
            end

            if helpful and GetCVarBool("autoSelfCast") then
                parts[#parts + 1] = "[help] target"

                if harmful then
                    parts[#parts + 1] = "[harm] target"
                end

                parts[#parts + 1] = "player"
            else
                parts[#parts + 1] = "target"
            end
        end

        local driver =
            #parts > 0 and table.concat(parts, "; ") or nil

        if self.MIABUnitDriver ~= driver then
            UnregisterAttributeDriver(self, "unit")
            self:SetAttribute("unit", nil)

            if driver then
                RegisterAttributeDriver(self, "unit", driver)
            end

            self.MIABUnitDriver = driver
        end
    end

    castingButtons[button] = true
    button:RefreshCasting()
end

local castingEvents = CreateFrame("Frame")
castingEvents:RegisterEvent("CVAR_UPDATE")
castingEvents:RegisterEvent("UPDATE_BINDINGS")
castingEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
castingEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
castingEvents:RegisterEvent("SPELLS_CHANGED")

castingEvents:SetScript("OnEvent", function()
    if InCombatLockdown() then return end

    for button in pairs(castingButtons) do
        button:RefreshCasting()
    end
end)

local feedbackButtons = setmetatable({}, { __mode = "k" })

function ns.SetButtonCooldownDuration(cooldown, duration)
    if duration then
        cooldown:SetCooldownFromDurationObject(duration)
    else
        cooldown:Clear()
    end
end

function ns.InitializeButtonSpellFeedback(button, resolveSpellID)
    local recharge = CreateFrame(
        "Cooldown", nil, button, "CooldownFrameTemplate"
    )
    recharge:SetAllPoints(button.icon)
    recharge:EnableMouse(false)
    recharge:SetDrawSwipe(false)
    recharge:SetDrawEdge(true)
    recharge:SetHideCountdownNumbers(true)
    button.chargeCooldown = recharge

    local alert = CreateFrame(
        "Frame", nil, button, "ActionButtonSpellAlertTemplate"
    )
    alert:EnableMouse(false)
    alert:SetPoint("CENTER", button, "CENTER", 0, 0)
    alert:SetSize(
        button:GetWidth() * 1.4,
        button:GetHeight() * 1.4
    )
    alert:Hide()
    button.SpellActivationAlert = alert

    local staticGlow =
        button:CreateTexture(nil, "OVERLAY", nil, 7)
    staticGlow:SetAtlas("UI-HUD-RotationHelper-ProcAltGlow")
    staticGlow:SetPoint(
        "TOPLEFT", button, "TOPLEFT", -4, 4
    )
    staticGlow:SetPoint(
        "BOTTOMRIGHT", button, "BOTTOMRIGHT", 4, -4
    )
    staticGlow:Hide()
    button.StaticProcGlow = staticGlow

    local macroName = button:CreateFontString(
        nil, "OVERLAY", "NumberFontNormalSmall"
    )
    macroName:SetPoint(
        "BOTTOM", button, "BOTTOM", 0, 2
    )
    macroName:SetWidth(button:GetWidth() - 4)
    macroName:SetWordWrap(false)
    macroName:SetText("")
    button.MacroName = macroName

    button.UpdateProcGlow = function(self)
        local appearance = self.MIABFeedbackAppearance or {}
        local mode = appearance.procStyle or "ANIMATED"
        local spellID = resolveSpellID()

        local show =
            mode ~= "OFF"
            and self:IsVisible()
            and spellID
            and C_SpellActivationOverlay.IsSpellOverlayed(spellID)

        self.StaticProcGlow:SetShown(
            show and mode == "STATIC" or false
        )

        if show and mode == "ANIMATED" then
            ActionButtonSpellAlertManager:ShowAlert(self)
        else
            ActionButtonSpellAlertManager:HideAlert(self)
        end
    end

    button:HookScript("OnSizeChanged", function(self, width, height)
        self.SpellActivationAlert:SetSize(
            width * 1.4,
            height * 1.4
        )
        self.MacroName:SetWidth(math.max(1, width - 4))
    end)

    button:HookScript("OnShow", function(self)
        self:UpdateProcGlow()
    end)

    button:HookScript("OnHide", function(self)
        ActionButtonSpellAlertManager:HideAlert(self)
        self.StaticProcGlow:Hide()
    end)

    feedbackButtons[button] = true
end

local feedbackEvents = CreateFrame("Frame")
feedbackEvents:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
feedbackEvents:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
feedbackEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
feedbackEvents:RegisterEvent("SPELLS_CHANGED")
feedbackEvents:RegisterEvent("UPDATE_MACROS")

feedbackEvents:SetScript("OnEvent", function()
    for button in pairs(feedbackButtons) do
        button:UpdateProcGlow()
    end
end)

function ns.InitializeButtonFlyout(button, resolveActionType)
    if not button then return end

    if type(button.WrapScript) ~= "function" then
        FlyoutError("SecureHandlerStateTemplate is missing from a button.")
        button.UpdateFlyout = function() end
        button.ConfigureActionSetFlyouts = function() end
        return
    end

    ns.MIABFlyoutPopups = ns.MIABFlyoutPopups
        or setmetatable({}, { __mode = "k" })

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
    local children = {}
    local popups = {}
    local configuredID
    local configuredDirection
    local currentPopup
    local usesActionSets = false
    local setFlyoutIDs = {}
    local setStateKey = "miab-currentset"
    button.MIABFlyoutChildren = children

    local arrowContainer = CreateFrame("Frame", nil, button)
    arrowContainer:SetAllPoints(button)
    arrowContainer:EnableMouse(false)
    arrowContainer:Hide()
    button:SetFrameRef("miab-flyout-arrow", arrowContainer)

    local arrow = arrowContainer:CreateTexture(
        nil, "OVERLAY", nil, 5
    )
    arrow:SetSize(12, 8)
    button.Arrow = arrow

    if not button.BorderShadow then
        button.BorderShadow =
            button:CreateTexture(nil, "BACKGROUND")
        button.BorderShadow:SetAllPoints(button)
        button.BorderShadow:SetColorTexture(
            0, 0, 0, 0.35
        )
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

    arrow:SetTexture(
        "Interface\\ChatFrame\\ChatFrameExpandArrow"
    )
    arrow:Hide()

    local function PopupDirection()
        local direction = button:GetAttribute("flyoutDirection")
        return DIRECTIONS[direction] and direction or "UP"
    end

    local function PositionArrow(direction, shown)
        arrow:Show()
        arrowContainer:SetShown(shown)

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
            arrow:SetPoint("TOP", button, "TOP", 0, 0)
        elseif direction == "DOWN" then
            arrow:SetPoint("BOTTOM", button, "BOTTOM", 0, 0)
        elseif direction == "LEFT" then
            arrow:SetPoint("LEFT", button, "LEFT", 0, 0)
        else
            arrow:SetPoint("RIGHT", button, "RIGHT", 0, 0)
        end
    end

    button:WrapScript(button, "OnClick", [[
        local useSets = self:GetAttribute("miab-flyout-uses-sets")
        local stateKey = self:GetAttribute("miab-flyout-state-key")
            or "miab-currentset"
        local selected = tonumber(self:GetAttribute(stateKey)) or 1
        local flyout
        local popup

        if useSets then
            flyout = self:GetAttribute("miab-flyout-set-" .. selected)
            popup = self:GetFrameRef("miab-flyout-popup-" .. selected)
        else
            flyout = self:GetAttribute("miab-secure-flyout")
            popup = self:GetFrameRef("miab-popup")
        end

        local shouldClick = (down and true or false)
            == (self:GetAttribute("useOnKeyDown") == true)
        local actionType = self:GetAttribute("type")

        if flyout and popup and shouldClick and actionType then
            self:SetAttribute("miab-restore-type", actionType)
            self:SetAttribute("miab-flyout-click", true)
            self:SetAttribute("miab-flyout-click-set", selected)
            self:SetAttribute("type", nil)
            return nil, true
        else
            self:SetAttribute("miab-flyout-click", nil)
        end
    ]], [[
        if self:GetAttribute("miab-flyout-click") then
            self:SetAttribute("miab-flyout-click", nil)
            self:SetAttribute("type", self:GetAttribute("miab-restore-type"))

            local selected = tonumber(
                self:GetAttribute("miab-flyout-click-set")
            ) or 1
            local popup

            if self:GetAttribute("miab-flyout-uses-sets") then
                popup = self:GetFrameRef("miab-flyout-popup-" .. selected)
            else
                popup = self:GetFrameRef("miab-popup")
            end

            local manager = self:GetFrameRef("miab-manager")

            if popup then
                if manager then
                    local count =
                        manager:GetAttribute("miab-popup-count") or 0

                    for i = 1, count do
                        local other =
                            manager:GetFrameRef("miab-popup-" .. i)

                        if other and other ~= popup and other:IsShown() then
                            other:Hide()
                        end
                    end
                end

                if popup:IsShown() then
                    popup:Hide()
                else
                    popup:Show()
                end
            end
        end
    ]])

    local function AddChild(popup, index)
        local child = CreateFrame(
            "CheckButton", nil, popup,
            "SecureActionButtonTemplate,SecureHandlerStateTemplate"
        )
        child:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        child:RegisterForClicks("AnyDown", "AnyUp")
        child:SetAttribute("type", "spell")
        child:SetAttribute("useOnKeyDown", false)

        ns.InitializeSpellCasting(child, function()
            return child.MIABSpellID
        end)

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

        local count = child:CreateFontString(
            nil, "OVERLAY", "NumberFontNormal"
        )
        count:SetPoint(
            "BOTTOMRIGHT", child, "BOTTOMRIGHT", -2, 2
        )
        child.Count = count

        ns.InitializeButtonSpellFeedback(child, function()
            return child.MIABSpellID
        end)

        if button.MIABFeedbackAppearance then
            ns.ApplyButtonFeedbackAppearance(
                child, button.MIABFeedbackAppearance
            )
        end

        child.UpdateCooldown = function(self)
            local spellID = self.MIABSpellID

            if spellID then
                ns.SetButtonCooldownDuration(
                    self.cooldown,
                    C_Spell.GetSpellCooldownDuration(spellID)
                )
                ns.SetButtonCooldownDuration(
                    self.chargeCooldown,
                    C_Spell.GetSpellChargeDuration(spellID, true)
                )
                self.Count:SetText(
                    C_Spell.GetSpellDisplayCount(spellID)
                )
            else
                self.cooldown:Clear()
                self.chargeCooldown:Clear()
                self.Count:SetText("")
            end

            self:UpdateProcGlow()
        end

        child:HookScript("OnShow", function(self)
            self:UpdateCooldown()
        end)

        child:HookScript("PostClick", function(self)
            self:UpdateCooldown()
        end)

        popup:WrapScript(child, "OnClick", "", [[
            local shouldClick =
                down == (self:GetAttribute("useOnKeyDown") == true)

            if shouldClick then
                local owner = self:GetParent()
                if owner then
                    owner:Hide()
                end
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

        popup.MIABChildren[index] = child
        children[#children + 1] = child
        return child
    end

    local function CreatePopup(id)
        local popup = CreateFrame(
            "Frame", nil, UIParent, "SecureHandlerStateTemplate"
        )
        popup:SetSize(BUTTON_SIZE + 16, BUTTON_SIZE + 16)
        popup:SetFrameStrata("DIALOG")
        popup:Hide()
        popup.MIABChildren = {}
        popup.MIABID = id

        ns.MIABFlyoutPopups[popup] = true

        local popupIndex =
            (manager:GetAttribute("miab-popup-count") or 0) + 1

        manager:SetFrameRef("miab-popup-" .. popupIndex, popup)
        manager:SetAttribute("miab-popup-count", popupIndex)

        button:SetFrameRef("miab-manager", manager)

        popups[id] = popup
        return popup
    end

    local function PreparePopup(id, direction, force)
        if not id or not GetFlyoutInfo or not GetFlyoutSlotInfo then
            return nil
        end

        local popup = popups[id]

        if popup and popup.MIABDirection == direction and not force then
            return popup
        end

        local _, _, count, known = GetFlyoutInfo(id)
        if not known or not count or count == 0 then
            return nil
        end

        if not popup then
            popup = CreatePopup(id)
        end

        local valid = {}
        for i = 1, count do
            local spellID, overrideID, isKnown =
                GetFlyoutSlotInfo(id, i)

            if isKnown and spellID then
                valid[#valid + 1] = {
                    spellID, overrideID or spellID,
                }
            end
        end

        if #valid == 0 then
            popup:Hide()
            return nil
        end

        popup:Hide()
        popup.MIABDirection = direction

        for i, data in ipairs(valid) do
            local child = popup.MIABChildren[i] or AddChild(popup, i)
            child:SetAttribute("spell", data[1])
            child.MIABSpellID = data[1]
            child:RefreshCasting()
            child.icon:SetTexture(
                C_Spell.GetSpellTexture(data[2])
            )
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

        for i = #valid + 1, #popup.MIABChildren do
            popup.MIABChildren[i]:Hide()
        end

        local length =
            16 + #valid * BUTTON_SIZE + (#valid - 1) * 4

        if direction == "UP" or direction == "DOWN" then
            popup:SetSize(BUTTON_SIZE + 16, length)
        else
            popup:SetSize(length, BUTTON_SIZE + 16)
        end

        popup:ClearAllPoints()

        if direction == "UP" then
            popup:SetPoint("BOTTOM", button, "TOP", 0, 4)
        elseif direction == "DOWN" then
            popup:SetPoint("TOP", button, "BOTTOM", 0, -4)
        elseif direction == "LEFT" then
            popup:SetPoint("RIGHT", button, "LEFT", -4, 0)
        else
            popup:SetPoint("LEFT", button, "RIGHT", 4, 0)
        end

        return popup
    end

    button.UpdateFlyout = function(self)
        if InCombatLockdown() then return end

        local kind, id = resolveActionType()
        if kind ~= "flyout" then id = nil end

        if not id and kind == "flyout" and self.actionSlot then
            local actionKind, actionID =
                GetActionInfo(self.actionSlot)
            if actionKind == "flyout" then
                id = actionID
            end
        end

        if not id and kind == "flyout" then
            id = self:GetAttribute("spell")
        end

        local direction = PopupDirection()

        if configuredID == id
            and configuredDirection == direction
        then
            return
        end

        configuredID = id
        configuredDirection = direction
        currentPopup = PreparePopup(id, direction)

        self:SetAttribute("miab-secure-flyout", currentPopup and id or nil)

        if currentPopup then
            self:SetFrameRef("miab-popup", currentPopup)
        end

        PositionArrow(direction, currentPopup ~= nil)
    end

    button.ConfigureActionSetFlyouts = function(self, flyoutsBySet, stateKey)
        if InCombatLockdown() then return end

        setStateKey = stateKey or "miab-currentset"
        self:SetAttribute(
            "miab-flyout-state-key",
            setStateKey
        )
        usesActionSets = type(flyoutsBySet) == "table"
        setFlyoutIDs = flyoutsBySet or {}
        local direction = PopupDirection()

        for _, popup in pairs(popups) do
            if popup:IsShown() then
                popup:Hide()
            end
        end

        self:SetAttribute("miab-flyout-uses-sets", usesActionSets or nil)

        if usesActionSets then
            for setNumber = 1, 12 do
                local id = setFlyoutIDs[setNumber]
                local popup = PreparePopup(id, direction)

                self:SetAttribute(
                    "miab-flyout-set-" .. setNumber,
                    popup and id or nil
                )

                if popup then
                    self:SetFrameRef(
                        "miab-flyout-popup-" .. setNumber, popup
                    )
                end
            end
        end

        configuredID = nil
        configuredDirection = nil
        self:UpdateFlyout()
    end

    local cooldownEvents = CreateFrame("Frame")
    cooldownEvents:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    cooldownEvents:RegisterEvent("SPELL_UPDATE_CHARGES")
    cooldownEvents:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
    cooldownEvents:RegisterEvent("SPELLS_CHANGED")
    cooldownEvents:RegisterEvent("PLAYER_REGEN_ENABLED")

    local spellbookRefreshPending = false

    cooldownEvents:SetScript("OnEvent", function(_, event)
        if event == "SPELLS_CHANGED" and InCombatLockdown() then
            spellbookRefreshPending = true
        elseif event == "SPELLS_CHANGED"
            or (event == "PLAYER_REGEN_ENABLED" and spellbookRefreshPending)
        then
            spellbookRefreshPending = false

            for _, popup in pairs(popups) do
                popup.MIABDirection = nil
            end

            if usesActionSets then
                button:ConfigureActionSetFlyouts(setFlyoutIDs, setStateKey)
            else
                configuredID = nil
                button:UpdateFlyout()
            end
        end

        for _, popup in pairs(popups) do
            if popup:IsShown() then
                for _, child in ipairs(popup.MIABChildren) do
                    if child:IsShown() then
                        child:UpdateCooldown()
                    end
                end
            end
        end
    end)

    button:UpdateFlyout()
end

ns.InteractionButtons = ns.InteractionButtons or {}

function ns.GetButtonInteractionSettings()
    local settings =
        ns.db and ns.db.buttonInteraction or nil

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

local regularButtons = setmetatable({}, { __mode = "k" })
local editingSets = {}
local MAX_SETS = 12

local function ActiveSpecializationID()
    local index = GetSpecialization()
    return index and GetSpecializationInfo(index)
end

function ns.EnsureIndependentRegularBarSets(barID)
    if not ns.db or not ns.db.bars then return nil end

    local settings = ns.db.bars[barID]
    if not settings or settings.source ~= "blizzard" then
        return nil
    end

    settings.actionPages = settings.actionPages or {}
    local pages = settings.actionPages

    if barID == 1 then return pages end
    if pages.independentSetsV2 then return pages end

    for _, modifier in ipairs({ "shift", "ctrl", "alt" }) do
        pages[modifier] = pages[modifier] or {}
        pages[modifier].enabled = false
        pages[modifier].page =
            modifier == "shift" and 2
            or (modifier == "ctrl" and 3 or 4)
    end

    pages.contextRules = {}
    pages.setSources = nil
    pages.setsBySpec = nil
    pages.visibleSetCount = 1
    pages.unifiedSets = true
    pages.independentSetsV2 = true

    return pages
end

local function RegularSetTable(settings, setNumber, create)
    if not settings or setNumber == 1 then return nil end

    local specID = ActiveSpecializationID()
    if not specID then return nil end

    local pages = settings.actionPages
    if not pages then return nil end

    if create then
        pages.setsBySpec = pages.setsBySpec or {}
        pages.setsBySpec[specID] =
            pages.setsBySpec[specID] or {}
        pages.setsBySpec[specID][setNumber] =
            pages.setsBySpec[specID][setNumber] or {}
    end

    return pages.setsBySpec
        and pages.setsBySpec[specID]
        and pages.setsBySpec[specID][setNumber]
end

function ns.GetRegularBarSetAssignment(
    barID,
    buttonID,
    setNumber
)
    if not ns.db or not ns.db.bars then return nil end

    local settings = ns.db.bars[barID]

    if not settings
        or settings.source ~= "blizzard"
        or barID == 1
    then
        return nil
    end

    local entries =
        RegularSetTable(settings, setNumber, false)

    return entries and entries[buttonID]
end

local function RegularSetAssignment(
    barID,
    buttonID,
    setNumber,
    assignment
)
    if InCombatLockdown() or setNumber == 1 then
        return false
    end

    local settings =
        ns.db and ns.db.bars and ns.db.bars[barID]

    if not settings
        or settings.source ~= "blizzard"
        or barID == 1
    then
        return false
    end

    local entries = RegularSetTable(
        settings, setNumber, true
    )

    if not entries then return false end

    entries[buttonID] = assignment
    return true
end

local function RegularSetCurrent(barID)
    return editingSets[barID]
end

function ns.SetRegularBarEditSet(barID, setNumber)
    if InCombatLockdown() then
        return false, "combat"
    end

    local settings =
        ns.db and ns.db.bars and ns.db.bars[barID]

    if not settings
        or settings.source ~= "blizzard"
        or barID == 1
    then
        return false, "unsupported"
    end

    if setNumber then
        setNumber = tonumber(setNumber)

        if not setNumber
            or setNumber ~= math.floor(setNumber)
            or setNumber < 1
            or setNumber > MAX_SETS
        then
            return false, "invalid"
        end
    end

    editingSets[barID] = setNumber
    ns.UpdateBar(barID)

    return true
end

function ns.SetBarActionSetEditPage(barID, setNumber)
    local settings =
        ns.db and ns.db.bars and ns.db.bars[barID]

    if not settings then
        return false, "unsupported"
    end

    if settings.source == "custom" then
        return ns.SetCustomBarEditPage(barID, setNumber)
    end

    return ns.SetRegularBarEditSet(barID, setNumber)
end

function ns.GetBarActionSetAssignment(
    barID,
    buttonID,
    setNumber
)
    local settings =
        ns.db and ns.db.bars and ns.db.bars[barID]

    if not settings then return nil end

    if settings.source == "custom" then
        return ns.GetCustomBarPageAssignment(
            barID, buttonID, setNumber
        )
    end

    return ns.GetRegularBarSetAssignment(
        barID, buttonID, setNumber
    )
end

local function AssignmentFromCursor()
    local kind, first, second, third = GetCursorInfo()

    if kind == "action" then
        local actionType, id, subtype =
            GetActionInfo(first)

        if actionType == "companion"
            and subtype == "MOUNT"
        then
            id = C_MountJournal.GetMountFromSpell(id)
            actionType = "mount"
        end

        if actionType == "spell"
            or actionType == "macro"
            or actionType == "item"
            or actionType == "flyout"
            or actionType == "mount"
        then
            return id and {
                type = actionType,
                id = id,
            }
        end

        if (actionType == "battlepet"
            or actionType == "summonpet")
            and type(id) == "string"
        then
            return {
                type = "battlepet",
                id = id,
            }
        end
    elseif kind == "spell" then
        local mountID =
            third and C_MountJournal.GetMountFromSpell(third)

        if third then
            return {
                type = mountID and "mount" or "spell",
                id = mountID or third,
            }
        end
    elseif kind == "item"
        or kind == "macro"
        or kind == "flyout"
        or kind == "battlepet"
    then
        return first and {
            type = kind,
            id = first,
        }
    elseif kind == "mount" then
        return first and {
            type = "mount",
            id = first,
            index = second,
        }
    end

    return nil
end

local function PickupSetAssignment(assignment)
    if not assignment or GetCursorInfo() then
        return false
    end

    if assignment.type == "spell" then
        C_Spell.PickupSpell(assignment.id)
    elseif assignment.type == "item" then
        C_Item.PickupItem(assignment.id)
    elseif assignment.type == "macro" then
        PickupMacro(assignment.id)
    elseif assignment.type == "action" then
        PickupAction(assignment.id)
    elseif assignment.type == "battlepet" then
        C_PetJournal.PickupPet(assignment.id)
    elseif assignment.type == "mount" then
        local mountID = assignment.id
        local index = assignment.index

        if index
            and C_MountJournal.GetDisplayedMountID(index) ~= mountID
        then
            index = nil
        end

        if not index then
            for i = 1, C_MountJournal.GetNumDisplayedMounts() do
                if C_MountJournal.GetDisplayedMountID(i) == mountID then
                    index = i
                    break
                end
            end
        end

        if index then
            C_MountJournal.Pickup(index)
        end

        if not GetCursorInfo() then
            local _, spellID =
                C_MountJournal.GetMountInfoByID(mountID)

            if spellID then
                C_Spell.PickupSpell(spellID)
            end
        end
    elseif assignment.type == "flyout" then
        return false
    end

    return GetCursorInfo() ~= nil
end

local function SetSecureValues(assignment)
    if not assignment then return nil end

    if assignment.type == "action" then
        return "action", nil, nil, nil, nil, assignment.id
    elseif assignment.type == "spell" then
        local info = C_Spell.GetSpellInfo(assignment.id)
        return info and "spell" or nil, info and info.name
    elseif assignment.type == "item" then
        return "item", nil, "item:" .. assignment.id
    elseif assignment.type == "macro" then
        return "macro", nil, nil, assignment.id
    elseif assignment.type == "flyout" then
        return "flyout", assignment.id
    elseif assignment.type == "mount" then
        local mountName, spellID =
            C_MountJournal.GetMountInfoByID(assignment.id)

        local info =
            spellID and C_Spell.GetSpellInfo(spellID)

        local name =
            (info and info.name) or mountName

        if name then
            return "macro", nil, nil, nil, "/cast " .. name
        end
    elseif assignment.type == "battlepet" then
        return "macro", nil, nil, nil,
            "/summonpet " .. assignment.id
    end

    return nil
end

local function GetFlyoutSpellbookIcon(flyoutID)
    if not C_SpellBook
        or not C_SpellBook.GetNumSpellBookSkillLines
        or not C_SpellBook.GetSpellBookSkillLineInfo
        or not C_SpellBook.GetSpellBookItemInfo
        or not Enum or not Enum.SpellBookSpellBank
        or not Enum.SpellBookItemType
    then
        return nil
    end

    local bank = Enum.SpellBookSpellBank.Player
    local flyoutType = Enum.SpellBookItemType.Flyout

    for index = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local line = C_SpellBook.GetSpellBookSkillLineInfo(index)

        if line then
            local first = (line.itemIndexOffset or 0) + 1
            local last = first + (line.numSpellBookItems or 0) - 1

            for slot = first, last do
                local info = C_SpellBook.GetSpellBookItemInfo(
                    slot, bank
                )

                if info and info.itemType == flyoutType
                    and info.actionID == flyoutID
                then
                    return info.iconID
                end
            end
        end
    end

    return nil
end

local function GetSetIcon(assignment)
    if not assignment then return nil end

    if assignment.type == "flyout" then
        return GetFlyoutSpellbookIcon(assignment.id) or 134400
    elseif assignment.type == "spell" then
        local info = C_Spell.GetSpellInfo(assignment.id)
        return info and info.iconID
    elseif assignment.type == "item" then
        return C_Item.GetItemIconByID(assignment.id)
    elseif assignment.type == "macro" then
        local _, texture = GetMacroInfo(assignment.id)
        return texture
    elseif assignment.type == "mount" then
        local _, _, texture =
            C_MountJournal.GetMountInfoByID(assignment.id)
        return texture
    elseif assignment.type == "battlepet" then
        local _, _, _, _, _, _, _, _, texture =
            C_PetJournal.GetPetInfoByPetID(assignment.id)
        return texture
    elseif assignment.type == "action" then
        return C_ActionBar.GetActionTexture(assignment.id)
    end

    return 134400
end

local function GetSetSpell(assignment)
    if not assignment then return nil end

    if assignment.type == "spell" then
        return assignment.id
    end

    if assignment.type == "macro" then
        return GetMacroSpell(assignment.id)
    end

    if assignment.type == "mount" then
        local _, id =
            C_MountJournal.GetMountInfoByID(assignment.id)
        return id
    end

    if assignment.type == "action" then
        local kind, id = GetActionInfo(assignment.id)
        if kind == "spell" then return id end
        if kind == "macro" then return GetMacroSpell(id) end
    end
end

local regularSpecEvents = CreateFrame("Frame")
regularSpecEvents:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
regularSpecEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
regularSpecEvents:RegisterEvent("PLAYER_REGEN_ENABLED")

regularSpecEvents:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_SPECIALIZATION_CHANGED"
        and unit ~= "player"
    then
        return
    end

    if InCombatLockdown() then return end

    for button in pairs(regularButtons) do
        if button.ReconfigureActionSets then
            button:ReconfigureActionSets()
        end
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
    button:SetAttribute("checkselfcast", true)
    button:SetAttribute("checkfocuscast", true)
    button:SetAttribute("checkmouseovercast", true)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("useOnKeyDown", false)

    button.ApplyButtonInteraction = function(self)
        if InCombatLockdown() then return end

        local locked, onPress =
            ns.GetButtonInteractionSettings()

        self:SetAttribute(
            "useOnKeyDown",
            onPress and locked and not IsShiftKeyDown()
        )
    end

    ns.InteractionButtons[button] = true
    button:ApplyButtonInteraction()
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(
        nil, "BACKGROUND"
    )
    background:SetAllPoints()
    background:SetColorTexture(
        0.08, 0.08, 0.08, 0.85
    )
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
    count:SetPoint(
        "BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2
    )
    button.Count = count

    local hotKey = button:CreateFontString(
        nil, "OVERLAY", "NumberFontNormalSmall"
    )
    hotKey:SetDrawLayer("OVERLAY", 7)
    hotKey:SetPoint(
        "TOPRIGHT", button, "TOPRIGHT", -2, -2
    )
    hotKey:SetJustifyH("RIGHT")
    hotKey:SetText("")
    button.HotKey = hotKey

    local checked = button:CreateTexture(nil, "OVERLAY")
    checked:SetAllPoints(icon)
    checked:SetColorTexture(
        1, 0.82, 0, 0.25
    )
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
    dragHighlight:SetColorTexture(
        0.15, 0.8, 0.78, 0.32
    )
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
    local basePage =
        math.floor((actionSlot - 1) / BUTTONS_PER_PAGE) + 1
    local currentActionSlot = actionSlot
    local unifiedMode = false
    local activeSet = 1

    local function CurrentSetAssignment()
        if not unifiedMode or activeSet == 1 then
            return nil
        end

        return ns.GetRegularBarSetAssignment(
            parent.barID,
            buttonID,
            activeSet
        )
    end

    local function UsesExtraSet()
        return unifiedMode and activeSet > 1
    end

    local usableState = true
    local resourceState = false
    local outOfRangeState = false
    local UpdateAll

    local function GetPageSlot(page)
        return ((page - 1) * BUTTONS_PER_PAGE) + buttonID
    end

    local function ResolveActionSlot(
        shiftHeld,
        ctrlHeld,
        altHeld
    )
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
        if unifiedMode then
            local slot =
                button:GetAttribute("miab-native-slot")

            if issecretvalue and issecretvalue(slot) then
                return currentActionSlot
            end

            return tonumber(slot) or actionSlot
        end

        if automaticPaging then
            local value = button:GetAttribute("miab-page")

            if issecretvalue and issecretvalue(value) then
                return currentActionSlot
            end

            local page = tonumber(value) or basePage
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
        if not UsesExtraSet()
            and not C_ActionBar.HasAction(currentActionSlot)
        then
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

        if (automaticPaging or unifiedMode)
            and ns.GetButtonKeybind
        then
            key = ns.GetButtonKeybind(
                parent.barID, buttonID, "primary"
            ) or ns.GetButtonKeybind(
                parent.barID, buttonID, "secondary"
            )
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
        local assignment = CurrentSetAssignment()
        local texture

        if UsesExtraSet() then
            texture = GetSetIcon(assignment)
        else
            texture =
                C_ActionBar.GetActionTexture(currentActionSlot)
        end

        if texture then
            icon:SetTexture(texture)
            icon:Show()
        else
            icon:SetTexture(nil)
            icon:Hide()
        end
    end

    ns.InitializeButtonSpellFeedback(button, function()
        if UsesExtraSet() then
            return GetSetSpell(CurrentSetAssignment())
        end

        local kind, id = GetActionInfo(currentActionSlot)

        if kind == "spell" then
            return id
        elseif kind == "macro" then
            return id and GetMacroSpell(id)
        end
    end)

    local function UpdateCooldown()
        if UsesExtraSet() then
            local assignment = CurrentSetAssignment()
            local spellID = GetSetSpell(assignment)

            if spellID then
                ns.SetButtonCooldownDuration(
                    cooldown,
                    C_Spell.GetSpellCooldownDuration(spellID)
                )
                ns.SetButtonCooldownDuration(
                    button.chargeCooldown,
                    C_Spell.GetSpellChargeDuration(spellID, true)
                )
            elseif assignment and assignment.type == "item" then
                local start, duration, enabled =
                    C_Item.GetItemCooldown(assignment.id)

                if enabled and duration and duration > 0 then
                    cooldown:SetCooldown(start, duration)
                else
                    cooldown:Clear()
                end

                button.chargeCooldown:Clear()
            else
                cooldown:Clear()
                button.chargeCooldown:Clear()
            end

            return
        end

        ns.SetButtonCooldownDuration(
            cooldown,
            C_ActionBar.GetActionCooldownDuration(currentActionSlot)
        )
        ns.SetButtonCooldownDuration(
            button.chargeCooldown,
            C_ActionBar.GetActionChargeDuration(currentActionSlot, true)
        )
    end

    local function UpdateCount()
        if UsesExtraSet() then
            local assignment = CurrentSetAssignment()

            if assignment and assignment.type == "macro" then
                local name = GetMacroInfo(assignment.id)
                button.MacroName:SetText(name or "")
            else
                button.MacroName:SetText("")
            end

            if not assignment then
                count:SetText("")
            elseif assignment.type == "item" then
                local quantity =
                    C_Item.GetItemCount(assignment.id)

                count:SetText(
                    quantity and quantity > 1 and quantity or ""
                )
            else
                local spellID = GetSetSpell(assignment)

                count:SetText(
                    spellID
                    and C_Spell.GetSpellDisplayCount(spellID)
                    or ""
                )
            end

            return
        end

        local kind = GetActionInfo(currentActionSlot)

        if kind == "macro" then
            button.MacroName:SetText(
                C_ActionBar.GetActionText(currentActionSlot)
            )
        else
            button.MacroName:SetText("")
        end

        if not C_ActionBar.HasAction(currentActionSlot) then
            count:SetText("")
            return
        end

        count:SetText(
            C_ActionBar.GetActionDisplayCount(currentActionSlot)
        )
    end

    local function UpdateUsability()
        if UsesExtraSet() then
            local assignment = CurrentSetAssignment()
            local spellID = GetSetSpell(assignment)

            if spellID then
                usableState, resourceState =
                    C_Spell.IsSpellUsable(spellID)
            elseif assignment and assignment.type == "item" then
                usableState, resourceState =
                    C_Item.IsUsableItem(assignment.id)
            else
                usableState, resourceState = true, false
            end

            ApplyColor()
            return
        end

        usableState, resourceState =
            C_ActionBar.IsUsableAction(currentActionSlot)
        ApplyColor()
    end

    local function UpdateCheckedState()
        if UsesExtraSet() then
            local assignment = CurrentSetAssignment()

            if assignment and assignment.type == "mount" then
                local _, _, _, active =
                    C_MountJournal.GetMountInfoByID(assignment.id)

                button:SetChecked(active == true)
            elseif assignment and assignment.type == "battlepet" then
                button:SetChecked(
                    C_PetJournal.GetSummonedPetGUID()
                    == assignment.id
                )
            elseif assignment and assignment.type == "action" then
                button:SetChecked(
                    C_ActionBar.IsCurrentAction(assignment.id)
                )
            else
                button:SetChecked(false)
            end

            return
        end

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
        button:UpdateProcGlow()
    end

    button.actionSlot = currentActionSlot

    ns.InitializeButtonFlyout(button, function()
        if UsesExtraSet() then
            local assignment = CurrentSetAssignment()

            if assignment and assignment.type == "action" then
                return GetActionInfo(assignment.id)
            end

            return assignment and assignment.type,
                assignment and assignment.id
        end

        return GetActionInfo(currentActionSlot)
    end)

    button:HookScript("PostClick", function()
        if not InCombatLockdown() then
            local assignment = CurrentSetAssignment()

            local kind = UsesExtraSet()
                and assignment and assignment.type
                or GetActionInfo(currentActionSlot)

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
            button,
            currentActionSlot,
            cooldown
        )
        C_ActionBar.EnableActionRangeCheck(
            currentActionSlot,
            true
        )

        UpdateAll()
    end

    local function SetModifierAttribute(
        attribute,
        shiftHeld,
        ctrlHeld,
        altHeld
    )
        button:SetAttribute(
            attribute,
            ResolveActionSlot(
                shiftHeld,
                ctrlHeld,
                altHeld
            )
        )
    end

    local automaticPageHandler = [[
        local page = tonumber(newstate) or 1
        local slot = (page - 1) * 12
            + self:GetAttribute("miab-button-id")

        self:SetAttribute("miab-native-slot", slot)

        if self:GetAttribute("miab-unified") then
            if (tonumber(self:GetAttribute("miab-set")) or 1) == 1 then
                self:SetAttribute("type", "action")
                self:SetAttribute("action", slot)
            end
        else
            self:SetAttribute("action", slot)
        end

        local clickSlot = slot

        if self:GetAttribute("miab-unified") then
            clickSlot = self:GetAttribute("action")
        end

        self:SetAttribute("shift-action*", clickSlot)
        self:SetAttribute("ctrl-action*", clickSlot)
        self:SetAttribute("alt-action*", clickSlot)
        self:SetAttribute("ctrl-shift-action*", clickSlot)
        self:SetAttribute("alt-shift-action*", clickSlot)
        self:SetAttribute("alt-ctrl-action*", clickSlot)
        self:SetAttribute("alt-ctrl-shift-action*", clickSlot)
        self:SetAttribute("miab-page", page)
    ]]

    local unifiedSetHandler = [[
        local setNumber = tonumber(newstate) or 1

        if setNumber < 1 or setNumber > 12 then
            setNumber = 1
        end

        local previousSet = tonumber(
            self:GetAttribute("miab-currentset")
        ) or 1

        if previousSet ~= setNumber then
            local oldPopup = self:GetFrameRef(
                "miab-flyout-popup-" .. previousSet
            )

            if oldPopup and oldPopup:IsShown() then
                oldPopup:Hide()
            end
        end

        if setNumber == 1 then
            self:SetAttribute("type", "action")
            self:SetAttribute(
                "action",
                self:GetAttribute("miab-native-slot")
            )
            self:SetAttribute("spell", nil)
            self:SetAttribute("item", nil)
            self:SetAttribute("macro", nil)
            self:SetAttribute("macrotext", nil)
        else
            local prefix = "miab-set-" .. setNumber .. "-"

            self:SetAttribute(
                "type",
                self:GetAttribute(prefix .. "type")
            )
            self:SetAttribute(
                "spell",
                self:GetAttribute(prefix .. "spell")
            )
            self:SetAttribute(
                "item",
                self:GetAttribute(prefix .. "item")
            )
            self:SetAttribute(
                "macro",
                self:GetAttribute(prefix .. "macro")
            )
            self:SetAttribute(
                "macrotext",
                self:GetAttribute(prefix .. "macrotext")
            )
            self:SetAttribute(
                "action",
                self:GetAttribute(prefix .. "action")
            )
        end

        local slot = self:GetAttribute("action")

        self:SetAttribute("shift-action*", slot)
        self:SetAttribute("ctrl-action*", slot)
        self:SetAttribute("alt-action*", slot)
        self:SetAttribute("ctrl-shift-action*", slot)
        self:SetAttribute("alt-shift-action*", slot)
        self:SetAttribute("alt-ctrl-action*", slot)
        self:SetAttribute("alt-ctrl-shift-action*", slot)
        self:SetAttribute("miab-currentset", setNumber)

        local arrowFrame = self:GetFrameRef("miab-flyout-arrow")
        if arrowFrame then
            if self:GetAttribute("miab-flyout-set-" .. setNumber) then
                arrowFrame:Show()
            else
                arrowFrame:Hide()
            end
        end

        if self:GetAttribute("miab-layout-visible") == false then
            self:Hide()
        elseif self:GetAttribute("miab-empty-hide")
            and not self:GetAttribute("miab-occupied-" .. setNumber)
        then
            self:Hide()
        else
            self:Show()
        end
    ]]

    local CONDITIONS = {
        stealth = "[stealth]",
        combat = "[combat]",
        nocombat = "[nocombat]",
        friendly = "[@target,help,nodead]",
        hostile = "[@target,harm,nodead]",
        mounted = "[mounted]",
        flying = "[flying]",
        swimming = "[swimming]",
        pet = "[pet]",
        vehicle = "[vehicleui]",
        override = "[overridebar]",
        possess = "[possessbar]",
    }

    local function ConditionToken(name)
        local token = CONDITIONS[name]
        if token then return token end

        if type(name) ~= "string" then
            return nil
        end

        local form = name:match("^form:(%d+)$")

        if form and tonumber(form) >= 1
            and tonumber(form) <= 10
        then
            return "[form:" .. form .. "]"
        end

        return nil
    end

    local function ConfigureAutomaticPaging(pageSettings)
        local isPrimary = parent.barID == 1

        if unifiedMode then
            UnregisterStateDriver(button, "page")

            if isPrimary then
                local native = {
                    "[vehicleui] 1",
                    "[overridebar] 1",
                    "[possessbar] 1",
                }

                for value = 2, 6 do
                    native[#native + 1] =
                        "[bar:" .. value .. "] " .. value
                end

                for value = 1, 4 do
                    native[#native + 1] =
                        "[bonusbar:" .. value .. "] "
                        .. (value + 6)
                end

                native[#native + 1] = "1"

                button:SetAttribute(
                    "_onstate-page",
                    automaticPageHandler
                )
                button:SetAttribute("miab-button-id", buttonID)
                button:SetAttribute("state-page", nil)

                RegisterStateDriver(
                    button,
                    "page",
                    table.concat(native, "; ")
                )
            else
                button:SetAttribute(
                    "miab-native-slot",
                    actionSlot
                )
            end

            return
        end

        local rules = {}
        local context =
            not isPrimary
            and type(pageSettings.contextRules) == "table"
            and pageSettings.contextRules or {}

        for _, rule in ipairs(context) do
            if type(rule) == "table"
                and rule.enabled ~= false
            then
                local targetPage = tonumber(rule.page)
                local condition =
                    ConditionToken(rule.condition)

                if condition
                    and targetPage
                    and targetPage == math.floor(targetPage)
                    and targetPage >= 1
                    and targetPage <= 15
                then
                    rules[#rules + 1] =
                        condition .. " " .. targetPage
                end
            end
        end

        automaticPaging = isPrimary or #rules > 0
        UnregisterStateDriver(button, "page")

        if not automaticPaging then
            button:SetAttribute("miab-page", nil)
            return
        end

        local conditions = {}

        if isPrimary then
            conditions[#conditions + 1] = "[vehicleui] 1"
            conditions[#conditions + 1] = "[overridebar] 1"
            conditions[#conditions + 1] = "[possessbar] 1"
        end

        for _, rule in ipairs(rules) do
            conditions[#conditions + 1] = rule
        end

        for _, modifier in ipairs({
            "alt", "ctrl", "shift"
        }) do
            local entry = modifierPages[modifier]

            if entry.enabled then
                conditions[#conditions + 1] =
                    "[mod:" .. modifier .. "] " .. entry.page
            end
        end

        if isPrimary then
            for actionPage = 2, 6 do
                conditions[#conditions + 1] =
                    "[bar:" .. actionPage .. "] "
                    .. actionPage
            end

            for offset = 1, 4 do
                conditions[#conditions + 1] =
                    "[bonusbar:" .. offset .. "] "
                    .. (offset + 6)
            end
        end

        conditions[#conditions + 1] = tostring(basePage)

        button:SetAttribute(
            "_onstate-page",
            automaticPageHandler
        )
        button:SetAttribute("miab-button-id", buttonID)
        button:SetAttribute("state-page", nil)

        RegisterStateDriver(
            button,
            "page",
            table.concat(conditions, "; ")
        )
    end

    local function ConfigureUnifiedSets(settings)
        if InCombatLockdown() then return end

        local barID = parent.barID
        local parts = {}
        local editing = RegularSetCurrent(barID)

        if editing then
            parts[1] = tostring(editing)
        else
            for _, rule in ipairs(
                settings.contextRules or {}
            ) do
                local target = tonumber(rule.page)
                local condition =
                    ConditionToken(rule.condition)

                if type(rule) == "table"
                    and rule.enabled ~= false
                    and condition
                    and target
                    and target == math.floor(target)
                    and target >= 1
                    and target <= MAX_SETS
                then
                    parts[#parts + 1] =
                        condition .. " " .. target
                end
            end

            for _, modifier in ipairs({
                "alt", "ctrl", "shift"
            }) do
                local entry = modifierPages[modifier]

                if entry.enabled then
                    parts[#parts + 1] =
                        "[mod:" .. modifier .. "] "
                        .. entry.page
                end
            end

            parts[#parts + 1] = "1"
        end

        UnregisterStateDriver(button, "miabset")
        button:SetAttribute("miab-unified", true)

        local barSettings = ns.db.bars[barID]
        button:SetAttribute(
            "miab-layout-visible",
            buttonID <= (tonumber(barSettings.buttonCount) or 12)
        )

        local native =
            button:GetAttribute("miab-native-slot")

        if not native then
            button:SetAttribute(
                "miab-native-slot",
                actionSlot
            )
        end

        for number = 2, MAX_SETS do
            local assignment =
                ns.GetRegularBarSetAssignment(
                    barID, buttonID, number
                )

            local kind, spell, item, macro, macrotext, slot =
                SetSecureValues(assignment)

            local prefix = "miab-set-" .. number .. "-"

            button:SetAttribute(prefix .. "type", kind)
            button:SetAttribute(prefix .. "spell", spell)
            button:SetAttribute(prefix .. "item", item)
            button:SetAttribute(prefix .. "macro", macro)
            button:SetAttribute(
                prefix .. "macrotext",
                macrotext
            )
            button:SetAttribute(prefix .. "action", slot)
        end

        local flyoutsBySet = {}
        local nativeKind, nativeID = GetActionInfo(actionSlot)

        if nativeKind == "flyout" then
            flyoutsBySet[1] = nativeID
        end

        for number = 2, MAX_SETS do
            local assignment = ns.GetRegularBarSetAssignment(
                barID, buttonID, number
            )

            if assignment then
                if assignment.type == "flyout" then
                    flyoutsBySet[number] = assignment.id
                elseif assignment.type == "action" then
                    local actionKind, actionID =
                        GetActionInfo(assignment.id)

                    if actionKind == "flyout" then
                        flyoutsBySet[number] = actionID
                    end
                end
            end
        end

        button:ConfigureActionSetFlyouts(flyoutsBySet)

        button:SetAttribute(
            "_onstate-miabset",
            unifiedSetHandler
        )
        button:SetAttribute("state-miabset", nil)

        RegisterStateDriver(
            button,
            "miabset",
            table.concat(parts, "; ")
        )
    end

    local function ConfigureActionPages(settings)
        if InCombatLockdown() then return false end

        settings = settings or {}
        local barID = parent.barID

        if barID and barID > 1 then
            settings =
                ns.EnsureIndependentRegularBarSets(barID)
                or settings
        end

        unifiedMode = barID ~= 1 and (
            settings.unifiedSets == true
            or RegularSetCurrent(barID) ~= nil
        )

        local shift = settings.shift or {}
        local ctrl = settings.ctrl or {}
        local alt = settings.alt or {}

        modifierPages.shift.enabled =
            parent.barID ~= 1
            and shift.enabled and true or false
        modifierPages.shift.page = math.max(
            1,
            math.min(
                unifiedMode and MAX_SETS or 15,
                tonumber(shift.page) or 2
            )
        )

        modifierPages.ctrl.enabled =
            parent.barID ~= 1
            and ctrl.enabled and true or false
        modifierPages.ctrl.page = math.max(
            1,
            math.min(
                unifiedMode and MAX_SETS or 15,
                tonumber(ctrl.page) or 3
            )
        )

        modifierPages.alt.enabled =
            parent.barID ~= 1
            and alt.enabled and true or false
        modifierPages.alt.page = math.max(
            1,
            math.min(
                unifiedMode and MAX_SETS or 15,
                tonumber(alt.page) or 4
            )
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

        if unifiedMode then
            for _, key in ipairs({
                "shift-action*",
                "ctrl-action*",
                "alt-action*",
                "ctrl-shift-action*",
                "alt-shift-action*",
                "alt-ctrl-action*",
                "alt-ctrl-shift-action*",
            }) do
                button:SetAttribute(key, actionSlot)
            end
        end

        if not unifiedMode then
            UnregisterStateDriver(button, "miabset")
            button:SetAttribute("miab-unified", nil)
            button:SetAttribute("miab-currentset", 1)
            button:ConfigureActionSetFlyouts(nil)
            activeSet = 1
        end

        ConfigureAutomaticPaging(settings)

        if unifiedMode then
            ConfigureUnifiedSets(settings)
        end

        RefreshEffectiveActionSlot()
        UpdateAll()
        return true
    end

    button:HookScript(
        "OnAttributeChanged",
        function(_, attribute, value)
            if unifiedMode
                and attribute == "miab-currentset"
            then
                if issecretvalue and issecretvalue(value) then
                    return
                end

                local nextSet = tonumber(value)

                if nextSet
                    and nextSet >= 1
                    and nextSet <= MAX_SETS
                then
                    activeSet = nextSet
                    UpdateAll()

                    if not InCombatLockdown()
                        and ns.RefreshEmptyButtonVisibility
                    then
                        ns.RefreshEmptyButtonVisibility(parent.barID)
                    end
                end

                return
            end

            if automaticPaging
                and attribute == "miab-page"
                and value
            then
                if issecretvalue and issecretvalue(value) then
                    return
                end

                RefreshEffectiveActionSlot()
            end
        end
    )

    button:SetScript("OnEnter", function(self)
        UpdateDragHighlight()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

        if UsesExtraSet() then
            local assignment = CurrentSetAssignment()
            if not assignment then return end

            if assignment.type == "spell"
                or assignment.type == "mount"
            then
                local id = assignment.id

                if assignment.type == "mount" then
                    local _, spellID =
                        C_MountJournal.GetMountInfoByID(id)
                    id = spellID
                end

                if id then
                    GameTooltip:SetSpellByID(id)
                end
            elseif assignment.type == "item" then
                GameTooltip:SetItemByID(assignment.id)
            elseif assignment.type == "action" then
                GameTooltip:SetAction(assignment.id)
            elseif assignment.type == "macro" then
                local name = GetMacroInfo(assignment.id)
                if name then
                    GameTooltip:SetText(name)
                end
            elseif assignment.type == "flyout" then
                local name =
                    GetFlyoutInfo
                    and GetFlyoutInfo(assignment.id)
                if name then
                    GameTooltip:SetText(name)
                end
            elseif assignment.type == "battlepet" then
                local _, custom, _, _, _, _, _, species =
                    C_PetJournal.GetPetInfoByPetID(
                        assignment.id
                    )
                GameTooltip:SetText(
                    custom or species or "Battle Pet"
                )
            end
        else
            GameTooltip:SetAction(currentActionSlot)
        end

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
            if not InCombatLockdown() then
                if unifiedMode then
                    ConfigureUnifiedSets(
                        ns.db.bars[parent.barID].actionPages
                    )
                end

                UpdateAll()

                if ns.RefreshEmptyButtonVisibility then
                    ns.RefreshEmptyButtonVisibility(parent.barID)
                end
            end
        end)
    end

    local function PutCursorInSet()
        local candidate = AssignmentFromCursor()
        if not candidate then return false end

        local previous = CurrentSetAssignment()
        ClearCursor()

        if previous
            and not PickupSetAssignment(previous)
        then
            PickupSetAssignment(candidate)
            return false
        end

        if not RegularSetAssignment(
            parent.barID,
            buttonID,
            activeSet,
            candidate
        ) then
            ClearCursor()
            PickupSetAssignment(candidate)
            return false
        end

        return true
    end

    button:SetScript("OnDragStart", function()
        if InCombatLockdown() or GetCursorInfo() then
            return
        end

        local locked = ns.GetButtonInteractionSettings()
        if locked and not IsShiftKeyDown() then
            return
        end

        if UsesExtraSet() then
            local current = CurrentSetAssignment()

            if not PickupSetAssignment(current) then
                return
            end

            RegularSetAssignment(
                parent.barID,
                buttonID,
                activeSet,
                nil
            )

            dragged = true
            button:SetAttribute("type", nil)
        else
            dragged = true
            PickupAction(currentActionSlot)
        end

        UpdateDragHighlight()
        RefreshSoon()
    end)

    button:SetScript("OnReceiveDrag", function()
        if InCombatLockdown() or not GetCursorInfo() then
            return
        end

        dragged = true
        placementPending = true

        if UsesExtraSet() then
            PutCursorInSet()
            button:SetAttribute("type", nil)
        else
            C_ActionBar.PutActionInSlot(currentActionSlot)
        end

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
                if UsesExtraSet() then
                    PutCursorInSet()
                else
                    C_ActionBar.PutActionInSlot(
                        currentActionSlot
                    )
                end

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
            if UsesExtraSet() then
                local actionType =
                    SetSecureValues(CurrentSetAssignment())
                self:SetAttribute("type", actionType)
            else
                self:SetAttribute("type", "action")
            end

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
    eventFrame:RegisterEvent("UPDATE_MACROS")
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
    eventFrame:RegisterEvent("ACTION_USABLE_CHANGED")
    eventFrame:RegisterEvent("ACTION_RANGE_CHECK_UPDATE")
    eventFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

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
                outOfRangeState = checksRange and not inRange
                ApplyColor()
            end

            return
        end

        if event == "ACTIONBAR_SLOT_CHANGED" then
            if arg1 ~= 0
                and arg1 ~= currentActionSlot
            then
                return
            end
        end

        if event == "PLAYER_REGEN_ENABLED" then
            RefreshEffectiveActionSlot()
        end

        UpdateAll()
    end)

    C_ActionBar.RegisterActionUIButton(
        button,
        currentActionSlot,
        cooldown
    )
    C_ActionBar.EnableActionRangeCheck(
        currentActionSlot,
        true
    )

    button.UpdateAll = UpdateAll
    button.RefreshVisualState = ApplyColor
    button.RefreshKeybindText = RefreshKeybindText
    button.ConfigureActionPages = ConfigureActionPages

    button.ReconfigureActionSets = function()
        local settings =
            ns.db and ns.db.bars
            and ns.db.bars[parent.barID]

        if settings then
            ConfigureActionPages(settings.actionPages)
        end
    end

    regularButtons[button] = true

    button.GetCurrentActionSlot = function()
        return currentActionSlot
    end

    button.GetCurrentActionSet = function()
        return unifiedMode and activeSet or nil
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
