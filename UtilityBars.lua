
local addonName, ns = ...

local definitions = {
    { key = "microMenu", name = "Micro Menu", frame = "MicroMenuContainer", x = 360, y = -310 },
    { key = "bagBar", name = "Bag Bar", frame = "BagsBar", x = 530, y = -310 },
}

ns.defaults.utilityBars = ns.defaults.utilityBars or {}

for _, definition in ipairs(definitions) do
    ns.defaults.utilityBars[definition.key] = {
        enabled = true,
        x = definition.x,
        y = definition.y,
        scale = 1,
        visibility = {
            opacity = 1,
            fadedOpacity = 0.2,
            fadeOnMouseover = false,
            showFullyInCombat = false,
        },
    }
end

local states = {}
local queued = false
local pending = false
local Refresh

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do
        result[key] = Copy(item)
    end
    return result
end

local function Settings(definition)
    if not ns.db then return nil end
    ns.db.utilityBars = ns.db.utilityBars or {}
    local settings = ns.db.utilityBars[definition.key]
    local defaults = ns.defaults.utilityBars[definition.key]

    if type(settings) ~= "table" then
        settings = Copy(defaults)
        ns.db.utilityBars[definition.key] = settings
    end

    for key, value in pairs(defaults) do
        if settings[key] == nil then
            settings[key] = Copy(value)
        end
    end

    return settings
end

local function QueueRefresh()
    if InCombatLockdown() then
        pending = true
        return
    end
    if queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        Refresh()
    end)
end

local function MeasureButtons(state)
    local native = state.native
    if not native then return nil end

    local left, right, top, bottom
    local inspected = 0

    local function Inspect(frame, depth)
        if inspected >= 160 or depth > 5 or not frame:IsShown() then
            return
        end

        inspected = inspected + 1
        local objectType = frame:GetObjectType()

        if objectType == "Button" or objectType == "CheckButton" then
            local width, height = frame:GetSize()
            local l, r = frame:GetLeft(), frame:GetRight()
            local t, b = frame:GetTop(), frame:GetBottom()

            if width and height and width >= 8 and height >= 8
                and width <= 120 and height <= 120
                and l and r and t and b
            then
                local scale = frame:GetEffectiveScale()
                l, r, t, b = l * scale, r * scale, t * scale, b * scale
                left = left and math.min(left, l) or l
                right = right and math.max(right, r) or r
                top = top and math.max(top, t) or t
                bottom = bottom and math.min(bottom, b) or b
                return
            end
        end

        if frame.GetChildren then
            for _, child in ipairs({ frame:GetChildren() }) do
                Inspect(child, depth + 1)
            end
        end
    end

    Inspect(native, 0)

    if not left or not right or not top or not bottom then
        return nil
    end

    local anchorX, anchorY = state.anchor:GetCenter()
    if not anchorX or not anchorY then return nil end

    local parentScale = UIParent:GetEffectiveScale()
    local anchorScale = state.anchor:GetEffectiveScale()
    local centerX = (left + right) / 2
    local centerY = (top + bottom) / 2

    return
        math.max(24, (right - left) / parentScale + 8),
        math.max(24, (top - bottom) / parentScale + 8),
        (centerX - anchorX * anchorScale) / parentScale,
        (centerY - anchorY * anchorScale) / parentScale
end

local function SyncDrag(state)
    if not state.dragging or InCombatLockdown() then return end

    local x, y = state.mover:GetCenter()
    local centerX, centerY = UIParent:GetCenter()
    if not x or not y or not centerX or not centerY then return end

    local settings = Settings(state.definition)
    if not settings then return end

    local offsetX = math.floor(x - centerX - (state.visualOffsetX or 0) + 0.5)
    local offsetY = math.floor(y - centerY - (state.visualOffsetY or 0) + 0.5)
    if settings.x == offsetX and settings.y == offsetY then return end

    settings.x = offsetX
    settings.y = offsetY
    state.anchor:ClearAllPoints()
    state.anchor:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)
end

local function MakeMover(state)
    local mover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    mover:SetFrameStrata("DIALOG")
    mover:SetFrameLevel(200)
    mover:SetClampedToScreen(true)
    mover:SetMovable(true)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    mover:SetBackdropColor(0.04, 0.55, 0.58, 0.25)
    mover:SetBackdropBorderColor(0.20, 0.85, 0.88, 1)

    local title = mover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("CENTER")
    title:SetText(state.definition.name)

    mover:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        local x, y = self:GetCenter()
        local centerX, centerY = UIParent:GetCenter()
        if not x or not y or not centerX or not centerY then return end
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", x - centerX, y - centerY)
        state.dragging = true
        self:StartMoving()
    end)

    local function StopDrag(self)
        if not state.dragging then return end
        self:StopMovingOrSizing()
        if not InCombatLockdown() then SyncDrag(state) end
        state.dragging = false
        if not InCombatLockdown() then
            Refresh()
            if ns.RefreshConfig then ns.RefreshConfig() end
        else
            pending = true
        end
    end

    mover:SetScript("OnDragStop", StopDrag)
    mover:HookScript("OnHide", StopDrag)
    mover:SetScript("OnUpdate", function()
        if state.dragging then SyncDrag(state) end
    end)
    mover:Hide()
    return mover
end

local function CreateState(definition)
    local state = { definition = definition, unlocked = false }
    local anchor = CreateFrame(
        "Frame", "MythIncActionBars" .. definition.key .. "Anchor",
        UIParent, "SecureHandlerStateTemplate"
    )
    anchor:SetSize(60, 40)
    state.anchor = anchor
    state.mover = MakeMover(state)
    states[definition.key] = state
    return state
end

local function OwnNativeFrame(state)
    if state.native then return true end
    local native = _G[state.definition.frame]
    if not native then return false end

    state.native = native
    state.original = {
        parent = native:GetParent(),
        scale = native:GetScale(),
        ignoreInLayout = native.ignoreInLayout,
        points = {},
    }

    for index = 1, native:GetNumPoints() do
        state.original.points[index] = { native:GetPoint(index) }
    end

    native:SetParent(state.anchor)
    native.ignoreInLayout = true
    native:ClearAllPoints()
    native:SetScale(1)
    native:SetPoint("CENTER", state.anchor, "CENTER")

    if native.Layout then
        hooksecurefunc(native, "Layout", QueueRefresh)
    end

    return true
end

local function PositionNative(state)
    local native = state.native
    if not native then return end

    if native:GetParent() ~= state.anchor then
        native:SetParent(state.anchor)
    end

    local point, relative = native:GetPoint(1)
    if native:GetNumPoints() ~= 1
        or point ~= "CENTER"
        or relative ~= state.anchor
        or native:GetScale() ~= 1
    then
        native:ClearAllPoints()
        native:SetScale(1)
        native:SetPoint("CENTER", state.anchor, "CENTER")
    end

    native.ignoreInLayout = true
end

local function PositionMover(state)
    local mover = state.mover
    local anchor = state.anchor
    local width, height, dx, dy = MeasureButtons(state)

    if not width then
        local native = state.native
        local scale = anchor:GetScale()
        width = math.max(40, (native and native:GetWidth() or 100) * scale)
        height = math.max(28, (native and native:GetHeight() or 32) * scale)
        dx, dy = 0, 0
    end

    state.visualOffsetX = dx
    state.visualOffsetY = dy
    mover:SetSize(width, height)

    if not state.dragging then
        mover:ClearAllPoints()
        mover:SetPoint("CENTER", anchor, "CENTER", dx, dy)
    end

    mover:SetShown(state.unlocked == true)
end

local function Apply(state)
    local settings = Settings(state.definition)
    if not settings or InCombatLockdown() then
        pending = true
        return
    end

    if not OwnNativeFrame(state) then
        state.mover:Hide()
        return
    end

    PositionNative(state)

    local anchor = state.anchor
    anchor:SetScale(math.max(0.5, math.min(2, tonumber(settings.scale) or 1)))
    anchor:SetSize(
        math.max(1, state.native:GetWidth()),
        math.max(1, state.native:GetHeight())
    )
    anchor:ClearAllPoints()
    anchor:SetPoint(
        "CENTER", UIParent, "CENTER",
        tonumber(settings.x) or 0, tonumber(settings.y) or 0
    )

    local driver = settings.enabled
        and "[petbattle] hide; show" or "hide"
    if state.driver ~= driver then
        state.driver = driver
        RegisterStateDriver(anchor, "visibility", driver)
    end

    if not settings.enabled then
        state.unlocked = false
    end

    PositionMover(state)
end

Refresh = function()
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    if not ns.db then return end
    for _, definition in ipairs(definitions) do
        Apply(states[definition.key])
    end
end

ns.RefreshUtilityBars = Refresh

local function SetUnlocked(state, enabled)
    if InCombatLockdown() then return end
    local settings = Settings(state.definition)
    state.unlocked = enabled and settings and settings.enabled or false
    if state.dragging then
        state.mover:StopMovingOrSizing()
        state.dragging = false
    end
    Apply(state)
end

for _, definition in ipairs(definitions) do
    local current = definition
    local state = CreateState(current)

    ns.SpecialConfigTargets[current.key] = {
        name = current.name,
        shortName = current.key == "microMenu" and "Micro Menu" or "Bag Bar",
        bindable = false,
        visibility = true,
        defaults = ns.defaults.utilityBars[current.key],
        GetSettings = function() return Settings(current) end,
        Refresh = Refresh,
        IsUnlocked = function() return state.unlocked end,
        SetUnlocked = function(enabled) SetUnlocked(state, enabled) end,
        Count = function() return 0 end,
        Bind = function() return false, "unsupported" end,
    }
end

local previousSetAllBarsUnlocked = ns.SetAllBarsUnlocked
if previousSetAllBarsUnlocked then
    ns.SetAllBarsUnlocked = function(unlocked)
        local success, reason = previousSetAllBarsUnlocked(unlocked)
        if not success then return success, reason end
        if InCombatLockdown() then return success, reason end
        for _, target in pairs(ns.SpecialConfigTargets or {}) do
            if target.GetSettings and target.SetUnlocked then
                local settings = target.GetSettings()
                target.SetUnlocked(unlocked == true and settings and settings.enabled == true)
            end
        end
        if ns.RefreshConfig then ns.RefreshConfig() end
        return success, reason
    end
end

local fadeElapsed = 0
local layoutElapsed = 0

local function UpdateFade(delta)
    fadeElapsed = fadeElapsed + delta
    if fadeElapsed < 0.05 then return end
    local step = fadeElapsed
    fadeElapsed = 0
    if not ns.db then return end

    for _, definition in ipairs(definitions) do
        local state = states[definition.key]
        local settings = Settings(definition)
        local visibility = ns.GetBarFadeSettings
            and ns.GetBarFadeSettings(definition.key)
        if visibility and settings and state.native then
            local target = visibility.opacity
            if state.unlocked or (visibility.showFullyInCombat and InCombatLockdown()) then
                target = 1
            elseif visibility.fadeOnMouseover
                and not state.anchor:IsMouseOver()
                and not state.native:IsMouseOver()
            then
                target = visibility.fadedOpacity
            end

            local current = state.alpha or state.anchor:GetAlpha()
            if current < target then
                current = math.min(target, current + step / 0.15)
            elseif current > target then
                current = math.max(target, current - step / 0.15)
            end
            state.alpha = current
            if state.anchor:GetAlpha() ~= current then
                state.anchor:SetAlpha(current)
            end
        end
    end
end

local events = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED", "ADDON_LOADED", "EDIT_MODE_LAYOUTS_UPDATED",
    "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "BAG_UPDATE_DELAYED",
}) do
    events:RegisterEvent(event)
end

events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        for _, state in pairs(states) do
            state.unlocked = false
            if state.dragging then
                state.mover:StopMovingOrSizing()
                state.dragging = false
            end
            state.mover:Hide()
        end
        pending = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then QueueRefresh() end
    else
        QueueRefresh()
    end
end)

events:SetScript("OnUpdate", function(_, delta)
    UpdateFade(delta)
    layoutElapsed = layoutElapsed + delta
    if layoutElapsed < 0.12 then return end
    layoutElapsed = 0
    if InCombatLockdown() then return end

    for _, state in pairs(states) do
        if state.native and state.native:GetParent() ~= state.anchor then
            QueueRefresh()
        elseif state.unlocked and not state.dragging then
            local width, height, dx, dy = MeasureButtons(state)
            if width and (
                math.abs(width - state.mover:GetWidth()) > 1
                or math.abs(height - state.mover:GetHeight()) > 1
                or math.abs(dx - (state.visualOffsetX or 0)) > 1
                or math.abs(dy - (state.visualOffsetY or 0)) > 1
            ) then
                PositionMover(state)
            end
        end
    end
end)

if ns.RefreshAllBarsFromProfile then
    local refreshProfile = ns.RefreshAllBarsFromProfile
    ns.RefreshAllBarsFromProfile = function(...)
        local success, reason = refreshProfile(...)
        if success then
            for _, state in pairs(states) do state.unlocked = false end
            Refresh()
        end
        return success, reason
    end
end
