
local addonName, ns = ...

local TEXT_POSITIONS = {
    TOPLEFT = true,
    TOP = true,
    TOPRIGHT = true,
    LEFT = true,
    CENTER = true,
    RIGHT = true,
    BOTTOMLEFT = true,
    BOTTOM = true,
    BOTTOMRIGHT = true,
}

local VALID_FLYOUT_DIRECTIONS = {
    UP = true,
    DOWN = true,
    LEFT = true,
    RIGHT = true,
}

local pendingFlyoutButtons =
    setmetatable({}, { __mode = "k" })

local TEXT_DEFAULTS = {
    count = { size = 12, position = "BOTTOMRIGHT" },
    cooldown = { size = 16, position = "CENTER" },
    recharge = { size = 12, position = "TOPLEFT" },
    macro = { size = 10, position = "BOTTOM" },
    keybind = { size = 12, position = "TOPRIGHT" },
}

local function Number(value, fallback)
    value = tonumber(value)

    if not value or value ~= value then
        return fallback
    end

    return value
end

local function EnsureAppearance(settings)
    settings.appearance = settings.appearance or {}
    local appearance = settings.appearance

    if appearance.iconInset ~= nil
        and appearance.iconZoom == nil
    then
        appearance.iconZoom = 0
    end

    appearance.iconInset = nil

    local defaults = {
        iconZoom = 0,
        showBorder = true,
        emptyOpacity = 0.85,

        showEmptyButtons = true,
        showEmptyWhileUnlocked = true,

        showCooldown = true,
        showCooldownText = true,
        showRecharge = true,
        showRechargeText = false,
        showCount = true,
        showMacroName = true,
        showKeybind = true,
        desaturateUnusable = false,
        rangeColoring = true,
        usabilityColoring = true,
        procStyle = "ANIMATED",
        procOpacity = 1,
    }

    for key, value in pairs(defaults) do
        if appearance[key] == nil then
            appearance[key] = value
        end
    end

    for prefix, definition in pairs(TEXT_DEFAULTS) do
        local positionKey = prefix .. "Position"
        local sizeKey = prefix .. "TextSize"
        local colorKey = prefix .. "Color"

        if not TEXT_POSITIONS[appearance[positionKey]] then
            appearance[positionKey] = definition.position
        end

        if appearance[sizeKey] == nil then
            appearance[sizeKey] = definition.size
        end

        appearance[prefix .. "OffsetX"] =
            Number(appearance[prefix .. "OffsetX"], 0)

        appearance[prefix .. "OffsetY"] =
            Number(appearance[prefix .. "OffsetY"], 0)

        appearance[colorKey] = appearance[colorKey] or {}

        local color = appearance[colorKey]

        if color.r == nil then color.r = 1 end
        if color.g == nil then color.g = 1 end
        if color.b == nil then color.b = 1 end
        if color.a == nil then color.a = 1 end
    end

    if not VALID_FLYOUT_DIRECTIONS[
        appearance.flyoutDirection
    ] then
        appearance.flyoutDirection = "UP"
    end

    return appearance
end

-- ============================================================
-- ICON AND TEXT APPEARANCE
-- ============================================================

local function ApplyIconZoom(button, appearance)
    if not button.icon then return end

    local zoom = math.max(
        0,
        math.min(30, Number(appearance.iconZoom, 0))
    )

    local crop = zoom / 200

    button.icon:SetTexCoord(
        crop,
        1 - crop,
        crop,
        1 - crop
    )
end

local function ApplyBorder(button, appearance)
    if button.Border then
        button.Border:SetShown(
            appearance.showBorder ~= false
        )
    end
end

local function ApplyBackground(button, appearance)
    if button.Background then
        button.Background:SetAlpha(
            Number(appearance.emptyOpacity, 0.85)
        )
    end
end

local function StyleText(
    text,
    button,
    appearance,
    prefix,
    size,
    position
)
    if not text then return end

    local font =
        ns.Media and ns.Media.font or STANDARD_TEXT_FONT

    text:SetFont(
        font,
        Number(appearance[prefix .. "TextSize"], size),
        "OUTLINE"
    )

    local point =
        appearance[prefix .. "Position"] or position

    if not TEXT_POSITIONS[point] then
        point = position
    end

    local inset = prefix == "keybind" and 3 or 2

    local left =
        point:find("LEFT", 1, true) ~= nil

    local right =
        point:find("RIGHT", 1, true) ~= nil

    local top =
        point:find("TOP", 1, true) ~= nil

    local bottom =
        point:find("BOTTOM", 1, true) ~= nil

    local x = left and inset or (right and -inset or 0)
    local y = top and -inset or (bottom and inset or 0)

    x = x + Number(
        appearance[prefix .. "OffsetX"],
        0
    )

    y = y + Number(
        appearance[prefix .. "OffsetY"],
        0
    )

    text:ClearAllPoints()
    text:SetPoint(point, button, point, x, y)

    text:SetJustifyH(
        left and "LEFT"
        or (right and "RIGHT" or "CENTER")
    )

    local color =
        appearance[prefix .. "Color"] or {}

    text:SetTextColor(
        color.r or 1,
        color.g or 1,
        color.b or 1,
        color.a or 1
    )
end

local function ApplyCooldown(button, appearance)
    if button.chargeCooldown then
        button.chargeCooldown:SetDrawEdge(
            appearance.showRecharge ~= false
        )

        button.chargeCooldown:SetHideCountdownNumbers(
            appearance.showRechargeText ~= true
        )

        StyleText(
            button.chargeCooldown:GetCountdownFontString(),
            button,
            appearance,
            "recharge",
            12,
            "TOPLEFT"
        )
    end

    if not button.cooldown then return end

    button.cooldown:SetDrawSwipe(
        appearance.showCooldown ~= false
    )

    button.cooldown:SetHideCountdownNumbers(
        appearance.showCooldownText == false
    )

    StyleText(
        button.cooldown:GetCountdownFontString(),
        button,
        appearance,
        "cooldown",
        16,
        "CENTER"
    )
end

local function ApplyCountText(button, appearance)
    if not button.Count then return end

    button.Count:SetShown(
        appearance.showCount ~= false
    )

    StyleText(
        button.Count,
        button,
        appearance,
        "count",
        12,
        "BOTTOMRIGHT"
    )
end

function ns.ApplyButtonFeedbackAppearance(
    button,
    appearance
)
    button.MIABFeedbackAppearance = appearance

    ApplyCooldown(button, appearance)
    ApplyCountText(button, appearance)

    if button.MacroName then
        button.MacroName:SetShown(
            appearance.showMacroName ~= false
        )

        StyleText(
            button.MacroName,
            button,
            appearance,
            "macro",
            10,
            "BOTTOM"
        )
    end

    local opacity = math.max(
        0,
        math.min(
            1,
            Number(appearance.procOpacity, 1)
        )
    )

    if button.SpellActivationAlert then
        button.SpellActivationAlert:SetAlpha(opacity)
    end

    if button.StaticProcGlow then
        button.StaticProcGlow:SetAlpha(opacity)
    end

    if button.UpdateProcGlow then
        button:UpdateProcGlow()
    end
end

local function ApplyKeybindText(button, appearance)
    local hotKey = button.HotKey

    if not hotKey then return end

    hotKey:SetDrawLayer("OVERLAY", 7)

    StyleText(
        hotKey,
        button,
        appearance,
        "keybind",
        12,
        "TOPRIGHT"
    )

    hotKey:SetShown(
        appearance.showKeybind ~= false
    )
end

-- ============================================================
-- FLYOUT DIRECTION
-- ============================================================

local function ApplyFlyoutDirection(button, appearance)
    local direction =
        appearance.flyoutDirection or "UP"

    if not VALID_FLYOUT_DIRECTIONS[direction] then
        direction = "UP"
    end

    if InCombatLockdown() then
        pendingFlyoutButtons[button] = direction
        return
    end

    pendingFlyoutButtons[button] = nil

    if button:GetAttribute("flyoutDirection")
        ~= direction
    then
        button:SetAttribute(
            "flyoutDirection",
            direction
        )
    end

    if button.SetPopupDirection then
        button:SetPopupDirection(direction)
    end

    if button.UpdateFlyout then
        button:UpdateFlyout()
    end
end

local flyoutEvents = CreateFrame("Frame")

flyoutEvents:RegisterEvent("PLAYER_REGEN_ENABLED")

flyoutEvents:SetScript("OnEvent", function()
    if InCombatLockdown() then return end

    for button, direction in pairs(
        pendingFlyoutButtons
    ) do
        pendingFlyoutButtons[button] = nil

        if button:GetAttribute("flyoutDirection")
            ~= direction
        then
            button:SetAttribute(
                "flyoutDirection",
                direction
            )
        end

        if button.SetPopupDirection then
            button:SetPopupDirection(direction)
        end

        if button.UpdateFlyout then
            button:UpdateFlyout()
        end
    end
end)

-- ============================================================
-- ACTION CURSOR DETECTION
-- ============================================================
--
-- Detect objects that can be placed on action bars.
-- Hidden empty buttons temporarily reappear while an action
-- is being carried, then return to their saved visibility.
--
-- Cursor state is cached to avoid repeated button scans.
-- ============================================================

local DRAG_CURSOR_TYPES = {
    spell = true,
    item = true,
    macro = true,
    action = true,
    mount = true,
    companion = true,
    petaction = true,
    battlepet = true,
    flyout = true,
    equipmentset = true,
    toy = true,
    outfit = true,
}

local cursorCarryingAction = false

local function IsActionOnCursor()
    return DRAG_CURSOR_TYPES[GetCursorInfo()] == true
end

-- ============================================================
-- EMPTY BUTTON VISIBILITY
-- ============================================================
--
-- Empty-button visibility is independent of bar fading.
--
-- Secure action assignments and bar visibility state drivers
-- are never modified.
--
-- Hidden empty slots normally have zero alpha and cannot
-- receive mouse input.
--
-- While an action is on the cursor, configured empty slots
-- are revealed as valid drop targets.
--
-- Protected mouse interaction is only changed out of combat.
-- ============================================================

local BLIZZARD_BASE_PAGES = {
    [1] = 1,
    [2] = 6,
    [3] = 5,
    [4] = 4,
    [5] = 3,
    [6] = 13,
    [7] = 14,
    [8] = 15,
}

local emptyButtonState =
    setmetatable({}, { __mode = "k" })

local function HasBlizzardAction(
    settings,
    barID,
    buttonID,
    button
)
    if not C_ActionBar
        or not C_ActionBar.HasAction
    then
        return true
    end

    local checked = {}

    local function HasPage(page)
        page = tonumber(page)

        if not page then
            return false
        end

        page = math.floor(page)

        if page < 1 or page > 15
            or checked[page]
        then
            return false
        end

        checked[page] = true

        local slot = (page - 1) * 12 + buttonID

        return C_ActionBar.HasAction(slot) == true
    end

    local basePage = BLIZZARD_BASE_PAGES[barID]

    if not basePage then
        return true
    end

    if HasPage(basePage) then
        return true
    end

    local pages = settings.actionPages or {}

    for _, modifier in ipairs({
        "shift",
        "ctrl",
        "alt",
    }) do
        local definition = pages[modifier]

        if definition
            and definition.enabled
            and HasPage(definition.page)
        then
            return true
        end
    end

    -- The primary bar can also use bonus action pages for
    -- stances, shapeshifting and related states.
    if barID == 1 then
        for page = 1, 10 do
            if HasPage(page) then
                return true
            end
        end
    end

    if button and button.GetCurrentActionSlot then
        local slot = button.GetCurrentActionSlot()

        if type(slot) == "number"
            and C_ActionBar.HasAction(slot) == true
        then
            return true
        end
    end

    return false
end

local function HasCustomAssignment(settings, buttonID)
    local assignments = settings.assignments

    return assignments
        and assignments[buttonID] ~= nil
        or false
end

local function ShouldShowEmptyButton(
    settings,
    barID,
    buttonID,
    button
)
    local appearance = EnsureAppearance(settings)

    if appearance.showEmptyButtons ~= false then
        return true
    end

    -- Carrying an action temporarily reveals available
    -- slots even when a bar is locked.
    if cursorCarryingAction then
        return true
    end

    if appearance.showEmptyWhileUnlocked ~= false
        and ns.IsBarUnlocked
        and ns.IsBarUnlocked(barID)
    then
        return true
    end

    if settings.source == "custom" then
        return HasCustomAssignment(
            settings,
            buttonID
        )
    end

    return HasBlizzardAction(
        settings,
        barID,
        buttonID,
        button
    )
end

function ns.RefreshEmptyButtonVisibility(barID)
    if InCombatLockdown() then
        return false
    end

    if not ns.db
        or not ns.db.bars
        or not ns.Bars
    then
        return false
    end

    local settings = ns.db.bars[barID]
    local bar = ns.Bars[barID]

    if not settings
        or not bar
        or not bar.buttons
    then
        return false
    end

    local buttonCount =
        tonumber(settings.buttonCount) or 12

    for buttonID, button in ipairs(bar.buttons) do
        local show = true

        if settings.enabled
            and buttonID <= buttonCount
        then
            show = ShouldShowEmptyButton(
                settings,
                barID,
                buttonID,
                button
            )
        end

        local previous = emptyButtonState[button]

        if previous ~= show then
            emptyButtonState[button] = show

            button:SetAlpha(show and 1 or 0)
            button:EnableMouse(show)
        end
    end

    return true
end

function ns.RefreshAllEmptyButtonVisibility()
    if InCombatLockdown() then
        return false
    end

    if not ns.Bars then
        return false
    end

    for barID in pairs(ns.Bars) do
        ns.RefreshEmptyButtonVisibility(barID)
    end

    return true
end

-- ============================================================
-- EVENT-DRIVEN EMPTY BUTTON REFRESHING
-- ============================================================
--
-- Multiple refresh requests within the same frame are
-- combined into a single update.
--
-- Requests during combat remain pending until combat ends.
-- ============================================================

local pendingRefreshAll = false
local pendingBarRefreshes = {}
local refreshScheduled = false

local function RunPendingEmptyRefreshes()
    refreshScheduled = false

    if InCombatLockdown() then
        return
    end

    if pendingRefreshAll then
        pendingRefreshAll = false
        pendingBarRefreshes = {}

        ns.RefreshAllEmptyButtonVisibility()
        return
    end

    local bars = pendingBarRefreshes
    pendingBarRefreshes = {}

    for barID in pairs(bars) do
        ns.RefreshEmptyButtonVisibility(barID)
    end
end

local function QueueEmptyButtonRefresh(barID)
    if type(barID) == "number" then
        if not pendingRefreshAll then
            pendingBarRefreshes[barID] = true
        end
    else
        pendingRefreshAll = true
        pendingBarRefreshes = {}
    end

    if refreshScheduled or InCombatLockdown() then
        return
    end

    refreshScheduled = true

    C_Timer.After(0, RunPendingEmptyRefreshes)
end

-- ============================================================
-- CURSOR TRANSITION TRACKING
-- ============================================================
--
-- When a player picks up an action, reveal hidden empty
-- slots so they can receive a drop.
--
-- When the action is dropped or cancelled, restore normal
-- empty-button visibility.
--
-- A full refresh only occurs when the cursor changes
-- between carrying and not carrying an action.
-- ============================================================

local function RefreshActionCursorState()
    if InCombatLockdown() then
        return
    end

    local carryingAction = IsActionOnCursor()

    if cursorCarryingAction == carryingAction then
        return
    end

    cursorCarryingAction = carryingAction

    QueueEmptyButtonRefresh()
end

-- ============================================================
-- CUSTOM BUTTON ASSIGNMENT NOTIFICATIONS
-- ============================================================
--
-- CustomActionButton.lua retains ownership of assignments.
-- Refresh after dragging, clicking or dropping actions.
-- ============================================================

local originalCreateCustomActionButton =
    ns.CreateCustomActionButton

if originalCreateCustomActionButton then
    ns.CreateCustomActionButton = function(...)
        local button =
            originalCreateCustomActionButton(...)

        if not button then
            return button
        end

        button:HookScript(
            "OnReceiveDrag",
            function(self)
                if not InCombatLockdown() then
                    QueueEmptyButtonRefresh(self.barID)
                end
            end
        )

        button:HookScript(
            "OnDragStart",
            function(self)
                if not InCombatLockdown() then
                    QueueEmptyButtonRefresh(self.barID)
                end
            end
        )

        button:HookScript(
            "PostClick",
            function(self)
                if not InCombatLockdown() then
                    QueueEmptyButtonRefresh(self.barID)
                end
            end
        )

        return button
    end
end

-- ============================================================
-- BAR LOCK / UNLOCK NOTIFICATIONS
-- ============================================================
--
-- Mover.lua loads after Appearance.lua.
-- Hook existing mover functions after loading.
-- ============================================================

local moverHooksInstalled = false

local function InstallMoverHooks()
    if moverHooksInstalled then
        return
    end

    if type(ns.SetBarUnlocked) ~= "function"
        or type(ns.SetAllBarsUnlocked) ~= "function"
    then
        return
    end

    moverHooksInstalled = true

    hooksecurefunc(
        ns,
        "SetBarUnlocked",
        function(barID)
            QueueEmptyButtonRefresh(barID)
        end
    )

    hooksecurefunc(
        ns,
        "SetAllBarsUnlocked",
        function()
            QueueEmptyButtonRefresh()
        end
    )
end

-- ============================================================
-- WOW EVENT LISTENERS
-- ============================================================
--
-- WoW Retail supports CURSOR_CHANGED.
--
-- CURSOR_UPDATE was removed from registration because it
-- is no longer a valid Retail event.
--
-- The existing lightweight cursor-state check also handles
-- cursor swaps that do not dispatch another event.
-- ============================================================

local emptyButtonEvents = CreateFrame("Frame")

for _, event in ipairs({
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_SPECIALIZATION_CHANGED",
    "ACTIONBAR_SLOT_CHANGED",
    "ACTIONBAR_PAGE_CHANGED",
    "UPDATE_MACROS",
    "CURSOR_CHANGED",
}) do
    emptyButtonEvents:RegisterEvent(event)
end

emptyButtonEvents:SetScript(
    "OnEvent",
    function(_, event, unit)
        if event == "PLAYER_LOGIN" then
            InstallMoverHooks()
            QueueEmptyButtonRefresh()
            return
        end

        if event == "PLAYER_SPECIALIZATION_CHANGED"
            and unit ~= "player"
        then
            return
        end

        if event == "PLAYER_REGEN_ENABLED" then
            cursorCarryingAction = IsActionOnCursor()

            QueueEmptyButtonRefresh()
            return
        end

        if event == "CURSOR_CHANGED" then
            if not InCombatLockdown() then
                -- Cursor state may settle after this event.
                -- Recheck on the next frame.
                C_Timer.After(
                    0,
                    RefreshActionCursorState
                )
            end

            return
        end

        if event == "PLAYER_ENTERING_WORLD" then
            InstallMoverHooks()

            cursorCarryingAction =
                IsActionOnCursor()
        end

        QueueEmptyButtonRefresh()
    end
)

-- ============================================================
-- STANDARD BUTTON APPEARANCE
-- ============================================================

function ns.ApplyButtonAppearance(button, settings)
    if not button or not settings then
        return
    end

    local appearance = EnsureAppearance(settings)

    button.MIABFeedbackAppearance = appearance

    ApplyIconZoom(button, appearance)
    ApplyBorder(button, appearance)
    ApplyBackground(button, appearance)

    ns.ApplyButtonFeedbackAppearance(
        button,
        appearance
    )

    ApplyKeybindText(button, appearance)
    ApplyFlyoutDirection(button, appearance)

    for _, child in ipairs(
        button.MIABFlyoutChildren or {}
    ) do
        ns.ApplyButtonFeedbackAppearance(
            child,
            appearance
        )
    end

    if button.RefreshVisualState then
        button.RefreshVisualState()
    end
end

function ns.ApplyBarAppearance(barID)
    if not ns.db or not ns.db.bars then
        return
    end

    local settings = ns.db.bars[barID]
    local bar = ns.Bars and ns.Bars[barID]

    if not settings or not bar then
        return
    end

    EnsureAppearance(settings)
    ns.RefreshBarFade(barID, true)

    for _, button in ipairs(bar.buttons) do
        ns.ApplyButtonAppearance(
            button,
            settings
        )
    end

    ns.RefreshEmptyButtonVisibility(barID)
end

function ns.GetBarAppearance(barID)
    local settings =
        ns.db and ns.db.bars
        and ns.db.bars[barID]

    if not settings then
        return nil
    end

    return EnsureAppearance(settings)
end

-- ============================================================
-- BAR FADING
-- ============================================================
--
-- Fading continues to use its existing animation loop.
--
-- Empty-button occupancy is never repeatedly scanned.
--
-- Cursor state is checked alongside fading, ensuring that
-- cursor swaps are recognized even without another event.
-- ============================================================

local fadeStates =
    setmetatable({}, { __mode = "k" })

local ownedFadeFrames =
    setmetatable({}, { __mode = "k" })

local SPECIAL_FADE_FRAMES = {
    petBar = {
        "MythIncActionBarsPetBar",
    },

    stanceBar = {
        "MythIncActionBarsStanceBar",
    },

    extraAction = {
        "ExtraActionBarFrame",
        "MythIncActionBarsextraActionAnchor",
    },

    zoneAbility = {
        "ZoneAbilityFrame",
        "MythIncActionBarszoneAbilityAnchor",
    },

    vehicleControls = {
        "MythIncActionBarsVehicleControl",
    },
}

local function ClampOpacity(value, fallback)
    value = tonumber(value)

    if not value or value ~= value then
        return fallback
    end

    return math.max(
        0,
        math.min(1, value)
    )
end

function ns.GetBarFadeSettings(barID)
    local target = ns.SpecialConfigTargets
        and ns.SpecialConfigTargets[barID]

    local settings = target and target.GetSettings()
        or (
            ns.db and ns.db.bars
            and ns.db.bars[barID]
        )

    if not settings then
        return
    end

    settings.visibility =
        settings.visibility or {}

    local visibility = settings.visibility

    visibility.opacity =
        ClampOpacity(visibility.opacity, 1)

    visibility.fadedOpacity = math.min(
        visibility.opacity,
        ClampOpacity(visibility.fadedOpacity, 0.2)
    )

    visibility.fadeOnMouseover =
        visibility.fadeOnMouseover == true

    visibility.showFullyInCombat =
        visibility.showFullyInCombat == true

    return visibility
end

local function FadeFrames(barID)
    local names = SPECIAL_FADE_FRAMES[barID]

    if not names then
        local bar = ns.Bars and ns.Bars[barID]

        return bar and { bar } or {}
    end

    local frames = {}

    for _, name in ipairs(names) do
        if _G[name] then
            frames[#frames + 1] = _G[name]
        end
    end

    return frames
end

local function IsUnlocked(barID)
    local target = ns.SpecialConfigTargets
        and ns.SpecialConfigTargets[barID]

    if target then
        return target.IsUnlocked()
    end

    return ns.IsBarUnlocked
        and ns.IsBarUnlocked(barID)
end

local function Hovered(frames)
    for _, frame in ipairs(frames) do
        if frame:IsShown()
            and frame:IsMouseOver()
        then
            return true
        end
    end

    return false
end

local function EditingBars()
    return (
        ns.IsKeybindModeActive
        and ns.IsKeybindModeActive()
    )
    or IsActionOnCursor()
end

local function TargetOpacity(
    barID,
    frames,
    visibility,
    editing
)
    if editing or IsUnlocked(barID) then
        return 1, true
    end

    if visibility.showFullyInCombat
        and InCombatLockdown()
    then
        return 1, true
    end

    if visibility.fadeOnMouseover
        and not Hovered(frames)
    then
        return visibility.fadedOpacity, false
    end

    return visibility.opacity, false
end

local function UpdateFade(
    barID,
    bar,
    frames,
    visibility,
    editing,
    elapsed,
    immediate
)
    local target, forceFull = TargetOpacity(
        barID,
        frames,
        visibility,
        editing
    )

    local state = fadeStates[bar]

    if not state then
        state = {
            alpha = bar:GetAlpha()
        }

        fadeStates[bar] = state
    end

    if immediate or forceFull then
        state.alpha = target
    else
        local step = elapsed / 0.15

        if state.alpha < target then
            state.alpha = math.min(
                target,
                state.alpha + step
            )
        elseif state.alpha > target then
            state.alpha = math.max(
                target,
                state.alpha - step
            )
        end
    end

    if bar:GetAlpha() ~= state.alpha then
        bar:SetAlpha(state.alpha)
    end
end

function ns.RefreshBarFade(barID, immediate)
    local visibility =
        ns.GetBarFadeSettings(barID)

    if not visibility then
        return
    end

    local target = ns.SpecialConfigTargets
        and ns.SpecialConfigTargets[barID]

    if target
        and not target.GetSettings().enabled
    then
        return
    end

    local frames = FadeFrames(barID)
    local editing = EditingBars()

    for _, bar in ipairs(frames) do
        if target
            and ownedFadeFrames[bar] == nil
        then
            ownedFadeFrames[bar] = bar:GetAlpha()
        end

        UpdateFade(
            barID,
            bar,
            frames,
            visibility,
            editing,
            0,
            immediate ~= false
        )
    end
end

function ns.SetBarFadeOption(barID, option, value)
    local visibility =
        ns.GetBarFadeSettings(barID)

    if not visibility then
        return false, "missing"
    end

    if option == "opacity"
        or option == "fadedOpacity"
    then
        value = tonumber(value)

        if not value or value ~= value then
            return false, "invalid"
        end

        visibility[option] =
            ClampOpacity(value, 1)

    elseif option == "fadeOnMouseover"
        or option == "showFullyInCombat"
    then
        visibility[option] =
            value and true or false
    else
        return false, "invalid"
    end

    ns.GetBarFadeSettings(barID)
    ns.RefreshBarFade(barID, true)

    return true
end

-- ============================================================
-- FADE WATCHER
-- ============================================================
--
-- Retains the existing fading behaviour.
--
-- Cursor state is checked every 0.05 seconds.
-- Only cursor-state transitions trigger a refresh of
-- empty-button visibility.
--
-- No repeated empty-action-slot scanning occurs.
-- ============================================================

local fadeWatcher = CreateFrame("Frame")
local fadeElapsed = 0

fadeWatcher:SetScript("OnUpdate", function(_, elapsed)
    fadeElapsed = fadeElapsed + elapsed

    if fadeElapsed < 0.05 then
        return
    end

    local step = fadeElapsed
    fadeElapsed = 0

    RefreshActionCursorState()

    if not ns.db or not ns.db.bars then
        return
    end

    local editing = EditingBars()

    for barID, bar in pairs(ns.Bars or {}) do
        local settings = ns.db.bars[barID]

        if settings
            and settings.enabled
            and bar:IsShown()
        then
            local visibility =
                ns.GetBarFadeSettings(barID)

            UpdateFade(
                barID,
                bar,
                { bar },
                visibility,
                editing,
                step,
                false
            )
        end
    end

    local active = {}

    for barID in pairs(SPECIAL_FADE_FRAMES) do
        local target = ns.SpecialConfigTargets
            and ns.SpecialConfigTargets[barID]

        local settings =
            target and target.GetSettings()

        if settings and settings.enabled then
            local frames = FadeFrames(barID)
            local visibility =
                ns.GetBarFadeSettings(barID)

            for _, bar in ipairs(frames) do
                active[bar] = true

                if ownedFadeFrames[bar] == nil then
                    ownedFadeFrames[bar] =
                        bar:GetAlpha()
                end

                UpdateFade(
                    barID,
                    bar,
                    frames,
                    visibility,
                    editing,
                    step,
                    false
                )
            end
        end
    end

    for bar, alpha in pairs(ownedFadeFrames) do
        if not active[bar] then
            bar:SetAlpha(alpha)
            ownedFadeFrames[bar] = nil
            fadeStates[bar] = nil
        end
    end
end)
