local addonName, ns = ...

local widgets = ns.ConfigWidgets
local media = ns.Media
local colors = media.colors
local font = media.font

function ns.CreateGeneralConfigPage(
    parent
)
    local page =
        CreateFrame(
            "Frame",
            nil,
            parent
        )

    local function SetFont(
        fontString,
        size,
        muted
    )
        fontString:SetFont(
            font,
            size,
            "OUTLINE"
        )

        fontString:SetTextColor(
            unpack(
                muted
                    and colors.muted
                    or colors.text
            )
        )
    end

    local section =
        widgets.CreateSection(
            page,
            "INTERFACE",
            1036,
            190,
            0,
            0
        )

    local showMinimapCheckbox =
        widgets.CreateCheckButton(
            section,
            "Show Minimap Button",
            18,
            -42,
            function()
                if ns.IsMinimapButtonShown then
                    return ns.IsMinimapButtonShown()
                end

                return true
            end,
            function(value)
                if ns.SetMinimapButtonShown then
                    ns.SetMinimapButtonShown(
                        value
                    )
                end
            end
        )

    local description =
        section:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        description,
        10,
        true
    )

    description:SetPoint(
        "TOPLEFT",
        section,
        "TOPLEFT",
        18,
        -72
    )

    description:SetWidth(
        800
    )

    description:SetJustifyH(
        "LEFT"
    )

    description:SetText(
        "Show a MythInc Action Bars shortcut around the minimap."
    )

    widgets.CreateButton(
        section,
        "Reset Minimap Button Position",
        230,
        30,
        18,
        -106,
        function()
            if ns.ResetMinimapButtonPosition then
                ns.ResetMinimapButtonPosition()
            end
        end
    )

    local note =
        section:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        note,
        10,
        true
    )

    note:SetPoint(
        "TOPLEFT",
        section,
        "TOPLEFT",
        18,
        -150
    )

    note:SetWidth(
        900
    )

    note:SetJustifyH(
        "LEFT"
    )

    note:SetText(
        "MythInc Action Bars remains available from WoW's Addon Compartment when the minimap button is hidden."
    )

    function page:Refresh()
        if showMinimapCheckbox
            and showMinimapCheckbox.Refresh
        then
            showMinimapCheckbox:Refresh()
        end
    end

    return page
end