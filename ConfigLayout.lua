local addonName, ns = ...

function ns.CreateLayoutConfigPage(
    parent,
    context
)
    local widgets =
        ns.ConfigWidgets

    local page =
        CreateFrame(
            "Frame",
            nil,
            parent
        )

    page:SetAllPoints()

    local controls = {}

    local buttonCountControl
    local buttonsPerRowControl

    local function GetSettings()
        return context.GetSelectedSettings()
    end

    local function GetBarID()
        return context.GetSelectedBarID()
    end

    local function UpdateBar()
        ns.UpdateBar(
            GetBarID()
        )

        ns.RefreshBarMover(
            GetBarID()
        )
    end

    local layoutSection =
        widgets.CreateSection(
            page,
            "Layout",
            506,
            238,
            0,
            0
        )

    local positionSection =
        widgets.CreateSection(
            page,
            "Position",
            506,
            238,
            530,
            0
        )

    buttonCountControl =
        widgets.CreateSlider(
            layoutSection,
            "Buttons",
            1,
            12,
            1,
            24,
            -42,
            function()
                local settings =
                    GetSettings()

                return settings.buttonCount
            end,
            function(value)
                local settings =
                    GetSettings()

                settings.buttonCount =
                    value

                if settings.columns
                    > value
                then
                    settings.columns =
                        value
                end

                UpdateBar()

                if context.RefreshConfig then
                    context.RefreshConfig()
                end
            end,
            nil,
            190
        )

    controls[
        #controls + 1
    ] =
        buttonCountControl

    buttonsPerRowControl =
        widgets.CreateSlider(
            layoutSection,
            "Buttons Per Row",
            1,
            12,
            1,
            280,
            -42,
            function()
                local settings =
                    GetSettings()

                return settings.columns
            end,
            function(value)
                local settings =
                    GetSettings()

                settings.columns =
                    math.min(
                        value,
                        settings.buttonCount
                    )

                UpdateBar()
            end,
            nil,
            190
        )

    controls[
        #controls + 1
    ] =
        buttonsPerRowControl

    controls[
        #controls + 1
    ] =
        widgets.CreateSlider(
            layoutSection,
            "Button Size",
            24,
            64,
            1,
            24,
            -132,
            function()
                local settings =
                    GetSettings()

                return settings.buttonSize
            end,
            function(value)
                local settings =
                    GetSettings()

                settings.buttonSize =
                    value

                UpdateBar()
            end,
            nil,
            190
        )

    controls[
        #controls + 1
    ] =
        widgets.CreateSlider(
            layoutSection,
            "Spacing",
            0,
            20,
            1,
            280,
            -132,
            function()
                local settings =
                    GetSettings()

                return settings.spacing
            end,
            function(value)
                local settings =
                    GetSettings()

                settings.spacing =
                    value

                UpdateBar()
            end,
            nil,
            190
        )

    controls[
        #controls + 1
    ] =
        widgets.CreateSlider(
            positionSection,
            "Scale",
            0.5,
            2,
            0.05,
            24,
            -42,
            function()
                local settings =
                    GetSettings()

                return settings.scale
            end,
            function(value)
                local settings =
                    GetSettings()

                settings.scale =
                    value

                UpdateBar()
            end,
            function(value)
                return string.format(
                    "%.2f",
                    value
                )
            end,
            440
        )

    controls[
        #controls + 1
    ] =
        widgets.CreateSlider(
            positionSection,
            "X Position",
            -1000,
            1000,
            1,
            24,
            -132,
            function()
                local settings =
                    GetSettings()

                return settings.position.x
            end,
            function(value)
                local settings =
                    GetSettings()

                settings.position.x =
                    value

                UpdateBar()
            end,
            nil,
            190
        )

    controls[
        #controls + 1
    ] =
        widgets.CreateSlider(
            positionSection,
            "Y Position",
            -1000,
            1000,
            1,
            280,
            -132,
            function()
                local settings =
                    GetSettings()

                return settings.position.y
            end,
            function(value)
                local settings =
                    GetSettings()

                settings.position.y =
                    value

                UpdateBar()
            end,
            nil,
            190
        )

    page.Refresh =
        function()
            local settings =
                GetSettings()

            if not settings then
                return
            end

            if settings.columns
                > settings.buttonCount
            then
                settings.columns =
                    settings.buttonCount
            end

            if buttonsPerRowControl
                and buttonsPerRowControl.SetMinMaxValues
            then
                buttonsPerRowControl:SetMinMaxValues(
                    1,
                    settings.buttonCount
                )
            end

            for _, control in ipairs(
                controls
            ) do
                if control.Refresh then
                    control:Refresh()
                end
            end
        end

    page:Hide()

    return page
end