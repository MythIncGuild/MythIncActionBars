local addonName, ns = ...

local menus = {
    MythIncActionBarsPetSettings = true,
    MythIncActionBarsStanceSettings = true,
    MythIncActionBarsExtraSettings = true,
}

local function MenuHidden(self)
    -- Cancel key capture using the menu's existing Escape handler.
    local keyHandler = self:GetScript("OnKeyDown")
    if keyHandler then
        keyHandler(self, "ESCAPE")
    end

    self:EnableKeyboard(false)
    self:SetPropagateKeyboardInput(true)

    local parent = self:GetParent()
    if parent then
        parent:StopMovingOrSizing()
    end

    -- Closing a menu preserves each bar's current lock state.
end

local function Install(menu)
    if not menu
        or not menus[menu:GetName()]
        or menu.mythIncMenuStateInstalled then
        return
    end

    menu.mythIncMenuStateInstalled = true
    local setScript = menu.SetScript

    if menu:GetScript("OnHide") then
        setScript(menu, "OnHide", MenuHidden)
    else
        -- New menus set OnHide after their backdrop is created.
        -- Install the replacement before their initial Hide.
        menu.SetScript = function(self, script, handler)
            if script == "OnHide" then
                self.SetScript = setScript
                setScript(self, script, MenuHidden)
            else
                setScript(self, script, handler)
            end
        end
    end
end

local setBackdrop = ns.ConfigWidgets.SetBackdrop
ns.ConfigWidgets.SetBackdrop = function(frame, ...)
    local result = setBackdrop(frame, ...)
    Install(frame)
    return result
end

for name in pairs(menus) do
    Install(_G[name])
end