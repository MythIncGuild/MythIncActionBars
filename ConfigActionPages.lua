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
    content:SetHeight(450)

    local controls = {}

    local scrollOffset = 0
    local scrollStep = 45

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
        return math.max(
            0,
            content:GetHeight()
                - page:GetHeight()
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

        local ratio = 0

        if maxScroll > 0 then
            ratio =
                scrollOffset
                / maxScroll
        end

        scrollThumb:ClearAllPoints()

        scrollThumb:SetPoint(
            "TOP",
            scrollTrack,
            "TOP",
            0,
            -(
                availableTravel
                * ratio
            )
        )
    end

    local function ApplyScroll()
        scrollOffset =
            math.max(
                0,
                math.min(
                    scrollOffset,
                    GetMaxScroll()
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

        local scale =
            scrollTrack:GetEffectiveScale()

        local cursor =
            cursorY / scale

        local offset =
            trackTop - cursor

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

        local travel =
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
                    travel
                )
            )

        local ratio = 0

        if travel > 0 then
            ratio =
                offset / travel
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
            else
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
            if button
                ~= "LeftButton"
            then
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

            local scale =
                scrollTrack:GetEffectiveScale()

            local cursor =
                cursorY / scale

            local thumbTop =
                scrollThumb:GetTop()

            if thumbTop then
                dragOffset =
                    thumbTop - cursor
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
        ApplyScroll
    )

    local supportedSection =
        widgets.CreateSection(
            content,
            "Action Pages",
            1012,
            126,
            0,
            0
        )

    local description =
        supportedSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    description:SetFont(
        font,
        11,
        "OUTLINE"
    )

    description:SetTextColor(
        unpack(colors.muted)
    )

    description:SetPoint(
        "TOPLEFT",
        supportedSection,
        "TOPLEFT",
        24,
        -42
    )

    description:SetWidth(950)
    description:SetJustifyH("LEFT")

    local basePageText =
        supportedSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    basePageText:SetFont(
        font,
        11,
        "OUTLINE"
    )

    basePageText:SetTextColor(
        unpack(colors.text)
    )

    basePageText:SetPoint(
        "TOPLEFT",
        supportedSection,
        "TOPLEFT",
        24,
        -84
    )

    local rulesSection =
        widgets.CreateSection(
            content,
            "Modifier Page Rules",
            1012,
            260,
            0,
            -142
        )

    local priorityText =
        rulesSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    priorityText:SetFont(
        font,
        11,
        "OUTLINE"
    )

    priorityText:SetTextColor(
        unpack(colors.muted)
    )

    priorityText:SetPoint(
        "TOPLEFT",
        rulesSection,
        "TOPLEFT",
        24,
        -42
    )

    priorityText:SetText(
        "If multiple modifiers are held: Alt takes priority over Ctrl, then Shift."
    )

    local unsupportedSection =
        widgets.CreateSection(
            content,
            "Action Pages",
            1012,
            150,
            0,
            0
        )

    local unsupportedText =
        unsupportedSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    unsupportedText:SetFont(
        font,
        11,
        "OUTLINE"
    )

    unsupportedText:SetTextColor(
        unpack(colors.muted)
    )

    unsupportedText:SetPoint(
        "TOPLEFT",
        unsupportedSection,
        "TOPLEFT",
        24,
        -46
    )

    unsupportedText:SetWidth(950)
    unsupportedText:SetJustifyH("LEFT")

    unsupportedText:SetText(
        "Modifier-based Action Pages currently apply to Blizzard-backed Bars 1–8. Custom MIAB bars will gain their own page system in a later version."
    )

    local function GetSettings()
        return ns.GetBarActionPageSettings(
            context.GetSelectedBarID()
        )
    end

    local function CreateModifierColumn(
        modifier,
        label,
        x
    )
        local checkbox =
            widgets.CreateCheckButton(
                rulesSection,
                "Enable " .. label,
                x,
                -84,
                function()
                    local settings =
                        GetSettings()

                    return settings
                        and settings[
                            modifier
                        ].enabled
                        or false
                end,
                function(value)
                    ns.SetBarModifierPageEnabled(
                        context.GetSelectedBarID(),
                        modifier,
                        value
                    )
                end
            )

        controls[
            #controls + 1
        ] =
            checkbox

        local slider =
            widgets.CreateSlider(
                rulesSection,
                label .. " Page",
                1,
                15,
                1,
                x,
                -132,
                function()
                    local settings =
                        GetSettings()

                    if not settings then
                        return 1
                    end

                    return settings[
                        modifier
                    ].page
                end,
                function(value)
                    ns.SetBarModifierPage(
                        context.GetSelectedBarID(),
                        modifier,
                        value
                    )
                end,
                nil,
                280
            )

        controls[
            #controls + 1
        ] =
            slider
    end

    CreateModifierColumn(
        "shift",
        "Shift",
        24
    )

    CreateModifierColumn(
        "ctrl",
        "Ctrl",
        354
    )

    CreateModifierColumn(
        "alt",
        "Alt",
        684
    )

    page.Refresh =
        function()
            local barID =
                context.GetSelectedBarID()

            local supported =
                ns.BarSupportsActionPages(
                    barID
                )

            supportedSection:SetShown(
                supported
            )

            rulesSection:SetShown(
                supported
            )

            unsupportedSection:SetShown(
                not supported
            )

            if supported then
                content:SetHeight(
                    420
                )

                description:SetText(
                    "Display a different set of actions while Shift, Ctrl, or Alt is held. Releasing the modifier returns this bar to its normal action page."
                )

                basePageText:SetText(
                    "Normal action page: Page "
                        .. tostring(
                            ns.GetBarBasePage(
                                barID
                            )
                                or "?"
                        )
                )

                for _, control in ipairs(
                    controls
                ) do
                    if control.Refresh then
                        control:Refresh()
                    end
                end
            else
                content:SetHeight(
                    170
                )

                scrollOffset = 0
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