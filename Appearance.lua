local addonName, ns = ...

local VALID_KEYBIND_POSITIONS = {
    TOPRIGHT = true,
    TOPLEFT = true,
    BOTTOMRIGHT = true,
    BOTTOMLEFT = true,
}

local function EnsureAppearance(settings)
    settings.appearance = settings.appearance or {}
    local appearance = settings.appearance

    if appearance.iconInset ~= nil and appearance.iconZoom == nil then
        appearance.iconZoom = 0
    end
    appearance.iconInset = nil

    if appearance.iconZoom == nil then appearance.iconZoom = 0 end
    if appearance.showBorder == nil then appearance.showBorder = true end
    if appearance.emptyOpacity == nil then appearance.emptyOpacity = 0.85 end
    if appearance.showCooldown == nil then appearance.showCooldown = true end
    if appearance.showCooldownText == nil then appearance.showCooldownText = true end
    if appearance.showCount == nil then appearance.showCount = true end
    if appearance.countTextSize == nil then appearance.countTextSize = 12 end
    if appearance.showKeybind == nil then appearance.showKeybind = true end
    if appearance.keybindTextSize == nil then appearance.keybindTextSize = 12 end

    if not VALID_KEYBIND_POSITIONS[appearance.keybindPosition] then
        appearance.keybindPosition = "TOPRIGHT"
    end

    appearance.keybindColor = appearance.keybindColor or {}
    local color = appearance.keybindColor
    if color.r == nil then color.r = 1 end
    if color.g == nil then color.g = 1 end
    if color.b == nil then color.b = 1 end
    if color.a == nil then color.a = 1 end

    if appearance.desaturateUnusable == nil then
        appearance.desaturateUnusable = false
    end
    if appearance.rangeColoring == nil then appearance.rangeColoring = true end
    if appearance.usabilityColoring == nil then appearance.usabilityColoring = true end

    return appearance
end

local function ApplyIconZoom(button, appearance)
    if not button.icon then return end
    local zoom = math.max(0, math.min(30, tonumber(appearance.iconZoom) or 0))
    local crop = zoom / 200
    button.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
end

local function ApplyBorder(button, appearance)
    if button.Border then
        button.Border:SetShown(appearance.showBorder ~= false)
    end
end

local function ApplyBackground(button, appearance)
    if button.Background then
        button.Background:SetAlpha(tonumber(appearance.emptyOpacity) or 0.85)
    end
end

local function ApplyCooldown(button, appearance)
    if not button.cooldown then return end
    if button.cooldown.SetDrawSwipe then
        button.cooldown:SetDrawSwipe(appearance.showCooldown ~= false)
    end
    if button.cooldown.SetHideCountdownNumbers then
        button.cooldown:SetHideCountdownNumbers(
            appearance.showCooldownText == false
        )
    end
end

local function ApplyCountText(button, appearance)
    if not button.Count then return end
    button.Count:SetShown(appearance.showCount ~= false)
    local fontPath = ns.Media and ns.Media.font or STANDARD_TEXT_FONT
    button.Count:SetFont(
        fontPath, tonumber(appearance.countTextSize) or 12, "OUTLINE"
    )
end

local function AnchorHotKey(hotKey, position)
    hotKey:ClearAllPoints()
    local parent = hotKey:GetParent()

    if position == "TOPLEFT" then
        hotKey:SetPoint("TOPLEFT", parent, "TOPLEFT", 3, -3)
        hotKey:SetJustifyH("LEFT")
    elseif position == "BOTTOMRIGHT" then
        hotKey:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -3, 3)
        hotKey:SetJustifyH("RIGHT")
    elseif position == "BOTTOMLEFT" then
        hotKey:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 3, 3)
        hotKey:SetJustifyH("LEFT")
    else
        hotKey:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -3, -3)
        hotKey:SetJustifyH("RIGHT")
    end
end

local function ApplyKeybindText(button, appearance)
    local hotKey = button.HotKey
    if not hotKey then return end

    hotKey:SetDrawLayer("OVERLAY", 7)
    local fontPath = ns.Media and ns.Media.font or STANDARD_TEXT_FONT
    hotKey:SetFont(
        fontPath, tonumber(appearance.keybindTextSize) or 12, "OUTLINE"
    )

    local color = appearance.keybindColor
    hotKey:SetTextColor(
        color.r or 1, color.g or 1, color.b or 1, color.a or 1
    )
    AnchorHotKey(hotKey, appearance.keybindPosition)
    hotKey:SetShown(appearance.showKeybind ~= false)
end

function ns.ApplyButtonAppearance(button, settings)
    if not button or not settings then return end

    local appearance = EnsureAppearance(settings)
    ApplyIconZoom(button, appearance)
    ApplyBorder(button, appearance)
    ApplyBackground(button, appearance)
    ApplyCooldown(button, appearance)
    ApplyCountText(button, appearance)
    ApplyKeybindText(button, appearance)

    if button.RefreshVisualState then
        button.RefreshVisualState()
    end
end

function ns.ApplyBarAppearance(barID)
    if not ns.db or not ns.db.bars then return end

    local settings = ns.db.bars[barID]
    local bar = ns.Bars and ns.Bars[barID]
    if not settings or not bar then return end

    EnsureAppearance(settings)
    ns.RefreshBarFade(barID, true)

    for _, button in ipairs(bar.buttons) do
        ns.ApplyButtonAppearance(button, settings)
    end
end

function ns.GetBarAppearance(barID)
    local settings = ns.db and ns.db.bars and ns.db.bars[barID]
    if not settings then return nil end
    return EnsureAppearance(settings)
end

-- Secure visibility decides whether a bar is shown.
-- Fading changes opacity without changing its visibility driver.
local fadeStates = setmetatable({}, { __mode = "k" })
local ownedFadeFrames = setmetatable({}, { __mode = "k" })

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
}

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
    if not value or value ~= value then return fallback end
    return math.max(0, math.min(1, value))
end

function ns.GetBarFadeSettings(barID)
    local target = ns.SpecialConfigTargets and ns.SpecialConfigTargets[barID]
    local settings = target and target.GetSettings()
        or (ns.db and ns.db.bars and ns.db.bars[barID])
    if not settings then return end

    settings.visibility = settings.visibility or {}
    local visibility = settings.visibility

    visibility.opacity = ClampOpacity(visibility.opacity, 1)
    visibility.fadedOpacity = math.min(
        visibility.opacity,
        ClampOpacity(visibility.fadedOpacity, 0.2)
    )
    visibility.fadeOnMouseover = visibility.fadeOnMouseover == true
    visibility.showFullyInCombat = visibility.showFullyInCombat == true

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
        if _G[name] then frames[#frames + 1] = _G[name] end
    end
    return frames
end

local function IsUnlocked(barID)
    local target = ns.SpecialConfigTargets and ns.SpecialConfigTargets[barID]
    if target then return target.IsUnlocked() end
    return ns.IsBarUnlocked and ns.IsBarUnlocked(barID)
end

local function Hovered(frames)
    for _, frame in ipairs(frames) do
        if frame:IsShown() and frame:IsMouseOver() then
            return true
        end
    end
    return false
end

local function EditingBars()
    return (ns.IsKeybindModeActive and ns.IsKeybindModeActive())
        or DRAG_CURSOR_TYPES[GetCursorInfo()] == true
end

local function TargetOpacity(barID, frames, visibility, editing)
    if editing or IsUnlocked(barID) then
        return 1, true
    end

    if visibility.showFullyInCombat and InCombatLockdown() then
        return 1, true
    end

    if visibility.fadeOnMouseover and not Hovered(frames) then
        return visibility.fadedOpacity, false
    end

    return visibility.opacity, false
end

local function UpdateFade(
    barID, bar, frames, visibility, editing, elapsed, immediate
)
    local target, forceFull = TargetOpacity(
        barID, frames, visibility, editing
    )

    local state = fadeStates[bar]
    if not state then
        state = { alpha = bar:GetAlpha() }
        fadeStates[bar] = state
    end

    if immediate or forceFull then
        state.alpha = target
    else
        local step = elapsed / 0.15
        if state.alpha < target then
            state.alpha = math.min(target, state.alpha + step)
        elseif state.alpha > target then
            state.alpha = math.max(target, state.alpha - step)
        end
    end

    if bar:GetAlpha() ~= state.alpha then
        bar:SetAlpha(state.alpha)
    end
end

function ns.RefreshBarFade(barID, immediate)
    local visibility = ns.GetBarFadeSettings(barID)
    if not visibility then return end

    local target = ns.SpecialConfigTargets and ns.SpecialConfigTargets[barID]
    if target and not target.GetSettings().enabled then return end

    local frames = FadeFrames(barID)
    local editing = EditingBars()

    for _, bar in ipairs(frames) do
        if target and ownedFadeFrames[bar] == nil then
            ownedFadeFrames[bar] = bar:GetAlpha()
        end

        UpdateFade(
            barID, bar, frames, visibility,
            editing, 0, immediate ~= false
        )
    end
end

function ns.SetBarFadeOption(barID, option, value)
    local visibility = ns.GetBarFadeSettings(barID)
    if not visibility then return false, "missing" end

    if option == "opacity" or option == "fadedOpacity" then
        value = tonumber(value)
        if not value or value ~= value then return false, "invalid" end
        visibility[option] = ClampOpacity(value, 1)
    elseif option == "fadeOnMouseover" or option == "showFullyInCombat" then
        visibility[option] = value and true or false
    else
        return false, "invalid"
    end

    ns.GetBarFadeSettings(barID)
    ns.RefreshBarFade(barID, true)
    return true
end

local fadeWatcher = CreateFrame("Frame")
local fadeElapsed = 0

fadeWatcher:SetScript("OnUpdate", function(_, elapsed)
    fadeElapsed = fadeElapsed + elapsed
    if fadeElapsed < 0.05 then return end

    local step = fadeElapsed
    fadeElapsed = 0
    if not ns.db or not ns.db.bars then return end

    local editing = EditingBars()

    for barID, bar in pairs(ns.Bars or {}) do
        local settings = ns.db.bars[barID]
        if settings and settings.enabled and bar:IsShown() then
            local visibility = ns.GetBarFadeSettings(barID)
            UpdateFade(
                barID, bar, { bar }, visibility, editing, step, false
            )
        end
    end

    local active = {}

    for barID in pairs(SPECIAL_FADE_FRAMES) do
        local target = ns.SpecialConfigTargets and ns.SpecialConfigTargets[barID]
        local settings = target and target.GetSettings()

        if settings and settings.enabled then
            local frames = FadeFrames(barID)
            local visibility = ns.GetBarFadeSettings(barID)

            for _, bar in ipairs(frames) do
                active[bar] = true

                if ownedFadeFrames[bar] == nil then
                    ownedFadeFrames[bar] = bar:GetAlpha()
                end

                UpdateFade(
                    barID, bar, frames, visibility, editing, step, false
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