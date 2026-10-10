local addonName, ns = ...

function ns.CreateFadeConfigControls(section, getBarID, controls, refresh)
    local widgets = ns.ConfigWidgets

    local function Get()
        return ns.GetBarFadeSettings(getBarID())
    end

    local function Set(option, value)
        ns.SetBarFadeOption(getBarID(), option, value)
        refresh()
    end

    for _, option in ipairs({
        { "Fade when the mouse is away", "fadeOnMouseover", 24 },
        { "Show fully in combat", "showFullyInCombat", 520 },
    }) do
        local key = option[2]
        controls[#controls + 1] = widgets.CreateCheckButton(
            section, option[1], option[3], -48,
            function()
                local settings = Get()
                return settings and settings[key]
            end,
            function(value) Set(key, value) end
        )
    end

    for _, option in ipairs({
        { "Normal Opacity", "opacity", 24 },
        { "Faded Opacity", "fadedOpacity", 520 },
    }) do
        local key = option[2]
        controls[#controls + 1] = widgets.CreateSlider(
            section, option[1], 0, 100, 1, option[3], -118,
            function()
                local settings = Get()
                return (settings and settings[key] or 1) * 100
            end,
            function(value) Set(key, value / 100) end,
            function(value)
                return string.format("%d%%", math.floor(value + 0.5))
            end,
            440
        )
    end

    local text = widgets.CreateText(
        section,
        "Fading changes opacity; existing hide rules still apply. Hotkeys continue to work.\n"
            .. "Bars show fully while unlocked, in /kb, or while dragging abilities. Faded opacity cannot exceed normal opacity.",
        11, 24, -192, true
    )
    text:SetWidth(950)
    text:SetJustifyH("LEFT")
end

function ns.CreateVisibilityConfigPage(parent, context)
    local widgets = ns.ConfigWidgets
    local media = ns.Media
    local colors = media.colors
    local font = media.font

    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:SetClipsChildren(true)

    local content = CreateFrame("Frame", nil, page)
    content:SetWidth(1020)
    content:SetHeight(680)

    local modeButtons = {}
    local controls = {}
    local scrollOffset = 0
    local scrollStep = 45

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

    local dragging = false
    local dragOffset = 0

    local function GetMaxScroll()
        return math.max(0, content:GetHeight() - page:GetHeight())
    end

    local function UpdateScrollbar()
        local viewportHeight = page:GetHeight()
        local contentHeight = content:GetHeight()
        local trackHeight = scrollTrack:GetHeight()
        local maxScroll = GetMaxScroll()

        if viewportHeight <= 0 or contentHeight <= 0
            or trackHeight <= 0 or maxScroll <= 0
        then
            scrollTrack:Hide()
            return
        end

        scrollTrack:Show()

        local visibleRatio = math.min(1, viewportHeight / contentHeight)
        local thumbHeight = math.min(
            trackHeight, math.max(28, trackHeight * visibleRatio)
        )
        scrollThumb:SetHeight(thumbHeight)

        local availableTravel = math.max(0, trackHeight - thumbHeight)
        local thumbOffset = availableTravel * (scrollOffset / maxScroll)

        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -thumbOffset)
    end

    local function ApplyScroll()
        scrollOffset = math.max(0, math.min(scrollOffset, GetMaxScroll()))
        content:ClearAllPoints()
        content:SetPoint("TOPLEFT", page, "TOPLEFT", 0, scrollOffset)
        UpdateScrollbar()
    end

    local function SetScrollFromThumbPosition(cursorY, preserveDragOffset)
        local trackTop = scrollTrack:GetTop()
        local trackHeight = scrollTrack:GetHeight()
        local thumbHeight = scrollThumb:GetHeight()
        if not trackTop or trackHeight <= 0 then return end

        local scaledCursorY = cursorY / scrollTrack:GetEffectiveScale()
        local offset = trackTop - scaledCursorY

        if preserveDragOffset then
            offset = offset - dragOffset
        else
            offset = offset - thumbHeight / 2
        end

        local availableTravel = math.max(0, trackHeight - thumbHeight)
        offset = math.max(0, math.min(offset, availableTravel))

        local ratio = availableTravel > 0 and offset / availableTravel or 0
        scrollOffset = GetMaxScroll() * ratio
        ApplyScroll()
    end

    page:EnableMouseWheel(true)
    page:SetScript("OnMouseWheel", function(_, delta)
        if delta < 0 then
            scrollOffset = scrollOffset + scrollStep
        elseif delta > 0 then
            scrollOffset = scrollOffset - scrollStep
        end
        ApplyScroll()
    end)

    scrollTrack:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        local _, cursorY = GetCursorPosition()
        SetScrollFromThumbPosition(cursorY, false)
    end)

    scrollThumb:SetScript("OnDragStart", function()
        dragging = true
        local _, cursorY = GetCursorPosition()
        local scaledCursorY = cursorY / scrollTrack:GetEffectiveScale()
        local thumbTop = scrollThumb:GetTop()
        dragOffset = thumbTop and thumbTop - scaledCursorY or 0
    end)

    scrollThumb:SetScript("OnDragStop", function()
        dragging = false
    end)

    scrollThumb:SetScript("OnUpdate", function()
        if not dragging then return end
        local _, cursorY = GetCursorPosition()
        SetScrollFromThumbPosition(cursorY, true)
    end)

    scrollThumb:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(colors.hoverBorder or colors.accent))
    end)

    scrollThumb:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(colors.accent))
    end)

    page:SetScript("OnSizeChanged", ApplyScroll)

    local baseSection = widgets.CreateSection(
        content, "Base Visibility", 1012, 190, 0, 0
    )

    local function Description(section, text, y)
        local label = section:CreateFontString(nil, "OVERLAY")
        label:SetFont(font, 11, "OUTLINE")
        label:SetTextColor(unpack(colors.muted))
        label:SetPoint("TOPLEFT", section, "TOPLEFT", 24, y)
        label:SetWidth(950)
        label:SetJustifyH("LEFT")
        label:SetText(text)
        return label
    end

    Description(
        baseSection,
        "Choose the bar's normal combat visibility. Additional conditions below can hide the bar regardless of this setting.",
        -42
    )

    local statusText = baseSection:CreateFontString(nil, "OVERLAY")
    statusText:SetFont(font, 11, "OUTLINE")
    statusText:SetTextColor(unpack(colors.text))
    statusText:SetPoint("TOPLEFT", baseSection, "TOPLEFT", 24, -132)

    local additionalSection = widgets.CreateSection(
        content, "Additional Hide Conditions", 1012, 190, 0, -206
    )

    Description(
        additionalSection,
        "These conditions are combined with the base visibility rule. Multiple conditions may be enabled at the same time.",
        -42
    )

    local function GetVisibility()
        return ns.GetBarVisibilitySettings(context.GetSelectedBarID())
    end

    local function GetMode()
        local visibility = GetVisibility()
        return visibility and visibility.mode or "always"
    end

    local function Refresh()
        local visibility = GetVisibility()
        if not visibility then return end

        local mode = GetMode()
        for buttonMode, button in pairs(modeButtons) do
            button:SetSelected(buttonMode == mode)
        end

        for _, control in ipairs(controls) do
            if control.Refresh then control:Refresh() end
        end

        if mode == "combat" then
            statusText:SetText(
                "Base rule: The bar is shown only while you are in combat."
            )
        elseif mode == "nocombat" then
            statusText:SetText(
                "Base rule: The bar is hidden while you are in combat."
            )
        else
            statusText:SetText(
                "Base rule: The bar is normally always shown while enabled."
            )
        end

        ApplyScroll()
    end

    local function SetMode(mode)
        ns.SetBarVisibilityMode(context.GetSelectedBarID(), mode)
        Refresh()
    end

    for _, definition in ipairs({
        { "always", "Always Show", 24 },
        { "combat", "Hide Out of Combat", 316 },
        { "nocombat", "Hide In Combat", 608 },
    }) do
        local mode = definition[1]
        modeButtons[mode] = widgets.CreateTabButton(
            baseSection, definition[2], 280, 38, definition[3], -78,
            function() SetMode(mode) end
        )
    end

    for _, definition in ipairs({
        { "Hide While Mounted", "hideMounted", 24 },
        { "Hide in Vehicle / Override Bar", "hideVehicle", 330 },
        { "Hide During Pet Battles", "hidePetBattle", 690 },
    }) do
        local key = definition[2]
        controls[#controls + 1] = widgets.CreateCheckButton(
            additionalSection, definition[1], definition[3], -92,
            function()
                local visibility = GetVisibility()
                return visibility and visibility[key] or false
            end,
            function(value)
                ns.SetBarVisibilityOption(
                    context.GetSelectedBarID(), key, value
                )
            end
        )
    end

    local fadeSection = widgets.CreateSection(
        content, "Opacity and Mouseover Fading", 1012, 240, 0, -412
    )
    ns.CreateFadeConfigControls(
        fadeSection, context.GetSelectedBarID, controls, Refresh
    )

    page.Refresh = Refresh
    page.ResetScroll = function()
        scrollOffset = 0
        ApplyScroll()
    end

    page:Hide()
    ApplyScroll()
    return page
end