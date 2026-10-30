local addonName, addonTable = ...

addonTable.Communication = {}

local Communication = addonTable.Communication

function Communication:Initialize()
    local success = C_ChatInfo.RegisterAddonMessagePrefix(addonTable.PREFIX)

    if not success then
        print("|cffff0000[Lidl Roulette]|r Konnte Kommunikations-Prefix nicht registrieren.")
        return false
    end

    return true
end

function Communication.SendMessage(command, playerName, level, challengeID, eventID, challengerName, comboHighScore)
    local message = string.format(
        "%s|%s|%d|%s|%s|%s|%s",
        command,
        playerName,
        level,
        challengeID and tostring(challengeID) or "-",
        eventID,
        challengerName or "-",
        comboHighScore ~= nil and tostring(comboHighScore) or "-"
    )

    local partyMessageSuccess, partyMessageErrorMessage = C_ChatInfo.SendAddonMessage(
        addonTable.PREFIX,
        message,
        "PARTY"
    )

    local guildMessageSuccess, guildMessageErrorMessage = C_ChatInfo.SendAddonMessage(
        addonTable.PREFIX,
        message,
        "GUILD"
    )

    if partyMessageSuccess == false and guildMessageSuccess == false then
        print("|cffff0000[Lidl Roulette]|r Nachricht konnte nicht gesendet werden.")

        if partyMessageErrorMessage then
            print("|cffff0000Fehler:|r " .. tostring(partyMessageErrorMessage))
        end

        if guildMessageErrorMessage then
            print("|cffff0000Fehler:|r " .. tostring(guildMessageErrorMessage))
        end
    end
end

function Communication:OnMessageReceived(prefix, message, _, sender)
    if prefix ~= addonTable.PREFIX or not message then
        return
    end

    local command, playerName, level, challengeID, eventID, challengerName, comboHighScore =
        strsplit("|", message)

    if command ~= "LEVELUP" and command ~= "DEATH" and command ~= "DUEL" and command ~= "TIMERFINISHED" and command ~= "TIMERCANCELED" then
        return
    end

    local playerLevel = tonumber(level)
    local playerChallengeID
    if challengeID ~= "-" then
        playerChallengeID = tonumber(challengeID)
        if not playerChallengeID then
            print("|cffff0000[Lidl Roulette]|r Ungültige Nachricht von " .. tostring(sender))
            return
        end
    end

    local playerComboHighScore
    if comboHighScore and comboHighScore ~= "-" then
        playerComboHighScore = tonumber(comboHighScore)
        if not playerComboHighScore or playerComboHighScore < 0 or playerComboHighScore % 1 ~= 0 then
            print("|cffff0000[Lidl Roulette]|r Ungültiger Combo-Highscore von " .. tostring(sender))
            return
        end
    end

    if not playerName or not playerLevel or not eventID or eventID == "" then
        print("|cffff0000[Lidl Roulette]|r Ungültige Nachricht von " .. tostring(sender))
        return
    end

    addonTable:OnRemoteEventRecieved(
        playerName,
        playerLevel,
        playerChallengeID,
        eventID,
        challengerName ~= "-" and challengerName or nil,
        command,
        playerComboHighScore
    )
end