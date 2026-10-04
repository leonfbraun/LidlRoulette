local addonName, addonTable = ...

addonTable.OverviewUi = {}
local OverviewUi = addonTable.OverviewUi

local frame

function addonTable.OverviewUi:Initialize()
    frame = CreateFrame("Frame", "OverviewFrame", UIParent)
    frame:SetSize(600, 350)

    local checkbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -16)
    checkbox:SetChecked(OverviewUi.enabled)

    checkbox:SetScript("OnClick", function(self)
        OverviewUi.enabled = self:GetChecked() and true or false
    end)
end