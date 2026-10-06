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

    local currentSection =
        widgets.CreateSection(
            page,
            "CURRENT PROFILE",
            1012,
            108,
            0,
            0
        )

    local currentName =
        currentSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        currentName,
        15
    )

    currentName:SetPoint(
        "TOPLEFT",
        currentSection,
        "TOPLEFT",
        24,
        -42
    )

    local characterText =
        currentSection:CreateFontString(
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
        currentName,
        "BOTTOMLEFT",
        0,
        -8
    )

    local listSection =
        widgets.CreateSection(
            page,
            "PROFILES",
            330,
            430,
            0,
            -124
        )

    local actionsSection =
        widgets.CreateSection(
            page,
            "PROFILE SETTINGS",
            666,
            430,
            346,
            -124
        )

    local selectedTitle =
        actionsSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        selectedTitle,
        15
    )

    selectedTitle:SetPoint(
        "TOPLEFT",
        actionsSection,
        "TOPLEFT",
        24,
        -42
    )

    local selectedHint =
        actionsSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        selectedHint,
        10,
        true
    )

    selectedHint:SetPoint(
        "TOPLEFT",
        selectedTitle,
        "BOTTOMLEFT",
        0,
        -8
    )

    selectedHint:SetWidth(
        610
    )

    selectedHint:SetJustifyH(
        "LEFT"
    )

    local statusText =
        actionsSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        statusText,
        10,
        true
    )

    statusText:SetPoint(
        "BOTTOMLEFT",
        actionsSection,
        "BOTTOMLEFT",
        24,
        18
    )

    statusText:SetWidth(
        610
    )

    statusText:SetJustifyH(
        "LEFT"
    )

    local function CreateInput(
        y
    )
        local editBox =
            CreateFrame(
                "EditBox",
                nil,
                actionsSection,
                "BackdropTemplate"
            )

        editBox:SetSize(
            360,
            30
        )

        editBox:SetPoint(
            "TOPLEFT",
            actionsSection,
            "TOPLEFT",
            24,
            y
        )

        editBox:SetAutoFocus(
            false
        )

        editBox:SetFont(
            font,
            11,
            "OUTLINE"
        )

        editBox:SetTextColor(
            unpack(
                colors.text
            )
        )

        editBox:SetTextInsets(
            8,
            8,
            0,
            0
        )

        editBox:SetBackdrop({
            bgFile =
                "Interface\\Buttons\\WHITE8x8",

            edgeFile =
                "Interface\\Buttons\\WHITE8x8",

            edgeSize =
                1,
        })

        editBox:SetBackdropColor(
            0.05,
            0.06,
            0.07,
            0.95
        )

        editBox:SetBackdropBorderColor(
            0.18,
            0.20,
            0.21,
            1
        )

        editBox:SetScript(
            "OnEscapePressed",
            function(self)
                self:ClearFocus()
            end
        )

        return editBox
    end

    local newNameLabel =
        actionsSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        newNameLabel,
        10,
        true
    )

    newNameLabel:SetPoint(
        "TOPLEFT",
        actionsSection,
        "TOPLEFT",
        24,
        -104
    )

    newNameLabel:SetText(
        "New Profile Name"
    )

    local newNameInput =
        CreateInput(
            -124
        )

    local renameLabel =
        actionsSection:CreateFontString(
            nil,
            "OVERLAY"
        )

    SetFont(
        renameLabel,
        10,
        true
    )

    renameLabel:SetPoint(
        "TOPLEFT",
        actionsSection,
        "TOPLEFT",
        24,
        -216
    )

    renameLabel:SetText(
        "Rename Selected Profile"
    )

    local renameInput =
        CreateInput(
            -236
        )

    local useButton
    local createButton
    local copyButton
    local renameButton
    local deleteButton

    local function ClearProfileButtons()
        for _, button in ipairs(
            profileButtons
        ) do
            button:Hide()
            button:SetParent(nil)
        end

        profileButtons = {}
    end

    local function SetStatus(
        text
    )
        statusText:SetText(
            text
            or ""
        )
    end

    local function RefreshButtons()
        if not selectedProfile
            or not ns.ProfileExists(
                selectedProfile
            )
        then
            selectedProfile =
                ns.GetCurrentProfileName()
        end

        selectedTitle:SetText(
            selectedProfile
        )

        local current =
            ns.GetCurrentProfileName()

        if selectedProfile
            == current
        then
            selectedHint:SetText(
                "This profile is currently active for this character."
            )

            useButton:Disable()
        else
            selectedHint:SetText(
                "Use this profile on the current character. Switching profiles reloads the UI."
            )

            useButton:Enable()
        end

        if selectedProfile
            == "Default"
        then
            renameButton:Disable()
            deleteButton:Disable()
        else
            renameButton:Enable()

            if selectedProfile
                == current
            then
                deleteButton:Disable()
            else
                deleteButton:Enable()
            end
        end

        for profileName, button in pairs(
            page.ProfileButtonMap
            or {}
        ) do
            button:SetSelected(
                profileName
                    == selectedProfile
            )
        end
    end

    local function RefreshProfileList()
        ClearProfileButtons()

        page.ProfileButtonMap = {}

        local names =
            ns.GetProfileNames()

        for index, profileName in ipairs(
            names
        ) do
            local button =
                widgets.CreateTabButton(
                    listSection,
                    profileName,
                    286,
                    30,
                    18,
                    -42
                        - (
                            (index - 1)
                            * 36
                        ),
                    function()
                        selectedProfile =
                            profileName

                        renameInput:SetText(
                            profileName
                        )

                        SetStatus("")

                        RefreshButtons()
                    end
                )

            profileButtons[
                #profileButtons + 1
            ] =
                button

            page.ProfileButtonMap[
                profileName
            ] =
                button
        end

        RefreshButtons()
    end

    useButton =
        widgets.CreateButton(
            actionsSection,
            "Use Profile",
            150,
            30,
            490,
            -48,
            function()
                local success =
                    ns.SetActiveProfile(
                        selectedProfile
                    )

                if not success then
                    SetStatus(
                        "Unable to activate that profile."
                    )

                    return
                end

                ReloadUI()
            end
        )

    createButton =
        widgets.CreateButton(
            actionsSection,
            "Create New",
            120,
            30,
            400,
            -124,
            function()
                local name =
                    newNameInput:GetText()

                local success,
                    reason =
                    ns.CreateProfile(
                        name
                    )

                if not success then
                    if reason
                        == "exists"
                    then
                        SetStatus(
                            "A profile with that name already exists."
                        )
                    else
                        SetStatus(
                            "Enter a profile name first."
                        )
                    end

                    return
                end

                selectedProfile =
                    name:match(
                        "^%s*(.-)%s*$"
                    )

                newNameInput:SetText("")

                renameInput:SetText(
                    selectedProfile
                )

                SetStatus(
                    "Profile created."
                )

                RefreshProfileList()
            end
        )

    copyButton =
        widgets.CreateButton(
            actionsSection,
            "Copy Selected",
            120,
            30,
            526,
            -124,
            function()
                local name =
                    newNameInput:GetText()

                local success,
                    reason =
                    ns.CopyProfile(
                        selectedProfile,
                        name
                    )

                if not success then
                    if reason
                        == "exists"
                    then
                        SetStatus(
                            "A profile with that name already exists."
                        )

                    elseif reason
                        == "empty"
                    then
                        SetStatus(
                            "Enter a new profile name first."
                        )

                    else
                        SetStatus(
                            "Unable to copy that profile."
                        )
                    end

                    return
                end

                selectedProfile =
                    name:match(
                        "^%s*(.-)%s*$"
                    )

                newNameInput:SetText("")

                renameInput:SetText(
                    selectedProfile
                )

                SetStatus(
                    "Profile copied."
                )

                RefreshProfileList()
            end
        )

    renameButton =
        widgets.CreateButton(
            actionsSection,
            "Rename",
            120,
            30,
            400,
            -236,
            function()
                local oldName =
                    selectedProfile

                local newName =
                    renameInput:GetText()

                local wasActive =
                    oldName
                    == ns.GetCurrentProfileName()

                local success,
                    reason =
                    ns.RenameProfile(
                        oldName,
                        newName
                    )

                if not success then
                    if reason
                        == "default"
                    then
                        SetStatus(
                            "The Default profile cannot be renamed."
                        )

                    elseif reason
                        == "exists"
                    then
                        SetStatus(
                            "A profile with that name already exists."
                        )

                    elseif reason
                        == "empty"
                    then
                        SetStatus(
                            "Enter a new profile name first."
                        )

                    else
                        SetStatus(
                            "Unable to rename that profile."
                        )
                    end

                    return
                end

                selectedProfile =
                    newName:match(
                        "^%s*(.-)%s*$"
                    )

                SetStatus(
                    "Profile renamed."
                )

                if wasActive then
                    ReloadUI()
                    return
                end

                RefreshProfileList()
            end
        )

    deleteButton =
        widgets.CreateButton(
            actionsSection,
            "Delete",
            120,
            30,
            526,
            -236,
            function()
                local profileToDelete =
                    selectedProfile

                StaticPopup_Show(
                    "MYTHINC_ACTIONBARS_DELETE_PROFILE",
                    profileToDelete,
                    nil,
                    {
                        profileName =
                            profileToDelete,

                        callback =
                            function()
                                selectedProfile =
                                    ns.GetCurrentProfileName()

                                renameInput:SetText(
                                    selectedProfile
                                )

                                SetStatus(
                                    "Profile deleted."
                                )

                                RefreshProfileList()
                            end,
                    }
                )
            end
        )

    StaticPopupDialogs[
        "MYTHINC_ACTIONBARS_DELETE_PROFILE"
    ] = {
        text =
            "Delete profile \"%s\"?\n\nThis cannot be undone.",

        button1 =
            "Delete",

        button2 =
            "Cancel",

        timeout =
            0,

        whileDead =
            true,

        hideOnEscape =
            true,

        preferredIndex =
            3,

        OnAccept =
            function(
                self,
                data
            )
                if not data
                    or not data.profileName
                then
                    return
                end

                local success =
                    ns.DeleteProfile(
                        data.profileName
                    )

                if success
                    and data.callback
                then
                    data.callback()
                end
            end,
    }

    page.Refresh =
        function()
            local active =
                ns.GetCurrentProfileName()

            currentName:SetText(
                active
            )

            characterText:SetText(
                ns.GetCharacterProfileKey()
            )

            if not selectedProfile
                or not ns.ProfileExists(
                    selectedProfile
                )
            then
                selectedProfile =
                    active
            end

            renameInput:SetText(
                selectedProfile
            )

            RefreshProfileList()
        end

    page:Show()

    return page
end