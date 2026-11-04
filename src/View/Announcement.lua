local addonName, addonTable = ...

addonTable.AnnouncementUi = {}

local AnnouncementUi = addonTable.AnnouncementUi

local announcementFrame
local playerAnnouncementText
local challengeTitleText
local challengeDescriptionText
local fadeOutAnimation
local hideTimer

function AnnouncementUi:Initialize()
    announcementFrame = CreateFrame("Frame", nil, UIParent)
    announcementFrame:SetSize(900, 150)
    announcementFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 350)
    announcementFrame:SetFrameStrata("TOOLTIP")

    playerAnnouncementText = announcementFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    playerAnnouncementText:SetFont("Fonts\\FRIZQT__.TTF", 26, "OUTLINE")
    playerAnnouncementText:SetPoint("TOP", announcementFrame, "TOP", 0, -10)
    playerAnnouncementText:SetWidth(880)
    playerAnnouncementText:SetJustifyH("CENTER")

    challengeTitleText = announcementFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    challengeTitleText:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
    challengeTitleText:SetPoint("TOP", playerAnnouncementText, "BOTTOM", 0, -8)
    challengeTitleText:SetWidth(880)
    challengeTitleText:SetJustifyH("CENTER")

    challengeDescriptionText = announcementFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    challengeDescriptionText:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    challengeDescriptionText:SetPoint("TOP", challengeTitleText, "BOTTOM", 0, -8)
    challengeDescriptionText:SetWidth(880)
    challengeDescriptionText:SetJustifyH("CENTER")
    challengeDescriptionText:SetWordWrap(true)

    fadeOutAnimation = announcementFrame:CreateAnimationGroup()
    local fade = fadeOutAnimation:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(1.5)
    fadeOutAnimation:SetScript("OnFinished", function()
        announcementFrame:Hide()
        announcementFrame:SetAlpha(1)
    end)

    announcementFrame:Hide()
end

function AnnouncementUi:ShowAnnouncement(playerName, challengerName, level, challengeID, command, comboHighScore, challengeSong, targetScore, taxSilver)
    local announcementMessage
    local challenge = challengeID and addonTable.Roulette.GetChallenge(challengeID)
    local compactTitle
    local compactDescription
    if command == "DEATH" then
        announcementMessage = "|cffffffff" .. playerName .. "|r ist mit Level " .. tostring(level) .. " gestorben"
    elseif command == "LEVELUP" then
        announcementMessage = "Ding, Level Up! |cffffffff" .. playerName .. "|r ist jetzt Level " .. tostring(level)
    elseif command == "DUEL" then
        announcementMessage = "|cffffffff" .. playerName .. "|r hat ein Duell gegen |cffffffff" .. challengerName .. "|r verloren"
    elseif command == "TIMERFINISHED" then
        announcementMessage = "Der Timer von |cffffffff" .. playerName .. "|r's Challenge ist abgelaufen!"
    elseif command == "TIMERCANCELED" then
        announcementMessage = "|cffffffff" .. playerName .. "|r hat den Challenge-Timer abgebrochen."
    elseif command == "GUITARHEROFINISHED" then
        announcementMessage = "|cffffffff" .. playerName .. "|r hat Guitar Hero gespielt!"
    elseif command == "OSUFINISHED" then
        announcementMessage = "|cffffffff" .. playerName .. "|r hat Osu! gespielt!"
    else
        return
    end

    local isComboChallenge = challenge and (challenge.bayonettaCombo or challenge.devilMayCryCombo)
    local isRhythmChallenge = command == "GUITARHEROFINISHED" or command == "OSUFINISHED"
    if isComboChallenge and (command == "TIMERFINISHED" or command == "TIMERCANCELED") then
        local timerStatus = command == "TIMERFINISHED" and "Timer beendet" or "Timer abgebrochen"
        announcementMessage = timerStatus .. " - |cffffffff" .. playerName .. "|r"
        local scoreUnit = challenge and challenge.bayonettaCombo and " Combo Points" or " Treffer"
        compactTitle = challenge.title .. (comboHighScore ~= nil and
            (" - Highscore: " .. tostring(comboHighScore) .. scoreUnit) or "")
    elseif isRhythmChallenge then
        local challengeName = challenge and challenge.title or (command == "GUITARHEROFINISHED" and "Guitar Hero" or "Osu!")
        announcementMessage = "|cffffffff" .. playerName .. "|r - " .. challengeName
        compactTitle = "Song: " .. tostring(challengeSong or "Unbekannt")
        compactDescription = "Score: " .. tostring(comboHighScore or "-") ..
            (targetScore and (" / " .. tostring(targetScore)) or "") .. " Punkte"
        if targetScore and comboHighScore ~= nil and comboHighScore >= targetScore then
            compactDescription = compactDescription .. " - |cff73ff8cZiel erreicht!|r"
        elseif targetScore and comboHighScore ~= nil then
            compactDescription = compactDescription .. " - |cffff4747Ziel verfehlt, Steuern: " ..
                tostring(taxSilver or addonTable:GetTaxSilver(level)) .. " Silber|r"
        end
    elseif comboHighScore ~= nil and (command == "TIMERFINISHED" or command == "TIMERCANCELED") then
        local scoreUnit = challenge and challenge.bayonettaCombo and " Combo Points" or " Treffer"
        announcementMessage = announcementMessage .. "\nCombo-Highscore: |cffffb52e" .. tostring(comboHighScore) .. scoreUnit .. "|r"
    end
    
    playerAnnouncementText:SetText(announcementMessage)
    print("|cff2674cc[L|cffff0000i|rDL Roulette]|r " .. announcementMessage)

    if(challengeID) then
        if compactTitle then
            challengeTitleText:SetText(compactTitle)
            challengeDescriptionText:SetText(compactDescription or "")
            print("|cff2674cc[L|cffff0000i|rDL Roulette]|r " .. compactTitle)
            if compactDescription then
                print("|cff2674cc[L|cffff0000i|rDL Roulette]|r " .. compactDescription)
            end
        else
            local rarityColorCode = addonTable.Roulette.GetRarityColorHexCode(challenge.rarity)
            local challengeTitle = "Challenge: |cff" .. rarityColorCode .. "[" .. challenge.title .. "]|r"

            challengeTitleText:SetText(challengeTitle)
            challengeDescriptionText:SetText(challenge.description)

            print("|cff2674cc[L|cffff0000i|rDL Roulette]|r " .. challengeTitle)
            print("|cff2674cc[L|cffff0000i|rDL Roulette]|r " .. challenge.description)
        end
    else
        challengeTitleText:SetText("")
        challengeDescriptionText:SetText("")
    end

    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
    if fadeOutAnimation:IsPlaying() then
        fadeOutAnimation:Stop()
    end
    announcementFrame:SetAlpha(1)
    announcementFrame:Show()
    PlaySound(8959)

    hideTimer = C_Timer.NewTimer(8, function()
        hideTimer = nil
        fadeOutAnimation:Play()
    end)
end
