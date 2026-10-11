
local addonName, ns = ...

local customButtons = setmetatable({}, { __mode = "k" })
local activeSpecID
local activePageByBar = {}
local editPageByBar = {}
local MAX_PAGES = ns.MAX_CUSTOM_ACTION_PAGES or 12

local function CurrentSpecID()
    local index = GetSpecialization()
    return index and GetSpecializationInfo(index)
end

local function ActivateSpecialization(settings)
    if InCombatLockdown() then return end

    activeSpecID = activeSpecID or CurrentSpecID()
    if not activeSpecID then return end

    if not settings.assignmentsBySpec then
        -- Preserve legacy custom contents as Page 1.
        settings.assignmentsBySpec = {
            [activeSpecID] = settings.assignments or {},
        }
    end

    settings.assignmentsBySpec[activeSpecID] =
        settings.assignmentsBySpec[activeSpecID] or {}

    settings.assignments =
        settings.assignmentsBySpec[activeSpecID]

    settings.customPagesBySpec =
        settings.customPagesBySpec or {}
end

local function GetPageAssignments(settings, page, create)
    if not settings then return nil end

    if not InCombatLockdown() then
        ActivateSpecialization(settings)
    end

    page = math.floor(tonumber(page) or 1)

    if page < 1 or page > MAX_PAGES then
        return nil
    end

    if page == 1 then
        if create and not settings.assignments then
            settings.assignments = {}
        end

        return settings.assignments
    end

    local specID = activeSpecID or CurrentSpecID()
    if not specID then return nil end

    local specPages = settings.customPagesBySpec
        and settings.customPagesBySpec[specID]

    if not specPages and create then
        settings.customPagesBySpec =
            settings.customPagesBySpec or {}

        specPages = {}
        settings.customPagesBySpec[specID] = specPages
    end

    if not specPages then return nil end

    if not specPages[page] and create then
        specPages[page] = {}
    end

    return specPages[page]
end

local function GetAssignment(barID, buttonID, page)
    local settings = ns.db
        and ns.db.bars
        and ns.db.bars[barID]

    if not settings then return nil end

    local assignments = GetPageAssignments(
        settings,
        page or activePageByBar[barID] or 1,
        false
    )

    return assignments and assignments[buttonID]
end

local function SetAssignment(barID, buttonID, assignment)
    if InCombatLockdown() then return false end

    local settings = ns.db
        and ns.db.bars
        and ns.db.bars[barID]

    if not settings then return false end

    local page = editPageByBar[barID]
        or activePageByBar[barID]
        or 1

    local assignments = GetPageAssignments(
        settings,
        page,
        true
    )

    if not assignments then return false end

    assignments[buttonID] = assignment
    return true
end

function ns.GetCustomBarPageAssignment(
    barID,
    buttonID,
    page
)
    return GetAssignment(barID, buttonID, page)
end

function ns.GetCustomBarActivePage(barID)
    return activePageByBar[barID] or 1
end

-- ============================================================
-- PAGE RULE COMPILATION
-- ============================================================

local CONDITION_TOKENS = {
    stealth = "[stealth]",
    combat = "[combat]",
    nocombat = "[nocombat]",
    mounted = "[mounted]",
    flying = "[flying]",
    swimming = "[swimming]",
    friendly = "[@target,help,nodead]",
    hostile = "[@target,harm,nodead]",
    pet = "[pet]",
    vehicle = "[vehicleui]",
    override = "[overridebar]",
    possess = "[possessbar]",
}

local function CompileRule(rule)
    if type(rule) ~= "table"
        or rule.enabled == false
    then
        return nil
    end

    local page = tonumber(rule.page)

    if not page
        or page ~= math.floor(page)
        or page < 1
        or page > MAX_PAGES
    then
        return nil
    end

    local condition = rule.condition
    local token = CONDITION_TOKENS[condition]

    if not token
        and type(condition) == "string"
    then
        local form = condition:match("^form:(%d+)$")

        if form and tonumber(form) <= 10 then
            token = "[form:" .. form .. "]"
        end
    end

    return token
        and (token .. " " .. page)
        or nil
end

local function BuildPageDriver(settings, barID)
    local pages = settings.actionPages or {}

    -- Edit preview is temporary and never stored
    -- in the character's saved profile.
    local editingPage = editPageByBar[barID]

    if editingPage
        and editingPage >= 1
        and editingPage <= MAX_PAGES
    then
        return tostring(math.floor(editingPage)), true
    end

    if ns.CompileActionPageDriver then
        return ns.CompileActionPageDriver(
            pages,
            MAX_PAGES
        )
    end

    local parts = {}

    for _, rule in ipairs(pages.contextRules or {}) do
        local compiled = CompileRule(rule)

        if compiled then
            parts[#parts + 1] = compiled
        end
    end

    -- Modifier priority: ALT, CTRL, SHIFT.
    for _, name in ipairs({
        "alt",
        "ctrl",
        "shift",
    }) do
        local entry = pages[name]
        local page = entry and tonumber(entry.page)

        if entry
            and entry.enabled
            and page
            and page == math.floor(page)
            and page >= 1
            and page <= MAX_PAGES
        then
            parts[#parts + 1] =
                "[mod:" .. name .. "] " .. page
        end
    end

    local active = #parts > 0
    parts[#parts + 1] = "1"

    return table.concat(parts, "; "), active
end

function ns.SetCustomBarEditPage(barID, page)
    if InCombatLockdown() then
        return false, "combat"
    end

    local settings = ns.db
        and ns.db.bars
        and ns.db.bars[barID]

    if not settings or settings.source ~= "custom" then
        return false, "unsupported"
    end

    if page ~= nil then
        page = tonumber(page)

        if not page
            or page ~= math.floor(page)
            or page < 1
            or page > MAX_PAGES
        then
            return false, "invalid"
        end
    end

    editPageByBar[barID] = page

    if ns.ConfigureCustomBarPaging then
        ns.ConfigureCustomBarPaging(barID)
    end

    return true
end

-- ============================================================
-- SPECIALIZATION HANDLING
-- ============================================================

local specializationEvents = CreateFrame("Frame")

specializationEvents:RegisterEvent(
    "PLAYER_SPECIALIZATION_CHANGED"
)
specializationEvents:RegisterEvent(
    "PLAYER_ENTERING_WORLD"
)
specializationEvents:RegisterEvent(
    "PLAYER_REGEN_ENABLED"
)

specializationEvents:SetScript(
    "OnEvent",
    function(_, event, unit)
        if event == "PLAYER_SPECIALIZATION_CHANGED"
            and unit ~= "player"
        then
            return
        end

        if InCombatLockdown() then return end

        local specID = CurrentSpecID()
        if not specID then return end

        activeSpecID = specID

        for _, settings in pairs(
            ns.db and ns.db.bars or {}
        ) do
            if settings.source == "custom" then
                ActivateSpecialization(settings)
            end
        end

        if ns.CloseMIABFlyouts then
            ns.CloseMIABFlyouts()
        end

        for button in pairs(customButtons) do
            if button.UpdateAssignment then
                button.UpdateAssignment()
            end
        end

        for barID, settings in pairs(
            ns.db and ns.db.bars or {}
        ) do
            if settings.source == "custom"
                and ns.ConfigureCustomBarPaging
            then
                ns.ConfigureCustomBarPaging(barID)
            end
        end

        if ns.ApplyAllKeybinds then
            ns.ApplyAllKeybinds()
        end

        if ns.RefreshAllEmptyButtonVisibility then
            ns.RefreshAllEmptyButtonVisibility()
        end
    end
)

-- ============================================================
-- ASSIGNMENT INFORMATION
-- ============================================================

local function GetAppearance(barID)
    local settings = ns.db
        and ns.db.bars
        and ns.db.bars[barID]

    return settings and settings.appearance
end

local function GetMountSpellID(mountID)
    if not mountID then return nil end

    local _, spellID =
        C_MountJournal.GetMountInfoByID(mountID)

    return spellID
end

local function GetFlyoutSpellbookEntry(flyoutID)
    if not C_SpellBook
        or not C_SpellBook.GetNumSpellBookSkillLines
        or not C_SpellBook.GetSpellBookSkillLineInfo
        or not C_SpellBook.GetSpellBookItemInfo
    then
        return nil
    end

    local bank = Enum.SpellBookSpellBank.Player
    local flyoutType = Enum.SpellBookItemType.Flyout

    for lineIndex = 1,
        C_SpellBook.GetNumSpellBookSkillLines()
    do
        local line =
            C_SpellBook.GetSpellBookSkillLineInfo(
                lineIndex
            )

        if line then
            local first =
                (line.itemIndexOffset or 0) + 1

            local last =
                first + (line.numSpellBookItems or 0) - 1

            for slot = first, last do
                local info =
                    C_SpellBook.GetSpellBookItemInfo(
                        slot,
                        bank
                    )

                if info
                    and info.itemType == flyoutType
                    and info.actionID == flyoutID
                then
                    return slot, bank, info.iconID
                end
            end
        end
    end

    return nil
end

local function GetAssignmentIcon(assignment)
    if not assignment then return nil end

    if assignment.type == "flyout" then
        local _, _, iconID =
            GetFlyoutSpellbookEntry(assignment.id)

        return iconID or 134400
    end

    if assignment.type == "spell" then
        local info =
            C_Spell.GetSpellInfo(assignment.id)

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
            C_MountJournal.GetMountInfoByID(
                assignment.id
            )

        return icon
    end

    if assignment.type == "battlepet" then
        local _, _, _, _, _, _, _, _, icon =
            C_PetJournal.GetPetInfoByPetID(
                assignment.id
            )

        return icon
    end

    return nil
end

local function GetAssignmentSpellID(assignment)
    if not assignment then return nil end

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

-- ============================================================
-- SECURE ACTION PAGING
-- ============================================================

local SECURE_PAGE_SNIPPET = [[
    local page = tonumber(newstate) or 1
    if page < 1 or page > 12 then
        page = 1
    end

    local prefix = "miab-page-" .. page .. "-"

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
    self:SetAttribute("miab-currentpage", page)
]]

local function SecureValues(assignment, pagingEnabled)
    if not assignment then return nil end

    if assignment.type == "flyout" then
        return "flyout", assignment.id

    elseif assignment.type == "spell" then
        local info =
            C_Spell.GetSpellInfo(assignment.id)

        local name = info and info.name

        if not name or name == "" then
            return nil
        end

        -- Preserve direct spell casting when paging is off.
        if not pagingEnabled then
            return "spell", name
        end

        -- Build targeting conditions before combat.
        -- Each page then carries its own casting macro.
        local clauses = {}

        local helpful =
            C_Spell.IsSpellHelpful(assignment.id)

        local harmful =
            C_Spell.IsSpellHarmful(assignment.id)

        local function Modifier(action)
            local key = GetModifiedClick(action)

            if not key or key == "NONE" then
                return nil
            end

            local mods = {}

            for mod in key:lower():gmatch("[^%-]+") do
                if mod ~= "alt"
                    and mod ~= "ctrl"
                    and mod ~= "shift"
                then
                    return nil
                end

                mods[#mods + 1] = "mod:" .. mod
            end

            return #mods > 0
                and table.concat(mods, ",")
                or nil
        end

        local mouseover =
            GetModifiedClick("MOUSEOVERCAST")

        local mousemod =
            Modifier("MOUSEOVERCAST")

        if GetCVarBool("enableMouseoverCast")
            and (
                mouseover == "NONE"
                or mousemod
            )
        then
            local prefix =
                mousemod and (mousemod .. ",") or ""

            if helpful then
                clauses[#clauses + 1] =
                    "[" .. prefix
                    .. "@mouseover,help,nodead]"
            end

            if harmful then
                clauses[#clauses + 1] =
                    "[" .. prefix
                    .. "@mouseover,harm,nodead]"
            end
        end

        local selfcast = Modifier("SELFCAST")
        local focuscast = Modifier("FOCUSCAST")

        if selfcast then
            clauses[#clauses + 1] =
                "[" .. selfcast .. ",@player]"
        end

        if focuscast then
            clauses[#clauses + 1] =
                "[" .. focuscast .. ",@focus,exists]"
        end

        if helpful and GetCVarBool("autoSelfCast") then
            clauses[#clauses + 1] =
                "[@target,help,nodead]"

            if harmful then
                clauses[#clauses + 1] =
                    "[@target,harm,nodead]"
            end

            clauses[#clauses + 1] = "[@player]"
        else
            clauses[#clauses + 1] = "[@target]"
        end

        local lines = {}

        for _, clause in ipairs(clauses) do
            lines[#lines + 1] =
                clause .. " " .. name
        end

        return "macro",
            nil,
            nil,
            nil,
            "/cast " .. table.concat(lines, "; ")

    elseif assignment.type == "item" then
        return "item",
            nil,
            "item:" .. assignment.id

    elseif assignment.type == "macro" then
        return "macro",
            nil,
            nil,
            assignment.id

    elseif assignment.type == "mount" then
        local mountName, spellID =
            C_MountJournal.GetMountInfoByID(
                assignment.id
            )

        local info =
            spellID and C_Spell.GetSpellInfo(spellID)

        local castName =
            (info and info.name) or mountName

        if castName and castName ~= "" then
            return "macro",
                nil,
                nil,
                nil,
                "/cast " .. castName
        end

    elseif assignment.type == "battlepet" then
        return "macro",
            nil,
            nil,
            nil,
            "/summonpet " .. assignment.id
    end

    return nil
end

local function ApplySecureAssignment(button, assignment)
    if InCombatLockdown() then return end

    local actionType, spell, item, macro, macrotext =
        SecureValues(assignment, false)

    button:SetAttribute("type", actionType)
    button:SetAttribute("spell", spell)
    button:SetAttribute("item", item)
    button:SetAttribute("macro", macro)
    button:SetAttribute("macrotext", macrotext)
end

local function ConfigureSecurePages(
    button,
    settings,
    barID,
    buttonID
)
    if InCombatLockdown() then return false end

    local driver, active =
        BuildPageDriver(settings, barID)

    -- Prepare every page's secure action outside combat.
    for page = 1, MAX_PAGES do
        local assignment =
            GetAssignment(barID, buttonID, page)

        local actionType, spell, item, macro, macrotext =
            SecureValues(assignment, active)

        local prefix = "miab-page-" .. page .. "-"

        button:SetAttribute(
            prefix .. "type",
            actionType
        )
        button:SetAttribute(
            prefix .. "spell",
            spell
        )
        button:SetAttribute(
            prefix .. "item",
            item
        )
        button:SetAttribute(
            prefix .. "macro",
            macro
        )
        button:SetAttribute(
            prefix .. "macrotext",
            macrotext
        )
    end

    UnregisterStateDriver(button, "miabpage")

    if active then
        button:SetAttribute(
            "_onstate-miabpage",
            SECURE_PAGE_SNIPPET
        )

        button:SetAttribute("state-miabpage", nil)

        RegisterStateDriver(
            button,
            "miabpage",
            driver
        )
    else
        -- Preserve the legacy Normal-page action path.
        activePageByBar[barID] = 1

        ApplySecureAssignment(
            button,
            GetAssignment(barID, buttonID, 1)
        )

        button:SetAttribute(
            "miab-currentpage",
            1
        )
    end

    return true
end

-- ============================================================
-- CURSOR ACTION PICKUP
-- ============================================================

local function FindMountDisplayIndex(mountID)
    if not mountID
        or not C_MountJournal.GetDisplayedMountID
    then
        return nil
    end

    local count =
        C_MountJournal.GetNumDisplayedMounts()

    for index = 1, count do
        if C_MountJournal.GetDisplayedMountID(index)
            == mountID
        then
            return index
        end
    end

    return nil
end

local function PickupAssignment(assignment)
    if not assignment or GetCursorInfo() then
        return false
    end

    if assignment.type == "flyout" then
        local slot, bank =
            GetFlyoutSpellbookEntry(assignment.id)

        if slot and C_SpellBook.PickupSpellBookItem then
            C_SpellBook.PickupSpellBookItem(
                slot,
                bank
            )

        elseif slot and PickupSpellBookItem then
            PickupSpellBookItem(slot, bank)
        end

    elseif assignment.type == "spell" then
        C_Spell.PickupSpell(assignment.id)

    elseif assignment.type == "item" then
        C_Item.PickupItem(assignment.id)

    elseif assignment.type == "macro" then
        PickupMacro(assignment.id)

    elseif assignment.type == "mount" then
        local displayIndex = assignment.index

        if displayIndex
            and C_MountJournal.GetDisplayedMountID
            and C_MountJournal.GetDisplayedMountID(
                displayIndex
            ) ~= assignment.id
        then
            displayIndex = nil
        end

        if not displayIndex then
            displayIndex =
                FindMountDisplayIndex(assignment.id)
        end

        if displayIndex then
            C_MountJournal.Pickup(displayIndex)

            if GetCursorInfo() then
                assignment.index = displayIndex
            end
        end

        if not GetCursorInfo() then
            local spellID =
                GetMountSpellID(assignment.id)

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

-- ============================================================
-- CUSTOM BUTTON
-- ============================================================

function ns.CreateCustomActionButton(
    parent,
    name,
    barID,
    buttonID
)
    local button = CreateFrame(
        "CheckButton",
        name,
        parent,
        "SecureActionButtonTemplate,SecureHandlerStateTemplate"
    )

    button:SetSize(36, 36)

    local activePage = activePageByBar[barID] or 1

    local function CurrentAssignment()
        return GetAssignment(
            barID,
            buttonID,
            activePage
        )
    end

    ns.InitializeButtonFlyout(button, function()
        local assignment = CurrentAssignment()

        return assignment and assignment.type,
            assignment and assignment.id
    end)

    button:SetAttribute("useOnKeyDown", false)
    button:RegisterForClicks("AnyDown", "AnyUp")

    button.ApplyButtonInteraction = function(self)
        if InCombatLockdown() then return end

        local locked, onPress =
            ns.GetButtonInteractionSettings()

        self:SetAttribute(
            "useOnKeyDown",
            onPress
                and locked
                and not IsShiftKeyDown()
        )
    end

    ns.InteractionButtons[button] = true
    button:ApplyButtonInteraction()
    button:RegisterForDrag("LeftButton")

    local background =
        button:CreateTexture(nil, "BACKGROUND")

    background:SetAllPoints()
    background:SetColorTexture(
        0.08,
        0.08,
        0.08,
        0.85
    )

    button.Background = background

    local icon =
        button:CreateTexture(nil, "ARTWORK")

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

    count:SetPoint(
        "BOTTOMRIGHT",
        button,
        "BOTTOMRIGHT",
        -2,
        2
    )

    button.Count = count

    local hotKey = button:CreateFontString(
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

    hotKey:SetJustifyH("RIGHT")
    hotKey:SetText("")
    button.HotKey = hotKey

    local checked =
        button:CreateTexture(nil, "OVERLAY")

    checked:SetAllPoints(icon)
    checked:SetColorTexture(
        1,
        0.82,
        0,
        0.25
    )

    button:SetCheckedTexture(checked)

    local border =
        button:CreateTexture(nil, "OVERLAY")

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
            icon:SetVertexColor(
                1,
                0.25,
                0.25
            )

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
                desaturateUnusable
                    and not usableState
            )
        end
    end

    local function UpdateIcon()
        local assignment = CurrentAssignment()
        local texture = GetAssignmentIcon(assignment)

        if button.MacroName then
            if assignment
                and assignment.type == "macro"
            then
                local name =
                    GetMacroInfo(assignment.id)

                button.MacroName:SetText(name or "")
            else
                button.MacroName:SetText("")
            end
        end

        if texture then
            icon:SetTexture(texture)
            icon:Show()
        else
            icon:SetTexture(nil)
            icon:Hide()
        end
    end

    ns.InitializeSpellCasting(button, function()
        local assignment = CurrentAssignment()

        if assignment
            and assignment.type == "spell"
        then
            return assignment.id
        end
    end)

    ns.InitializeButtonSpellFeedback(button, function()
        return GetAssignmentSpellID(
            CurrentAssignment()
        )
    end)

    local function UpdateCooldown()
        local assignment = CurrentAssignment()
        local spellID =
            GetAssignmentSpellID(assignment)

        if spellID then
            ns.SetButtonCooldownDuration(
                button.chargeCooldown,
                C_Spell.GetSpellChargeDuration(
                    spellID
                )
            )
        else
            button.chargeCooldown:Clear()
        end

        if not assignment then
            cooldown:Clear()
            return
        end

        if assignment.type == "battlepet" then
            if C_PetJournal.GetPetCooldownByGUID then
                local startTime, duration, enabled =
                    C_PetJournal.GetPetCooldownByGUID(
                        assignment.id
                    )

                if startTime
                    and duration
                    and duration > 0
                    and enabled ~= false
                    and enabled ~= 0
                then
                    cooldown:SetCooldown(
                        startTime,
                        duration
                    )
                else
                    cooldown:Clear()
                end
            else
                cooldown:Clear()
            end

            return
        end

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

            return
        end

        if assignment.type == "item" then
            local start, duration, enable =
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

        cooldown:Clear()
    end

    local function UpdateCount()
        local assignment = CurrentAssignment()

        if not assignment then
            count:SetText("")
            return
        end

        if assignment.type == "item" then
            local quantity =
                C_Item.GetItemCount(
                    assignment.id
                )

            if quantity and quantity > 1 then
                count:SetText(quantity)
            else
                count:SetText("")
            end

            return
        end

        local spellID =
            GetAssignmentSpellID(assignment)

        if spellID then
            count:SetText(
                C_Spell.GetSpellDisplayCount(
                    spellID
                )
            )
        else
            count:SetText("")
        end
    end

    local function UpdateUsability()
        local assignment = CurrentAssignment()

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
                    C_PetJournal.PetIsSummonable(
                        assignment.id
                    ) ~= false
            else
                usableState = true
            end

            resourceState = false
            ApplyColor()
            return
        end

        local spellID =
            GetAssignmentSpellID(assignment)

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
                C_Item.IsUsableItem(
                    assignment.id
                )

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
        local assignment = CurrentAssignment()

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

        local spellID =
            GetAssignmentSpellID(assignment)

        if spellID then
            local inRange =
                C_Spell.IsSpellInRange(spellID)

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
                outOfRangeState = false
            end

            ApplyColor()
            return
        end

        outOfRangeState = false
        ApplyColor()
    end

    local function UpdateCheckedState()
        local assignment = CurrentAssignment()

        if assignment
            and assignment.type == "battlepet"
        then
            button:SetChecked(
                C_PetJournal.GetSummonedPetGUID()
                    == assignment.id
            )

        elseif assignment
            and assignment.type == "mount"
        then
            local _, _, _, active =
                C_MountJournal.GetMountInfoByID(
                    assignment.id
                )

            button:SetChecked(active == true)

        else
            button:SetChecked(false)
        end
    end

    local function UpdateVisualState()
        button:UpdateProcGlow()
        UpdateUsability()
        UpdateRange()
        UpdateCheckedState()
    end

    -- ========================================================
    -- ACTIVE PAGE VISUALS
    -- ========================================================

    local suppressRelease = false
    local suppressedClick = false
    local cursorHandled = false
    local placementGeneration = 0

    local function RefreshPageVisuals()
        UpdateIcon()
        UpdateCooldown()
        UpdateCount()
        UpdateVisualState()
    end

    local function UpdateAssignment()
        if InCombatLockdown() then return end

        local settings = ns.db
            and ns.db.bars
            and ns.db.bars[barID]

        if not settings then return end

        ConfigureSecurePages(
            button,
            settings,
            barID,
            buttonID
        )

        if button.RefreshCasting then
            button:RefreshCasting()
        end

        activePage =
            activePageByBar[barID] or 1

        if button.UpdateFlyout then
            button:UpdateFlyout()
        end

        if suppressRelease then
            button:SetAttribute("type", nil)
        end

        RefreshPageVisuals()
    end

    button:HookScript(
        "OnAttributeChanged",
        function(_, key, page)
            if key ~= "miab-currentpage" then
                return
            end

            if issecretvalue
                and issecretvalue(page)
            then
                return
            end

            page = tonumber(page)

            if not page
                or page < 1
                or page > MAX_PAGES
            then
                return
            end

            activePage = page
            activePageByBar[barID] = page

            RefreshPageVisuals()

            if not InCombatLockdown()
                and button.UpdateFlyout
            then
                button:UpdateFlyout()
            end
        end
    )

    -- ========================================================
    -- DRAG AND DROP
    -- ========================================================

    local function AssignFromCursor()
        if InCombatLockdown() then
            return false
        end

        local cursorType, info1, info2, info3 =
            GetCursorInfo()

        local assignment

        if cursorType == "flyout" then
            assignment = {
                type = "flyout",
                id = info1,
            }

        elseif cursorType == "spell" then
            local mountID =
                info3
                and C_MountJournal.GetMountFromSpell(
                    info3
                )

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

            if actionType == "flyout" then
                assignment = {
                    type = "flyout",
                    id = actionID,
                }

            elseif actionType == "spell" then
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
                    C_MountJournal.GetMountFromSpell(
                        actionID
                    )

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

        local previous = CurrentAssignment()

        ClearCursor()

        if previous
            and not PickupAssignment(previous)
        then
            PickupAssignment(assignment)
            return false
        end

        if not SetAssignment(
            barID,
            buttonID,
            assignment
        ) then
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
        placementGeneration =
            placementGeneration + 1

        local generation = placementGeneration

        button:SetAttribute("type", nil)

        C_Timer.After(0, function()
            if generation ~= placementGeneration then
                return
            end

            cursorHandled = false

            if not InCombatLockdown() then
                UpdateAssignment()
            end
        end)
    end

    button:SetScript(
        "OnReceiveDrag",
        function()
            if InCombatLockdown()
                or cursorHandled
                or not GetCursorInfo()
            then
                return
            end

            ArmPlacementGuard()
            AssignFromCursor()

            button:SetAttribute("type", nil)
        end
    )

    button:HookScript(
        "PreClick",
        function(self, mouseButton, down)
            suppressedClick = false

            if InCombatLockdown() then
                return
            end

            if down then
                placementGeneration =
                    placementGeneration + 1

                suppressRelease = false
                cursorHandled = false

                if GetCursorInfo() then
                    suppressedClick = true
                    self:SetAttribute("type", nil)
                end

                -- Do not re-register paging immediately
                -- before a normal spell click.
                return
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

                self:SetAttribute("type", nil)
            end
        end
    )

    button:HookScript(
        "PostClick",
        function(self, mouseButton, down)
            if InCombatLockdown() then
                return
            end

            if not down then
                local restore =
                    suppressRelease
                    or suppressedClick
                    or cursorHandled

                suppressRelease = false
                suppressedClick = false
                cursorHandled = false

                if restore then
                    UpdateAssignment()
                end

            elseif not suppressedClick then
                UpdateCooldown()
                UpdateCheckedState()
            end

            local assignment = CurrentAssignment()

            if ns.CloseMIABFlyouts
                and (
                    not assignment
                    or assignment.type ~= "flyout"
                )
            then
                ns.CloseMIABFlyouts()
            end
        end
    )

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

            if locked and not IsShiftKeyDown() then
                return
            end

            local assignment =
                CurrentAssignment()

            if not PickupAssignment(assignment) then
                return
            end

            suppressRelease = true
            cursorHandled = false

            SetAssignment(barID, buttonID, nil)
            UpdateAssignment()
        end
    )

    button:SetScript(
        "OnEnter",
        function(self)
            UpdateDragHighlight()

            local assignment =
                CurrentAssignment()

            if not assignment then return end

            GameTooltip:SetOwner(
                self,
                "ANCHOR_RIGHT"
            )

            if assignment.type == "flyout" then
                local name =
                    GetFlyoutInfo
                    and GetFlyoutInfo(assignment.id)

                if name then
                    GameTooltip:SetText(name)
                end

            elseif assignment.type == "spell" then
                GameTooltip:SetSpellByID(
                    assignment.id
                )

            elseif assignment.type == "item" then
                GameTooltip:SetItemByID(
                    assignment.id
                )

            elseif assignment.type == "macro" then
                local macroName =
                    GetMacroInfo(assignment.id)

                if macroName then
                    GameTooltip:SetText(macroName)
                end

            elseif assignment.type == "mount" then
                local mountName, spellID =
                    C_MountJournal.GetMountInfoByID(
                        assignment.id
                    )

                if spellID then
                    GameTooltip:SetSpellByID(spellID)

                elseif mountName then
                    GameTooltip:SetText(mountName)
                end

            elseif assignment.type == "battlepet" then
                local _, customName,
                    _, _, _, _, _, speciesName =
                    C_PetJournal.GetPetInfoByPetID(
                        assignment.id
                    )

                local petName =
                    customName or speciesName

                if petName then
                    GameTooltip:SetText(petName)
                    GameTooltip:AddLine(
                        "Battle Pet",
                        0.7,
                        0.7,
                        0.7
                    )
                end
            end

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

    -- ========================================================
    -- ACTION UPDATES
    -- ========================================================

    local eventFrame = CreateFrame("Frame")

    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
    eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("SPELLS_CHANGED")
    eventFrame:RegisterEvent("UPDATE_MACROS")
    eventFrame:RegisterEvent("PET_JOURNAL_LIST_UPDATE")
    eventFrame:RegisterEvent("UPDATE_SUMMONPETS_ACTION")

    eventFrame:SetScript(
        "OnEvent",
        function(_, event)
            if event == "PLAYER_REGEN_ENABLED" then
                placementGeneration =
                    placementGeneration + 1

                suppressRelease = false
                suppressedClick = false
                cursorHandled = false

                UpdateAssignment()
                return
            end

            if event == "UPDATE_MACROS"
                or event == "SPELLS_CHANGED"
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
        end
    )

    local elapsedSinceStateUpdate = 0

    button:SetScript(
        "OnUpdate",
        function(_, elapsed)
            if not button:IsShown() then
                ns.SetDragHighlight(button, false)
                return
            end

            if button:IsMouseOver() then
                UpdateDragHighlight()

            elseif dragHighlight:IsShown() then
                ns.SetDragHighlight(button, false)
            end

            local assignment =
                CurrentAssignment()

            if not assignment then
                elapsedSinceStateUpdate = 0

                if icon:IsShown()
                    or count:GetText() ~= ""
                then
                    UpdateAssignment()
                end

                return
            end

            elapsedSinceStateUpdate =
                elapsedSinceStateUpdate + elapsed

            if elapsedSinceStateUpdate < 0.2 then
                return
            end

            elapsedSinceStateUpdate = 0

            UpdateCooldown()
            UpdateCount()
            UpdateVisualState()
        end
    )

    button.UpdateAssignment = UpdateAssignment
    button.RefreshVisualState = UpdateVisualState
    button.barID = barID
    button.buttonID = buttonID

    customButtons[button] = true
    UpdateAssignment()

    return button
end

-- ============================================================
-- BAR PAGING REFRESH
-- ============================================================

function ns.ConfigureCustomBarPaging(barID)
    if InCombatLockdown() then
        return false, "combat"
    end

    local settings = ns.db
        and ns.db.bars
        and ns.db.bars[barID]

    if not settings
        or settings.source ~= "custom"
    then
        return false, "unsupported"
    end

    ActivateSpecialization(settings)

    local bar =
        ns.Bars and ns.Bars[barID]

    if bar then
        for _, button in ipairs(
            bar.buttons or {}
        ) do
            if button.UpdateAssignment then
                button.UpdateAssignment()
            end
        end
    end

    return true
end

-- ============================================================
-- TEMPORARY ALPHA PAGING TEST COMMANDS
-- ============================================================
--
-- /miabpage 9 2           Edit Page 2 of Bar 9
-- /miabpage 9 auto        Return to automatic paging
-- /miabpage 9 shift 2     SHIFT switches to Page 2
-- /miabpage 9 shift off   Disable SHIFT paging
-- /miabpage 9 stealth 3   Stealth switches to Page 3
-- /miabpage 9 stealth off Remove stealth rule
-- /miabpage 9 status      Print the current page driver
--
-- Configuration is performed outside combat.
-- The registered driver performs action switching.
-- ============================================================

SLASH_MIABCUSTOMPAGE1 = "/miabpage"

SlashCmdList.MIABCUSTOMPAGE = function(message)
    local barText, command, value =
        message:match(
            "^(%S+)%s*(%S*)%s*(%S*)"
        )

    local barID = tonumber(barText)

    local settings =
        barID
        and ns.db
        and ns.db.bars
        and ns.db.bars[barID]

    local prefix =
        "|cff7fd5ffMythInc Paging:|r "

    if not settings
        or settings.source ~= "custom"
    then
        print(
            prefix
            .. "Usage: /miabpage <custom bar #> "
            .. "<page|auto|shift|ctrl|alt|stealth|status> "
            .. "[page|off]"
        )
        return
    end

    if InCombatLockdown() then
        print(
            prefix
            .. "Paging configuration cannot be changed in combat."
        )
        return
    end

    local pages = settings.actionPages or {}
    settings.actionPages = pages

    if command == "status" then
        local driver =
            BuildPageDriver(settings, barID)

        print(
            prefix
            .. "Bar "
            .. barID
            .. " driver: "
            .. driver
        )

        print(
            prefix
            .. "Editing Page "
            .. tostring(
                editPageByBar[barID] or "auto"
            )
        )

        return
    end

    if command == "auto" then
        ns.SetCustomBarEditPage(barID, nil)

        print(
            prefix
            .. "Bar "
            .. barID
            .. " editing stopped; automatic rules active."
        )
        return
    end

    local target = tonumber(command)

    if target then
        local okay, reason =
            ns.SetCustomBarEditPage(
                barID,
                target
            )

        if okay then
            print(
                prefix
                .. "Editing Bar "
                .. barID
                .. ", Page "
                .. target
            )
        else
            print(
                prefix
                .. "Cannot edit page: "
                .. tostring(reason)
            )
        end

        return
    end

    if command == "shift"
        or command == "ctrl"
        or command == "alt"
    then
        pages[command] =
            pages[command] or {}

        local entry = pages[command]

        if value == "off" then
            entry.enabled = false
        else
            local page = tonumber(value)

            if not page
                or page < 1
                or page > MAX_PAGES
                or page ~= math.floor(page)
            then
                print(
                    prefix
                    .. "Use a page number from 1 to "
                    .. MAX_PAGES
                    .. "."
                )
                return
            end

            entry.page = page
            entry.enabled = true
        end

        ns.ConfigureCustomBarPaging(barID)

        print(
            prefix
            .. "Bar "
            .. barID
            .. " "
            .. command
            .. " paging updated."
        )

        return
    end

    if command == "stealth" then
        pages.contextRules =
            pages.contextRules or {}

        for i = #pages.contextRules, 1, -1 do
            if pages.contextRules[i].condition
                == "stealth"
            then
                table.remove(
                    pages.contextRules,
                    i
                )
            end
        end

        if value ~= "off" then
            local page = tonumber(value)

            if not page
                or page < 1
                or page > MAX_PAGES
                or page ~= math.floor(page)
            then
                print(
                    prefix
                    .. "Use a page number from 1 to "
                    .. MAX_PAGES
                    .. "."
                )
                return
            end

            table.insert(
                pages.contextRules,
                1,
                {
                    enabled = true,
                    condition = "stealth",
                    page = page,
                }
            )
        end

        ns.ConfigureCustomBarPaging(barID)

        print(
            prefix
            .. "Bar "
            .. barID
            .. " stealth paging updated."
        )

        return
    end

    print(
        prefix
        .. "Unknown command. Use /miabpage "
        .. barID
        .. " status for the current rule."
    )
end
