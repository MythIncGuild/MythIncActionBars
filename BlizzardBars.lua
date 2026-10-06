local addonName, ns = ...

local hiddenParent =
    CreateFrame(
        "Frame",
        "MythIncActionBarsHiddenBlizzardBars",
        UIParent
    )

hiddenParent:Hide()

local frameNames = {
    "MainActionBar",
    "MultiBarBottomLeft",
    "MultiBarBottomRight",
    "MultiBarRight",
    "MultiBarLeft",
    "MultiBar5",
    "MultiBar6",
    "MultiBar7",
}

local originalParents = {}
local suppressed = false
local pendingState

local function GetDesiredState()
    if not ns.global then
        return true
    end

    return ns.global
        .hideBlizzardActionBars
        ~= false
end

local function StoreOriginalParent(
    frameName,
    frame
)
    if originalParents[
        frameName
    ] == nil
    then
        originalParents[
            frameName
        ] =
            frame:GetParent()
            or UIParent
    end
end

local function SuppressFrame(
    frameName
)
    local frame =
        _G[
            frameName
        ]

    if not frame then
        return
    end

    StoreOriginalParent(
        frameName,
        frame
    )

    if frame:GetParent()
        ~= hiddenParent
    then
        frame:SetParent(
            hiddenParent
        )
    end
end

local function RestoreFrame(
    frameName
)
    local frame =
        _G[
            frameName
        ]

    if not frame then
        return
    end

    local parent =
        originalParents[
            frameName
        ]
        or UIParent

    if frame:GetParent()
        == hiddenParent
    then
        frame:SetParent(
            parent
        )
    end
end

local function ApplySuppression(
    shouldHide
)
    if InCombatLockdown() then
        pendingState =
            shouldHide

        return false
    end

    for _, frameName in ipairs(
        frameNames
    ) do
        if shouldHide then
            SuppressFrame(
                frameName
            )
        else
            RestoreFrame(
                frameName
            )
        end
    end

    suppressed =
        shouldHide

    pendingState =
        nil

    return true
end

function ns.AreBlizzardActionBarsHidden()
    return GetDesiredState()
end

function ns.SetHideBlizzardActionBars(
    shouldHide
)
    shouldHide =
        shouldHide
        and true
        or false

    if not ns.global then
        return false,
            "missing"
    end

    ns.global
        .hideBlizzardActionBars =
        shouldHide

    if InCombatLockdown() then
        pendingState =
            shouldHide

        return false,
            "combat"
    end

    ApplySuppression(
        shouldHide
    )

    return true
end

function ns.RefreshBlizzardActionBarSuppression()
    return ApplySuppression(
        GetDesiredState()
    )
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
    "EDIT_MODE_LAYOUTS_UPDATED"
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
            C_Timer.After(
                0,
                function()
                    ns.RefreshBlizzardActionBarSuppression()
                end
            )

            return
        end

        if event
            == "PLAYER_REGEN_ENABLED"
        then
            if pendingState
                ~= nil
            then
                ApplySuppression(
                    pendingState
                )
            end

            return
        end

        if event
            == "EDIT_MODE_LAYOUTS_UPDATED"
        then
            if suppressed
                and not InCombatLockdown()
            then
                ApplySuppression(
                    true
                )
            end
        end
    end
)