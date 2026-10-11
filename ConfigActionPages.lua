
local addonName, ns = ...

function ns.CreateActionPagesConfigPage(parent, context)
    local widgets = ns.ConfigWidgets
    local colors = ns.Media.colors
    local font = ns.Media.font

    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:SetClipsChildren(true)

    local scroll = CreateFrame("ScrollFrame", nil, page)
    scroll:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    scroll:SetPoint(
        "BOTTOMRIGHT", page, "BOTTOMRIGHT", -17, 0
    )
    scroll:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1014, 360)
    scroll:SetScrollChild(content)

    local track = CreateFrame(
        "Slider", nil, page, "BackdropTemplate"
    )
    track:SetPoint("TOPRIGHT", page, "TOPRIGHT", -5, -4)
    track:SetPoint(
        "BOTTOMRIGHT", page, "BOTTOMRIGHT", -5, 4
    )
    track:SetWidth(4)
    track:SetOrientation("VERTICAL")
    track:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    track:SetBackdropColor(0.08, 0.09, 0.09, 0.9)
    track:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    track:SetMinMaxValues(0, 1)
    track:SetValueStep(1)

    local thumb = track:GetThumbTexture()
    thumb:SetWidth(8)
    thumb:SetHeight(35)
    thumb:SetVertexColor(unpack(colors.accent))

    local updatingScroll = false

    local function UpdateScroll()
        local maximum = math.max(
            0,
            content:GetHeight() - scroll:GetHeight()
        )

        updatingScroll = true
        track:SetMinMaxValues(0, math.max(1, maximum))
        track:SetValue(
            math.min(scroll:GetVerticalScroll(), maximum)
        )
        updatingScroll = false
        track:SetShown(maximum > 0)

        local ratio =
            scroll:GetHeight()
            / math.max(1, content:GetHeight())

        thumb:SetHeight(
            math.min(
                track:GetHeight(),
                math.max(
                    28,
                    track:GetHeight() * ratio
                )
            )
        )
    end

    track:SetScript("OnValueChanged", function(_, value)
        if not updatingScroll then
            scroll:SetVerticalScroll(value)
        end
    end)

    scroll:SetScript("OnMouseWheel", function(_, delta)
        local maximum = math.max(
            0,
            content:GetHeight() - scroll:GetHeight()
        )

        local value = math.max(
            0,
            math.min(
                maximum,
                scroll:GetVerticalScroll() - delta * 45
            )
        )

        scroll:SetVerticalScroll(value)
        updatingScroll = true
        track:SetValue(value)
        updatingScroll = false
    end)

    scroll:SetScript("OnSizeChanged", UpdateScroll)

    local function Text(owner, value, size, x, y, muted)
        local label =
            owner:CreateFontString(nil, "OVERLAY")

        label:SetFont(font, size or 11, "OUTLINE")
        label:SetTextColor(
            unpack(muted and colors.muted or colors.text)
        )
        label:SetPoint(
            "TOPLEFT", owner, "TOPLEFT", x, y
        )
        label:SetJustifyH("LEFT")
        label:SetText(value or "")

        return label
    end

    local function SelectedBarID()
        return context.GetSelectedBarID()
    end

    local function SelectedBar()
        return ns.db
            and ns.db.bars
            and ns.db.bars[SelectedBarID()]
    end

    local function GetPages()
        local settings = SelectedBar()
        if not settings then return nil end

        settings.actionPages =
            settings.actionPages or {}

        local pages = settings.actionPages

        for _, name in ipairs({
            "shift", "ctrl", "alt"
        }) do
            pages[name] = pages[name] or {
                enabled = false,
                page =
                    name == "shift" and 2
                    or (name == "ctrl" and 3 or 4),
            }
        end

        pages.contextRules = pages.contextRules or {}

        if settings.source == "blizzard"
            and SelectedBarID() ~= 1
            and ns.EnsureIndependentRegularBarSets
        then
            pages =
                ns.EnsureIndependentRegularBarSets(
                    SelectedBarID()
                )
        end

        return pages
    end

    local function Message(message)
        print(
            "|cff7fd5ffMythInc Action Bars:|r "
            .. message
        )
    end

    local function ChangePages(change)
        if InCombatLockdown() then
            Message(
                "Action Pages cannot be configured during combat."
            )
            page:Refresh()
            return
        end

        local settings = SelectedBar()
        local pages = GetPages()

        if not settings or not pages then
            return
        end

        change(pages)

        if settings.source == "custom" then
            if ns.ConfigureCustomBarPaging then
                ns.ConfigureCustomBarPaging(
                    SelectedBarID()
                )
            end
        else
            ns.UpdateBar(SelectedBarID())
        end

        page:Refresh()
    end

    local popup = CreateFrame(
        "Frame",
        nil,
        UIParent,
        "BackdropTemplate"
    )
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(200)
    popup:SetSize(228, 80)
    popup:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    popup:SetBackdropColor(
        0.09, 0.11, 0.13, 0.98
    )
    popup:SetBackdropBorderColor(
        unpack(colors.accent)
    )
    popup:EnableMouse(true)
    popup:SetClampedToScreen(true)
    popup:Hide()

    local dismissLayer = CreateFrame("Button", nil, UIParent)
    dismissLayer:SetAllPoints(UIParent)
    dismissLayer:SetFrameStrata("FULLSCREEN_DIALOG")
    dismissLayer:SetFrameLevel(199)
    dismissLayer:EnableMouse(true)
    dismissLayer:RegisterForClicks("AnyUp")
    dismissLayer:SetScript("OnClick", function()
        popup:Hide()
    end)
    dismissLayer:Hide()

    popup:HookScript("OnHide", function()
        dismissLayer:Hide()
    end)

    local popupAnchor
    local popupOptions = {}
    local popupStart = 1
    local popupCallback
    local popupRows = {}
    local VISIBLE_OPTIONS = 7

    local function RefreshPopup()
        local count = math.min(
            VISIBLE_OPTIONS, #popupOptions
        )

        local height =
            count * 30
            + 10
            + (
                #popupOptions > VISIBLE_OPTIONS
                and 32 or 0
            )

        popup:SetHeight(height)

        for index, entry in ipairs(popupRows) do
            local option =
                popupOptions[popupStart + index - 1]

            entry:SetShown(
                option ~= nil and index <= count
            )

            if option then
                entry.label:SetText(option.label)
                entry.value = option.value
            end
        end

        if popup.previous then
            local paged =
                #popupOptions > VISIBLE_OPTIONS

            popup.previous:SetShown(paged)
            popup.next:SetShown(paged)
            popup.previous:SetEnabled(popupStart > 1)
            popup.next:SetEnabled(
                popupStart + VISIBLE_OPTIONS
                <= #popupOptions
            )
        end
    end

    for index = 1, VISIBLE_OPTIONS do
        local entry = CreateFrame(
            "Button",
            nil,
            popup,
            "BackdropTemplate"
        )
        entry:SetHeight(28)
        entry:SetPoint(
            "TOPLEFT", popup, "TOPLEFT",
            5, -5 - (index - 1) * 30
        )
        entry:SetPoint(
            "TOPRIGHT", popup, "TOPRIGHT",
            -5, -5 - (index - 1) * 30
        )
        entry:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
        })
        entry:SetBackdropColor(0, 0, 0, 0)
        entry.label = Text(entry, "", 11, 9, -7)

        entry:SetScript("OnEnter", function(self)
            self:SetBackdropColor(
                0.18, 0.31, 0.34, 0.9
            )
        end)

        entry:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0, 0, 0, 0)
        end)

        entry:SetScript("OnClick", function(self)
            popup:Hide()
            if popupCallback then
                popupCallback(self.value)
            end
        end)

        popupRows[index] = entry
    end

    local previous = widgets.CreateButton(
        popup,
        "Previous",
        100,
        25,
        6,
        -5
    )
    previous:ClearAllPoints()
    previous:SetPoint(
        "BOTTOMLEFT",
        popup,
        "BOTTOMLEFT",
        6,
        5
    )

    previous:SetScript("OnClick", function()
        popupStart = math.max(
            1,
            popupStart - VISIBLE_OPTIONS
        )
        RefreshPopup()
    end)

    local nextButton = widgets.CreateButton(
        popup,
        "Next",
        100,
        25,
        6,
        -5
    )
    nextButton:ClearAllPoints()
    nextButton:SetPoint(
        "BOTTOMRIGHT",
        popup,
        "BOTTOMRIGHT",
        -6,
        5
    )

    nextButton:SetScript("OnClick", function()
        popupStart = math.min(
            math.max(
                1,
                #popupOptions - VISIBLE_OPTIONS + 1
            ),
            popupStart + VISIBLE_OPTIONS
        )
        RefreshPopup()
    end)

    popup.previous = previous
    popup.next = nextButton
    popup:EnableMouseWheel(true)

    popup:SetScript("OnMouseWheel", function(_, delta)
        popupStart = math.max(
            1,
            math.min(
                math.max(
                    1,
                    #popupOptions - VISIBLE_OPTIONS + 1
                ),
                popupStart - delta
            )
        )
        RefreshPopup()
    end)

    local function OpenPopup(
        anchor,
        options,
        callback,
        width
    )
        if popup:IsShown() then
            local sameAnchor = popupAnchor == anchor
            popup:Hide()
            if sameAnchor then
                return
            end
        end

        popupAnchor = anchor
        popupOptions = options
        popupCallback = callback
        popupStart = 1
        popup:SetWidth(width or 228)
        RefreshPopup()
        popup:ClearAllPoints()

        local bottom = anchor:GetBottom()
        local height = popup:GetHeight()

        if bottom and bottom < height + 25 then
            popup:SetPoint(
                "BOTTOMLEFT",
                anchor,
                "TOPLEFT",
                0,
                3
            )
        else
            popup:SetPoint(
                "TOPLEFT",
                anchor,
                "BOTTOMLEFT",
                0,
                -3
            )
        end

        dismissLayer:Show()
        popup:Show()
    end

    local function SetName(number)
        if number == 1 then
            return "Default Set"
        end

        return "Set " .. number
    end

    local function CustomSetCount()
        local settings = SelectedBar()
        if not settings then return 1 end

        local pages = GetPages()

        local count = math.max(
            1,
            math.min(
                12,
                tonumber(pages.visibleSetCount) or 1
            )
        )

        for _, name in ipairs({
            "shift", "ctrl", "alt"
        }) do
            local entry = pages[name]

            if entry and entry.enabled then
                count = math.max(
                    count,
                    tonumber(entry.page) or 1
                )
            end
        end

        for _, rule in ipairs(pages.contextRules) do
            count = math.max(
                count,
                tonumber(rule.page) or 1
            )
        end

        if ns.GetBarActionSetAssignment then
            for number = count + 1, 12 do
                for buttonID = 1, 12 do
                    if ns.GetBarActionSetAssignment(
                        SelectedBarID(),
                        buttonID,
                        number
                    ) then
                        count = math.max(count, number)
                        break
                    end
                end
            end
        end

        return math.min(
            12,
            math.floor(count)
        )
    end

    local function CustomSetOptions()
        local result = {}

        for number = 1, CustomSetCount() do
            result[#result + 1] = {
                value = number,
                label = SetName(number),
            }
        end

        return result
    end

    local customFrames = {}

    local customHeading = Text(
        content,
        "Action Sets",
        12,
        8,
        -4
    )
    customFrames[#customFrames + 1] = customHeading

    local previewByBar = {}

    local editorSection = widgets.CreateSection(
        content,
        "Edit Bar Contents",
        1012,
        161,
        0,
        -46
    )
    customFrames[#customFrames + 1] = editorSection

    local explanation = Text(
        editorSection,
        "An Action Set is a collection of abilities shown in this same bar. Switching sets never creates another bar.",
        10,
        20,
        -39,
        true
    )
    explanation:SetWidth(955)

    local primaryExplanation = Text(
        editorSection,
        "Bar 1 is the primary Blizzard action bar. Its action sets and automatic stance, stealth, and vehicle switching are controlled by the game. Edit its abilities directly on the bar. Use Bars 2-8 or custom bars for independent action sets and custom switching rules.",
        11,
        20,
        -46,
        true
    )
    primaryExplanation:SetWidth(930)
    primaryExplanation:SetWordWrap(true)

    local chooseSet

    chooseSet = widgets.CreateButton(
        editorSection,
        "Choose Action Set",
        220,
        30,
        20,
        -69,
        function()
            OpenPopup(
                chooseSet,
                CustomSetOptions(),
                function(number)
                    if InCombatLockdown() then
                        Message(
                            "Action sets cannot be edited in combat."
                        )
                        return
                    end

                    local barID = SelectedBarID()

                    if ns.SetBarActionSetEditPage(
                        barID,
                        number
                    ) then
                        previewByBar[barID] = number
                    end

                    page:Refresh()
                end,
                220
            )
        end
    )

    local autoButton = widgets.CreateButton(
        editorSection,
        "Use Automatic Switching",
        220,
        30,
        259,
        -69,
        function()
            if InCombatLockdown() then
                Message(
                    "Action sets cannot be edited in combat."
                )
                return
            end

            local barID = SelectedBarID()

            if ns.SetBarActionSetEditPage(
                barID,
                nil
            ) then
                previewByBar[barID] = nil
            end

            page:Refresh()
        end
    )

    local addSetButton = widgets.CreateButton(
        editorSection,
        "+ Add Action Set",
        180,
        30,
        498,
        -69,
        function()
            if InCombatLockdown() then
                Message(
                    "Action sets cannot be edited in combat."
                )
                return
            end

            local count = CustomSetCount()
            if count >= 12 then return end

            local barID = SelectedBarID()
            GetPages().visibleSetCount = count + 1

            if ns.SetBarActionSetEditPage(
                barID,
                count + 1
            ) then
                previewByBar[barID] = count + 1
            end

            page:Refresh()
        end
    )

    local previewLabel = Text(
        editorSection,
        "",
        11,
        20,
        -120,
        true
    )
    previewLabel:SetWidth(955)

    local customModifiers = {}

    for index, modifier in ipairs({
        "shift", "ctrl", "alt"
    }) do
        local title = string.upper(modifier)

        local section = widgets.CreateSection(
            content,
            title .. " Modifier",
            324,
            213,
            (index - 1) * 344,
            -226
        )
        customFrames[#customFrames + 1] = section

        local checkbox = widgets.CreateCheckButton(
            section,
            "Enable " .. title .. " Switching",
            20,
            -42,
            function()
                local pages = GetPages()

                return pages
                    and pages[modifier]
                    and pages[modifier].enabled
                    or false
            end,
            function(value)
                ChangePages(function(pages)
                    pages[modifier].enabled = value
                end)
            end
        )

        Text(
            section,
            "SWITCH TO ACTION SET",
            9,
            20,
            -87,
            true
        )

        local target

        target = widgets.CreateButton(
            section,
            "Default Set",
            280,
            31,
            20,
            -121,
            function()
                OpenPopup(
                    target,
                    CustomSetOptions(),
                    function(number)
                        ChangePages(function(pages)
                            pages[modifier].page = number
                        end)
                    end,
                    278
                )
            end
        )

        customModifiers[modifier] = {
            section = section,
            checkbox = checkbox,
            target = target,
        }
    end

    local CONDITIONS = {
        { value = "stealth", label = "Stealth" },
        { value = "combat", label = "In Combat" },
        { value = "nocombat", label = "Out of Combat" },
        { value = "friendly", label = "Friendly Target" },
        { value = "hostile", label = "Hostile Target" },
        { value = "mounted", label = "Mounted" },
        { value = "flying", label = "Flying" },
        { value = "swimming", label = "Swimming" },
        { value = "pet", label = "Pet Active" },
        { value = "vehicle", label = "Vehicle UI" },
        { value = "override", label = "Override Bar" },
        { value = "possess", label = "Possess Bar" },
    }

    for i = 1, 10 do
        CONDITIONS[#CONDITIONS + 1] = {
            value = "form:" .. i,
            label = "Form / Stance " .. i,
        }
    end

    local CONDITION_NAMES = {}

    for _, item in ipairs(CONDITIONS) do
        CONDITION_NAMES[item.value] = item.label
    end

    local rulesSection = widgets.CreateSection(
        content,
        "Automatic Set Switching",
        1012,
        98,
        0,
        -458
    )

    Text(
        rulesSection,
        "First matching rule wins. Modifier switching applies only when no automatic rule matches.",
        10,
        20,
        -40,
        true
    )

    local addRule = widgets.CreateButton(
        rulesSection,
        "+ Add Rule",
        135,
        29,
        847,
        -34,
        function()
            ChangePages(function(pages)
                if #pages.contextRules < 10 then
                    table.insert(
                        pages.contextRules,
                        {
                            enabled = true,
                            condition = "stealth",
                            page = math.min(
                                2,
                                CustomSetCount()
                            ),
                        }
                    )
                end
            end)
        end
    )

    local emptyLabel = Text(
        rulesSection,
        "No automatic rules configured.",
        11,
        20,
        -81,
        true
    )

    local ruleRows = {}

    for index = 1, 10 do
        local position = index

        local row = CreateFrame(
            "Frame",
            nil,
            rulesSection
        )
        row:SetPoint(
            "TOPLEFT",
            rulesSection,
            "TOPLEFT",
            16,
            -84 - (index - 1) * 45
        )
        row:SetSize(972, 38)

        Text(
            row,
            tostring(index) .. ".",
            11,
            0,
            -10,
            true
        )

        local enabled = widgets.CreateCheckButton(
            row,
            "Active",
            35,
            -7,
            function()
                local pages = GetPages()
                local rule =
                    pages and pages.contextRules[position]

                return rule
                    and rule.enabled ~= false
                    or false
            end,
            function(value)
                ChangePages(function(pages)
                    if pages.contextRules[position] then
                        pages.contextRules[position].enabled =
                            value
                    end
                end)
            end
        )

        local conditionButton

        conditionButton = widgets.CreateButton(
            row,
            "Stealth",
            210,
            30,
            173,
            -3,
            function()
                OpenPopup(
                    conditionButton,
                    CONDITIONS,
                    function(value)
                        ChangePages(function(pages)
                            if pages.contextRules[position] then
                                pages.contextRules[position].condition =
                                    value
                            end
                        end)
                    end,
                    215
                )
            end
        )

        local targetButton

        targetButton = widgets.CreateButton(
            row,
            "Set 2",
            180,
            30,
            397,
            -3,
            function()
                OpenPopup(
                    targetButton,
                    CustomSetOptions(),
                    function(value)
                        ChangePages(function(pages)
                            if pages.contextRules[position] then
                                pages.contextRules[position].page =
                                    value
                            end
                        end)
                    end,
                    220
                )
            end
        )

        local up = widgets.CreateButton(
            row,
            "Up",
            68,
            30,
            590,
            -3,
            function()
                ChangePages(function(pages)
                    local rules = pages.contextRules

                    if position > 1 and rules[position] then
                        rules[position - 1], rules[position] =
                            rules[position], rules[position - 1]
                    end
                end)
            end
        )

        local down = widgets.CreateButton(
            row,
            "Down",
            68,
            30,
            665,
            -3,
            function()
                ChangePages(function(pages)
                    local rules = pages.contextRules

                    if position < #rules
                        and rules[position]
                    then
                        rules[position + 1], rules[position] =
                            rules[position], rules[position + 1]
                    end
                end)
            end
        )

        local remove = widgets.CreateButton(
            row,
            "Remove",
            95,
            30,
            758,
            -3,
            function()
                ChangePages(function(pages)
                    if pages.contextRules[position] then
                        table.remove(
                            pages.contextRules,
                            position
                        )
                    end
                end)
            end
        )

        ruleRows[index] = {
            frame = row,
            enabled = enabled,
            condition = conditionButton,
            target = targetButton,
            up = up,
            down = down,
            remove = remove,
        }
    end

    local note = Text(
        content,
        "",
        10,
        12,
        -580,
        true
    )
    note:SetWidth(980)

    page.Refresh = function()
        if not InCombatLockdown() then
            for otherBarID in pairs(previewByBar) do
                if otherBarID ~= SelectedBarID() then
                    ns.SetBarActionSetEditPage(
                        otherBarID,
                        nil
                    )
                    previewByBar[otherBarID] = nil
                end
            end
        end

        popup:Hide()

        local settings = SelectedBar()
        local barID = SelectedBarID()

        local available = settings and (
            settings.source == "custom"
            or (
                settings.source == "blizzard"
                and barID ~= 1
            )
        )

        local primary =
            settings
            and settings.source == "blizzard"
            and barID == 1

        for _, frame in ipairs(customFrames) do
            frame:SetShown(
                available or primary or false
            )
        end

        customHeading:SetShown(
            available or primary or false
        )
        editorSection:SetShown(
            available or primary or false
        )
        explanation:SetShown(available or false)
        primaryExplanation:SetShown(primary or false)
        chooseSet:SetShown(available or false)
        autoButton:SetShown(available or false)
        addSetButton:SetShown(available or false)
        previewLabel:SetShown(available or false)

        for _, data in pairs(customModifiers) do
            data.section:SetShown(available or false)
        end

        rulesSection:SetShown(available or false)
        note:SetShown(available or false)

        if primary then
            editorSection:SetHeight(134)
            content:SetHeight(210)
        elseif available then
            editorSection:SetHeight(161)
            local editingPage = previewByBar[barID]

            chooseSet:SetText(
                editingPage
                and ("Editing: " .. SetName(editingPage))
                or "Choose Action Set"
            )

            autoButton:SetEnabled(
                editingPage ~= nil
            )
            addSetButton:SetEnabled(
                CustomSetCount() < 12
            )

            previewLabel:SetText(
                editingPage
                and (
                    "Editing " .. SetName(editingPage)
                    .. ". Drag abilities onto this bar, then select Use Automatic Switching."
                )
                or "Automatic switching is active. Choose a set above to change its abilities."
            )

            local pages = GetPages()

            for modifier, data in pairs(customModifiers) do
                data.checkbox:Refresh()
                data.target:SetText(
                    SetName(
                        pages[modifier].page or 1
                    )
                )
            end

            local rules = pages.contextRules
            local ruleCount = math.min(10, #rules)
            local top = -458
            local sectionHeight =
                98 + 45 * ruleCount

            rulesSection:ClearAllPoints()
            rulesSection:SetPoint(
                "TOPLEFT",
                content,
                "TOPLEFT",
                0,
                top
            )
            rulesSection:SetHeight(sectionHeight)
            emptyLabel:SetShown(ruleCount == 0)

            for index, data in ipairs(ruleRows) do
                local rule = rules[index]
                data.frame:SetShown(rule ~= nil)

                if rule then
                    data.enabled:Refresh()
                    data.condition:SetText(
                        CONDITION_NAMES[rule.condition]
                        or rule.condition
                        or "Condition"
                    )

                    local targetPage =
                        tonumber(rule.page) or 1

                    data.target:SetText(
                        SetName(targetPage)
                    )
                    data.up:SetEnabled(index > 1)
                    data.down:SetEnabled(index < #rules)
                end
            end

            addRule:SetEnabled(#rules < 10)

            note:ClearAllPoints()
            note:SetPoint(
                "TOPLEFT",
                rulesSection,
                "BOTTOMLEFT",
                12,
                -12
            )
            note:SetText(
                settings.source == "blizzard"
                and "The Default Set keeps this bar's original Blizzard actions. Added sets are independent and saved separately by specialization."
                or "Each action set belongs to this custom bar and is saved separately by specialization."
            )
            content:SetHeight(
                -top + sectionHeight + 54
            )
        else
            content:SetHeight(300)
        end

        UpdateScroll()
    end

    page.ResetScroll = function()
        popup:Hide()
        scroll:SetVerticalScroll(0)
        track:SetValue(0)
        UpdateScroll()
    end

    page:SetScript("OnHide", function()
        popup:Hide()

        if InCombatLockdown() then return end

        for barID in pairs(previewByBar) do
            ns.SetBarActionSetEditPage(barID, nil)
            previewByBar[barID] = nil
        end
    end)

    page:Hide()
    UpdateScroll()

    return page
end
