
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
local gridSpacingBox
local gridSpacingLabel
local gridOpacityBox
local gridOpacityLabel
local alignmentGridCheckbox
local hideBlizzardCheckbox
local lockContentsCheckbox
local activateOnPressCheckbox
local barSelectorSection
local barSelectorViewport
local barSelectorOffset = 0
local specialSelectorRowOffset = 0
local actionSelectorScrollbar
local specialSelectorScrollbar
local categoryFrame
local renameDialog
local nameControl
local unlockButton
local unlockAllButton
local pageHost
local specialPage
local renameButton
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
local resizeGrip
local lastResizeClickTime = 0
local resizeHint
local logoTexture
local applyToAllButton
local spellbookLayoutButton

local bulkOverlay
local bulkSourceLabel
local bulkSourcePopup
local bulkSourceButtons = {}
local bulkSourcePreviousButton
local bulkSourceNextButton
local bulkSourcePageLabel
local bulkSourceID
local bulkSourcePage = 1
local bulkTargetButtons = {}
local bulkTargetPage = 1
local bulkTargetPreviousButton
local bulkTargetNextButton
local bulkTargetPageLabel
local bulkTargetSelection = {}
local bulkSettingSelection = {}
local bulkButtons = {}
local bulkSelectionLabel
local bulkApplyButton

local isMinimized = false
local spellbookLayout = false

local WINDOW_WIDTH = 1080
local WINDOW_HEIGHT = 720
local MINIMIZED_HEIGHT = 64
local MIN_WINDOW_HEIGHT = 480
local SCREEN_MARGIN = 32
local preferredWindowHeight = WINDOW_HEIGHT
local resizeInProgress = false
local resizeStartCursorY = 0
local resizeStartHeight = WINDOW_HEIGHT
local resizeBaseScale = 1
local resizeFixedCenterX
local resizeFixedTop

local BAR_BUTTON_WIDTH = 118
local BAR_BUTTON_HEIGHT = 30
local BAR_BUTTON_SPACING = 6
local BAR_COLUMNS = 6
local BAR_VISIBLE_ROWS = 2
local BAR_VISIBLE_COUNT = BAR_COLUMNS * BAR_VISIBLE_ROWS
local SPECIAL_VISIBLE_COUNT = BAR_COLUMNS
local SPECIAL_BAR_IDS = {
    "petBar", "stanceBar", "extraAction", "zoneAbility",
    "vehicleControls", "microMenu", "bagBar",
}
local SELECTOR_TOP = -208
local SELECTOR_ROW_HEIGHT = BAR_BUTTON_HEIGHT + BAR_BUTTON_SPACING

local BULK_SETTINGS = {
    "Layout", "Appearance", "Visibility", "Action Pages",
}

local CATEGORY_NAMES = {
    "Layout", "Appearance", "Visibility", "Action Pages", "Keybinds",
}

local function SetFont(fontString, size, muted)
    fontString:SetFont(font, size, "OUTLINE")
    fontString:SetTextColor(
        unpack(muted and colors.muted or colors.text)
    )
end

local function Message(text)
    print("|cff7fd5ffMythInc Action Bars:|r " .. text)
end

local function DeepCopy(value)
    if type(value) ~= "table" then return value end

    local copy = {}

    for key, entry in pairs(value) do
        copy[key] = DeepCopy(entry)
    end

    return copy
end

local function GetTarget(barID)
    return ns.SpecialConfigTargets
        and ns.SpecialConfigTargets[barID or selectedBarID]
end

local function GetConfigBarIDs()
    local ids = ns.GetBarIDs()

    for _, id in ipairs(SPECIAL_BAR_IDS) do
        if GetTarget(id) then
            ids[#ids + 1] = id
        end
    end

    return ids
end

local function GetConfigSettings(barID)
    local target = GetTarget(barID)

    return target and target.GetSettings()
        or ns.db.bars[barID]
end

local function GetSelectedSettings()
    return GetConfigSettings(selectedBarID)
end

local function GetSelectedBarID()
    return selectedBarID
end

local function IsSelectedUnlocked()
    local target = GetTarget()

    if target then
        return target.IsUnlocked()
    end

    return ns.IsBarUnlocked(selectedBarID)
end

local function UnlockSelected(value)
    local target = GetTarget()

    if target then
        if not InCombatLockdown() then
            target.SetUnlocked(value)
        end
    else
        ns.SetBarUnlocked(selectedBarID, value)
    end
end

local function HideBulkDialog()
    if bulkSourcePopup then
        bulkSourcePopup:Hide()
    end
    if bulkOverlay then
        bulkOverlay:Hide()
    end

    bulkSourceID = nil
end

local function GetFallbackBarID(deletedBarID)
    local ids = ns.GetBarIDs()
    if #ids == 0 then return nil end

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
    for index, barID in ipairs(GetConfigBarIDs()) do
        if barID == selectedBarID then
            return index
        end
    end

    return 1
end

local function GetSpecialBarIDs()
    local ids = {}
    for _, id in ipairs(SPECIAL_BAR_IDS) do
        if GetTarget(id) then
            ids[#ids + 1] = id
        end
    end
    return ids
end

local function ClampBarSelectorOffset()
    local maxOffset = math.max(
        0,
        math.ceil(#ns.GetBarIDs() / BAR_COLUMNS) - BAR_VISIBLE_ROWS
    )

    barSelectorOffset = math.max(
        0,
        math.min(barSelectorOffset, maxOffset)
    )

    local maxSpecialRow = math.max(
        0,
        math.ceil(#GetSpecialBarIDs() / SPECIAL_VISIBLE_COUNT) - 1
    )
    specialSelectorRowOffset = math.max(
        0, math.min(specialSelectorRowOffset, maxSpecialRow)
    )
end

local function EnsureSelectedBarVisible()
    if GetTarget() then
        for index, id in ipairs(GetSpecialBarIDs()) do
            if id == selectedBarID then
                specialSelectorRowOffset = math.floor(
                    (index - 1) / SPECIAL_VISIBLE_COUNT
                )
                break
            end
        end
        ClampBarSelectorOffset()
        return
    end

    local row = math.floor(
        (FindSelectedIndex() - 1) / BAR_COLUMNS
    )

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
    local target = GetTarget()

    if target then
        for _, frame in ipairs({
            layoutPage, appearancePage, visibilityPage,
            actionPagesPage, keybindsPage,
        }) do
            frame:Hide()
        end

        if specialPage then
            specialPage:Show()
            specialPage:Refresh(target, selectedCategory)
        end

        return
    end

    if specialPage then
        specialPage:Hide()
    end

    if layoutPage then
        local showing = selectedCategory == "Layout"
        layoutPage:SetShown(showing)

        if showing and layoutPage.Refresh then
            layoutPage:Refresh()
        end
    end

    local pages = {
        Appearance = appearancePage,
        Visibility = visibilityPage,
        ["Action Pages"] = actionPagesPage,
        Keybinds = keybindsPage,
    }

    for name, frame in pairs(pages) do
        local showing = selectedCategory == name
        frame:SetShown(showing)

        if showing then
            if frame.ResetScroll then
                frame:ResetScroll()
            end

            if frame.Refresh then
                frame:Refresh()
            end
        end
    end
end

local function RefreshCategoryButtons()
    local target = GetTarget()

    local function Supported(name)
        return not target
            or name == "Layout"
            or name == "Appearance"
            or (name == "Keybinds" and target.bindable ~= false)
            or (name == "Visibility" and target.visibility)
            or (name == "Action Pages" and target.paging)
    end

    if not Supported(selectedCategory) then
        selectedCategory = "Layout"
    end

    for name, button in pairs(categoryButtons) do
        button:SetSelected(name == selectedCategory)

        if Supported(name) then
            button:Enable()
        else
            button:Disable()
        end
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
    if not panel or not barSelectorSection
        or not categoryFrame or not pageHost
    then
        return
    end

    barSelectorSection:SetHeight(178)
    barSelectorViewport:SetHeight(
        BAR_VISIBLE_ROWS * SELECTOR_ROW_HEIGHT
    )

    categoryFrame:ClearAllPoints()
    categoryFrame:SetPoint(
        "TOPLEFT", panel, "TOPLEFT",
        22, SELECTOR_TOP - 190
    )

    pageHost:ClearAllPoints()
    pageHost:SetPoint(
        "TOPLEFT", panel, "TOPLEFT",
        22, SELECTOR_TOP - 238
    )
    pageHost:SetPoint(
        "BOTTOMRIGHT", panel, "BOTTOMRIGHT", -22, 58
    )
end

local function CreateSelectorScrollbar(viewport, getMaximum, getOffset, setOffset)
    local track = CreateFrame("Frame", nil, viewport, "BackdropTemplate")
    track:SetWidth(8)
    track:SetPoint("TOPRIGHT", viewport, "TOPRIGHT", -3, -2)
    track:SetPoint("BOTTOMRIGHT", viewport, "BOTTOMRIGHT", -3, 2)
    track:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    track:SetBackdropColor(0.08, 0.10, 0.13, 0.9)
    track:EnableMouse(true)
    track:EnableMouseWheel(true)

    local thumb = CreateFrame("Frame", nil, track, "BackdropTemplate")
    thumb:SetWidth(8)
    thumb:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    thumb:SetBackdropColor(unpack(colors.accent))
    thumb:EnableMouse(true)
    thumb:EnableMouseWheel(true)
    thumb:RegisterForDrag("LeftButton")

    local dragging = false
    local dragOffset = 0

    local function Update()
        local maximum = getMaximum()
        if maximum <= 0 then
            dragging = false
            track:Hide()
            return
        end

        track:Show()
        local height = track:GetHeight()
        if height <= 0 then return end
        local thumbHeight = math.min(
            height,
            math.max(14, height / (maximum + 1))
        )
        thumb:SetHeight(thumbHeight)
        local travel = math.max(0, height - thumbHeight)
        local fraction = math.max(0, math.min(1, getOffset() / maximum))
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -travel * fraction)
    end

    local function FromCursor(keepOffset)
        local _, cursorY = GetCursorPosition()
        local scale = track:GetEffectiveScale()
        local top = track:GetTop()
        if not top or not scale or scale <= 0 then return end
        local height = track:GetHeight()
        local thumbHeight = thumb:GetHeight()
        local travel = math.max(0, height - thumbHeight)
        if travel <= 0 then return end
        local position = top - cursorY / scale
            - (keepOffset and dragOffset or thumbHeight / 2)
        position = math.max(0, math.min(travel, position))
        setOffset(math.floor(position / travel * getMaximum() + 0.5))
    end

    track:SetScript("OnMouseDown", function(_, mouseButton)
        if mouseButton == "LeftButton" then FromCursor(false) end
    end)

    thumb:SetScript("OnDragStart", function()
        local _, cursorY = GetCursorPosition()
        local scale = track:GetEffectiveScale()
        dragOffset = track:GetTop() - cursorY / scale
            - (track:GetTop() - thumb:GetTop())
        dragging = true
    end)
    thumb:SetScript("OnDragStop", function()
        dragging = false
    end)
    thumb:SetScript("OnUpdate", function()
        if dragging then FromCursor(true) end
    end)

    local function Wheel(_, delta)
        setOffset(getOffset() - delta)
    end
    track:SetScript("OnMouseWheel", Wheel)
    thumb:SetScript("OnMouseWheel", Wheel)
    track:Hide()
    return Update
end

local function RefreshBarSelector()
    if not barSelectorViewport then return end

    ClearBarButtons()
    ClampBarSelectorOffset()

    local function PlaceButton(barID, poolIndex, parent, column, row)
        local settings = GetConfigSettings(barID)
        if not settings then return end

        local button = barButtonPool[poolIndex]

        if not button then
            button = widgets.CreateTabButton(
                parent, "",
                BAR_BUTTON_WIDTH, BAR_BUTTON_HEIGHT,
                0, 0,
                function(self)
                    SelectBar(self.barID)
                end
            )

            button.enableCheckbox = widgets.CreateCheckButton(
                button, "", 2, -3,
                function()
                    local entry = GetConfigSettings(button.barID)
                    return entry and entry.enabled or false
                end,
                function(value)
                    local target = GetTarget(button.barID)

                    if target then
                        if not InCombatLockdown() then
                            target.GetSettings().enabled = value
                            target.Refresh()

                            if value and ns.IsMoveModeActive() then
                                target.SetUnlocked(true)
                            end
                        end
                    else
                        ns.SetBarEnabled(button.barID, value)
                    end

                    button.enableCheckbox:Refresh()
                    RefreshControls()
                end
            )

            button:EnableMouseWheel(true)
            button:SetScript("OnMouseWheel", function(self, delta)
                if type(self.barID) == "string" then
                    local maxRow = math.max(
                        0, math.ceil(#GetSpecialBarIDs() / SPECIAL_VISIBLE_COUNT) - 1
                    )
                    specialSelectorRowOffset = math.max(
                        0, math.min(maxRow, specialSelectorRowOffset - delta)
                    )
                else
                    local maxRow = math.max(
                        0, math.ceil(#ns.GetBarIDs() / BAR_COLUMNS) - BAR_VISIBLE_ROWS
                    )
                    barSelectorOffset = math.max(
                        0, math.min(maxRow, barSelectorOffset - delta)
                    )
                end
                RefreshBarSelector()
            end)

            barButtonPool[poolIndex] = button
        end

        button.barID = barID
        button:SetParent(parent)
        local special = type(barID) == "string"
        local width = special and 109 or BAR_BUTTON_WIDTH
        local spacing = special and 2 or BAR_BUTTON_SPACING
        button:SetWidth(width)
        button:ClearAllPoints()
        button:SetPoint(
            "TOPLEFT", parent, "TOPLEFT",
            column * (width + spacing),
            -row * SELECTOR_ROW_HEIGHT
        )

        local target = GetTarget(barID)
        local specialLabels = {
            petBar = "Pet", stanceBar = "Stance",
            extraAction = "Extra", zoneAbility = "Zone",
            vehicleControls = "Vehicle", microMenu = "Micro Menu",
            bagBar = "Bag Bar",
        }
        button:SetText(target and (specialLabels[barID] or target.name) or settings.name)
        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT", button, "LEFT", 28, 0)
        button.label:SetPoint("RIGHT", button, "RIGHT", -4, 0)
        button.label:SetWordWrap(false)
        button.enableCheckbox:Refresh()
        button:SetSelected(barID == selectedBarID)
        button:Show()

        barButtons[barID] = button
    end

    local ids = ns.GetBarIDs()
    local first = barSelectorOffset * BAR_COLUMNS + 1
    local last = math.min(
        #ids, first + BAR_VISIBLE_COUNT - 1
    )

    for index = first, last do
        local visible = index - first

        PlaceButton(
            ids[index],
            visible + 1,
            barSelectorViewport,
            visible % BAR_COLUMNS,
            math.floor(visible / BAR_COLUMNS)
        )
    end

    local specialSelectorViewport =
        barSelectorSection.SpecialViewport

    if not specialSelectorViewport then
        widgets.CreateText(
            barSelectorSection,
            "SPECIAL BARS", 10, 12, -112, true
        )

        specialSelectorViewport = CreateFrame(
            "Frame", nil, barSelectorSection
        )
        specialSelectorViewport:SetPoint(
            "TOPLEFT", barSelectorSection, "TOPLEFT",
            12, -132
        )
        specialSelectorViewport:SetSize(780, 30)
        specialSelectorViewport:SetClipsChildren(true)
        specialSelectorViewport:EnableMouseWheel(true)
        specialSelectorViewport:SetScript("OnMouseWheel", function(_, delta)
            local maxRow = math.max(
                0, math.ceil(#GetSpecialBarIDs() / SPECIAL_VISIBLE_COUNT) - 1
            )
            specialSelectorRowOffset = math.max(
                0, math.min(maxRow, specialSelectorRowOffset - delta)
            )
            RefreshBarSelector()
        end)

        specialSelectorScrollbar = CreateSelectorScrollbar(
            specialSelectorViewport,
            function()
                return math.max(0,
                    math.ceil(#GetSpecialBarIDs() / SPECIAL_VISIBLE_COUNT) - 1
                )
            end,
            function() return specialSelectorRowOffset end,
            function(offset)
                specialSelectorRowOffset = offset
                RefreshBarSelector()
            end
        )

        barSelectorSection.SpecialViewport =
            specialSelectorViewport

        widgets.CreateSection(
            barSelectorSection,
            "BAR TOOLS", 232, 134, 792, -24
        )

        for _, entry in ipairs({
            { renameButton, 804, -60 },
            { unlockButton, 916, -60 },
            { unlockAllButton, 804, -102 },
            { addButton, 916, -102 },
        }) do
            local toolButton = entry[1]
            toolButton:SetWidth(100)
            toolButton:ClearAllPoints()
            toolButton:SetPoint(
                "TOPLEFT", barSelectorSection, "TOPLEFT",
                entry[2], entry[3]
            )
            toolButton:SetFrameLevel(
                barSelectorSection:GetFrameLevel() + 10
            )
        end
    end

    local specialIDs = GetSpecialBarIDs()
    local firstSpecial = specialSelectorRowOffset * SPECIAL_VISIBLE_COUNT + 1
    local lastSpecial = math.min(
        #specialIDs, firstSpecial + SPECIAL_VISIBLE_COUNT - 1
    )
    for index = firstSpecial, lastSpecial do
        PlaceButton(
            specialIDs[index],
            BAR_VISIBLE_COUNT + index - firstSpecial + 1,
            specialSelectorViewport,
            index - firstSpecial,
            0
        )
    end

    UpdateDynamicLayout()
    if actionSelectorScrollbar then actionSelectorScrollbar() end
    if specialSelectorScrollbar then specialSelectorScrollbar() end
end

RefreshControls = function()
    if hideBlizzardCheckbox then
        hideBlizzardCheckbox:Refresh()
    end

    if lockContentsCheckbox then
        lockContentsCheckbox:Refresh()
    end

    if activateOnPressCheckbox then
        activateOnPressCheckbox:Refresh()
    end

    if alignmentGridCheckbox then
        alignmentGridCheckbox:Refresh()
    end

    if gridSpacingBox then
        local visible = ns.IsAlignmentGridEnabled()
        gridSpacingBox:SetShown(visible)
        gridSpacingLabel:SetShown(visible)

        if not gridSpacingBox:HasFocus() then
            gridSpacingBox:SetText(
                tostring(ns.GetAlignmentGridSpacing())
            )
        end
    end

    if gridOpacityBox then
        local visible = ns.IsAlignmentGridEnabled()
        gridOpacityBox:SetShown(visible)
        gridOpacityLabel:SetShown(visible)

        if not gridOpacityBox:HasFocus() then
            gridOpacityBox:SetText(
                tostring(
                    math.floor(
                        ns.GetAlignmentGridOpacity() * 100 + 0.5
                    )
                )
            )
        end
    end

    local settings = GetSelectedSettings()
    if not settings then return end

    if unlockButton then
        if settings.enabled then
            unlockButton:Enable()
            unlockButton:SetText(
                IsSelectedUnlocked() and "Lock Bar" or "Unlock Bar"
            )
        else
            unlockButton:Disable()
            unlockButton:SetText("Unlock Bar")
        end
    end

    if unlockAllButton then
        unlockAllButton:SetText(
            (ns.IsMoveModeActive() or ns.AreAllEnabledBarsUnlocked())
                and "Lock All Bars" or "Unlock All Bars"
        )
    end

    if deleteButton then
        deleteButton:SetShown(settings.source == "custom")
    end

    if renameButton then
        if GetTarget() then
            renameButton:Disable()
        else
            renameButton:Enable()
        end
    end

    if applyToAllButton then
        if GetTarget() then
            applyToAllButton:Disable()
        else
            applyToAllButton:Enable()
        end
    end

    if not GetTarget() then
        for _, frame in ipairs({
            layoutPage, appearancePage, visibilityPage,
            actionPagesPage, keybindsPage,
        }) do
            if frame.Refresh then
                frame:Refresh()
            end
        end
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

    if not GetSelectedSettings() then
        selectedBarID = ns.GetBarIDs()[1] or 1
        barSelectorOffset = 0
        EnsureSelectedBarVisible()
        RefreshBarSelector()
    end

    RefreshControls()
end

SelectBar = function(barID)
    if not GetConfigSettings(barID) then return end

    HideBulkDialog()

    local oldBarID = selectedBarID

    if not ns.IsMoveModeActive() then
        local oldTarget = GetTarget(oldBarID)

        if oldTarget then
            if not InCombatLockdown() then
                oldTarget.SetUnlocked(false)
            end
        elseif ns.IsBarUnlocked(oldBarID) then
            ns.SetBarUnlocked(oldBarID, false)
        end
    end

    selectedBarID = barID
    EnsureSelectedBarVisible()
    RefreshBarSelector()
    RefreshControls()
end

local function ResetSelectedBar()
    if InCombatLockdown() then return end

    local settings = GetSelectedSettings()
    if not settings then return end

    local target = GetTarget()

    if target then
        for key, value in pairs(target.defaults) do
            if key ~= "enabled"
                and key ~= "keybinds"
                and type(value) ~= "table"
            then
                settings[key] = value
            end
        end

        target.Refresh()
        RefreshControls()
        return
    end

    local defaults = ns.CreateDefaultBarSettings(
        selectedBarID, settings.enabled, settings.source
    )

    for _, key in ipairs({
        "buttonCount", "buttonSize", "spacing", "columns", "scale",
        "appearance", "visibility", "actionPages", "position",
    }) do
        settings[key] = DeepCopy(defaults[key])
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

local function GetBulkBarIDs()
    local ids = {}

    for _, barID in ipairs(ns.GetBarIDs()) do
        if ns.db and ns.db.bars
            and ns.db.bars[barID]
            and not GetTarget(barID)
        then
            ids[#ids + 1] = barID
        end
    end

    return ids
end

local function BulkBarLabel(barID)
    local settings = ns.db.bars[barID]
    if not settings then return "Unknown Bar" end
    local label = "Bar " .. barID
    if settings.name and settings.name ~= label then
        label = label .. " - " .. settings.name
    end
    return label
end

local function BulkTargets()
    local result = {}
    for _, id in ipairs(GetBulkBarIDs()) do
        if id ~= bulkSourceID then
            result[#result + 1] = id
        end
    end
    return result
end

local function BulkPagesSupported()
    return bulkSourceID and ns.BarSupportsActionPages(bulkSourceID)
end

local function RefreshBulkSourceList()
    if not bulkSourcePopup then return end
    local ids = GetBulkBarIDs()
    local pages = math.max(1, math.ceil(#ids / 7))
    bulkSourcePage = math.max(1, math.min(bulkSourcePage, pages))
    local offset = (bulkSourcePage - 1) * 7
    local shown = math.min(7, #ids - offset)
    bulkSourcePopup:SetHeight(12 + shown * 32 + (pages > 1 and 34 or 0))
    for i, button in ipairs(bulkSourceButtons) do
        local id = ids[offset + i]
        button.barID = id
        button:SetShown(id ~= nil)
        if id then
            button:SetText(BulkBarLabel(id))
            button:SetSelected(id == bulkSourceID)
        end
    end
    bulkSourcePreviousButton:SetShown(pages > 1)
    bulkSourceNextButton:SetShown(pages > 1)
    bulkSourcePageLabel:SetShown(pages > 1)
    bulkSourcePreviousButton:SetEnabled(bulkSourcePage > 1)
    bulkSourceNextButton:SetEnabled(bulkSourcePage < pages)
    bulkSourcePageLabel:SetText(bulkSourcePage .. " / " .. pages)
    for _, button in ipairs({bulkSourcePreviousButton, bulkSourceNextButton}) do
        button:ClearAllPoints()
    end
    bulkSourcePreviousButton:SetPoint("BOTTOMLEFT", bulkSourcePopup, "BOTTOMLEFT", 8, 5)
    bulkSourceNextButton:SetPoint("BOTTOMRIGHT", bulkSourcePopup, "BOTTOMRIGHT", -8, 5)
    bulkSourcePageLabel:ClearAllPoints()
    bulkSourcePageLabel:SetPoint("BOTTOM", bulkSourcePopup, "BOTTOM", 0, 12)
end

local function RefreshBulkDialog()
    if not bulkOverlay then return end
    local ids = GetBulkBarIDs()
    local valid = false
    for _, id in ipairs(ids) do
        if id == bulkSourceID then valid = true end
    end
    if not valid then bulkSourceID = ids[1] end
    if bulkSourceID then bulkTargetSelection[bulkSourceID] = nil end
    bulkSourceLabel:SetText(bulkSourceID and BulkBarLabel(bulkSourceID) or "Choose source bar")
    if not BulkPagesSupported() then bulkSettingSelection["Action Pages"] = nil end
    local targets = BulkTargets()
    local pages = math.max(1, math.ceil(#targets / 12))
    bulkTargetPage = math.max(1, math.min(bulkTargetPage, pages))
    local offset = (bulkTargetPage - 1) * 12
    local targetCount = 0
    for _, id in ipairs(targets) do
        if bulkTargetSelection[id] then targetCount = targetCount + 1 end
    end
    for i, button in ipairs(bulkTargetButtons) do
        local id = targets[offset + i]
        button.barID = id
        button:SetShown(id ~= nil)
        if id then
            button:SetText(BulkBarLabel(id))
            button:SetSelected(bulkTargetSelection[id] == true)
        end
    end
    bulkTargetPreviousButton:SetShown(pages > 1)
    bulkTargetNextButton:SetShown(pages > 1)
    bulkTargetPageLabel:SetShown(pages > 1)
    bulkTargetPreviousButton:SetEnabled(bulkTargetPage > 1)
    bulkTargetNextButton:SetEnabled(bulkTargetPage < pages)
    bulkTargetPageLabel:SetText(bulkTargetPage .. " / " .. pages)
    local settingCount = 0
    for _, kind in ipairs(BULK_SETTINGS) do
        local available = kind ~= "Action Pages" or BulkPagesSupported()
        local selected = available and bulkSettingSelection[kind] == true
        bulkButtons[kind]:SetSelected(selected)
        bulkButtons[kind]:SetEnabled(available)
        if selected then settingCount = settingCount + 1 end
    end
    bulkSelectionLabel:SetText(targetCount .. " target bars / " .. settingCount .. " setting groups selected")
    bulkApplyButton:SetEnabled(bulkSourceID ~= nil and targetCount > 0 and settingCount > 0)
    RefreshBulkSourceList()
end

local function ApplyBulkSettings()
    if InCombatLockdown() then
        Message("Settings cannot be copied during combat.")
        return
    end
    local sourceID = bulkSourceID
    local sourceSettings = sourceID and ns.db.bars[sourceID]
    if not sourceSettings then return end
    local targets = {}
    for _, id in ipairs(BulkTargets()) do
        if bulkTargetSelection[id] then targets[#targets + 1] = id end
    end
    local layout = bulkSettingSelection.Layout == true
    local appearance = bulkSettingSelection.Appearance == true
    local visibility = bulkSettingSelection.Visibility == true
    local pages = BulkPagesSupported() and bulkSettingSelection["Action Pages"] == true
    if #targets == 0 or not (layout or appearance or visibility or pages) then
        Message("Select target bars and settings first.")
        return
    end
    if appearance then ns.GetBarAppearance(sourceID) end
    if visibility then
        ns.GetBarVisibilitySettings(sourceID)
        ns.GetBarFadeSettings(sourceID)
    end
    if pages then ns.GetBarActionPageSettings(sourceID) end
    local source = DeepCopy(sourceSettings)
    local changed = 0
    local skipped = 0
    for _, id in ipairs(targets) do
        local destination = ns.db.bars[id]
        if destination and id ~= sourceID then
            local touched = false
            local pageCompatible = pages
                and ns.BarSupportsActionPages(id)
                and destination.source == source.source
            if layout then
                for _, field in ipairs({"buttonCount", "buttonSize", "spacing", "columns", "scale"}) do
                    if source[field] ~= nil then
                        destination[field] = DeepCopy(source[field])
                    end
                end
                touched = true
            end
            if appearance then
                destination.appearance = DeepCopy(source.appearance or {})
                touched = true
            end
            if visibility then
                destination.visibility = DeepCopy(source.visibility or {})
                touched = true
            end
            if pages then
                if pageCompatible then
                    local destinationPages = destination.actionPages or {}
                    local copiedPages = DeepCopy(source.actionPages or {})
                    copiedPages.setsBySpec = destinationPages.setsBySpec
                    destination.actionPages = copiedPages
                    touched = true
                else
                    skipped = skipped + 1
                end
            end
            if touched then
                if layout or visibility or (pages and pageCompatible) then
                    ns.UpdateBar(id)
                end
                ns.ApplyBarAppearance(id)
                ns.RefreshBarFade(id, true)
                ns.RefreshBarMover(id)
                changed = changed + 1
            end
        end
    end
    if layout and changed > 0 and ns.ApplyAllKeybinds then
        ns.ApplyAllKeybinds()
    end
    HideBulkDialog()
    RefreshControls()
    local extra = skipped > 0 and (" Action Pages skipped on " .. skipped .. " incompatible bars.") or ""
    Message("Copied settings from " .. BulkBarLabel(sourceID) .. " to " .. changed .. " bars." .. extra)
end

local function ShowBulkDialog()
    if InCombatLockdown() then
        Message("Settings cannot be copied during combat.")
        return
    end
    if GetTarget() or not GetSelectedSettings() then return end
    if not bulkOverlay then
        bulkOverlay = CreateFrame("Frame", nil, panel)
        bulkOverlay:SetAllPoints(panel)
        bulkOverlay:SetFrameLevel(panel:GetFrameLevel() + 80)
        bulkOverlay:EnableMouse(true)
        local dim = bulkOverlay:CreateTexture(nil, "BACKGROUND")
        dim:SetAllPoints()
        dim:SetColorTexture(0, 0, 0, 0.68)
        local box = CreateFrame("Frame", nil, bulkOverlay, "BackdropTemplate")
        box:SetSize(690, 620)
        box:SetPoint("CENTER")
        widgets.SetBackdrop(box, colors.background)
        box:EnableMouse(true)
        box:SetScript("OnMouseDown", function()
            if bulkSourcePopup then
                bulkSourcePopup:Hide()
            end
        end)
        local function Label(text, size, x, y, muted)
            local label = box:CreateFontString(nil, "OVERLAY")
            SetFont(label, size, muted)
            label:SetPoint("TOPLEFT", box, "TOPLEFT", x, y)
            label:SetText(text)
            return label
        end
        Label("Apply to...", 16, 22, -20)
        Label("Source Bar", 12, 22, -61)
        bulkSourceLabel = widgets.CreateButton(box, "Choose source bar", 644, 34, 22, -86, function()
            if bulkSourcePopup:IsShown() then
                bulkSourcePopup:Hide()
            else
                RefreshBulkSourceList()
                bulkSourcePopup:Show()
            end
        end)
        local sourceArrowLeft = bulkSourceLabel:CreateLine(nil, "OVERLAY")
        sourceArrowLeft:SetThickness(2)
        sourceArrowLeft:SetColorTexture(unpack(colors.accent))
        sourceArrowLeft:SetStartPoint("RIGHT", bulkSourceLabel, -25, 3)
        sourceArrowLeft:SetEndPoint("RIGHT", bulkSourceLabel, -19, -3)

        local sourceArrowRight = bulkSourceLabel:CreateLine(nil, "OVERLAY")
        sourceArrowRight:SetThickness(2)
        sourceArrowRight:SetColorTexture(unpack(colors.accent))
        sourceArrowRight:SetStartPoint("RIGHT", bulkSourceLabel, -19, -3)
        sourceArrowRight:SetEndPoint("RIGHT", bulkSourceLabel, -13, 3)
        Label("Target Bars", 12, 22, -140)
        widgets.CreateButton(box, "Select All Bars", 136, 28, 382, -133, function()
            bulkSourcePopup:Hide()
            for _, id in ipairs(BulkTargets()) do bulkTargetSelection[id] = true end
            RefreshBulkDialog()
        end)
        widgets.CreateButton(box, "Clear", 136, 28, 530, -133, function()
            bulkSourcePopup:Hide()
            bulkTargetSelection = {}
            RefreshBulkDialog()
        end)
        local targetContainer = CreateFrame("Frame", nil, box)
        targetContainer:SetSize(644, 108)
        targetContainer:SetPoint("TOPLEFT", box, "TOPLEFT", 22, -179)
        targetContainer:EnableMouseWheel(true)
        targetContainer:SetScript("OnMouseWheel", function(_, delta)
            local pages = math.max(1, math.ceil(#BulkTargets() / 12))
            bulkTargetPage = math.max(1, math.min(pages, bulkTargetPage - delta))
            RefreshBulkDialog()
        end)
        for index = 1, 12 do
            local column = (index - 1) % 4
            local row = math.floor((index - 1) / 4)
            local button = widgets.CreateTabButton(targetContainer, "", 155, 32, column * 163, -row * 37, function(self)
                if not self.barID then return end
                bulkSourcePopup:Hide()
                bulkTargetSelection[self.barID] = not bulkTargetSelection[self.barID] or nil
                RefreshBulkDialog()
            end)
            button.label:ClearAllPoints()
            button.label:SetPoint("LEFT", button, "LEFT", 7, 0)
            button.label:SetPoint("RIGHT", button, "RIGHT", -7, 0)
            button.label:SetWordWrap(false)
            bulkTargetButtons[index] = button
        end
        bulkTargetPreviousButton = widgets.CreateButton(box, "Previous", 106, 25, 22, -297, function()
            bulkTargetPage = math.max(1, bulkTargetPage - 1)
            RefreshBulkDialog()
        end)
        bulkTargetNextButton = widgets.CreateButton(box, "Next", 106, 25, 560, -297, function()
            bulkTargetPage = bulkTargetPage + 1
            RefreshBulkDialog()
        end)
        bulkTargetPageLabel = Label("", 10, 322, -304, true)
        bulkTargetPageLabel:ClearAllPoints()
        bulkTargetPageLabel:SetPoint("TOP", box, "TOP", 0, -304)
        Label("Settings to Copy", 12, 22, -348)
        widgets.CreateButton(box, "All Settings", 136, 28, 382, -341, function()
            bulkSourcePopup:Hide()
            for _, kind in ipairs(BULK_SETTINGS) do
                if kind ~= "Action Pages" or BulkPagesSupported() then
                    bulkSettingSelection[kind] = true
                end
            end
            RefreshBulkDialog()
        end)
        widgets.CreateButton(box, "Clear", 136, 28, 530, -341, function()
            bulkSourcePopup:Hide()
            bulkSettingSelection = {}
            RefreshBulkDialog()
        end)
        for index, kind in ipairs(BULK_SETTINGS) do
            local column = (index - 1) % 2
            local row = math.floor((index - 1) / 2)
            bulkButtons[kind] = widgets.CreateTabButton(box, kind, 316, 34, 22 + column * 328, -385 - row * 41, function()
                bulkSourcePopup:Hide()
                bulkSettingSelection[kind] = not bulkSettingSelection[kind] or nil
                RefreshBulkDialog()
            end)
        end
        bulkSelectionLabel = Label("", 11, 22, -481, true)
        local detail = Label("Bar names, positions, enabled states, actions, and keybinds are preserved.", 10, 22, -507, true)
        detail:SetWidth(644)
        detail:SetWordWrap(true)
        Label("Action Pages copy rules only to the same type of bar; assigned spells stay unchanged.", 10, 22, -524, true)
        widgets.CreateButton(box, "Cancel", 136, 34, 382, -565, HideBulkDialog)
        bulkApplyButton = widgets.CreateButton(box, "Apply Now", 136, 34, 530, -565, ApplyBulkSettings)
        bulkSourcePopup = CreateFrame("Frame", nil, box, "BackdropTemplate")
        bulkSourcePopup:SetWidth(644)
        bulkSourcePopup:SetPoint("TOPLEFT", bulkSourceLabel, "BOTTOMLEFT", 0, -3)
        bulkSourcePopup:SetFrameLevel(box:GetFrameLevel() + 20)
        widgets.SetBackdrop(bulkSourcePopup, colors.background)
        bulkSourcePopup:EnableMouse(true)
        bulkSourcePopup:EnableMouseWheel(true)
        bulkSourcePopup:Hide()
        bulkSourcePopup:SetScript("OnMouseWheel", function(_, delta)
            local pages = math.max(1, math.ceil(#GetBulkBarIDs() / 7))
            bulkSourcePage = math.max(1, math.min(pages, bulkSourcePage - delta))
            RefreshBulkSourceList()
        end)
        for index = 1, 7 do
            local button = widgets.CreateTabButton(bulkSourcePopup, "", 626, 29, 9, -6 - (index - 1) * 32, function(self)
                if not self.barID then return end
                bulkSourceID = self.barID
                bulkTargetSelection[bulkSourceID] = nil
                bulkSourcePopup:Hide()
                bulkTargetPage = 1
                RefreshBulkDialog()
            end)
            button.label:ClearAllPoints()
            button.label:SetPoint("LEFT", button, "LEFT", 10, 0)
            button.label:SetPoint("RIGHT", button, "RIGHT", -10, 0)
            button.label:SetWordWrap(false)
            bulkSourceButtons[index] = button
        end
        bulkSourcePreviousButton = widgets.CreateButton(bulkSourcePopup, "Previous", 106, 25, 8, -1, function()
            bulkSourcePage = math.max(1, bulkSourcePage - 1)
            RefreshBulkSourceList()
        end)
        bulkSourceNextButton = widgets.CreateButton(bulkSourcePopup, "Next", 106, 25, 530, -1, function()
            bulkSourcePage = bulkSourcePage + 1
            RefreshBulkSourceList()
        end)
        bulkSourcePageLabel = bulkSourcePopup:CreateFontString(nil, "OVERLAY")
        SetFont(bulkSourcePageLabel, 10, true)
        bulkOverlay:EnableKeyboard(true)
        bulkOverlay:SetPropagateKeyboardInput(false)
        bulkOverlay:SetScript("OnKeyDown", function(_, key)
            if key == "ESCAPE" then
                if bulkSourcePopup:IsShown() then bulkSourcePopup:Hide() else HideBulkDialog() end
            end
        end)
    end
    bulkSourceID = selectedBarID
    bulkSourcePage = 1
    bulkTargetPage = 1
    bulkTargetSelection = {}
    bulkSettingSelection = { Appearance = true }
    for index, id in ipairs(GetBulkBarIDs()) do
        if id == bulkSourceID then
            bulkSourcePage = math.floor((index - 1) / 7) + 1
            break
        end
    end
    bulkSourcePopup:Hide()
    RefreshBulkDialog()
    bulkOverlay:Show()
end

local function GetWindowPreferences()
    local root = ns.rootDB or MythIncActionBarsDB
    if not root then return nil end

    if type(root.window) ~= "table" then
        root.window = {}
    end

    return root.window
end

local function LoadWindowHeight()
    local preferences = GetWindowPreferences()
    local height = preferences and tonumber(preferences.height)
    spellbookLayout =
        preferences and preferences.spellbookLayout == true or false

    if height and height == height then
        preferredWindowHeight = math.max(
            MIN_WINDOW_HEIGHT,
            math.floor(height + 0.5)
        )
    else
        preferredWindowHeight = WINDOW_HEIGHT
    end
end

local function SaveWindowHeight()
    local preferences = GetWindowPreferences()
    if preferences then
        preferences.height = preferredWindowHeight
    end
end

local function GetScreenFitScale()
    local availableWidth =
        UIParent:GetWidth() - SCREEN_MARGIN

    if spellbookLayout then
        availableWidth =
            UIParent:GetWidth() * 0.49 - SCREEN_MARGIN
    end

    return math.max(0.1, math.min(
        1,
        availableWidth / WINDOW_WIDTH,
        (UIParent:GetHeight() - SCREEN_MARGIN) / WINDOW_HEIGHT
    ))
end

local function PositionConfigWindow()
    if not panel then return end

    panel:ClearAllPoints()

    if spellbookLayout then
        panel:SetPoint(
            "RIGHT", UIParent, "RIGHT",
            -SCREEN_MARGIN / 2, 0
        )
    else
        panel:SetPoint(
            "CENTER", UIParent, "CENTER", 0, 0
        )
    end
end

local FitConfigToScreen

local function SetSpellbookLayout(enabled)
    if not panel then return end

    spellbookLayout = enabled == true

    local preferences = GetWindowPreferences()
    if preferences then
        preferences.spellbookLayout = spellbookLayout
    end

    if spellbookLayoutButton then
        spellbookLayoutButton:SetText(
            spellbookLayout
                and "Normal Layout"
                or "Spellbook Layout"
        )
    end

    PositionConfigWindow()
    FitConfigToScreen()
end

local function GetMaximumWindowHeight(baseScale)
    return math.max(
        WINDOW_HEIGHT,
        math.floor(
            (UIParent:GetHeight() - SCREEN_MARGIN) / baseScale
        )
    )
end

FitConfigToScreen = function()
    if not panel then return end

    local baseScale = GetScreenFitScale()
    local shownHeight = math.min(
        preferredWindowHeight,
        GetMaximumWindowHeight(baseScale)
    )

    if isMinimized then
        panel:SetHeight(MINIMIZED_HEIGHT)
        panel:SetScale(
            baseScale * math.min(
                1,
                shownHeight / WINDOW_HEIGHT
            )
        )
    elseif shownHeight < WINDOW_HEIGHT then
        panel:SetHeight(WINDOW_HEIGHT)
        panel:SetScale(
            baseScale * shownHeight / WINDOW_HEIGHT
        )
    else
        panel:SetHeight(shownHeight)
        panel:SetScale(baseScale)
    end

    if resizeGrip then
        resizeGrip:SetShown(not isMinimized)
    end
end

local function StartVerticalResize()
    if not panel or isMinimized or resizeInProgress then
        return
    end

    resizeInProgress = true
    resizeStartHeight = preferredWindowHeight
    resizeBaseScale = GetScreenFitScale()

    local _, cursorY = GetCursorPosition()
    resizeStartCursorY = cursorY

    local centerX = panel:GetCenter()
    local top = panel:GetTop()
    local effectiveScale = panel:GetEffectiveScale()

    if centerX and top then
        resizeFixedCenterX = centerX * effectiveScale
        resizeFixedTop = top * effectiveScale
    else
        resizeFixedCenterX = nil
        resizeFixedTop = nil
    end
end

local function UpdateVerticalResize()
    if not resizeInProgress or not panel then return end

    local _, cursorY = GetCursorPosition()
    local parentScale = UIParent:GetEffectiveScale()
    local pixelsPerUnit = parentScale * resizeBaseScale

    if pixelsPerUnit <= 0 then return end

    local delta =
        (resizeStartCursorY - cursorY) / pixelsPerUnit

    preferredWindowHeight = math.floor(math.max(
        MIN_WINDOW_HEIGHT,
        math.min(
            GetMaximumWindowHeight(resizeBaseScale),
            resizeStartHeight + delta
        )
    ) + 0.5)

    FitConfigToScreen()

    if resizeFixedCenterX and resizeFixedTop then
        local effectiveScale = panel:GetEffectiveScale()
        panel:ClearAllPoints()
        panel:SetPoint(
            "TOP", UIParent, "BOTTOMLEFT",
            resizeFixedCenterX / effectiveScale,
            resizeFixedTop / effectiveScale
        )
    end
end

local function StopVerticalResize()
    if not resizeInProgress then return end

    UpdateVerticalResize()
    resizeInProgress = false
    resizeFixedCenterX = nil
    resizeFixedTop = nil
    SaveWindowHeight()
end

local function CreateResizeGrip()
    resizeGrip = CreateFrame("Button", nil, panel)
    resizeGrip:SetSize(104, 14)
    resizeGrip:SetPoint(
        "BOTTOM", panel, "BOTTOM", 0, 2
    )
    resizeGrip:SetFrameLevel(
        panel:GetFrameLevel() + 15
    )
    resizeGrip:RegisterForDrag("LeftButton")
    resizeGrip:RegisterForClicks("LeftButtonUp")

    local line =
        resizeGrip:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(unpack(colors.accent))
    line:SetSize(48, 2)
    line:SetPoint(
        "CENTER", resizeGrip, "CENTER", 0, 2
    )

    local secondLine =
        resizeGrip:CreateTexture(nil, "ARTWORK")
    secondLine:SetColorTexture(unpack(colors.accent))
    secondLine:SetSize(30, 2)
    secondLine:SetPoint(
        "CENTER", resizeGrip, "CENTER", 0, -2
    )

    resizeHint = CreateFrame(
        "Frame", nil, panel, "BackdropTemplate"
    )
    resizeHint:SetSize(294, 94)
    resizeHint:SetPoint(
        "BOTTOM", resizeGrip, "TOP", 0, 8
    )
    resizeHint:SetFrameStrata("TOOLTIP")
    resizeHint:SetFrameLevel(resizeGrip:GetFrameLevel() + 20)
    resizeHint:EnableMouse(false)
    widgets.SetBackdrop(resizeHint, colors.background)

    local hintTitle = resizeHint:CreateFontString(
        nil, "OVERLAY"
    )
    hintTitle:SetFont(font, 12, "OUTLINE")
    hintTitle:SetTextColor(unpack(colors.text))
    hintTitle:SetPoint(
        "TOPLEFT", resizeHint, "TOPLEFT", 12, -11
    )
    hintTitle:SetText("Resize Configuration")

    local hintBody = resizeHint:CreateFontString(
        nil, "OVERLAY"
    )
    hintBody:SetFont(font, 10, "OUTLINE")
    hintBody:SetTextColor(unpack(colors.muted))
    hintBody:SetPoint(
        "TOPLEFT", hintTitle, "BOTTOMLEFT", 0, -7
    )
    hintBody:SetPoint(
        "RIGHT", resizeHint, "RIGHT", -12, 0
    )
    hintBody:SetJustifyH("LEFT")
    hintBody:SetWordWrap(true)
    hintBody:SetText(
        "Drag to resize the menu. Double-click to restore the default 1080 x 720 size."
    )
    resizeHint:Hide()

    resizeGrip:SetScript("OnDragStart", function()
        lastResizeClickTime = 0
        resizeHint:Hide()
        StartVerticalResize()
    end)
    resizeGrip:SetScript("OnDragStop", StopVerticalResize)
    resizeGrip:SetScript("OnUpdate", UpdateVerticalResize)

    resizeGrip:SetScript("OnEnter", function()
        line:SetAlpha(1)
        secondLine:SetAlpha(1)
        if not resizeInProgress and not isMinimized then
            resizeHint:Show()
        end
    end)

    resizeGrip:SetScript("OnLeave", function()
        line:SetAlpha(0.65)
        secondLine:SetAlpha(0.65)
        resizeHint:Hide()
    end)

    resizeGrip:HookScript("OnHide", function()
        resizeHint:Hide()
    end)

    resizeGrip:SetScript("OnClick", function(_, mouseButton)
        if mouseButton ~= "LeftButton" or isMinimized or resizeInProgress then
            return
        end

        local now = GetTime()
        if lastResizeClickTime > 0 and now - lastResizeClickTime <= 0.35 then
            lastResizeClickTime = 0
            preferredWindowHeight = WINDOW_HEIGHT
            SaveWindowHeight()
            PositionConfigWindow()
            FitConfigToScreen()
            resizeHint:Hide()
        else
            lastResizeClickTime = now
        end
    end)

    line:SetAlpha(0.65)
    secondLine:SetAlpha(0.65)
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

    HideBulkDialog()
    selectedTopLevel = mode

    if generalTab then
        generalTab:SetSelected(mode == "General")
    end

    if actionBarsTab then
        actionBarsTab:SetSelected(
            mode == "Action Bars"
        )
    end

    if profilesTab then
        profilesTab:SetSelected(mode == "Profiles")
    end

    local showGeneral =
        not isMinimized and mode == "General"

    local showActionBars =
        not isMinimized and mode == "Action Bars"

    local showProfiles =
        not isMinimized and mode == "Profiles"

    local showProfileActions =
        not isMinimized and mode ~= "General"

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

    if applyToAllButton then
        applyToAllButton:SetShown(showActionBars)
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
        applyChangesButton:SetShown(
            not isMinimized
        )
    end

    if revertChangesButton then
        revertChangesButton:SetShown(
            not isMinimized
        )
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
    elseif showProfiles
        and profilesPage
        and profilesPage.Refresh
    then
        profilesPage:Refresh()
    end
end

local function SetMinimized(minimized)
    StopVerticalResize()
    isMinimized = minimized

    minimizeButton:SetText(
        minimized and "Restore" or "Minimize"
    )

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

    if action and action() == false then
        return
    end

    HideConfirmationDialog()
end

local function CreateConfirmationDialog()
    if confirmationDialog then
        return confirmationDialog
    end

    confirmationOverlay =
        CreateFrame("Frame", nil, panel)
    confirmationOverlay:SetAllPoints(panel)
    confirmationOverlay:SetFrameLevel(
        panel:GetFrameLevel() + 90
    )
    confirmationOverlay:EnableMouse(true)

    local dim =
        confirmationOverlay:CreateTexture(
            nil, "BACKGROUND"
        )
    dim:SetAllPoints()
    dim:SetColorTexture(0, 0, 0, 0.58)

    confirmationDialog = CreateFrame(
        "Frame",
        nil,
        confirmationOverlay,
        "BackdropTemplate"
    )
    confirmationDialog:SetSize(560, 210)
    confirmationDialog:SetPoint(
        "CENTER", panel, "CENTER", 0, 20
    )
    confirmationDialog:SetFrameLevel(
        confirmationOverlay:GetFrameLevel() + 10
    )
    widgets.SetBackdrop(
        confirmationDialog, colors.background
    )

    confirmationTitle =
        confirmationDialog:CreateFontString(
            nil, "OVERLAY"
        )
    SetFont(confirmationTitle, 16, false)
    confirmationTitle:SetPoint(
        "TOPLEFT",
        confirmationDialog,
        "TOPLEFT",
        22,
        -20
    )

    confirmationMessage =
        confirmationDialog:CreateFontString(
            nil, "OVERLAY"
        )
    SetFont(confirmationMessage, 11, true)
    confirmationMessage:SetPoint(
        "TOPLEFT",
        confirmationTitle,
        "BOTTOMLEFT",
        0,
        -16
    )
    confirmationMessage:SetWidth(516)
    confirmationMessage:SetJustifyH("LEFT")
    confirmationMessage:SetJustifyV("TOP")

    for index = 1, 3 do
        local buttonIndex = index

        confirmationButtons[index] =
            widgets.CreateButton(
                confirmationDialog,
                "",
                150,
                34,
                0,
                -152,
                function()
                    RunConfirmationAction(
                        buttonIndex
                    )
                end
            )

        confirmationButtons[index]:Hide()
    end

    confirmationDialog:EnableKeyboard(true)
    confirmationDialog:SetPropagateKeyboardInput(false)

    confirmationDialog:SetScript(
        "OnKeyDown",
        function(_, key)
            if key == "ESCAPE" then
                if confirmationButtonCount > 0 then
                    RunConfirmationAction(
                        confirmationButtonCount
                    )
                else
                    HideConfirmationDialog()
                end
                return
            end

            if key == "ENTER"
                and confirmationButtonCount > 0
            then
                RunConfirmationAction(1)
            end
        end
    )

    confirmationOverlay:Hide()
    confirmationDialog:Hide()
    return confirmationDialog
end

local function ShowConfirmationDialog(options)
    CreateConfirmationDialog()

    confirmationTitle:SetText(
        options.title or "Confirm"
    )
    confirmationMessage:SetText(
        options.message or ""
    )
    confirmationActions = {}

    local buttons = options.buttons or {}
    confirmationButtonCount = math.min(
        3, #buttons
    )

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
        local dialogButton =
            confirmationButtons[index]

        dialogButton:ClearAllPoints()
        dialogButton:SetPoint(
            "TOPLEFT",
            confirmationDialog,
            "TOPLEFT",
            positions[index],
            -152
        )
        dialogButton:SetText(
            definition.text or "Okay"
        )

        confirmationActions[index] =
            definition.action
        dialogButton:Show()
    end

    confirmationOverlay:Show()
    confirmationDialog:Show()
    confirmationDialog:SetFrameLevel(
        confirmationOverlay:GetFrameLevel() + 10
    )
end

ns.ShowConfigConfirmation =
    ShowConfirmationDialog

local function ShowDeleteBarConfirmation(
    barID,
    barName
)
    ShowConfirmationDialog({
        title = "Delete Bar",
        message = "Delete \"" .. barName
            .. "\"?\n\nAll actions and settings stored on this custom bar will be permanently removed.",
        buttons = {
            {
                text = "Delete",
                action = function()
                    local success, reason =
                        ns.DeleteBar(barID)

                    if not success then
                        if reason == "combat" then
                            Message(
                                "Cannot delete an action bar during combat."
                            )
                        end
                        return false
                    end

                    selectedBarID =
                        GetFallbackBarID(barID) or 1
                    EnsureSelectedBarVisible()
                    RefreshBarSelector()
                    RefreshControls()

                    return true
                end,
            },
            {text = "Cancel"},
        },
    })
end

local function ShowRevertConfirmation()
    ShowConfirmationDialog({
        title = "Revert Changes",
        message = "Revert changes to the active profile?\n\nSettings will return to the last applied state.",
        buttons = {
            {
                text = "Revert Changes",
                action = function()
                    if ns.LockAllBars then
                        ns.LockAllBars()
                    end

                    local success, reason =
                        ns.RevertConfigChanges()

                    if not success then
                        if reason == "combat" then
                            Message(
                                "Changes cannot be reverted during combat."
                            )
                        end
                        return false
                    end

                    return true
                end,
            },
            {text = "Cancel"},
        },
    })
end

local function ShowResetAllConfirmation()
    ShowConfirmationDialog({
        title = "Reset All",
        message = "Reset the active profile to defaults?\n\nAll action bar settings, custom bars, assignments, and keybinds in this profile will be reset.",
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
                            Message(
                                "The active profile cannot be reset during combat."
                            )
                        end
                        return false
                    end

                    return true
                end,
            },
            {text = "Cancel"},
        },
    })
end

local function ShowUnappliedChangesDialog()
    ShowConfirmationDialog({
        title = "Unapplied Changes",
        message = "You have changes that have not been applied. What would you like to do?",
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
                    local success, reason =
                        ns.RevertConfigChanges()

                    if not success then
                        if reason == "combat" then
                            Message(
                                "Changes cannot be reverted during combat."
                            )
                        end
                        return false
                    end

                    allowConfigClose = true
                    panel:Hide()
                    return true
                end,
            },
            {text = "Cancel"},
        },
    })
end

local spellbookWasVisible = false
local spellbookPollElapsed = 0

local function IsSpellbookVisible()
    return (PlayerSpellsFrame and PlayerSpellsFrame:IsShown())
        or (SpellBookFrame and SpellBookFrame:IsShown())
        or false
end

local function OfferSpellbookLayout()
    local preferences = GetWindowPreferences()

    if not preferences or preferences.spellbookPromptSeen then
        return
    end

    if spellbookLayout or isMinimized or InCombatLockdown() then
        return
    end

    if (confirmationOverlay and confirmationOverlay:IsShown())
        or (bulkOverlay and bulkOverlay:IsShown())
        or (renameDialog and renameDialog:IsShown())
    then
        return
    end

    ShowConfirmationDialog({
        title = "Spellbook Layout Available",
        message = "MIAB can move to the right side of your screen to give the spellbook more room while you drag abilities onto your action bars.\n\nWould you like to use Spellbook Layout? You can change this any time using the button at the top of MIAB.",
        buttons = {
            {
                text = "Use Spellbook Layout",
                action = function()
                    preferences.spellbookPromptSeen = true
                    SetSpellbookLayout(true)
                    return true
                end,
            },
            {
                text = "Not Now",
                action = function()
                    preferences.spellbookPromptSeen = true
                    return true
                end,
            },
        },
    })
end

RequestCloseConfig = function()
    if not panel or not panel:IsShown() then
        return
    end

    HideBulkDialog()

    if ns.HasConfigChanges
        and ns.HasConfigChanges()
    then
        ShowUnappliedChangesDialog()
        return
    end

    allowConfigClose = true
    panel:Hide()
end

local function CreateHeader()
    logoTexture =
        panel:CreateTexture(nil, "ARTWORK")
    logoTexture:SetSize(96, 96)
    logoTexture:SetPoint(
        "TOPLEFT", panel, "TOPLEFT", 18, -10
    )
    logoTexture:SetTexture(
        "Interface\\AddOns\\MythIncActionBars\\Media\\Artwork\\MIUF_Icon_128.png"
    )

    local title =
        panel:CreateFontString(nil, "OVERLAY")
    SetFont(title, 17)
    title:SetPoint(
        "TOPLEFT", panel, "TOPLEFT", 120, -16
    )
    title:SetText("M Y T H Inc Action Bars")

    local version =
        panel:CreateFontString(nil, "OVERLAY")
    SetFont(version, 10, true)
    version:SetPoint(
        "LEFT", title, "RIGHT", 10, -1
    )
    version:SetText(ns.version)

    widgets.CreateButton(
        panel,
        "X",
        28,
        24,
        WINDOW_WIDTH - 38,
        -10,
        function()
            RequestCloseConfig()
        end
    )

    minimizeButton = widgets.CreateButton(
        panel,
        "Minimize",
        86,
        24,
        WINDOW_WIDTH - 130,
        -10,
        function()
            SetMinimized(not isMinimized)
        end
    )

    spellbookLayoutButton = widgets.CreateButton(
        panel,
        spellbookLayout
            and "Normal Layout"
            or "Spellbook Layout",
        148,
        24,
        716,
        -10,
        function()
            SetSpellbookLayout(
                not spellbookLayout
            )
        end
    )

    generalTab = widgets.CreateTabButton(
        panel,
        "General",
        110,
        28,
        180,
        -48,
        function()
            SetTopLevelMode("General")
        end
    )

    actionBarsTab = widgets.CreateTabButton(
        panel,
        "Action Bars",
        110,
        28,
        298,
        -48,
        function()
            SetTopLevelMode("Action Bars")
        end
    )

    profilesTab = widgets.CreateTabButton(
        panel,
        "Profiles",
        110,
        28,
        416,
        -48,
        function()
            SetTopLevelMode("Profiles")
        end
    )

    actionBarsTab:SetSelected(true)
end

local function CreateActionBarSettingsSection()
    actionBarSettingsSection = widgets.CreateSection(
        panel,
        "ACTION BAR SETTINGS",
        1036,
        100,
        22,
        -96
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
                Message(
                    "Blizzard bar visibility will update when combat ends."
                )
            end
        end
    )

    lockContentsCheckbox = widgets.CreateCheckButton(
        actionBarSettingsSection,
        "Lock Button Contents",
        380,
        -32,
        function()
            return not ns.db.buttonInteraction
                or ns.db.buttonInteraction.lockContents ~= false
        end,
        function(value)
            ns.db.buttonInteraction =
                ns.db.buttonInteraction or {}

            ns.db.buttonInteraction.lockContents =
                value == true

            if ns.NotifyButtonInteractionChanged then
                ns.NotifyButtonInteractionChanged()
            elseif ns.RefreshButtonInteraction then
                ns.RefreshButtonInteraction()
            end

            RefreshControls()
        end
    )

    activateOnPressCheckbox = widgets.CreateCheckButton(
        actionBarSettingsSection,
        "Activate on Press",
        18,
        -68,
        function()
            return ns.db.buttonInteraction
                and ns.db.buttonInteraction.activateOnPress == true
                or false
        end,
        function(value)
            ns.db.buttonInteraction =
                ns.db.buttonInteraction or {}

            ns.db.buttonInteraction.activateOnPress =
                value == true

            if ns.NotifyButtonInteractionChanged then
                ns.NotifyButtonInteractionChanged()
            elseif ns.RefreshButtonInteraction then
                ns.RefreshButtonInteraction()
            end

            RefreshControls()
        end
    )

    alignmentGridCheckbox = widgets.CreateCheckButton(
        actionBarSettingsSection,
        "Show Alignment Grid",
        380,
        -68,
        function()
            return ns.IsAlignmentGridEnabled()
        end,
        function(value)
            ns.SetAlignmentGridEnabled(value)
            RefreshControls()
        end
    )

    gridSpacingLabel = widgets.CreateText(
        actionBarSettingsSection,
        "Grid spacing (px)",
        11,
        620,
        -73
    )

    gridSpacingBox = CreateFrame(
        "EditBox",
        nil,
        actionBarSettingsSection,
        "InputBoxTemplate"
    )
    gridSpacingBox:SetSize(58, 20)
    gridSpacingBox:SetPoint(
        "TOPLEFT",
        actionBarSettingsSection,
        "TOPLEFT",
        758,
        -69
    )
    gridSpacingBox:SetAutoFocus(false)
    gridSpacingBox:SetMaxLetters(3)
    gridSpacingBox:SetJustifyH("CENTER")
    gridSpacingBox:SetTextColor(
        unpack(colors.text)
    )

    local function RestoreGridSpacing()
        gridSpacingBox:SetText(
            tostring(
                ns.GetAlignmentGridSpacing()
            )
        )
    end

    local function CommitGridSpacing()
        ns.SetAlignmentGridSpacing(
            gridSpacingBox:GetText()
        )
        RestoreGridSpacing()
    end

    gridSpacingBox:SetScript(
        "OnEnterPressed",
        function(self)
            CommitGridSpacing()
            self:ClearFocus()
        end
    )

    gridSpacingBox:SetScript(
        "OnEscapePressed",
        function(self)
            RestoreGridSpacing()
            self:ClearFocus()
        end
    )

    gridSpacingBox:SetScript(
        "OnEditFocusLost",
        CommitGridSpacing
    )

    gridSpacingBox:SetScript(
        "OnEditFocusGained",
        function(self)
            self:HighlightText()
        end
    )

    RestoreGridSpacing()

    gridOpacityLabel = widgets.CreateText(
        actionBarSettingsSection,
        "Opacity (%)",
        11,
        842,
        -73
    )

    gridOpacityBox = CreateFrame(
        "EditBox",
        nil,
        actionBarSettingsSection,
        "InputBoxTemplate"
    )
    gridOpacityBox:SetSize(50, 20)
    gridOpacityBox:SetPoint(
        "TOPLEFT",
        actionBarSettingsSection,
        "TOPLEFT",
        962,
        -69
    )
    gridOpacityBox:SetAutoFocus(false)
    gridOpacityBox:SetMaxLetters(3)
    gridOpacityBox:SetJustifyH("CENTER")
    gridOpacityBox:SetTextColor(
        unpack(colors.text)
    )

    local function RestoreGridOpacity()
        gridOpacityBox:SetText(
            tostring(
                math.floor(
                    ns.GetAlignmentGridOpacity()
                    * 100 + 0.5
                )
            )
        )
    end

    local function CommitGridOpacity()
        local percent =
            tonumber(gridOpacityBox:GetText())

        if percent then
            ns.SetAlignmentGridOpacity(
                percent / 100
            )
        end

        RestoreGridOpacity()
    end

    gridOpacityBox:SetScript(
        "OnEnterPressed",
        function(self)
            CommitGridOpacity()
            self:ClearFocus()
        end
    )

    gridOpacityBox:SetScript(
        "OnEscapePressed",
        function(self)
            RestoreGridOpacity()
            self:ClearFocus()
        end
    )

    gridOpacityBox:SetScript(
        "OnEditFocusLost",
        CommitGridOpacity
    )

    gridOpacityBox:SetScript(
        "OnEditFocusGained",
        function(self)
            self:HighlightText()
        end
    )

    RestoreGridOpacity()

    local visible = ns.IsAlignmentGridEnabled()
    gridSpacingBox:SetShown(visible)
    gridSpacingLabel:SetShown(visible)
    gridOpacityBox:SetShown(visible)
    gridOpacityLabel:SetShown(visible)
end

local function CreateBarSelector()
    barSelectorSection = widgets.CreateSection(
        panel,
        "ACTION BARS",
        1036,
        100,
        22,
        SELECTOR_TOP
    )

    barSelectorViewport = CreateFrame(
        "Frame",
        nil,
        barSelectorSection
    )
    barSelectorViewport:SetSize(
        780,
        SELECTOR_ROW_HEIGHT
    )
    barSelectorViewport:SetPoint(
        "TOPLEFT",
        barSelectorSection,
        "TOPLEFT",
        12,
        -36
    )
    barSelectorViewport:SetClipsChildren(true)
    barSelectorViewport:EnableMouseWheel(true)

    barSelectorViewport:SetScript(
        "OnMouseWheel",
        function(_, delta)
            local totalRows = math.ceil(
                #ns.GetBarIDs() / BAR_COLUMNS
            )

            local maxOffset = math.max(
                0,
                totalRows - BAR_VISIBLE_ROWS
            )

            if delta < 0 then
                barSelectorOffset = math.min(
                    maxOffset,
                    barSelectorOffset + 1
                )
            elseif delta > 0 then
                barSelectorOffset = math.max(
                    0,
                    barSelectorOffset - 1
                )
            end

            RefreshBarSelector()
        end
    )

    actionSelectorScrollbar = CreateSelectorScrollbar(
        barSelectorViewport,
        function()
            return math.max(0,
                math.ceil(#ns.GetBarIDs() / BAR_COLUMNS) - BAR_VISIBLE_ROWS
            )
        end,
        function() return barSelectorOffset end,
        function(offset)
            barSelectorOffset = offset
            RefreshBarSelector()
        end
    )

    addButton = widgets.CreateButton(
        barSelectorSection,
        "Add Action Bar",
        110,
        30,
        912,
        -74,
        function()
            local barID, reason = ns.AddBar()

            if not barID then
                if reason == "combat" then
                    Message(
                        "Cannot create an action bar during combat."
                    )
                end
                return
            end

            SelectBar(barID)
        end
    )

    unlockAllButton = widgets.CreateButton(
        barSelectorSection,
        "Unlock All Bars",
        110,
        30,
        796,
        -74,
        function()
            local success, reason =
                ns.ToggleAllBarsUnlocked()

            if not success
                and reason == "combat"
            then
                Message(
                    "Bars cannot be unlocked during combat."
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

    renameButton = widgets.CreateButton(
        barSelectorSection,
        "Rename Bar",
        110,
        30,
        796,
        -38,
        function()
            renameBarID = selectedBarID

            if not renameDialog then
                renameDialog = CreateFrame(
                    "Frame", nil, panel
                )
                renameDialog:SetAllPoints(panel)
                renameDialog:SetFrameLevel(
                    panel:GetFrameLevel() + 80
                )
                renameDialog:EnableMouse(true)

                local dim =
                    renameDialog:CreateTexture(
                        nil, "BACKGROUND"
                    )
                dim:SetAllPoints()
                dim:SetColorTexture(
                    0, 0, 0, 0.75
                )

                local box = widgets.CreateSection(
                    renameDialog,
                    "RENAME BAR",
                    420,
                    166,
                    0,
                    0
                )
                box:ClearAllPoints()
                box:SetPoint(
                    "CENTER",
                    renameDialog,
                    "CENTER"
                )

                nameControl = widgets.CreateEditBox(
                    box,
                    "Name",
                    370,
                    20,
                    -38,
                    function()
                        local settings =
                            ns.db.bars[renameBarID]

                        return settings
                            and settings.name or ""
                    end,
                    function() end
                )

                local function SaveName()
                    local settings =
                        ns.db.bars[renameBarID]

                    local value =
                        nameControl.editBox:GetText()
                            :match("^%s*(.-)%s*$")

                    if not settings
                        or value == ""
                    then
                        return
                    end

                    settings.name = value
                    ns.RefreshBarMover(renameBarID)
                    HideRenameDialog()
                    RefreshBarSelector()
                    RefreshControls()
                end

                nameControl.editBox:SetScript(
                    "OnEnterPressed",
                    SaveName
                )

                nameControl.editBox:SetScript(
                    "OnEscapePressed",
                    HideRenameDialog
                )

                widgets.CreateButton(
                    box,
                    "Save",
                    110,
                    30,
                    170,
                    -118,
                    SaveName
                )

                widgets.CreateButton(
                    box,
                    "Cancel",
                    110,
                    30,
                    288,
                    -118,
                    HideRenameDialog
                )
            end

            nameControl:Refresh()
            renameDialog:Show()
            nameControl.editBox:SetFocus()
            nameControl.editBox:HighlightText()
        end
    )

    unlockButton = widgets.CreateButton(
        barSelectorSection,
        "Unlock Bar",
        110,
        30,
        912,
        -38,
        function()
            local settings =
                GetSelectedSettings()

            if not settings
                or not settings.enabled
            then
                return
            end

            UnlockSelected(
                not IsSelectedUnlocked()
            )
            RefreshControls()
        end
    )
end

local function CreateCategoryTabs()
    categoryFrame = CreateFrame(
        "Frame", nil, panel
    )
    categoryFrame:SetSize(1036, 34)
    categoryFrame:SetPoint(
        "TOPLEFT", panel, "TOPLEFT",
        22, -366
    )

    for index, name in ipairs(CATEGORY_NAMES) do
        local categoryName = name

        categoryButtons[name] =
            widgets.CreateTabButton(
                categoryFrame,
                name,
                196,
                34,
                (index - 1) * 206,
                0,
                function()
                    selectedCategory = categoryName
                    RefreshCategoryButtons()
                end
            )
    end
end

local function CreatePageHost()
    pageHost = CreateFrame(
        "Frame", nil, panel
    )
    pageHost:SetPoint(
        "TOPLEFT", panel, "TOPLEFT",
        22, -414
    )
    pageHost:SetPoint(
        "BOTTOMRIGHT", panel, "BOTTOMRIGHT",
        -22, 58
    )
    pageHost:SetClipsChildren(true)

    layoutPage = ns.CreateLayoutConfigPage(
        pageHost,
        {
            GetSelectedSettings = GetSelectedSettings,
            GetSelectedBarID = GetSelectedBarID,
            RefreshConfig = RefreshControls,
        }
    )

    local context = {
        GetSelectedSettings = GetSelectedSettings,
        GetSelectedBarID = GetSelectedBarID,
    }

    appearancePage = ns.CreateAppearanceConfigPage(
        pageHost, context
    )
    visibilityPage = ns.CreateVisibilityConfigPage(
        pageHost, context
    )
    actionPagesPage = ns.CreateActionPagesConfigPage(
        pageHost, context
    )
    keybindsPage = ns.CreateKeybindsConfigPage(
        pageHost, context
    )

    for _, frame in ipairs({
        layoutPage,
        appearancePage,
        visibilityPage,
        actionPagesPage,
        keybindsPage,
    }) do
        frame:SetAllPoints(pageHost)
    end

    specialPage = ns.CreateSpecialConfigPage(
        pageHost,
        {
            RefreshConfig = RefreshControls,
        }
    )

    specialPage:Hide()
    layoutPage:Show()
    appearancePage:Hide()
    visibilityPage:Hide()
    actionPagesPage:Hide()
    keybindsPage:Hide()
end

local function CreateGeneralHost()
    generalHost = CreateFrame(
        "Frame", nil, panel
    )
    generalHost:SetPoint(
        "TOPLEFT", panel, "TOPLEFT",
        22, -96
    )
    generalHost:SetPoint(
        "BOTTOMRIGHT", panel, "BOTTOMRIGHT",
        -22, 58
    )

    generalPage =
        ns.CreateGeneralConfigPage(generalHost)
    generalPage:SetAllPoints(generalHost)
    generalHost:Hide()
end

local function CreateProfilesHost()
    profilesHost = CreateFrame(
        "Frame", nil, panel
    )
    profilesHost:SetPoint(
        "TOPLEFT", panel, "TOPLEFT",
        22, -96
    )
    profilesHost:SetPoint(
        "BOTTOMRIGHT", panel, "BOTTOMRIGHT",
        -22, 58
    )

    profilesPage =
        ns.CreateProfilesConfigPage(
            profilesHost
        )
    profilesPage:SetAllPoints(profilesHost)
    profilesHost:Hide()
end

local function CreateBottomActions()
    local y = -(WINDOW_HEIGHT - 46)

    local function AnchorToBottom(button, x)
        button:ClearAllPoints()
        button:SetPoint(
            "BOTTOMLEFT",
            panel,
            "BOTTOMLEFT",
            x,
            16
        )
    end

    applyChangesButton = widgets.CreateButton(
        panel,
        "Apply Changes",
        146,
        30,
        22,
        y,
        function()
            if ns.ApplyConfigChanges() then
                Message("Changes applied.")
            end
        end
    )

    revertChangesButton = widgets.CreateButton(
        panel,
        "Revert Changes",
        146,
        30,
        178,
        y,
        function()
            if InCombatLockdown() then
                Message(
                    "Changes cannot be reverted during combat."
                )
                return
            end

            if not ns.CanRevertConfigChanges() then
                Message(
                    "There is no saved state to revert to."
                )
                return
            end

            ShowRevertConfirmation()
        end
    )

    resetButton = widgets.CreateButton(
        panel,
        "Reset Bar",
        130,
        30,
        346,
        y,
        ResetSelectedBar
    )

    deleteButton = widgets.CreateButton(
        panel,
        "Delete Bar",
        130,
        30,
        486,
        y,
        function()
            local settings =
                GetSelectedSettings()

            if not settings
                or settings.source ~= "custom"
            then
                return
            end

            if InCombatLockdown() then
                Message(
                    "Cannot delete an action bar during combat."
                )
                return
            end

            ShowDeleteBarConfirmation(
                selectedBarID,
                settings.name
            )
        end
    )

    applyToAllButton = widgets.CreateButton(
        panel,
        "Apply to...",
        160,
        30,
        636,
        y,
        ShowBulkDialog
    )

    resetAllButton = widgets.CreateButton(
        panel,
        "Reset All",
        110,
        30,
        WINDOW_WIDTH - 132,
        y,
        function()
            if InCombatLockdown() then
                Message(
                    "The active profile cannot be reset during combat."
                )
                return
            end

            ShowResetAllConfirmation()
        end
    )

    AnchorToBottom(applyChangesButton, 22)
    AnchorToBottom(revertChangesButton, 178)
    AnchorToBottom(resetButton, 346)
    AnchorToBottom(deleteButton, 486)
    AnchorToBottom(applyToAllButton, 636)
    AnchorToBottom(
        resetAllButton,
        WINDOW_WIDTH - 132
    )
end

local function CreateConfigPanel()
    if panel then return panel end

    LoadWindowHeight()

    panel = CreateFrame(
        "Frame",
        "MythIncActionBarsConfig",
        UIParent,
        "BackdropTemplate"
    )

    panel:SetSize(
        WINDOW_WIDTH,
        WINDOW_HEIGHT
    )
    PositionConfigWindow()
    widgets.SetBackdrop(
        panel,
        colors.background
    )
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript(
        "OnDragStart", panel.StartMoving
    )
    panel:SetScript(
        "OnDragStop", panel.StopMovingOrSizing
    )

    panel:EnableKeyboard(
        not InCombatLockdown()
    )
    if not InCombatLockdown() then
        panel:SetPropagateKeyboardInput(true)
    end

    panel:SetScript("OnKeyDown", function(self, key)
        if key ~= "ESCAPE"
            or InCombatLockdown()
        then
            return
        end

        if (PlayerSpellsFrame and PlayerSpellsFrame:IsShown())
            or (SpellBookFrame and SpellBookFrame:IsShown())
        then
            return
        end

        if (confirmationOverlay and confirmationOverlay:IsShown())
            or (bulkOverlay and bulkOverlay:IsShown())
            or (renameDialog and renameDialog:IsShown())
        then
            return
        end

        self:SetPropagateKeyboardInput(false)
        RequestCloseConfig()

        C_Timer.After(0, function()
            if not InCombatLockdown() then
                self:SetPropagateKeyboardInput(true)
            end
        end)
    end)

    panel:SetScript("OnKeyUp", function(self)
        if not InCombatLockdown() then
            self:SetPropagateKeyboardInput(true)
        end
    end)

    panel:RegisterEvent("UI_SCALE_CHANGED")
    panel:RegisterEvent("DISPLAY_SIZE_CHANGED")
    panel:RegisterEvent("PLAYER_REGEN_DISABLED")
    panel:RegisterEvent("PLAYER_REGEN_ENABLED")

    panel:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            self:EnableKeyboard(false)
        elseif event == "PLAYER_REGEN_ENABLED" then
            self:EnableKeyboard(true)
            self:SetPropagateKeyboardInput(true)
        else
            FitConfigToScreen()
        end
    end)

    CreateHeader()
    CreateActionBarSettingsSection()
    CreateBarSelector()
    CreateBarManagementControls()
    CreateCategoryTabs()
    CreatePageHost()
    CreateGeneralHost()
    CreateProfilesHost()
    CreateBottomActions()
    CreateResizeGrip()

    panel:HookScript("OnUpdate", function(_, elapsed)
        spellbookPollElapsed = spellbookPollElapsed + elapsed

        if spellbookPollElapsed < 0.25 then
            return
        end

        spellbookPollElapsed = 0

        local visible = IsSpellbookVisible()

        if visible and not spellbookWasVisible then
            OfferSpellbookLayout()
        end

        spellbookWasVisible = visible
    end)

    panel:SetScript("OnShow", function()
        spellbookWasVisible = IsSpellbookVisible()
        spellbookPollElapsed = 0

        panel:EnableKeyboard(
            not InCombatLockdown()
        )

        if not InCombatLockdown() then
            panel:SetPropagateKeyboardInput(true)
        end

        if suppressNextSessionStart then
            suppressNextSessionStart = false
        elseif ns.BeginConfigSession then
            ns.BeginConfigSession()
        end

        allowConfigClose = false

        if not GetSelectedSettings() then
            selectedBarID =
                ns.GetBarIDs()[1] or 1
        end

        EnsureSelectedBarVisible()
        RefreshBarSelector()
        SetTopLevelMode(selectedTopLevel)
        FitConfigToScreen()
    end)

    panel:SetScript("OnHide", function()
        StopVerticalResize()

        if renameDialog then
            renameDialog:Hide()
        end

        HideBulkDialog()

        if ns.LockAllBars then
            ns.LockAllBars()
        end

        if allowConfigClose then
            allowConfigClose = false
            return
        end

        if ns.HasConfigChanges
            and ns.HasConfigChanges()
        then
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
SlashCmdList.MYTHINCACTIONBARS = ns.ToggleConfig

function ns.SelectConfigBar(barID)
    local config = CreateConfigPanel()

    if not config:IsShown() then
        config:Show()
    end

    isMinimized = false

    SetTopLevelMode("Action Bars")
    SelectBar(barID)
    FitConfigToScreen()
end
