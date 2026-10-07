local addonName, ns = ...

local function GetAssignment(barID, buttonID)
    if not ns.db or not ns.db.bars then
        return nil
    end

    local settings = ns.db.bars[barID]

    if not settings then
        return nil
    end

    settings.assignments = settings.assignments or {}

    return settings.assignments[buttonID]
end

local function SetAssignment(barID, buttonID, assignment)
    if not ns.db or not ns.db.bars then
        return false
    end

    local settings = ns.db.bars[barID]

    if not settings then
        return false
    end

    settings.assignments = settings.assignments or {}
    settings.assignments[buttonID] = assignment

    return true
end

local function GetAppearance(barID)
    local settings =
        ns.db
        and ns.db.bars
        and ns.db.bars[barID]

    if not settings then
        return nil
    end

    return settings.appearance
end

local function GetMountSpellID(mountID)
    if not mountID then
        return nil
    end

    local _, spellID = C_MountJournal.GetMountInfoByID(mountID)

    return spellID
end

local function GetAssignmentIcon(assignment)
    if not assignment then
        return nil
    end

    if assignment.type == "spell" then
        local info = C_Spell.GetSpellInfo(assignment.id)
        return info and info.iconID
    end

    if assignment.type == "item" then
        return C_Item.GetItemIconByID(assignment.id)
    end

    if assignment.type == "macro" then
        local _, icon = GetMacroInfo(assignment.id)
        return icon
    end

    if assignment.type == "mount" then
        local _, _, icon =
            C_MountJournal.GetMountInfoByID(assignment.id)

        return icon
    end

    if assignment.type == "battlepet" then
        local _, _, _, _, _, _, _, _, icon =
            C_PetJournal.GetPetInfoByPetID(assignment.id)

        return icon
    end

    return nil
end

local function GetAssignmentSpellID(assignment)
    if not assignment then
        return nil
    end

    if assignment.type == "spell" then
        return assignment.id
    end

    if assignment.type == "macro" then
        return GetMacroSpell(assignment.id)
    end

    if assignment.type == "mount" then
        return GetMountSpellID(assignment.id)
    end

    return nil
end

local function ApplySecureAssignment(button, assignment)
    button:SetAttribute("type", nil)
    button:SetAttribute("spell", nil)
    button:SetAttribute("item", nil)
    button:SetAttribute("macro", nil)
    button:SetAttribute("macrotext", nil)

    if not assignment then
        return
    end

    if assignment.type == "spell" then
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", assignment.id)
        return
    end

    if assignment.type == "item" then
        button:SetAttribute("type", "item")
        button:SetAttribute("item", "item:" .. assignment.id)
        return
    end

    if assignment.type == "macro" then
        button:SetAttribute("type", "macro")
        button:SetAttribute("macro", assignment.id)
        return
    end

    if assignment.type == "mount" then
        local mountName, spellID =
            C_MountJournal.GetMountInfoByID(assignment.id)

        local spellInfo =
            spellID and C_Spell.GetSpellInfo(spellID)

        local castName =
            (spellInfo and spellInfo.name) or mountName

        if castName and castName ~= "" then
            button:SetAttribute("type", "macro")
            button:SetAttribute("macrotext", "/cast " .. castName)
        end

        return
    end

    if assignment.type == "battlepet" then
        button:SetAttribute("type", "macro")
        button:SetAttribute(
            "macrotext",
            "/summonpet " .. assignment.id
        )
    end
end

local function FindMountDisplayIndex(mountID)
    if not mountID
        or not C_MountJournal.GetDisplayedMountID
    then
        return nil
    end

    local count = C_MountJournal.GetNumDisplayedMounts()

    for index = 1, count do
        if C_MountJournal.GetDisplayedMountID(index) == mountID then
            return index
        end
    end

    return nil
end

-- Used by both dragging and occupied-slot swapping.
-- The stored assignment is removed only after pickup succeeds.
local function PickupAssignment(assignment)
    if not assignment or GetCursorInfo() then
        return false
    end

    if assignment.type == "spell" then
        C_Spell.PickupSpell(assignment.id)

    elseif assignment.type == "item" then
        C_Item.PickupItem(assignment.id)

    elseif assignment.type == "macro" then
        PickupMacro(assignment.id)

    elseif assignment.type == "mount" then
        local displayIndex = assignment.index

        if displayIndex
            and C_MountJournal.GetDisplayedMountID
            and C_MountJournal.GetDisplayedMountID(displayIndex)
                ~= assignment.id
        then
            displayIndex = nil
        end

        if not displayIndex then
            displayIndex = FindMountDisplayIndex(assignment.id)
        end

        if displayIndex then
            C_MountJournal.Pickup(displayIndex)

            if GetCursorInfo() then
                assignment.index = displayIndex
            end
        end

        -- Preserve the original spell fallback.
        if not GetCursorInfo() then
            local spellID = GetMountSpellID(assignment.id)

            if not spellID then
                return false
            end

            C_Spell.PickupSpell(spellID)
        end

    elseif assignment.type == "battlepet" then
        C_PetJournal.PickupPet(assignment.id)

    else
        return false
    end

    return GetCursorInfo() ~= nil
end

function ns.CreateCustomActionButton(parent, name, barID, buttonID)
    local button = CreateFrame(
        "CheckButton",
        name,
        parent,
        "SecureActionButtonTemplate"
    )

    button:SetSize(36, 36)

    -- Preserve activation on release.
    button:SetAttribute("useOnKeyDown", false)

    -- Receive both phases for execution and placement guards.
    button:RegisterForClicks("AnyDown", "AnyUp")
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
        "Cooldown",
        nil,
        button,
        "CooldownFrameTemplate"
    )

    cooldown:SetAllPoints(icon)
    button.cooldown = cooldown

    local count = button:CreateFontString(
        nil,
        "OVERLAY",
        "NumberFontNormal"
    )

    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.Count = count

    local hotKey = button:CreateFontString(
        nil,
        "OVERLAY",
        "NumberFontNormalSmall"
    )

    hotKey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -3, -3)
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
        nil,
        "OVERLAY",
        nil,
        6
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

        ns.SetDragHighlight(button, validCursor)
    end

    local usableState = true
    local resourceState = false
    local outOfRangeState = false

    local function ApplyColor()
        local appearance = GetAppearance(barID)

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
        local assignment = GetAssignment(barID, buttonID)
        local texture = GetAssignmentIcon(assignment)

        if texture then
            icon:SetTexture(texture)
            icon:Show()
        else
            icon:SetTexture(nil)
            icon:Hide()
        end
    end

    local function UpdateCooldown()
        local assignment = GetAssignment(barID, buttonID)

        if not assignment then
            cooldown:Clear()
            return
        end

        if assignment.type == "battlepet" then
            if C_PetJournal.GetPetCooldownByGUID then
                local startTime, duration, enabled =
                    C_PetJournal.GetPetCooldownByGUID(assignment.id)

                if startTime
                    and duration
                    and duration > 0
                    and enabled ~= false
                    and enabled ~= 0
                then
                    cooldown:SetCooldown(startTime, duration)
                else
                    cooldown:Clear()
                end
            else
                cooldown:Clear()
            end

            return
        end

        local spellID = GetAssignmentSpellID(assignment)

        if spellID then
            local duration =
                C_Spell.GetSpellCooldownDuration(spellID)

            if duration then
                cooldown:SetCooldownFromDurationObject(duration)
            else
                cooldown:Clear()
            end

            return
        end

        if assignment.type == "item" then
            local start, duration, enable =
                C_Item.GetItemCooldown(assignment.id)

            if enable
                and enable ~= 0
                and duration
                and duration > 0
            then
                cooldown:SetCooldown(start, duration)
            else
                cooldown:Clear()
            end

            return
        end

        cooldown:Clear()
    end

    local function UpdateCount()
        local assignment = GetAssignment(barID, buttonID)

        if not assignment then
            count:SetText("")
            return
        end

        if assignment.type == "item" then
            local quantity = C_Item.GetItemCount(assignment.id)

            if quantity and quantity > 1 then
                count:SetText(quantity)
            else
                count:SetText("")
            end

            return
        end

        count:SetText("")
    end

    local function UpdateUsability()
        local assignment = GetAssignment(barID, buttonID)

        if not assignment then
            usableState = true
            resourceState = false
            ApplyColor()
            return
        end

        if assignment.type == "mount" then
            if C_MountJournal.GetMountUsabilityByID then
                local usable =
                    C_MountJournal.GetMountUsabilityByID(
                        assignment.id,
                        true
                    )

                usableState = usable ~= false
            else
                usableState = true
            end

            resourceState = false
            ApplyColor()
            return
        end

        if assignment.type == "battlepet" then
            if C_PetJournal.PetIsSummonable then
                usableState =
                    C_PetJournal.PetIsSummonable(assignment.id)
                        ~= false
            else
                usableState = true
            end

            resourceState = false
            ApplyColor()
            return
        end

        local spellID = GetAssignmentSpellID(assignment)

        if spellID then
            local usable, insufficientPower =
                C_Spell.IsSpellUsable(spellID)

            usableState = usable
            resourceState = insufficientPower

            ApplyColor()
            return
        end

        if assignment.type == "item" then
            local usable, insufficientPower =
                C_Item.IsUsableItem(assignment.id)

            usableState = usable
            resourceState = insufficientPower

            ApplyColor()
            return
        end

        usableState = true
        resourceState = false
        ApplyColor()
    end

    local function UpdateRange()
        local assignment = GetAssignment(barID, buttonID)

        if not assignment then
            outOfRangeState = false
            ApplyColor()
            return
        end

        if assignment.type == "mount"
            or assignment.type == "battlepet"
        then
            outOfRangeState = false
            ApplyColor()
            return
        end

        local spellID = GetAssignmentSpellID(assignment)

        if spellID then
            local inRange = C_Spell.IsSpellInRange(spellID)

            outOfRangeState = inRange == false
            ApplyColor()
            return
        end

        if assignment.type == "item" then
            if InCombatLockdown() then
                outOfRangeState = false
                ApplyColor()
                return
            end

            if C_Item.ItemHasRange
                and C_Item.ItemHasRange(assignment.id)
            then
                local inRange =
                    C_Item.IsItemInRange(assignment.id, "target")

                outOfRangeState = inRange == false
            else
                outOfRangeState = false
            end

            ApplyColor()
            return
        end

        outOfRangeState = false
        ApplyColor()
    end

    local function UpdateCheckedState()
        local assignment = GetAssignment(barID, buttonID)

        if assignment and assignment.type == "battlepet" then
            button:SetChecked(
                C_PetJournal.GetSummonedPetGUID() == assignment.id
            )

        elseif assignment and assignment.type == "mount" then
            local _, _, _, active =
                C_MountJournal.GetMountInfoByID(assignment.id)

            button:SetChecked(active == true)

        else
            button:SetChecked(false)
        end
    end

    local function UpdateVisualState()
        UpdateUsability()
        UpdateRange()
        UpdateCheckedState()
    end

    local suppressRelease = false
    local suppressedClick = false
    local cursorHandled = false
    local placementGeneration = 0

    local function UpdateAssignment()
        if InCombatLockdown() then
            return
        end

        local assignment = GetAssignment(barID, buttonID)

        ApplySecureAssignment(button, assignment)

        if suppressRelease then
            button:SetAttribute("type", nil)
        end

        UpdateIcon()
        UpdateCooldown()
        UpdateCount()
        UpdateVisualState()
    end

    local function AssignFromCursor()
        if InCombatLockdown() then
            return false
        end

        local cursorType, info1, info2, info3 = GetCursorInfo()
        local assignment

        if cursorType == "spell" then
            -- A mount picked up through spell fallback remains a mount.
            local mountID =
                info3
                and C_MountJournal.GetMountFromSpell(info3)

            assignment = {
                type = mountID and "mount" or "spell",
                id = mountID or info3,
            }

        elseif cursorType == "item" then
            assignment = {
                type = "item",
                id = info1,
            }

        elseif cursorType == "macro" then
            assignment = {
                type = "macro",
                id = info1,
            }

        elseif cursorType == "mount" then
            assignment = {
                type = "mount",
                id = info1,
                index = info2,
            }

        elseif cursorType == "battlepet" then
            assignment = {
                type = "battlepet",
                id = info1,
            }

        elseif cursorType == "action" then
            local actionType, actionID, subType =
                GetActionInfo(info1)

            if actionType == "spell" then
                assignment = {
                    type = "spell",
                    id = actionID,
                }

            elseif actionType == "item" then
                assignment = {
                    type = "item",
                    id = actionID,
                }

            elseif actionType == "macro" then
                assignment = {
                    type = "macro",
                    id = actionID,
                }

            elseif actionType == "companion"
                and subType == "MOUNT"
            then
                local mountID =
                    C_MountJournal.GetMountFromSpell(actionID)

                if mountID then
                    assignment = {
                        type = "mount",
                        id = mountID,
                    }
                end

            elseif (
                actionType == "battlepet"
                or actionType == "summonpet"
            ) and type(actionID) == "string" then
                assignment = {
                    type = "battlepet",
                    id = actionID,
                }
            end
        end

        if not assignment or not assignment.id then
            return false
        end

        local previous = GetAssignment(barID, buttonID)

        ClearCursor()

        if previous and not PickupAssignment(previous) then
            -- Keep the occupied slot if pickup fails.
            -- Attempt to restore the incoming action to the cursor.
            PickupAssignment(assignment)
            return false
        end

        if not SetAssignment(barID, buttonID, assignment) then
            ClearCursor()
            PickupAssignment(assignment)
            return false
        end

        ns.ClearDragHighlight()
        UpdateAssignment()

        return true
    end

    local function ArmPlacementGuard()
        suppressRelease = true
        cursorHandled = true
        placementGeneration = placementGeneration + 1

        local generation = placementGeneration

        button:SetAttribute("type", nil)

        C_Timer.After(0, function()
            if generation ~= placementGeneration then
                return
            end

            cursorHandled = false

            -- Restore attributes between events.
            -- PreClick guards the trailing placement click.
            if not InCombatLockdown() then
                ApplySecureAssignment(
                    button,
                    GetAssignment(barID, buttonID)
                )
            end
        end)
    end

    button:SetScript("OnReceiveDrag", function()
        if InCombatLockdown()
            or cursorHandled
            or not GetCursorInfo()
        then
            return
        end

        ArmPlacementGuard()
        AssignFromCursor()

        button:SetAttribute("type", nil)
    end)

    button:HookScript("PreClick", function(self, mouseButton, down)
        suppressedClick = false

        if InCombatLockdown() then
            return
        end

        if down then
            -- A new press clears a completed-drag guard.
            placementGeneration = placementGeneration + 1
            suppressRelease = false
            cursorHandled = false

            UpdateAssignment()
        end

        if suppressRelease or cursorHandled then
            suppressedClick = true
            self:SetAttribute("type", nil)
            return
        end

        if GetCursorInfo() then
            suppressedClick = true

            ArmPlacementGuard()
            AssignFromCursor()

            -- Placement must not activate the assigned action.
            self:SetAttribute("type", nil)
        end
    end)

    button:HookScript("PostClick", function(self, mouseButton, down)
        if suppressedClick or suppressRelease then
            if not down then
                suppressRelease = false
                suppressedClick = false
                UpdateAssignment()
            end

            return
        end

        -- Secure attributes execute the action.
        -- PostClick only refreshes its visual state.
        UpdateCooldown()
        UpdateCheckedState()
    end)

    button:SetScript("OnDragStart", function()
        if InCombatLockdown() or GetCursorInfo() then
            return
        end

        local assignment = GetAssignment(barID, buttonID)

        if not PickupAssignment(assignment) then
            return
        end

        suppressRelease = true
        cursorHandled = false

        SetAssignment(barID, buttonID, nil)
        UpdateAssignment()
    end)

    button:SetScript("OnEnter", function(self)
        UpdateDragHighlight()

        local assignment = GetAssignment(barID, buttonID)

        if not assignment then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

        if assignment.type == "spell" then
            GameTooltip:SetSpellByID(assignment.id)

        elseif assignment.type == "item" then
            GameTooltip:SetItemByID(assignment.id)

        elseif assignment.type == "macro" then
            local macroName = GetMacroInfo(assignment.id)

            if macroName then
                GameTooltip:SetText(macroName)
            end

        elseif assignment.type == "mount" then
            local mountName, spellID =
                C_MountJournal.GetMountInfoByID(assignment.id)

            if spellID then
                GameTooltip:SetSpellByID(spellID)
            elseif mountName then
                GameTooltip:SetText(mountName)
            end

        elseif assignment.type == "battlepet" then
            local _, customName, _, _, _, _, _, speciesName =
                C_PetJournal.GetPetInfoByPetID(assignment.id)

            local petName = customName or speciesName

            if petName then
                GameTooltip:SetText(petName)
                GameTooltip:AddLine("Battle Pet", 0.7, 0.7, 0.7)
            end
        end

        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        ns.SetDragHighlight(button, false)
        GameTooltip:Hide()
    end)

    local eventFrame = CreateFrame("Frame")

    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
    eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("UPDATE_MACROS")
    eventFrame:RegisterEvent("PET_JOURNAL_LIST_UPDATE")
    eventFrame:RegisterEvent("UPDATE_SUMMONPETS_ACTION")

    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            placementGeneration = placementGeneration + 1
            suppressRelease = false
            suppressedClick = false
            cursorHandled = false

            UpdateAssignment()
            return
        end

        if event == "UPDATE_MACROS"
            or event == "PET_JOURNAL_LIST_UPDATE"
            or event == "UPDATE_SUMMONPETS_ACTION"
        then
            UpdateAssignment()
            return
        end

        UpdateIcon()
        UpdateCooldown()
        UpdateCount()
        UpdateVisualState()
    end)

    local elapsedSinceStateUpdate = 0

    button:SetScript("OnUpdate", function(_, elapsed)
        if not button:IsShown() then
            ns.SetDragHighlight(button, false)
            return
        end

        if button:IsMouseOver() then
            UpdateDragHighlight()
        elseif dragHighlight:IsShown() then
            ns.SetDragHighlight(button, false)
        end

        local assignment = GetAssignment(barID, buttonID)

        if not assignment then
            elapsedSinceStateUpdate = 0

            if icon:IsShown() or count:GetText() ~= "" then
                UpdateAssignment()
            end

            return
        end

        elapsedSinceStateUpdate = elapsedSinceStateUpdate + elapsed

        if elapsedSinceStateUpdate < 0.2 then
            return
        end

        elapsedSinceStateUpdate = 0

        UpdateCooldown()
        UpdateCount()
        UpdateVisualState()
    end)

    button.UpdateAssignment = UpdateAssignment
    button.RefreshVisualState = UpdateVisualState
    button.barID = barID
    button.buttonID = buttonID

    UpdateAssignment()

    return button
end