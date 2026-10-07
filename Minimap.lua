local addonName, ns = ...

local button
local isDragging = false

local DEFAULT_ANGLE = 225
local DEFAULT_OFFSET = 16

local MIN_OFFSET = 2
local MAX_OFFSET = 16

local function EnsureSettings()
    if not ns.global then
        return
    end

    if ns.global.minimapButtonAngle == nil then
        ns.global.minimapButtonAngle =
            DEFAULT_ANGLE
    end

    if ns.global.minimapButtonOffset == nil then
        ns.global.minimapButtonOffset =
            DEFAULT_OFFSET
    end

    if ns.global.showMinimapButton == nil then
        ns.global.showMinimapButton =
            true
    end
end

local function NormalizeAngle(
    angle
)
    angle =
        tonumber(
            angle
        )
        or DEFAULT_ANGLE

    while angle < 0 do
        angle =
            angle + 360
    end

    while angle >= 360 do
        angle =
            angle - 360
    end

    return angle
end

local function ClampOffset(
    offset
)
    offset =
        tonumber(
            offset
        )
        or DEFAULT_OFFSET

    return math.max(
        MIN_OFFSET,
        math.min(
            MAX_OFFSET,
            offset
        )
    )
end

local function GetMinimapRadius()
    if not Minimap then
        return 70
    end

    local width =
        Minimap:GetWidth()
        or 140

    local height =
        Minimap:GetHeight()
        or 140

    return math.min(
        width,
        height
    ) / 2
end

local function PositionButton(
    angle,
    offset
)
    if not button then
        return
    end

    EnsureSettings()

    angle =
        NormalizeAngle(
            angle
        )

    offset =
        ClampOffset(
            offset
        )

    if ns.global then
        ns.global.minimapButtonAngle =
            angle

        ns.global.minimapButtonOffset =
            offset
    end

    local radius =
        GetMinimapRadius()
        + offset

    local radians =
        math.rad(
            angle
        )

    local x =
        math.cos(
            radians
        )
        * radius

    local y =
        math.sin(
            radians
        )
        * radius

    button:ClearAllPoints()

    button:SetPoint(
        "CENTER",
        Minimap,
        "CENTER",
        x,
        y
    )
end

local function UpdatePositionFromCursor()
    if not button
        or not Minimap
    then
        return
    end

    local minimapX,
        minimapY =
        Minimap:GetCenter()

    if not minimapX
        or not minimapY
    then
        return
    end

    local cursorX,
        cursorY =
        GetCursorPosition()

    local scale =
        Minimap:GetEffectiveScale()

    if not scale
        or scale <= 0
    then
        scale = 1
    end

    cursorX =
        cursorX / scale

    cursorY =
        cursorY / scale

    local deltaX =
        cursorX
        - minimapX

    local deltaY =
        cursorY
        - minimapY

    local angle =
        math.deg(
            math.atan2(
                deltaY,
                deltaX
            )
        )

    local distance =
        math.sqrt(
            (deltaX * deltaX)
            + (deltaY * deltaY)
        )

    local offset =
        distance
        - GetMinimapRadius()

    PositionButton(
        angle,
        offset
    )
end

local function ShowTooltip(
    self
)
    GameTooltip:SetOwner(
        self,
        "ANCHOR_LEFT"
    )

    GameTooltip:AddLine(
        "MythInc Action Bars",
        0.5,
        0.84,
        1
    )

    GameTooltip:AddLine(
        " "
    )

    GameTooltip:AddDoubleLine(
        "Left Click",
        "Open Settings",
        1,
        1,
        1,
        0.75,
        0.75,
        0.75
    )

    GameTooltip:AddDoubleLine(
        "Right Click",
        "Keybind Mode",
        1,
        1,
        1,
        0.75,
        0.75,
        0.75
    )

    GameTooltip:AddDoubleLine(
        "Drag",
        "Move Button",
        1,
        1,
        1,
        0.75,
        0.75,
        0.75
    )

    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

local function SetNormalAppearance()
    if not button then
        return
    end

    button.Icon:SetVertexColor(
        1,
        1,
        1
    )

    button.Glow:SetAlpha(
        0
    )
end

local function SetHoverAppearance()
    if not button then
        return
    end

    button.Icon:SetVertexColor(
        1,
        1,
        1
    )

    button.Glow:SetAlpha(
        0.28
    )
end

local function SetPressedAppearance()
    if not button then
        return
    end

    button.Glow:SetAlpha(
        0
    )

    button.Icon:SetVertexColor(
        0.72,
        0.72,
        0.72
    )
end

local function ApplyVisibility()
    if not button then
        return
    end

    EnsureSettings()

    local shown =
        not ns.global
        or ns.global.showMinimapButton
            ~= false

    if not shown then
        button:SetScript(
            "OnUpdate",
            nil
        )

        isDragging =
            false

        HideTooltip()
    end

    button:SetShown(
        shown
    )
end

local function CreateMinimapButton()
    if button then
        ApplyVisibility()

        return button
    end

    EnsureSettings()

    button =
        CreateFrame(
            "Button",
            "MythIncActionBarsMinimapButton",
            Minimap
        )

    button:SetSize(
        34,
        34
    )

    button:SetFrameStrata(
        "MEDIUM"
    )

    button:SetFrameLevel(
        Minimap:GetFrameLevel()
        + 8
    )

    button:SetClampedToScreen(
        true
    )

    button:RegisterForClicks(
        "LeftButtonUp",
        "RightButtonUp"
    )

    button:RegisterForDrag(
        "LeftButton"
    )

    local icon =
        button:CreateTexture(
            nil,
            "ARTWORK"
        )

    icon:SetAllPoints()

    icon:SetTexture(
        "Interface\\AddOns\\MythIncActionBars\\Media\\Artwork\\MIUF_Icon_128.png"
    )

    icon:SetTexCoord(
        0,
        1,
        0,
        1
    )

    button.Icon =
        icon

    local glow =
        button:CreateTexture(
            nil,
            "OVERLAY"
        )

    glow:SetPoint(
        "CENTER",
        button,
        "CENTER",
        0,
        0
    )

    glow:SetSize(
        38,
        38
    )

    glow:SetTexture(
        "Interface\\AddOns\\MythIncActionBars\\Media\\Artwork\\MIUF_Icon_128.png"
    )

    glow:SetTexCoord(
        0,
        1,
        0,
        1
    )

    glow:SetBlendMode(
        "ADD"
    )

    glow:SetAlpha(
        0
    )

    button.Glow =
        glow

    button:SetScript(
        "OnMouseDown",
        function(
            _,
            mouseButton
        )
            if mouseButton == "LeftButton"
                or mouseButton == "RightButton"
            then
                SetPressedAppearance()
            end
        end
    )

    button:SetScript(
        "OnMouseUp",
        function(self)
            if self:IsMouseOver() then
                SetHoverAppearance()
            else
                SetNormalAppearance()
            end
        end
    )

    button:SetScript(
        "OnEnter",
        function(self)
            if isDragging then
                return
            end

            SetHoverAppearance()

            ShowTooltip(
                self
            )
        end
    )

    button:SetScript(
        "OnLeave",
        function()
            SetNormalAppearance()
            HideTooltip()
        end
    )

    button:SetScript(
        "OnClick",
        function(
            _,
            mouseButton
        )
            if isDragging then
                return
            end

            if mouseButton
                == "RightButton"
            then
                if ns.ToggleKeybindMode then
                    ns.ToggleKeybindMode()
                end

                return
            end

            if ns.ToggleConfig then
                ns.ToggleConfig()
            end
        end
    )

    button:SetScript(
        "OnDragStart",
        function()
            isDragging =
                true

            SetNormalAppearance()

            button:SetScript(
                "OnUpdate",
                UpdatePositionFromCursor
            )

            HideTooltip()
        end
    )

    button:SetScript(
        "OnDragStop",
        function()
            button:SetScript(
                "OnUpdate",
                nil
            )

            UpdatePositionFromCursor()

            SetNormalAppearance()

            C_Timer.After(
                0,
                function()
                    isDragging =
                        false
                end
            )
        end
    )

    PositionButton(
        ns.global
            and ns.global.minimapButtonAngle
            or DEFAULT_ANGLE,
        ns.global
            and ns.global.minimapButtonOffset
            or DEFAULT_OFFSET
    )

    ApplyVisibility()

    return button
end

function ns.GetMinimapButton()
    return button
end

function ns.IsMinimapButtonShown()
    EnsureSettings()

    return not ns.global
        or ns.global.showMinimapButton
            ~= false
end

function ns.SetMinimapButtonShown(
    shown
)
    EnsureSettings()

    shown =
        shown
        and true
        or false

    if ns.global then
        ns.global.showMinimapButton =
            shown
    end

    if shown
        and not button
    then
        CreateMinimapButton()
    end

    ApplyVisibility()

    return true
end

function ns.RefreshMinimapButton()
    EnsureSettings()

    CreateMinimapButton()

    PositionButton(
        ns.global
            and ns.global.minimapButtonAngle
            or DEFAULT_ANGLE,
        ns.global
            and ns.global.minimapButtonOffset
            or DEFAULT_OFFSET
    )

    ApplyVisibility()
end

function ns.ResetMinimapButtonPosition()
    EnsureSettings()

    if ns.global then
        ns.global.minimapButtonAngle =
            DEFAULT_ANGLE

        ns.global.minimapButtonOffset =
            DEFAULT_OFFSET
    end

    PositionButton(
        DEFAULT_ANGLE,
        DEFAULT_OFFSET
    )

    return true
end

function MythIncActionBars_OnAddonCompartmentClick(
    addonName,
    buttonName
)
    if buttonName == "RightButton" then
        if ns.ToggleKeybindMode then
            ns.ToggleKeybindMode()
        end

        return
    end

    if ns.ToggleConfig then
        ns.ToggleConfig()
    end
end

function MythIncActionBars_OnAddonCompartmentEnter(
    addonName,
    menuButtonFrame
)
    if not menuButtonFrame then
        return
    end

    GameTooltip:SetOwner(
        menuButtonFrame,
        "ANCHOR_LEFT"
    )

    GameTooltip:AddLine(
        "MythInc Action Bars",
        0.5,
        0.84,
        1
    )

    GameTooltip:AddLine(
        "Left Click: Open Settings",
        1,
        1,
        1
    )

    GameTooltip:AddLine(
        "Right Click: Keybind Mode",
        1,
        1,
        1
    )

    GameTooltip:Show()
end

function MythIncActionBars_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

local eventFrame =
    CreateFrame(
        "Frame"
    )

eventFrame:RegisterEvent(
    "PLAYER_LOGIN"
)

eventFrame:SetScript(
    "OnEvent",
    function()
        ns.RefreshMinimapButton()
    end
)