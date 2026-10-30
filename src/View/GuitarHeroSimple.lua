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

local frame
local songText
local scoreText
local statusText
local timeText
local laneLabels = {}
local closeButton
local ticker
local sessionID = 0
local song
local chart
local beatDuration
local beatCount
local startedAt
local countdownAt
local lastDisplayedBeat = -1
local judgedBeat = -1
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

    if showResult then
        if lastDisplayedBeat >= 0 and judgedBeat ~= lastDisplayedBeat then
            misses = misses + 1
        end
        statusText:SetText("Song beendet | Treffer: " .. hits .. " | Verfehlt: " .. misses)
        closeButton:SetText("Schließen")
        UpdateScore()
        print("|cff2674cc[L|cffff0000i|rDL Roulette]|r Guitar Hero: " .. song.title ..
            " beendet. Score: " .. score .. " | Treffer: " .. hits .. " | Verfehlt: " .. misses)
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
    local beatIndex = math.floor(elapsed / beatDuration + 0.5)
    local timingError = math.abs(elapsed - beatIndex * beatDuration)
    if beatIndex < 0 or beatIndex >= beatCount or timingError > HIT_WINDOW or judgedBeat == beatIndex then
        misses = misses + 1
        combo = 0
        UpdateScore()
        return
    end

    judgedBeat = beatIndex
    local expectedKey = chart:sub(beatIndex % #chart + 1, beatIndex % #chart + 1)
    if key == expectedKey then
        hits = hits + 1
        combo = combo + 1
        score = score + math.max(50, math.floor(100 * (1 - timingError / HIT_WINDOW)))
    else
        misses = misses + 1
        combo = 0
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
        statusText:SetText("Drücke die angezeigte Taste im Takt")
        return
    end

    local elapsed = GetTime() - startedAt
    local beatIndex = math.floor((elapsed - song.beatOffset + HIT_WINDOW) / beatDuration)
    if beatIndex >= 0 and beatIndex < beatCount and beatIndex ~= lastDisplayedBeat then
        if lastDisplayedBeat >= 0 and judgedBeat ~= lastDisplayedBeat then
            misses = misses + 1
            combo = 0
        end

        lastDisplayedBeat = beatIndex
        local expectedKey = chart:sub(beatIndex % #chart + 1, beatIndex % #chart + 1)
        statusText:SetText("JETZT: " .. expectedKey)
        for laneKey, label in pairs(laneLabels) do
            local color = LANE_COLORS[laneKey]
            local alpha = laneKey == expectedKey and 1 or 0.35
            label:SetTextColor(color[1] * alpha, color[2] * alpha, color[3] * alpha)
        end
        UpdateScore()
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
    frame:SetSize(560, 260)
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
    songText:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")

    scoreText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    scoreText:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -50)
    scoreText:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")

    timeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    timeText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -52)
    timeText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")

    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    statusText:SetPoint("CENTER", frame, "CENTER", 0, 40)
    statusText:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")

    for index, key in ipairs(LANE_KEYS) do
        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        label:SetPoint("BOTTOM", frame, "BOTTOM", (index - 2.5) * 112, 50)
        label:SetFont("Fonts\\FRIZQT__.TTF", 32, "OUTLINE")
        label:SetText(key)
        local color = LANE_COLORS[key]
        label:SetTextColor(color[1], color[2], color[3], 0.35)
        laneLabels[key] = label
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

function GuitarHeroUi:Start()
    local songs = addonTable.GuitarHeroSongs or {}
    local validSongs = {}
    for _, candidate in ipairs(songs) do
        if type(candidate.bpm) == "number" and candidate.bpm >= 30 and candidate.bpm <= 300
            and type(candidate.duration) == "number" and candidate.duration > 0 and candidate.duration <= 180
            and type(candidate.beatOffset) == "number" and candidate.beatOffset >= 0 and candidate.beatOffset < candidate.duration
            and type(candidate.chart) == "string" and #candidate.chart > 0 and #candidate.chart <= 64
            and type(candidate.music) == "string" and candidate.music ~= "" then
            local candidateChart = candidate.chart:gsub("%s", ""):upper()
            if candidateChart:match("^[WASD]+$") then
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
    chart = selected.chart
    beatDuration = 60 / song.bpm
    beatCount = math.floor((song.duration - song.beatOffset) / beatDuration) + 1
    countdownAt = GetTime()
    lastCountdownNumber = COUNTDOWN_SECONDS
    lastDisplayedBeat = -1
    judgedBeat = -1
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

    frame:SetPropagateKeyboardInput(false)
    frame:Show()
    frame:Raise()
    local currentSession = sessionID
    ticker = C_Timer.NewTicker(TICK_SECONDS, function()
        if currentSession == sessionID then
            UpdateGame()
        end
    end)
end