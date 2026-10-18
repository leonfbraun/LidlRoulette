local addonName, addonTable = ...

addonTable.PopupChallengeUi = {}

local PopupChallengeUi = addonTable.PopupChallengeUi
local schedulerFrame = CreateFrame("Frame")
schedulerFrame:SetSize(1, 1)
schedulerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT")
local popupFrames = {}
local activePopups = {}
local activePopupOrder = {}
local activePopupCount = 0
local challengeActive = false
local challengePaused = false
local nextPopupAt
local pausedAt
local previousPopupIndex
local previousSizeIndex
local maxActivePopups = 10
local popupSizes = {
    { width = 440, height = 240 },
    { width = 560, height = 310 },
    { width = 680, height = 380 },
}

schedulerFrame:Show()

local popupMessages = {
    {
        title = "SUPER PC CLEANER 2000",
        message = "Ihr Computer hat 847 kritische Probleme! Registrieren Sie sich JETZT, um sie alle zu beheben.",
        style = "browser",
        action = "Jetzt registrieren",
    },
    {
        title = "MegaCodec-Pro herunterladen",
        message = "Download wird vorbereitet. Bitte schließen Sie dieses Fenster nicht.",
        detail = "Verbindung zu mirror-7.example.invalid wird hergestellt ...",
        style = "browser",
        action = "Download abbrechen",
        progress = {
            label = "Download läuft",
            start = 4,
            duration = 36,
            stuckAt = 99,
        },
    },
    {
        title = "SIE HABEN GEWONNEN!!!",
        message = "Herzlichen Glückwunsch! Sie sind unser 1.000.000ster Besucher. Ihr Preis wartet auf Sie!",
        style = "browser",
        action = "Gewinn abholen",
    },
    {
        title = "Unbekannte Symbolleiste",
        message = "Die fantastische SearchBuddy-Leiste möchte Ihre Startseite und Suchmaschine aktualisieren.",
        style = "browser",
        action = "Jetzt installieren",
    },
    {
        title = "WICHTIGE SICHERHEITSWARNUNG",
        message = "Ihr kostenloser Testschutz läuft gleich ab. Klicken Sie hier, um maximalen Schutz zu aktivieren!",
        style = "browser",
        action = "Schutz aktivieren",
    },
    {
        title = "System wird überprüft",
        message = "Der kostenlose Sicherheitscheck durchsucht jetzt Ihre Dateien.",
        detail = "Verdächtige Einträge gefunden: 37",
        progress = {
            label = "Schnellscan",
            start = 12,
            duration = 24,
            stuckAt = 100,
        },
    },
    {
        title = "Updates werden installiert",
        message = "Bitte warten Sie, während wichtige Komponenten eingerichtet werden.",
        detail = "Installiere Web-Booster und SearchBuddy ...",
        progress = {
            label = "Installation",
            start = 0,
            duration = 42,
            stuckAt = 97,
        },
    },
    {
        title = "Download abgeschlossen",
        message = "MegaCodec-Pro ist bereit. Installieren Sie jetzt das optionale Web-Booster-Paket!",
        detail = "Empfohlenes Zusatzpaket: Toolbar Plus (vorgewählt)",
        style = "browser",
        action = "Jetzt installieren",
    },
    {
        title = ":( Ihr PC hat ein Problem festgestellt",
        message = "MegaCodec-Pro ist auf ein unerwartetes Problem gestoßen. Keine Sorge: Es wurde nichts gespeichert, verschlüsselt oder beschädigt.",
        detail = "Fehlercode: LIDL_RLT_0xBEEF\nUrsache: zu viele fragwürdige Toolbars",
        style = "blueScreen",
    },
    {
        title = "Download Manager - Eingabeaufforderung",
        message = "FileCleanerPro wird heruntergeladen ...",
        style = "terminal",
        terminalLines = {
            "C:\\> download virus_Setup.exe",
            "Verbinde mit mirror-7.example.invalid ...",
            "Server gefunden: 203.0.113.42",
            "Lade virus_Setup_Setup.exe herunter ...",
            "[======................]  28%  2.8 MB / 10.0 MB",
            "[============..........]  56%  5.6 MB / 10.0 MB",
            "[==================....]  84%  8.4 MB / 10.0 MB",
            "Download abgeschlossen: 10.0 MB",
            "C:\\> _",
        },
    },
}

local popupStyles = {
    default = {
        background = { 0.78, 0.78, 0.78, 1 },
        border = { 0.95, 0.95, 0.95, 1 },
        titleBar = { 0.02, 0.19, 0.55, 1 },
        title = { 1, 1, 1, 1 },
        text = { 0.05, 0.05, 0.05, 1 },
        detail = { 0.18, 0.18, 0.18, 1 },
    },
    blueScreen = {
        background = { 0.02, 0.27, 0.62, 1 },
        border = { 0.55, 0.78, 1, 1 },
        titleBar = { 0.02, 0.27, 0.62, 1 },
        title = { 1, 1, 1, 1 },
        text = { 1, 1, 1, 1 },
        detail = { 0.86, 0.93, 1, 1 },
    },
    terminal = {
        background = { 0.015, 0.02, 0.015, 1 },
        border = { 0.38, 0.42, 0.38, 1 },
        titleBar = { 0.14, 0.15, 0.14, 1 },
        title = { 0.35, 1, 0.38, 1 },
        text = { 0.35, 1, 0.38, 1 },
        detail = { 0.35, 1, 0.38, 1 },
    },
    browser = {
        background = { 0.94, 0.94, 0.94, 1 },
        border = { 0.55, 0.55, 0.55, 1 },
        titleBar = { 0.78, 0.8, 0.83, 1 },
        title = { 0.12, 0.12, 0.12, 1 },
        text = { 0.08, 0.08, 0.08, 1 },
        detail = { 0.25, 0.25, 0.25, 1 },
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
    popupFrame.titleBar = titleBar

    local browserAddressBar = popupFrame:CreateTexture(nil, "ARTWORK")
    browserAddressBar:SetPoint("TOPLEFT", popupFrame, "TOPLEFT", 14, -48)
    browserAddressBar:SetPoint("TOPRIGHT", popupFrame, "TOPRIGHT", -14, -48)
    browserAddressBar:SetHeight(26)
    browserAddressBar:SetColorTexture(1, 1, 1, 1)
    popupFrame.browserAddressBar = browserAddressBar

    popupFrame.browserAddress = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    popupFrame.browserAddress:SetPoint("LEFT", browserAddressBar, "LEFT", 8, 0)
    popupFrame.browserAddress:SetPoint("RIGHT", browserAddressBar, "RIGHT", -8, 0)
    popupFrame.browserAddress:SetJustifyH("LEFT")
    popupFrame.browserAddress:SetText("http://totally-safe.example.invalid")

    popupFrame.title = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    popupFrame.title:SetPoint("LEFT", titleBar, "LEFT", 12, 0)
    popupFrame.title:SetPoint("RIGHT", titleBar, "RIGHT", -38, 0)
    popupFrame.title:SetJustifyH("LEFT")

    popupFrame.message = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    popupFrame.message:SetPoint("TOPLEFT", popupFrame, "TOPLEFT", 26, -86)
    popupFrame.message:SetPoint("TOPRIGHT", popupFrame, "TOPRIGHT", -26, -86)
    popupFrame.message:SetJustifyH("CENTER")
    popupFrame.message:SetJustifyV("MIDDLE")
    popupFrame.message:SetWordWrap(true)

    popupFrame.detail = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popupFrame.detail:SetPoint("TOPLEFT", popupFrame.message, "BOTTOMLEFT", 0, -10)
    popupFrame.detail:SetPoint("TOPRIGHT", popupFrame.message, "BOTTOMRIGHT", 0, -10)
    popupFrame.detail:SetJustifyH("CENTER")
    popupFrame.detail:SetWordWrap(true)

    popupFrame.terminalText = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popupFrame.terminalText:SetPoint("TOPLEFT", popupFrame, "TOPLEFT", 22, -62)
    popupFrame.terminalText:SetPoint("BOTTOMRIGHT", popupFrame, "BOTTOMRIGHT", -22, 30)
    popupFrame.terminalText:SetFont("Fonts\\ARIALN.TTF", 14, "OUTLINE")
    popupFrame.terminalText:SetJustifyH("LEFT")
    popupFrame.terminalText:SetJustifyV("TOP")
    popupFrame.terminalText:SetWordWrap(true)
    popupFrame.terminalText:Hide()

    popupFrame.progressBar = CreateFrame("StatusBar", nil, popupFrame)
    popupFrame.progressBar:SetPoint("BOTTOMLEFT", popupFrame, "BOTTOMLEFT", 22, 54)
    popupFrame.progressBar:SetPoint("BOTTOMRIGHT", popupFrame, "BOTTOMRIGHT", -22, 54)
    popupFrame.progressBar:SetHeight(18)
    popupFrame.progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    popupFrame.progressBar:SetStatusBarColor(0.12, 0.55, 0.9)
    popupFrame.progressBar:SetMinMaxValues(0, 100)

    local progressBackground = popupFrame.progressBar:CreateTexture(nil, "BACKGROUND")
    progressBackground:SetAllPoints()
    progressBackground:SetColorTexture(0.02, 0.02, 0.02, 1)

    popupFrame.progressText = popupFrame.progressBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popupFrame.progressText:SetPoint("CENTER", popupFrame.progressBar, "CENTER")
    popupFrame.progressBar:Hide()

    popupFrame.closeButton = CreateFrame("Button", nil, popupFrame, "UIPanelCloseButton")
    popupFrame.closeButton:SetPoint("TOPRIGHT", popupFrame, "TOPRIGHT", -2, -2)
    popupFrame.closeButton:SetScript("OnClick", function()
        popupFrame:Hide()
        popupFrame:SetScript("OnUpdate", nil)
        activePopups[popupFrame] = nil
        activePopupCount = activePopupCount - 1
        for index, activePopup in ipairs(activePopupOrder) do
            if activePopup == popupFrame then
                table.remove(activePopupOrder, index)
                break
            end
        end
        PopupChallengeUi.UpdatePopupLayers()
    end)

    popupFrame.actionButton = CreateFrame("Button", nil, popupFrame, "UIPanelButtonTemplate")
    popupFrame.actionButton:SetSize(160, 26)
    popupFrame.actionButton:SetPoint("BOTTOMRIGHT", popupFrame, "BOTTOMRIGHT", -22, 14)
    popupFrame.actionButton:Hide()

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

local function GetRandomPopupSize()
    local sizeIndexes = {}
    for index = 1, #popupSizes do
        if index ~= previousSizeIndex then
            table.insert(sizeIndexes, index)
        end
    end
    local sizeIndex = sizeIndexes[math.random(#sizeIndexes)]
    previousSizeIndex = sizeIndex

    return popupSizes[sizeIndex]
end

local function PositionPopup(popupFrame)
    local size = popupFrame.stackSize
    local width = math.min(size.width, math.floor(UIParent:GetWidth() - 32))
    local height = math.min(size.height, math.floor(UIParent:GetHeight() - 32))
    popupFrame:SetSize(width, height)
    popupFrame:ClearAllPoints()

    local maxX = math.max(0, math.floor((UIParent:GetWidth() - width) / 2))
    local maxY = math.max(0, math.floor((UIParent:GetHeight() - height) / 2))
    popupFrame:SetPoint(
        "CENTER",
        UIParent,
        "CENTER",
        math.random(-maxX, maxX),
        math.random(-maxY, maxY)
    )
end

function PopupChallengeUi.UpdatePopupLayers()
    for index, popupFrame in ipairs(activePopupOrder) do
        local frameLevel = UIParent:GetFrameLevel() + index * 10
        popupFrame:SetFrameLevel(frameLevel)
        popupFrame.closeButton:SetFrameLevel(frameLevel + 1)
        popupFrame.actionButton:SetFrameLevel(frameLevel + 1)
    end
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
    popupFrame.detail:SetText(popup.detail or "")
    local style = popupStyles[popup.style] or popupStyles.default
    popupFrame:SetBackdropColor(unpack(style.background))
    popupFrame:SetBackdropBorderColor(unpack(style.border))
    popupFrame.titleBar:SetColorTexture(unpack(style.titleBar))
    popupFrame.title:SetTextColor(unpack(style.title))
    popupFrame.message:SetTextColor(unpack(style.text))
    popupFrame.detail:SetTextColor(unpack(style.detail))
    if popup.style == "browser" then
        popupFrame.browserAddressBar:Show()
        popupFrame.browserAddress:Show()
    else
        popupFrame.browserAddressBar:Hide()
        popupFrame.browserAddress:Hide()
    end
    if popup.action then
        popupFrame.actionButton:SetText(popup.action)
        popupFrame.actionButton:Show()
    else
        popupFrame.actionButton:Hide()
    end
    popupFrame.message:SetShown(popup.style ~= "terminal")
    popupFrame.detail:SetShown(popup.style ~= "terminal")
    popupFrame.terminalText:Hide()
    popupFrame.progressBar:Hide()
    popupFrame:SetScript("OnUpdate", nil)
    if popup.style == "terminal" then
        local visibleLineCount = 0
        local elapsed = 0
        popupFrame.terminalText:Show()
        popupFrame.terminalText:SetText("")
        popupFrame:SetScript("OnUpdate", function(self, delta)
            if challengePaused then
                return
            end

            elapsed = elapsed + delta
            if elapsed >= 1.2 and visibleLineCount < #popup.terminalLines then
                elapsed = 0
                visibleLineCount = visibleLineCount + 1
                popupFrame.terminalText:SetText(
                    table.concat(popup.terminalLines, "\n", 1, visibleLineCount)
                )
            end
        end)
    elseif popup.progress then
        local elapsed = 0
        local progress = popup.progress
        popupFrame.progressBar:SetValue(progress.start)
        popupFrame.progressText:SetText(progress.label .. ": " .. progress.start .. "%")
        popupFrame.progressBar:Show()
        popupFrame:SetScript("OnUpdate", function(self, delta)
            if challengePaused then
                return
            end

            elapsed = elapsed + delta
            local percent = math.min(
                progress.stuckAt,
                progress.start + (elapsed / progress.duration) * (progress.stuckAt - progress.start)
            )
            percent = math.floor(percent)
            self.progressBar:SetValue(percent)
            self.progressText:SetText(progress.label .. ": " .. percent .. "%")
            if percent >= progress.stuckAt then
                self.progressText:SetText(progress.label .. ": " .. percent .. "% - bitte warten ...")
            end
        end)
    end
    popupFrame.stackSize = GetRandomPopupSize()
    PositionPopup(popupFrame)
    popupFrame:Show()
    activePopups[popupFrame] = true
    table.insert(activePopupOrder, popupFrame)
    activePopupCount = activePopupCount + 1
    PopupChallengeUi.UpdatePopupLayers()
end

function PopupChallengeUi.Start()
    for popupFrame in pairs(activePopups) do
        popupFrame:Hide()
    end
    activePopups = {}
    activePopupOrder = {}
    activePopupCount = 0
    challengeActive = true
    challengePaused = false
    pausedAt = nil
    previousPopupIndex = nil
    previousSizeIndex = nil
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
        popupFrame:SetScript("OnUpdate", nil)
        popupFrame:Hide()
    end
    activePopups = {}
    activePopupOrder = {}
    activePopupCount = 0
end
