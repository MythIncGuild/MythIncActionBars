local addonName, ns = ...

ns.ConfigWidgets = {}
local widgets = ns.ConfigWidgets
local media = ns.Media
local colors = media.colors
local texture = media.texture
local font = media.font

local function SetBackdrop(frame, color)
    frame:SetBackdrop({
        bgFile = texture,
        edgeFile = texture,
        edgeSize = 1,
    })
    frame:SetBackdropColor(unpack(color or colors.surface))
    frame:SetBackdropBorderColor(unpack(colors.border))
end

local function SetFont(fontString, size, color)
    fontString:SetFont(font, size, "OUTLINE")
    fontString:SetTextColor(unpack(color or colors.text))
end

widgets.SetBackdrop = SetBackdrop
widgets.SetFont = SetFont

function widgets.CreatePanel(parent, width, height)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetSize(width, height)
    SetBackdrop(panel, colors.surface)
    return panel
end

function widgets.CreateSection(parent, titleText, width, height, x, y)
    local section = widgets.CreatePanel(parent, width, height)
    section:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local title = section:CreateFontString(nil, "OVERLAY")
    SetFont(title, 12)
    title:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -10)
    title:SetText(titleText)
    section.Title = title
    return section
end

function widgets.CreateText(parent, text, size, x, y, muted)
    local label = parent:CreateFontString(nil, "OVERLAY")
    SetFont(label, size or 11, muted and colors.muted or colors.text)
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)
    return label
end

function widgets.CreateButton(parent, text, width, height, x, y, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    SetBackdrop(button, colors.surface)

    local label = button:CreateFontString(nil, "OVERLAY")
    SetFont(label, 11)
    label:SetPoint("CENTER")
    label:SetText(text)

    button.label = label
    button.selected = false
    button.hovered = false

    local function Paint()
        if not button:IsEnabled() then
            button:SetBackdropColor(unpack(colors.background))
            button:SetBackdropBorderColor(unpack(colors.border))
            label:SetTextColor(unpack(colors.disabled))
            return
        end

        label:SetTextColor(unpack(colors.text))

        if button.selected then
            button:SetBackdropColor(unpack(colors.selected))
            button:SetBackdropBorderColor(unpack(colors.accent))
        elseif button.hovered then
            button:SetBackdropColor(unpack(colors.hover))
            button:SetBackdropBorderColor(unpack(colors.hoverBorder))
        else
            button:SetBackdropColor(unpack(colors.surface))
            button:SetBackdropBorderColor(unpack(colors.border))
        end
    end

    function button:SetText(value)
        label:SetText(value)
    end

    function button:GetText()
        return label:GetText()
    end

    function button:SetSelected(value)
        button.selected = value and true or false
        Paint()
    end

    button:SetScript("OnEnter", function()
        button.hovered = true
        Paint()
    end)

    button:SetScript("OnLeave", function()
        button.hovered = false
        Paint()
    end)

    button:HookScript("OnEnable", Paint)
    button:HookScript("OnDisable", Paint)

    if onClick then
        button:SetScript("OnClick", onClick)
    end

    Paint()
    return button
end

function widgets.CreateTabButton(parent, text, width, height, x, y, onClick)
    return widgets.CreateButton(parent, text, width, height, x, y, onClick)
end

function widgets.CreateCheckButton(parent, text, x, y, getter, setter)
    local checkbox = CreateFrame("CheckButton", nil, parent)
    checkbox:SetSize(24, 24)
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local box = CreateFrame("Frame", nil, checkbox, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 4, -4)
    box:SetPoint("BOTTOMRIGHT", -4, 4)
    box:EnableMouse(false)
    SetBackdrop(box, colors.surface)

    -- Ordinary textures painted explicitly from the checked state.
    local fill = box:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", box, "TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -2, 2)
    fill:SetColorTexture(0.18, 0.43, 0.40, 1)

    local highlight = box:CreateTexture(nil, "OVERLAY")
    highlight:SetAllPoints(box)
    highlight:SetColorTexture(0.35, 0.70, 0.65, 0.22)
    highlight:Hide()

    local label = checkbox:CreateFontString(nil, "OVERLAY")
    SetFont(label, 11)
    label:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
    label:SetText(text)
    checkbox.label = label

    local function Paint()
        fill:SetShown(checkbox:GetChecked() and true or false)
        box:SetAlpha(checkbox:IsEnabled() and 1 or 0.45)
        label:SetTextColor(unpack(
            checkbox:IsEnabled() and colors.text or colors.disabled
        ))
    end

    checkbox.Refresh = function()
        checkbox:SetChecked(getter() and true or false)
        Paint()
    end

    checkbox:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
        self:Refresh()
    end)

    checkbox:SetScript("OnEnter", function()
        highlight:SetShown(checkbox:IsEnabled())
    end)

    checkbox:SetScript("OnLeave", function()
        highlight:Hide()
    end)

    checkbox:HookScript("OnEnable", Paint)

    checkbox:HookScript("OnDisable", function()
        highlight:Hide()
        Paint()
    end)

    checkbox:HookScript("OnShow", function()
        checkbox:Refresh()
    end)

    checkbox:Refresh()
    return checkbox
end

function widgets.CreateEditBox(parent, labelText, width, x, y, getter, setter)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width, 48)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local label = container:CreateFontString(nil, "OVERLAY")
    SetFont(label, 11)
    label:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    label:SetText(labelText)

    local editBox = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
    editBox:SetSize(width, 22)
    editBox:SetPoint("TOPLEFT", container, "TOPLEFT", 4, -20)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(40)
    editBox:SetTextColor(unpack(colors.text))

    local refreshing = false

    local function Commit()
        if refreshing then return end

        local value = editBox:GetText()
        value = value:gsub("^%s+", "")
        value = value:gsub("%s+$", "")

        if value == "" then
            value = getter()
        end

        setter(value)
        editBox:SetText(value)
    end

    editBox:SetScript("OnEnterPressed", function(self)
        Commit()
        self:ClearFocus()
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText(getter())
        self:ClearFocus()
    end)

    editBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)

    editBox:SetScript("OnEditFocusLost", Commit)

    container.Refresh = function()
        refreshing = true
        editBox:SetText(getter() or "")
        refreshing = false
    end

    container.editBox = editBox
    container.Refresh()
    return container
end

function widgets.CreateSlider(
    parent, labelText, minValue, maxValue, step,
    x, y, getter, setter, formatter, width
)
    width = width or 250

    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width, 70)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local label = container:CreateFontString(nil, "OVERLAY")
    SetFont(label, 11)
    label:SetPoint("TOP", container, "TOP", 0, 0)
    label:SetText(labelText)

    local sliderName =
        "MythIncActionBarsSlider" .. tostring(math.random(100000, 999999))

    local slider = CreateFrame(
        "Slider", sliderName, container, "OptionsSliderTemplate"
    )
    slider:SetPoint("TOP", container, "TOP", 0, -22)
    slider:SetWidth(width)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider.Text:SetText("")
    slider.Low:SetText(tostring(minValue))
    slider.High:SetText(tostring(maxValue))
    SetFont(slider.Low, 9, colors.muted)
    SetFont(slider.High, 9, colors.muted)

    local thumb = slider:GetThumbTexture()
    if thumb then
        thumb:SetVertexColor(unpack(colors.accent))
    end

    local valueBox = CreateFrame(
        "EditBox", nil, container, "InputBoxTemplate"
    )
    valueBox:SetSize(58, 20)
    valueBox:SetPoint("TOP", slider, "BOTTOM", 0, -1)
    valueBox:SetAutoFocus(false)
    valueBox:SetJustifyH("CENTER")
    valueBox:SetMaxLetters(10)
    valueBox:SetTextColor(unpack(colors.text))

    local refreshing = false

    local function Clamp(value)
        value = math.max(minValue, math.min(maxValue, value))
        local steps = math.floor(((value - minValue) / step) + 0.5)
        value = minValue + steps * step
        return math.max(minValue, math.min(maxValue, value))
    end

    local function Format(value)
        if formatter then
            return formatter(value)
        end
        if step < 1 then
            return string.format("%.2f", value)
        end
        return tostring(math.floor(value + 0.5))
    end

    local function Restore()
        refreshing = true
        local value = getter()
        slider:SetValue(value)
        valueBox:SetText(Format(value))
        refreshing = false
    end

    local function Commit()
        if refreshing then return end

        local value = tonumber(valueBox:GetText())
        if not value then
            Restore()
            valueBox:ClearFocus()
            return
        end

        value = Clamp(value)
        refreshing = true
        slider:SetValue(value)
        valueBox:SetText(Format(value))
        refreshing = false

        setter(value)
        valueBox:ClearFocus()
    end

    slider:SetScript("OnValueChanged", function(self, value)
        if refreshing then return end
        value = Clamp(value)
        setter(value)

        if not valueBox:HasFocus() then
            valueBox:SetText(Format(value))
        end
    end)

    valueBox:SetScript("OnEnterPressed", Commit)

    valueBox:SetScript("OnEscapePressed", function(self)
        Restore()
        self:ClearFocus()
    end)

    valueBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)

    valueBox:SetScript("OnEditFocusLost", Commit)

    container.Refresh = Restore

    container.SetMinMaxValues = function(self, newMin, newMax)
        minValue = newMin
        maxValue = newMax
        slider:SetMinMaxValues(minValue, maxValue)
        slider.Low:SetText(tostring(minValue))
        slider.High:SetText(tostring(maxValue))

        local value = getter()
        if value < minValue then
            setter(minValue)
        elseif value > maxValue then
            setter(maxValue)
        end

        self:Refresh()
    end

    container.slider = slider
    container.valueBox = valueBox
    container.Refresh()
    return container
end