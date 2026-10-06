local addonName, ns = ...

local VALID_KEYBIND_POSITIONS = {
    TOPRIGHT = true,
    TOPLEFT = true,
    BOTTOMRIGHT = true,
    BOTTOMLEFT = true,
}

local function EnsureAppearance(
    settings
)
    settings.appearance =
        settings.appearance
        or {}

    local appearance =
        settings.appearance

    if appearance.iconInset
        ~= nil
        and appearance.iconZoom
            == nil
    then
        appearance.iconZoom = 0
    end

    appearance.iconInset =
        nil

    if appearance.iconZoom == nil then
        appearance.iconZoom = 0
    end

    if appearance.showBorder == nil then
        appearance.showBorder = true
    end

    if appearance.emptyOpacity == nil then
        appearance.emptyOpacity = 0.85
    end

    if appearance.showCooldown == nil then
        appearance.showCooldown = true
    end

    if appearance.showCooldownText == nil then
        appearance.showCooldownText = true
    end

    if appearance.showCount == nil then
        appearance.showCount = true
    end

    if appearance.countTextSize == nil then
        appearance.countTextSize = 12
    end

    if appearance.showKeybind == nil then
        appearance.showKeybind = true
    end

    if appearance.keybindTextSize == nil then
        appearance.keybindTextSize = 12
    end

    if not VALID_KEYBIND_POSITIONS[
        appearance.keybindPosition
    ] then
        appearance.keybindPosition =
            "TOPRIGHT"
    end

    appearance.keybindColor =
        appearance.keybindColor
        or {}

    if appearance.keybindColor.r == nil then
        appearance.keybindColor.r = 1
    end

    if appearance.keybindColor.g == nil then
        appearance.keybindColor.g = 1
    end

    if appearance.keybindColor.b == nil then
        appearance.keybindColor.b = 1
    end

    if appearance.keybindColor.a == nil then
        appearance.keybindColor.a = 1
    end

    if appearance.desaturateUnusable == nil then
        appearance.desaturateUnusable = false
    end

    if appearance.rangeColoring == nil then
        appearance.rangeColoring = true
    end

    if appearance.usabilityColoring == nil then
        appearance.usabilityColoring = true
    end

    return appearance
end

local function ApplyIconZoom(
    button,
    appearance
)
    if not button.icon then
        return
    end

    local zoom =
        tonumber(
            appearance.iconZoom
        )
        or 0

    zoom =
        math.max(
            0,
            math.min(
                30,
                zoom
            )
        )

    local crop =
        zoom / 200

    button.icon:SetTexCoord(
        crop,
        1 - crop,
        crop,
        1 - crop
    )
end

local function ApplyBorder(
    button,
    appearance
)
    if not button.Border then
        return
    end

    button.Border:SetShown(
        appearance.showBorder
            ~= false
    )
end

local function ApplyBackground(
    button,
    appearance
)
    if not button.Background then
        return
    end

    button.Background:SetAlpha(
        tonumber(
            appearance.emptyOpacity
        )
            or 0.85
    )
end

local function ApplyCooldown(
    button,
    appearance
)
    if not button.cooldown then
        return
    end

    if button.cooldown.SetDrawSwipe then
        button.cooldown:SetDrawSwipe(
            appearance.showCooldown
                ~= false
        )
    end

    if button.cooldown.SetHideCountdownNumbers then
        button.cooldown:SetHideCountdownNumbers(
            appearance.showCooldownText
                == false
        )
    end
end

local function ApplyCountText(
    button,
    appearance
)
    if not button.Count then
        return
    end

    button.Count:SetShown(
        appearance.showCount
            ~= false
    )

    local fontPath =
        ns.Media
        and ns.Media.font
        or STANDARD_TEXT_FONT

    button.Count:SetFont(
        fontPath,
        tonumber(
            appearance.countTextSize
        )
            or 12,
        "OUTLINE"
    )
end

local function AnchorHotKey(
    hotKey,
    position
)
    hotKey:ClearAllPoints()

    if position
        == "TOPLEFT"
    then
        hotKey:SetPoint(
            "TOPLEFT",
            hotKey:GetParent(),
            "TOPLEFT",
            3,
            -3
        )

        hotKey:SetJustifyH(
            "LEFT"
        )

    elseif position
        == "BOTTOMRIGHT"
    then
        hotKey:SetPoint(
            "BOTTOMRIGHT",
            hotKey:GetParent(),
            "BOTTOMRIGHT",
            -3,
            3
        )

        hotKey:SetJustifyH(
            "RIGHT"
        )

    elseif position
        == "BOTTOMLEFT"
    then
        hotKey:SetPoint(
            "BOTTOMLEFT",
            hotKey:GetParent(),
            "BOTTOMLEFT",
            3,
            3
        )

        hotKey:SetJustifyH(
            "LEFT"
        )

    else
        hotKey:SetPoint(
            "TOPRIGHT",
            hotKey:GetParent(),
            "TOPRIGHT",
            -3,
            -3
        )

        hotKey:SetJustifyH(
            "RIGHT"
        )
    end
end

local function ApplyKeybindText(
    button,
    appearance
)
    local hotKey =
        button.HotKey

    if not hotKey then
        return
    end

    hotKey:SetDrawLayer(
        "OVERLAY",
        7
    )

    local fontPath =
        ns.Media
        and ns.Media.font
        or STANDARD_TEXT_FONT

    hotKey:SetFont(
        fontPath,
        tonumber(
            appearance.keybindTextSize
        )
            or 12,
        "OUTLINE"
    )

    local color =
        appearance.keybindColor

    hotKey:SetTextColor(
        color.r or 1,
        color.g or 1,
        color.b or 1,
        color.a or 1
    )

    AnchorHotKey(
        hotKey,
        appearance.keybindPosition
    )

    hotKey:SetShown(
        appearance.showKeybind
            ~= false
    )
end

function ns.ApplyButtonAppearance(
    button,
    settings
)
    if not button
        or not settings
    then
        return
    end

    local appearance =
        EnsureAppearance(
            settings
        )

    ApplyIconZoom(
        button,
        appearance
    )

    ApplyBorder(
        button,
        appearance
    )

    ApplyBackground(
        button,
        appearance
    )

    ApplyCooldown(
        button,
        appearance
    )

    ApplyCountText(
        button,
        appearance
    )

    ApplyKeybindText(
        button,
        appearance
    )

    if button.RefreshVisualState then
        button.RefreshVisualState()
    end
end

function ns.ApplyBarAppearance(
    barID
)
    if not ns.db
        or not ns.db.bars
    then
        return
    end

    local settings =
        ns.db.bars[
            barID
        ]

    local bar =
        ns.Bars
        and ns.Bars[
            barID
        ]

    if not settings
        or not bar
    then
        return
    end

    EnsureAppearance(
        settings
    )

    for _, button in ipairs(
        bar.buttons
    ) do
        ns.ApplyButtonAppearance(
            button,
            settings
        )
    end
end

function ns.GetBarAppearance(
    barID
)
    local settings =
        ns.db
        and ns.db.bars
        and ns.db.bars[
            barID
        ]

    if not settings then
        return nil
    end

    return EnsureAppearance(
        settings
    )
end