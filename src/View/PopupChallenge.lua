local addonName, addonTable = ...

addonTable.PopupChallengeUi = {}

local PopupChallengeUi = addonTable.PopupChallengeUi
local schedulerFrame = CreateFrame("Frame")
schedulerFrame:SetSize(1, 1)
schedulerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT")
local popupFrames = {}
local activePopups = {}
local activePopupCount = 0
local challengeActive = false
local challengePaused = false
local nextPopupAt
local pausedAt
local previousPopupIndex
local previousSizeIndex
local previousPositionIndex
local maxActivePopups = 4
local popupSizes = {
    { width = 440, height = 240 },
    { width = 560, height = 310 },
    { width = 680, height = 380 },
}
local popupPositions = {
    { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
    { point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = 105 },
    { point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = 65 },
}

schedulerFrame:Show()

local popupMessages = {
    {
        title = "SUPER PC CLEANER 2000",
        message = "Ihr Computer hat 847 kritische Probleme! Registrieren Sie sich JETZT, um sie alle zu beheben.",
        button = "Schließen",
    },
    {
        title = "SIE HABEN GEWONNEN!!!",
        message = "Herzlichen Glückwunsch! Sie sind unser 1.000.000ster Besucher. Ihr Preis wartet auf Sie!",
        button = "Schließen",
    },
    {
        title = "Unbekannte Symbolleiste",
        message = "Die fantastische SearchBuddy-Leiste möchte Ihre Startseite und Suchmaschine aktualisieren.",
        button = "Schließen",
    },
    {
        title = "WICHTIGE SICHERHEITSWARNUNG",
        message = "Ihr kostenloser Testschutz läuft gleich ab. Klicken Sie hier, um maximalen Schutz zu aktivieren!",
        button = "Schließen",
    },
    {
        title = "Download abgeschlossen",
        message = "MegaCodec-Pro ist bereit. Installieren Sie jetzt das optionale Web-Booster-Paket!",
        button = "Schließen",
    },
}

local function ScheduleNextPopup()
    if challengeActive then
        nextPopupAt = GetTime() + math.random(8, 20)
    end
end

local function CreatePopup()
    local popupFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popupFrame:SetFrameStrata("DIALOG")
    popupFrame:SetClampedToScreen(true)
    popupFrame:EnableMouse(true)
    popupFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    popupFrame:SetBackdropColor(0.08, 0.07, 0.05, 1)
    popupFrame:SetBackdropBorderColor(0.85, 0.72, 0.38, 1)

    local titleBar = popupFrame:CreateTexture(nil, "ARTWORK")
    titleBar:SetPoint("TOPLEFT", popupFrame, "TOPLEFT", 8, -8)
    titleBar:SetPoint("TOPRIGHT", popupFrame, "TOPRIGHT", -8, -8)
    titleBar:SetHeight(36)
    titleBar:SetColorTexture(0.05, 0.12, 0.48, 1)

    popupFrame.title = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    popupFrame.title:SetPoint("LEFT", titleBar, "LEFT", 12, 0)
    popupFrame.title:SetPoint("RIGHT", titleBar, "RIGHT", -10, 0)
    popupFrame.title:SetJustifyH("LEFT")

    popupFrame.message = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    popupFrame.message:SetPoint("TOPLEFT", popupFrame, "TOPLEFT", 26, -68)
    popupFrame.message:SetPoint("TOPRIGHT", popupFrame, "TOPRIGHT", -26, -68)
    popupFrame.message:SetJustifyH("CENTER")
    popupFrame.message:SetJustifyV("MIDDLE")
    popupFrame.message:SetWordWrap(true)

    local fakeUrl = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fakeUrl:SetPoint("BOTTOMLEFT", popupFrame, "BOTTOMLEFT", 22, 46)
    fakeUrl:SetText("http://totally-safe.example.invalid")

    popupFrame.dismissButton = CreateFrame("Button", nil, popupFrame, "UIPanelButtonTemplate")
    popupFrame.dismissButton:SetSize(150, 28)
    popupFrame.dismissButton:SetPoint("BOTTOMRIGHT", popupFrame, "BOTTOMRIGHT", -20, 12)
    popupFrame.dismissButton:SetScript("OnClick", function()
        popupFrame:Hide()
        activePopups[popupFrame] = nil
        activePopupCount = activePopupCount - 1
    end)

    popupFrame:Hide()
    table.insert(popupFrames, popupFrame)
    return popupFrame
end

local function GetPopupFrame()
    for _, popupFrame in ipairs(popupFrames) do
        if not activePopups[popupFrame] then
            return popupFrame
        end
    end

    return CreatePopup()
end

local function PositionPopup(popupFrame)
    local sizeIndexes = {}
    for index = 1, #popupSizes do
        if index ~= previousSizeIndex then
            table.insert(sizeIndexes, index)
        end
    end
    local sizeIndex = sizeIndexes[math.random(#sizeIndexes)]
    previousSizeIndex = sizeIndex

    local size = popupSizes[sizeIndex]
    local width = math.min(size.width, math.floor(UIParent:GetWidth() - 32))
    local height = math.min(size.height, math.floor(UIParent:GetHeight() - 32))
    popupFrame:SetSize(width, height)
    popupFrame:ClearAllPoints()
    local positionIndexes = {}
    for index = 1, #popupPositions do
        if index ~= previousPositionIndex then
            table.insert(positionIndexes, index)
        end
    end
    local positionIndex = positionIndexes[math.random(#positionIndexes)]
    previousPositionIndex = positionIndex

    local position = popupPositions[positionIndex]
    popupFrame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
end

local function ShowRandomPopup()
    local popupFrame = GetPopupFrame()
    local availablePopupIndexes = {}
    for popupIndex = 1, #popupMessages do
        if popupIndex ~= previousPopupIndex then
            table.insert(availablePopupIndexes, popupIndex)
        end
    end
    local popupIndex = availablePopupIndexes[math.random(#availablePopupIndexes)]
    previousPopupIndex = popupIndex

    local popup = popupMessages[popupIndex]
    popupFrame.title:SetText(popup.title)
    popupFrame.message:SetText(popup.message)
    popupFrame.dismissButton:SetText(popup.button)
    PositionPopup(popupFrame)
    popupFrame:Show()
    activePopups[popupFrame] = true
    activePopupCount = activePopupCount + 1
end

function PopupChallengeUi.Start()
    for popupFrame in pairs(activePopups) do
        popupFrame:Hide()
    end
    activePopups = {}
    activePopupCount = 0
    challengeActive = true
    challengePaused = false
    pausedAt = nil
    previousPopupIndex = nil
    previousSizeIndex = nil
    previousPositionIndex = nil
    ScheduleNextPopup()
    schedulerFrame:SetScript("OnUpdate", function()
        if challengeActive and not challengePaused and GetTime() >= nextPopupAt then
            if activePopupCount < maxActivePopups then
                ShowRandomPopup()
            end
            ScheduleNextPopup()
        end
    end)
end

function PopupChallengeUi.Pause()
    if challengeActive and not challengePaused then
        challengePaused = true
        pausedAt = GetTime()
    end
end

function PopupChallengeUi.Resume()
    if challengeActive and challengePaused then
        nextPopupAt = nextPopupAt + (GetTime() - pausedAt)
        challengePaused = false
        pausedAt = nil
    end
end

function PopupChallengeUi.Stop()
    challengeActive = false
    challengePaused = false
    pausedAt = nil
    nextPopupAt = nil
    schedulerFrame:SetScript("OnUpdate", nil)
    for popupFrame in pairs(activePopups) do
        popupFrame:Hide()
    end
    activePopups = {}
    activePopupCount = 0
end
