local addonName, addonTable = ...

addonTable.ChallengeRouletteUi = {}
local ChallengeRouletteUi = addonTable.ChallengeRouletteUi

local frame
local titleText
local playerText
local rarityText
local descriptionText
local wheelText

local animationRunning = false

function ChallengeRouletteUi:Initialize()
    if frame then
        return
    end

    frame = CreateFrame("Frame", "ChallengeRouletteFrame", UIParent)

    frame:SetSize(600, 350)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.03, 0.03, 0.03, 0.96)

    titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetFont("Fonts\\FRIZQT__.TTF", 35, "OUTLINE")
    titleText:SetPoint("TOP", frame, "TOP", 0, -20)

    playerText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    playerText:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    playerText:SetPoint("TOP", titleText, "BOTTOM", 0, -10)

    wheelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    wheelText:SetFont("Fonts\\FRIZQT__.TTF", 30, "OUTLINE")
    wheelText:SetPoint("CENTER", frame, "CENTER", 0, 20)
    wheelText:SetWidth(400)

    rarityText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    rarityText:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    rarityText:SetPoint("TOP", wheelText, "BOTTOM", 0, -15)
    rarityText:SetWidth(400)

    descriptionText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    descriptionText:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    descriptionText:SetPoint("TOP", rarityText, "BOTTOM", 0, -22)
    descriptionText:SetWidth(400)
    descriptionText:SetJustifyH("CENTER")

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeButton:SetSize(100, 25)
    closeButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 15)
    closeButton:SetText("Schließen")
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    frame:SetScript("OnUpdate", function(self, elapsed)
        if animationRunning then
            ChallengeRouletteUi:UpdateAnimation(elapsed)
        end
    end)
end

function ChallengeRouletteUi:ShowChallenge(playerName, level, challengeID, challengeReason)
    local challenge = addonTable.Roulette:GetChallenge(challengeID)

    if not challenge then
        print("|cffff0000[Lidl Roulette]|r Unbekannte Challenge-ID: " ..
            tostring(challengeID))
        return
    end

    self:Initialize()
    frame:Show()

    if challengeReason == "death" then 
        titleText:SetText("You died!")
        playerText:SetText(playerName .. " ist mit Level " .. tostring(level) .. " gestorben.")
    elseif challengeReason == "levelup" then
        titleText:SetText("LEVEL UP!")
        playerText:SetText(playerName .. " ist jetzt Level " .. tostring(level))
    elseif challengeReason == "duel" then 
        titleText:SetText("Duell verloren :(")
        playerText:SetText(playerName .. " wurde mit Level " ..  tostring(level) .. " im Duell besiegt")
    end
    
    wheelText:SetText("● ● ●")
    rarityText:SetText("")
    descriptionText:SetText("")

    self.targetChallengeID = challengeID
    self.animationElapsed = 0
    self.animationDuration = 2.5
    self.animationAccumulator = 0
    self.animationInterval = 0.08

    animationRunning = true
end

function ChallengeRouletteUi:UpdateAnimation(elapsed)
    self.animationElapsed = self.animationElapsed + elapsed
    self.animationAccumulator = self.animationAccumulator + elapsed

    if self.animationElapsed >= self.animationDuration then
        animationRunning = false
        self:FinishAnimation()
        return
    end

    if self.animationAccumulator >= self.animationInterval then
        self.animationAccumulator = 0

        local randomID = addonTable.Roulette.Roll()
        local challenge = addonTable.Roulette:GetChallenge(randomID)

        if challenge then
            wheelText:SetText("[" .. challenge.title .. "]")
            local rarityColor = addonTable.Roulette.GetRarityColor(challenge.rarity)
            wheelText:SetTextColor(rarityColor[1], rarityColor[2], rarityColor[3])
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end

        local progress = self.animationElapsed / self.animationDuration
        self.animationInterval = 0.05 + (progress * 0.30)
    end
end

function ChallengeRouletteUi:FinishAnimation()
    local challenge = addonTable.Roulette:GetChallenge(self.targetChallengeID)

    if not challenge then
        return
    end

    wheelText:SetText("[" .. challenge.title .. "]")
    local rarityColor = addonTable.Roulette.GetRarityColor(challenge.rarity)
    wheelText:SetTextColor(rarityColor[1], rarityColor[2], rarityColor[3])

    rarityText:SetText(challenge.rarity)
    rarityText:SetTextColor(rarityColor[1], rarityColor[2], rarityColor[3])
    descriptionText:SetText(challenge.description)
    PlaySound(8960)

    local rarityColorCode = addonTable.Roulette.GetRarityColorHexCode(challenge.rarity)
    local challengeTitle = "Challenge: |cff" .. rarityColorCode .. "[" .. challenge.title .. "]|r"
    print("|cff2674cc[L|cffff0000i|rDL Roulette]|r " .. challengeTitle)
    print("|cff2674cc[L|cffff0000i|rDL Roulette]|r " .. challenge.description)
end