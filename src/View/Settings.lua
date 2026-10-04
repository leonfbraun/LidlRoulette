local addonName, addonTable = ...

addonTable.SettingsUi = {}
local SettingsUi = addonTable.SettingsUi

local frame

function SettingsUi:Initialize()
    frame = CreateFrame("Frame", "SettingsFrame", UIParent)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    frame:SetSize(600, 350)

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.03, 0.03, 0.03, 0.96)

    local titleText = frame:CreateFontString("TitleText", "OVERLAY", "GameFontNormalLarge")
    titleText:SetFont("Fonts\\FRIZQT__.TTF", 25, "OUTLINE")
    titleText:SetPoint("CENTER", frame, "TOP", 0, -20)
    titleText:SetText("Einstellungen")

    local checkbox = CreateFrame("CheckButton", "TitleText" , frame, "UICheckButtonTemplate")
    checkbox:SetPoint("CENTER", frame, "TOP", 0, -40)
    checkbox:SetChecked(SettingsUi.enabled)

    checkbox:SetScript("OnClick", function(self)
        SettingsUi.enabled = self:GetChecked() and true or false
    end)
end