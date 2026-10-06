local addonName, ns = ...

function ns.CreateActionPagesConfigPage(
    parent,
    context
)
    local widgets =
        ns.ConfigWidgets

    local media =
        ns.Media

    local colors =
        media.colors

    local font =
        media.font

    local page =
        CreateFrame(
            "Frame",
            nil,
            parent
        )

    page:SetAllPoints()
    page:SetClipsChildren(true)

    local content =
        CreateFrame(
            "Frame",
            nil,
            page
        )

    content:SetWidth(1020)
    content:SetHeight(430)

    local controls = {}
    local modifierControls = {}

    local scrollOffset = 0
    local scrollStep = 45

    local BAR_TO_PAGE = {
        [1] = 1,
        [2] = 6,
        [3] = 5,
        [4] = 4,
        [5] = 3,
        [6] = 13,
        [7] = 14,
        [8] = 15,
    }

    local PAGE_TO_BAR = {
        [1] = 1,
        [6] = 2,
        [5] = 3,
        [4] = 4,
        [3] = 5,
        [13] = 6,
        [14] = 7,
        [15] = 8,
    }

    local scrollTrack =
        CreateFrame(
            "Frame",
            nil,
            page,
            "BackdropTemplate"
        )

    scrollTrack:SetWidth(4)

    scrollTrack:SetPoint(
        "TOPRIGHT",
        page,
        "TOPRIGHT",
        -5,
        -4
    )

    scrollTrack:SetPoint(
        "BOTTOMRIGHT",
        page,
        "BOTTOMRIGHT",
        -5,
        4
    )

    scrollTrack:SetBackdrop({
        bgFile =
            "Interface\\Buttons\\WHITE8x8",
    })

    scrollTrack:SetBackdropColor(
        0.08,
        0.09,
        0.09,
        0.9
    )

    scrollTrack:EnableMouse(true)

    local scrollThumb =
        CreateFrame(
            "Frame",
            nil,
            scrollTrack,
            "BackdropTemplate"
        )

    scrollThumb:SetWidth(8)

    scrollThumb:SetBackdrop({
        bgFile =
            "Interface\\Buttons\\WHITE8x8",
    })

    scrollThumb:SetBackdropColor(
        unpack(colors.accent)
    )

    scrollThumb:EnableMouse(true)

    scrollThumb:RegisterForDrag(
        "LeftButton"
    )

    local dragging = false
    local dragOffset = 0

    local function GetMaxScroll()
        local viewportHeight =
            page:GetHeight()

        local contentHeight =
            content:GetHeight()

        return math.max(
            0,
            contentHeight
                - viewportHeight
        )
    end

    local function UpdateScrollbar()
        local viewportHeight =
            page:GetHeight()

        local contentHeight =
            content:GetHeight()

        local trackHeight =
            scrollTrack:GetHeight()

        local maxScroll =
            GetMaxScroll()

        if viewportHeight <= 0
            or contentHeight <= 0
            or trackHeight <= 0
            or maxScroll <= 0
        then
            scrollTrack:Hide()
            return
        end

        scrollTrack:Show()

        local visibleRatio =
            math.min(
                1,
                viewportHeight
                    / contentHeight
            )

        local thumbHeight =
            math.max(
                28,
                trackHeight
                    * visibleRatio
            )

        thumbHeight =
            math.min(
                trackHeight,
                thumbHeight
            )

        scrollThumb:SetHeight(
            thumbHeight
        )

        local availableTravel =
            math.max(
                0,
                trackHeight
                    - thumbHeight
            )

        local scrollRatio = 0

        if maxScroll > 0 then
            scrollRatio =
                scrollOffset
                / maxScroll
        end

        local thumbOffset =
            availableTravel
            * scrollRatio

        scrollThumb:ClearAllPoints()

        scrollThumb:SetPoint(
            "TOP",
            scrollTrack,
            "TOP",
            0,
            -thumbOffset
        )
    end

    local function ApplyScroll()
        local maxScroll =
            GetMaxScroll()

        scrollOffset =
            math.max(
                0,
                math.min(
                    scrollOffset,
                    maxScroll
                )
            )

        content:ClearAllPoints()

        content:SetPoint(
            "TOPLEFT",
            page,
            "TOPLEFT",
            0,
            scrollOffset
        )

        UpdateScrollbar()
    end

    local function SetScrollFromThumbPosition(
        cursorY,
        preserveDragOffset
    )
        local trackTop =
            scrollTrack:GetTop()

        local trackHeight =
            scrollTrack:GetHeight()

        local thumbHeight =
            scrollThumb:GetHeight()

        if not trackTop
            or trackHeight <= 0
        then
            return
        end

        local effectiveScale =
            scrollTrack:GetEffectiveScale()

        local scaledCursorY =
            cursorY
            / effectiveScale

        local offset =
            trackTop
            - scaledCursorY

        if preserveDragOffset then
            offset =
                offset
                - dragOffset
        else
            offset =
                offset
                - (
                    thumbHeight
                    / 2
                )
        end

        local availableTravel =
            math.max(
                0,
                trackHeight
                    - thumbHeight
            )

        offset =
            math.max(
                0,
                math.min(
                    offset,
                    availableTravel
                )
            )

        local ratio = 0

        if availableTravel > 0 then
            ratio =
                offset
                / availableTravel
        end

        scrollOffset =
            GetMaxScroll()
            * ratio

        ApplyScroll()
    end

    page:EnableMouseWheel(true)

    page:SetScript(
        "OnMouseWheel",
        function(_, delta)
            if delta < 0 then
                scrollOffset =
                    scrollOffset
                    + scrollStep
            elseif delta > 0 then
                scrollOffset =
                    scrollOffset
                    - scrollStep
            end

            ApplyScroll()
        end
    )

    scrollTrack:SetScript(
        "OnMouseDown",
        function(_, button)
            if button ~= "LeftButton" then
                return
            end

            local _,
                cursorY =
                GetCursorPosition()

            SetScrollFromThumbPosition(
                cursorY,
                false
            )
        end
    )

    scrollThumb:SetScript(
        "OnDragStart",
        function()
            dragging = true

            local _,
                cursorY =
                GetCursorPosition()

            local effectiveScale =
                scrollTrack:GetEffectiveScale()

            local scaledCursorY =
                cursorY
                / effectiveScale

            local thumbTop =
                scrollThumb:GetTop()

            if thumbTop then
                dragOffset =
                    thumbTop
                    - scaledCursorY
            else
                dragOffset = 0
            end
        end
    )

    scrollThumb:SetScript(
        "OnDragStop",
        function()
            dragging = false
        end
    )

    scrollThumb:SetScript(
        "OnUpdate",
        function()
            if not dragging then
                return
            end

            local _,
                cursorY =
                GetCursorPosition()

            SetScrollFromThumbPosition(
                cursorY,
                true
            )
        end
    )

    scrollThumb:SetScript(
        "OnEnter",
        function(self)
            self:SetBackdropColor(
                unpack(
                    colors.hoverBorder
                        or colors.accent
                )
            )
        end
    )

    scrollThumb:SetScript(
        "OnLeave",
        function(self)
            self:SetBackdropColor(
                unpack(colors.accent)
            )
        end
    )

    page:SetScript(
        "OnSizeChanged",
        function()
            ApplyScroll()
        end
    )

    local function SetFont(
        fontString,
        size,
        muted
    )
        fontString:SetFont(
            font,
            size,
            "OUTLINE"
        )

        fontString:SetTextColor(
            unpack(
                muted
                    and colors.muted
                    or colors.text
            )
        )
    end

    local function GetBarID()
        return context.GetSelectedBarID()
    end

    local function GetSettings()
        return ns.GetBarActionPageSettings(
            GetBarID()
        )
    end

    local function GetBarLabel(
        barID
    )
        local settings =
            ns.db
            and ns.db.bars
            and ns.db.bars[
                barID
            ]

        local name =
            settings
            and settings.name
            or (
                "Bar "
                .. barID
            )

        if name == "Bar " .. barID then
            return name
        end

        return "Bar "
            .. barID
            .. " - "
            .. name
    end

    local function GetTargetDescription(
        modifier
    )
        local settings =
            GetSettings()

        if not settings
            or not settings[
                modifier
            ]
        then
            return "No target selected"
        end

        local rawPage =
            settings[
                modifier
            ].page

        local targetBar =
            PAGE_TO_BAR[
                rawPage
            ]

        if targetBar then
            return GetBarLabel(
                targetBar
            )
        end

        return "Special Page "
            .. tostring(
                rawPage
            )
    end

    local description =
        content:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        description,
        11,
        true
    )

    description:SetPoint(
        "TOPLEFT",
        content,
        "TOPLEFT",
        8,
        -4
    )

    description:SetWidth(
        980
    )

    description:SetJustifyH(
        "LEFT"
    )

    description:SetText(
        ""
    )

    local baseLabel =
        content:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        baseLabel,
        11,
        false
    )

    baseLabel:SetPoint(
        "TOPLEFT",
        description,
        "TOPLEFT",
        8,
        -4
    )

    local unsupportedText =
        content:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        unsupportedText,
        12,
        true
    )

    unsupportedText:SetPoint(
        "TOPLEFT",
        baseLabel,
        "BOTTOMLEFT",
        0,
        -26
    )

    unsupportedText:SetWidth(
        980
    )

    unsupportedText:SetJustifyH(
        "LEFT"
    )

    unsupportedText:SetText(
        "Action Pages are currently available only for Blizzard-backed Bars 1-8. Custom action bars will receive their own paging system later."
    )

    unsupportedText:Hide()

    local function ApplyEnabled(
        modifier,
        enabled
    )
        local success,
            reason =
            ns.SetBarModifierPageEnabled(
                GetBarID(),
                modifier,
                enabled
            )

        if not success
            and reason == "combat"
        then
            print(
                "|cff7fd5ffMythInc Action Bars:|r Action Pages cannot be changed during combat."
            )

            return
        end

        page:Refresh()
    end

    local function ApplyTargetBar(
        modifier,
        targetBarID
    )
        local pageNumber =
            BAR_TO_PAGE[
                targetBarID
            ]

        if not pageNumber then
            return
        end

        local success,
            reason =
            ns.SetBarModifierPage(
                GetBarID(),
                modifier,
                pageNumber
            )

        if not success
            and reason == "combat"
        then
            print(
                "|cff7fd5ffMythInc Action Bars:|r Action Pages cannot be changed during combat."
            )

            return
        end

        page:Refresh()
    end

    local function CreateModifierSection(
        modifier,
        title,
        x
    )
        local section =
            widgets.CreateSection(
                content,
                title,
                324,
                220,
                x,
                -50
            )

        local enable =
            widgets.CreateCheckButton(
                section,
                "Enable "
                    .. title
                    .. " Page",
                20,
                -42,
                function()
                    local settings =
                        GetSettings()

                    return settings
                        and settings[
                            modifier
                        ]
                        and settings[
                            modifier
                        ].enabled
                        or false
                end,
                function(value)
                    ApplyEnabled(
                        modifier,
                        value
                    )
                end
            )

        controls[
            #controls + 1
        ] =
            enable

        local targetCaption =
            section:CreateFontString(
                nil,
                "OVERLAY"
            )

        SetFont(
            targetCaption,
            9,
            true
        )

        targetCaption:SetPoint(
            "TOPLEFT",
            section,
            "TOPLEFT",
            20,
            -86
        )

        targetCaption:SetText(
            "SHOW ACTIONS FROM"
        )

        local currentTarget =
            section:CreateFontString(
                nil,
                "OVERLAY"
            )

        SetFont(
            currentTarget,
            11,
            false
        )

        currentTarget:SetPoint(
            "TOPLEFT",
            targetCaption,
            "BOTTOMLEFT",
            0,
            -7
        )

        currentTarget:SetWidth(
            282
        )

        currentTarget:SetJustifyH(
            "LEFT"
        )

        local barButtons = {}

        for barID = 1, 8 do
            local index =
                barID - 1

            local column =
                index % 4

            local row =
                math.floor(
                    index / 4
                )

            local button =
                widgets.CreateTabButton(
                    section,
                    "Bar " .. barID,
                    67,
                    28,
                    20
                        + (
                            column
                            * 72
                        ),
                    -138
                        - (
                            row
                            * 34
                        ),
                    function()
                        ApplyTargetBar(
                            modifier,
                            barID
                        )
                    end
                )

            barButtons[
                barID
            ] =
                button
        end

        modifierControls[
            modifier
        ] = {
            section =
                section,

            enable =
                enable,

            currentTarget =
                currentTarget,

            barButtons =
                barButtons,
        }
    end

    CreateModifierSection(
        "shift",
        "SHIFT",
        0
    )

    CreateModifierSection(
        "ctrl",
        "CTRL",
        344
    )

    CreateModifierSection(
        "alt",
        "ALT",
        688
    )

    page.Refresh =
        function()
            local barID =
                GetBarID()

            local supported =
                ns.BarSupportsActionPages(
                    barID
                )

            local selectedSettings =
                ns.db
                and ns.db.bars
                and ns.db.bars[
                    barID
                ]

            if supported then
                unsupportedText:Hide()

                baseLabel:SetText(
                    "Normal actions: "
                    .. GetBarLabel(
                        barID
                    )
                )

                for modifier,
                    data
                in pairs(
                    modifierControls
                ) do
                    data.section:Show()

                    if data.enable.Refresh then
                        data.enable:Refresh()
                    end

                    local settings =
                        GetSettings()

                    local modifierSettings =
                        settings
                        and settings[
                            modifier
                        ]

                    local currentPage =
                        modifierSettings
                        and modifierSettings.page

                    local selectedTargetBar =
                        currentPage
                        and PAGE_TO_BAR[
                            currentPage
                        ]

                    data.currentTarget:SetText(
                        GetTargetDescription(
                            modifier
                        )
                    )

                    for targetBarID,
                        button
                    in pairs(
                        data.barButtons
                    ) do
                        button:SetSelected(
                            targetBarID
                                == selectedTargetBar
                        )
                    end
                end
            else
                baseLabel:SetText(
                    selectedSettings
                    and (
                        "Selected bar: "
                        .. selectedSettings.name
                    )
                    or ""
                )

                unsupportedText:Show()

                for _,
                    data
                in pairs(
                    modifierControls
                ) do
                    data.section:Hide()
                end
            end

            ApplyScroll()
        end

    page.ResetScroll =
        function()
            scrollOffset = 0
            ApplyScroll()
        end

    page:Hide()

    ApplyScroll()

    return page
end