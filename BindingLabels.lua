local addonName, ns = ...

local records = {}
local queued = false
local previewWasActive = false
local Refresh

local dragTypes = {
    action = true,
    spell = true,
    item = true,
    macro = true,
    mount = true,
    companion = true,
    petaction = true,
    battlepet = true,
    flyout = true,
}

local function PreviewActive()
    if ns.IsKeybindModeActive and ns.IsKeybindModeActive() then
        return true
    end

    local cursorType = GetCursorInfo()
    return cursorType and dragTypes[cursorType] == true or false
end

local function Restore(record)
    if record.savedAlpha ~= nil then
        record.original:SetAlpha(record.savedAlpha)
        record.savedAlpha = nil
    end

    record.host:Hide()
end

local function RestoreAll()
    for _, record in pairs(records) do
        Restore(record)
    end
end

local function RefreshCustomLabels()
    for barID, bar in pairs(ns.Bars or {}) do
        local settings = ns.db.bars and ns.db.bars[barID]

        if settings then
            for index, button in ipairs(bar.buttons or {}) do
                if button.UpdateAssignment and button.HotKey then
                    local assignment = (settings.assignments or {})[index]
                    local entry = (settings.keybinds or {})[index]

                    local key = assignment
                        and entry
                        and (entry.primary or entry.secondary)

                    button.HotKey:SetText(
                        key and ns.FormatKeybind(key) or ""
                    )
                end
            end
        end
    end
end

local function Style(record, button)
    if InCombatLockdown() then
        return
    end

    local original = record.original
    local label = record.label

    record.host:SetFrameLevel(button:GetFrameLevel() + 30)
    record.host:SetScale(button:GetScale())
    record.host:SetAllPoints(button)

    local font, size, flags = original:GetFont()

    label:SetFont(
        font or STANDARD_TEXT_FONT,
        size or 12,
        flags or "OUTLINE"
    )

    local r, g, b = original:GetTextColor()
    label:SetTextColor(r or 1, g or 1, b or 1, 1)
    label:SetJustifyH(original:GetJustifyH())
    label:SetJustifyV(original:GetJustifyV())
    label:ClearAllPoints()

    local count = original:GetNumPoints()

    if count == 0 then
        label:SetPoint("TOPRIGHT", button, "TOPRIGHT", -3, -3)
    else
        for index = 1, count do
            label:SetPoint(original:GetPoint(index))
        end
    end
end

local function ShowLabel(button, parent, key, wanted)
    local original = button and button.HotKey

    if not original then
        return
    end

    local record = records[button]

    if not wanted or not key or key == "" then
        if record then
            Restore(record)
        end

        return
    end

    if not record then
        -- Allocate and anchor outside combat.
        if InCombatLockdown() then
            return
        end

        local host = CreateFrame("Frame", nil, parent)
        host:EnableMouse(false)

        local label = host:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormalSmall"
        )

        label:SetDrawLayer("OVERLAY", 7)

        record = {
            original = original,
            host = host,
            label = label,
        }

        records[button] = record
    end

    if record.savedAlpha == nil then
        record.savedAlpha = original:GetAlpha()
    end

    original:SetAlpha(0)
    Style(record, button)

    record.label:SetText(ns.FormatKeybind(key))
    record.label:SetAlpha(1)
    record.label:Show()
    record.host:Show()
end

Refresh = function()
    if not ns.db then
        return
    end

    RefreshCustomLabels()

    if not PreviewActive() then
        previewWasActive = false
        RestoreAll()
        return
    end

    previewWasActive = true
    local visited = {}

    for barID, bar in pairs(ns.Bars or {}) do
        local settings = ns.db.bars and ns.db.bars[barID]

        if settings and settings.enabled then
            local count = math.min(
                settings.buttonCount or 12,
                #(bar.buttons or {})
            )

            for index = 1, count do
                local button = bar.buttons[index]
                local entry = (settings.keybinds or {})[index]
                local key = entry and (entry.primary or entry.secondary)

                if not key
                    and button.GetCurrentActionSlot
                    and ns.GetDisplayKeybindForActionSlot
                then
                    key = ns.GetDisplayKeybindForActionSlot(
                        button.GetCurrentActionSlot()
                    )
                end

                visited[button] = true
                ShowLabel(button, bar, key, bar:IsVisible())
            end
        end
    end

    for _, definition in ipairs({
        {
            key = "petBar",
            native = "PetActionBar",
            carrier = "MythIncActionBarsPetBar",
            command = "BONUSACTIONBUTTON",
            count = 10,
        },
        {
            key = "stanceBar",
            native = "StanceBar",
            carrier = "MythIncActionBarsStanceBar",
            command = "SHAPESHIFTBUTTON",
            count = math.min(10, GetNumShapeshiftForms() or 0),
        },
    }) do
        local settings = ns.db[definition.key]
        local native = _G[definition.native]
        local carrier = _G[definition.carrier]

        if settings and settings.enabled and native and carrier then
            for index, button in ipairs(native.actionButtons or {}) do
                if index <= definition.count
                    and button:GetParent() == carrier
                then
                    local key = (settings.keybinds or {})[index]
                        or GetBindingKey(definition.command .. index)

                    visited[button] = true

                    ShowLabel(
                        button,
                        carrier,
                        key,
                        carrier:IsVisible()
                    )
                end
            end
        end
    end

    for button, record in pairs(records) do
        if not visited[button] then
            Restore(record)
        end
    end
end

local function QueueRefresh()
    if queued then
        return
    end

    queued = true

    C_Timer.After(0, function()
        queued = false
        Refresh()
    end)
end

local setMode = ns.SetKeybindMode

ns.SetKeybindMode = function(...)
    local success, reason = setMode(...)
    Refresh()

    return success, reason
end

local refreshDisplay = ns.RefreshKeybindDisplay

ns.RefreshKeybindDisplay = function(...)
    local result = refreshDisplay(...)
    Refresh()

    return result
end

local applyAppearance = ns.ApplyButtonAppearance

ns.ApplyButtonAppearance = function(...)
    local result = applyAppearance(...)
    QueueRefresh()

    return result
end

local refreshProfile = ns.RefreshAllBarsFromProfile

ns.RefreshAllBarsFromProfile = function(...)
    RestoreAll()

    local success, reason = refreshProfile(...)
    Refresh()

    return success, reason
end

local events = CreateFrame("Frame")

for _, event in ipairs({
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "CURSOR_CHANGED",
    "UPDATE_BINDINGS",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED",
}) do
    events:RegisterEvent(event)
end

events:SetScript("OnEvent", QueueRefresh)

local elapsed = 0

events:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta

    if elapsed < 0.1 then
        return
    end

    elapsed = 0

    if PreviewActive() or previewWasActive then
        Refresh()
    end
end)