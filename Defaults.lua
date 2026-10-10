
local addonName, ns = ...

local MAX_CUSTOM_PAGES = 12

ns.MAX_CUSTOM_ACTION_PAGES = MAX_CUSTOM_PAGES

-- Only supported conditions may be passed to a secure
-- state driver. Do not evaluate user-entered Lua or
-- unrestricted secure snippets.

local PAGE_CONDITIONS = {
    stealth = "[stealth]",
    combat = "[combat]",
    nocombat = "[nocombat]",
    mounted = "[mounted]",
    flying = "[flying]",
    swimming = "[swimming]",
    pet = "[pet]",
    vehicle = "[vehicleui]",
    override = "[overridebar]",
    possess = "[possessbar]",
    friendly = "[@target,help,nodead]",
    hostile = "[@target,harm,nodead]",
}

function ns.GetActionPageCondition(condition)
    if type(condition) ~= "string" then
        return nil
    end

    if PAGE_CONDITIONS[condition] then
        return PAGE_CONDITIONS[condition]
    end

    local form = condition:match("^form:(%d+)$")

    if form
        and tonumber(form) >= 1
        and tonumber(form) <= 10
    then
        return "[form:" .. tonumber(form) .. "]"
    end

    return nil
end

function ns.CompileActionPageDriver(actionPages, maxPage)
    -- This function compiles and validates rules only.
    -- Installing the resulting driver belongs to the
    -- secure action-button implementation.

    actionPages =
        type(actionPages) == "table"
        and actionPages or {}

    maxPage = tonumber(maxPage) or MAX_CUSTOM_PAGES

    maxPage = math.max(
        1,
        math.min(
            MAX_CUSTOM_PAGES,
            math.floor(maxPage)
        )
    )

    local function ValidPage(page)
        page = tonumber(page)

        if not page
            or page ~= math.floor(page)
            or page < 1
            or page > maxPage
        then
            return nil
        end

        return page
    end

    local rules = {}
    local invalidCount = 0

    -- Automatic conditions have priority.
    -- The order in contextRules determines which
    -- matching condition wins.

    if type(actionPages.contextRules) == "table" then
        for _, rule in ipairs(actionPages.contextRules) do
            if type(rule) == "table"
                and rule.enabled ~= false
            then
                local condition =
                    ns.GetActionPageCondition(
                        rule.condition
                    )

                local page = ValidPage(rule.page)

                if condition and page then
                    rules[#rules + 1] =
                        condition .. " " .. page
                else
                    invalidCount = invalidCount + 1
                end
            end
        end
    end

    -- Modifier priority when multiple modifier keys
    -- are held together: ALT > CTRL > SHIFT.
    --
    -- The rule editor can later expose this ordering.

    for _, modifier in ipairs({
        "alt",
        "ctrl",
        "shift",
    }) do
        local settings = actionPages[modifier]

        if type(settings) == "table"
            and settings.enabled
        then
            local page = ValidPage(settings.page)

            if page then
                rules[#rules + 1] =
                    "[mod:"
                    .. modifier
                    .. "] "
                    .. page
            else
                invalidCount = invalidCount + 1
            end
        end
    end

    -- No rules means the existing bar's default
    -- behaviour should remain unchanged.

    if #rules == 0 then
        return "1", false, invalidCount
    end

    -- The Normal page is the fallback.

    rules[#rules + 1] = "1"

    return table.concat(rules, "; "),
        true,
        invalidCount
end

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

    local settings = {
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

            showEmptyButtons = true,
            showEmptyWhileUnlocked = true,

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

            flyoutDirection = "UP",
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

            -- Prioritized automatic paging rules.
            --
            -- Example:
            --
            -- {
            --     enabled = true,
            --     condition = "stealth",
            --     page = 5,
            -- }
            --
            -- No rules are active by default.

            contextRules = {},
        },

        keybinds = {},

        -- Legacy and Normal-page assignments.
        assignments = {},

        position = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = x,
            y = y,
        },
    }

    if source == "custom" then
        -- Additional pages are stored by specialization.
        --
        -- customPagesBySpec[specID][page][buttonID]
        --
        -- Page 1 remains in the existing
        -- assignmentsBySpec system.
        --
        -- Do not initialize assignmentsBySpec here:
        -- the existing legacy migration needs to
        -- adopt settings.assignments first.

        settings.customPagesBySpec = {}
    end

    return settings
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
