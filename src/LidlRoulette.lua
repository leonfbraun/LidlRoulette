local addonName, addonTable = ...

addonTable.PREFIX = "LIDL_ROULETTE"
addonTable.VERSION = "0.1.0"
addonTable.ProcessedEvents = {}

addonTable.patternKnockout = DUEL_WINNER_KNOCKOUT:gsub("%%[%d]+%$s", "(.+)"):gsub("%%s", "(.+)")
addonTable.patternRetreat = DUEL_WINNER_RETREAT:gsub("%%[%d]+%$s", "(.+)"):gsub("%%s", "(.+)")

local function EnsureSavedSettings()
    if type(LidlRouletteDB) ~= "table" then
        LidlRouletteDB = {}
    end

    if type(LidlRouletteDB.settings) ~= "table" then
        LidlRouletteDB.settings = {}
    end

    if LidlRouletteDB.settings.isRouletteEnabled == nil then
        LidlRouletteDB.settings.isRouletteEnabled = true
    end
end

EnsureSavedSettings()

local savedVariablesFrame = CreateFrame("Frame")
savedVariablesFrame:RegisterEvent("ADDON_LOADED")
savedVariablesFrame:SetScript("OnEvent", function(self, _, loadedAddonName)
    if loadedAddonName == addonName then
        EnsureSavedSettings()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

function addonTable:Initialize()
    if not self.Communication:Initialize() then
        return
    end
    self.Events:RegisterCommunicationEvents()
    self.ChallengeRouletteUi:Initialize()
    self.AnnouncementUi:Initialize()
    self:PrintHelp()

end

-- creates a unique event ID based on the player's name, current timestamp, and a random number
function addonTable:CreateEventID()
    local firstName, lastName = UnitName("player")
    local fullName = firstName .. " " .. lastName
    local timestamp = time()
    local randomNumber = math.random(100000, 999999)

    return string.format("%s-%d-%d", fullName, timestamp, randomNumber)
end

function addonTable:OnLocalLevelUp(playerLevel)
    local firstName, lastName = UnitName("player")
    local fullName = firstName .. " " .. lastName

    local eventID = self:CreateEventID()
    local challengeID
    if LidlRouletteDB.settings.isRouletteEnabled == true then
        challengeID = self.Roulette.Roll()
    end

    print("|cff2674cc[L|cffff0000i|rDL Roulette]|r " .. fullName ..
        " ist jetzt Level " .. tostring(playerLevel) .. "!")
    if challengeID then
        self.ChallengeRouletteUi:ShowChallenge(fullName, playerLevel, challengeID, "levelup")
    end

    self.ProcessedEvents[eventID] = true
    
    C_Timer.After(3, function() 
        local command = "LEVELUP"
        self.Communication.SendMessage(command, fullName, playerLevel, challengeID, eventID)
    end)
end

function addonTable:OnLocalDeath()
    local firstName, lastName = UnitName("player")
    local fullName = firstName .. " " .. lastName

    local playerLevel = UnitLevel("player") or 1

    local eventID = self:CreateEventID()
    local challengeID
    if LidlRouletteDB.settings.isRouletteEnabled == true then
        challengeID = self.Roulette.Roll("death")
    end

    if challengeID then
        print("|cff2674cc[L|cffff0000i|rDL Roulette]|r " .. fullName .. " ist mit Level " .. tostring(playerLevel) .. " gestorben.")
        self.ChallengeRouletteUi:ShowChallenge(fullName, playerLevel, challengeID, "death")
    end

    self.ProcessedEvents[eventID] = true
    
    C_Timer.After(3, function() 
        local command = "DEATH"
        self.Communication.SendMessage(command, fullName, playerLevel, challengeID, eventID)
    end)
    
end

function addonTable:OnLocalDuelLoss(winnerName, loserName) 
    local playerLevel = UnitLevel("player") or 1

    local eventID = self:CreateEventID()
    local challengeID
    if LidlRouletteDB.settings.isRouletteEnabled == true then
        challengeID = self.Roulette.Roll("duel")
    end

    print("|cff2674cc[L|cffff0000i|rDL Roulette]|r " .. winnerName ..
        " hat dich im Duell besiegt!")
    if challengeID then
        self.ChallengeRouletteUi:ShowChallenge(loserName, playerLevel, challengeID, "duel")
    end

    self.ProcessedEvents[eventID] = true
    
    C_Timer.After(3, function() 
        local command = "DUEL"
        self.Communication.SendMessage(command, loserName, playerLevel, challengeID, eventID, winnerName)
    end)
end

function addonTable:OnRemoteEventRecieved(playerName, level, challengeID, eventID, challengerName, command)
    if self.ProcessedEvents[eventID] then
        return
    end

    self.ProcessedEvents[eventID] = true

    self.AnnouncementUi:ShowAnnouncement(playerName, challengerName, level, challengeID, command)
end


function addonTable.handleDuelResult(message)
    local firstName, lastName = UnitName("player")
    local fullName = firstName .. " " .. lastName

    local winner, loser = message:match(addonTable.patternKnockout)

    if winner and loser then
        if winner == fullName then
            print("Duell-Ergebnis: Du hast GEWONNEN gegen " .. loser .. "!")
        elseif loser == fullName then
            addonTable:OnLocalDuelLoss(winner, loser)
        end
        return
    end

    local fleer, pursuer = message:match(addonTable.patternRetreat)

    if fleer and pursuer then
        if pursuer == fullName then
            print("Duell-Ergebnis: Du hast GEWONNEN, weil " .. fleer .. " abgehauen ist!")
        elseif fleer == fullName then
            addonTable:OnLocalDuelLoss(winner, loser)
        end
        return
    end
end

-- shows optional help message when the addon is loaded
function addonTable:PrintHelp()
    print("|cff2674cc[L|cffff0000i|rDL Roulette]|r Addon geladen. Version: " .. self.VERSION)
    print("|cff2674cc[L|cffff0000i|rDL Roulette]|r Verfügbare Befehle:")
    print("|cff2674cc/lidl test|r - Zeigt eine Test-Challenge an.")
    print("|cff2674cc/lidl test1|r - Zeigt eine Test-Meldung an.")
    print("|cff2674cc/lidl challenges|r - Listet alle verfügbaren Challenges auf.")
end

SLASH_LEVELROULETTE1 = "/lidl"

SlashCmdList["LEVELROULETTE"] = function(message)
    message = string.lower(message or "")

    if message == "test" then
        local level = UnitLevel("player") or 1
        addonTable:OnLocalLevelUp(level)
        return
    end

    if message == "test1" then
        local firstName, lastName = UnitName("player")
        local fullName = firstName .. " " .. lastName
        local level = UnitLevel("player") or 1
        local challengeID
        if LidlRouletteDB.settings.isRouletteEnabled == true then
            challengeID = addonTable.Roulette.Roll()
        end
        local challengeMessage = challengeID and (" und Challenge-ID " .. tostring(challengeID)) or ""
        print("|cff2674cc[L|cffff0000i|rDL Roulette]|r Test-Meldung für " .. fullName .. " mit Level " .. tostring(level) .. challengeMessage)

        addonTable.AnnouncementUi:ShowAnnouncement(fullName, nil, level, challengeID, "LEVELUP")
        return
    end

    if message == "challenges" then
        for id, challenge in ipairs(addonTable.Challenges) do
            print("|cff2674cc" .. tostring(id) .. ".|r " .. challenge.title)
        end
        return
    end

    addonTable:PrintHelp()
end