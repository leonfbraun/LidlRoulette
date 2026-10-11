local addonName, addonTable = ...

addonTable.Events = {}

local Events = addonTable.Events

--Init Events
local frame = CreateFrame("Frame")

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("CHAT_MSG_SYSTEM")

local function makeDuelPattern(format)
    return format:gsub("%%[%d]+%$s", "(.+)"):gsub("%%s", "(.+)")
end

local patternKnockout = makeDuelPattern(DUEL_WINNER_KNOCKOUT)
local patternRetreat = makeDuelPattern(DUEL_WINNER_RETREAT)

local function handleDuelResult(message)
    local firstName, lastName = UnitName("player")
    local fullName = firstName .. " " .. lastName

    local winner, loser = message:match(patternKnockout)

    if winner and loser then
        if winner == fullName then
            print("Duell-Ergebnis: Du hast GEWONNEN gegen " .. loser .. "!")
        elseif loser == fullName then
            print("Duell-Ergebnis: Du hast VERLOREN gegen " .. winner .. "!")
        end
        return
    end

    local fleer, pursuer = message:match(patternRetreat)

    if fleer and pursuer then
        if pursuer == fullName then
            print("Duell-Ergebnis: Du hast GEWONNEN, weil " .. fleer .. " abgehauen ist!")
        elseif fleer == fullName then
            print("Duell-Ergebnis: Du hast VERLOREN, weil du abgehauen bist!")
        end
        return
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
