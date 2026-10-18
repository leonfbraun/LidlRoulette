local addonName, addonTable = ...

addonTable.TimerUi = {}

local TimerUi = addonTable.TimerUi

local timerFrame

local function CreateTimerFrame()
    local TimerFrame = CreateFrame("Frame", "MyChallengeTimerFrame", UIParent, "BackdropTemplate")
    TimerFrame:SetSize(280, 115)
    TimerFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -300, -50)
    TimerFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })

    TimerFrame:SetMovable(true)
    TimerFrame:EnableMouse(true)
    TimerFrame:RegisterForDrag("LeftButton")
    TimerFrame:SetScript("OnDragStart", TimerFrame.StartMoving)
    TimerFrame:SetScript("OnDragStop", TimerFrame.StopMovingOrSizing)

    TimerFrame.challengeName = CreateFrame("Button", nil, TimerFrame)
    TimerFrame.challengeName:SetPoint("TOP", TimerFrame, "TOP", 0, -5)
    TimerFrame.challengeName:SetSize(1, 24)
    TimerFrame.challengeName:EnableMouse(true)
    TimerFrame.challengeName:RegisterForDrag("LeftButton")
    TimerFrame.challengeName:SetScript("OnDragStart", function()
        TimerFrame:StartMoving()
    end)
    TimerFrame.challengeName:SetScript("OnDragStop", function()
        TimerFrame:StopMovingOrSizing()
    end)
    TimerFrame.challengeName:SetScript("OnEnter", function(self)
        if self.description then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(self.description, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    TimerFrame.challengeName:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    TimerFrame.challengeText = TimerFrame.challengeName:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    TimerFrame.challengeText:SetAllPoints()
    TimerFrame.challengeText:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    TimerFrame.challengeText:SetJustifyH("CENTER")

    TimerFrame.bar = CreateFrame("StatusBar", nil, TimerFrame)
    TimerFrame.bar:SetPoint("TOPLEFT", TimerFrame, "TOPLEFT", 8, -33)
    TimerFrame.bar:SetPoint("BOTTOMRIGHT", TimerFrame, "BOTTOMRIGHT", -8, 53)
    TimerFrame.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    TimerFrame.bar:SetStatusBarColor(0.2, 0.7, 1)

    TimerFrame.text = TimerFrame.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    TimerFrame.text:SetPoint("CENTER")

    TimerFrame.pauseButton = CreateFrame("Button", nil, TimerFrame, "UIPanelButtonTemplate")
    TimerFrame.pauseButton:SetSize(100, 22)
    TimerFrame.pauseButton:SetPoint("BOTTOMLEFT", TimerFrame, "BOTTOMLEFT", 18, 9)
    TimerFrame.pauseButton:SetText("Pause")

    TimerFrame.closeButton = CreateFrame("Button", nil, TimerFrame, "UIPanelButtonTemplate")
    TimerFrame.closeButton:SetSize(100, 22)
    TimerFrame.closeButton:SetPoint("BOTTOMRIGHT", TimerFrame, "BOTTOMRIGHT", -18, 9)
    TimerFrame.closeButton:SetText("Abbrechen")
    TimerFrame.closeButton:SetScript("OnClick", function()
        TimerUi.CancelChallengeTimer()
    end)

    TimerFrame:Hide()
    return TimerFrame
end

local function EndChallengeTimer(command)
    if not timerFrame or not timerFrame.challengeID then
        return
    end

    local challengeID = timerFrame.challengeID
    timerFrame.challengeID = nil
    timerFrame:SetScript("OnUpdate", nil)
    timerFrame:Hide()
    addonTable.Keybindings.Stop()
    addonTable.PopupChallengeUi.Stop()
    addonTable:OnLocalTimerEvent(challengeID, command)
end

function TimerUi.StartChallengeTimer(challengeID)
    local challenge = addonTable.Roulette.GetChallenge(challengeID)

    timerFrame = timerFrame or CreateTimerFrame()
    if timerFrame.challengeID then
        EndChallengeTimer("TIMERCANCELED")
    end
    timerFrame.challengeID = challengeID

    local duration = challenge.timeInSeconds

    local startTime = GetTime()
    local remaining = duration
    local paused = false

    local rarityColor = addonTable.Roulette.GetRarityColor(challenge.rarity)
    timerFrame.challengeText:SetText("[" .. challenge.title .. "]")
    timerFrame.challengeText:SetTextColor(rarityColor[1], rarityColor[2], rarityColor[3])
    timerFrame.challengeName:SetWidth(timerFrame.challengeText:GetStringWidth() + 4)
    timerFrame.challengeName.description = challenge.description
    timerFrame.pauseButton:SetText("Pause")
    timerFrame.pauseButton:SetScript("OnClick", function(self)
        if paused then
            startTime = GetTime() - (duration - remaining)
            paused = false
            addonTable.PopupChallengeUi.Resume()
            self:SetText("Pause")
        else
            remaining = math.max(0, duration - (GetTime() - startTime))
            if remaining <= 0 then
                EndChallengeTimer("TIMERFINISHED")
                return
            end
            paused = true
            addonTable.PopupChallengeUi.Pause()
            self:SetText("Fortsetzen")
        end
    end)

    timerFrame.bar:SetMinMaxValues(0, duration)
    timerFrame.bar:SetValue(duration)
    timerFrame:Show()

    if challenge.keybindingShuffle then
        addonTable.Keybindings.Start(challenge.keybindingShuffle)
    end
    if challenge.popupChallenge then
        addonTable.PopupChallengeUi.Start()
    end
    timerFrame:SetScript("OnUpdate", function(self)
        if paused then
            return
        end

        remaining = duration - (GetTime() - startTime)
        if remaining <= 0 then
            EndChallengeTimer("TIMERFINISHED")
            return
        end
        self.bar:SetValue(remaining)
        local totalSeconds = math.ceil(remaining)
        self.text:SetText(string.format("%d:%02d", math.floor(totalSeconds / 60), totalSeconds % 60))
    end)
end

function TimerUi.CancelChallengeTimer()
    EndChallengeTimer("TIMERCANCELED")
end