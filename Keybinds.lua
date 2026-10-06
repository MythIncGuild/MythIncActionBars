local addonName, ns = ...

local bindingOwner =
    CreateFrame(
        "Frame",
        "MythIncActionBarsBindingOwner",
        UIParent
    )

local blockedBindingButton =
    CreateFrame(
        "Button",
        "MythIncActionBarsBlockedBindingButton",
        UIParent,
        "SecureActionButtonTemplate"
    )

blockedBindingButton:SetSize(
    1,
    1
)

blockedBindingButton:SetPoint(
    "BOTTOMLEFT",
    UIParent,
    "BOTTOMLEFT",
    -10,
    -10
)

blockedBindingButton:SetAlpha(
    0
)

blockedBindingButton:EnableMouse(
    false
)

local keyboardListener =
    CreateFrame(
        "Frame",
        "MythIncActionBarsKeybindListener",
        UIParent
    )

keyboardListener:SetSize(
    1,
    1
)

keyboardListener:SetPoint(
    "CENTER"
)

keyboardListener:EnableKeyboard(
    true
)

keyboardListener:SetPropagateKeyboardInput(
    true
)

keyboardListener:Hide()

local bindModeFrame =
    CreateFrame(
        "Frame",
        "MythIncActionBarsBindModeFrame",
        UIParent,
        "BackdropTemplate"
    )

bindModeFrame:SetSize(
    480,
    72
)

bindModeFrame:SetPoint(
    "TOP",
    UIParent,
    "TOP",
    0,
    -100
)

bindModeFrame:SetFrameStrata(
    "TOOLTIP"
)

bindModeFrame:SetBackdrop({
    bgFile =
        "Interface\\Buttons\\WHITE8x8",

    edgeFile =
        "Interface\\Buttons\\WHITE8x8",

    edgeSize =
        1,
})

bindModeFrame:SetBackdropColor(
    0.03,
    0.04,
    0.045,
    0.96
)

bindModeFrame:SetBackdropBorderColor(
    0.15,
    0.65,
    0.68,
    1
)

local bindModeTitle =
    bindModeFrame:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormal"
    )

bindModeTitle:SetPoint(
    "TOP",
    bindModeFrame,
    "TOP",
    0,
    -12
)

bindModeTitle:SetText(
    "MythInc Action Bars - Keybind Mode"
)

local bindModeText =
    bindModeFrame:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )

bindModeText:SetPoint(
    "TOP",
    bindModeTitle,
    "BOTTOM",
    0,
    -8
)

bindModeText:SetText(
    "Hover a MIAB button and press a key. Delete clears. Escape exits."
)

bindModeFrame:Hide()

local pendingApply = false
local bindModeActive = false
local hoveredBindTarget
local bindOverlays = {}

local BLIZZARD_BINDING_PREFIXES = {
    [1] = "ACTIONBUTTON",
    [2] = "MULTIACTIONBAR1BUTTON",
    [3] = "MULTIACTIONBAR2BUTTON",
    [4] = "MULTIACTIONBAR3BUTTON",
    [5] = "MULTIACTIONBAR4BUTTON",
    [6] = "MULTIACTIONBAR5BUTTON",
    [7] = "MULTIACTIONBAR6BUTTON",
    [8] = "MULTIACTIONBAR7BUTTON",
}

local PAGE_TO_BAR = {
    [1] = 1,
    [6] = 2,
    [5] = 3,
    [4] = 4,
    [3] = 5,
    [13] = 6,
    [14] = 7,
    [15] = 8,
}

local function GetBarSettings(
    barID
)
    return ns.db
        and ns.db.bars
        and ns.db.bars[barID]
end

local function EnsureBarKeybinds(
    settings
)
    if not settings then
        return nil
    end

    settings.keybinds =
        settings.keybinds
        or {}

    return settings.keybinds
end

local function EnsureButtonEntry(
    barID,
    buttonID
)
    local settings =
        GetBarSettings(
            barID
        )

    if not settings then
        return nil
    end

    local keybinds =
        EnsureBarKeybinds(
            settings
        )

    keybinds[buttonID] =
        keybinds[buttonID]
        or {
            primary = nil,
            secondary = nil,
        }

    return keybinds[buttonID]
end

local function NormalizeKey(
    key
)
    if type(key)
        ~= "string"
    then
        return nil
    end

    key =
        string.upper(
            key
        )

    key =
        string.gsub(
            key,
            "%s+",
            ""
        )

    if key == "" then
        return nil
    end

    return key
end

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

local function NormalizeMouseButton(
    button
)
    local map = {
        LeftButton = "BUTTON1",
        RightButton = "BUTTON2",
        MiddleButton = "BUTTON3",
        Button4 = "BUTTON4",
        Button5 = "BUTTON5",
    }

    return map[button]
        or string.upper(
            button
        )
end

function ns.BuildCapturedKey(
    base
)
    if not base
        or IsModifierOnly(
            base
        )
    then
        return nil
    end

    local parts = {}

    if IsAltKeyDown() then
        parts[
            #parts + 1
        ] =
            "ALT"
    end

    if IsControlKeyDown() then
        parts[
            #parts + 1
        ] =
            "CTRL"
    end

    if IsShiftKeyDown() then
        parts[
            #parts + 1
        ] =
            "SHIFT"
    end

    parts[
        #parts + 1
    ] =
        string.upper(
            base
        )

    return table.concat(
        parts,
        "-"
    )
end

function ns.NormalizeKeybindMouseButton(
    button
)
    return NormalizeMouseButton(
        button
    )
end

local function ParseKey(
    key
)
    local normalized =
        NormalizeKey(
            key
        )

    if not normalized then
        return nil
    end

    local modifiers = {
        ALT = false,
        CTRL = false,
        SHIFT = false,
    }

    local baseParts = {}

    for part in string.gmatch(
        normalized,
        "[^%-]+"
    ) do
        if part == "ALT"
            or part == "CTRL"
            or part == "SHIFT"
        then
            modifiers[
                part
            ] =
                true
        else
            baseParts[
                #baseParts + 1
            ] =
                part
        end
    end

    if #baseParts == 0 then
        return nil
    end

    return modifiers,
        table.concat(
            baseParts,
            "-"
        )
end

local function BuildKey(
    modifiers,
    base
)
    local parts = {}

    if modifiers.ALT then
        parts[
            #parts + 1
        ] =
            "ALT"
    end

    if modifiers.CTRL then
        parts[
            #parts + 1
        ] =
            "CTRL"
    end

    if modifiers.SHIFT then
        parts[
            #parts + 1
        ] =
            "SHIFT"
    end

    parts[
        #parts + 1
    ] =
        base

    return table.concat(
        parts,
        "-"
    )
end

local function CopyModifiers(
    modifiers
)
    return {
        ALT =
            modifiers.ALT,

        CTRL =
            modifiers.CTRL,

        SHIFT =
            modifiers.SHIFT,
    }
end

local function GetActionPageModifiers(
    settings
)
    local result = {}

    if not settings
        or settings.source
            ~= "blizzard"
        or not settings.actionPages
    then
        return result
    end

    if settings.actionPages.shift
        and settings.actionPages.shift.enabled
    then
        result[
            #result + 1
        ] =
            "SHIFT"
    end

    if settings.actionPages.ctrl
        and settings.actionPages.ctrl.enabled
    then
        result[
            #result + 1
        ] =
            "CTRL"
    end

    if settings.actionPages.alt
        and settings.actionPages.alt.enabled
    then
        result[
            #result + 1
        ] =
            "ALT"
    end

    return result
end

local function BuildBlockedModifierKeys(
    key,
    settings
)
    local modifiers,
        base =
        ParseKey(
            key
        )

    if not modifiers then
        return {}
    end

    local pageModifiers =
        GetActionPageModifiers(
            settings
        )

    local missing = {}

    for _, modifier in ipairs(
        pageModifiers
    ) do
        if not modifiers[
            modifier
        ] then
            missing[
                #missing + 1
            ] =
                modifier
        end
    end

    local results = {}

    local combinations =
        (2 ^ #missing)
        - 1

    for mask =
        1,
        combinations
    do
        local derivedModifiers =
            CopyModifiers(
                modifiers
            )

        for index, modifier in ipairs(
            missing
        ) do
            local bit =
                2 ^ (
                    index - 1
                )

            if math.floor(
                mask / bit
            ) % 2 == 1
            then
                derivedModifiers[
                    modifier
                ] =
                    true
            end
        end

        results[
            #results + 1
        ] =
            BuildKey(
                derivedModifiers,
                base
            )
    end

    return results
end

local function FormatBaseKey(
    base
)
    local replacements = {
        BUTTON1 = "M1",
        BUTTON2 = "M2",
        BUTTON3 = "M3",
        BUTTON4 = "M4",
        BUTTON5 = "M5",
        MOUSEWHEELUP = "MWU",
        MOUSEWHEELDOWN = "MWD",
        NUMPADPLUS = "N+",
        NUMPADMINUS = "N-",
        NUMPADMULTIPLY = "N*",
        NUMPADDIVIDE = "N/",
        SPACE = "Spc",
    }

    return replacements[
        base
    ]
        or base
end

function ns.FormatKeybind(
    key
)
    local modifiers,
        base =
        ParseKey(
            key
        )

    if not modifiers then
        return ""
    end

    local text = ""

    if modifiers.ALT then
        text =
            text .. "A-"
    end

    if modifiers.CTRL then
        text =
            text .. "C-"
    end

    if modifiers.SHIFT then
        text =
            text .. "S-"
    end

    return text
        .. FormatBaseKey(
            base
        )
end

function ns.GetButtonKeybind(
    barID,
    buttonID,
    slot
)
    if slot ~= "primary"
        and slot ~= "secondary"
    then
        return nil
    end

    local entry =
        EnsureButtonEntry(
            barID,
            buttonID
        )

    if not entry then
        return nil
    end

    return entry[
        slot
    ]
end

function ns.GetDisplayKeybindForActionSlot(
    actionSlot
)
    actionSlot =
        tonumber(
            actionSlot
        )

    if not actionSlot
        or actionSlot < 1
    then
        return nil
    end

    local page =
        math.floor(
            (actionSlot - 1)
            / 12
        )
        + 1

    local buttonID =
        ((actionSlot - 1) % 12)
        + 1

    local barID =
        PAGE_TO_BAR[
            page
        ]

    if not barID then
        return nil
    end

    local entry =
        EnsureButtonEntry(
            barID,
            buttonID
        )

    if not entry then
        return nil
    end

    return entry.primary
        or entry.secondary
end

local function RemoveDuplicateBindings(
    key,
    exceptBarID,
    exceptButtonID,
    exceptSlot
)
    local conflicts = {}

    for barID, settings in pairs(
        ns.db.bars
    ) do
        local keybinds =
            EnsureBarKeybinds(
                settings
            )

        for buttonID, entry in pairs(
            keybinds
        ) do
            if type(buttonID)
                == "number"
                and type(entry)
                    == "table"
            then
                for _, slot in ipairs({
                    "primary",
                    "secondary",
                }) do
                    if entry[slot]
                        == key
                        and not (
                            barID
                                == exceptBarID
                            and buttonID
                                == exceptButtonID
                            and slot
                                == exceptSlot
                        )
                    then
                        conflicts[
                            #conflicts + 1
                        ] = {
                            barID =
                                barID,

                            buttonID =
                                buttonID,

                            slot =
                                slot,
                        }

                        entry[
                            slot
                        ] =
                            nil
                    end
                end
            end
        end
    end

    return conflicts
end

local function GetExistingMIABKeys()
    local used = {}

    if not ns.db
        or not ns.db.bars
    then
        return used
    end

    for _, settings in pairs(
        ns.db.bars
    ) do
        local keybinds =
            EnsureBarKeybinds(
                settings
            )

        for _, entry in pairs(
            keybinds
        ) do
            if type(entry)
                == "table"
            then
                for _, slot in ipairs({
                    "primary",
                    "secondary",
                }) do
                    local key =
                        NormalizeKey(
                            entry[
                                slot
                            ]
                        )

                    if key then
                        used[
                            key
                        ] =
                            true
                    end
                end
            end
        end
    end

    return used
end

function ns.ImportBlizzardKeybinds()
    if not ns.db
        or not ns.db.bars
    then
        return false
    end

    if ns.db.keybindsImportedFromBlizzard
        == true
    then
        return false
    end

    local used =
        GetExistingMIABKeys()

    for barID = 1, 8 do
        local settings =
            GetBarSettings(
                barID
            )

        local prefix =
            BLIZZARD_BINDING_PREFIXES[
                barID
            ]

        if settings
            and prefix
        then
            for buttonID = 1, 12 do
                local entry =
                    EnsureButtonEntry(
                        barID,
                        buttonID
                    )

                if entry
                    and not entry.primary
                    and not entry.secondary
                then
                    local command =
                        prefix
                        .. buttonID

                    local primary,
                        secondary =
                        GetBindingKey(
                            command
                        )

                    primary =
                        NormalizeKey(
                            primary
                        )

                    secondary =
                        NormalizeKey(
                            secondary
                        )

                    if primary
                        and not used[
                            primary
                        ]
                    then
                        entry.primary =
                            primary

                        used[
                            primary
                        ] =
                            true
                    end

                    if secondary
                        and not used[
                            secondary
                        ]
                    then
                        entry.secondary =
                            secondary

                        used[
                            secondary
                        ] =
                            true
                    end
                end
            end
        end
    end

    ns.db.keybindsImportedFromBlizzard =
        true

    return true
end

function ns.RefreshKeybindDisplay()
    if not ns.Bars
        or not ns.db
        or not ns.db.bars
    then
        return
    end

    for barID, bar in pairs(
        ns.Bars
    ) do
        local settings =
            GetBarSettings(
                barID
            )

        if settings then
            local keybinds =
                EnsureBarKeybinds(
                    settings
                )

            for buttonID, button in ipairs(
                bar.buttons
            ) do
                if button.RefreshKeybindText then
                    button.RefreshKeybindText()
                else
                    local entry =
                        keybinds[
                            buttonID
                        ]

                    local key =
                        entry
                        and (
                            entry.primary
                            or entry.secondary
                        )

                    if button.SetKeybindText then
                        button.SetKeybindText(
                            ns.FormatKeybind(
                                key
                            )
                        )

                    elseif button.HotKey then
                        button.HotKey:SetText(
                            ns.FormatKeybind(
                                key
                            )
                        )
                    end
                end
            end
        end
    end
end

function ns.ApplyAllKeybinds()
    ns.RefreshKeybindDisplay()

    if InCombatLockdown() then
        pendingApply =
            true

        return false,
            "combat"
    end

    ClearOverrideBindings(
        bindingOwner
    )

    local explicit = {}
    local boundEntries = {}

    for _, barID in ipairs(
        ns.GetBarIDs()
    ) do
        local settings =
            GetBarSettings(
                barID
            )

        local bar =
            ns.Bars
            and ns.Bars[
                barID
            ]

        if settings
            and bar
            and settings.enabled
        then
            local keybinds =
                EnsureBarKeybinds(
                    settings
                )

            local buttonCount =
                math.min(
                    settings.buttonCount
                        or 12,
                    #bar.buttons
                )

            for buttonID =
                1,
                buttonCount
            do
                local button =
                    bar.buttons[
                        buttonID
                    ]

                local entry =
                    keybinds[
                        buttonID
                    ]

                if button
                    and entry
                then
                    for _, slot in ipairs({
                        "primary",
                        "secondary",
                    }) do
                        local key =
                            NormalizeKey(
                                entry[
                                    slot
                                ]
                            )

                        if key
                            and not explicit[
                                key
                            ]
                        then
                            explicit[
                                key
                            ] =
                                true

                            boundEntries[
                                #boundEntries + 1
                            ] = {
                                key =
                                    key,

                                settings =
                                    settings,
                            }

                            SetOverrideBindingClick(
                                bindingOwner,
                                true,
                                key,
                                button:GetName(),
                                "LeftButton"
                            )
                        end
                    end
                end
            end
        end
    end

    local blocked = {}

    for _, data in ipairs(
        boundEntries
    ) do
        local blockedKeys =
            BuildBlockedModifierKeys(
                data.key,
                data.settings
            )

        for _, blockedKey in ipairs(
            blockedKeys
        ) do
            if not explicit[
                blockedKey
            ]
                and not blocked[
                    blockedKey
                ]
            then
                blocked[
                    blockedKey
                ] =
                    true

                SetOverrideBindingClick(
                    bindingOwner,
                    true,
                    blockedKey,
                    blockedBindingButton:GetName(),
                    "LeftButton"
                )
            end
        end
    end

    pendingApply =
        false

    return true
end

function ns.SetButtonKeybind(
    barID,
    buttonID,
    slot,
    key
)
    if slot ~= "primary"
        and slot ~= "secondary"
    then
        return false,
            "invalid"
    end

    if InCombatLockdown() then
        return false,
            "combat"
    end

    local entry =
        EnsureButtonEntry(
            barID,
            buttonID
        )

    if not entry then
        return false,
            "missing"
    end

    local normalized =
        NormalizeKey(
            key
        )

    if not normalized then
        entry[
            slot
        ] =
            nil

        ns.ApplyAllKeybinds()

        return true,
            {}
    end

    local modifiers =
        ParseKey(
            normalized
        )

    if not modifiers then
        return false,
            "invalid"
    end

    local conflicts =
        RemoveDuplicateBindings(
            normalized,
            barID,
            buttonID,
            slot
        )

    entry[
        slot
    ] =
        normalized

    ns.ApplyAllKeybinds()

    return true,
        conflicts
end

function ns.ClearButtonKeybind(
    barID,
    buttonID,
    slot
)
    return ns.SetButtonKeybind(
        barID,
        buttonID,
        slot,
        nil
    )
end

function ns.ClearBarKeybinds(
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

    settings.keybinds = {}

    ns.ApplyAllKeybinds()

    return true
end

local function SetHoveredOverlay(
    overlay
)
    hoveredBindTarget =
        overlay

    if not overlay then
        bindModeText:SetText(
            "Hover a MIAB button and press a key. Delete clears. Escape exits."
        )

        return
    end

    local key =
        ns.GetButtonKeybind(
            overlay.barID,
            overlay.buttonID,
            "primary"
        )

    local display =
        key
        and ns.FormatKeybind(
            key
        )
        or "Unbound"

    local settings =
        GetBarSettings(
            overlay.barID
        )

    local barName =
        settings
        and settings.name
        or (
            "Bar "
            .. overlay.barID
        )

    bindModeText:SetText(
        barName
        .. " - Button "
        .. overlay.buttonID
        .. " - Current: "
        .. display
    )
end

local function BindHoveredKey(
    key
)
    if not bindModeActive
        or not hoveredBindTarget
    then
        return
    end

    local success =
        ns.SetButtonKeybind(
            hoveredBindTarget.barID,
            hoveredBindTarget.buttonID,
            "primary",
            key
        )

    if not success then
        return
    end

    SetHoveredOverlay(
        hoveredBindTarget
    )

    if ns.RefreshConfig then
        ns.RefreshConfig()
    end
end

local function CreateBindOverlay(
    barID,
    buttonID,
    button
)
    local existing =
        bindOverlays[
            button
        ]

    if existing then
        existing.barID =
            barID

        existing.buttonID =
            buttonID

        return existing
    end

    local overlay =
        CreateFrame(
            "Frame",
            nil,
            button,
            "BackdropTemplate"
        )

    overlay:SetAllPoints(
        button
    )

    overlay:SetFrameLevel(
        button:GetFrameLevel()
        + 20
    )

    overlay:SetBackdrop({
        edgeFile =
            "Interface\\Buttons\\WHITE8x8",

        edgeSize =
            2,
    })

    overlay:SetBackdropBorderColor(
        0.15,
        0.65,
        0.68,
        0.9
    )

    overlay:EnableMouse(
        true
    )

    overlay:EnableMouseWheel(
        true
    )

    overlay.barID =
        barID

    overlay.buttonID =
        buttonID

    overlay:SetScript(
        "OnEnter",
        function(self)
            self:SetBackdropBorderColor(
                0.2,
                0.9,
                0.9,
                1
            )

            SetHoveredOverlay(
                self
            )
        end
    )

    overlay:SetScript(
        "OnLeave",
        function(self)
            self:SetBackdropBorderColor(
                0.15,
                0.65,
                0.68,
                0.9
            )

            if hoveredBindTarget
                == self
            then
                SetHoveredOverlay(
                    nil
                )
            end
        end
    )

    overlay:SetScript(
        "OnMouseDown",
        function(
            _,
            mouseButton
        )
            if mouseButton
                == "LeftButton"
                or mouseButton
                    == "RightButton"
            then
                return
            end

            local base =
                NormalizeMouseButton(
                    mouseButton
                )

            local key =
                ns.BuildCapturedKey(
                    base
                )

            if key then
                BindHoveredKey(
                    key
                )
            end
        end
    )

    overlay:SetScript(
        "OnMouseWheel",
        function(
            _,
            delta
        )
            local base =
                delta > 0
                and "MOUSEWHEELUP"
                or "MOUSEWHEELDOWN"

            local key =
                ns.BuildCapturedKey(
                    base
                )

            if key then
                BindHoveredKey(
                    key
                )
            end
        end
    )

    overlay:Hide()

    bindOverlays[
        button
    ] =
        overlay

    return overlay
end

local function RefreshBindModeOverlays()
    for _, overlay in pairs(
        bindOverlays
    ) do
        overlay:Hide()
    end

    if not bindModeActive
        or not ns.Bars
    then
        return
    end

    for barID, bar in pairs(
        ns.Bars
    ) do
        local settings =
            GetBarSettings(
                barID
            )

        if settings
            and settings.enabled
        then
            local buttonCount =
                math.min(
                    settings.buttonCount
                        or 12,
                    #bar.buttons
                )

            for buttonID =
                1,
                buttonCount
            do
                local button =
                    bar.buttons[
                        buttonID
                    ]

                if button
                    and button:IsShown()
                then
                    local overlay =
                        CreateBindOverlay(
                            barID,
                            buttonID,
                            button
                        )

                    overlay:Show()
                end
            end
        end
    end
end

function ns.IsKeybindModeActive()
    return bindModeActive
end

function ns.SetKeybindMode(
    enabled
)
    enabled =
        enabled
        and true
        or false

    if enabled
        and InCombatLockdown()
    then
        print(
            "|cff7fd5ffMythInc Action Bars:|r Keybind Mode cannot be enabled during combat."
        )

        return false
    end

    bindModeActive =
        enabled

    SetHoveredOverlay(
        nil
    )

    if enabled then
        bindModeFrame:Show()

        keyboardListener:Show()

        keyboardListener:EnableKeyboard(
            true
        )

        keyboardListener:SetPropagateKeyboardInput(
            false
        )

        RefreshBindModeOverlays()

        print(
            "|cff7fd5ffMythInc Action Bars:|r Keybind Mode enabled. Hover a MIAB button and press a key."
        )
    else
        keyboardListener:SetPropagateKeyboardInput(
            true
        )

        keyboardListener:Hide()

        bindModeFrame:Hide()

        for _, overlay in pairs(
            bindOverlays
        ) do
            overlay:Hide()
        end

        print(
            "|cff7fd5ffMythInc Action Bars:|r Keybind Mode disabled."
        )
    end

    return true
end

function ns.ToggleKeybindMode()
    return ns.SetKeybindMode(
        not bindModeActive
    )
end

keyboardListener:SetScript(
    "OnKeyDown",
    function(
        _,
        key
    )
        if not bindModeActive then
            return
        end

        if key
            == "ESCAPE"
        then
            ns.SetKeybindMode(
                false
            )

            return
        end

        if not hoveredBindTarget then
            return
        end

        if key == "BACKSPACE"
            or key == "DELETE"
        then
            BindHoveredKey(
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
            BindHoveredKey(
                captured
            )
        end
    end
)

SLASH_MYTHINCACTIONBARSKEYBIND1 =
    "/kb"

SLASH_MYTHINCACTIONBARSKEYBIND2 =
    "/miabkb"

SlashCmdList.MYTHINCACTIONBARSKEYBIND =
    function()
        ns.ToggleKeybindMode()
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

eventFrame:RegisterEvent(
    "PLAYER_REGEN_DISABLED"
)

eventFrame:SetScript(
    "OnEvent",
    function(
        _,
        event
    )
        if event
            == "PLAYER_LOGIN"
        then
            ns.ImportBlizzardKeybinds()

            C_Timer.After(
                0,
                function()
                    ns.ApplyAllKeybinds()
                end
            )

            return
        end

        if event
            == "PLAYER_REGEN_DISABLED"
        then
            if bindModeActive then
                ns.SetKeybindMode(
                    false
                )
            end

            return
        end

        if event
            == "PLAYER_REGEN_ENABLED"
        then
            if pendingApply then
                ns.ApplyAllKeybinds()
            end
        end
    end
)