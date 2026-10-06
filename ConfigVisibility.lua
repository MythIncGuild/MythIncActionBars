local addonName, ns = ...

function ns.CreateVisibilityConfigPage(
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
    content:SetHeight(470)

    local modeButtons = {}
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

    local baseSection =
        widgets.CreateSection(
            content,
            "Base Visibility",
            1012,
            190,
            0,
            0
        )

    local baseDescription =
        baseSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    baseDescription:SetFont(
        font,
        11,
        "OUTLINE"
    )

    baseDescription:SetTextColor(
        unpack(
            colors.muted
        )
    )

    baseDescription:SetPoint(
        "TOPLEFT",
        baseSection,
        "TOPLEFT",
        24,
        -42
    )

    baseDescription:SetWidth(
        950
    )

    baseDescription:SetJustifyH(
        "LEFT"
    )

    baseDescription:SetText(
        "Choose the bar's normal combat visibility. Additional conditions below can hide the bar regardless of this setting."
    )

    local statusText =
        baseSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    statusText:SetFont(
        font,
        11,
        "OUTLINE"
    )

    statusText:SetTextColor(
        unpack(
            colors.text
        )
    )

    statusText:SetPoint(
        "TOPLEFT",
        baseSection,
        "TOPLEFT",
        24,
        -132
    )

    local additionalSection =
        widgets.CreateSection(
            content,
            "Additional Hide Conditions",
            1012,
            190,
            0,
            -206
        )

    local additionalDescription =
        additionalSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    additionalDescription:SetFont(
        font,
        11,
        "OUTLINE"
    )

    additionalDescription:SetTextColor(
        unpack(
            colors.muted
        )
    )

    additionalDescription:SetPoint(
        "TOPLEFT",
        additionalSection,
        "TOPLEFT",
        24,
        -42
    )

    additionalDescription:SetWidth(
        950
    )

    additionalDescription:SetJustifyH(
        "LEFT"
    )

    additionalDescription:SetText(
        "These conditions are combined with the base visibility rule. Multiple conditions may be enabled at the same time."
    )

    local function GetVisibility()
        return ns.GetBarVisibilitySettings(
            context.GetSelectedBarID()
        )
    end

    local function GetMode()
        local visibility =
            GetVisibility()

        if not visibility then
            return "always"
        end

        return visibility.mode
    end

    local function Refresh()
        local visibility =
            GetVisibility()

        if not visibility then
            return
        end

        local mode =
            GetMode()

        for buttonMode, button in pairs(
            modeButtons
        ) do
            button:SetSelected(
                buttonMode
                    == mode
            )
        end

        for _, control in ipairs(
            controls
        ) do
            if control.Refresh then
                control:Refresh()
            end
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

    local function SetMode(
        mode
    )
        ns.SetBarVisibilityMode(
            context.GetSelectedBarID(),
            mode
        )

        Refresh()
    end

    modeButtons.always =
        widgets.CreateTabButton(
            baseSection,
            "Always Show",
            280,
            38,
            24,
            -78,
            function()
                SetMode(
                    "always"
                )
            end
        )

    modeButtons.combat =
        widgets.CreateTabButton(
            baseSection,
            "Hide Out of Combat",
            280,
            38,
            316,
            -78,
            function()
                SetMode(
                    "combat"
                )
            end
        )

    modeButtons.nocombat =
        widgets.CreateTabButton(
            baseSection,
            "Hide In Combat",
            280,
            38,
            608,
            -78,
            function()
                SetMode(
                    "nocombat"
                )
            end
        )

    controls[
        #controls + 1
    ] =
        widgets.CreateCheckButton(
            additionalSection,
            "Hide While Mounted",
            24,
            -92,
            function()
                local visibility =
                    GetVisibility()

                return visibility
                    and visibility.hideMounted
                    or false
            end,
            function(value)
                ns.SetBarVisibilityOption(
                    context.GetSelectedBarID(),
                    "hideMounted",
                    value
                )
            end
        )

    controls[
        #controls + 1
    ] =
        widgets.CreateCheckButton(
            additionalSection,
            "Hide in Vehicle / Override Bar",
            330,
            -92,
            function()
                local visibility =
                    GetVisibility()

                return visibility
                    and visibility.hideVehicle
                    or false
            end,
            function(value)
                ns.SetBarVisibilityOption(
                    context.GetSelectedBarID(),
                    "hideVehicle",
                    value
                )
            end
        )

    controls[
        #controls + 1
    ] =
        widgets.CreateCheckButton(
            additionalSection,
            "Hide During Pet Battles",
            690,
            -92,
            function()
                local visibility =
                    GetVisibility()

                return visibility
                    and visibility.hidePetBattle
                    or false
            end,
            function(value)
                ns.SetBarVisibilityOption(
                    context.GetSelectedBarID(),
                    "hidePetBattle",
                    value
                )
            end
        )

    page.Refresh =
        Refresh

    page.ResetScroll =
        function()
            scrollOffset = 0

            ApplyScroll()
        end

    page:Hide()

    ApplyScroll()

    return page
end