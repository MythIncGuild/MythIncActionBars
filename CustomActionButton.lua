local addonName, ns = ...

local function GetAssignment(
    barID,
    buttonID
)
    local settings =
        ns.db.bars[barID]

    settings.assignments =
        settings.assignments
        or {}

    return settings.assignments[
        buttonID
    ]
end

local function SetAssignment(
    barID,
    buttonID,
    assignment
)
    local settings =
        ns.db.bars[barID]

    settings.assignments =
        settings.assignments
        or {}

    settings.assignments[
        buttonID
    ] =
        assignment
end

local function GetAppearance(
    barID
)
    local settings =
        ns.db
        and ns.db.bars
        and ns.db.bars[barID]

    if not settings then
        return nil
    end

    return settings.appearance
end

local function GetAssignmentIcon(
    assignment
)
    if not assignment then
        return nil
    end

    if assignment.type
        == "spell"
    then
        local info =
            C_Spell.GetSpellInfo(
                assignment.id
            )

        return info
            and info.iconID
    end

    if assignment.type
        == "item"
    then
        return C_Item.GetItemIconByID(
            assignment.id
        )
    end

    if assignment.type
        == "macro"
    then
        local _, icon =
            GetMacroInfo(
                assignment.id
            )

        return icon
    end

    return nil
end

local function GetAssignmentSpellID(
    assignment
)
    if not assignment then
        return nil
    end

    if assignment.type
        == "spell"
    then
        return assignment.id
    end

    if assignment.type
        == "macro"
    then
        return GetMacroSpell(
            assignment.id
        )
    end

    return nil
end

local function ApplySecureAssignment(
    button,
    assignment
)
    button:SetAttribute(
        "type",
        nil
    )

    button:SetAttribute(
        "spell",
        nil
    )

    button:SetAttribute(
        "item",
        nil
    )

    button:SetAttribute(
        "macro",
        nil
    )

    if not assignment then
        return
    end

    if assignment.type
        == "spell"
    then
        button:SetAttribute(
            "type",
            "spell"
        )

        button:SetAttribute(
            "spell",
            assignment.id
        )

        return
    end

    if assignment.type
        == "item"
    then
        button:SetAttribute(
            "type",
            "item"
        )

        button:SetAttribute(
            "item",
            "item:"
                .. assignment.id
        )

        return
    end

    if assignment.type
        == "macro"
    then
        button:SetAttribute(
            "type",
            "macro"
        )

        button:SetAttribute(
            "macro",
            assignment.id
        )
    end
end

function ns.CreateCustomActionButton(
    parent,
    name,
    barID,
    buttonID
)
    local button =
        CreateFrame(
            "CheckButton",
            name,
            parent,
            "SecureActionButtonTemplate"
        )

    button:SetSize(
        36,
        36
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

    hotKey:SetPoint(
        "TOPRIGHT",
        button,
        "TOPRIGHT",
        -3,
        -3
    )

    hotKey:SetJustifyH(
        "RIGHT"
    )

    hotKey:SetText(
        ""
    )

    button.HotKey =
        hotKey

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

    local usableState = true
    local resourceState = false
    local outOfRangeState = false

    local function ApplyColor()
        local appearance =
            GetAppearance(
                barID
            )

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
        local assignment =
            GetAssignment(
                barID,
                buttonID
            )

        local texture =
            GetAssignmentIcon(
                assignment
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
        local assignment =
            GetAssignment(
                barID,
                buttonID
            )

        if not assignment then
            cooldown:Clear()
            return
        end

        if assignment.type
            == "spell"
        then
            local duration =
                C_Spell.GetSpellCooldownDuration(
                    assignment.id
                )

            if duration then
                cooldown:SetCooldownFromDurationObject(
                    duration
                )
            else
                cooldown:Clear()
            end

            return
        end

        if assignment.type
            == "item"
        then
            local start,
                duration,
                enable =
                C_Item.GetItemCooldown(
                    assignment.id
                )

            if enable
                and enable ~= 0
                and duration
                and duration > 0
            then
                cooldown:SetCooldown(
                    start,
                    duration
                )
            else
                cooldown:Clear()
            end

            return
        end

        if assignment.type
            == "macro"
        then
            local spellID =
                GetMacroSpell(
                    assignment.id
                )

            if spellID then
                local duration =
                    C_Spell.GetSpellCooldownDuration(
                        spellID
                    )

                if duration then
                    cooldown:SetCooldownFromDurationObject(
                        duration
                    )
                else
                    cooldown:Clear()
                end
            else
                cooldown:Clear()
            end
        end
    end

    local function UpdateCount()
        local assignment =
            GetAssignment(
                barID,
                buttonID
            )

        if not assignment then
            count:SetText("")
            return
        end

        if assignment.type
            == "item"
        then
            local quantity =
                C_Item.GetItemCount(
                    assignment.id
                )

            if quantity
                and quantity > 1
            then
                count:SetText(
                    quantity
                )
            else
                count:SetText("")
            end

            return
        end

        count:SetText("")
    end

    local function UpdateUsability()
        local assignment =
            GetAssignment(
                barID,
                buttonID
            )

        if not assignment then
            usableState = true
            resourceState = false
            ApplyColor()
            return
        end

        local spellID =
            GetAssignmentSpellID(
                assignment
            )

        if spellID then
            local usable,
                insufficientPower =
                C_Spell.IsSpellUsable(
                    spellID
                )

            usableState =
                usable

            resourceState =
                insufficientPower

            ApplyColor()
            return
        end

        if assignment.type
            == "item"
        then
            local usable,
                insufficientPower =
                C_Item.IsUsableItem(
                    assignment.id
                )

            usableState =
                usable

            resourceState =
                insufficientPower

            ApplyColor()
            return
        end

        usableState = true
        resourceState = false

        ApplyColor()
    end

    local function UpdateRange()
        local assignment =
            GetAssignment(
                barID,
                buttonID
            )

        if not assignment then
            outOfRangeState = false
            ApplyColor()
            return
        end

        local spellID =
            GetAssignmentSpellID(
                assignment
            )

        if spellID then
            local inRange =
                C_Spell.IsSpellInRange(
                    spellID
                )

            outOfRangeState =
                inRange == false

            ApplyColor()
            return
        end

        if assignment.type
            == "item"
        then
            if InCombatLockdown() then
                outOfRangeState = false
                ApplyColor()
                return
            end

            if C_Item.ItemHasRange
                and C_Item.ItemHasRange(
                    assignment.id
                )
            then
                local inRange =
                    C_Item.IsItemInRange(
                        assignment.id,
                        "target"
                    )

                outOfRangeState =
                    inRange == false
            else
                outOfRangeState =
                    false
            end

            ApplyColor()
            return
        end

        outOfRangeState = false

        ApplyColor()
    end

    local function UpdateVisualState()
        UpdateUsability()
        UpdateRange()
    end

    local function UpdateAssignment()
        if InCombatLockdown() then
            return
        end

        local assignment =
            GetAssignment(
                barID,
                buttonID
            )

        ApplySecureAssignment(
            button,
            assignment
        )

        UpdateIcon()
        UpdateCooldown()
        UpdateCount()
        UpdateVisualState()
    end

    local function AssignFromCursor()
        if InCombatLockdown() then
            return
        end

        local cursorType,
            info1,
            info2,
            info3 =
            GetCursorInfo()

        if cursorType
            == "spell"
        then
            SetAssignment(
                barID,
                buttonID,
                {
                    type = "spell",
                    id = info3,
                }
            )

        elseif cursorType
            == "item"
        then
            SetAssignment(
                barID,
                buttonID,
                {
                    type = "item",
                    id = info1,
                }
            )

        elseif cursorType
            == "macro"
        then
            SetAssignment(
                barID,
                buttonID,
                {
                    type = "macro",
                    id = info1,
                }
            )

        else
            return
        end

        ClearCursor()

        UpdateAssignment()
    end

    button:SetScript(
        "OnReceiveDrag",
        function()
            AssignFromCursor()
        end
    )

    button:SetScript(
        "OnDragStart",
        function()
            if InCombatLockdown() then
                return
            end

            local assignment =
                GetAssignment(
                    barID,
                    buttonID
                )

            if not assignment then
                return
            end

            if assignment.type
                == "spell"
            then
                C_Spell.PickupSpell(
                    assignment.id
                )

            elseif assignment.type
                == "item"
            then
                C_Item.PickupItem(
                    assignment.id
                )

            elseif assignment.type
                == "macro"
            then
                PickupMacro(
                    assignment.id
                )
            end

            SetAssignment(
                barID,
                buttonID,
                nil
            )

            UpdateAssignment()
        end
    )

    button:SetScript(
        "OnEnter",
        function(self)
            local assignment =
                GetAssignment(
                    barID,
                    buttonID
                )

            if not assignment then
                return
            end

            GameTooltip:SetOwner(
                self,
                "ANCHOR_RIGHT"
            )

            if assignment.type
                == "spell"
            then
                GameTooltip:SetSpellByID(
                    assignment.id
                )

            elseif assignment.type
                == "item"
            then
                GameTooltip:SetItemByID(
                    assignment.id
                )

            elseif assignment.type
                == "macro"
            then
                local macroName =
                    GetMacroInfo(
                        assignment.id
                    )

                if macroName then
                    GameTooltip:SetText(
                        macroName
                    )
                end
            end

            GameTooltip:Show()
        end
    )

    button:SetScript(
        "OnLeave",
        function()
            GameTooltip:Hide()
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
        "PLAYER_TARGET_CHANGED"
    )

    eventFrame:RegisterEvent(
        "SPELL_UPDATE_COOLDOWN"
    )

    eventFrame:RegisterEvent(
        "SPELL_UPDATE_CHARGES"
    )

    eventFrame:RegisterEvent(
        "BAG_UPDATE_COOLDOWN"
    )

    eventFrame:RegisterEvent(
        "BAG_UPDATE_DELAYED"
    )

    eventFrame:RegisterEvent(
        "UPDATE_MACROS"
    )

    eventFrame:SetScript(
        "OnEvent",
        function(
            _,
            event
        )
            if event
                == "UPDATE_MACROS"
            then
                UpdateAssignment()
                return
            end

            UpdateIcon()
            UpdateCooldown()
            UpdateCount()
            UpdateVisualState()
        end
    )

    local elapsedSinceStateUpdate =
        0

    button:SetScript(
        "OnUpdate",
        function(
            _,
            elapsed
        )
            if not button:IsShown() then
                return
            end

            if not GetAssignment(
                barID,
                buttonID
            ) then
                return
            end

            elapsedSinceStateUpdate =
                elapsedSinceStateUpdate
                + elapsed

            if elapsedSinceStateUpdate
                < 0.2
            then
                return
            end

            elapsedSinceStateUpdate =
                0

            UpdateVisualState()
        end
    )

    button.UpdateAssignment =
        UpdateAssignment

    button.RefreshVisualState =
        UpdateVisualState

    button.barID =
        barID

    button.buttonID =
        buttonID

    UpdateAssignment()

    return button
end