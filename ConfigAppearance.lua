local addonName, ns = ...

function ns.CreateAppearanceConfigPage(
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
    content:SetHeight(690)

    local controls = {}
    local positionButtons = {}

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

        local travel =
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
                travel
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
                    thumbTop
                    - cursor
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

    local function GetSettings()
        local settings =
            context.GetSelectedSettings()

        if not settings then
            return nil
        end

        settings.appearance =
            settings.appearance
            or {}

        local appearance =
            settings.appearance

        if appearance.iconZoom == nil then
            appearance.iconZoom = 0
        end

        if appearance.showBorder == nil then
            appearance.showBorder = true
        end

        if appearance.emptyOpacity == nil then
            appearance.emptyOpacity = 0.85
        end

        if appearance.showCooldown == nil then
            appearance.showCooldown = true
        end

        if appearance.showCooldownText == nil then
            appearance.showCooldownText = true
        end

        if appearance.showCount == nil then
            appearance.showCount = true
        end

        if appearance.countTextSize == nil then
            appearance.countTextSize = 12
        end

        if appearance.showKeybind == nil then
            appearance.showKeybind = true
        end

        if appearance.keybindTextSize == nil then
            appearance.keybindTextSize = 12
        end

        if appearance.keybindPosition == nil then
            appearance.keybindPosition =
                "TOPRIGHT"
        end

        appearance.keybindColor =
            appearance.keybindColor
            or {
                r = 1,
                g = 1,
                b = 1,
                a = 1,
            }

        if appearance.desaturateUnusable == nil then
            appearance.desaturateUnusable = false
        end

        if appearance.rangeColoring == nil then
            appearance.rangeColoring = true
        end

        if appearance.usabilityColoring == nil then
            appearance.usabilityColoring = true
        end

        return settings
    end

    local function Apply()
        ns.ApplyBarAppearance(
            context.GetSelectedBarID()
        )
    end

    local iconSection =
        widgets.CreateSection(
            content,
            "Icon",
            496,
            200,
            0,
            0
        )

    local cooldownSection =
        widgets.CreateSection(
            content,
            "Cooldown",
            496,
            200,
            516,
            0
        )

    local textSection =
        widgets.CreateSection(
            content,
            "Text",
            496,
            220,
            0,
            -216
        )

    local keybindSection =
        widgets.CreateSection(
            content,
            "Keybind Text",
            496,
            220,
            516,
            -216
        )

    local backgroundSection =
        widgets.CreateSection(
            content,
            "Button Background",
            496,
            150,
            0,
            -452
        )

    local stateSection =
        widgets.CreateSection(
            content,
            "Action State Feedback",
            496,
            220,
            516,
            -452
        )

    controls[#controls + 1] =
        widgets.CreateSlider(
            iconSection,
            "Icon Zoom (%)",
            0,
            30,
            1,
            24,
            -48,
            function()
                return GetSettings()
                    .appearance
                    .iconZoom
            end,
            function(value)
                GetSettings()
                    .appearance
                    .iconZoom =
                    value

                Apply()
            end,
            nil,
            420
        )

    controls[#controls + 1] =
        widgets.CreateCheckButton(
            iconSection,
            "Show Border",
            24,
            -146,
            function()
                return GetSettings()
                    .appearance
                    .showBorder
            end,
            function(value)
                GetSettings()
                    .appearance
                    .showBorder =
                    value

                Apply()
            end
        )

    controls[#controls + 1] =
        widgets.CreateCheckButton(
            cooldownSection,
            "Show Cooldown Overlay",
            24,
            -48,
            function()
                return GetSettings()
                    .appearance
                    .showCooldown
            end,
            function(value)
                GetSettings()
                    .appearance
                    .showCooldown =
                    value

                Apply()
            end
        )

    controls[#controls + 1] =
        widgets.CreateCheckButton(
            cooldownSection,
            "Show Cooldown Numbers",
            24,
            -90,
            function()
                return GetSettings()
                    .appearance
                    .showCooldownText
            end,
            function(value)
                GetSettings()
                    .appearance
                    .showCooldownText =
                    value

                Apply()
            end
        )

    controls[#controls + 1] =
        widgets.CreateCheckButton(
            textSection,
            "Show Stack / Count",
            24,
            -42,
            function()
                return GetSettings()
                    .appearance
                    .showCount
            end,
            function(value)
                GetSettings()
                    .appearance
                    .showCount =
                    value

                Apply()
            end
        )

    controls[#controls + 1] =
        widgets.CreateSlider(
            textSection,
            "Count Text Size",
            8,
            24,
            1,
            220,
            -36,
            function()
                return GetSettings()
                    .appearance
                    .countTextSize
            end,
            function(value)
                GetSettings()
                    .appearance
                    .countTextSize =
                    value

                Apply()
            end,
            nil,
            240
        )

    controls[#controls + 1] =
        widgets.CreateCheckButton(
            keybindSection,
            "Show Keybind Text",
            24,
            -42,
            function()
                return GetSettings()
                    .appearance
                    .showKeybind
            end,
            function(value)
                GetSettings()
                    .appearance
                    .showKeybind =
                    value

                Apply()
            end
        )

    controls[#controls + 1] =
        widgets.CreateSlider(
            keybindSection,
            "Keybind Text Size",
            8,
            24,
            1,
            220,
            -36,
            function()
                return GetSettings()
                    .appearance
                    .keybindTextSize
            end,
            function(value)
                GetSettings()
                    .appearance
                    .keybindTextSize =
                    value

                Apply()
            end,
            nil,
            240
        )

    local positionLabel =
        keybindSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    positionLabel:SetFont(
        font,
        10,
        "OUTLINE"
    )

    positionLabel:SetTextColor(
        unpack(colors.muted)
    )

    positionLabel:SetPoint(
        "TOPLEFT",
        keybindSection,
        "TOPLEFT",
        24,
        -116
    )

    positionLabel:SetText(
        "Position"
    )

    local positionOptions = {
        {
            value = "TOPLEFT",
            label = "Top Left",
        },
        {
            value = "TOPRIGHT",
            label = "Top Right",
        },
        {
            value = "BOTTOMLEFT",
            label = "Bottom Left",
        },
        {
            value = "BOTTOMRIGHT",
            label = "Bottom Right",
        },
    }

    for index, option in ipairs(
        positionOptions
    ) do
        local button =
            widgets.CreateTabButton(
                keybindSection,
                option.label,
                104,
                28,
                24
                    + (
                        (index - 1)
                        * 112
                    ),
                -140,
                function()
                    GetSettings()
                        .appearance
                        .keybindPosition =
                        option.value

                    Apply()

                    page:Refresh()
                end
            )

        positionButtons[
            option.value
        ] =
            button
    end

    local colorLabel =
        keybindSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    colorLabel:SetFont(
        font,
        10,
        "OUTLINE"
    )

    colorLabel:SetTextColor(
        unpack(colors.muted)
    )

    colorLabel:SetPoint(
        "TOPLEFT",
        keybindSection,
        "TOPLEFT",
        24,
        -184
    )

    colorLabel:SetText(
        "Color"
    )

    local colorButton =
        CreateFrame(
            "Button",
            nil,
            keybindSection,
            "BackdropTemplate"
        )

    colorButton:SetSize(
        72,
        24
    )

    colorButton:SetPoint(
        "TOPLEFT",
        keybindSection,
        "TOPLEFT",
        80,
        -178
    )

    colorButton:SetBackdrop({
        bgFile =
            "Interface\\Buttons\\WHITE8x8",
        edgeFile =
            "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    local function RefreshColorButton()
        local color =
            GetSettings()
                .appearance
                .keybindColor

        colorButton:SetBackdropColor(
            color.r,
            color.g,
            color.b,
            1
        )

        colorButton:SetBackdropBorderColor(
            0.35,
            0.38,
            0.40,
            1
        )
    end

    colorButton:SetScript(
        "OnClick",
        function()
            local appearance =
                GetSettings()
                    .appearance

            local oldColor = {
                r =
                    appearance
                        .keybindColor.r,
                g =
                    appearance
                        .keybindColor.g,
                b =
                    appearance
                        .keybindColor.b,
            }

            local function ApplyPickerColor()
                local r,
                    g,
                    b =
                    ColorPickerFrame:GetColorRGB()

                appearance.keybindColor.r =
                    r

                appearance.keybindColor.g =
                    g

                appearance.keybindColor.b =
                    b

                RefreshColorButton()
                Apply()
            end

            ColorPickerFrame:
                SetupColorPickerAndShow({
                    r =
                        oldColor.r,
                    g =
                        oldColor.g,
                    b =
                        oldColor.b,
                    hasOpacity =
                        false,

                    swatchFunc =
                        ApplyPickerColor,

                    cancelFunc =
                        function(previous)
                            appearance
                                .keybindColor.r =
                                previous.r
                                or oldColor.r

                            appearance
                                .keybindColor.g =
                                previous.g
                                or oldColor.g

                            appearance
                                .keybindColor.b =
                                previous.b
                                or oldColor.b

                            RefreshColorButton()
                            Apply()
                        end,
                })
        end
    )

    controls[#controls + 1] =
        widgets.CreateSlider(
            backgroundSection,
            "Empty Button Opacity",
            0,
            1,
            0.05,
            24,
            -42,
            function()
                return GetSettings()
                    .appearance
                    .emptyOpacity
            end,
            function(value)
                GetSettings()
                    .appearance
                    .emptyOpacity =
                    value

                Apply()
            end,
            function(value)
                return string.format(
                    "%d%%",
                    math.floor(
                        value
                            * 100
                            + 0.5
                    )
                )
            end,
            420
        )

    controls[#controls + 1] =
        widgets.CreateCheckButton(
            stateSection,
            "Color Actions When Out of Range",
            24,
            -48,
            function()
                return GetSettings()
                    .appearance
                    .rangeColoring
            end,
            function(value)
                GetSettings()
                    .appearance
                    .rangeColoring =
                    value

                Apply()
            end
        )

    controls[#controls + 1] =
        widgets.CreateCheckButton(
            stateSection,
            "Color Unusable / Resource-Limited Actions",
            24,
            -90,
            function()
                return GetSettings()
                    .appearance
                    .usabilityColoring
            end,
            function(value)
                GetSettings()
                    .appearance
                    .usabilityColoring =
                    value

                Apply()
            end
        )

    controls[#controls + 1] =
        widgets.CreateCheckButton(
            stateSection,
            "Desaturate Unusable Actions",
            24,
            -132,
            function()
                return GetSettings()
                    .appearance
                    .desaturateUnusable
            end,
            function(value)
                GetSettings()
                    .appearance
                    .desaturateUnusable =
                    value

                Apply()
            end
        )

    page.Refresh =
        function()
            for _, control in ipairs(
                controls
            ) do
                if control.Refresh then
                    control:Refresh()
                end
            end

            local selectedPosition =
                GetSettings()
                    .appearance
                    .keybindPosition

            for position, button in pairs(
                positionButtons
            ) do
                button:SetSelected(
                    position
                        == selectedPosition
                )
            end

            RefreshColorButton()
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