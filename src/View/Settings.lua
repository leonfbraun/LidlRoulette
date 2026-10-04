local addonName, addonTable = ...

addonTable.SettingsUi = {}
local SettingsUi = addonTable.SettingsUi

local frame

function SettingsUi:Initialize()
    frame = CreateFrame("Frame", "SettingsFrame", UIParent)
    frame:SetSize(600, 350)

    local checkbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -16)
    checkbox:SetChecked(SettingsUi.enabled)

    checkbox:SetScript("OnClick", function(self)
        SettingsUi.enabled = self:GetChecked() and true or false
    end)
end