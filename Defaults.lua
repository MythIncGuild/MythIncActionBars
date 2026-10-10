
local addonName, ns = ...

function ns.CreateDefaultBarSettings(
    barID,
    enabled,
    source
)
    source = source or "custom"

    local x = 0
    local y = -200

    if source == "blizzard" then
        y = -200 - ((barID - 1) * 45)
    else
        local customIndex = math.max(1, barID - 8)

        x = ((customIndex - 1) % 5) * 24
        y = -100 - (((customIndex - 1) % 5) * 24)
    end

    return {
        name = "Bar " .. barID,

        enabled = enabled and true or false,

        source = source,

        buttonCount = 12,
        buttonSize = 36,
        spacing = 4,
        columns = 12,
        scale = 1,

        appearance = {
            iconZoom = 0,
            showBorder = true,
            emptyOpacity = 0.85,
            showCooldown = true,
            showCooldownText = true,
            showCount = true,
            countTextSize = 12,

            showKeybind = true,
            keybindTextSize = 12,
            keybindPosition = "TOPRIGHT",

            keybindColor = {
                r = 1,
                g = 1,
                b = 1,
                a = 1,
            },

            desaturateUnusable = false,
            rangeColoring = true,
            usabilityColoring = true,
        },

        visibility = {
            mode = "always",
            hideMounted = false,
            hideVehicle = false,
            hidePetBattle = false,
        },

        actionPages = {
            shift = {
                enabled = false,
                page = 2,
            },

            ctrl = {
                enabled = false,
                page = 3,
            },

            alt = {
                enabled = false,
                page = 4,
            },
        },

        keybinds = {},
        assignments = {},

        position = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = x,
            y = y,
        },
    }
end

ns.defaults = {
    bars = {},

    buttonInteraction = {
        lockContents = true,
        activateOnPress = false,
    },
}

for barID = 1, 8 do
    ns.defaults.bars[barID] =
        ns.CreateDefaultBarSettings(
            barID,
            barID == 1,
            "blizzard"
        )
end
