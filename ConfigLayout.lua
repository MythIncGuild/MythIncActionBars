local addonName, ns = ...

ns.SpecialConfigTargets = ns.SpecialConfigTargets or {}

local function Message(text)
    print("|cff7fd5ffMythInc Action Bars:|r " .. text)
end

local function ScrollArea(page, height)
    local viewport = CreateFrame("ScrollFrame", nil, page)
    viewport:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    viewport:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -24, 0)
    viewport:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, viewport)
    content:SetSize(1036, height)
    viewport:SetScrollChild(content)

    local slider = CreateFrame("Slider", nil, page, "BackdropTemplate")
    slider:SetPoint("TOPRIGHT", page, "TOPRIGHT", -4, -4)
    slider:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -4, 4)
    slider:SetWidth(12)
    slider:SetOrientation("VERTICAL")
    slider:SetValueStep(1)
    slider:SetBackdrop({bgFile = ns.Media.texture})
    slider:SetBackdropColor(0.08, 0.10, 0.13, 1)
    slider:SetThumbTexture(ns.Media.texture)
    slider:GetThumbTexture():SetSize(12, 40)
    slider:GetThumbTexture():SetVertexColor(0.22, 0.43, 0.41, 1)

    local offset, maximum, scale = 0, 0, 1

    local function SetOffset(value)
        offset = math.max(0, math.min(maximum, value))
        viewport:SetVerticalScroll(offset / scale)
    end

    slider:SetScript("OnValueChanged", function(_, value)
        SetOffset(value)
    end)

    local function Wheel(_, delta)
        SetOffset(offset - delta * 40)
        slider:SetValue(offset)
    end

    viewport:SetScript("OnMouseWheel", Wheel)

    local function Update()
        scale = math.min(1, math.max(1, viewport:GetWidth()) / 1036)
        content:SetScale(scale)

        maximum = math.max(
            0, content:GetHeight() * scale - viewport:GetHeight()
        )

        slider:SetMinMaxValues(0, maximum)
        slider:SetShown(maximum > 0)
        SetOffset(offset)
        slider:SetValue(offset)
    end

    viewport:SetScript("OnSizeChanged", Update)
    page:SetScript("OnShow", Update)

    return content, Update, Wheel
end

function ns.CreateLayoutConfigPage(parent, context)
    local widgets = ns.ConfigWidgets
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()

    local content, UpdateScroll = ScrollArea(page, 480)
    local controls = {}

    local function Settings()
        return context.GetSelectedSettings()
    end

    local function ID()
        return context.GetSelectedBarID()
    end

    local function UpdateBar()
        ns.UpdateBar(ID())
        ns.RefreshBarMover(ID())
    end

    local layout = widgets.CreateSection(
        content, "Layout", 506, 238, 0, 0
    )
    local position = widgets.CreateSection(
        content, "Position", 506, 238, 530, 0
    )

    local function Slider(section, label, key, low, high, step, x, y, width)
        local control = widgets.CreateSlider(
            section, label, low, high, step, x, y,
            function()
                local settings = Settings()
                return (key == "x" or key == "y")
                    and settings.position[key] or settings[key]
            end,
            function(value)
                if InCombatLockdown() then
                    Message("Layout cannot change during combat.")
                    return
                end

                local settings = Settings()

                if key == "x" or key == "y" then
                    settings.position[key] = value
                elseif key == "scale" then
                    local ratio = (tonumber(settings.scale) or 1) / value
                    settings.position.x = (settings.position.x or 0) * ratio
                    settings.position.y = (settings.position.y or 0) * ratio
                    settings.scale = value
                else
                    settings[key] = value
                end

                if key == "buttonCount" then
                    settings.columns = math.min(settings.columns, value)
                end
                if key == "columns" then
                    settings.columns = math.min(value, settings.buttonCount)
                end

                UpdateBar()

                if key == "buttonCount" and context.RefreshConfig then
                    context.RefreshConfig()
                end
            end,
            key == "scale"
                and function(value) return string.format("%.2f", value) end
                or nil,
            width or 190
        )

        controls[#controls + 1] = control
        return control
    end

    Slider(layout, "Buttons", "buttonCount", 1, 12, 1, 24, -42)
    local columns = Slider(
        layout, "Buttons Per Row", "columns", 1, 12, 1, 280, -42
    )
    Slider(layout, "Button Size", "buttonSize", 24, 64, 1, 24, -132)
    Slider(layout, "Spacing", "spacing", 0, 20, 1, 280, -132)
    Slider(position, "Scale", "scale", 0.5, 2, 0.05, 24, -42, 440)
    Slider(position, "X Position", "x", -1000, 1000, 1, 24, -132)
    Slider(position, "Y Position", "y", -1000, 1000, 1, 280, -132)

    local alignment = widgets.CreateSection(
        content, "Alignment and Snapping", 1036, 222, 0, -254
    )

    controls[#controls + 1] = widgets.CreateCheckButton(
        alignment,
        "Snap while dragging (hold Shift to bypass)",
        24, -40,
        function() return ns.GetBarSnapEnabled(ID()) end,
        function(value) ns.SetBarSnapEnabled(ID(), value) end
    )

    local referenceID
    local referenceButton

    local function RefreshReference()
        local choices = ns.GetPositionReferenceBars(ID())
        local valid = false

        for _, id in ipairs(choices) do
            if id == referenceID then valid = true end
        end

        if not valid then referenceID = choices[1] end

        referenceButton:SetText(
            referenceID
                and ("Reference: Bar " .. referenceID .. " (choose)")
                or "No other visible bar"
        )
    end

    local picker = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    picker:SetSize(330, 246)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetClampedToScreen(true)
    picker:EnableMouse(true)
    widgets.SetBackdrop(picker, ns.Media.colors.background)

    local background = picker:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.035, 0.039, 0.040, 1)

    widgets.CreateText(picker, "Reference Bar", 12, 12, -10)

    local list = CreateFrame("ScrollFrame", nil, picker)
    list:SetPoint("TOPLEFT", picker, "TOPLEFT", 10, -32)
    list:SetSize(288, 176)
    list:EnableMouseWheel(true)

    local listContent = CreateFrame("Frame", nil, list)
    listContent:SetSize(288, 176)
    list:SetScrollChild(listContent)

    local listSlider = CreateFrame(
        "Slider", nil, picker, "BackdropTemplate"
    )
    listSlider:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -12, -32)
    listSlider:SetSize(12, 176)
    listSlider:SetOrientation("VERTICAL")
    listSlider:SetValueStep(1)
    listSlider:SetBackdrop({bgFile = ns.Media.texture})
    listSlider:SetBackdropColor(0.08, 0.10, 0.13, 1)
    listSlider:SetThumbTexture(ns.Media.texture)
    listSlider:GetThumbTexture():SetSize(12, 28)
    listSlider:GetThumbTexture():SetVertexColor(0.22, 0.43, 0.41, 1)

    local rows = {}
    local listOffset, listMaximum = 0, 0

    local function ListScroll(value)
        listOffset = math.max(0, math.min(listMaximum, value))
        list:SetVerticalScroll(listOffset)
    end

    listSlider:SetScript("OnValueChanged", function(_, value)
        ListScroll(value)
    end)

    local function ListWheel(_, delta)
        ListScroll(listOffset - delta * 32)
        listSlider:SetValue(listOffset)
    end

    picker:EnableMouseWheel(true)
    picker:SetScript("OnMouseWheel", ListWheel)
    list:SetScript("OnMouseWheel", ListWheel)
    listSlider:EnableMouseWheel(true)
    listSlider:SetScript("OnMouseWheel", ListWheel)

    widgets.CreateButton(
        picker, "Close", 82, 26, 236, -214,
        function() picker:Hide() end
    )

    referenceButton = widgets.CreateButton(
        alignment, "Reference", 330, 28, 24, -92,
        function()
            if picker:IsShown() then
                picker:Hide()
                return
            end

            local choices = ns.GetPositionReferenceBars(ID())
            if #choices == 0 then return end

            for _, row in ipairs(rows) do row:Hide() end

            for index, id in ipairs(choices) do
                local row = rows[index]

                if not row then
                    row = widgets.CreateButton(
                        listContent, "", 288, 28,
                        0, -(index - 1) * 32,
                        function(self)
                            referenceID = self.barID
                            picker:Hide()
                            RefreshReference()
                        end
                    )

                    row:EnableMouseWheel(true)
                    row:SetScript("OnMouseWheel", ListWheel)
                    rows[index] = row
                end

                row.barID = id
                local name = ns.db.bars[id].name

                row:SetText(
                    name and name ~= "Bar " .. id
                        and ("Bar " .. id .. " - " .. name)
                        or "Bar " .. id
                )
                row:SetShown(true)
            end

            local height = math.max(176, #choices * 32)
            listContent:SetHeight(height)
            listMaximum = math.max(0, height - 176)
            listSlider:SetMinMaxValues(0, listMaximum)
            listSlider:SetShown(listMaximum > 0)
            ListScroll(0)
            listSlider:SetValue(0)

            local rootScale = UIParent:GetEffectiveScale()
            local buttonScale =
                referenceButton:GetEffectiveScale() / rootScale

            picker:SetScale(buttonScale)
            picker:ClearAllPoints()

            local top = referenceButton:GetTop() * buttonScale

            if UIParent:GetHeight() - top >= 250 * buttonScale then
                picker:SetPoint(
                    "BOTTOMLEFT", referenceButton, "TOPLEFT", 0, 4
                )
            else
                picker:SetPoint(
                    "TOPLEFT", referenceButton, "BOTTOMLEFT", 0, -4
                )
            end

            picker:Show()
        end
    )

    picker:Hide()
    page:SetScript("OnHide", function() picker:Hide() end)

    local function Align(mode)
        local success, reason = ns.AlignBar(ID(), referenceID, mode)

        if not success then
            Message(
                reason == "combat"
                    and "Position cannot change during combat."
                    or "Choose another visible reference bar."
            )
        end

        if context.RefreshConfig then context.RefreshConfig() end
    end

    local placements = {
        {"Above", "above"}, {"Below", "below"},
        {"Left", "left"}, {"Right", "right"},
    }
    local edges = {
        {"Align Left", "alignLeft"}, {"Align Right", "alignRight"},
        {"Align Top", "alignTop"}, {"Align Bottom", "alignBottom"},
    }

    for index, entry in ipairs(placements) do
        local mode = entry[2]
        widgets.CreateButton(
            alignment, entry[1], 116, 28,
            392 + (index - 1) * 126, -92,
            function() Align(mode) end
        )
    end

    for index, entry in ipairs(edges) do
        local mode = entry[2]
        widgets.CreateButton(
            alignment, entry[1], 116, 28,
            392 + (index - 1) * 126, -134,
            function() Align(mode) end
        )
    end

    widgets.CreateButton(
        alignment, "Center Horizontally", 156, 28, 24, -134,
        function() Align("screenX") end
    )
    widgets.CreateButton(
        alignment, "Center Vertically", 156, 28, 204, -134,
        function() Align("screenY") end
    )

    widgets.CreateText(
        alignment,
        "Placement uses a 4-pixel gap. Bars remain independently movable.",
        11, 24, -184, true
    )
    widgets.CreateText(
        alignment,
        "New bars use free space beside the selected bar when possible.",
        11, 24, -202, true
    )

    page.Refresh = function()
        local settings = Settings()
        if not settings then return end

        picker:Hide()
        ns.SetBarPlacementReference(ID())
        settings.columns = math.min(settings.columns, settings.buttonCount)
        columns:SetMinMaxValues(1, settings.buttonCount)

        for _, control in ipairs(controls) do control:Refresh() end

        RefreshReference()
        UpdateScroll()
    end

    page:Hide()
    return page
end

function ns.CreateSpecialConfigPage(parent, context)
    local widgets = ns.ConfigWidgets
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()

    local content, UpdateScroll, Wheel = ScrollArea(page, 540)
    local cache = {}
    local capturing, activeTarget, activeCategory

    local function StopCapture()
        capturing = nil
        page:EnableKeyboard(false)
        page:SetPropagateKeyboardInput(true)
    end

    local function Build(target, category)
        local frame = CreateFrame("Frame", nil, content)
        frame:SetAllPoints()
        frame.controls = {}
        frame.bindButtons = {}

        local function SetValue(key, value)
            if InCombatLockdown() then
                Message("Settings cannot change during combat.")
                frame:Refresh()
                return
            end

            local settings = target.GetSettings()

            if key == "scale" and target.scaledPosition then
                local ratio = (tonumber(settings.scale) or 1) / value
                settings.x = (settings.x or 0) * ratio
                settings.y = (settings.y or 0) * ratio
            end

            settings[key] = value
            target.Refresh()

            if context.RefreshConfig then context.RefreshConfig() end
        end

        local function Slider(section, label, key, low, high, step, x, y)
            frame.controls[#frame.controls + 1] = widgets.CreateSlider(
                section, label, low, high, step, x, y,
                function() return target.GetSettings()[key] end,
                function(value) SetValue(key, value) end,
                key == "scale"
                    and function(value) return string.format("%.2f", value) end
                    or nil,
                420
            )
        end

        local function Check(section, label, key, x, y)
            frame.controls[#frame.controls + 1] = widgets.CreateCheckButton(
                section, label, x, y,
                function() return target.GetSettings()[key] end,
                function(value) SetValue(key, value) end
            )
        end

                if category == "Layout" then
            local section = widgets.CreateSection(
                frame,
                target.name .. " Layout",
                1036,
                360,
                0,
                0
            )

            if target.grid then
                Slider(
                    section,
                    "Buttons Per Row",
                    "columns",
                    1,
                    10,
                    1,
                    24,
                    -42
                )
            end

            Slider(
                section,
                "X Position",
                "x",
                -1000,
                1000,
                1,
                24,
                -146
            )

            Slider(
                section,
                "Y Position",
                "y",
                -1000,
                1000,
                1,
                554,
                -146
            )

            widgets.CreateButton(
                section,
                "Reset Position",
                160,
                30,
                24,
                -250,
                function()
                    if InCombatLockdown() then
                        return
                    end

                    local settings = target.GetSettings()

                    settings.x = target.defaults.x
                    settings.y = target.defaults.y

                    target.Refresh()

                    if context.RefreshConfig then
                        context.RefreshConfig()
                    end
                end
            )

            widgets.CreateText(
                section,
                "Use Unlock Bar above to move this bar. Apply / Revert works across all bar types.",
                11,
                24,
                -306,
                true
            )

        elseif category == "Appearance" then
            local section = widgets.CreateSection(
                frame,
                target.name .. " Appearance",
                1036,
                300,
                0,
                0
            )

            if target.grid then
                Slider(
                    section,
                    "Button Size",
                    "buttonSize",
                    24,
                    64,
                    1,
                    24,
                    -42
                )

                Slider(
                    section,
                    "Spacing",
                    "spacing",
                    0,
                    20,
                    1,
                    554,
                    -42
                )
            end

            Slider(
                section,
                "Scale",
                "scale",
                0.5,
                2,
                0.05,
                24,
                -146
            )

            widgets.CreateText(
                section,
                "These controls resize the existing native buttons. Other artwork follows Blizzard's presentation.",
                11,
                24,
                -254,
                true
            )

        elseif category == "Visibility" then
            local section = widgets.CreateSection(
                frame, target.name .. " Visibility", 1036, 250, 0, 0
            )

            Check(section, "Hide while mounted", "hideMounted", 24, -48)
            Check(section, "Hide in vehicles / override states", "hideVehicle", 24, -94)
            Check(section, "Show only in combat", "combatOnly", 24, -140)

            widgets.CreateText(
                section,
                "The bar also follows Blizzard's pet / form availability and pet-battle visibility.",
                11, 24, -194, true
            )

        elseif category == "Action Pages" then
            local section = widgets.CreateSection(
                frame, "Vehicle Action Pages", 1036, 220, 0, 0
            )

            Check(
                section,
                "Use vehicle / override / possession pages on Bar 1",
                "mainBarPaging", 24, -48
            )

            widgets.CreateText(
                section,
                "Special pages take priority over modifier pages. Bar 1 must be enabled and visible in vehicles.",
                11, 24, -110, true
            )
            widgets.CreateText(
                section,
                "This setting controls Bar 1. The selected Vehicle Exit button is a single exit control.",
                11, 24, -138, true
            )

        elseif category == "Keybinds" then
            local section = widgets.CreateSection(
                frame, target.name .. " Keybinds", 1036, 530, 0, 0
            )

            widgets.CreateText(
                section,
                "Click a slot, then press a key. Escape cancels capture. Delete / Backspace clears the binding.",
                11, 24, -40, true
            )
            widgets.CreateText(
                section,
                "You can also use /kb. Inherited Blizzard bindings are shown when present.",
                11, 24, -64, true
            )

            for index = 1, target.grid and 10 or 1 do
                local slot = index
                local column = (index - 1) % 2
                local row = math.floor((index - 1) / 2)

                local button = widgets.CreateButton(
                    section, "", 460, 34,
                    24 + column * 506, -108 - row * 64,
                    function()
                        if InCombatLockdown()
                            or not target.GetSettings().enabled
                            or slot > target.Count()
                        then
                            return
                        end

                        capturing = slot
                        page:EnableKeyboard(true)
                        page:SetPropagateKeyboardInput(false)
                        frame:Refresh()
                    end
                )

                button:EnableMouseWheel(true)
                button:SetScript("OnMouseWheel", Wheel)
                frame.bindButtons[index] = button
            end
        end

        frame.Refresh = function()
            for _, control in ipairs(frame.controls) do control:Refresh() end

            local settings = target.GetSettings()

            for index, button in ipairs(frame.bindButtons) do
                local available = settings.enabled and index <= target.Count()
                if available then button:Enable() else button:Disable() end

                local custom = settings.keybinds and settings.keybinds[index]
                local key = custom or (target.Inherited and target.Inherited(index))

                button:SetText(
                    capturing == index
                        and "Press a key... (Escape cancels)"
                        or (
                            "Slot " .. index .. "  |  "
                            .. (key and ns.FormatKeybind(key) or "Unbound")
                            .. (key and not custom and " (Blizzard)" or "")
                            .. (index > target.Count() and " - unavailable" or "")
                        )
                )
            end
        end

        return frame
    end

    page:SetScript("OnKeyDown", function(_, key)
        if not capturing then
            page:SetPropagateKeyboardInput(true)
            return
        end

        page:SetPropagateKeyboardInput(false)

        if key == "ESCAPE" or InCombatLockdown() then
            StopCapture()
        else
            local binding = ns.BuildCapturedKey(key)

            if key == "DELETE" or key == "BACKSPACE" then
                binding = nil
            elseif not binding then
                return
            end

            local slot = capturing
            StopCapture()
            activeTarget.Bind(slot, binding)
        end

        if activeTarget then page:Refresh(activeTarget, activeCategory) end
    end)

    page:SetScript("OnHide", StopCapture)

    page.Refresh = function(_, target, category)
        if activeTarget ~= target or activeCategory ~= category then
            StopCapture()
        end

        activeTarget, activeCategory = target, category

        for _, pages in pairs(cache) do
            for _, frame in pairs(pages) do frame:Hide() end
        end

        cache[target] = cache[target] or {}

        if not cache[target][category] then
            cache[target][category] = Build(target, category)
        end

        local frame = cache[target][category]
        frame:Show()
        frame:Refresh()
        UpdateScroll()
    end

    page:Hide()
    return page
end