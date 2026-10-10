
local addonName, ns = ...

local BUTTON_SIZE = 36
local BUTTONS_PER_PAGE = 12

-- Shared interaction registry for regular and custom buttons.
ns.InteractionButtons = ns.InteractionButtons or {}

-- Both regular and custom buttons use the same profile settings.
function ns.GetButtonInteractionSettings()
    local settings = ns.db and ns.db.buttonInteraction

    local locked = not settings
        or settings.lockContents ~= false

    local onPress = settings
        and settings.activateOnPress == true
        or false

    return locked, onPress
end

function ns.RefreshButtonInteraction()
    if InCombatLockdown() then
        return
    end

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

ns.DragHighlightState =
    ns.DragHighlightState
    or {
        activeButton = nil,
    }

function ns.SetDragHighlight(
    button,
    shown
)
    local state =
        ns.DragHighlightState

    if shown then
        local previous =
            state.activeButton

        if previous
            and previous ~= button
            and previous.DragHighlight
        then
            previous.DragHighlight:Hide()
        end

        if button
            and button.DragHighlight
        then
            button.DragHighlight:Show()
            state.activeButton = button
        end

        return
    end

    if button
        and button.DragHighlight
    then
        button.DragHighlight:Hide()
    end

    if state.activeButton == button then
        state.activeButton = nil
    end
end

function ns.ClearDragHighlight()
    local state =
        ns.DragHighlightState

    local button =
        state.activeButton

    if button
        and button.DragHighlight
    then
        button.DragHighlight:Hide()
    end

    state.activeButton = nil
end

local dragCursorFrame =
    CreateFrame("Frame")

dragCursorFrame:RegisterEvent(
    "CURSOR_CHANGED"
)

dragCursorFrame:SetScript(
    "OnEvent",
    function()
        local cursorType = GetCursorInfo()

        if not cursorType then
            ns.ClearDragHighlight()
        end
    end
)

function ns.CreateActionButton(
    parent,
    name,
    actionSlot
)
    local button =
        CreateFrame(
            "CheckButton",
            name,
            parent,
            "SecureActionButtonTemplate,SecureHandlerStateTemplate"
        )

    button:SetSize(
        BUTTON_SIZE,
        BUTTON_SIZE
    )

    button:SetAttribute(
        "type",
        "action"
    )

    button:SetAttribute(
        "action",
        actionSlot
    )

    button:SetAttribute(
        "useOnKeyDown",
        false
    )

    button:RegisterForClicks(
        "AnyDown",
        "AnyUp"
    )

    button:RegisterForDrag(
        "LeftButton"
    )

    function button:ApplyButtonInteraction()
        if InCombatLockdown() then
            return
        end

        local locked, onPress =
            ns.GetButtonInteractionSettings()

        -- Dragging cannot be distinguished from a normal click
        -- before WoW reaches its drag threshold.
        --
        -- When unlocked, we execute on release even if press
        -- activation was requested.
        --
        -- When locked and Shift is held, use release activation
        -- to allow safe Shift-dragging.

        local useDown =
            onPress
            and locked
            and not IsShiftKeyDown()

        self:SetAttribute(
            "useOnKeyDown",
            useDown
        )
    end

    ns.InteractionButtons[button] = true
    button:ApplyButtonInteraction()

    local background =
        button:CreateTexture(
            nil,
            "BACKGROUND"
        )

    background:SetAllPoints()

    background:SetColorTexture(
        0.08,
        0.08,
        0.08,
        0.85
    )

    button.Background =
        background

    local icon =
        button:CreateTexture(
            nil,
            "ARTWORK"
        )

    icon:SetPoint(
        "TOPLEFT",
        2,
        -2
    )

    icon:SetPoint(
        "BOTTOMRIGHT",
        -2,
        2
    )

    button.icon =
        icon

    local cooldown =
        CreateFrame(
            "Cooldown",
            nil,
            button,
            "CooldownFrameTemplate"
        )

    cooldown:SetAllPoints(
        icon
    )

    button.cooldown =
        cooldown

    local count =
        button:CreateFontString(
            nil,
            "OVERLAY",
            "NumberFontNormal"
        )

    count:SetPoint(
        "BOTTOMRIGHT",
        button,
        "BOTTOMRIGHT",
        -2,
        2
    )

    button.Count =
        count

    local hotKey =
        button:CreateFontString(
            nil,
            "OVERLAY",
            "NumberFontNormalSmall"
        )

    hotKey:SetDrawLayer(
        "OVERLAY",
        7
    )

    hotKey:SetPoint(
        "TOPRIGHT",
        button,
        "TOPRIGHT",
        -2,
        -2
    )

    hotKey:SetJustifyH(
        "RIGHT"
    )

    hotKey:SetText("")

    button.HotKey =
        hotKey

    local checked =
        button:CreateTexture(
            nil,
            "OVERLAY"
        )

    checked:SetAllPoints(
        icon
    )

    checked:SetColorTexture(
        1,
        0.82,
        0,
        0.25
    )

    button:SetCheckedTexture(
        checked
    )

    local border =
        button:CreateTexture(
            nil,
            "OVERLAY"
        )

    border:SetAllPoints()

    border:SetAtlas(
        "UI-HUD-ActionBar-IconFrame"
    )

    button.Border =
        border

    local dragHighlight =
        button:CreateTexture(
            nil,
            "OVERLAY",
            nil,
            6
        )

    dragHighlight:SetPoint(
        "TOPLEFT",
        button,
        "TOPLEFT",
        2,
        -2
    )

    dragHighlight:SetPoint(
        "BOTTOMRIGHT",
        button,
        "BOTTOMRIGHT",
        -2,
        2
    )

    dragHighlight:SetColorTexture(
        0.15,
        0.8,
        0.78,
        0.32
    )

    dragHighlight:Hide()

    button.DragHighlight =
        dragHighlight

    local function UpdateDragHighlight()
        if InCombatLockdown() then
            ns.SetDragHighlight(
                button,
                false
            )
            return
        end

        local cursorType =
            GetCursorInfo()

        local validCursor =
            cursorType == "spell"
            or cursorType == "item"
            or cursorType == "macro"
            or cursorType == "action"
            or cursorType == "mount"
            or cursorType == "battlepet"

        ns.SetDragHighlight(
            button,
            validCursor
        )
    end

    local buttonID =
        ((actionSlot - 1)
            % BUTTONS_PER_PAGE)
        + 1

    local modifierPages = {
        shift = {
            enabled = false,
            page = 2,
        },

        ctrl = {
            enabled = false,
            page = 3,
        },

        alt = {
            enabled = false,
            page = 4,
        },
    }

    local automaticPaging =
        parent.barID == 1

    local currentActionSlot =
        actionSlot

    local usableState = true
    local resourceState = false
    local outOfRangeState = false

    local UpdateAll

    local function GetPageSlot(
        page
    )
        return (
            (page - 1)
            * BUTTONS_PER_PAGE
        ) + buttonID
    end

    local function ResolveActionSlot(
        shiftHeld,
        ctrlHeld,
        altHeld
    )
        if altHeld
            and modifierPages.alt.enabled
        then
            return GetPageSlot(
                modifierPages.alt.page
            )
        end

        if ctrlHeld
            and modifierPages.ctrl.enabled
        then
            return GetPageSlot(
                modifierPages.ctrl.page
            )
        end

        if shiftHeld
            and modifierPages.shift.enabled
        then
            return GetPageSlot(
                modifierPages.shift.page
            )
        end

        return actionSlot
    end

    local function GetEffectiveActionSlot()
        if automaticPaging then
            local page = tonumber(
                button:GetAttribute(
                    "miab-page"
                )
            ) or 1

            return GetPageSlot(page)
        end

        return ResolveActionSlot(
            IsShiftKeyDown(),
            IsControlKeyDown(),
            IsAltKeyDown()
        )
    end

    local function GetAppearance()
        local barID =
            parent.barID

        if not barID
            or not ns.db
            or not ns.db.bars
        then
            return nil
        end

        local settings =
            ns.db.bars[barID]

        if not settings then
            return nil
        end

        return settings.appearance
    end

    local function RefreshKeybindText()
        if not C_ActionBar.HasAction(
            currentActionSlot
        ) then
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

        if automaticPaging
            and ns.GetButtonKeybind
        then
            key = ns.GetButtonKeybind(
                1,
                buttonID,
                "primary"
            ) or ns.GetButtonKeybind(
                1,
                buttonID,
                "secondary"
            )
        else
            key =
                ns.GetDisplayKeybindForActionSlot(
                    currentActionSlot
                )
        end

        hotKey:SetText(
            ns.FormatKeybind(key)
        )
    end

    local function ApplyColor()
        local appearance =
            GetAppearance()

        local rangeColoring =
            not appearance
            or appearance.rangeColoring ~= false

        local usabilityColoring =
            not appearance
            or appearance.usabilityColoring ~= false

        local desaturateUnusable =
            appearance
            and appearance.desaturateUnusable == true

        if rangeColoring
            and outOfRangeState
        then
            icon:SetVertexColor(
                1,
                0.25,
                0.25
            )

        elseif usabilityColoring then
            if usableState then
                icon:SetVertexColor(
                    1,
                    1,
                    1
                )

            elseif resourceState then
                icon:SetVertexColor(
                    0.5,
                    0.5,
                    1
                )

            else
                icon:SetVertexColor(
                    0.4,
                    0.4,
                    0.4
                )
            end

        else
            icon:SetVertexColor(
                1,
                1,
                1
            )
        end

        if icon.SetDesaturated then
            icon:SetDesaturated(
                desaturateUnusable
                    and not usableState
            )
        end
    end

    local function UpdateIcon()
        local texture =
            C_ActionBar.GetActionTexture(
                currentActionSlot
            )

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

        cooldown:SetCooldownFromDurationObject(
            duration
        )
    end

    local function UpdateCount()
        if not C_ActionBar.HasAction(
            currentActionSlot
        ) then
            count:SetText("")
            return
        end

        count:SetText(
            C_ActionBar.GetActionDisplayCount(
                currentActionSlot
            )
        )
    end

    local function UpdateUsability()
        local usable,
            lackingResources =
            C_ActionBar.IsUsableAction(
                currentActionSlot
            )

        usableState =
            usable

        resourceState =
            lackingResources

        ApplyColor()
    end

    local function UpdateCheckedState()
        if not C_ActionBar.HasAction(
            currentActionSlot
        ) then
            button:SetChecked(false)
            return
        end

        button:SetChecked(
            C_ActionBar.IsCurrentAction(
                currentActionSlot
            )
        )
    end

    UpdateAll = function()
        UpdateIcon()
        UpdateCooldown()
        UpdateCount()
        UpdateUsability()
        UpdateCheckedState()
        RefreshKeybindText()
    end

    local function RefreshEffectiveActionSlot()
        local newSlot =
            GetEffectiveActionSlot()

        if newSlot == currentActionSlot then
            RefreshKeybindText()
            return
        end

        currentActionSlot =
            newSlot

        button.actionSlot =
            currentActionSlot

        outOfRangeState =
            false

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

    -- These attributes are changed only by the restricted
    -- state handler in combat.
    -- All click modifier combinations follow the same page.

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
        if not automaticPaging then
            return
        end

        local conditions = {
            "[vehicleui] 1",
            "[overridebar] 1",
            "[possessbar] 1",
        }

        for _, modifier in ipairs({
            "alt",
            "ctrl",
            "shift",
        }) do
            local entry =
                modifierPages[modifier]

            if entry.enabled then
                conditions[#conditions + 1] =
                    "[mod:"
                    .. modifier
                    .. "] "
                    .. entry.page
            end
        end

        for page = 2, 6 do
            conditions[#conditions + 1] =
                "[bar:"
                .. page
                .. "] "
                .. page
        end

        -- Bonus offsets 1-4 are class/form/stealth
        -- pages 7-10. Offset 5 stays with Blizzard.

        for offset = 1, 4 do
            conditions[#conditions + 1] =
                "[bonusbar:"
                .. offset
                .. "] "
                .. (offset + 6)
        end

        conditions[#conditions + 1] =
            "1"

        UnregisterStateDriver(
            button,
            "page"
        )

        button:SetAttribute(
            "_onstate-page",
            automaticPageHandler
        )

        button:SetAttribute(
            "miab-button-id",
            buttonID
        )

        button:SetAttribute(
            "state-page",
            nil
        )

        RegisterStateDriver(
            button,
            "page",
            table.concat(
                conditions,
                "; "
            )
        )
    end

    local function ConfigureActionPages(
        settings
    )
        if InCombatLockdown() then
            return false
        end

        settings =
            settings or {}

        local shift =
            settings.shift or {}

        local ctrl =
            settings.ctrl or {}

        local alt =
            settings.alt or {}

        modifierPages.shift.enabled =
            shift.enabled and true or false

        modifierPages.shift.page =
            math.max(
                1,
                math.min(
                    15,
                    tonumber(shift.page) or 2
                )
            )

        modifierPages.ctrl.enabled =
            ctrl.enabled and true or false

        modifierPages.ctrl.page =
            math.max(
                1,
                math.min(
                    15,
                    tonumber(ctrl.page) or 3
                )
            )

        modifierPages.alt.enabled =
            alt.enabled and true or false

        modifierPages.alt.page =
            math.max(
                1,
                math.min(
                    15,
                    tonumber(alt.page) or 4
                )
            )

        button:SetAttribute(
            "action",
            actionSlot
        )

        SetModifierAttribute(
            "shift-action*",
            true,
            false,
            false
        )

        SetModifierAttribute(
            "ctrl-action*",
            false,
            true,
            false
        )

        SetModifierAttribute(
            "alt-action*",
            false,
            false,
            true
        )

        SetModifierAttribute(
            "ctrl-shift-action*",
            true,
            true,
            false
        )

        SetModifierAttribute(
            "alt-shift-action*",
            true,
            false,
            true
        )

        SetModifierAttribute(
            "alt-ctrl-action*",
            false,
            true,
            true
        )

        SetModifierAttribute(
            "alt-ctrl-shift-action*",
            true,
            true,
            true
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

    button:SetScript(
        "OnEnter",
        function(self)
            UpdateDragHighlight()

            GameTooltip:SetOwner(
                self,
                "ANCHOR_RIGHT"
            )

            GameTooltip:SetAction(
                currentActionSlot
            )

            GameTooltip:Show()
        end
    )

    button:SetScript(
        "OnLeave",
        function()
            ns.SetDragHighlight(
                button,
                false
            )

            GameTooltip:Hide()
        end
    )

    -- Interaction state is deliberately separate from paging.
    -- Page changes continue to own the secure action attribute.

    local dragged = false
    local placementPending = false
    local dropHandled = false

    local function RefreshAfterInteraction()
        C_Timer.After(0, function()
            UpdateAll()
        end)
    end

    button:SetScript(
        "OnDragStart",
        function()
            if InCombatLockdown()
                or GetCursorInfo()
            then
                return
            end

            local locked =
                ns.GetButtonInteractionSettings()

            if locked
                and not IsShiftKeyDown()
            then
                return
            end

            PickupAction(
                currentActionSlot
            )

            if GetCursorInfo() then
                dragged = true

                UpdateDragHighlight()
                RefreshAfterInteraction()
            end
        end
    )

    button:SetScript(
        "OnReceiveDrag",
        function()
            if InCombatLockdown()
                or not GetCursorInfo()
            then
                return
            end

            -- A drag-drop is handled once here.
            -- Its trailing mouse release must not place again.

            placementPending = true
            dropHandled = true

            C_ActionBar.PutActionInSlot(
                currentActionSlot
            )

            ns.SetDragHighlight(
                button,
                false
            )

            RefreshAfterInteraction()
        end
    )

    button:HookScript(
        "PreClick",
        function(self, mouseButton, down)
            if InCombatLockdown() then
                return
            end

            if down then
                dragged = false
                dropHandled = false
                placementPending =
                    GetCursorInfo() ~= nil
            end

            if dragged
                or dropHandled
                or placementPending
            then
                self:SetAttribute(
                    "type",
                    nil
                )

                if not down
                    and not dragged
                    and not dropHandled
                    and GetCursorInfo()
                then
                    C_ActionBar.PutActionInSlot(
                        currentActionSlot
                    )

                    ns.ClearDragHighlight()
                    RefreshAfterInteraction()
                end

                return
            end

            if GetCursorInfo() then
                -- Cursor content may have arrived from outside
                -- this button's mouse-down event.

                self:SetAttribute(
                    "type",
                    nil
                )

                placementPending = true

                if not down then
                    C_ActionBar.PutActionInSlot(
                        currentActionSlot
                    )

                    ns.ClearDragHighlight()
                    RefreshAfterInteraction()
                end
            end
        end
    )

    button:HookScript(
        "PostClick",
        function(self, mouseButton, down)
            if not InCombatLockdown() then
                -- Only restore the type. Restoring the action
                -- attribute would overwrite secure paging.

                self:SetAttribute(
                    "type",
                    "action"
                )

                if not down then
                    dragged = false
                    placementPending = false
                    dropHandled = false
                end
            end

            UpdateCheckedState()
        end
    )

    local eventFrame =
        CreateFrame("Frame")

    eventFrame:RegisterEvent(
        "PLAYER_LOGIN"
    )

    eventFrame:RegisterEvent(
        "ACTIONBAR_SLOT_CHANGED"
    )

    eventFrame:RegisterEvent(
        "ACTIONBAR_UPDATE_COOLDOWN"
    )

    eventFrame:RegisterEvent(
        "ACTIONBAR_UPDATE_STATE"
    )

    eventFrame:RegisterEvent(
        "SPELL_UPDATE_COOLDOWN"
    )

    eventFrame:RegisterEvent(
        "SPELL_UPDATE_CHARGES"
    )

    eventFrame:RegisterEvent(
        "ACTION_USABLE_CHANGED"
    )

    eventFrame:RegisterEvent(
        "ACTION_RANGE_CHECK_UPDATE"
    )

    eventFrame:RegisterEvent(
        "MODIFIER_STATE_CHANGED"
    )

    eventFrame:SetScript(
        "OnEvent",
        function(
            _,
            event,
            arg1,
            arg2,
            arg3
        )
            if event
                == "MODIFIER_STATE_CHANGED"
            then
                RefreshEffectiveActionSlot()
                return
            end

            if event
                == "ACTION_USABLE_CHANGED"
            then
                local changes =
                    arg1 or {}

                for _, change in ipairs(changes) do
                    if change.slot
                        == currentActionSlot
                    then
                        usableState =
                            change.usable

                        resourceState =
                            change.noMana

                        ApplyColor()
                    end
                end

                return
            end

            if event
                == "ACTION_RANGE_CHECK_UPDATE"
            then
                local action =
                    arg1

                local inRange =
                    arg2

                local checksRange =
                    arg3

                if action
                    == currentActionSlot
                then
                    outOfRangeState =
                        checksRange
                        and not inRange

                    ApplyColor()
                end

                return
            end

            if event
                == "ACTIONBAR_SLOT_CHANGED"
            then
                if arg1 ~= 0
                    and arg1 ~= currentActionSlot
                then
                    return
                end
            end

            UpdateAll()
        end
    )

    C_ActionBar.RegisterActionUIButton(
        button,
        currentActionSlot,
        cooldown
    )

    C_ActionBar.EnableActionRangeCheck(
        currentActionSlot,
        true
    )

    button.UpdateAll =
        UpdateAll

    button.RefreshVisualState =
        ApplyColor

    button.RefreshKeybindText =
        RefreshKeybindText

    button.ConfigureActionPages =
        ConfigureActionPages

    button.GetCurrentActionSlot =
        function()
            return currentActionSlot
        end

    button.SetKeybindText =
        function(text)
            hotKey:SetText(
                text or ""
            )
        end

    button.baseActionSlot =
        actionSlot

    button.actionSlot =
        currentActionSlot

    button.eventFrame =
        eventFrame

    UpdateAll()

    return button
end
