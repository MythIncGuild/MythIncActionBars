local addonName, ns = ...

local BUTTON_SIZE = 36

function ns.CreateActionButton(parent, name, actionSlot)
    local button = CreateFrame(
        "CheckButton",
        name,
        parent,
        "SecureActionButtonTemplate"
    )

    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetAttribute("type", "action")
    button:SetAttribute("action", actionSlot)

    if GetCVarBool("ActionButtonUseKeyDown") then
        button:RegisterForClicks("AnyDown")
    else
        button:RegisterForClicks("AnyUp")
    end

    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.08, 0.08, 0.08, 0.85)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    button.icon = icon

    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    button.cooldown = cooldown

    local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.Count = count

    local checked = button:CreateTexture(nil, "OVERLAY")
    checked:SetAllPoints(icon)
    checked:SetColorTexture(1, 0.82, 0, 0.25)
    button:SetCheckedTexture(checked)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetAllPoints()
    border:SetAtlas("UI-HUD-ActionBar-IconFrame")
    button.Border = border

    C_ActionBar.RegisterActionUIButton(button, actionSlot, cooldown)
    C_ActionBar.EnableActionRangeCheck(actionSlot, true)

    local usableState = true
    local resourceState = false
    local outOfRangeState = false

    local function ApplyColor()
        if outOfRangeState then
            icon:SetVertexColor(1, 0.25, 0.25)
        elseif usableState then
            icon:SetVertexColor(1, 1, 1)
        elseif resourceState then
            icon:SetVertexColor(0.5, 0.5, 1)
        else
            icon:SetVertexColor(0.4, 0.4, 0.4)
        end
    end

    local function UpdateIcon()
        local texture = C_ActionBar.GetActionTexture(actionSlot)

        if texture then
            icon:SetTexture(texture)
            icon:Show()
        else
            icon:SetTexture(nil)
            icon:Hide()
        end
    end

    local function UpdateCooldown()
        local duration = C_ActionBar.GetActionCooldownDuration(actionSlot)
        cooldown:SetCooldownFromDurationObject(duration)
    end

    local function UpdateCount()
        local displayCount = C_ActionBar.GetActionDisplayCount(actionSlot)

        if displayCount and displayCount ~= "" and displayCount ~= "0" then
            count:SetText(displayCount)
        else
            count:SetText("")
        end
    end

    local function UpdateUsability()
        local usable, lackingResources = C_ActionBar.IsUsableAction(actionSlot)

        usableState = usable
        resourceState = lackingResources

        ApplyColor()
    end

    local function UpdateCheckedState()
        if not C_ActionBar.HasAction(actionSlot) then
            button:SetChecked(false)
        end
    end

    local function UpdateAll()
        UpdateIcon()
        UpdateCooldown()
        UpdateCount()
        UpdateUsability()
        UpdateCheckedState()
    end

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetAction(actionSlot)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnDragStart", function()
        if InCombatLockdown() then
            return
        end

        PickupAction(actionSlot)
    end)

    button:SetScript("OnReceiveDrag", function()
        if InCombatLockdown() then
            return
        end

        C_ActionBar.PutActionInSlot(actionSlot)
    end)

    button:HookScript("OnClick", function()
        if not C_ActionBar.HasAction(actionSlot) then
            button:SetChecked(false)
        end
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

    eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
        if event == "ACTION_USABLE_CHANGED" then
            local changes = arg1

            for _, change in ipairs(changes) do
                if change.slot == actionSlot then
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

            if action == actionSlot then
                outOfRangeState = checksRange and not inRange
                ApplyColor()
            end

            return
        end

        if event == "ACTIONBAR_SLOT_CHANGED" then
            if arg1 ~= 0 and arg1 ~= actionSlot then
                return
            end
        end

        UpdateAll()
    end)

    button.UpdateAll = UpdateAll
    button.actionSlot = actionSlot
    button.eventFrame = eventFrame

    return button
end