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

function AnnouncementUi:ShowChallengeAnnouncement(playerName, level, challengeID, reason)
    local challenge = addonTable.Roulette:GetChallenge(challengeID)
    if not challenge then
        return
    end
    
    local announcementMessage
    if reason == "death" then
        announcementMessage = "|cffffffff" .. playerName .. "|r ist mit Level " .. tostring(level) .. " gestorben."
    elseif reason == "levelup" then
        announcementMessage = "Ding, Level Up! |cffffffff" .. playerName .. "|r ist jetzt Level " .. tostring(level)
    else
        return
    end
    
    playerAnnouncementText:SetText(announcementMessage)
    local rarityColorCode = addonTable.Roulette.GetRarityColorHexCode(challenge.rarity)
    
    local challengeTitle = "Challenge: |cff" .. rarityColorCode .. "[" .. challenge.title .. "]|r"
    challengeTitleText:SetText(challengeTitle)

    challengeDescriptionText:SetText(challenge.description)

    print("|cff2674cc[L|cffff0000i|rDL Roulette]|r " .. announcementMessage)
    print("|cff2674cc[L|cffff0000i|rDL Roulette]|r " .. challengeTitle)
    print("|cff2674cc[L|cffff0000i|rDL Roulette]|r " .. challenge.description)

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