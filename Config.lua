local addonName, ns = ...

local widgets = ns.ConfigWidgets
local media = ns.Media
local colors = media.colors
local font = media.font

local panel
local SelectBar
local SetTopLevelMode

local selectedBarID = 1
local selectedCategory = "Layout"
local selectedTopLevel = "Action Bars"

local barButtons = {}
local categoryButtons = {}

local actionBarsTab
local profilesTab

local barSelectorSection
local barSelectorViewport
local barSelectorOffset = 0

local categoryFrame

local barHeader
local barHeaderTitle
local enableCheckbox
local unlockButton
local unlockAllButton
local hideBlizzardCheckbox

local pageHost
local layoutPage
local appearancePage
local visibilityPage
local actionPagesPage
local keybindsPage

local profilesHost
local profilesPage

local nameControl

local resetButton
local deleteButton
local addButton

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

local BAR_VISIBLE_COUNT =
    BAR_COLUMNS
    * BAR_VISIBLE_ROWS

local SELECTOR_TOP = -116
local SELECTOR_TITLE_HEIGHT = 38
local SELECTOR_BOTTOM_PADDING = 12

local SELECTOR_ROW_HEIGHT =
    BAR_BUTTON_HEIGHT
    + BAR_BUTTON_SPACING

local CATEGORY_NAMES = {
    "Layout",
    "Appearance",
    "Visibility",
    "Action Pages",
    "Keybinds",
}

local function SetFont(
    fontString,
    size,
    muted
)
    fontString:SetFont(
        font,
        size,
        "OUTLINE"
    )

    fontString:SetTextColor(
        unpack(
            muted
                and colors.muted
                or colors.text
        )
    )
end

local function GetSelectedSettings()
    return ns.db.bars[
        selectedBarID
    ]
end

local function GetSelectedBarID()
    return selectedBarID
end

local function GetFallbackBarID(
    deletedBarID
)
    local ids =
        ns.GetBarIDs()

    if #ids == 0 then
        return nil
    end

    local previous
    local nextID

    for _, barID in ipairs(
        ids
    ) do
        if barID < deletedBarID then
            previous = barID

        elseif barID > deletedBarID then
            nextID = barID
            break
        end
    end

    return previous
        or nextID
        or ids[1]
end

local function FindSelectedIndex()
    local ids =
        ns.GetBarIDs()

    for index, barID in ipairs(
        ids
    ) do
        if barID
            == selectedBarID
        then
            return index
        end
    end

    return 1
end

local function ClampBarSelectorOffset()
    local ids =
        ns.GetBarIDs()

    local maxOffset =
        math.max(
            0,
            math.ceil(
                #ids
                / BAR_COLUMNS
            )
            - BAR_VISIBLE_ROWS
        )

    barSelectorOffset =
        math.max(
            0,
            math.min(
                barSelectorOffset,
                maxOffset
            )
        )
end

local function EnsureSelectedBarVisible()
    local index =
        FindSelectedIndex()

    local row =
        math.floor(
            (index - 1)
            / BAR_COLUMNS
        )

    if row
        < barSelectorOffset
    then
        barSelectorOffset =
            row

    elseif row
        >= barSelectorOffset
            + BAR_VISIBLE_ROWS
    then
        barSelectorOffset =
            row
            - BAR_VISIBLE_ROWS
            + 1
    end

    ClampBarSelectorOffset()
end

local function RefreshBarButtons()
    for barID, button in pairs(
        barButtons
    ) do
        button:SetSelected(
            barID
                == selectedBarID
        )
    end
end

local function RefreshCategoryPage()
    if layoutPage then
        local showing =
            selectedCategory
            == "Layout"

        layoutPage:SetShown(
            showing
        )

        if showing
            and layoutPage.Refresh
        then
            layoutPage:Refresh()
        end
    end

    if appearancePage then
        local showing =
            selectedCategory
            == "Appearance"

        appearancePage:SetShown(
            showing
        )

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
        local showing =
            selectedCategory
            == "Visibility"

        visibilityPage:SetShown(
            showing
        )

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
        local showing =
            selectedCategory
            == "Action Pages"

        actionPagesPage:SetShown(
            showing
        )

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
        local showing =
            selectedCategory
            == "Keybinds"

        keybindsPage:SetShown(
            showing
        )

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
    for name, button in pairs(
        categoryButtons
    ) do
        button:SetSelected(
            name
                == selectedCategory
        )
    end

    RefreshCategoryPage()
end

local function ClearBarButtons()
    for _, button in pairs(
        barButtons
    ) do
        button:Hide()
        button:SetParent(nil)
    end

    barButtons = {}
end

local function UpdateDynamicLayout()
    if not panel
        or not barSelectorSection
        or not barHeader
        or not categoryFrame
        or not pageHost
    then
        return
    end

    local ids =
        ns.GetBarIDs()

    local totalRows =
        math.max(
            1,
            math.ceil(
                #ids
                / BAR_COLUMNS
            )
        )

    local visibleRows =
        math.min(
            BAR_VISIBLE_ROWS,
            totalRows
        )

    local selectorHeight =
        SELECTOR_TITLE_HEIGHT
        + (
            visibleRows
            * SELECTOR_ROW_HEIGHT
        )
        + SELECTOR_BOTTOM_PADDING

    barSelectorSection:SetHeight(
        selectorHeight
    )

    barSelectorViewport:SetHeight(
        visibleRows
        * SELECTOR_ROW_HEIGHT
    )

    local headerY =
        SELECTOR_TOP
        - selectorHeight
        - 12

    barHeader:ClearAllPoints()

    barHeader:SetPoint(
        "TOPLEFT",
        panel,
        "TOPLEFT",
        22,
        headerY
    )

    local categoryY =
        headerY - 84

    categoryFrame:ClearAllPoints()

    categoryFrame:SetPoint(
        "TOPLEFT",
        panel,
        "TOPLEFT",
        22,
        categoryY
    )

    local pageY =
        categoryY - 48

    pageHost:ClearAllPoints()

    pageHost:SetPoint(
        "TOPLEFT",
        panel,
        "TOPLEFT",
        22,
        pageY
    )

    pageHost:SetPoint(
        "BOTTOMRIGHT",
        panel,
        "BOTTOMRIGHT",
        -22,
        58
    )
end

local function RefreshBarSelector()
    if not barSelectorViewport then
        return
    end

    ClearBarButtons()
    ClampBarSelectorOffset()

    local ids =
        ns.GetBarIDs()

    local firstIndex =
        (
            barSelectorOffset
            * BAR_COLUMNS
        )
        + 1

    local lastIndex =
        math.min(
            #ids,
            firstIndex
                + BAR_VISIBLE_COUNT
                - 1
        )

    local visibleIndex = 0

    for index =
        firstIndex,
        lastIndex
    do
        local barID =
            ids[index]

        local settings =
            ns.db.bars[
                barID
            ]

        local column =
            visibleIndex
            % BAR_COLUMNS

        local row =
            math.floor(
                visibleIndex
                / BAR_COLUMNS
            )

        local button =
            widgets.CreateTabButton(
                barSelectorViewport,
                settings.name,
                BAR_BUTTON_WIDTH,
                BAR_BUTTON_HEIGHT,
                column
                    * (
                        BAR_BUTTON_WIDTH
                        + BAR_BUTTON_SPACING
                    ),
                -row
                    * SELECTOR_ROW_HEIGHT,
                function()
                    SelectBar(
                        barID
                    )
                end
            )

        button:SetSelected(
            barID
                == selectedBarID
        )

        barButtons[
            barID
        ] =
            button

        visibleIndex =
            visibleIndex + 1
    end

    UpdateDynamicLayout()
end

local function RefreshControls()
    local settings =
        GetSelectedSettings()

    if not settings then
        return
    end

    if nameControl
        and nameControl.Refresh
    then
        nameControl:Refresh()
    end

    if hideBlizzardCheckbox
        and hideBlizzardCheckbox.Refresh
    then
        hideBlizzardCheckbox:Refresh()
    end

    if barHeaderTitle then
        barHeaderTitle:SetText(
            string.upper(
                settings.name
            )
        )
    end

    if enableCheckbox
        and enableCheckbox.Refresh
    then
        enableCheckbox:Refresh()
    end

    if unlockButton then
        if settings.enabled then
            unlockButton:Enable()

            if ns.IsBarUnlocked(
                selectedBarID
            ) then
                unlockButton:SetText(
                    "Lock Bar"
                )
            else
                unlockButton:SetText(
                    "Unlock Bar"
                )
            end
        else
            unlockButton:Disable()

            unlockButton:SetText(
                "Unlock Bar"
            )
        end
    end

    if unlockAllButton then
    if ns.IsMoveModeActive()
        or ns.AreAllEnabledBarsUnlocked()
    then
        unlockAllButton:SetText(
            "Lock All Bars"
        )
    else
        unlockAllButton:SetText(
            "Unlock All Bars"
        )
    end
end

    if deleteButton then
        deleteButton:SetShown(
            settings.source
                == "custom"
        )
    end

    if layoutPage
        and layoutPage.Refresh
    then
        layoutPage:Refresh()
    end

    if appearancePage
        and appearancePage.Refresh
    then
        appearancePage:Refresh()
    end

    if visibilityPage
        and visibilityPage.Refresh
    then
        visibilityPage:Refresh()
    end

    if actionPagesPage
        and actionPagesPage.Refresh
    then
        actionPagesPage:Refresh()
    end

    if keybindsPage
        and keybindsPage.Refresh
    then
        keybindsPage:Refresh()
    end

    RefreshBarButtons()
    RefreshCategoryButtons()
end

function ns.RefreshConfig()
    if selectedTopLevel
        == "Profiles"
    then
        if profilesPage
            and profilesPage.Refresh
        then
            profilesPage:Refresh()
        end

        return
    end

    RefreshControls()
end

SelectBar =
    function(
        barID
    )
        if not ns.db.bars[
            barID
        ] then
            return
        end

        local oldBarID =
            selectedBarID

        if not ns.IsMoveModeActive()
    and ns.IsBarUnlocked(
        oldBarID
    )
then
    ns.SetBarUnlocked(
        oldBarID,
        false
    )
end

        selectedBarID =
            barID

        EnsureSelectedBarVisible()
        RefreshBarSelector()
        RefreshControls()
    end

local function ResetSelectedBar()
    if InCombatLockdown() then
        return
    end

    local settings =
        GetSelectedSettings()

    if not settings then
        return
    end

    local defaultSettings =
        ns.CreateDefaultBarSettings(
            selectedBarID,
            settings.enabled,
            settings.source
        )

    local currentName =
        settings.name

    local currentAssignments =
        settings.assignments

    local currentKeybinds =
        settings.keybinds

    settings.buttonCount =
        defaultSettings.buttonCount

    settings.buttonSize =
        defaultSettings.buttonSize

    settings.spacing =
        defaultSettings.spacing

    settings.columns =
        defaultSettings.columns

    settings.scale =
        defaultSettings.scale

    settings.appearance = {
        iconZoom =
            defaultSettings
                .appearance
                .iconZoom,

        showBorder =
            defaultSettings
                .appearance
                .showBorder,

        emptyOpacity =
            defaultSettings
                .appearance
                .emptyOpacity,

        showCooldown =
            defaultSettings
                .appearance
                .showCooldown,

        showCooldownText =
            defaultSettings
                .appearance
                .showCooldownText,

        showCount =
            defaultSettings
                .appearance
                .showCount,

        countTextSize =
            defaultSettings
                .appearance
                .countTextSize,

        showKeybind =
            defaultSettings
                .appearance
                .showKeybind,

        keybindTextSize =
            defaultSettings
                .appearance
                .keybindTextSize,

        keybindPosition =
            defaultSettings
                .appearance
                .keybindPosition,

        keybindColor = {
            r =
                defaultSettings
                    .appearance
                    .keybindColor
                    .r,

            g =
                defaultSettings
                    .appearance
                    .keybindColor
                    .g,

            b =
                defaultSettings
                    .appearance
                    .keybindColor
                    .b,

            a =
                defaultSettings
                    .appearance
                    .keybindColor
                    .a,
        },

        desaturateUnusable =
            defaultSettings
                .appearance
                .desaturateUnusable,

        rangeColoring =
            defaultSettings
                .appearance
                .rangeColoring,

        usabilityColoring =
            defaultSettings
                .appearance
                .usabilityColoring,
    }

    settings.visibility = {
        mode =
            defaultSettings
                .visibility
                .mode,

        hideMounted =
            defaultSettings
                .visibility
                .hideMounted,

        hideVehicle =
            defaultSettings
                .visibility
                .hideVehicle,

        hidePetBattle =
            defaultSettings
                .visibility
                .hidePetBattle,
    }

    settings.actionPages = {
        shift = {
            enabled =
                defaultSettings
                    .actionPages
                    .shift
                    .enabled,

            page =
                defaultSettings
                    .actionPages
                    .shift
                    .page,
        },

        ctrl = {
            enabled =
                defaultSettings
                    .actionPages
                    .ctrl
                    .enabled,

            page =
                defaultSettings
                    .actionPages
                    .ctrl
                    .page,
        },

        alt = {
            enabled =
                defaultSettings
                    .actionPages
                    .alt
                    .enabled,

            page =
                defaultSettings
                    .actionPages
                    .alt
                    .page,
        },
    }

    settings.position.point =
        defaultSettings.position.point

    settings.position.relativePoint =
        defaultSettings.position.relativePoint

    settings.position.x =
        defaultSettings.position.x

    settings.position.y =
        defaultSettings.position.y

    settings.name =
        currentName

    settings.keybinds =
        currentKeybinds
        or {}

    if settings.source
        == "custom"
    then
        settings.assignments =
            currentAssignments
            or {}
    end

    ns.UpdateBar(
        selectedBarID
    )

    if ns.ApplyAllKeybinds then
        ns.ApplyAllKeybinds()
    end

    if ns.ApplyBarAppearance then
        ns.ApplyBarAppearance(
            selectedBarID
        )
    end

    ns.RefreshBarMover(
        selectedBarID
    )

    RefreshControls()
end

StaticPopupDialogs[
    "MYTHINC_ACTIONBARS_DELETE_BAR"
] = {
    text =
        "Delete %s?\n\nAll actions and settings stored on this custom bar will be permanently removed.",

    button1 =
        "Delete",

    button2 =
        "Cancel",

    timeout =
        0,

    whileDead =
        true,

    hideOnEscape =
        true,

    preferredIndex =
        3,

    OnAccept =
        function(
            self,
            data
        )
            if not data
                or not data.barID
            then
                return
            end

            local barID =
                data.barID

            local success,
                reason =
                ns.DeleteBar(
                    barID
                )

            if not success then
                if reason
                    == "combat"
                then
                    print(
                        "|cff7fd5ffMythInc Action Bars:|r Cannot delete an action bar during combat."
                    )
                end

                return
            end

            selectedBarID =
                GetFallbackBarID(
                    barID
                )
                or 1

            EnsureSelectedBarVisible()
            RefreshBarSelector()
            RefreshControls()
        end,
}

local function FitConfigToScreen()
    if not panel then
        return
    end

    local targetHeight =
        isMinimized
        and MINIMIZED_HEIGHT
        or WINDOW_HEIGHT

    local scale =
        math.min(
            1,
            (
                UIParent:GetWidth()
                - 32
            )
                / WINDOW_WIDTH,
            (
                UIParent:GetHeight()
                - 32
            )
                / targetHeight
        )

    panel:SetScale(
        scale
    )
end

SetTopLevelMode =
    function(
        mode
    )
        if mode ~= "Action Bars"
            and mode ~= "Profiles"
        then
            return
        end

        selectedTopLevel =
            mode

        if actionBarsTab then
            actionBarsTab:SetSelected(
                mode
                    == "Action Bars"
            )
        end

        if profilesTab then
            profilesTab:SetSelected(
                mode
                    == "Profiles"
            )
        end

        local showActionBars =
            not isMinimized
            and mode
                == "Action Bars"

        local showProfiles =
            not isMinimized
            and mode
                == "Profiles"

        if barSelectorSection then
            barSelectorSection:SetShown(
                showActionBars
            )
        end

        if barHeader then
            barHeader:SetShown(
                showActionBars
            )
        end

        if categoryFrame then
            categoryFrame:SetShown(
                showActionBars
            )
        end

        if pageHost then
            pageHost:SetShown(
                showActionBars
            )
        end

        if resetButton then
            resetButton:SetShown(
                showActionBars
            )
        end

        if deleteButton then
            local settings =
                GetSelectedSettings()

            deleteButton:SetShown(
                showActionBars
                and settings
                and settings.source
                    == "custom"
            )
        end

        if profilesHost then
            profilesHost:SetShown(
                showProfiles
            )
        end

        if showActionBars then
            RefreshControls()
        elseif showProfiles
            and profilesPage
            and profilesPage.Refresh
        then
            profilesPage:Refresh()
        end
    end

local function SetMinimized(
    minimized
)
    isMinimized =
        minimized

    if minimized then
        panel:SetHeight(
            MINIMIZED_HEIGHT
        )

        minimizeButton:SetText(
            "Restore"
        )
    else
        panel:SetHeight(
            WINDOW_HEIGHT
        )

        minimizeButton:SetText(
            "Minimize"
        )
    end

    SetTopLevelMode(
        selectedTopLevel
    )

    FitConfigToScreen()
end

local function CreateHeader()
    logoTexture =
        panel:CreateTexture(
            nil,
            "ARTWORK"
        )

    logoTexture:SetSize(
        96,
        96
    )

    logoTexture:SetPoint(
        "TOPLEFT",
        panel,
        "TOPLEFT",
        18,
        -10
    )

    logoTexture:SetTexture(
        "Interface\\AddOns\\MythIncActionBars\\Media\\Artwork\\MIUF_Icon_128.png"
    )

    local title =
        panel:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        title,
        17
    )

    title:SetPoint(
        "TOPLEFT",
        panel,
        "TOPLEFT",
        120,
        -16
    )

    title:SetText(
        "M Y T H Inc Action Bars"
    )

    local version =
        panel:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        version,
        10,
        true
    )

    version:SetPoint(
        "LEFT",
        title,
        "RIGHT",
        10,
        -1
    )

    version:SetText(
        ns.version
    )

    widgets.CreateButton(
        panel,
        "X",
        28,
        24,
        WINDOW_WIDTH - 38,
        -10,
        function()
            panel:Hide()
        end
    )

    minimizeButton =
        widgets.CreateButton(
            panel,
            "Minimize",
            86,
            24,
            WINDOW_WIDTH - 130,
            -10,
            function()
                SetMinimized(
                    not isMinimized
                )
            end
        )

    actionBarsTab =
        widgets.CreateTabButton(
            panel,
            "Action Bars",
            110,
            28,
            180,
            -48,
            function()
                SetTopLevelMode(
                    "Action Bars"
                )
            end
        )

    profilesTab =
        widgets.CreateTabButton(
            panel,
            "Profiles",
            110,
            28,
            298,
            -48,
            function()
                SetTopLevelMode(
                    "Profiles"
                )
            end
        )

    actionBarsTab:SetSelected(
        true
    )
end

local function CreateBarSelector()
    barSelectorSection =
        widgets.CreateSection(
            panel,
            "ACTION BARS",
            1036,
            100,
            22,
            SELECTOR_TOP
        )

    barSelectorViewport =
        CreateFrame(
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

    barSelectorViewport:SetClipsChildren(
        true
    )

    barSelectorViewport:EnableMouseWheel(
        true
    )

    barSelectorViewport:SetScript(
        "OnMouseWheel",
        function(_, delta)
            local ids =
                ns.GetBarIDs()

            local totalRows =
                math.ceil(
                    #ids
                    / BAR_COLUMNS
                )

            local maxOffset =
                math.max(
                    0,
                    totalRows
                        - BAR_VISIBLE_ROWS
                )

            if delta < 0 then
                barSelectorOffset =
                    math.min(
                        maxOffset,
                        barSelectorOffset
                            + 1
                    )
            elseif delta > 0 then
                barSelectorOffset =
                    math.max(
                        0,
                        barSelectorOffset
                            - 1
                    )
            end

            RefreshBarSelector()
        end
    )

    hideBlizzardCheckbox =
        widgets.CreateCheckButton(
            barSelectorSection,
            "Hide Blizzard Action Bars",
            812,
            -22,
            function()
                return ns.AreBlizzardActionBarsHidden()
            end,
            function(value)
                local success,
                    reason =
                    ns.SetHideBlizzardActionBars(
                        value
                    )

                if not success
                    and reason
                        == "combat"
                then
                    print(
                        "|cff7fd5ffMythInc Action Bars:|r Blizzard bar visibility will update when combat ends."
                    )
                end
            end
        )

    addButton =
        widgets.CreateButton(
            barSelectorSection,
            "Add Action Bar",
            150,
            30,
            866,
            -84,
            function()
                local barID,
                    reason =
                    ns.AddBar()

                if not barID then
                    if reason
                        == "combat"
                    then
                        print(
                            "|cff7fd5ffMythInc Action Bars:|r Cannot create an action bar during combat."
                        )
                    end

                    return
                end

                SelectBar(
                    barID
                )
            end
        )
    unlockAllButton =
    widgets.CreateButton(
        barSelectorSection,
        "Unlock All Bars",
        150,
        30,
        866,
        -50,
        function()
            local success,
                reason =
                ns.ToggleAllBarsUnlocked()

            if not success
                and reason
                    == "combat"
            then
                print(
                    "|cff7fd5ffMythInc Action Bars:|r Bars cannot be unlocked during combat."
                )
            end

            RefreshControls()
        end
    )
end

local function CreateSelectedBarHeader()
    barHeader =
        widgets.CreateSection(
            panel,
            "",
            1036,
            70,
            22,
            -282
        )

    barHeader.Title:Hide()

    barHeaderTitle =
        barHeader:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        barHeaderTitle,
        14
    )

    barHeaderTitle:SetPoint(
        "LEFT",
        barHeader,
        "LEFT",
        16,
        0
    )

    nameControl =
        widgets.CreateEditBox(
            barHeader,
            "Name",
            260,
            220,
            -12,
            function()
                local settings =
                    GetSelectedSettings()

                return settings
                    and settings.name
                    or ""
            end,
            function(value)
                local settings =
                    GetSelectedSettings()

                if not settings then
                    return
                end

                settings.name =
                    value

                EnsureSelectedBarVisible()
                RefreshBarSelector()
                RefreshControls()

                ns.RefreshBarMover(
                    selectedBarID
                )
            end
        )

    enableCheckbox =
        widgets.CreateCheckButton(
            barHeader,
            "Enabled",
            680,
            -23,
            function()
                local settings =
                    GetSelectedSettings()

                return settings
                    and settings.enabled
                    or false
            end,
            function(value)
                ns.SetBarEnabled(
                    selectedBarID,
                    value
                )

                RefreshControls()
            end
        )

    unlockButton =
        widgets.CreateButton(
            barHeader,
            "Unlock Bar",
            160,
            30,
            858,
            -20,
            function()
                local settings =
                    GetSelectedSettings()

                if not settings
                    or not settings.enabled
                then
                    return
                end

                ns.SetBarUnlocked(
                    selectedBarID,
                    not ns.IsBarUnlocked(
                        selectedBarID
                    )
                )

                RefreshControls()
            end
        )
end

local function CreateCategoryTabs()
    categoryFrame =
        CreateFrame(
            "Frame",
            nil,
            panel
        )

    categoryFrame:SetSize(
        1036,
        34
    )

    categoryFrame:SetPoint(
        "TOPLEFT",
        panel,
        "TOPLEFT",
        22,
        -366
    )

    local width = 196
    local spacing = 10

    for index, name in ipairs(
        CATEGORY_NAMES
    ) do
        local button =
            widgets.CreateTabButton(
                categoryFrame,
                name,
                width,
                34,
                (index - 1)
                    * (
                        width
                        + spacing
                    ),
                0,
                function()
                    selectedCategory =
                        name

                    RefreshCategoryButtons()
                end
            )

        categoryButtons[
            name
        ] =
            button
    end
end

local function CreatePageHost()
    pageHost =
        CreateFrame(
            "Frame",
            nil,
            panel
        )

    pageHost:SetPoint(
        "TOPLEFT",
        panel,
        "TOPLEFT",
        22,
        -414
    )

    pageHost:SetPoint(
        "BOTTOMRIGHT",
        panel,
        "BOTTOMRIGHT",
        -22,
        58
    )

    pageHost:SetClipsChildren(
        true
    )

    layoutPage =
        ns.CreateLayoutConfigPage(
            pageHost,
            {
                GetSelectedSettings =
                    GetSelectedSettings,

                GetSelectedBarID =
                    GetSelectedBarID,

                RefreshConfig =
                    RefreshControls,
            }
        )

    appearancePage =
        ns.CreateAppearanceConfigPage(
            pageHost,
            {
                GetSelectedSettings =
                    GetSelectedSettings,

                GetSelectedBarID =
                    GetSelectedBarID,
            }
        )

    visibilityPage =
        ns.CreateVisibilityConfigPage(
            pageHost,
            {
                GetSelectedSettings =
                    GetSelectedSettings,

                GetSelectedBarID =
                    GetSelectedBarID,
            }
        )

    actionPagesPage =
        ns.CreateActionPagesConfigPage(
            pageHost,
            {
                GetSelectedSettings =
                    GetSelectedSettings,

                GetSelectedBarID =
                    GetSelectedBarID,
            }
        )

    keybindsPage =
        ns.CreateKeybindsConfigPage(
            pageHost,
            {
                GetSelectedSettings =
                    GetSelectedSettings,

                GetSelectedBarID =
                    GetSelectedBarID,
            }
        )

    layoutPage:SetAllPoints(
        pageHost
    )

    appearancePage:SetAllPoints(
        pageHost
    )

    visibilityPage:SetAllPoints(
        pageHost
    )

    actionPagesPage:SetAllPoints(
        pageHost
    )

    keybindsPage:SetAllPoints(
        pageHost
    )

    layoutPage:Show()
    appearancePage:Hide()
    visibilityPage:Hide()
    actionPagesPage:Hide()
    keybindsPage:Hide()
end

local function CreateProfilesHost()
    profilesHost =
        CreateFrame(
            "Frame",
            nil,
            panel
        )

    profilesHost:SetPoint(
        "TOPLEFT",
        panel,
        "TOPLEFT",
        22,
        -96
    )

    profilesHost:SetPoint(
        "BOTTOMRIGHT",
        panel,
        "BOTTOMRIGHT",
        -22,
        58
    )

    profilesPage =
        ns.CreateProfilesConfigPage(
            profilesHost
        )

    profilesPage:SetAllPoints(
        profilesHost
    )

    profilesHost:Hide()
end

local function CreateBottomActions()
    resetButton =
        widgets.CreateButton(
            panel,
            "Reset Bar",
            150,
            30,
            22,
            -(WINDOW_HEIGHT - 46),
            function()
                ResetSelectedBar()
            end
        )

    deleteButton =
        widgets.CreateButton(
            panel,
            "Delete Bar",
            150,
            30,
            184,
            -(WINDOW_HEIGHT - 46),
            function()
                local settings =
                    GetSelectedSettings()

                if not settings
                    or settings.source
                        ~= "custom"
                then
                    return
                end

                if InCombatLockdown() then
                    print(
                        "|cff7fd5ffMythInc Action Bars:|r Cannot delete an action bar during combat."
                    )

                    return
                end

                StaticPopup_Show(
                    "MYTHINC_ACTIONBARS_DELETE_BAR",
                    settings.name,
                    nil,
                    {
                        barID =
                            selectedBarID,
                    }
                )
            end
        )
end

local function CreateConfigPanel()
    if panel then
        return panel
    end

    panel =
        CreateFrame(
            "Frame",
            "MythIncActionBarsConfig",
            UIParent,
            "BackdropTemplate"
        )

        table.insert(
    UISpecialFrames,
    "MythIncActionBarsConfig"
)

    panel:SetSize(
        WINDOW_WIDTH,
        WINDOW_HEIGHT
    )

    panel:SetPoint(
        "CENTER"
    )

    widgets.SetBackdrop(
        panel,
        colors.background
    )

    panel:SetFrameStrata(
        "DIALOG"
    )

    panel:SetClampedToScreen(
        true
    )

    panel:SetMovable(
        true
    )

    panel:EnableMouse(
        true
    )

    panel:RegisterForDrag(
        "LeftButton"
    )

    panel:SetScript(
        "OnDragStart",
        panel.StartMoving
    )

    panel:SetScript(
        "OnDragStop",
        panel.StopMovingOrSizing
    )

    panel:RegisterEvent(
        "UI_SCALE_CHANGED"
    )

    panel:RegisterEvent(
        "DISPLAY_SIZE_CHANGED"
    )

    panel:SetScript(
        "OnEvent",
        FitConfigToScreen
    )

    CreateHeader()
    CreateBarSelector()
    CreateSelectedBarHeader()
    CreateCategoryTabs()
    CreatePageHost()
    CreateProfilesHost()
    CreateBottomActions()

    panel:SetScript(
        "OnShow",
        function()
            if not ns.db.bars[
                selectedBarID
            ] then
                local ids =
                    ns.GetBarIDs()

                selectedBarID =
                    ids[1]
                    or 1
            end

            EnsureSelectedBarVisible()
            RefreshBarSelector()
            SetTopLevelMode(
                selectedTopLevel
            )
            FitConfigToScreen()
        end
    )

    panel:SetScript(
        "OnHide",
        function()
            ns.LockAllBars()
        end
    )

    panel:Hide()

    FitConfigToScreen()

    return panel
end

function ns.ToggleConfig()
    local config =
        CreateConfigPanel()

    if config:IsShown() then
        config:Hide()
    else
        config:Show()
    end
end

SLASH_MYTHINCACTIONBARS1 =
    "/miab"

SLASH_MYTHINCACTIONBARS2 =
    "/mythincactionbars"

SlashCmdList.MYTHINCACTIONBARS =
    function()
        ns.ToggleConfig()
    end