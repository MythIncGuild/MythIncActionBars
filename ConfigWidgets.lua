local addonName, ns = ...

ns.ConfigWidgets = {}

local widgets = ns.ConfigWidgets

function widgets.CreateSectionTitle(parent, text, x, y)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    title:SetText(text)

    return title
end

function widgets.CreateDescription(parent, text, x, y, width)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetText(text)

    return label
end

function widgets.CreateDivider(parent, x, y, width)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    line:SetSize(width, 1)
    line:SetColorTexture(0.35, 0.35, 0.35, 0.7)

    return line
end

function widgets.CreateButton(parent, text, width, height, x, y, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")

    button:SetSize(width, height)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", onClick)

    return button
end

function widgets.CreateCheckButton(parent, text, x, y, getter, setter)
    local checkbox = CreateFrame(
        "CheckButton",
        nil,
        parent,
        "UICheckButtonTemplate"
    )

    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    checkbox.Text:SetText(text)
    checkbox:SetChecked(getter())

    checkbox:SetScript("OnClick", function(self)
        setter(self:GetChecked())
    end)

    checkbox.Refresh = function(self)
        self:SetChecked(getter())
    end

    return checkbox
end

function widgets.CreateSlider(
    parent,
    labelText,
    minValue,
    maxValue,
    step,
    x,
    y,
    getter,
    setter,
    formatter
)
    local container = CreateFrame("Frame", nil, parent)

    container:SetSize(300, 52)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local label = container:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormal"
    )

    label:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    label:SetText(labelText)

    local valueText = container:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlight"
    )

    valueText:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)

    local slider = CreateFrame(
        "Slider",
        nil,
        container,
        "OptionsSliderTemplate"
    )

    slider:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -22)
    slider:SetWidth(300)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    slider.Low:SetText("")
    slider.High:SetText("")
    slider.Text:SetText("")

    local function FormatValue(value)
        if formatter then
            return formatter(value)
        end

        if step < 1 then
            return string.format("%.2f", value)
        end

        return tostring(math.floor(value + 0.5))
    end

    local refreshing = false

    slider:SetScript("OnValueChanged", function(self, value)
        if refreshing then
            return
        end

        local rounded = math.floor((value / step) + 0.5) * step

        setter(rounded)
        valueText:SetText(FormatValue(rounded))
    end)

    container.Refresh = function()
        refreshing = true

        local value = getter()

        slider:SetValue(value)
        valueText:SetText(FormatValue(value))

        refreshing = false
    end

    container.Refresh()

    container.slider = slider
    container.valueText = valueText

    return container
end