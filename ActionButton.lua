local addonName, ns = ...

local BUTTON_SIZE = 36
local BUTTONS_PER_PAGE = 12

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
            "SecureActionButtonTemplate"
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

    if GetCVarBool(
        "ActionButtonUseKeyDown"
    ) then
        button:RegisterForClicks(
            "AnyDown"
        )
    else
        button:RegisterForClicks(
            "AnyUp"
        )
    end

    button:RegisterForDrag(
        "LeftButton"
    )

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
        )
            + buttonID
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
            ns.db.bars[
                barID
            ]

        if not settings then
            return nil
        end

        return settings.appearance
    end

    local function RefreshKeybindText()
        if not ns.GetDisplayKeybindForActionSlot
            or not ns.FormatKeybind
        then
            hotKey:SetText("")
            return
        end

        local key =
            ns.GetDisplayKeybindForActionSlot(
                currentActionSlot
            )

        hotKey:SetText(
            ns.FormatKeybind(
                key
            )
        )
    end

    local function ApplyColor()
        local appearance =
            GetAppearance()

        local rangeColoring =
            not appearance
            or appearance.rangeColoring
                ~= false

        local usabilityColoring =
            not appearance
            or appearance.usabilityColoring
                ~= false

        local desaturateUnusable =
            appearance
            and appearance.desaturateUnusable
                == true

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
            icon:SetTexture(
                texture
            )

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
            button:SetChecked(
                false
            )

            return
        end

        button:SetChecked(
            C_ActionBar.IsCurrentAction(
                currentActionSlot
            )
        )
    end

    UpdateAll =
        function()
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

        if newSlot
            == currentActionSlot
        then
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

    local function ConfigureActionPages(
        settings
    )
        if InCombatLockdown() then
            return false
        end

        settings =
            settings or {}

        local shift =
            settings.shift
            or {}

        local ctrl =
            settings.ctrl
            or {}

        local alt =
            settings.alt
            or {}

        modifierPages.shift.enabled =
            shift.enabled
            and true
            or false

        modifierPages.shift.page =
            math.max(
                1,
                math.min(
                    15,
                    tonumber(
                        shift.page
                    )
                        or 2
                )
            )

        modifierPages.ctrl.enabled =
            ctrl.enabled
            and true
            or false

        modifierPages.ctrl.page =
            math.max(
                1,
                math.min(
                    15,
                    tonumber(
                        ctrl.page
                    )
                        or 3
                )
            )

        modifierPages.alt.enabled =
            alt.enabled
            and true
            or false

        modifierPages.alt.page =
            math.max(
                1,
                math.min(
                    15,
                    tonumber(
                        alt.page
                    )
                        or 4
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

        RefreshEffectiveActionSlot()

        return true
    end

    button:SetScript(
        "OnEnter",
        function(self)
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
            GameTooltip:Hide()
        end
    )

    button:SetScript(
        "OnDragStart",
        function()
            if InCombatLockdown() then
                return
            end

            PickupAction(
                currentActionSlot
            )
        end
    )

    button:SetScript(
        "OnReceiveDrag",
        function()
            if InCombatLockdown() then
                return
            end

            C_ActionBar.PutActionInSlot(
                currentActionSlot
            )
        end
    )

    button:HookScript(
        "OnClick",
        function()
            UpdateCheckedState()
        end
    )

    local eventFrame =
        CreateFrame(
            "Frame"
        )

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
                    arg1

                for _, change in ipairs(
                    changes
                ) do
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
                    and arg1
                        ~= currentActionSlot
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
                text
                or ""
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