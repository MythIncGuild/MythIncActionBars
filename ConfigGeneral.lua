
local addonName, ns = ...

local widgets = ns.ConfigWidgets

function ns.CreateGeneralConfigPage(parent)
    local page = CreateFrame("Frame", nil, parent)

    local section = widgets.CreateSection(
        page,
        "INTERFACE",
        1036,
        120,
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
                    ns.SetMinimapButtonShown(value)
                end
            end
        )

    widgets.CreateButton(
        section,
        "Reset Minimap Button Position",
        230,
        30,
        18,
        -76,
        function()
            if ns.ResetMinimapButtonPosition then
                ns.ResetMinimapButtonPosition()
            end
        end
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
