local addonName, ns = ...

ns.name = addonName
ns.version = "0.1.0-alpha.1"

local function CopyDefaults(source, destination)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(destination[key]) ~= "table" then
                destination[key] = {}
            end

            CopyDefaults(value, destination[key])
        elseif destination[key] == nil then
            destination[key] = value
        end
    end
end

function ns.InitializeDatabase()
    MythIncActionBarsDB = MythIncActionBarsDB or {}

    CopyDefaults(ns.defaults, MythIncActionBarsDB)

    ns.db = MythIncActionBarsDB
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:SetScript("OnEvent", function(_, _, loadedAddon)
    if loadedAddon ~= addonName then
        return
    end

    ns.InitializeDatabase()

    print("|cff7fd5ffMythInc Action Bars|r loaded.")
end)