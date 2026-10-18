local addonName, addonTable = ...

addonTable.TimerUi = {}

local TimerUi = addonTable.TimerUi

local function CreateTimerFrame()
    local TimerFrame = CreateFrame("Frame", "MyChallengeTimerFrame", UIParent, "BackdropTemplate")
    TimerFrame:SetSize(220, 40)
    TimerFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -350, -150)
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

    TimerFrame.bar = CreateFrame("StatusBar", nil, TimerFrame)
    TimerFrame.bar:SetPoint("TOPLEFT", 6, -6)
    TimerFrame.bar:SetPoint("BOTTOMRIGHT", -6, 6)
    TimerFrame.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    TimerFrame.bar:SetStatusBarColor(0.2, 0.7, 1)

    TimerFrame.text = TimerFrame.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    TimerFrame.text:SetPoint("CENTER")

    TimerFrame:Hide()
    return TimerFrame
end

local timerFrame

function TimerUi.StartChallengeTimer(challengeID)
    timerFrame = timerFrame or CreateTimerFrame()

    local challenge = addonTable.Roulette.GetChallenge(challengeID)
    local duration = challenge.timeInSeconds

    local startTime = GetTime()
    timerFrame.bar:SetMinMaxValues(0, duration)
    timerFrame:Show()

    timerFrame:SetScript("OnUpdate", function(self)
        local remaining = duration - (GetTime() - startTime)
        if remaining <= 0 then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            if onFinish then onFinish() end
            return
        end
        self.bar:SetValue(remaining)
        self.text:SetText(string.format("%d:%02d", remaining / 60, remaining % 60))
    end)
end

function TimerUi.CancelChallengeTimer()
    if timerFrame then
        timerFrame:SetScript("OnUpdate", nil)
        timerFrame:Hide()
    end
end