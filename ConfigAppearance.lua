
local addonName, ns = ...

function ns.CreateAppearanceConfigPage(parent, context)
    local widgets = ns.ConfigWidgets
    local media = ns.Media
    local colors = media.colors
    local font = media.font

    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:SetClipsChildren(true)

    local content = CreateFrame("Frame", nil, page)
    content:SetWidth(1020)
    content:SetHeight(1)

    local controls = {}
    local refreshers = {}

    local scrollOffset = 0
    local scrollStep = 45
    local dragging = false
    local dragOffset = 0

    local scrollTrack = CreateFrame(
        "Frame", nil, page, "BackdropTemplate"
    )
    scrollTrack:SetWidth(4)
    scrollTrack:SetPoint("TOPRIGHT", page, "TOPRIGHT", -5, -4)
    scrollTrack:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -5, 4)
    scrollTrack:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    scrollTrack:SetBackdropColor(0.08, 0.09, 0.09, 0.9)
    scrollTrack:EnableMouse(true)

    local scrollThumb = CreateFrame(
        "Frame", nil, scrollTrack, "BackdropTemplate"
    )
    scrollThumb:SetWidth(8)
    scrollThumb:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    scrollThumb:SetBackdropColor(unpack(colors.accent))
    scrollThumb:EnableMouse(true)
    scrollThumb:RegisterForDrag("LeftButton")

    local function GetMaxScroll()
        return math.max(
            0,
            content:GetHeight() - page:GetHeight()
        )
    end

    local function UpdateScrollbar()
        local viewportHeight = page:GetHeight()
        local contentHeight = content:GetHeight()
        local trackHeight = scrollTrack:GetHeight()
        local maxScroll = GetMaxScroll()

        if viewportHeight <= 0
            or contentHeight <= 0
            or trackHeight <= 0
            or maxScroll <= 0
        then
            scrollTrack:Hide()
            return
        end

        scrollTrack:Show()

        local thumbHeight = math.min(
            trackHeight,
            math.max(
                28,
                trackHeight * viewportHeight / contentHeight
            )
        )

        scrollThumb:SetHeight(thumbHeight)

        local travel = math.max(
            0,
            trackHeight - thumbHeight
        )

        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint(
            "TOP",
            scrollTrack,
            "TOP",
            0,
            -(travel * scrollOffset / maxScroll)
        )
    end

    local function ApplyScroll()
        scrollOffset = math.max(
            0,
            math.min(scrollOffset, GetMaxScroll())
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
        local trackTop = scrollTrack:GetTop()
        local trackHeight = scrollTrack:GetHeight()
        local thumbHeight = scrollThumb:GetHeight()

        if not trackTop or trackHeight <= 0 then
            return
        end

        local cursor =
            cursorY / scrollTrack:GetEffectiveScale()

        local offset = trackTop - cursor

        if preserveDragOffset then
            offset = offset - dragOffset
        else
            offset = offset - thumbHeight / 2
        end

        local travel = math.max(
            0,
            trackHeight - thumbHeight
        )

        offset = math.max(
            0,
            math.min(offset, travel)
        )

        local ratio =
            travel > 0 and offset / travel or 0

        scrollOffset = GetMaxScroll() * ratio
        ApplyScroll()
    end

    page:EnableMouseWheel(true)
    page:SetScript("OnMouseWheel", function(_, delta)
        scrollOffset = scrollOffset - delta * scrollStep
        ApplyScroll()
    end)

    scrollTrack:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then
            return
        end

        local _, cursorY = GetCursorPosition()
        SetScrollFromThumbPosition(cursorY, false)
    end)

    scrollThumb:SetScript("OnDragStart", function()
        dragging = true

        local _, cursorY = GetCursorPosition()
        local cursor =
            cursorY / scrollTrack:GetEffectiveScale()

        local thumbTop = scrollThumb:GetTop()

        dragOffset =
            thumbTop and thumbTop - cursor or 0
    end)

    scrollThumb:SetScript("OnDragStop", function()
        dragging = false
    end)

    scrollThumb:SetScript("OnUpdate", function()
        if not dragging then
            return
        end

        local _, cursorY = GetCursorPosition()
        SetScrollFromThumbPosition(cursorY, true)
    end)

    scrollThumb:SetScript("OnEnter", function(self)
        self:SetBackdropColor(
            unpack(colors.hoverBorder or colors.accent)
        )
    end)

    scrollThumb:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(colors.accent))
    end)

    page:SetScript("OnSizeChanged", ApplyScroll)

    page:SetScript("OnHide", function()
        dragging = false
    end)

    local function GetSettings()
        local settings = context.GetSelectedSettings()

        if not settings then
            return nil
        end

        ns.GetBarAppearance(context.GetSelectedBarID())

        return settings
    end

    local function Apply()
        ns.ApplyBarAppearance(
            context.GetSelectedBarID()
        )
    end

    local function Check(section, label, key, y)
        controls[#controls + 1] =
            widgets.CreateCheckButton(
                section,
                label,
                24,
                y,
                function()
                    local settings = GetSettings()

                    return settings
                        and settings.appearance[key]
                end,
                function(value)
                    local settings = GetSettings()

                    if not settings then
                        return
                    end

                    settings.appearance[key] = value
                    Apply()
                end
            )
    end

    local function Slider(
        section,
        label,
        key,
        minimum,
        maximum,
        step,
        y,
        formatter
    )
        controls[#controls + 1] =
            widgets.CreateSlider(
                section,
                label,
                minimum,
                maximum,
                step,
                24,
                y,
                function()
                    local settings = GetSettings()

                    return settings
                        and settings.appearance[key]
                        or minimum
                end,
                function(value)
                    local settings = GetSettings()

                    if not settings then
                        return
                    end

                    settings.appearance[key] = value
                    Apply()
                end,
                formatter,
                420
            )
    end

    local function Choices(
        section,
        key,
        options,
        y,
        columns
    )
        local buttons = {}

        columns = columns or #options

        local spacing = 448 / columns

        for index, option in ipairs(options) do
            local value = option[1]
            local column = (index - 1) % columns
            local row = math.floor(
                (index - 1) / columns
            )

            buttons[value] = widgets.CreateTabButton(
                section,
                option[2],
                spacing - 6,
                28,
                24 + column * spacing,
                y - row * 32,
                function()
                    local settings = GetSettings()

                    if not settings then
                        return
                    end

                    settings.appearance[key] = value

                    Apply()
                    page:Refresh()
                end
            )
        end

        refreshers[#refreshers + 1] = function()
            local settings = GetSettings()

            if not settings then
                return
            end

            for value, button in pairs(buttons) do
                button:SetSelected(
                    settings.appearance[key] == value
                )
            end
        end
    end

    local function Label(section, text, x, y)
        local label = section:CreateFontString(
            nil,
            "OVERLAY"
        )

        label:SetFont(font, 10, "OUTLINE")
        label:SetTextColor(unpack(colors.muted))
        label:SetPoint(
            "TOPLEFT",
            section,
            "TOPLEFT",
            x,
            y
        )
        label:SetText(text)

        return label
    end

    local function Color(section, prefix, y)
        local key = prefix .. "Color"

        local button = CreateFrame(
            "Button",
            nil,
            section,
            "BackdropTemplate"
        )

        button:SetSize(72, 24)
        button:SetPoint(
            "TOPLEFT",
            section,
            "TOPLEFT",
            80,
            y
        )

        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })

        Label(section, "Color", 24, y - 6)

        local function Refresh()
            local settings = GetSettings()

            if not settings then
                return
            end

            local color = settings.appearance[key]

            button:SetBackdropColor(
                color.r,
                color.g,
                color.b,
                1
            )
            button:SetBackdropBorderColor(
                0.35,
                0.38,
                0.40,
                1
            )
        end

        refreshers[#refreshers + 1] = Refresh

        button:SetScript("OnClick", function()
            local settings = GetSettings()

            if not settings then
                return
            end

            local appearance = settings.appearance
            local barID = context.GetSelectedBarID()
            local color = appearance[key]

            local old = {
                r = color.r,
                g = color.g,
                b = color.b,
                a = color.a,
            }

            local function Set(r, g, b)
                appearance[key] = {
                    r = r,
                    g = g,
                    b = b,
                    a = old.a or 1,
                }

                ns.ApplyBarAppearance(barID)

                if context.GetSelectedSettings()
                    == settings
                then
                    Refresh()
                end
            end

            ColorPickerFrame:SetupColorPickerAndShow({
                r = old.r,
                g = old.g,
                b = old.b,
                hasOpacity = false,

                swatchFunc = function()
                    Set(
                        ColorPickerFrame:GetColorRGB()
                    )
                end,

                cancelFunc = function()
                    Set(
                        old.r,
                        old.g,
                        old.b
                    )
                end,
            })
        end)
    end

    local function OffsetBox(
        section,
        prefix,
        axis,
        label,
        x
    )
        local key = prefix .. "Offset" .. axis

        Label(section, label, x, -350)

        local box = CreateFrame(
            "EditBox",
            nil,
            section,
            "InputBoxTemplate"
        )

        box:SetSize(180, 22)
        box:SetPoint(
            "TOPLEFT",
            section,
            "TOPLEFT",
            x + 6,
            -372
        )

        box:SetAutoFocus(false)
        box:SetMaxLetters(6)
        box:SetJustifyH("CENTER")
        box:SetTextColor(unpack(colors.text))

        local editingSettings
        local editingBarID

        local function Restore()
            local settings = GetSettings()

            if not settings then
                return
            end

            box:SetText(
                tostring(
                    settings.appearance[key] or 0
                )
            )
        end

        local function Commit()
            if not editingSettings then
                return
            end

            local settings = editingSettings
            local barID = editingBarID

            editingSettings = nil
            editingBarID = nil

            local value = tonumber(box:GetText())

            if value and value == value then
                value = math.max(
                    -200,
                    math.min(200, value)
                )

                value = math.floor(value + 0.5)

                settings.appearance[key] = value
                ns.ApplyBarAppearance(barID)
            end

            Restore()
        end

        box:SetScript(
            "OnEditFocusGained",
            function(self)
                editingSettings = GetSettings()
                editingBarID =
                    context.GetSelectedBarID()

                self:HighlightText()
            end
        )

        box:SetScript(
            "OnEnterPressed",
            function(self)
                Commit()
                self:ClearFocus()
            end
        )

        box:SetScript(
            "OnEscapePressed",
            function(self)
                editingSettings = nil
                editingBarID = nil

                Restore()
                self:ClearFocus()
            end
        )

        box:SetScript("OnEditFocusLost", Commit)

        box:SetScript("OnHide", function(self)
            self:ClearFocus()
        end)

        refreshers[#refreshers + 1] = function()
            if editingSettings
                and editingSettings
                    ~= context.GetSelectedSettings()
            then
                Commit()
                box:ClearFocus()
            end

            if not box:HasFocus() then
                Restore()
            end
        end
    end

    local positions = {
        { "TOPLEFT", "Top Left" },
        { "TOP", "Top" },
        { "TOPRIGHT", "Top Right" },
        { "LEFT", "Left" },
        { "CENTER", "Center" },
        { "RIGHT", "Right" },
        { "BOTTOMLEFT", "Bottom Left" },
        { "BOTTOM", "Bottom" },
        { "BOTTOMRIGHT", "Bottom Right" },
    }

    local function TextControls(
        section,
        prefix,
        showKey,
        label,
        cooldown
    )
        Check(
            section,
            label,
            showKey,
            cooldown and -80 or -42
        )

        Slider(
            section,
            "Text Size",
            prefix .. "TextSize",
            8,
            32,
            1,
            cooldown and -122 or -84
        )

        Choices(
            section,
            prefix .. "Position",
            positions,
            -202,
            3
        )

        Color(section, prefix, -306)

        OffsetBox(
            section,
            prefix,
            "X",
            "Horizontal Offset (px)",
            24
        )

        OffsetBox(
            section,
            prefix,
            "Y",
            "Vertical Offset (px)",
            254
        )
    end

    local SECTION_WIDTH = 496
    local COLUMN_SPACING = 516
    local SECTION_SPACING = 16
    local BOTTOM_PADDING = 20

    local columnHeights = {
        0,
        0,
    }

    local function UpdateContentHeight()
        local height = math.max(
            columnHeights[1],
            columnHeights[2]
        )

        if height > 0 then
            height = height - SECTION_SPACING
        end

        content:SetHeight(
            math.max(1, height + BOTTOM_PADDING)
        )
    end

    local function Section(
        title,
        column,
        height
    )
        local index = column + 1
        local y = -columnHeights[index]

        local section = widgets.CreateSection(
            content,
            title,
            SECTION_WIDTH,
            height,
            column * COLUMN_SPACING,
            y
        )

        columnHeights[index] =
            columnHeights[index]
            + height
            + SECTION_SPACING

        UpdateContentHeight()

        return section
    end

    -- ICON

    local iconSection = Section(
        "Icon",
        0,
        195
    )

    Slider(
        iconSection,
        "Icon Zoom (%)",
        "iconZoom",
        0,
        30,
        1,
        -48
    )

    Check(
        iconSection,
        "Show Border",
        "showBorder",
        -146
    )

    -- COOLDOWN

    local cooldownSection = Section(
        "Cooldown",
        1,
        418
    )

    Check(
        cooldownSection,
        "Show Cooldown Overlay",
        "showCooldown",
        -42
    )

    TextControls(
        cooldownSection,
        "cooldown",
        "showCooldownText",
        "Show Cooldown Numbers",
        true
    )

    -- CHARGES / STACK COUNT

    local countSection = Section(
        "Charges / Stack Count",
        0,
        418
    )

    TextControls(
        countSection,
        "count",
        "showCount",
        "Show Charges / Stack Count"
    )

    -- KEYBIND TEXT

    local keybindSection = Section(
        "Keybind Text",
        1,
        418
    )

    TextControls(
        keybindSection,
        "keybind",
        "showKeybind",
        "Show Keybind Text"
    )

    -- MACRO NAME

    local macroSection = Section(
        "Macro Name",
        0,
        418
    )

    TextControls(
        macroSection,
        "macro",
        "showMacroName",
        "Show Macro Name"
    )

    -- CHARGE RECHARGE

    local rechargeSection = Section(
        "Charge Recharge",
        1,
        418
    )

    Check(
        rechargeSection,
        "Show Recharge Indicator",
        "showRecharge",
        -42
    )

    TextControls(
        rechargeSection,
        "recharge",
        "showRechargeText",
        "Show Recharge Numbers",
        true
    )

    local function Percent(value)
        return string.format(
            "%d%%",
            math.floor(value * 100 + 0.5)
        )
    end

    -- BUTTON BACKGROUND

    local backgroundSection = Section(
        "Button Background",
        0,
        135
    )

    Slider(
        backgroundSection,
        "Empty Button Opacity",
        "emptyOpacity",
        0,
        1,
        0.05,
        -48,
        Percent
    )

    -- ACTION STATE FEEDBACK

    local stateSection = Section(
        "Action State Feedback",
        1,
        185
    )

    Check(
        stateSection,
        "Color Actions When Out of Range",
        "rangeColoring",
        -48
    )

    Check(
        stateSection,
        "Color Unusable / Resource-Limited Actions",
        "usabilityColoring",
        -90
    )

    Check(
        stateSection,
        "Desaturate Unusable Actions",
        "desaturateUnusable",
        -132
    )

    -- FLYOUT DIRECTION

    local flyoutSection = Section(
        "Flyout Direction",
        0,
        106
    )

    Choices(
        flyoutSection,
        "flyoutDirection",
        {
            { "UP", "Up" },
            { "DOWN", "Down" },
            { "LEFT", "Left" },
            { "RIGHT", "Right" },
        },
        -48
    )

    -- PROC HIGHLIGHT
    -- Placed in the left column beneath Flyout Direction,
    -- avoiding unnecessary vertical space on the right.

    local procSection = Section(
        "Proc Highlight",
        0,
        198
    )

    Choices(
        procSection,
        "procStyle",
        {
            { "OFF", "Off" },
            { "ANIMATED", "Animated" },
            { "STATIC", "Static" },
        },
        -48
    )

    Slider(
        procSection,
        "Opacity",
        "procOpacity",
        0,
        1,
        0.05,
        -110,
        Percent
    )

    page.Refresh = function()
        if not GetSettings() then
            return
        end

        for _, control in ipairs(controls) do
            if control.Refresh then
                control:Refresh()
            end
        end

        for _, refresh in ipairs(refreshers) do
            refresh()
        end

        ApplyScroll()
    end

    page.ResetScroll = function()
        scrollOffset = 0
        ApplyScroll()
    end

    page:Hide()
    ApplyScroll()

    return page
end
