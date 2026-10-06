local addonName, ns = ...

local panel
local currentPage
local bar1Page
local navigationButtons = {}
local controls = {}

local PANEL_WIDTH = 820
local PANEL_HEIGHT = 600
local NAV_WIDTH = 180

local function RefreshControls()
    for _, control in ipairs(controls) do
        if control.Refresh then
            control:Refresh()
        end
    end
end

function ns.RefreshConfig()
    RefreshControls()
end

local function SetPage(pageName)
    currentPage = pageName

    if bar1Page then
        bar1Page:SetShown(pageName == "bar1")
    end

    for name, button in pairs(navigationButtons) do
        if button.selected then
            button.selected:SetShown(name == pageName)
        end
    end

    RefreshControls()
end

local function CreateNavigationButton(parent, text, pageName, y)
    local button = CreateFrame("Button", nil, parent)

    button:SetSize(NAV_WIDTH - 24, 32)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.08, 0.08, 0.08, 0.8)

    local selected = button:CreateTexture(nil, "BACKGROUND", nil, 1)
    selected:SetAllPoints()
    selected:SetColorTexture(0.12, 0.38, 0.62, 0.8)
    selected:Hide()

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.2, 0.55, 0.85, 0.22)

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", button, "LEFT", 12, 0)
    label:SetText(text)

    button.selected = selected

    button:SetScript("OnClick", function()
        SetPage(pageName)
    end)

    navigationButtons[pageName] = button

    return button
end

local function CreateBar1Page(parent)
    local page = CreateFrame("Frame", nil, parent)

    page:SetPoint("TOPLEFT", parent, "TOPLEFT", NAV_WIDTH + 28, -52)
    page:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -28, 28)

    ns.ConfigWidgets.CreateSectionTitle(
        page,
        "Bar 1",
        0,
        0
    )

    ns.ConfigWidgets.CreateDescription(
        page,
        "Configure the layout, scale and position of Action Bar 1.",
        0,
        -28,
        540
    )

    ns.ConfigWidgets.CreateDivider(
        page,
        0,
        -58,
        560
    )

    ns.ConfigWidgets.CreateSectionTitle(
        page,
        "Layout",
        0,
        -82
    )

    controls[#controls + 1] = ns.ConfigWidgets.CreateSlider(
        page,
        "Button Size",
        24,
        64,
        1,
        0,
        -118,
        function()
            return ns.db.bars.bar1.buttonSize
        end,
        function(value)
            ns.db.bars.bar1.buttonSize = value
            ns.UpdateBar1()
            ns.RefreshBar1Mover()
        end
    )

    controls[#controls + 1] = ns.ConfigWidgets.CreateSlider(
        page,
        "Spacing",
        0,
        20,
        1,
        330,
        -118,
        function()
            return ns.db.bars.bar1.spacing
        end,
        function(value)
            ns.db.bars.bar1.spacing = value
            ns.UpdateBar1()
            ns.RefreshBar1Mover()
        end
    )

    controls[#controls + 1] = ns.ConfigWidgets.CreateSlider(
        page,
        "Buttons Per Row",
        1,
        12,
        1,
        0,
        -190,
        function()
            return ns.db.bars.bar1.columns
        end,
        function(value)
            ns.db.bars.bar1.columns = value
            ns.UpdateBar1()
            ns.RefreshBar1Mover()
        end
    )

    controls[#controls + 1] = ns.ConfigWidgets.CreateSlider(
        page,
        "Scale",
        0.5,
        2,
        0.05,
        330,
        -190,
        function()
            return ns.db.bars.bar1.scale
        end,
        function(value)
            ns.db.bars.bar1.scale = value
            ns.UpdateBar1()
            ns.RefreshBar1Mover()
        end,
        function(value)
            return string.format("%.2f", value)
        end
    )

    ns.ConfigWidgets.CreateDivider(
        page,
        0,
        -268,
        560
    )

    ns.ConfigWidgets.CreateSectionTitle(
        page,
        "Position",
        0,
        -292
    )

    controls[#controls + 1] = ns.ConfigWidgets.CreateSlider(
        page,
        "X Position",
        -1000,
        1000,
        1,
        0,
        -328,
        function()
            return ns.db.bars.bar1.position.x
        end,
        function(value)
            ns.db.bars.bar1.position.x = value
            ns.UpdateBar1()
            ns.RefreshBar1Mover()
        end
    )

    controls[#controls + 1] = ns.ConfigWidgets.CreateSlider(
        page,
        "Y Position",
        -1000,
        1000,
        1,
        330,
        -328,
        function()
            return ns.db.bars.bar1.position.y
        end,
        function(value)
            ns.db.bars.bar1.position.y = value
            ns.UpdateBar1()
            ns.RefreshBar1Mover()
        end
    )

    local unlockButton = ns.ConfigWidgets.CreateButton(
        page,
        "Unlock Bar",
        140,
        28,
        0,
        -410,
        function(self)
            if ns.IsBar1Unlocked() then
                ns.SetBar1Unlocked(false)
                self:SetText("Unlock Bar")
            else
                ns.SetBar1Unlocked(true)
                self:SetText("Lock Bar")
            end
        end
    )

    local resetButton = ns.ConfigWidgets.CreateButton(
        page,
        "Reset Bar 1",
        140,
        28,
        160,
        -410,
        function()
            if InCombatLockdown() then
                return
            end

            local defaults = ns.defaults.bars.bar1
            local settings = ns.db.bars.bar1

            settings.buttonCount = defaults.buttonCount
            settings.buttonSize = defaults.buttonSize
            settings.spacing = defaults.spacing
            settings.columns = defaults.columns
            settings.scale = defaults.scale

            settings.position.point = defaults.position.point
            settings.position.relativePoint = defaults.position.relativePoint
            settings.position.x = defaults.position.x
            settings.position.y = defaults.position.y

            ns.UpdateBar1()
            ns.RefreshBar1Mover()
            RefreshControls()
        end
    )

    page.unlockButton = unlockButton
    page.resetButton = resetButton

    page:SetScript("OnShow", function(self)
        if ns.IsBar1Unlocked() then
            self.unlockButton:SetText("Lock Bar")
        else
            self.unlockButton:SetText("Unlock Bar")
        end

        RefreshControls()
    end)

    return page
end

local function CreateConfigPanel()
    if panel then
        return panel
    end

    panel = CreateFrame(
        "Frame",
        "MythIncActionBarsConfig",
        UIParent,
        "BasicFrameTemplateWithInset"
    )

    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetClampedToScreen(true)
    panel:Hide()

    panel:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    panel.TitleText:SetText("MythInc Action Bars")

    local navBackground = panel:CreateTexture(nil, "BACKGROUND")
    navBackground:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -30)
    navBackground:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 8)
    navBackground:SetWidth(NAV_WIDTH)
    navBackground:SetColorTexture(0.04, 0.04, 0.04, 0.78)

    local navTitle = panel:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalLarge"
    )

    navTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -50)
    navTitle:SetText("Action Bars")

    CreateNavigationButton(
        panel,
        "Bar 1",
        "bar1",
        -82
    )

    bar1Page = CreateBar1Page(panel)

    panel:SetScript("OnShow", function()
        SetPage(currentPage or "bar1")
    end)

    panel:SetScript("OnHide", function()
        ns.SetBar1Unlocked(false)

        if bar1Page then
            bar1Page.unlockButton:SetText("Unlock Bar")
        end
    end)

    return panel
end

function ns.ToggleConfig()
    local config = CreateConfigPanel()

    if config:IsShown() then
        config:Hide()
    else
        config:Show()
    end
end

SLASH_MYTHINCACTIONBARS1 = "/miab"
SLASH_MYTHINCACTIONBARS2 = "/mythincactionbars"

SlashCmdList.MYTHINCACTIONBARS = function()
    ns.ToggleConfig()
end