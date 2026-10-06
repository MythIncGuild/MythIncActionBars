local addonName, ns = ...

local BUTTONS_PER_BAR = 12

local BLIZZARD_BAR_PAGES = {
    [1] = 1,
    [2] = 6,
    [3] = 5,
    [4] = 4,
    [5] = 3,
    [6] = 13,
    [7] = 14,
    [8] = 15,
}

ns.Bars =
    ns.Bars or {}

local pendingUpdates = {}

local function GetBarSettings(
    barID
)
    return ns.db.bars[barID]
end

local function EnsureVisibilitySettings(
    settings
)
    if not settings then
        return nil
    end

    settings.visibility =
        settings.visibility
        or {}

    local visibility =
        settings.visibility

    if visibility.mode
        ~= "always"
        and visibility.mode
            ~= "combat"
        and visibility.mode
            ~= "nocombat"
    then
        visibility.mode =
            "always"
    end

    if visibility.hideMounted == nil then
        visibility.hideMounted =
            false
    end

    if visibility.hideVehicle == nil then
        visibility.hideVehicle =
            false
    end

    if visibility.hidePetBattle == nil then
        visibility.hidePetBattle =
            false
    end

    return visibility
end

local function EnsureModifierPage(
    actionPages,
    modifier,
    defaultPage
)
    actionPages[modifier] =
        actionPages[modifier]
        or {}

    local settings =
        actionPages[modifier]

    if settings.enabled == nil then
        settings.enabled =
            false
    end

    settings.page =
        math.floor(
            tonumber(
                settings.page
            )
                or defaultPage
        )

    settings.page =
        math.max(
            1,
            math.min(
                15,
                settings.page
            )
        )

    return settings
end

local function EnsureActionPageSettings(
    settings
)
    if not settings then
        return nil
    end

    settings.actionPages =
        settings.actionPages
        or {}

    EnsureModifierPage(
        settings.actionPages,
        "shift",
        2
    )

    EnsureModifierPage(
        settings.actionPages,
        "ctrl",
        3
    )

    EnsureModifierPage(
        settings.actionPages,
        "alt",
        4
    )

    return settings.actionPages
end

local function BuildVisibilityDriver(
    settings
)
    local visibility =
        EnsureVisibilitySettings(
            settings
        )

    local conditions = {}

    if visibility.hideMounted then
        conditions[
            #conditions + 1
        ] =
            "[mounted] hide"
    end

    if visibility.hideVehicle then
        conditions[
            #conditions + 1
        ] =
            "[vehicleui] hide"

        conditions[
            #conditions + 1
        ] =
            "[overridebar] hide"
    end

    if visibility.hidePetBattle then
        conditions[
            #conditions + 1
        ] =
            "[petbattle] hide"
    end

    if visibility.mode
        == "combat"
    then
        conditions[
            #conditions + 1
        ] =
            "[combat] show"

        conditions[
            #conditions + 1
        ] =
            "hide"

    elseif visibility.mode
        == "nocombat"
    then
        conditions[
            #conditions + 1
        ] =
            "[combat] hide"

        conditions[
            #conditions + 1
        ] =
            "show"

    else
        conditions[
            #conditions + 1
        ] =
            "show"
    end

    return table.concat(
        conditions,
        "; "
    )
end

local function HasConditionalVisibility(
    settings
)
    local visibility =
        EnsureVisibilitySettings(
            settings
        )

    return visibility.mode
        ~= "always"
        or visibility.hideMounted
        or visibility.hideVehicle
        or visibility.hidePetBattle
end

local function GetBlizzardActionSlot(
    barID,
    buttonID
)
    local page =
        BLIZZARD_BAR_PAGES[
            barID
        ]

    if not page then
        return nil
    end

    return (
        (page - 1)
        * BUTTONS_PER_BAR
    )
        + buttonID
end

local function LayoutBar(
    barID
)
    local bar =
        ns.Bars[barID]

    local settings =
        GetBarSettings(
            barID
        )

    if not bar
        or not settings
    then
        return
    end

    if not settings.enabled then
        return
    end

    local buttonCount =
        settings.buttonCount

    local buttonSize =
        settings.buttonSize

    local spacing =
        settings.spacing

    local columns =
        math.max(
            1,
            math.min(
                settings.columns,
                buttonCount
            )
        )

    local rows =
        math.ceil(
            buttonCount
            / columns
        )

    local width =
        (buttonSize * columns)
        + (
            spacing
            * (columns - 1)
        )

    local height =
        (buttonSize * rows)
        + (
            spacing
            * (rows - 1)
        )

    bar:SetSize(
        width,
        height
    )

    bar:SetScale(
        settings.scale
    )

    for buttonID, button in ipairs(
        bar.buttons
    ) do
        button:ClearAllPoints()

        button:SetSize(
            buttonSize,
            buttonSize
        )

        local index =
            buttonID - 1

        local column =
            index % columns

        local row =
            math.floor(
                index / columns
            )

        button:SetPoint(
            "TOPLEFT",
            bar,
            "TOPLEFT",
            column
                * (
                    buttonSize
                    + spacing
                ),
            -(
                row
                * (
                    buttonSize
                    + spacing
                )
            )
        )

        button:SetShown(
            buttonID
                <= buttonCount
        )
    end
end

local function UpdatePosition(
    barID
)
    local bar =
        ns.Bars[barID]

    local settings =
        GetBarSettings(
            barID
        )

    if not bar
        or not settings
    then
        return
    end

    local position =
        settings.position

    bar:ClearAllPoints()

    bar:SetPoint(
        position.point,
        UIParent,
        position.relativePoint,
        position.x,
        position.y
    )
end

local function ApplyActionPages(
    barID
)
    local bar =
        ns.Bars[barID]

    local settings =
        GetBarSettings(
            barID
        )

    if not bar
        or not settings
    then
        return
    end

    local actionPages =
        EnsureActionPageSettings(
            settings
        )

    if settings.source
        ~= "blizzard"
    then
        return
    end

    for _, button in ipairs(
        bar.buttons
    ) do
        if button.ConfigureActionPages then
            button.ConfigureActionPages(
                actionPages
            )
        end
    end
end

local function ApplyVisibility(
    barID
)
    local bar =
        ns.Bars[barID]

    local settings =
        GetBarSettings(
            barID
        )

    if not bar
        or not settings
    then
        return
    end

    EnsureVisibilitySettings(
        settings
    )

    if not settings.enabled then
        UnregisterStateDriver(
            bar,
            "visibility"
        )

        bar:Hide()

        return
    end

    if HasConditionalVisibility(
        settings
    ) then
        local driver =
            BuildVisibilityDriver(
                settings
            )

        RegisterStateDriver(
            bar,
            "visibility",
            driver
        )
    else
        UnregisterStateDriver(
            bar,
            "visibility"
        )

        bar:Show()
    end
end

local function ApplyBarUpdate(
    barID
)
    LayoutBar(
        barID
    )

    UpdatePosition(
        barID
    )

    ApplyActionPages(
        barID
    )

    ApplyVisibility(
        barID
    )

    if ns.ApplyBarAppearance then
        ns.ApplyBarAppearance(
            barID
        )
    end

    if ns.RefreshBarMover then
        ns.RefreshBarMover(
            barID
        )
    end
end

local function CreateBlizzardButton(
    bar,
    barID,
    buttonID
)
    local actionSlot =
        GetBlizzardActionSlot(
            barID,
            buttonID
        )

    if not actionSlot then
        return nil
    end

    return ns.CreateActionButton(
        bar,
        "MythIncActionBarsBar"
            .. barID
            .. "Button"
            .. buttonID,
        actionSlot
    )
end

local function CreateCustomButton(
    bar,
    barID,
    buttonID
)
    return ns.CreateCustomActionButton(
        bar,
        "MythIncActionBarsBar"
            .. barID
            .. "Button"
            .. buttonID,
        barID,
        buttonID
    )
end

function ns.CreateBar(
    barID
)
    if ns.Bars[barID] then
        return ns.Bars[barID]
    end

    local settings =
        GetBarSettings(
            barID
        )

    if not settings then
        return
    end

    EnsureVisibilitySettings(
        settings
    )

    EnsureActionPageSettings(
        settings
    )

    settings.keybinds =
        settings.keybinds
        or {}

    local bar =
        CreateFrame(
            "Frame",
            "MythIncActionBarsBar"
                .. barID,
            UIParent,
            "SecureHandlerStateTemplate"
        )

    bar.barID =
        barID

    bar.buttons = {}

    for buttonID =
        1,
        BUTTONS_PER_BAR
    do
        local button

        if settings.source
            == "custom"
        then
            button =
                CreateCustomButton(
                    bar,
                    barID,
                    buttonID
                )
        else
            button =
                CreateBlizzardButton(
                    bar,
                    barID,
                    buttonID
                )
        end

        if button then
            bar.buttons[
                buttonID
            ] =
                button
        end
    end

    ns.Bars[
        barID
    ] =
        bar

    ApplyBarUpdate(
        barID
    )

    return bar
end

function ns.UpdateBar(
    barID
)
    if InCombatLockdown() then
        pendingUpdates[
            barID
        ] =
            true

        return false
    end

    ApplyBarUpdate(
        barID
    )

    return true
end

function ns.SetBarEnabled(
    barID,
    enabled
)
    local settings =
        GetBarSettings(
            barID
        )

    if not settings then
        return
    end

    settings.enabled =
        enabled
        and true
        or false

    if not settings.enabled
        and ns.SetBarUnlocked
    then
        ns.SetBarUnlocked(
            barID,
            false
        )
    end

    ns.UpdateBar(
        barID
    )

    if ns.ApplyAllKeybinds then
        ns.ApplyAllKeybinds()
    end
end

function ns.GetBarVisibilitySettings(
    barID
)
    local settings =
        GetBarSettings(
            barID
        )

    if not settings then
        return nil
    end

    return EnsureVisibilitySettings(
        settings
    )
end

function ns.GetBarVisibilityMode(
    barID
)
    local visibility =
        ns.GetBarVisibilitySettings(
            barID
        )

    if not visibility then
        return "always"
    end

    return visibility.mode
end

function ns.SetBarVisibilityMode(
    barID,
    mode
)
    if mode ~= "always"
        and mode ~= "combat"
        and mode ~= "nocombat"
    then
        return false,
            "invalid"
    end

    local visibility =
        ns.GetBarVisibilitySettings(
            barID
        )

    if not visibility then
        return false,
            "missing"
    end

    visibility.mode =
        mode

    local updated =
        ns.UpdateBar(
            barID
        )

    if not updated
        and InCombatLockdown()
    then
        return false,
            "combat"
    end

    return true
end

function ns.SetBarVisibilityOption(
    barID,
    option,
    enabled
)
    if option ~= "hideMounted"
        and option ~= "hideVehicle"
        and option ~= "hidePetBattle"
    then
        return false,
            "invalid"
    end

    local visibility =
        ns.GetBarVisibilitySettings(
            barID
        )

    if not visibility then
        return false,
            "missing"
    end

    visibility[option] =
        enabled
        and true
        or false

    local updated =
        ns.UpdateBar(
            barID
        )

    if not updated
        and InCombatLockdown()
    then
        return false,
            "combat"
    end

    return true
end

function ns.BarSupportsActionPages(
    barID
)
    local settings =
        GetBarSettings(
            barID
        )

    return settings
        and settings.source
            == "blizzard"
end

function ns.GetBarBasePage(
    barID
)
    return BLIZZARD_BAR_PAGES[
        barID
    ]
end

function ns.GetBarActionPageSettings(
    barID
)
    local settings =
        GetBarSettings(
            barID
        )

    if not settings then
        return nil
    end

    return EnsureActionPageSettings(
        settings
    )
end

function ns.SetBarModifierPageEnabled(
    barID,
    modifier,
    enabled
)
    if modifier ~= "shift"
        and modifier ~= "ctrl"
        and modifier ~= "alt"
    then
        return false,
            "invalid"
    end

    if not ns.BarSupportsActionPages(
        barID
    ) then
        return false,
            "unsupported"
    end

    local actionPages =
        ns.GetBarActionPageSettings(
            barID
        )

    if not actionPages then
        return false,
            "missing"
    end

    actionPages[
        modifier
    ].enabled =
        enabled
        and true
        or false

    local updated =
        ns.UpdateBar(
            barID
        )

    if not updated
        and InCombatLockdown()
    then
        return false,
            "combat"
    end

    if ns.ApplyAllKeybinds then
        ns.ApplyAllKeybinds()
    end

    return true
end

function ns.SetBarModifierPage(
    barID,
    modifier,
    page
)
    if modifier ~= "shift"
        and modifier ~= "ctrl"
        and modifier ~= "alt"
    then
        return false,
            "invalid"
    end

    if not ns.BarSupportsActionPages(
        barID
    ) then
        return false,
            "unsupported"
    end

    page =
        math.floor(
            tonumber(
                page
            )
                or 1
        )

    page =
        math.max(
            1,
            math.min(
                15,
                page
            )
        )

    local actionPages =
        ns.GetBarActionPageSettings(
            barID
        )

    if not actionPages then
        return false,
            "missing"
    end

    actionPages[
        modifier
    ].page =
        page

    local updated =
        ns.UpdateBar(
            barID
        )

    if not updated
        and InCombatLockdown()
    then
        return false,
            "combat"
    end

    return true
end

function ns.GetBar(
    barID
)
    return ns.Bars[
        barID
    ]
end

function ns.GetBarIDs()
    local ids = {}

    for barID, settings in pairs(
        ns.db.bars
    ) do
        if type(barID)
            == "number"
            and type(settings)
                == "table"
        then
            ids[
                #ids + 1
            ] =
                barID
        end
    end

    table.sort(
        ids
    )

    return ids
end

function ns.GetBarCount()
    local count = 0

    for barID, settings in pairs(
        ns.db.bars
    ) do
        if type(barID)
            == "number"
            and type(settings)
                == "table"
        then
            count =
                count + 1
        end
    end

    return count
end

function ns.GetHighestBarID()
    local highest = 0

    for barID in pairs(
        ns.db.bars
    ) do
        if type(barID)
            == "number"
            and barID > highest
        then
            highest =
                barID
        end
    end

    return highest
end

function ns.AddBar()
    if InCombatLockdown() then
        return nil,
            "combat"
    end

    local barID =
        ns.GetHighestBarID()
        + 1

    ns.db.bars[
        barID
    ] =
        ns.CreateDefaultBarSettings(
            barID,
            true,
            "custom"
        )

    ns.CreateBar(
        barID
    )

    if ns.ApplyAllKeybinds then
        ns.ApplyAllKeybinds()
    end

    return barID
end

function ns.DeleteBar(
    barID
)
    if InCombatLockdown() then
        return false,
            "combat"
    end

    local settings =
        GetBarSettings(
            barID
        )

    if not settings then
        return false,
            "missing"
    end

    if settings.source
        ~= "custom"
    then
        return false,
            "protected"
    end

    if ns.IsBarUnlocked
        and ns.IsBarUnlocked(
            barID
        )
    then
        ns.SetBarUnlocked(
            barID,
            false
        )
    end

    local bar =
        ns.Bars[
            barID
        ]

    if bar then
        UnregisterStateDriver(
            bar,
            "visibility"
        )

        bar:Hide()
    end

    local mover =
        ns.Movers
        and ns.Movers[
            barID
        ]

    if mover then
        mover:Hide()
    end

    pendingUpdates[
        barID
    ] =
        nil

    ns.db.bars[
        barID
    ] =
        nil

    ns.Bars[
        barID
    ] =
        nil

    if ns.Movers then
        ns.Movers[
            barID
        ] =
            nil
    end

    if ns.ApplyAllKeybinds then
        ns.ApplyAllKeybinds()
    end

    return true
end

local eventFrame =
    CreateFrame(
        "Frame"
    )

eventFrame:RegisterEvent(
    "PLAYER_LOGIN"
)

eventFrame:RegisterEvent(
    "PLAYER_REGEN_ENABLED"
)

eventFrame:SetScript(
    "OnEvent",
    function(_, event)
        if event
            == "PLAYER_LOGIN"
        then
            for _, barID in ipairs(
                ns.GetBarIDs()
            ) do
                ns.CreateBar(
                    barID
                )
            end

            if ns.ApplyAllKeybinds then
                ns.ApplyAllKeybinds()
            end

            return
        end

        if event
            == "PLAYER_REGEN_ENABLED"
        then
            for barID in pairs(
                pendingUpdates
            ) do
                pendingUpdates[
                    barID
                ] =
                    nil

                if ns.db.bars[
                    barID
                ] then
                    ApplyBarUpdate(
                        barID
                    )
                end
            end
        end
    end
)