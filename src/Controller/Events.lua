local addonName, addonTable = ...

addonTable.Events = {}

local Events = addonTable.Events

--Init Events
local frame = CreateFrame("Frame")

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("CHAT_MSG_SYSTEM")

local patternKnockout = "(.+) has defeated (.+) in a duel"
local patternRetreat = "(.+) has fled from (.+) in a duel"

local function handleDuelResult(message)
    local firstName, lastName = UnitName("player")
    local fullName = firstName .. " " .. lastName

    local winner, loser = message:match(patternKnockout)

    local winnerString = tostring(winner)
    local loserString = tostring(loser)

    print("Winner: " .. winnerString)
    print("Loser: " .. loserString)

    if winnerString and loserString then
        if winnerString == fullName then
            print("Duell-Ergebnis: Du hast GEWONNEN gegen " .. loserString .. "!")
        elseif loserString == fullName then
            print("Duell-Ergebnis: Du hast VERLOREN gegen " .. winnerString .. "!")
        end
        return
    end

    local fleer, pursuer = message:match(patternRetreat)

    local fleerString = tostring(fleer)
    local pursuerString = tostring(pursuer)
    if fleerString and pursuerString then
        if pursuerString == fullName then
            print("Duell-Ergebnis: Du hast GEWONNEN, weil " .. fleerString .. " abgehauen ist!")
        elseif fleerString == fullName then
            print("Duell-Ergebnis: Du hast VERLOREN, weil du abgehauen bist!")
        end
        return
    end

    if message:find(DUEL_FLED, 1, true) then
        print("Duell-Ergebnis: Du hast VERLOREN, weil du geflohen bist!")
    end
end

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
        handleDuelResult(message)
    end
end)

function Events.RegisterCommunicationEvents()
    frame:RegisterEvent("CHAT_MSG_ADDON")
end
