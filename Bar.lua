local addonName, ns = ...

local bar

local function GetBarSettings()
    return ns.db.bars.bar1
end

local function LayoutBar()
    if not bar then
        return
    end

    local settings = GetBarSettings()

    local buttonCount = settings.buttonCount
    local buttonSize = settings.buttonSize
    local spacing = settings.spacing
    local columns = math.max(1, math.min(settings.columns, buttonCount))

    local rows = math.ceil(buttonCount / columns)

    local width =
        (buttonSize * columns) +
        (spacing * (columns - 1))

    local height =
        (buttonSize * rows) +
        (spacing * (rows - 1))

    bar:SetSize(width, height)
    bar:SetScale(settings.scale)

    for i, button in ipairs(bar.buttons) do
        button:ClearAllPoints()
        button:SetSize(buttonSize, buttonSize)

        local index = i - 1
        local column = index % columns
        local row = math.floor(index / columns)

        button:SetPoint(
            "TOPLEFT",
            bar,
            "TOPLEFT",
            column * (buttonSize + spacing),
            -(row * (buttonSize + spacing))
        )

        if i <= buttonCount then
            button:Show()
        else
            button:Hide()
        end
    end
end

local function UpdatePosition()
    local settings = GetBarSettings()
    local position = settings.position

    bar:ClearAllPoints()

    bar:SetPoint(
        position.point,
        UIParent,
        position.relativePoint,
        position.x,
        position.y
    )
end

local function CreateBar()
    if bar then
        return
    end

    bar = CreateFrame(
        "Frame",
        "MythIncActionBarsBar1",
        UIParent
    )

    bar.buttons = {}

    for i = 1, 12 do
        bar.buttons[i] = ns.CreateActionButton(
            bar,
            "MythIncActionBarsBar1Button" .. i,
            i
        )
    end

    ns.Bar1 = bar

    LayoutBar()
    UpdatePosition()
end

function ns.UpdateBar1()
    if not bar then
        return
    end

    LayoutBar()
    UpdatePosition()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function()
    CreateBar()
end)