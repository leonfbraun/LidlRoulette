local addonName, addonTable = ...

addonTable.SettingsUi = {}
local SettingsUi = addonTable.SettingsUi

SettingsUi.panel = CreateFrame("Frame", "LidlRouletteSettingsPanel", UIParent)
SettingsUi.panel.name = "Lidl Roulette"
SettingsUi.panel.checkboxes = {}

local function CreatePanelHeading()
    local title = SettingsUi.panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(SettingsUi.panel.name)

    local description = SettingsUi.panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetText("Aktiviere/ deaktiviere das Challenge Roulette")
end

local function CreateEnableRouletteCheckbox()
    local checkbox = CreateFrame("CheckButton", nil, SettingsUi.panel, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", SettingsUi.panel, "TOPLEFT", 16, -80)
    checkbox:SetChecked(LidlRouletteDB.settings.isRouletteEnabled)

    local label = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
    label:SetText("Roulette aktiviert")

    checkbox:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        LidlRouletteDB.settings.isRouletteEnabled = isChecked
        print("|cff2674cc[L|cffff0000i|rDL Roulette]|r Roulette " .. (isChecked and "aktiviert" or "deaktiviert"))
    end)

    table.insert(SettingsUi.panel.checkboxes, checkbox)
end

CreatePanelHeading()
CreateEnableRouletteCheckbox()

SettingsUi.panel:SetScript("OnShow", function()
    SettingsUi.panel.checkboxes[1]:SetChecked(LidlRouletteDB.settings.isRouletteEnabled)
end)

local settingsCategory
local function OpenSettings()
    if settingsCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(settingsCategory:GetID())
        return
    end

    local openLegacySettings = _G.InterfaceOptionsFrame_OpenToCategory
    if openLegacySettings then
        openLegacySettings(SettingsUi.panel)
        openLegacySettings(SettingsUi.panel)
    end
end

local registrationFrame = CreateFrame("Frame")
registrationFrame:RegisterEvent("ADDON_LOADED")
registrationFrame:SetScript("OnEvent", function(self, _, loadedAddonName)
    if loadedAddonName ~= addonName then
        return
    end

    local interfaceOptionsAddCategory = _G.InterfaceOptions_AddCategory

    if Settings and Settings.RegisterCanvasLayoutCategory then
        settingsCategory = Settings.RegisterCanvasLayoutCategory(SettingsUi.panel, SettingsUi.panel.name)
        Settings.RegisterAddOnCategory(settingsCategory)
    elseif interfaceOptionsAddCategory then
        interfaceOptionsAddCategory(SettingsUi.panel)
    else
        error("No supported interface options registration API found")
    end

    local compartment = _G.AddonCompartmentFrame
    if compartment and compartment.RegisterAddon then
        compartment:RegisterAddon({
            text = SettingsUi.panel.name,
            func = OpenSettings,
        })
    end

    self:UnregisterEvent("ADDON_LOADED")
end)
