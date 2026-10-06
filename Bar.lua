local addonName, ns = ...

local BUTTON_COUNT = 12
local BUTTON_SIZE = 36
local BUTTON_SPACING = 4

local bar = CreateFrame("Frame", "MythIncActionBarsBar1", UIParent)

bar:SetSize(
    (BUTTON_SIZE * BUTTON_COUNT) + (BUTTON_SPACING * (BUTTON_COUNT - 1)),
    BUTTON_SIZE
)

bar:SetPoint("CENTER", UIParent, "CENTER", 0, -200)

bar.buttons = {}

for i = 1, BUTTON_COUNT do
    local button = ns.CreateActionButton(
        bar,
        "MythIncActionBarsBar1Button" .. i,
        i
    )

    if i == 1 then
        button:SetPoint("LEFT", bar, "LEFT", 0, 0)
    else
        button:SetPoint(
            "LEFT",
            bar.buttons[i - 1],
            "RIGHT",
            BUTTON_SPACING,
            0
        )
    end

    bar.buttons[i] = button
end

ns.Bar1 = bar