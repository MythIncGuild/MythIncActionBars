local addonName, ns = ...

local snapshot
local snapshotProfileName

local function DeepCopy(
    value
)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}

    for key, child in pairs(
        value
    ) do
        copy[
            DeepCopy(
                key
            )
        ] =
            DeepCopy(
                child
            )
    end

    return copy
end

local function DeepEqual(
    first,
    second
)
    if first == second then
        return true
    end

    if type(first)
        ~= type(second)
    then
        return false
    end

    if type(first)
        ~= "table"
    then
        return false
    end

    for key, value in pairs(
        first
    ) do
        if not DeepEqual(
            value,
            second[
                key
            ]
        )
        then
            return false
        end
    end

    for key in pairs(
        second
    ) do
        if first[
            key
        ] == nil
        then
            return false
        end
    end

    return true
end

local function ClearTable(
    target
)
    for key in pairs(
        target
    ) do
        target[
            key
        ] =
            nil
    end
end

local function ReplaceTable(
    target,
    source
)
    ClearTable(
        target
    )

    for key, value in pairs(
        source
    ) do
        target[
            key
        ] =
            DeepCopy(
                value
            )
    end
end

function ns.BeginConfigSession()
    if not ns.db then
        return
    end

    snapshot =
        DeepCopy(
            ns.db
        )

    snapshotProfileName =
        ns.GetCurrentProfileName
        and ns.GetCurrentProfileName()
        or nil
end

function ns.HasConfigChanges()
    if not snapshot
        or not ns.db
    then
        return false
    end

    if ns.GetCurrentProfileName
        and snapshotProfileName
            ~= ns.GetCurrentProfileName()
    then
        return false
    end

    return not DeepEqual(
        ns.db,
        snapshot
    )
end

function ns.ApplyConfigChanges()
    if not ns.db then
        return false
    end

    snapshot =
        DeepCopy(
            ns.db
        )

    snapshotProfileName =
        ns.GetCurrentProfileName
        and ns.GetCurrentProfileName()
        or nil

    return true
end

function ns.CanRevertConfigChanges()
    if not snapshot
        or not ns.db
    then
        return false
    end

    if ns.GetCurrentProfileName
        and snapshotProfileName
            ~= ns.GetCurrentProfileName()
    then
        return false
    end

    return true
end

function ns.RevertConfigChanges()
    if InCombatLockdown() then
        return false,
            "combat"
    end

    if not ns.CanRevertConfigChanges() then
        return false,
            "missing"
    end

    ReplaceTable(
        ns.db,
        snapshot
    )

    local success,
        reason =
        ns.RefreshAllBarsFromProfile()

    if not success then
        return false,
            reason
    end

    return true
end

function ns.ResetActiveProfileToDefaults()
    if InCombatLockdown() then
        return false,
            "combat"
    end

    if not ns.db
        or not ns.defaults
    then
        return false,
            "missing"
    end

    ReplaceTable(
        ns.db,
        ns.defaults
    )

    local success,
        reason =
        ns.RefreshAllBarsFromProfile()

    if not success then
        return false,
            reason
    end

    ns.ApplyConfigChanges()

    return true
end

function ns.SwitchProfileLive(
    profileName
)
    if InCombatLockdown() then
        return false,
            "combat"
    end

    if type(profileName)
        ~= "string"
        or profileName == ""
    then
        return false,
            "missing"
    end

    if not ns.rootDB
        or not ns.rootDB.profiles
        or not ns.rootDB.profiles[
            profileName
        ]
    then
        return false,
            "missing"
    end

    local characterKey

    if ns.GetCharacterProfileKey then
        characterKey =
            ns.GetCharacterProfileKey()
    end

    if not characterKey then
        return false,
            "character"
    end

    if ns.LockAllBars then
        ns.LockAllBars()
    end

    ns.rootDB.profileKeys =
        ns.rootDB.profileKeys
        or {}

    ns.rootDB.profileKeys[
        characterKey
    ] =
        profileName

    ns.profileName =
        profileName

    ns.db =
        ns.rootDB.profiles[
            profileName
        ]

    local success,
        reason =
        ns.RefreshAllBarsFromProfile()

    if not success then
        return false,
            reason
    end

    ns.BeginConfigSession()

    if ns.RefreshConfig then
        ns.RefreshConfig()
    end

    return true
end