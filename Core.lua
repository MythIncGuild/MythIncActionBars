local addonName, ns = ...

ns.name = addonName
ns.version = "0.1.0-alpha.1"

local function CopyDefaults(
    source,
    destination
)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(destination[key]) ~= "table" then
                destination[key] = {}
            end

            CopyDefaults(
                value,
                destination[key]
            )

        elseif destination[key] == nil then
            destination[key] = value
        end
    end
end

local function DeepCopy(
    source
)
    if type(source) ~= "table" then
        return source
    end

    local result = {}

    for key, value in pairs(source) do
        result[
            DeepCopy(key)
        ] =
            DeepCopy(value)
    end

    return result
end

local function Trim(
    value
)
    if type(value) ~= "string" then
        return ""
    end

    return value:match(
        "^%s*(.-)%s*$"
    )
end

local function GetCharacterKey()
    local name =
        UnitName("player")
        or "Unknown"

    local realm =
        GetRealmName()
        or "Unknown"

    return name
        .. " - "
        .. realm
end

local function MigrateBars(
    bars
)
    bars =
        bars or {}

    if bars.bar1
        and not bars[1]
    then
        bars[1] =
            bars.bar1

        bars.bar1 =
            nil
    end

    for barID, settings in pairs(
        bars
    ) do
        if type(barID) == "number"
            and type(settings) == "table"
        then
            if settings.source == nil then
                if barID <= 8 then
                    settings.source =
                        "blizzard"
                else
                    settings.source =
                        "custom"
                end
            end

            if settings.name == nil then
                settings.name =
                    "Bar " .. barID
            end

            if settings.assignments == nil then
                settings.assignments = {}
            end

            if settings.keybinds == nil then
                settings.keybinds = {}
            end
        end
    end

    return bars
end

local function MigrateDatabase()
    MythIncActionBarsDB =
        MythIncActionBarsDB
        or {}

    local root =
        MythIncActionBarsDB

    root.global =
        root.global
        or {}

    if root.global.hideBlizzardActionBars
        == nil
    then
        root.global.hideBlizzardActionBars =
            true
    end

    root.profiles =
        root.profiles
        or {}

    root.profileKeys =
        root.profileKeys
        or {}

    if root.bars then
        if not root.profiles.Default then
            root.profiles.Default = {
                bars =
                    root.bars,
            }
        elseif not root.profiles.Default.bars then
            root.profiles.Default.bars =
                root.bars
        end

        root.bars =
            nil
    end

    if not root.profiles.Default then
        root.profiles.Default = {}
    end

    for _, profile in pairs(
        root.profiles
    ) do
        if type(profile) == "table" then
            profile.bars =
                MigrateBars(
                    profile.bars
                )
        end
    end

    local characterKey =
        GetCharacterKey()

    local profileName =
        root.profileKeys[
            characterKey
        ]

    if not profileName
        or not root.profiles[
            profileName
        ]
    then
        profileName =
            "Default"

        root.profileKeys[
            characterKey
        ] =
            profileName
    end

    return root,
        profileName
end

function ns.InitializeDatabase()
    local root,
        profileName =
        MigrateDatabase()

    local profile =
        root.profiles[
            profileName
        ]

    CopyDefaults(
        ns.defaults,
        profile
    )

    profile.bars =
        MigrateBars(
            profile.bars
        )

    ns.rootDB =
        root

    ns.global =
        root.global

    ns.db =
        profile

    ns.profileName =
        profileName

    ns.characterKey =
        GetCharacterKey()
end

function ns.GetCurrentProfileName()
    return ns.profileName
        or "Default"
end

function ns.GetCharacterProfileKey()
    return ns.characterKey
        or GetCharacterKey()
end

function ns.GetProfileNames()
    local names = {}

    if not MythIncActionBarsDB
        or not MythIncActionBarsDB.profiles
    then
        return names
    end

    for name, profile in pairs(
        MythIncActionBarsDB.profiles
    ) do
        if type(name) == "string"
            and type(profile) == "table"
        then
            names[
                #names + 1
            ] =
                name
        end
    end

    table.sort(
        names,
        function(a, b)
            if a == "Default" then
                return true
            end

            if b == "Default" then
                return false
            end

            return string.lower(a)
                < string.lower(b)
        end
    )

    return names
end

function ns.ProfileExists(
    profileName
)
    profileName =
        Trim(
            profileName
        )

    return profileName ~= ""
        and MythIncActionBarsDB
        and MythIncActionBarsDB.profiles
        and type(
            MythIncActionBarsDB
                .profiles[
                    profileName
                ]
        ) == "table"
end

function ns.CreateProfile(
    profileName
)
    profileName =
        Trim(
            profileName
        )

    if profileName == "" then
        return false,
            "empty"
    end

    if ns.ProfileExists(
        profileName
    ) then
        return false,
            "exists"
    end

    local profile = {}

    CopyDefaults(
        ns.defaults,
        profile
    )

    MythIncActionBarsDB
        .profiles[
            profileName
        ] =
        profile

    return true
end

function ns.CopyProfile(
    sourceName,
    targetName
)
    sourceName =
        Trim(
            sourceName
        )

    targetName =
        Trim(
            targetName
        )

    if targetName == "" then
        return false,
            "empty"
    end

    if ns.ProfileExists(
        targetName
    ) then
        return false,
            "exists"
    end

    if not ns.ProfileExists(
        sourceName
    ) then
        return false,
            "missing"
    end

    local source =
        MythIncActionBarsDB
            .profiles[
                sourceName
            ]

    local profile =
        DeepCopy(
            source
        )

    CopyDefaults(
        ns.defaults,
        profile
    )

    MythIncActionBarsDB
        .profiles[
            targetName
        ] =
        profile

    return true
end

function ns.RenameProfile(
    oldName,
    newName
)
    oldName =
        Trim(
            oldName
        )

    newName =
        Trim(
            newName
        )

    if oldName == "Default" then
        return false,
            "default"
    end

    if newName == "" then
        return false,
            "empty"
    end

    if not ns.ProfileExists(
        oldName
    ) then
        return false,
            "missing"
    end

    if ns.ProfileExists(
        newName
    ) then
        return false,
            "exists"
    end

    MythIncActionBarsDB
        .profiles[
            newName
        ] =
        MythIncActionBarsDB
            .profiles[
                oldName
            ]

    MythIncActionBarsDB
        .profiles[
            oldName
        ] =
        nil

    for characterKey, profileName in pairs(
        MythIncActionBarsDB.profileKeys
    ) do
        if profileName
            == oldName
        then
            MythIncActionBarsDB
                .profileKeys[
                    characterKey
                ] =
                newName
        end
    end

    if ns.profileName
        == oldName
    then
        ns.profileName =
            newName
    end

    return true
end

function ns.DeleteProfile(
    profileName
)
    profileName =
        Trim(
            profileName
        )

    if profileName == "Default" then
        return false,
            "default"
    end

    if profileName
        == ns.GetCurrentProfileName()
    then
        return false,
            "active"
    end

    if not ns.ProfileExists(
        profileName
    ) then
        return false,
            "missing"
    end

    MythIncActionBarsDB
        .profiles[
            profileName
        ] =
        nil

    for characterKey, assignedProfile in pairs(
        MythIncActionBarsDB.profileKeys
    ) do
        if assignedProfile
            == profileName
        then
            MythIncActionBarsDB
                .profileKeys[
                    characterKey
                ] =
                "Default"
        end
    end

    return true
end

function ns.SetActiveProfile(
    profileName
)
    profileName =
        Trim(
            profileName
        )

    if not ns.ProfileExists(
        profileName
    ) then
        return false,
            "missing"
    end

    MythIncActionBarsDB
        .profileKeys[
            GetCharacterKey()
        ] =
        profileName

    return true
end

local eventFrame =
    CreateFrame(
        "Frame"
    )

eventFrame:RegisterEvent(
    "ADDON_LOADED"
)

eventFrame:SetScript(
    "OnEvent",
    function(
        _,
        _,
        loadedAddon
    )
        if loadedAddon
            ~= addonName
        then
            return
        end

        ns.InitializeDatabase()

        print(
            "|cff7fd5ffMythInc Action Bars|r loaded."
        )
    end
)