
local addonName, ns = ...

local definitions = {
    { key = "experienceBar", name = "Experience Bar", x = 0, y = -230, color = { 0.18, 0.58, 0.96 } },
    { key = "reputationBar", name = "Reputation Bar", x = 0, y = -255, color = { 0.25, 0.74, 0.48 } },
}

ns.defaults.statusBars = ns.defaults.statusBars or {}

for _, definition in ipairs(definitions) do
    ns.defaults.statusBars[definition.key] = {
        enabled = false,
        x = definition.x,
        y = definition.y,
        width = 360,
        height = 18,
        scale = 1,
        showText = true,
        visibility = {
            opacity = 1,
            fadedOpacity = 0.2,
            fadeOnMouseover = false,
            showFullyInCombat = false,
        },
    }
end

local states = {}
local pending = false
local Refresh
local blizzardTrackerAlpha
local blizzardTrackerSuppressed = false

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = Copy(item) end
    return result
end

local function Settings(definition)
    if not ns.db then return nil end
    ns.db.statusBars = ns.db.statusBars or {}
    local settings = ns.db.statusBars[definition.key]
    local defaults = ns.defaults.statusBars[definition.key]
    if type(settings) ~= "table" then
        settings = Copy(defaults)
        ns.db.statusBars[definition.key] = settings
    end
    for key, value in pairs(defaults) do
        if settings[key] == nil then settings[key] = Copy(value) end
    end
    return settings
end

local function Usable(value)
    if type(value) ~= "number" then return false end
    if issecretvalue and issecretvalue(value) then return false end
    return value == value
end

local function Number(value)
    if not Usable(value) then return "0" end
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(math.floor(value + 0.5)) end
    return tostring(math.floor(value + 0.5))
end

local function Progress(name, level, value, maximum, color, note, capped)
    if not Usable(value) or not Usable(maximum) or maximum <= 0 then return nil end
    value = math.max(0, math.min(maximum, value))
    return {
        name = name,
        level = level,
        value = value,
        maximum = maximum,
        color = color,
        note = note,
        capped = capped == true,
    }
end

local function ReadExperience()
    local level = UnitLevel("player")
    local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()
    if not Usable(maxLevel) or maxLevel <= 0 then
        maxLevel = GetMaxPlayerLevel and GetMaxPlayerLevel()
    end
    if Usable(level) and Usable(maxLevel) and level >= maxLevel then
        return nil
    end
    local current = UnitXP("player")
    local maximum = UnitXPMax("player")
    if not Usable(maximum) or maximum <= 0 then return nil end
    return Progress(
        "Experience",
        "Level " .. tostring(level),
        current,
        maximum,
        definitions[1].color
    )
end

local function ReadReputation()
    if not C_Reputation or not C_Reputation.GetWatchedFactionData then return nil end
    local faction = C_Reputation.GetWatchedFactionData()
    if not faction or not Usable(faction.factionID) or faction.factionID <= 0 then return nil end

    local factionID = faction.factionID
    local name = faction.name or "Reputation"
    local color = definitions[2].color

    if C_Reputation.IsAccountWideReputation and C_Reputation.IsAccountWideReputation(factionID) then
        name = name .. " (Warband)"
    end

    local paragon = C_Reputation.IsFactionParagonForCurrentPlayer
        and C_Reputation.IsFactionParagonForCurrentPlayer(factionID)
    if paragon and C_Reputation.GetFactionParagonInfo then
        local earned, threshold, _, rewardPending = C_Reputation.GetFactionParagonInfo(factionID)
        if Usable(earned) and Usable(threshold) and threshold > 0 then
            local note = rewardPending and "Paragon reward available" or nil
            return Progress(name, "Paragon", earned % threshold, threshold, color, note)
        end
    end

    if C_Reputation.IsMajorFaction and C_Reputation.IsMajorFaction(factionID)
        and C_MajorFactions and C_MajorFactions.GetMajorFactionData
    then
        local data = C_MajorFactions.GetMajorFactionData(factionID)
        if data then
            local level = data.renownLevel
            local earned = data.renownReputationEarned
            local threshold = data.renownLevelThreshold
            if Usable(level) and Usable(earned) and Usable(threshold) then
                if Usable(data.maxLevel) and level >= data.maxLevel then
                    return Progress(name, "Renown " .. level .. " (Max)", 1, 1, color, nil, true)
                end
                return Progress(name, "Renown " .. level, earned, math.max(1, threshold), color)
            end
        end
    end

    if C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
        local friendship = C_GossipInfo.GetFriendshipReputation(factionID)
        if friendship and Usable(friendship.friendshipFactionID)
            and friendship.friendshipFactionID > 0
        then
            local minimum = friendship.reactionThreshold
            local maximum = friendship.nextThreshold
            local standing = friendship.standing
            local level = friendship.reaction or "Friendship"
            if Usable(minimum) and Usable(maximum) and Usable(standing)
                and maximum > minimum
            then
                return Progress(name, level, standing - minimum, maximum - minimum, color)
            end
            if Usable(standing) and (maximum == nil or maximum == 0) then
                return Progress(name, level .. " (Max)", 1, 1, color, nil, true)
            end
            return nil
        end
    end

    local function NormalData(data)
        if not data then return nil end
        local current = data.currentStanding
        local minimum = data.currentReactionThreshold
        local maximum = data.nextReactionThreshold
        local reaction = data.reaction
        local level = Usable(reaction)
            and (_G["FACTION_STANDING_LABEL" .. reaction] or "Reputation")
            or "Reputation"

        if Usable(current) and Usable(minimum) and Usable(maximum)
            and maximum > minimum
        then
            return Progress(name, level, current - minimum, maximum - minimum, color)
        end
        if Usable(reaction) and reaction >= 8 then
            return Progress(name, level .. " (Max)", 1, 1, color, nil, true)
        end
        return nil
    end

    local data = NormalData(faction)
    if data then return data end
    if C_Reputation.GetFactionDataByID then
        return NormalData(C_Reputation.GetFactionDataByID(factionID))
    end
    return nil
end

local function ReadData(state)
    local reader = state.definition.key == "experienceBar"
        and ReadExperience or ReadReputation
    local success, result = pcall(reader)
    if success then
        state.data = result
        return result
    end
    return state.data
end

local function SyncDrag(state)
    if not state.dragging or InCombatLockdown() then return end
    local x, y = state.mover:GetCenter()
    local centerX, centerY = UIParent:GetCenter()
    if not x or not y or not centerX or not centerY then return end
    local settings = Settings(state.definition)
    if not settings then return end
    local offsetX = math.floor(x - centerX + 0.5)
    local offsetY = math.floor(y - centerY + 0.5)
    if settings.x == offsetX and settings.y == offsetY then return end
    settings.x, settings.y = offsetX, offsetY
    state.bar:ClearAllPoints()
    state.bar:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)
end

local function CreateState(definition)
    local bar = CreateFrame(
        "StatusBar", "MythIncActionBars" .. definition.key,
        UIParent, "BackdropTemplate"
    )
    bar:SetStatusBarTexture(ns.Media.texture or "Interface\\Buttons\\WHITE8x8")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetStatusBarColor(unpack(definition.color))
    bar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bar:SetBackdropColor(0.06, 0.08, 0.11, 0.95)
    bar:SetBackdropBorderColor(0.20, 0.34, 0.38, 1)
    bar:EnableMouse(true)
    bar:Hide()

    local text = bar:CreateFontString(nil, "OVERLAY")
    text:SetFont(ns.Media.font, 10, "OUTLINE")
    text:SetTextColor(unpack(ns.Media.colors.text))
    text:SetPoint("LEFT", bar, "LEFT", 6, 0)
    text:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
    text:SetJustifyH("CENTER")
    text:SetWordWrap(false)
    bar.text = text

    local state = { bar = bar, definition = definition, unlocked = false }
    local mover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    mover:SetFrameStrata("DIALOG")
    mover:SetFrameLevel(200)
    mover:SetMovable(true)
    mover:SetClampedToScreen(true)
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
    title:SetText(definition.name)

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

    bar:SetScript("OnEnter", function()
        state.hovered = true
        if not state.data then return end
        GameTooltip:SetOwner(bar, "ANCHOR_TOP")
        GameTooltip:AddLine(state.data.name, 1, 1, 1)
        GameTooltip:AddLine(state.data.level or "", 0.65, 0.85, 0.9)
        GameTooltip:AddLine(
            Number(state.data.value) .. " / " .. Number(state.data.maximum)
                .. " (" .. string.format("%.1f%%", state.data.value / state.data.maximum * 100) .. ")",
            1, 1, 1
        )
        if state.data.note then GameTooltip:AddLine(state.data.note, 0.2, 0.9, 0.3) end
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", function()
        state.hovered = false
        GameTooltip:Hide()
    end)

    state.mover = mover
    states[definition.key] = state
    return state
end

local function UpdateData(state)
    local settings = Settings(state.definition)
    if not settings then return end
    local data = ReadData(state)
    local bar = state.bar
    if not data then
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        bar.text:SetText(
            state.definition.key == "experienceBar"
                and "Experience (Max Level)" or "No watched reputation"
        )
        bar.text:SetShown(state.unlocked)
        bar:SetShown(settings.enabled and state.unlocked)
        return
    end

    bar:SetMinMaxValues(0, data.maximum)
    bar:SetValue(data.value)
    bar:SetStatusBarColor(unpack(data.color))
    local percent = data.value / data.maximum * 100
    local label = data.name .. " - " .. (data.level or "")
        .. "  " .. Number(data.value) .. "/" .. Number(data.maximum)
        .. " (" .. string.format("%.0f%%", percent) .. ")"
    bar.text:SetText(label)
    bar.text:SetShown(settings.showText or state.unlocked or state.hovered)
    bar:SetShown(settings.enabled and (state.unlocked or not data.capped))
end

local function SuppressBlizzardTracker()
    local manager = StatusTrackingBarManager
    if not manager or not ns.db then return end
    local experience = Settings(definitions[1])
    local reputation = Settings(definitions[2])
    local experienceData = states.experienceBar and states.experienceBar.data
    local reputationData = states.reputationBar and states.reputationBar.data
    local shouldSuppress = (experience and experience.enabled and experienceData)
        or (reputation and reputation.enabled and reputationData and not reputationData.capped)

    if shouldSuppress then
        if not blizzardTrackerSuppressed then
            blizzardTrackerAlpha = manager:GetAlpha()
            blizzardTrackerSuppressed = true
        end
        if manager:GetAlpha() ~= 0 then manager:SetAlpha(0) end
    elseif blizzardTrackerSuppressed then
        manager:SetAlpha(blizzardTrackerAlpha or 1)
        blizzardTrackerAlpha = nil
        blizzardTrackerSuppressed = false
    end
end

local function Apply(state)
    local settings = Settings(state.definition)
    if not settings then return end
    if InCombatLockdown() then pending = true; return end
    local bar = state.bar
    local scale = math.max(0.5, math.min(2, tonumber(settings.scale) or 1))
    local width = math.max(120, math.min(800, tonumber(settings.width) or 360))
    local height = math.max(8, math.min(40, tonumber(settings.height) or 18))
    bar:SetSize(width, height)
    bar:SetScale(scale)
    bar:ClearAllPoints()
    bar:SetPoint(
        "CENTER", UIParent, "CENTER",
        tonumber(settings.x) or 0, tonumber(settings.y) or 0
    )
    local mover = state.mover
    mover:SetSize(width * scale, math.max(24, height * scale))
    if not state.dragging then
        mover:ClearAllPoints()
        mover:SetPoint("CENTER", bar, "CENTER")
    end
    if not settings.enabled then state.unlocked = false end
    mover:SetShown(settings.enabled and state.unlocked)
    UpdateData(state)
end

Refresh = function()
    if InCombatLockdown() then pending = true; return end
    pending = false
    if not ns.db then return end
    for _, definition in ipairs(definitions) do
        Apply(states[definition.key])
    end
    SuppressBlizzardTracker()
end

ns.RefreshStatusBars = Refresh

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
        shortName = current.name,
        statusBar = true,
        bindable = false,
        visibility = true,
        defaults = ns.defaults.statusBars[current.key],
        GetSettings = function() return Settings(current) end,
        Refresh = Refresh,
        IsUnlocked = function() return state.unlocked end,
        SetUnlocked = function(enabled) SetUnlocked(state, enabled) end,
        Count = function() return 0 end,
        Bind = function() return false, "unsupported" end,
    }
end

local fadeElapsed = 0
local eventFrame = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE",
    "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "UPDATE_FACTION",
    "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "UPDATE_EXPANSION_LEVEL",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
}) do
    eventFrame:RegisterEvent(event)
end

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        for _, state in pairs(states) do
            state.unlocked = false
            state.mover:Hide()
        end
        pending = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then Refresh() end
        for _, state in pairs(states) do UpdateData(state) end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        Refresh()
    else
        for _, state in pairs(states) do UpdateData(state) end
    end
    SuppressBlizzardTracker()
end)

eventFrame:SetScript("OnUpdate", function(_, elapsed)
    fadeElapsed = fadeElapsed + elapsed
    if fadeElapsed < 0.05 then return end
    local step = fadeElapsed
    fadeElapsed = 0
    if not ns.db then return end
    SuppressBlizzardTracker()
    for _, definition in ipairs(definitions) do
        local state = states[definition.key]
        local visibility = ns.GetBarFadeSettings and ns.GetBarFadeSettings(definition.key)
        if visibility then
            local target = visibility.opacity
            if state.unlocked or (visibility.showFullyInCombat and InCombatLockdown()) then
                target = 1
            elseif visibility.fadeOnMouseover and not state.bar:IsMouseOver() then
                target = visibility.fadedOpacity
            end
            local alpha = state.bar:GetAlpha()
            if alpha < target then
                alpha = math.min(target, alpha + step / 0.15)
            elseif alpha > target then
                alpha = math.max(target, alpha - step / 0.15)
            end
            state.bar:SetAlpha(alpha)
        end
    end
end)

if ns.RefreshAllBarsFromProfile then
    local previousRefresh = ns.RefreshAllBarsFromProfile
    ns.RefreshAllBarsFromProfile = function(...)
        local success, reason = previousRefresh(...)
        if success then
            for _, state in pairs(states) do state.unlocked = false end
            Refresh()
        end
        return success, reason
    end
end
