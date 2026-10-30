local addonName, addonTable = ...

addonTable.GuitarHeroUi = {}
local GuitarHeroUi = addonTable.GuitarHeroUi

local LANE_KEYS = { "W", "A", "S", "D" }
local LANE_COLORS = {
    W = { 0.25, 0.85, 0.42 },
    A = { 0.95, 0.78, 0.22 },
    S = { 0.9, 0.3, 0.28 },
    D = { 0.25, 0.62, 0.95 },
}
local COUNTDOWN_SECONDS = 3
local HIT_WINDOW = 0.24
local TICK_SECONDS = 0.1
local NOTE_TRAVEL_SECONDS = 1.1
local NOTE_FALL_DISTANCE = 260
local LANE_HIT_Y = 55
local MAX_MARKERS = 16

local frame
local songText
local scoreText
local statusText
local timeText
local laneLabels = {}
local laneFeedbackTexts = {}
local laneFeedbackExpires = {}
local laneOffsets = {}
local markerPool = {}
local activeMarkers = {}
local closeButton
local ticker
local sessionID = 0
local song
local challengeID
local chart
local stepDuration
local stepCount
local nextVisualStep = 0
local nextMissCheckStep = 0
local startedAt
local countdownAt
local lastDisplayedStep = -1
local judgedSteps = {}
local lastDisplayedSecond = -1
local lastCountdownNumber
local score = 0
local hits = 0
local misses = 0
local combo = 0
local active = false
local musicStarted = false

local function UpdateScore()
    scoreText:SetText(string.format("%05d    COMBO %d", score, combo))
end

local function ShowLaneFeedback(key, wasHit)
    local feedbackText = laneFeedbackTexts[key]
    if not feedbackText then
        return
    end

    feedbackText:SetText(wasHit and "HIT!" or "MISS!")
    if wasHit then
        feedbackText:SetTextColor(0.35, 1, 0.4)
    else
        feedbackText:SetTextColor(1, 0.25, 0.25)
    end
    feedbackText:Show()
    laneFeedbackExpires[key] = GetTime() + 0.65
end

local function ReleaseMarker(marker)
    marker.active = false
    marker.label:Hide()
end

local function AcquireMarker()
    for _, marker in ipairs(markerPool) do
        if not marker.active then
            marker.active = true
            marker.label:Show()
            return marker
        end
    end

    if #markerPool >= MAX_MARKERS then
        return nil
    end

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetFont("Fonts\\FRIZQT__.TTF", 28, "OUTLINE")
    local marker = { label = label, active = true }
    table.insert(markerPool, marker)
    label:Show()
    return marker
end

local function RemoveMarkerForStep(stepIndex)
    for index = #activeMarkers, 1, -1 do
        local marker = activeMarkers[index]
        if marker.stepIndex == stepIndex then
            ReleaseMarker(marker)
            table.remove(activeMarkers, index)
            return
        end
    end
end

local function StopGame(showResult)
    if not active then
        return
    end

    active = false
    sessionID = sessionID + 1
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    if musicStarted then
        StopMusic()
    end
    musicStarted = false
    frame:SetPropagateKeyboardInput(true)
    for _, marker in ipairs(activeMarkers) do
        ReleaseMarker(marker)
    end
    activeMarkers = {}

    if showResult then
        while nextMissCheckStep < stepCount do
            local key = chart:sub(nextMissCheckStep + 1, nextMissCheckStep + 1)
            if key ~= "-" and not judgedSteps[nextMissCheckStep] then
                misses = misses + 1
            end
            nextMissCheckStep = nextMissCheckStep + 1
        end
        statusText:SetText("Song beendet | Treffer: " .. hits .. " | Verfehlt: " .. misses)
        closeButton:SetText("Schließen")
        UpdateScore()
        print("|cff2674cc[L|cffff0000i|rDL Roulette]|r Guitar Hero: " .. song.title ..
            " beendet. Score: " .. score .. " | Treffer: " .. hits .. " | Verfehlt: " .. misses)
        addonTable:OnLocalTimerEvent(challengeID, "GUITARHEROFINISHED", score, song.title)
    else
        frame:Hide()
    end
end

local function HandleKeyPress(key)
    key = string.upper(key or "")
    if not active or not musicStarted or not LANE_COLORS[key] then
        return
    end

    local elapsed = GetTime() - startedAt - song.beatOffset
    local stepIndex = math.floor(elapsed / stepDuration + 0.5)
    local timingError = math.abs(elapsed - stepIndex * stepDuration)
    if stepIndex < 0 or stepIndex >= stepCount or timingError > HIT_WINDOW then
        return
    end

    local expectedKey = chart:sub(stepIndex + 1, stepIndex + 1)
    if expectedKey == "-" or judgedSteps[stepIndex] then
        return
    end

    judgedSteps[stepIndex] = true
    RemoveMarkerForStep(stepIndex)
    if key == expectedKey then
        hits = hits + 1
        combo = combo + 1
        score = score + math.max(50, math.floor(100 * (1 - timingError / HIT_WINDOW)))
        ShowLaneFeedback(expectedKey, true)
    else
        misses = misses + 1
        combo = 0
        ShowLaneFeedback(key, false)
        ShowLaneFeedback(expectedKey, false)
    end
    UpdateScore()
end

local function UpdateGame()
    if not active then
        return
    end

    if not musicStarted then
        local remaining = COUNTDOWN_SECONDS - (GetTime() - countdownAt)
        local countdown = math.ceil(remaining)
        if countdown > 0 then
            if countdown ~= lastCountdownNumber then
                lastCountdownNumber = countdown
                statusText:SetText("Start in " .. countdown)
            end
            return
        end

        musicStarted = true
        startedAt = GetTime()
        PlayMusic(song.music)
        statusText:SetText("Drücke die Taste, wenn der fallende Marker W A S D erreicht")
        return
    end

    local elapsed = GetTime() - startedAt
    local stepIndex = math.floor((elapsed - song.beatOffset + HIT_WINDOW) / stepDuration)
    if stepIndex >= 0 and stepIndex < stepCount and stepIndex ~= lastDisplayedStep then
        lastDisplayedStep = stepIndex
        local expectedKey = chart:sub(stepIndex + 1, stepIndex + 1)
        for laneKey, label in pairs(laneLabels) do
            local color = LANE_COLORS[laneKey]
            local alpha = laneKey == expectedKey and expectedKey ~= "-" and 1 or 0.35
            label:SetTextColor(color[1] * alpha, color[2] * alpha, color[3] * alpha)
        end
        UpdateScore()
    end

    local latestExpiredStep = math.floor((elapsed - song.beatOffset - HIT_WINDOW) / stepDuration)
    while nextMissCheckStep <= latestExpiredStep and nextMissCheckStep < stepCount do
        local key = chart:sub(nextMissCheckStep + 1, nextMissCheckStep + 1)
        if key ~= "-" and not judgedSteps[nextMissCheckStep] then
            misses = misses + 1
            combo = 0
            ShowLaneFeedback(key, false)
        end
        nextMissCheckStep = nextMissCheckStep + 1
    end

    local now = GetTime()
    for key, expiresAt in pairs(laneFeedbackExpires) do
        if now >= expiresAt then
            laneFeedbackTexts[key]:Hide()
            laneFeedbackExpires[key] = nil
        end
    end

    local generatedMarkers = 0
    while nextVisualStep < stepCount and generatedMarkers < MAX_MARKERS do
        local hitAt = song.beatOffset + nextVisualStep * stepDuration
        local timeUntilHit = hitAt - elapsed
        if timeUntilHit > NOTE_TRAVEL_SECONDS then
            break
        end

        local currentStep = nextVisualStep
        nextVisualStep = nextVisualStep + 1
        generatedMarkers = generatedMarkers + 1
        local key = chart:sub(currentStep + 1, currentStep + 1)
        if key ~= "-" and timeUntilHit >= -HIT_WINDOW then
            local marker = AcquireMarker()
            if marker then
            marker.stepIndex = currentStep
                marker.key = key
                marker.hitAt = hitAt
                marker.label:SetText(key)
                local color = LANE_COLORS[key]
                marker.label:SetTextColor(color[1], color[2], color[3])
                table.insert(activeMarkers, marker)
            end
        end
    end

    for index = #activeMarkers, 1, -1 do
        local marker = activeMarkers[index]
        local timeUntilHit = marker.hitAt - elapsed
        if timeUntilHit < -HIT_WINDOW then
            ReleaseMarker(marker)
            table.remove(activeMarkers, index)
        else
            local progress = 1 - timeUntilHit / NOTE_TRAVEL_SECONDS
            local y = LANE_HIT_Y + NOTE_FALL_DISTANCE * (1 - progress)
            marker.label:ClearAllPoints()
            marker.label:SetPoint("CENTER", frame, "BOTTOM", laneOffsets[marker.key], y)
        end
    end

    local currentSecond = math.floor(elapsed)
    if currentSecond ~= lastDisplayedSecond then
        lastDisplayedSecond = currentSecond
        timeText:SetText(string.format("%d:%02d", math.floor(currentSecond / 60), currentSecond % 60))
    end

    if elapsed >= song.duration then
        StopGame(true)
    end
end

local function Initialize()
    if frame then
        return
    end

    frame = CreateFrame("Frame", "LidlRouletteGuitarHeroFrame", UIParent, "BackdropTemplate")
    frame:SetSize(560, 420)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:EnableKeyboard(true)
    frame:SetPropagateKeyboardInput(true)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    frame:SetBackdropColor(0.035, 0.04, 0.055, 0.98)
    frame:SetBackdropBorderColor(0.72, 0.75, 0.8, 1)

    songText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    songText:SetPoint("TOP", frame, "TOP", 0, -16)
    songText:SetWidth(520)
    songText:SetJustifyH("CENTER")
    songText:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")

    scoreText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    scoreText:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -50)
    scoreText:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")

    timeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    timeText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -52)
    timeText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")

    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    statusText:SetPoint("TOP", frame, "TOP", 0, -72)
    statusText:SetWidth(520)
    statusText:SetJustifyH("CENTER")
    statusText:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")

    for index, key in ipairs(LANE_KEYS) do
        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        local laneOffset = (index - 2.5) * 112
        label:SetPoint("CENTER", frame, "BOTTOM", laneOffset, LANE_HIT_Y)
        label:SetFont("Fonts\\FRIZQT__.TTF", 32, "OUTLINE")
        label:SetText(key)
        local color = LANE_COLORS[key]
        label:SetTextColor(color[1], color[2], color[3], 0.35)
        laneLabels[key] = label
        laneOffsets[key] = laneOffset

        local feedbackText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        feedbackText:SetPoint("BOTTOM", label, "TOP", 0, 5)
        feedbackText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
        feedbackText:Hide()
        laneFeedbackTexts[key] = feedbackText
    end

    closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeButton:SetSize(110, 24)
    closeButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 12)
    closeButton:SetScript("OnClick", function()
        if active then
            StopGame(false)
        else
            frame:Hide()
        end
    end)

    frame:SetScript("OnKeyDown", function(_, key)
        HandleKeyPress(key)
    end)
    frame:Hide()
end

function GuitarHeroUi:Start(challengeIDArg)
    local songs = addonTable.GuitarHeroSongs or {}
    local validSongs = {}
    for _, candidate in ipairs(songs) do
        if type(candidate.bpm) == "number" and candidate.bpm >= 30 and candidate.bpm <= 300
            and type(candidate.duration) == "number" and candidate.duration > 0 and candidate.duration <= 180
            and type(candidate.beatOffset) == "number" and candidate.beatOffset >= 0 and candidate.beatOffset < candidate.duration
            and type(candidate.stepsPerBeat) == "number" and candidate.stepsPerBeat >= 1
            and candidate.stepsPerBeat <= 8 and candidate.stepsPerBeat == math.floor(candidate.stepsPerBeat)
            and type(candidate.chart) == "string" and #candidate.chart > 0 and #candidate.chart <= 1024
            and type(candidate.music) == "string" and candidate.music ~= "" then
            local candidateChart = candidate.chart:gsub("%s", ""):upper()
            if candidateChart:match("^[WASD%-]+$") then
                table.insert(validSongs, { song = candidate, chart = candidateChart })
            end
        end
    end

    if #validSongs == 0 then
        print("|cffff0000[Lidl Roulette]|r Guitar Hero hat keinen gültigen Song konfiguriert.")
        return
    end

    Initialize()
    if active then
        StopGame(false)
    end

    local selected = validSongs[math.random(#validSongs)]
    song = selected.song
    challengeID = challengeIDArg
    chart = selected.chart
    stepDuration = 60 / song.bpm / song.stepsPerBeat
    stepCount = math.min(#chart, math.floor((song.duration - song.beatOffset) / stepDuration) + 1)
    nextVisualStep = 0
    nextMissCheckStep = 0
    activeMarkers = {}
    countdownAt = GetTime()
    lastCountdownNumber = COUNTDOWN_SECONDS
    lastDisplayedStep = -1
    judgedSteps = {}
    laneFeedbackExpires = {}
    for _, feedbackText in pairs(laneFeedbackTexts) do
        feedbackText:Hide()
    end
    lastDisplayedSecond = -1
    score = 0
    hits = 0
    misses = 0
    combo = 0
    musicStarted = false
    active = true
    sessionID = sessionID + 1

    songText:SetText(song.title)
    statusText:SetText("Start in " .. COUNTDOWN_SECONDS)
    timeText:SetText("0:00")
    closeButton:SetText("Abbrechen")
    UpdateScore()
    for key, label in pairs(laneLabels) do
        local color = LANE_COLORS[key]
        label:SetTextColor(color[1], color[2], color[3], 0.35)
    end

    frame:SetPropagateKeyboardInput(true)
    frame:Show()
    frame:Raise()
    local currentSession = sessionID
    ticker = C_Timer.NewTicker(TICK_SECONDS, function()
        if currentSession == sessionID then
            UpdateGame()
        end
    end)
end