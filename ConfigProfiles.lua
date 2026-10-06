local addonName, ns = ...

function ns.CreateProfilesConfigPage(
    parent
)
    local widgets =
        ns.ConfigWidgets

    local media =
        ns.Media

    local colors =
        media.colors

    local font =
        media.font

    local page =
        CreateFrame(
            "Frame",
            nil,
            parent
        )

    page:SetAllPoints()

    local selectedProfile =
        ns.GetCurrentProfileName()

    local profileButtons = {}
    local profileButtonMap = {}

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

    local function TrimName(
        value
    )
        if type(value) ~= "string" then
            return ""
        end

        return value:match(
            "^%s*(.-)%s*$"
        )
    end

    local title =
        page:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        title,
        16,
        false
    )

    title:SetPoint(
        "TOPLEFT",
        page,
        "TOPLEFT",
        8,
        -4
    )

    title:SetText(
        "Profiles"
    )

    local managementSection =
        widgets.CreateSection(
            page,
            "Profile Management",
            1012,
            510,
            0,
            -48
        )

    local currentLabel =
        managementSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        currentLabel,
        15,
        false
    )

    currentLabel:SetPoint(
        "TOPLEFT",
        managementSection,
        "TOPLEFT",
        22,
        -42
    )

    currentLabel:SetText(
        "Current profile:"
    )

    local currentName =
        managementSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    currentName:SetFont(
        font,
        15,
        "OUTLINE"
    )

    currentName:SetTextColor(
        unpack(
            colors.accent
        )
    )

    currentName:SetPoint(
        "LEFT",
        currentLabel,
        "RIGHT",
        6,
        0
    )

    local characterText =
        managementSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        characterText,
        10,
        true
    )

    characterText:SetPoint(
        "TOPLEFT",
        currentLabel,
        "BOTTOMLEFT",
        0,
        -8
    )

    local profilesHeading =
        managementSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        profilesHeading,
        15,
        false
    )

    profilesHeading:SetPoint(
        "TOPLEFT",
        managementSection,
        "TOPLEFT",
        22,
        -112
    )

    profilesHeading:SetText(
        "Profiles"
    )

    local managementHeading =
        managementSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        managementHeading,
        15,
        false
    )

    managementHeading:SetPoint(
        "TOPLEFT",
        managementSection,
        "TOPLEFT",
        414,
        -112
    )

    managementHeading:SetText(
        "Management"
    )

    local profileNameLabel =
        managementSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        profileNameLabel,
        10,
        false
    )

    profileNameLabel:SetPoint(
        "TOPLEFT",
        managementHeading,
        "BOTTOMLEFT",
        0,
        -18
    )

    profileNameLabel:SetText(
        "Profile name"
    )

    local profileNameInput =
        CreateFrame(
            "EditBox",
            nil,
            managementSection,
            "BackdropTemplate"
        )

    profileNameInput:SetSize(
        370,
        30
    )

    profileNameInput:SetPoint(
        "TOPLEFT",
        profileNameLabel,
        "BOTTOMLEFT",
        0,
        -8
    )

    profileNameInput:SetAutoFocus(
        false
    )

    profileNameInput:SetFont(
        font,
        11,
        "OUTLINE"
    )

    profileNameInput:SetTextColor(
        unpack(
            colors.text
        )
    )

    profileNameInput:SetTextInsets(
        8,
        8,
        0,
        0
    )

    profileNameInput:SetBackdrop({
        bgFile =
            "Interface\\Buttons\\WHITE8x8",

        edgeFile =
            "Interface\\Buttons\\WHITE8x8",

        edgeSize =
            1,
    })

    profileNameInput:SetBackdropColor(
        0.05,
        0.06,
        0.07,
        0.95
    )

    profileNameInput:SetBackdropBorderColor(
        0.18,
        0.20,
        0.21,
        1
    )

    profileNameInput:SetScript(
        "OnEscapePressed",
        function(self)
            self:ClearFocus()
        end
    )

    profileNameInput:SetScript(
        "OnEnterPressed",
        function(self)
            self:ClearFocus()
        end
    )

    local selectedText =
        managementSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        selectedText,
        10,
        true
    )

    selectedText:SetPoint(
        "TOPLEFT",
        managementSection,
        "TOPLEFT",
        22,
        -196
    )

    selectedText:SetWidth(
        350
    )

    selectedText:SetJustifyH(
        "LEFT"
    )

    local statusText =
        managementSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        statusText,
        10,
        true
    )

    statusText:SetPoint(
        "TOPLEFT",
        managementSection,
        "TOPLEFT",
        414,
        -298
    )

    statusText:SetWidth(
        370
    )

    statusText:SetJustifyH(
        "LEFT"
    )

    local useButton
    local createButton
    local copyButton
    local renameButton
    local deleteButton

    local function SetStatus(
        text
    )
        statusText:SetText(
            text
            or ""
        )
    end

    local function ClearProfileButtons()
        for _, button in ipairs(
            profileButtons
        ) do
            button:Hide()
            button:SetParent(nil)
        end

        profileButtons = {}
        profileButtonMap = {}
    end

    local function ProfileExists(
        profileName
    )
        if ns.ProfileExists then
            return ns.ProfileExists(
                profileName
            )
        end

        return ns.rootDB
            and ns.rootDB.profiles
            and ns.rootDB.profiles[
                profileName
            ] ~= nil
    end

    local function RefreshSelection()
        local current =
            ns.GetCurrentProfileName()

        if not selectedProfile
            or not ProfileExists(
                selectedProfile
            )
        then
            selectedProfile =
                current
        end

        local isCurrent =
            selectedProfile
            == current

        if isCurrent then
            selectedText:SetText(
                selectedProfile
                    .. " is already active."
            )
        else
            selectedText:SetText(
                "Selected: "
                    .. selectedProfile
            )
        end

        for profileName, button in pairs(
            profileButtonMap
        ) do
            button:SetSelected(
                profileName
                    == selectedProfile
            )
        end

        if isCurrent then
            useButton:Disable()
        else
            useButton:Enable()
        end

        if selectedProfile
            == "Default"
        then
            renameButton:Disable()
            deleteButton:Disable()
        else
            renameButton:Enable()

            if isCurrent then
                deleteButton:Disable()
            else
                deleteButton:Enable()
            end
        end
    end

    local function RefreshProfileList()
        ClearProfileButtons()

        local names =
            ns.GetProfileNames()

        for index, profileName in ipairs(
            names
        ) do
            local prefix = ""

            if profileName
                == ns.GetCurrentProfileName()
            then
                prefix = "* "
            end

            local button =
                widgets.CreateTabButton(
                    managementSection,
                    prefix
                        .. profileName,
                    350,
                    30,
                    22,
                    -258
                        - (
                            (index - 1)
                            * 36
                        ),
                    function()
                        selectedProfile =
                            profileName

                        profileNameInput:SetText(
                            profileName
                        )

                        SetStatus("")

                        RefreshSelection()
                    end
                )

            profileButtons[
                #profileButtons + 1
            ] =
                button

            profileButtonMap[
                profileName
            ] =
                button
        end

        RefreshSelection()
    end

    useButton =
    widgets.CreateButton(
        managementSection,
        "Use Selected Profile",
        220,
        34,
        22,
        -136,
        function()
            if not selectedProfile then
                return
            end

            if selectedProfile
                == ns.GetCurrentProfileName()
            then
                return
            end

            if InCombatLockdown() then
                SetStatus(
                    "Profiles cannot be changed during combat."
                )

                return
            end

            local function SwitchProfile()
                local success,
                    reason =
                    ns.SwitchProfileLive(
                        selectedProfile
                    )

                if not success then
                    if reason == "combat" then
                        SetStatus(
                            "Profiles cannot be changed during combat."
                        )
                    else
                        SetStatus(
                            "Unable to activate that profile."
                        )
                    end

                    return false
                end

                selectedProfile =
                    ns.GetCurrentProfileName()

                profileNameInput:SetText(
                    selectedProfile
                )

                SetStatus(
                    "Profile activated."
                )

                page:Refresh()

                return true
            end

            if ns.HasConfigChanges
                and ns.HasConfigChanges()
            then
                if not ns.ShowConfigConfirmation then
                    return
                end

                local targetProfile =
                    selectedProfile

                ns.ShowConfigConfirmation({
                    title =
                        "Switch Profile",

                    message =
                        "You have unapplied changes in the current profile.",

                    buttons = {
                        {
                            text =
                                "Apply & Switch",

                            action =
                                function()
                                    ns.ApplyConfigChanges()

                                    selectedProfile =
                                        targetProfile

                                    return SwitchProfile()
                                end,
                        },
                        {
                            text =
                                "Revert & Switch",

                            action =
                                function()
                                    local success,
                                        reason =
                                        ns.RevertConfigChanges()

                                    if not success then
                                        if reason == "combat" then
                                            SetStatus(
                                                "Changes cannot be reverted during combat."
                                            )
                                        end

                                        return false
                                    end

                                    selectedProfile =
                                        targetProfile

                                    return SwitchProfile()
                                end,
                        },
                        {
                            text =
                                "Cancel",
                        },
                    },
                })

                return
            end

            SwitchProfile()
        end
    )

    createButton =
        widgets.CreateButton(
            managementSection,
            "Create New",
            148,
            34,
            414,
            -206,
            function()
                local name =
                    TrimName(
                        profileNameInput:GetText()
                    )

                local success,
                    reason =
                    ns.CreateProfile(
                        name
                    )

                if not success then
                    if reason == "exists" then
                        SetStatus(
                            "That profile already exists."
                        )
                    else
                        SetStatus(
                            "Enter a profile name."
                        )
                    end

                    return
                end

                selectedProfile =
                    name

                profileNameInput:SetText(
                    name
                )

                SetStatus(
                    "Profile created."
                )

                RefreshProfileList()
            end
        )

    copyButton =
        widgets.CreateButton(
            managementSection,
            "Copy Current",
            148,
            34,
            572,
            -206,
            function()
                local name =
                    TrimName(
                        profileNameInput:GetText()
                    )

                if name == "" then
                    SetStatus(
                        "Enter a profile name."
                    )

                    return
                end

                local success,
                    reason =
                    ns.CopyProfile(
                        ns.GetCurrentProfileName(),
                        name
                    )

                if not success then
                    if reason == "exists" then
                        SetStatus(
                            "That profile already exists."
                        )
                    else
                        SetStatus(
                            "Unable to copy the profile."
                        )
                    end

                    return
                end

                selectedProfile =
                    name

                profileNameInput:SetText(
                    name
                )

                SetStatus(
                    "Profile copied."
                )

                RefreshProfileList()
            end
        )

    renameButton =
        widgets.CreateButton(
            managementSection,
            "Rename Selected",
            148,
            34,
            414,
            -248,
            function()
                if not selectedProfile then
                    return
                end

                local newName =
                    TrimName(
                        profileNameInput:GetText()
                    )

                local wasActive =
                    selectedProfile
                    == ns.GetCurrentProfileName()

                local success,
                    reason =
                    ns.RenameProfile(
                        selectedProfile,
                        newName
                    )

                if not success then
                    if reason == "default" then
                        SetStatus(
                            "Default cannot be renamed."
                        )

                    elseif reason == "exists" then
                        SetStatus(
                            "That profile already exists."
                        )

                    elseif reason == "empty" then
                        SetStatus(
                            "Enter a profile name."
                        )

                    else
                        SetStatus(
                            "Unable to rename that profile."
                        )
                    end

                    return
                end

                selectedProfile =
                    newName

                profileNameInput:SetText(
                    newName
                )

                if wasActive then
                    ReloadUI()
                    return
                end

                SetStatus(
                    "Profile renamed."
                )

                RefreshProfileList()
            end
        )

    deleteButton =
    widgets.CreateButton(
        managementSection,
        "Delete Selected",
        148,
        34,
        572,
        -248,
        function()
            if not selectedProfile then
                return
            end

            if not ns.ShowConfigConfirmation then
                return
            end

            local profileToDelete =
                selectedProfile

            ns.ShowConfigConfirmation({
                title =
                    "Delete Profile",

                message =
                    "Delete profile \""
                    .. profileToDelete
                    .. "\"?\n\nThis cannot be undone.",

                buttons = {
                    {
                        text =
                            "Delete",

                        action =
                            function()
                                local success,
                                    reason =
                                    ns.DeleteProfile(
                                        profileToDelete
                                    )

                                if not success then
                                    if reason == "default" then
                                        SetStatus(
                                            "Default cannot be deleted."
                                        )

                                    elseif reason == "active" then
                                        SetStatus(
                                            "The active profile cannot be deleted."
                                        )

                                    else
                                        SetStatus(
                                            "Unable to delete that profile."
                                        )
                                    end

                                    return false
                                end

                                selectedProfile =
                                    ns.GetCurrentProfileName()

                                profileNameInput:SetText(
                                    selectedProfile
                                )

                                SetStatus(
                                    "Profile deleted."
                                )

                                RefreshProfileList()

                                return true
                            end,
                    },
                    {
                        text =
                            "Cancel",
                    },
                },
            })
        end
    )

    local sharingHeading =
        managementSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        sharingHeading,
        15,
        false
    )

    sharingHeading:SetPoint(
        "TOPLEFT",
        managementSection,
        "TOPLEFT",
        414,
        -354
    )

    sharingHeading:SetText(
        "Sharing"
    )

    local exportButton =
        widgets.CreateButton(
            managementSection,
            "Export",
            148,
            34,
            414,
            -392,
            function()
            end
        )

    exportButton:Disable()

    local importButton =
        widgets.CreateButton(
            managementSection,
            "Import",
            148,
            34,
            572,
            -392,
            function()
            end
        )

    importButton:Disable()

    local sharingStatus =
        managementSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        sharingStatus,
        10,
        true
    )

    sharingStatus:SetPoint(
        "TOPLEFT",
        managementSection,
        "TOPLEFT",
        414,
        -442
    )

    sharingStatus:SetText(
        "Profile sharing will be added in a future update."
    )

    page.Refresh =
        function()
            local current =
                ns.GetCurrentProfileName()

            currentName:SetText(
                current
            )

            if ns.GetCharacterProfileKey then
                characterText:SetText(
                    "Character: "
                        .. ns.GetCharacterProfileKey()
                )
            else
                characterText:SetText(
                    "Character: "
                        .. (
                            UnitName("player")
                            or ""
                        )
                        .. " - "
                        .. (
                            GetRealmName()
                            or ""
                        )
                )
            end

            if not selectedProfile
                or not ProfileExists(
                    selectedProfile
                )
            then
                selectedProfile =
                    current
            end

            profileNameInput:SetText(
                selectedProfile
            )

            RefreshProfileList()
        end

    page:Show()

    return page
end