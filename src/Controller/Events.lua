local addonName, addonTable = ...

addonTable.Events = {}

local Events = addonTable.Events

--Init Events
local frame = CreateFrame("Frame")

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("DUEL_FINISHED")
frame:RegisterEvent("DUEL_INBOUNDS")


frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        addonTable:Initialize()
    elseif event == "PLAYER_LEVEL_UP" then
        local level = ...
        addonTable:OnLocalLevelUp(level)
    elseif event == "PLAYER_DEAD" then
        addonTable:OnLocalDeath()
    elseif event == "CHAT_MSG_ADDON" then
        addonTable.Communication:OnMessageReceived(...)
    elseif event == "CHAT_MSG_SYSTEM" then
        local message = ...
        if message:match(addonTable.patternKnockout)
        or message:match(addonTable.patternRetreat) then
            addonTable.handleDuelResult(message)
        end
    end
end)

function Events.RegisterCommunicationEvents()
    frame:RegisterEvent("CHAT_MSG_ADDON")
end
