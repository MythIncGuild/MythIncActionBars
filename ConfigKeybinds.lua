local addonName, ns = ...

function ns.CreateKeybindsConfigPage(
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
    content:SetHeight(700)

    local scrollOffset = 0
    local scrollStep = 45
    local rows = {}
    local activeField

    local captureFrame =
        CreateFrame(
            "Frame",
            nil,
            UIParent
        )

    captureFrame:SetSize(
        1,
        1
    )

    captureFrame:SetPoint(
        "CENTER"
    )

    captureFrame:EnableKeyboard(
        true
    )

    captureFrame:SetPropagateKeyboardInput(
        true
    )

    captureFrame:Hide()

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

    scrollTrack:EnableMouse(
        true
    )

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
        unpack(
            colors.accent
        )
    )

    scrollThumb:EnableMouse(
        true
    )

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
            trackTop
            - cursor

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
                offset
                / travel
        end

        scrollOffset =
            GetMaxScroll()
            * ratio

        ApplyScroll()
    end

    page:EnableMouseWheel(
        true
    )

    page:SetScript(
        "OnMouseWheel",
        function(
            _,
            delta
        )
            if activeField then
                return
            end

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
        function(
            _,
            button
        )
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
            dragging =
                true

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
                dragOffset =
                    0
            end
        end
    )

    scrollThumb:SetScript(
        "OnDragStop",
        function()
            dragging =
                false
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
                unpack(
                    colors.accent
                )
            )
        end
    )

    page:SetScript(
        "OnSizeChanged",
        ApplyScroll
    )

    local headerSection =
        widgets.CreateSection(
            content,
            "Keybinds",
            1012,
            118,
            0,
            0
        )

    local description =
        headerSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    description:SetFont(
        font,
        11,
        "OUTLINE"
    )

    description:SetTextColor(
        unpack(
            colors.muted
        )
    )

    description:SetPoint(
        "TOPLEFT",
        headerSection,
        "TOPLEFT",
        24,
        -42
    )

    description:SetWidth(
        950
    )

    description:SetJustifyH(
        "LEFT"
    )

    description:SetText(
        "Bind keys directly to MIAB buttons. Each button supports a primary and secondary bind. You can also type /kb for hover binding mode."
    )

    local statusText =
        headerSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    statusText:SetFont(
        font,
        10,
        "OUTLINE"
    )

    statusText:SetTextColor(
        unpack(
            colors.text
        )
    )

    statusText:SetPoint(
        "TOPLEFT",
        headerSection,
        "TOPLEFT",
        24,
        -82
    )

    statusText:SetText(
        "Click a binding field, then press a key or mouse button."
    )

    local listSection =
        widgets.CreateSection(
            content,
            "Button Bindings",
            1012,
            560,
            0,
            -134
        )

    local buttonHeader =
        listSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    buttonHeader:SetFont(
        font,
        10,
        "OUTLINE"
    )

    buttonHeader:SetTextColor(
        unpack(
            colors.muted
        )
    )

    buttonHeader:SetPoint(
        "TOPLEFT",
        listSection,
        "TOPLEFT",
        24,
        -38
    )

    buttonHeader:SetText(
        "BUTTON"
    )

    local primaryHeader =
        listSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    primaryHeader:SetFont(
        font,
        10,
        "OUTLINE"
    )

    primaryHeader:SetTextColor(
        unpack(
            colors.muted
        )
    )

    primaryHeader:SetPoint(
        "TOPLEFT",
        listSection,
        "TOPLEFT",
        280,
        -38
    )

    primaryHeader:SetText(
        "PRIMARY"
    )

    local secondaryHeader =
        listSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    secondaryHeader:SetFont(
        font,
        10,
        "OUTLINE"
    )

    secondaryHeader:SetTextColor(
        unpack(
            colors.muted
        )
    )

    secondaryHeader:SetPoint(
        "TOPLEFT",
        listSection,
        "TOPLEFT",
        580,
        -38
    )

    secondaryHeader:SetText(
        "SECONDARY"
    )

    local function IsModifierOnly(
        key
    )
        return key == "LSHIFT"
            or key == "RSHIFT"
            or key == "SHIFT"
            or key == "LCTRL"
            or key == "RCTRL"
            or key == "CTRL"
            or key == "LALT"
            or key == "RALT"
            or key == "ALT"
    end

    local function DescribeConflict(
        conflict
    )
        local settings =
            ns.db.bars[
                conflict.barID
            ]

        local name =
            settings
            and settings.name
            or (
                "Bar "
                .. conflict.barID
            )

        return name
            .. " Button "
            .. conflict.buttonID
    end

    local function StopCapture()
        if activeField then
            activeField.capturing =
                false

            activeField:SetBackdropBorderColor(
                0.18,
                0.20,
                0.21,
                1
            )

            local previous =
                activeField

            activeField =
                nil

            if previous.Refresh then
                previous:Refresh()
            end
        end

        captureFrame:SetPropagateKeyboardInput(
            true
        )

        captureFrame:Hide()
    end

    local function CommitBinding(
        field,
        key
    )
        local barID =
            context.GetSelectedBarID()

        local success,
            result =
            ns.SetButtonKeybind(
                barID,
                field.buttonID,
                field.slot,
                key
            )

        if not success then
            if result
                == "combat"
            then
                statusText:SetText(
                    "Keybinds cannot be changed during combat."
                )
            else
                statusText:SetText(
                    "That key could not be assigned."
                )
            end

            StopCapture()
            return
        end

        StopCapture()

        if result
            and #result > 0
        then
            statusText:SetText(
                ns.FormatKeybind(
                    key
                )
                .. " was moved from "
                .. DescribeConflict(
                    result[1]
                )
                .. "."
            )

        elseif key then
            statusText:SetText(
                ns.FormatKeybind(
                    key
                )
                .. " bound to Button "
                .. field.buttonID
                .. "."
            )

        else
            statusText:SetText(
                "Binding cleared from Button "
                .. field.buttonID
                .. "."
            )
        end

        if page.Refresh then
            page:Refresh()
        end
    end

    local function StartCapture(
        field
    )
        if InCombatLockdown() then
            statusText:SetText(
                "Keybinds cannot be changed during combat."
            )

            return
        end

        StopCapture()

        activeField =
            field

        field.capturing =
            true

        field:SetBackdropBorderColor(
            unpack(
                colors.accent
            )
        )

        field.Text:SetText(
            "Press a key..."
        )

        captureFrame:Show()

        captureFrame:SetPropagateKeyboardInput(
            false
        )

        statusText:SetText(
            "Press a key or mouse button. Escape cancels; Backspace/Delete clears."
        )
    end

    captureFrame:SetScript(
        "OnKeyDown",
        function(
            _,
            key
        )
            if not activeField then
                return
            end

            if key
                == "ESCAPE"
            then
                StopCapture()

                statusText:SetText(
                    "Binding capture cancelled."
                )

                return
            end

            if key == "BACKSPACE"
                or key == "DELETE"
            then
                local field =
                    activeField

                CommitBinding(
                    field,
                    nil
                )

                return
            end

            if IsModifierOnly(
                key
            ) then
                return
            end

            local captured =
                ns.BuildCapturedKey(
                    key
                )

            if captured then
                local field =
                    activeField

                CommitBinding(
                    field,
                    captured
                )
            end
        end
    )

    local function CreateBindingField(
        parentFrame,
        buttonID,
        slot,
        x
    )
        local field =
            CreateFrame(
                "Button",
                nil,
                parentFrame,
                "BackdropTemplate"
            )

        field:SetSize(
            250,
            30
        )

        field:SetPoint(
            "TOPLEFT",
            parentFrame,
            "TOPLEFT",
            x,
            0
        )

        field:SetBackdrop({
            bgFile =
                "Interface\\Buttons\\WHITE8x8",

            edgeFile =
                "Interface\\Buttons\\WHITE8x8",

            edgeSize =
                1,
        })

        field:SetBackdropColor(
            0.06,
            0.07,
            0.08,
            0.95
        )

        field:SetBackdropBorderColor(
            0.18,
            0.20,
            0.21,
            1
        )

        field:RegisterForClicks(
            "AnyUp"
        )

        field:EnableMouseWheel(
            true
        )

        field.buttonID =
            buttonID

        field.slot =
            slot

        field.Text =
            field:CreateFontString(
                nil,
                "OVERLAY"
            )

        field.Text:SetFont(
            font,
            11,
            "OUTLINE"
        )

        field.Text:SetPoint(
            "CENTER"
        )

        field.Text:SetTextColor(
            unpack(
                colors.text
            )
        )

        field.Refresh =
            function()
                if field.capturing then
                    return
                end

                local key =
                    ns.GetButtonKeybind(
                        context.GetSelectedBarID(),
                        buttonID,
                        slot
                    )

                if key then
                    field.Text:SetText(
                        ns.FormatKeybind(
                            key
                        )
                    )
                else
                    field.Text:SetText(
                        "Unbound"
                    )
                end
            end

        field:SetScript(
            "OnEnter",
            function(self)
                if not self.capturing then
                    self:SetBackdropBorderColor(
                        unpack(
                            colors.hoverBorder
                                or colors.accent
                        )
                    )
                end
            end
        )

        field:SetScript(
            "OnLeave",
            function(self)
                if not self.capturing then
                    self:SetBackdropBorderColor(
                        0.18,
                        0.20,
                        0.21,
                        1
                    )
                end
            end
        )

        field:SetScript(
            "OnClick",
            function(self)
                StartCapture(
                    self
                )
            end
        )

        field:SetScript(
            "OnMouseDown",
            function(
                self,
                mouseButton
            )
                if activeField
                    ~= self
                then
                    return
                end

                if mouseButton == "LeftButton"
                    or mouseButton == "RightButton"
                then
                    return
                end

                local base =
                    ns.NormalizeKeybindMouseButton(
                        mouseButton
                    )

                local key =
                    ns.BuildCapturedKey(
                        base
                    )

                if key then
                    CommitBinding(
                        self,
                        key
                    )
                end
            end
        )

        field:SetScript(
            "OnMouseWheel",
            function(
                self,
                delta
            )
                if activeField
                    ~= self
                then
                    return
                end

                local base =
                    delta > 0
                    and "MOUSEWHEELUP"
                    or "MOUSEWHEELDOWN"

                local key =
                    ns.BuildCapturedKey(
                        base
                    )

                if key then
                    CommitBinding(
                        self,
                        key
                    )
                end
            end
        )

        return field
    end

    for buttonID =
        1,
        12
    do
        local row =
            CreateFrame(
                "Frame",
                nil,
                listSection,
                "BackdropTemplate"
            )

        row:SetSize(
            964,
            38
        )

        row:SetBackdrop({
            bgFile =
                "Interface\\Buttons\\WHITE8x8",
        })

        row:SetBackdropColor(
            0.04,
            0.05,
            0.055,
            0.75
        )

        local label =
            row:CreateFontString(
                nil,
                "OVERLAY"
            )

        label:SetFont(
            font,
            11,
            "OUTLINE"
        )

        label:SetTextColor(
            unpack(
                colors.text
            )
        )

        label:SetPoint(
            "LEFT",
            row,
            "LEFT",
            12,
            0
        )

        label:SetText(
            "Button "
            .. buttonID
        )

        local primary =
            CreateBindingField(
                row,
                buttonID,
                "primary",
                256
            )

        local secondary =
            CreateBindingField(
                row,
                buttonID,
                "secondary",
                556
            )

        rows[
            buttonID
        ] = {
            frame =
                row,

            primary =
                primary,

            secondary =
                secondary,
        }
    end

    local clearButton =
        widgets.CreateButton(
            listSection,
            "Clear Bar Keybinds",
            170,
            30,
            818,
            -520,
            function()
                StopCapture()

                local success,
                    reason =
                    ns.ClearBarKeybinds(
                        context.GetSelectedBarID()
                    )

                if not success
                    and reason
                        == "combat"
                then
                    statusText:SetText(
                        "Keybinds cannot be changed during combat."
                    )

                    return
                end

                statusText:SetText(
                    "All keybinds for this bar were cleared."
                )

                if page.Refresh then
                    page:Refresh()
                end
            end
        )

    page.Refresh =
        function()
            local settings =
                context.GetSelectedSettings()

            if not settings then
                return
            end

            local count =
                math.max(
                    1,
                    math.min(
                        12,
                        settings.buttonCount
                            or 12
                    )
                )

            local visibleIndex = 0

            for buttonID =
                1,
                12
            do
                local row =
                    rows[
                        buttonID
                    ]

                if buttonID
                    <= count
                then
                    row.frame:Show()

                    row.frame:ClearAllPoints()

                    row.frame:SetPoint(
                        "TOPLEFT",
                        listSection,
                        "TOPLEFT",
                        24,
                        -62
                            - (
                                visibleIndex
                                * 44
                            )
                    )

                    row.primary:Refresh()
                    row.secondary:Refresh()

                    visibleIndex =
                        visibleIndex + 1
                else
                    row.frame:Hide()
                end
            end

            local listHeight =
                112
                + (
                    visibleIndex
                    * 44
                )

            listSection:SetHeight(
                listHeight
            )

            clearButton:ClearAllPoints()

            clearButton:SetPoint(
                "TOPLEFT",
                listSection,
                "TOPLEFT",
                818,
                -(
                    listHeight
                    - 42
                )
            )

            content:SetHeight(
                150
                + listHeight
            )

            ns.RefreshKeybindDisplay()

            ApplyScroll()
        end

    page.ResetScroll =
        function()
            StopCapture()

            scrollOffset =
                0

            ApplyScroll()
        end

    page:SetScript(
        "OnHide",
        function()
            StopCapture()
        end
    )

    page:Hide()

    ApplyScroll()

    return page
end