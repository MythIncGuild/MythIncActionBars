local addonName, ns = ...

local widgets = ns.ConfigWidgets
local media = ns.Media
local colors = media.colors
local font = media.font

local panel
local RefreshControls
local SelectBar
local SetTopLevelMode
local RequestCloseConfig

local barButtonPool = {}
local barButtons = {}
local categoryButtons = {}

local confirmationDialog
local confirmationOverlay
local confirmationTitle
local confirmationMessage
local confirmationButtons = {}
local confirmationActions = {}
local confirmationButtonCount = 0

local allowConfigClose = false
local suppressNextSessionStart = false

local selectedBarID = 1
local selectedCategory = "Layout"
local selectedTopLevel = "Action Bars"

local generalTab
local actionBarsTab
local profilesTab

local actionBarSettingsSection
local hideBlizzardCheckbox
local barSelectorSection
local barSelectorViewport
local barSelectorOffset = 0

local categoryFrame

local renameDialog
local nameControl
local unlockButton
local unlockAllButton

local pageHost
local layoutPage
local appearancePage
local visibilityPage
local actionPagesPage
local keybindsPage

local generalHost
local generalPage

local profilesHost
local profilesPage

local resetButton
local deleteButton
local addButton
local applyChangesButton
local revertChangesButton
local resetAllButton

local minimizeButton
local logoTexture
local isMinimized = false

local WINDOW_WIDTH = 1080
local WINDOW_HEIGHT = 720
local MINIMIZED_HEIGHT = 64

local BAR_BUTTON_WIDTH = 124
local BAR_BUTTON_HEIGHT = 30
local BAR_BUTTON_SPACING = 6
local BAR_COLUMNS = 6
local BAR_VISIBLE_ROWS = 3
local BAR_VISIBLE_COUNT = BAR_COLUMNS * BAR_VISIBLE_ROWS

local SELECTOR_TOP = -170
local SELECTOR_TITLE_HEIGHT = 38
local SELECTOR_BOTTOM_PADDING = 12
local SELECTOR_ROW_HEIGHT = BAR_BUTTON_HEIGHT + BAR_BUTTON_SPACING

local CATEGORY_NAMES = {
    "Layout",
    "Appearance",
    "Visibility",
    "Action Pages",
    "Keybinds",
}

local function SetFont(fontString, size, muted)
    fontString:SetFont(font, size, "OUTLINE")
    fontString:SetTextColor(
        unpack(muted and colors.muted or colors.text)
    )
end

local function GetSelectedSettings()
    return ns.db.bars[selectedBarID]
end

local function GetSelectedBarID()
    return selectedBarID
end

local function GetFallbackBarID(deletedBarID)
    local ids = ns.GetBarIDs()

    if #ids == 0 then
        return nil
    end

    local previous
    local nextID

    for _, barID in ipairs(ids) do
        if barID < deletedBarID then
            previous = barID
        elseif barID > deletedBarID then
            nextID = barID
            break
        end
    end

    return previous or nextID or ids[1]
end

local function FindSelectedIndex()
    local ids = ns.GetBarIDs()

    for index, barID in ipairs(ids) do
        if barID == selectedBarID then
            return index
        end
    end

    return 1
end

local function ClampBarSelectorOffset()
    local ids = ns.GetBarIDs()
    local maxOffset = math.max(
        0, math.ceil(#ids / BAR_COLUMNS) - BAR_VISIBLE_ROWS
    )

    barSelectorOffset = math.max(
        0, math.min(barSelectorOffset, maxOffset)
    )
end

local function EnsureSelectedBarVisible()
    local index = FindSelectedIndex()
    local row = math.floor((index - 1) / BAR_COLUMNS)

    if row < barSelectorOffset then
        barSelectorOffset = row
    elseif row >= barSelectorOffset + BAR_VISIBLE_ROWS then
        barSelectorOffset = row - BAR_VISIBLE_ROWS + 1
    end

    ClampBarSelectorOffset()
end

local function RefreshBarButtons()
    for barID, button in pairs(barButtons) do
        button:SetSelected(barID == selectedBarID)
    end
end

local function RefreshCategoryPage()
    if layoutPage then
        local showing = selectedCategory == "Layout"
        layoutPage:SetShown(showing)

        if showing and layoutPage.Refresh then
            layoutPage:Refresh()
        end
    end

    if appearancePage then
        local showing = selectedCategory == "Appearance"
        appearancePage:SetShown(showing)

        if showing then
            if appearancePage.ResetScroll then
                appearancePage:ResetScroll()
            end

            if appearancePage.Refresh then
                appearancePage:Refresh()
            end
        end
    end

    if visibilityPage then
        local showing = selectedCategory == "Visibility"
        visibilityPage:SetShown(showing)

        if showing then
            if visibilityPage.ResetScroll then
                visibilityPage:ResetScroll()
            end

            if visibilityPage.Refresh then
                visibilityPage:Refresh()
            end
        end
    end

    if actionPagesPage then
        local showing = selectedCategory == "Action Pages"
        actionPagesPage:SetShown(showing)

        if showing then
            if actionPagesPage.ResetScroll then
                actionPagesPage:ResetScroll()
            end

            if actionPagesPage.Refresh then
                actionPagesPage:Refresh()
            end
        end
    end

    if keybindsPage then
        local showing = selectedCategory == "Keybinds"
        keybindsPage:SetShown(showing)

        if showing then
            if keybindsPage.ResetScroll then
                keybindsPage:ResetScroll()
            end

            if keybindsPage.Refresh then
                keybindsPage:Refresh()
            end
        end
    end
end

local function RefreshCategoryButtons()
    for name, button in pairs(categoryButtons) do
        button:SetSelected(name == selectedCategory)
    end

    RefreshCategoryPage()
end

local function ClearBarButtons()
    for _, button in pairs(barButtons) do
        button:Hide()
    end

    barButtons = {}
end

local function UpdateDynamicLayout()
    if not panel
        or not barSelectorSection
        or not categoryFrame
        or not pageHost
    then
        return
    end

    local ids = ns.GetBarIDs()
    local totalRows = math.max(1, math.ceil(#ids / BAR_COLUMNS))
    local visibleRows = math.min(BAR_VISIBLE_ROWS, totalRows)

    local selectorHeight =
        SELECTOR_TITLE_HEIGHT
        + visibleRows * SELECTOR_ROW_HEIGHT
        + SELECTOR_BOTTOM_PADDING

    selectorHeight = math.max(116, selectorHeight)

    barSelectorSection:SetHeight(selectorHeight)
    barSelectorViewport:SetHeight(visibleRows * SELECTOR_ROW_HEIGHT)

    local categoryY = SELECTOR_TOP - selectorHeight - 12

    categoryFrame:ClearAllPoints()
    categoryFrame:SetPoint(
        "TOPLEFT", panel, "TOPLEFT", 22, categoryY
    )

    local pageY = categoryY - 48

    pageHost:ClearAllPoints()
    pageHost:SetPoint(
        "TOPLEFT", panel, "TOPLEFT", 22, pageY
    )
    pageHost:SetPoint(
        "BOTTOMRIGHT", panel, "BOTTOMRIGHT", -22, 58
    )
end

local function RefreshBarSelector()
    if not barSelectorViewport then
        return
    end

    ClearBarButtons()
    ClampBarSelectorOffset()

    local ids = ns.GetBarIDs()
    local firstIndex = barSelectorOffset * BAR_COLUMNS + 1
    local lastIndex = math.min(
        #ids, firstIndex + BAR_VISIBLE_COUNT - 1
    )

    local visibleIndex = 0

    for index = firstIndex, lastIndex do
        local barID = ids[index]
        local settings = ns.db.bars[barID]
        local column = visibleIndex % BAR_COLUMNS
        local row = math.floor(visibleIndex / BAR_COLUMNS)
        local button = barButtonPool[visibleIndex + 1]

        if not button then
            button = widgets.CreateTabButton(
                barSelectorViewport,
                "",
                BAR_BUTTON_WIDTH,
                BAR_BUTTON_HEIGHT,
                0,
                0,
                function(self)
                    SelectBar(self.barID)
                end
            )

            button.enableCheckbox = widgets.CreateCheckButton(
                button,
                "",
                2,
                -3,
                function()
                    local buttonSettings = ns.db.bars[button.barID]
                    return buttonSettings and buttonSettings.enabled or false
                end,
                function(value)
                    ns.SetBarEnabled(button.barID, value)
                    button.enableCheckbox:Refresh()
                    RefreshControls()
                end
            )

            barButtonPool[visibleIndex + 1] = button
        end

        button.barID = barID

        button:ClearAllPoints()
        button:SetPoint(
            "TOPLEFT",
            barSelectorViewport,
            "TOPLEFT",
            column * (BAR_BUTTON_WIDTH + BAR_BUTTON_SPACING),
            -row * SELECTOR_ROW_HEIGHT
        )

        button:SetText(settings.name)
        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT", button, "LEFT", 28, 0)
        button.label:SetPoint("RIGHT", button, "RIGHT", -4, 0)
        button.label:SetWordWrap(false)

        button.enableCheckbox:Refresh()
        button:SetSelected(barID == selectedBarID)
        button:Show()

        barButtons[barID] = button
        visibleIndex = visibleIndex + 1
    end

    UpdateDynamicLayout()
end

RefreshControls = function()
    if hideBlizzardCheckbox then
        hideBlizzardCheckbox:Refresh()
    end

    local settings = GetSelectedSettings()

    if not settings then
        return
    end

    if unlockButton then
        if settings.enabled then
            unlockButton:Enable()

            if ns.IsBarUnlocked(selectedBarID) then
                unlockButton:SetText("Lock Bar")
            else
                unlockButton:SetText("Unlock Bar")
            end
        else
            unlockButton:Disable()
            unlockButton:SetText("Unlock Bar")
        end
    end

    if unlockAllButton then
        if ns.IsMoveModeActive() or ns.AreAllEnabledBarsUnlocked() then
            unlockAllButton:SetText("Lock All Bars")
        else
            unlockAllButton:SetText("Unlock All Bars")
        end
    end

    if deleteButton then
        deleteButton:SetShown(settings.source == "custom")
    end

    if layoutPage and layoutPage.Refresh then
        layoutPage:Refresh()
    end

    if appearancePage and appearancePage.Refresh then
        appearancePage:Refresh()
    end

    if visibilityPage and visibilityPage.Refresh then
        visibilityPage:Refresh()
    end

    if actionPagesPage and actionPagesPage.Refresh then
        actionPagesPage:Refresh()
    end

    if keybindsPage and keybindsPage.Refresh then
        keybindsPage:Refresh()
    end

    RefreshBarButtons()
    RefreshCategoryButtons()
end

function ns.RefreshConfig()
    if selectedTopLevel == "General" then
        if generalPage and generalPage.Refresh then
            generalPage:Refresh()
        end

        return
    end

    if selectedTopLevel == "Profiles" then
        if profilesPage and profilesPage.Refresh then
            profilesPage:Refresh()
        end

        return
    end

    if not ns.db.bars[selectedBarID] then
        local ids = ns.GetBarIDs()

        selectedBarID = ids[1] or 1
        barSelectorOffset = 0

        EnsureSelectedBarVisible()
        RefreshBarSelector()
    end

    RefreshControls()
end

SelectBar = function(barID)
    if not ns.db.bars[barID] then
        return
    end

    local oldBarID = selectedBarID

    if not ns.IsMoveModeActive() and ns.IsBarUnlocked(oldBarID) then
        ns.SetBarUnlocked(oldBarID, false)
    end

    selectedBarID = barID

    EnsureSelectedBarVisible()
    RefreshBarSelector()
    RefreshControls()
end

local function ResetSelectedBar()
    if InCombatLockdown() then
        return
    end

    local settings = GetSelectedSettings()

    if not settings then
        return
    end

    local defaultSettings = ns.CreateDefaultBarSettings(
        selectedBarID, settings.enabled, settings.source
    )

    local currentName = settings.name
    local currentAssignments = settings.assignments
    local currentKeybinds = settings.keybinds

    settings.buttonCount = defaultSettings.buttonCount
    settings.buttonSize = defaultSettings.buttonSize
    settings.spacing = defaultSettings.spacing
    settings.columns = defaultSettings.columns
    settings.scale = defaultSettings.scale

    settings.appearance = {
        iconZoom = defaultSettings.appearance.iconZoom,
        showBorder = defaultSettings.appearance.showBorder,
        emptyOpacity = defaultSettings.appearance.emptyOpacity,
        showCooldown = defaultSettings.appearance.showCooldown,
        showCooldownText = defaultSettings.appearance.showCooldownText,
        showCount = defaultSettings.appearance.showCount,
        countTextSize = defaultSettings.appearance.countTextSize,
        showKeybind = defaultSettings.appearance.showKeybind,
        keybindTextSize = defaultSettings.appearance.keybindTextSize,
        keybindPosition = defaultSettings.appearance.keybindPosition,

        keybindColor = {
            r = defaultSettings.appearance.keybindColor.r,
            g = defaultSettings.appearance.keybindColor.g,
            b = defaultSettings.appearance.keybindColor.b,
            a = defaultSettings.appearance.keybindColor.a,
        },

        desaturateUnusable = defaultSettings.appearance.desaturateUnusable,
        rangeColoring = defaultSettings.appearance.rangeColoring,
        usabilityColoring = defaultSettings.appearance.usabilityColoring,
    }

    settings.visibility = {
        mode = defaultSettings.visibility.mode,
        hideMounted = defaultSettings.visibility.hideMounted,
        hideVehicle = defaultSettings.visibility.hideVehicle,
        hidePetBattle = defaultSettings.visibility.hidePetBattle,
    }

    settings.actionPages = {
        shift = {
            enabled = defaultSettings.actionPages.shift.enabled,
            page = defaultSettings.actionPages.shift.page,
        },
        ctrl = {
            enabled = defaultSettings.actionPages.ctrl.enabled,
            page = defaultSettings.actionPages.ctrl.page,
        },
        alt = {
            enabled = defaultSettings.actionPages.alt.enabled,
            page = defaultSettings.actionPages.alt.page,
        },
    }

    settings.position.point = defaultSettings.position.point
    settings.position.relativePoint = defaultSettings.position.relativePoint
    settings.position.x = defaultSettings.position.x
    settings.position.y = defaultSettings.position.y

    settings.name = currentName
    settings.keybinds = currentKeybinds or {}

    if settings.source == "custom" then
        settings.assignments = currentAssignments or {}
    end

    ns.UpdateBar(selectedBarID)

    if ns.ApplyAllKeybinds then
        ns.ApplyAllKeybinds()
    end

    if ns.ApplyBarAppearance then
        ns.ApplyBarAppearance(selectedBarID)
    end

    ns.RefreshBarMover(selectedBarID)
    RefreshControls()
end

local function FitConfigToScreen()
    if not panel then
        return
    end

    local targetHeight =
        isMinimized and MINIMIZED_HEIGHT or WINDOW_HEIGHT

    local scale = math.min(
        1,
        (UIParent:GetWidth() - 32) / WINDOW_WIDTH,
        (UIParent:GetHeight() - 32) / targetHeight
    )

    panel:SetScale(scale)
end

SetTopLevelMode = function(mode)
    if mode ~= "General"
        and mode ~= "Action Bars"
        and mode ~= "Profiles"
    then
        return
    end

    if renameDialog then
        renameDialog:Hide()
    end

    selectedTopLevel = mode

    if generalTab then
        generalTab:SetSelected(mode == "General")
    end

    if actionBarsTab then
        actionBarsTab:SetSelected(mode == "Action Bars")
    end

    if profilesTab then
        profilesTab:SetSelected(mode == "Profiles")
    end

    local showGeneral = not isMinimized and mode == "General"
    local showActionBars = not isMinimized and mode == "Action Bars"
    local showProfiles = not isMinimized and mode == "Profiles"
    local showProfileActions = not isMinimized and mode ~= "General"

    if generalHost then
        generalHost:SetShown(showGeneral)
    end

    if actionBarSettingsSection then
        actionBarSettingsSection:SetShown(showActionBars)
    end

    if barSelectorSection then
        barSelectorSection:SetShown(showActionBars)
    end

    if categoryFrame then
        categoryFrame:SetShown(showActionBars)
    end

    if pageHost then
        pageHost:SetShown(showActionBars)
    end

    if resetButton then
        resetButton:SetShown(showActionBars)
    end

    if deleteButton then
        local settings = GetSelectedSettings()

        deleteButton:SetShown(
            showActionBars
            and settings
            and settings.source == "custom"
        )
    end

    if profilesHost then
        profilesHost:SetShown(showProfiles)
    end

    if applyChangesButton then
        applyChangesButton:SetShown(not isMinimized)
    end

    if revertChangesButton then
        revertChangesButton:SetShown(not isMinimized)
    end

    if resetAllButton then
        resetAllButton:SetShown(showProfileActions)
    end

    if showGeneral then
        if generalPage and generalPage.Refresh then
            generalPage:Refresh()
        end
    elseif showActionBars then
        RefreshControls()
    elseif showProfiles and profilesPage and profilesPage.Refresh then
        profilesPage:Refresh()
    end
end

local function SetMinimized(minimized)
    isMinimized = minimized

    if minimized then
        panel:SetHeight(MINIMIZED_HEIGHT)
        minimizeButton:SetText("Restore")
    else
        panel:SetHeight(WINDOW_HEIGHT)
        minimizeButton:SetText("Minimize")
    end

    SetTopLevelMode(selectedTopLevel)
    FitConfigToScreen()
end

local function HideConfirmationDialog()
    if confirmationDialog then
        confirmationDialog:Hide()
    end

    if confirmationOverlay then
        confirmationOverlay:Hide()
    end

    confirmationActions = {}
    confirmationButtonCount = 0
end

local function RunConfirmationAction(index)
    local action = confirmationActions[index]

    if action then
        local shouldClose = action()

        if shouldClose == false then
            return
        end
    end

    HideConfirmationDialog()
end

local function CreateConfirmationDialog()
    if confirmationDialog then
        return confirmationDialog
    end

    confirmationOverlay = CreateFrame("Frame", nil, panel)
    confirmationOverlay:SetAllPoints(panel)
    confirmationOverlay:SetFrameLevel(panel:GetFrameLevel() + 90)
    confirmationOverlay:EnableMouse(true)

    local dim = confirmationOverlay:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints()
    dim:SetColorTexture(0, 0, 0, 0.58)

    confirmationDialog = CreateFrame(
        "Frame", nil, confirmationOverlay, "BackdropTemplate"
    )

    confirmationDialog:SetSize(560, 210)
    confirmationDialog:SetPoint("CENTER", panel, "CENTER", 0, 20)
    confirmationDialog:SetFrameLevel(
        confirmationOverlay:GetFrameLevel() + 10
    )

    widgets.SetBackdrop(confirmationDialog, colors.background)

    confirmationTitle = confirmationDialog:CreateFontString(
        nil, "OVERLAY"
    )

    SetFont(confirmationTitle, 16, false)

    confirmationTitle:SetPoint(
        "TOPLEFT", confirmationDialog, "TOPLEFT", 22, -20
    )

    confirmationMessage = confirmationDialog:CreateFontString(
        nil, "OVERLAY"
    )

    SetFont(confirmationMessage, 11, true)

    confirmationMessage:SetPoint(
        "TOPLEFT", confirmationTitle, "BOTTOMLEFT", 0, -16
    )
    confirmationMessage:SetWidth(516)
    confirmationMessage:SetJustifyH("LEFT")
    confirmationMessage:SetJustifyV("TOP")

    for index = 1, 3 do
        local buttonIndex = index

        confirmationButtons[index] = widgets.CreateButton(
            confirmationDialog,
            "",
            150,
            34,
            0,
            -152,
            function()
                RunConfirmationAction(buttonIndex)
            end
        )

        confirmationButtons[index]:Hide()
    end

    confirmationDialog:EnableKeyboard(true)
    confirmationDialog:SetPropagateKeyboardInput(false)

    confirmationDialog:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            if confirmationButtonCount > 0 then
                RunConfirmationAction(confirmationButtonCount)
            else
                HideConfirmationDialog()
            end

            return
        end

        if key == "ENTER" and confirmationButtonCount > 0 then
            RunConfirmationAction(1)
        end
    end)

    confirmationOverlay:Hide()
    confirmationDialog:Hide()

    return confirmationDialog
end

local function ShowConfirmationDialog(options)
    CreateConfirmationDialog()

    confirmationTitle:SetText(options.title or "Confirm")
    confirmationMessage:SetText(options.message or "")

    confirmationActions = {}

    local buttons = options.buttons or {}
    confirmationButtonCount = math.min(3, #buttons)

    for index = 1, 3 do
        confirmationButtons[index]:Hide()
        confirmationActions[index] = nil
    end

    local positions

    if confirmationButtonCount == 1 then
        positions = {205}
    elseif confirmationButtonCount == 2 then
        positions = {116, 294}
    else
        positions = {34, 205, 376}
    end

    for index = 1, confirmationButtonCount do
        local definition = buttons[index]
        local button = confirmationButtons[index]

        button:ClearAllPoints()
        button:SetPoint(
            "TOPLEFT",
            confirmationDialog,
            "TOPLEFT",
            positions[index],
            -152
        )

        button:SetText(definition.text or "Okay")
        confirmationActions[index] = definition.action
        button:Show()
    end

    confirmationOverlay:Show()
    confirmationDialog:Show()

    confirmationDialog:SetFrameLevel(
        confirmationOverlay:GetFrameLevel() + 10
    )
end

ns.ShowConfigConfirmation = ShowConfirmationDialog

local function ShowDeleteBarConfirmation(barID, barName)
    ShowConfirmationDialog({
        title = "Delete Bar",

        message =
            "Delete \"" .. barName
            .. "\"?\n\nAll actions and settings stored on this custom bar will be permanently removed.",

        buttons = {
            {
                text = "Delete",
                action = function()
                    local success, reason = ns.DeleteBar(barID)

                    if not success then
                        if reason == "combat" then
                            print(
                                "|cff7fd5ffMythInc Action Bars:|r Cannot delete an action bar during combat."
                            )
                        end

                        return false
                    end

                    selectedBarID = GetFallbackBarID(barID) or 1

                    EnsureSelectedBarVisible()
                    RefreshBarSelector()
                    RefreshControls()

                    return true
                end,
            },
            {
                text = "Cancel",
            },
        },
    })
end

local function ShowRevertConfirmation()
    ShowConfirmationDialog({
        title = "Revert Changes",

        message =
            "Revert changes to the active profile?\n\nSettings will return to the last applied state.",

        buttons = {
            {
                text = "Revert Changes",
                action = function()
                    if ns.LockAllBars then
                        ns.LockAllBars()
                    end

                    local success, reason = ns.RevertConfigChanges()

                    if not success then
                        if reason == "combat" then
                            print(
                                "|cff7fd5ffMythInc Action Bars:|r Changes cannot be reverted during combat."
                            )
                        end

                        return false
                    end

                    return true
                end,
            },
            {
                text = "Cancel",
            },
        },
    })
end

local function ShowResetAllConfirmation()
    ShowConfirmationDialog({
        title = "Reset All",

        message =
            "Reset the active profile to defaults?\n\nAll action bar settings, custom bars, assignments, and keybinds in this profile will be reset.",

        buttons = {
            {
                text = "Reset All",
                action = function()
                    if ns.LockAllBars then
                        ns.LockAllBars()
                    end

                    local success, reason =
                        ns.ResetActiveProfileToDefaults()

                    if not success then
                        if reason == "combat" then
                            print(
                                "|cff7fd5ffMythInc Action Bars:|r The active profile cannot be reset during combat."
                            )
                        end

                        return false
                    end

                    return true
                end,
            },
            {
                text = "Cancel",
            },
        },
    })
end

local function ShowUnappliedChangesDialog()
    ShowConfirmationDialog({
        title = "Unapplied Changes",

        message =
            "You have changes that have not been applied. What would you like to do?",

        buttons = {
            {
                text = "Apply Changes",
                action = function()
                    ns.ApplyConfigChanges()

                    allowConfigClose = true
                    panel:Hide()

                    return true
                end,
            },
            {
                text = "Revert Changes",
                action = function()
                    local success, reason = ns.RevertConfigChanges()

                    if not success then
                        if reason == "combat" then
                            print(
                                "|cff7fd5ffMythInc Action Bars:|r Changes cannot be reverted during combat."
                            )
                        end

                        return false
                    end

                    allowConfigClose = true
                    panel:Hide()

                    return true
                end,
            },
            {
                text = "Cancel",
            },
        },
    })
end

RequestCloseConfig = function()
    if not panel or not panel:IsShown() then
        return
    end

    if ns.HasConfigChanges and ns.HasConfigChanges() then
        ShowUnappliedChangesDialog()
        return
    end

    allowConfigClose = true
    panel:Hide()
end

local function CreateHeader()
    logoTexture = panel:CreateTexture(nil, "ARTWORK")
    logoTexture:SetSize(96, 96)
    logoTexture:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -10)
    logoTexture:SetTexture(
        "Interface\\AddOns\\MythIncActionBars\\Media\\Artwork\\MIUF_Icon_128.png"
    )

    local title = panel:CreateFontString(nil, "OVERLAY")
    SetFont(title, 17)
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 120, -16)
    title:SetText("M Y T H Inc Action Bars")

    local version = panel:CreateFontString(nil, "OVERLAY")
    SetFont(version, 10, true)
    version:SetPoint("LEFT", title, "RIGHT", 10, -1)
    version:SetText(ns.version)

    widgets.CreateButton(
        panel, "X", 28, 24, WINDOW_WIDTH - 38, -10,
        function()
            RequestCloseConfig()
        end
    )

    minimizeButton = widgets.CreateButton(
        panel, "Minimize", 86, 24, WINDOW_WIDTH - 130, -10,
        function()
            SetMinimized(not isMinimized)
        end
    )

    generalTab = widgets.CreateTabButton(
        panel, "General", 110, 28, 180, -48,
        function()
            SetTopLevelMode("General")
        end
    )

    actionBarsTab = widgets.CreateTabButton(
        panel, "Action Bars", 110, 28, 298, -48,
        function()
            SetTopLevelMode("Action Bars")
        end
    )

    profilesTab = widgets.CreateTabButton(
        panel, "Profiles", 110, 28, 416, -48,
        function()
            SetTopLevelMode("Profiles")
        end
    )

    actionBarsTab:SetSelected(true)
end

local function CreateActionBarSettingsSection()
    actionBarSettingsSection = widgets.CreateSection(
        panel, "ACTION BAR SETTINGS", 1036, 62, 22, -96
    )

    hideBlizzardCheckbox = widgets.CreateCheckButton(
        actionBarSettingsSection,
        "Hide Blizzard Action Bars",
        18,
        -32,
        function()
            return ns.AreBlizzardActionBarsHidden()
        end,
        function(value)
            local success, reason =
                ns.SetHideBlizzardActionBars(value)

            if not success and reason == "combat" then
                print(
                    "|cff7fd5ffMythInc Action Bars:|r Blizzard bar visibility will update when combat ends."
                )
            end
        end
    )
end

local function CreateBarSelector()
    barSelectorSection = widgets.CreateSection(
        panel, "ACTION BARS", 1036, 100, 22, SELECTOR_TOP
    )

    barSelectorViewport = CreateFrame(
        "Frame", nil, barSelectorSection
    )

    barSelectorViewport:SetSize(780, SELECTOR_ROW_HEIGHT)
    barSelectorViewport:SetPoint(
        "TOPLEFT", barSelectorSection, "TOPLEFT", 12, -36
    )
    barSelectorViewport:SetClipsChildren(true)
    barSelectorViewport:EnableMouseWheel(true)

    barSelectorViewport:SetScript("OnMouseWheel", function(_, delta)
        local ids = ns.GetBarIDs()
        local totalRows = math.ceil(#ids / BAR_COLUMNS)
        local maxOffset = math.max(
            0, totalRows - BAR_VISIBLE_ROWS
        )

        if delta < 0 then
            barSelectorOffset = math.min(
                maxOffset, barSelectorOffset + 1
            )
        elseif delta > 0 then
            barSelectorOffset = math.max(
                0, barSelectorOffset - 1
            )
        end

        RefreshBarSelector()
    end)

    addButton = widgets.CreateButton(
        barSelectorSection, "Add Action Bar", 110, 30, 912, -74,
        function()
            local barID, reason = ns.AddBar()

            if not barID then
                if reason == "combat" then
                    print(
                        "|cff7fd5ffMythInc Action Bars:|r Cannot create an action bar during combat."
                    )
                end

                return
            end

            SelectBar(barID)
        end
    )

    unlockAllButton = widgets.CreateButton(
        barSelectorSection, "Unlock All Bars", 110, 30, 796, -74,
        function()
            local success, reason = ns.ToggleAllBarsUnlocked()

            if not success and reason == "combat" then
                print(
                    "|cff7fd5ffMythInc Action Bars:|r Bars cannot be unlocked during combat."
                )
            end

            RefreshControls()
        end
    )
end

local function CreateBarManagementControls()
    local renameBarID

    local function HideRenameDialog()
        if renameDialog then
            renameDialog:Hide()
        end
    end

    widgets.CreateButton(
        barSelectorSection, "Rename Bar", 110, 30, 796, -38,
        function()
            renameBarID = selectedBarID

            if not renameDialog then
                renameDialog = CreateFrame("Frame", nil, panel)
                renameDialog:SetAllPoints(panel)
                renameDialog:SetFrameLevel(panel:GetFrameLevel() + 80)
                renameDialog:EnableMouse(true)

                local dim = renameDialog:CreateTexture(
                    nil, "BACKGROUND"
                )
                dim:SetAllPoints()
                dim:SetColorTexture(0, 0, 0, 0.75)

                local box = widgets.CreateSection(
                    renameDialog, "RENAME BAR", 420, 166, 0, 0
                )
                box:ClearAllPoints()
                box:SetPoint("CENTER", renameDialog, "CENTER")

                nameControl = widgets.CreateEditBox(
                    box,
                    "Name",
                    370,
                    20,
                    -38,
                    function()
                        local settings = ns.db.bars[renameBarID]
                        return settings and settings.name or ""
                    end,
                    function()
                    end
                )

                local function SaveName()
                    local settings = ns.db.bars[renameBarID]
                    local value = nameControl.editBox:GetText():match(
                        "^%s*(.-)%s*$"
                    )

                    if not settings or value == "" then
                        return
                    end

                    settings.name = value
                    ns.RefreshBarMover(renameBarID)

                    HideRenameDialog()
                    RefreshBarSelector()
                    RefreshControls()
                end

                nameControl.editBox:SetScript(
                    "OnEnterPressed", SaveName
                )
                nameControl.editBox:SetScript(
                    "OnEscapePressed", HideRenameDialog
                )

                widgets.CreateButton(
                    box, "Save", 110, 30, 170, -118, SaveName
                )
                widgets.CreateButton(
                    box, "Cancel", 110, 30, 288, -118, HideRenameDialog
                )
            end

            nameControl:Refresh()
            renameDialog:Show()
            nameControl.editBox:SetFocus()
            nameControl.editBox:HighlightText()
        end
    )

    unlockButton = widgets.CreateButton(
        barSelectorSection, "Unlock Bar", 110, 30, 912, -38,
        function()
            local settings = GetSelectedSettings()

            if not settings or not settings.enabled then
                return
            end

            ns.SetBarUnlocked(
                selectedBarID,
                not ns.IsBarUnlocked(selectedBarID)
            )

            RefreshControls()
        end
    )
end

local function CreateCategoryTabs()
    categoryFrame = CreateFrame("Frame", nil, panel)
    categoryFrame:SetSize(1036, 34)
    categoryFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -366)

    local width = 196
    local spacing = 10

    for index, name in ipairs(CATEGORY_NAMES) do
        local button = widgets.CreateTabButton(
            categoryFrame,
            name,
            width,
            34,
            (index - 1) * (width + spacing),
            0,
            function()
                selectedCategory = name
                RefreshCategoryButtons()
            end
        )

        categoryButtons[name] = button
    end
end

local function CreatePageHost()
    pageHost = CreateFrame("Frame", nil, panel)
    pageHost:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -414)
    pageHost:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -22, 58)
    pageHost:SetClipsChildren(true)

    layoutPage = ns.CreateLayoutConfigPage(pageHost, {
        GetSelectedSettings = GetSelectedSettings,
        GetSelectedBarID = GetSelectedBarID,
        RefreshConfig = RefreshControls,
    })

    appearancePage = ns.CreateAppearanceConfigPage(pageHost, {
        GetSelectedSettings = GetSelectedSettings,
        GetSelectedBarID = GetSelectedBarID,
    })

    visibilityPage = ns.CreateVisibilityConfigPage(pageHost, {
        GetSelectedSettings = GetSelectedSettings,
        GetSelectedBarID = GetSelectedBarID,
    })

    actionPagesPage = ns.CreateActionPagesConfigPage(pageHost, {
        GetSelectedSettings = GetSelectedSettings,
        GetSelectedBarID = GetSelectedBarID,
    })

    keybindsPage = ns.CreateKeybindsConfigPage(pageHost, {
        GetSelectedSettings = GetSelectedSettings,
        GetSelectedBarID = GetSelectedBarID,
    })

    layoutPage:SetAllPoints(pageHost)
    appearancePage:SetAllPoints(pageHost)
    visibilityPage:SetAllPoints(pageHost)
    actionPagesPage:SetAllPoints(pageHost)
    keybindsPage:SetAllPoints(pageHost)

    layoutPage:Show()
    appearancePage:Hide()
    visibilityPage:Hide()
    actionPagesPage:Hide()
    keybindsPage:Hide()
end

local function CreateGeneralHost()
    generalHost = CreateFrame("Frame", nil, panel)
    generalHost:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -96)
    generalHost:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -22, 58)

    generalPage = ns.CreateGeneralConfigPage(generalHost)
    generalPage:SetAllPoints(generalHost)

    generalHost:Hide()
end

local function CreateProfilesHost()
    profilesHost = CreateFrame("Frame", nil, panel)
    profilesHost:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -96)
    profilesHost:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -22, 58)

    profilesPage = ns.CreateProfilesConfigPage(profilesHost)
    profilesPage:SetAllPoints(profilesHost)

    profilesHost:Hide()
end

local function CreateBottomActions()
    applyChangesButton = widgets.CreateButton(
        panel, "Apply Changes", 146, 30, 22, -(WINDOW_HEIGHT - 46),
        function()
            local success = ns.ApplyConfigChanges()

            if success then
                print(
                    "|cff7fd5ffMythInc Action Bars:|r Changes applied."
                )
            end
        end
    )

    revertChangesButton = widgets.CreateButton(
        panel, "Revert Changes", 146, 30, 178, -(WINDOW_HEIGHT - 46),
        function()
            if InCombatLockdown() then
                print(
                    "|cff7fd5ffMythInc Action Bars:|r Changes cannot be reverted during combat."
                )
                return
            end

            if not ns.CanRevertConfigChanges() then
                print(
                    "|cff7fd5ffMythInc Action Bars:|r There is no saved state to revert to."
                )
                return
            end

            ShowRevertConfirmation()
        end
    )

    resetButton = widgets.CreateButton(
        panel, "Reset Bar", 130, 30, 346, -(WINDOW_HEIGHT - 46),
        function()
            ResetSelectedBar()
        end
    )

    deleteButton = widgets.CreateButton(
        panel, "Delete Bar", 130, 30, 486, -(WINDOW_HEIGHT - 46),
        function()
            local settings = GetSelectedSettings()

            if not settings or settings.source ~= "custom" then
                return
            end

            if InCombatLockdown() then
                print(
                    "|cff7fd5ffMythInc Action Bars:|r Cannot delete an action bar during combat."
                )
                return
            end

            ShowDeleteBarConfirmation(selectedBarID, settings.name)
        end
    )

    resetAllButton = widgets.CreateButton(
        panel,
        "Reset All",
        110,
        30,
        WINDOW_WIDTH - 132,
        -(WINDOW_HEIGHT - 46),
        function()
            if InCombatLockdown() then
                print(
                    "|cff7fd5ffMythInc Action Bars:|r The active profile cannot be reset during combat."
                )
                return
            end

            ShowResetAllConfirmation()
        end
    )
end

local function CreateConfigPanel()
    if panel then
        return panel
    end

    panel = CreateFrame(
        "Frame",
        "MythIncActionBarsConfig",
        UIParent,
        "BackdropTemplate"
    )

    table.insert(UISpecialFrames, "MythIncActionBarsConfig")

    panel:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    panel:SetPoint("CENTER")

    widgets.SetBackdrop(panel, colors.background)

    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")

    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

    panel:RegisterEvent("UI_SCALE_CHANGED")
    panel:RegisterEvent("DISPLAY_SIZE_CHANGED")
    panel:SetScript("OnEvent", FitConfigToScreen)

    CreateHeader()
    CreateActionBarSettingsSection()
    CreateBarSelector()
    CreateBarManagementControls()
    CreateCategoryTabs()
    CreatePageHost()
    CreateGeneralHost()
    CreateProfilesHost()
    CreateBottomActions()

    panel:SetScript("OnShow", function()
        if suppressNextSessionStart then
            suppressNextSessionStart = false
        elseif ns.BeginConfigSession then
            ns.BeginConfigSession()
        end

        allowConfigClose = false

        if not ns.db.bars[selectedBarID] then
            local ids = ns.GetBarIDs()
            selectedBarID = ids[1] or 1
        end

        EnsureSelectedBarVisible()
        RefreshBarSelector()

        SetTopLevelMode(selectedTopLevel)
        FitConfigToScreen()
    end)

    panel:SetScript("OnHide", function()
        if renameDialog then
            renameDialog:Hide()
        end

        if ns.LockAllBars then
            ns.LockAllBars()
        end

        if allowConfigClose then
            allowConfigClose = false
            return
        end

        if ns.HasConfigChanges and ns.HasConfigChanges() then
            suppressNextSessionStart = true

            C_Timer.After(0, function()
                if not panel:IsShown() then
                    panel:Show()
                end

                ShowUnappliedChangesDialog()
            end)
        end
    end)

    panel:Hide()
    FitConfigToScreen()

    return panel
end

function ns.ToggleConfig()
    local config = CreateConfigPanel()

    if config:IsShown() then
        RequestCloseConfig()
    else
        config:Show()
    end
end

SLASH_MYTHINCACTIONBARS1 = "/miab"
SLASH_MYTHINCACTIONBARS2 = "/mythincactionbars"

SlashCmdList.MYTHINCACTIONBARS = function()
    ns.ToggleConfig()
end