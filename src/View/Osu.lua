local addonName, addonTable = ...

addonTable.OsuUi = {}
local OsuUi = addonTable.OsuUi

local COUNTDOWN_SECONDS = 3
local APPROACH_SECONDS = 1.15
local HIT_WINDOW = 0.24
local PERFECT_WINDOW = 0.06
local GOOD_WINDOW = 0.14
local TICK_SECONDS = 0.05
local MUSIC_FADE_SECONDS = 0.8
local PLAYFIELD_WIDTH = 940
local PLAYFIELD_HEIGHT = 620
local CIRCLE_SIZE = 100
local MAX_CIRCLE_SIZE = 168
local TARGET_RING_SIZE = CIRCLE_SIZE + 10
local NOTE_EDGE_MARGIN = MAX_CIRCLE_SIZE / 2 + 8
local MIN_NOTE_DISTANCE = MAX_CIRCLE_SIZE + 12
local MAX_NOTE_DISTANCE = 210
local TIMING_INSTRUCTION = "Klicke genau dann, wenn der schrumpfende Ring den weißen Zielkreis berührt."
local HIT_SOUND_FILE = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\OSU\\OsuHitSound.ogg"

local frame
local playfield
local songText
local scoreText
local statusText
local timeText
local feedbackText
local cursorFeedbackFrame
local cursorFeedbackText
local closeButton
local ticker
local musicFadeTicker
local songSoundHandle
local musicVolumeBeforeGame
local sessionID = 0
local song
local challengeID
local notes = {}
local activeNotes = {}
local notePool = {}
local nextNoteToShow = 1
local startedAt
local countdownAt
local lastCountdownNumber
local score = 0
local hits = 0
local misses = 0
local combo = 0
local active = false
local musicStarted = false
local feedbackExpiresAt

local function UpdateScore()
    scoreText:SetText(string.format("%07d / ZIEL %07d    COMBO %d    FEHLER %d", score, song and song.targetScore or 0, combo, misses))
end

local function ShowCursorFeedback(text, red, green, blue)
    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    cursorX = cursorX / scale
    cursorY = cursorY / scale
    cursorX = math.max(180, math.min(UIParent:GetWidth() - 180, cursorX))
    cursorY = math.max(32, math.min(UIParent:GetHeight() - 32, cursorY + 28))

    cursorFeedbackText:SetText(text)
    cursorFeedbackText:SetTextColor(red, green, blue)
    cursorFeedbackFrame:ClearAllPoints()
    cursorFeedbackFrame:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", cursorX, cursorY)
    cursorFeedbackFrame:SetAlpha(1)
    cursorFeedbackFrame:Show()
    feedbackExpiresAt = GetTime() + 0.65
end

local function FadeBackgroundMusic(targetVolume, onFinished)
    if musicFadeTicker then
        musicFadeTicker:Cancel()
        musicFadeTicker = nil
    end

    local startVolume = tonumber(GetCVar("Sound_MusicVolume"))
    if startVolume == nil then
        if onFinished then
            onFinished()
        end
        return
    end

    local fadeStartedAt = GetTime()
    musicFadeTicker = C_Timer.NewTicker(0.05, function()
        local progress = math.min((GetTime() - fadeStartedAt) / MUSIC_FADE_SECONDS, 1)
        local volume = startVolume + (targetVolume - startVolume) * progress
        SetCVar("Sound_MusicVolume", string.format("%.3f", volume))

        if progress >= 1 then
            musicFadeTicker:Cancel()
            musicFadeTicker = nil
            if onFinished then
                onFinished()
            end
        end
    end)
end

local function CreateMaskedTexture(parent, layer, sublevel)
    local texture = parent:CreateTexture(nil, layer, nil, sublevel)
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    local mask = parent:CreateMaskTexture()
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    mask:SetAllPoints(texture)
    texture:AddMaskTexture(mask)
    return texture
end

local function CreateCircleButton()
    local button = CreateFrame("Button", nil, playfield)
    button:SetSize(CIRCLE_SIZE, CIRCLE_SIZE)
    button:RegisterForClicks("LeftButtonDown")

    local fill = CreateMaskedTexture(button, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetVertexColor(0.12, 0.62, 0.9, 0.95)

    local targetRing = CreateMaskedTexture(button, "ARTWORK", -2)
    targetRing:SetSize(TARGET_RING_SIZE, TARGET_RING_SIZE)
    targetRing:SetPoint("CENTER")
    targetRing:SetVertexColor(1, 1, 1, 0.9)

    local targetRingInner = CreateMaskedTexture(button, "ARTWORK", -1)
    targetRingInner:SetSize(CIRCLE_SIZE, CIRCLE_SIZE)
    targetRingInner:SetPoint("CENTER", targetRing)
    targetRingInner:SetVertexColor(0.055, 0.12, 0.21, 1)

    local inner = CreateMaskedTexture(button, "ARTWORK")
    inner:SetPoint("TOPLEFT", button, "TOPLEFT", 5, -5)
    inner:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -5, 5)
    inner:SetVertexColor(0.055, 0.12, 0.21, 1)

    local approach = CreateMaskedTexture(button, "ARTWORK", 1)
    approach:SetSize(MAX_CIRCLE_SIZE, MAX_CIRCLE_SIZE)
    approach:SetPoint("CENTER")
    approach:SetVertexColor(0.25, 0.85, 1, 0.8)

    local approachInner = CreateMaskedTexture(button, "ARTWORK", 2)
    approachInner:SetSize(MAX_CIRCLE_SIZE - 20, MAX_CIRCLE_SIZE - 20)
    approachInner:SetPoint("CENTER", approach)
    approachInner:SetVertexColor(0.055, 0.12, 0.21, 1)

    local number = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    number:SetFont("Fonts\\FRIZQT__.TTF", 19, "OUTLINE")
    number:SetPoint("CENTER")
    number:SetTextColor(1, 1, 1, 0.75)

    button.fill = fill
    button.approach = approach
    button.approachInner = approachInner
    button.number = number
    button:Hide()
    button:SetScript("OnClick", function(self)
        if not active or not musicStarted or not self.note then
            return
        end

        local cursorX, cursorY = GetCursorPosition()
        local scale = self:GetEffectiveScale()
        cursorX = cursorX / scale
        cursorY = cursorY / scale
        local centerX, centerY = self:GetCenter()
        local dx = cursorX - centerX
        local dy = cursorY - centerY
        if dx * dx + dy * dy > (CIRCLE_SIZE * 0.5) ^ 2 then
            ShowCursorFeedback("KLICKE MITTIG AUF DEN KREIS", 1, 0.8, 0.25)
            return
        end

        local note = self.note
        local timingError = math.abs((GetTime() - startedAt) - note.hitAt)
        if timingError > HIT_WINDOW then
            note.judged = true
            misses = misses + 1
            combo = 0
            ShowCursorFeedback("ZEITFENSTER VERPASST", 1, 0.25, 0.25)
        else
            note.judged = true
            hits = hits + 1
            combo = combo + 1
            PlaySoundFile(HIT_SOUND_FILE, "SFX")
            local points = timingError <= PERFECT_WINDOW and 300 or timingError <= GOOD_WINDOW and 100 or 50
            score = score + points
            if points == 300 then
                ShowCursorFeedback("PERFEKT  +300", 0.35, 1, 0.5)
            elseif points == 100 then
                ShowCursorFeedback("GUT  +100", 1, 0.9, 0.25)
            else
                ShowCursorFeedback("KNAPP  +50", 1, 0.6, 0.2)
            end
        end

        self:Hide()
        self.note = nil
        note.button = nil
        UpdateScore()
    end)

    return button
end

local function AcquireCircle(note)
    local button
    for _, candidate in ipairs(notePool) do
        if not candidate.note then
            button = candidate
            break
        end
    end

    if not button then
        button = CreateCircleButton()
        table.insert(notePool, button)
    end

    button.note = note
    button.number:SetText(note.comboNumber)
    button:ClearAllPoints()
    button:SetPoint("CENTER", playfield, "BOTTOMLEFT", note.x, note.y)
    button:Show()
    return button
end

local function IsPositionClear(x, y, hitAt, notes)
    for _, note in ipairs(notes) do
        if hitAt - note.hitAt <= APPROACH_SECONDS + HIT_WINDOW then
            local dx = x - note.x
            local dy = y - note.y
            if dx * dx + dy * dy < MIN_NOTE_DISTANCE * MIN_NOTE_DISTANCE then
                return false
            end
        end
    end

    return true
end

local function GetNextNotePosition(previousX, previousY, timeSincePrevious, hitAt, notes)
    if not previousX then
        return PLAYFIELD_WIDTH / 2, PLAYFIELD_HEIGHT / 2
    end

    local maxDistance = math.min(
        MAX_NOTE_DISTANCE,
        MIN_NOTE_DISTANCE + 8 + math.max(0, timeSincePrevious - 0.25) * 70
    )
    local minDistance = math.min(MIN_NOTE_DISTANCE, maxDistance)

    for _ = 1, 64 do
        local angle = math.random() * math.pi * 2
        local distance = minDistance + math.random() * (maxDistance - minDistance)
        local x = previousX + math.cos(angle) * distance
        local y = previousY + math.sin(angle) * distance
        if x >= NOTE_EDGE_MARGIN and x <= PLAYFIELD_WIDTH - NOTE_EDGE_MARGIN
            and y >= NOTE_EDGE_MARGIN and y <= PLAYFIELD_HEIGHT - NOTE_EDGE_MARGIN
            and IsPositionClear(x, y, hitAt, notes) then
            return x, y
        end
    end

    local bestX
    local bestY
    local bestDistance = -1
    for x = NOTE_EDGE_MARGIN, PLAYFIELD_WIDTH - NOTE_EDGE_MARGIN, 12 do
        for y = NOTE_EDGE_MARGIN, PLAYFIELD_HEIGHT - NOTE_EDGE_MARGIN, 12 do
            if IsPositionClear(x, y, hitAt, notes) then
                local dx = x - previousX
                local dy = y - previousY
                local distance = dx * dx + dy * dy
                if distance > bestDistance then
                    bestX = x
                    bestY = y
                    bestDistance = distance
                end
            end
        end
    end

    return bestX, bestY
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
    if songSoundHandle then
        StopSound(songSoundHandle)
        songSoundHandle = nil
    end
    if musicVolumeBeforeGame ~= nil then
        local originalVolume = musicVolumeBeforeGame
        musicVolumeBeforeGame = nil
        FadeBackgroundMusic(originalVolume)
    end
    musicStarted = false
    cursorFeedbackFrame:Hide()
    feedbackExpiresAt = nil

    for _, note in ipairs(notes) do
        if note.button then
            note.button.note = nil
            note.button:Hide()
            note.button = nil
        end
    end
    activeNotes = {}

    if showResult then
        for _, note in ipairs(notes) do
            if not note.judged then
                note.judged = true
                misses = misses + 1
            end
        end
        statusText:SetText("Song beendet | Treffer: " .. hits .. " | Verfehlt: " .. misses)
        closeButton:SetText("Schließen")
        UpdateScore()
        print("|cff2674cc[L|cffff0000i|rDL Roulette]|r Osu!: " .. song.title ..
            " beendet. Score: " .. score .. " | Treffer: " .. hits .. " | Verfehlt: " .. misses)
        local taxSilver = score < song.targetScore and (UnitLevel("player") or 1) * 2 or 0
        addonTable:OnLocalTimerEvent(
            challengeID,
            "OSUFINISHED",
            score,
            song.title,
            song.targetScore,
            taxSilver
        )
    else
        frame:Hide()
    end
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
                feedbackText:SetText(tostring(countdown))
                feedbackText:SetTextColor(1, 1, 1)
            end
            return
        end

        musicStarted = true
        startedAt = GetTime()
        local soundStarted
        soundStarted, songSoundHandle = PlaySoundFile(song.music, "SFX")
        if soundStarted then
            musicVolumeBeforeGame = tonumber(GetCVar("Sound_MusicVolume"))
            if musicVolumeBeforeGame ~= nil and musicVolumeBeforeGame > 0 then
                FadeBackgroundMusic(0)
            end
        else
            songSoundHandle = nil
            print("|cffff0000[Lidl Roulette]|r Song konnte nicht abgespielt werden: " .. song.title)
            StopGame(false)
            return
        end
        feedbackText:SetText("")
        return
    end

    local elapsed = GetTime() - startedAt
    while nextNoteToShow <= #notes do
        local note = notes[nextNoteToShow]
        if note.hitAt - elapsed > APPROACH_SECONDS then
            break
        end
        nextNoteToShow = nextNoteToShow + 1
        if not note.judged and note.hitAt - elapsed >= -HIT_WINDOW then
            note.button = AcquireCircle(note)
            table.insert(activeNotes, note)
        end
    end

    for index = #activeNotes, 1, -1 do
        local note = activeNotes[index]
        if note.judged then
            table.remove(activeNotes, index)
        else
            local timeUntilHit = note.hitAt - elapsed
            if timeUntilHit < -HIT_WINDOW then
                note.judged = true
                misses = misses + 1
                combo = 0
                ShowCursorFeedback("VERFEHLT", 1, 0.25, 0.25)
                note.button:Hide()
                note.button.note = nil
                note.button = nil
                table.remove(activeNotes, index)
            else
                local progress = math.max(0, math.min(1, 1 - timeUntilHit / APPROACH_SECONDS))
                local approachSize = MAX_CIRCLE_SIZE - (MAX_CIRCLE_SIZE - CIRCLE_SIZE) * progress
                note.button.approach:SetSize(approachSize, approachSize)
                note.button.approachInner:SetSize(approachSize - 20, approachSize - 20)
                local timingError = math.abs(timeUntilHit)
                if timingError <= PERFECT_WINDOW then
                    note.button.approach:SetVertexColor(0.35, 1, 0.5, 0.9)
                elseif timingError <= GOOD_WINDOW then
                    note.button.approach:SetVertexColor(1, 0.9, 0.25, 0.9)
                elseif timingError <= HIT_WINDOW then
                    note.button.approach:SetVertexColor(1, 0.55, 0.18, 0.9)
                else
                    note.button.approach:SetVertexColor(0.25, 0.85, 1, 0.8)
                end
            end
        end
    end

    if feedbackExpiresAt and GetTime() >= feedbackExpiresAt then
        cursorFeedbackFrame:Hide()
        feedbackExpiresAt = nil
    end

    local currentSecond = math.floor(elapsed)
    timeText:SetText(string.format("%d:%02d", math.floor(currentSecond / 60), currentSecond % 60))
    UpdateScore()
    if elapsed >= song.duration then
        StopGame(true)
    end
end

local function Initialize()
    if frame then
        return
    end

    frame = CreateFrame("Frame", "LidlRouletteOsuFrame", UIParent, "BackdropTemplate")
    frame:SetSize(1080, 860)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    local scale = math.min(
        1,
        (UIParent:GetWidth() - 60) / 1080,
        (UIParent:GetHeight() - 60) / 860
    )
    frame:SetScale(math.max(0.5, scale))
    frame:EnableMouse(true)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    frame:SetBackdropColor(0.025, 0.035, 0.065, 0.98)
    frame:SetBackdropBorderColor(0.2, 0.75, 0.95, 1)

    songText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    songText:SetPoint("TOP", frame, "TOP", 0, -14)
    songText:SetWidth(1000)
    songText:SetJustifyH("CENTER")
    songText:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")

    scoreText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    scoreText:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -48)
    scoreText:SetFont("Fonts\\FRIZQT__.TTF", 17, "OUTLINE")

    timeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    timeText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -50)
    timeText:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")

    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("TOP", frame, "TOP", 0, -73)
    statusText:SetWidth(1000)
    statusText:SetJustifyH("CENTER")
    statusText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    statusText:SetText(TIMING_INSTRUCTION)

    local timingLegend = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timingLegend:SetPoint("TOP", statusText, "BOTTOM", 0, -4)
    timingLegend:SetWidth(1000)
    timingLegend:SetJustifyH("CENTER")
    timingLegend:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    timingLegend:SetText("|cff59ff7aPERFEKT  ±0,06 s|r     |cffffdf4aGUT  ±0,14 s|r     |cffff9a42KNAPP  ±0,24 s|r     |cffffffffDaneben = Fehlschlag|r")

    playfield = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    playfield:SetSize(PLAYFIELD_WIDTH, PLAYFIELD_HEIGHT)
    playfield:SetPoint("CENTER", frame, "CENTER", 0, -20)
    playfield:SetFrameLevel(frame:GetFrameLevel() + 1)
    playfield:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    playfield:SetBackdropColor(0.035, 0.075, 0.13, 1)
    playfield:SetBackdropBorderColor(0.25, 0.5, 0.72, 1)

    feedbackText = playfield:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    feedbackText:SetPoint("CENTER")
    feedbackText:SetFont("Fonts\\FRIZQT__.TTF", 30, "OUTLINE")

    cursorFeedbackFrame = CreateFrame("Frame", nil, UIParent)
    cursorFeedbackFrame:SetSize(360, 42)
    cursorFeedbackFrame:SetFrameStrata("TOOLTIP")
    cursorFeedbackFrame:EnableMouse(false)
    cursorFeedbackText = cursorFeedbackFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cursorFeedbackText:SetAllPoints()
    cursorFeedbackText:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    cursorFeedbackText:SetJustifyH("CENTER")
    cursorFeedbackFrame:Hide()

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
end

function OsuUi:Start(challengeIDArg)
    local challenge = addonTable.Roulette.GetChallenge(challengeIDArg)
    if not challenge or not challenge.osu then
        print("|cffff0000[Lidl Roulette]|r Ungültige Osu!-Challenge.")
        return
    end

    local validSongs = {}
    for _, candidate in ipairs(addonTable.OsuSongs or {}) do
        local chartSource
        for _, source in ipairs(addonTable.GuitarHeroSongs or {}) do
            if source.title == candidate.chartSourceTitle then
                chartSource = source
                break
            end
        end

        if chartSource
            and type(candidate.bpm) == "number" and candidate.bpm >= 30 and candidate.bpm <= 300
            and type(candidate.duration) == "number" and candidate.duration > 0 and candidate.duration <= 180
            and type(candidate.beatOffset) == "number" and candidate.beatOffset >= 0 and candidate.beatOffset < candidate.duration
            and type(candidate.stepsPerBeat) == "number" and candidate.stepsPerBeat >= 1
            and candidate.stepsPerBeat <= 8 and candidate.stepsPerBeat == math.floor(candidate.stepsPerBeat)
            and type(candidate.targetScore) == "number" and candidate.targetScore > 0
            and type(candidate.music) == "string" and candidate.music ~= ""
            and type(chartSource.chart) == "string" then
            local sourceChart = chartSource.chart:gsub("%s", ""):upper()
            if #sourceChart > 0 and #sourceChart <= 1024 and sourceChart:match("^[WASD%-]+$") then
                table.insert(validSongs, { song = candidate, chart = sourceChart })
            end
        end
    end

    if #validSongs == 0 then
        print("|cffff0000[Lidl Roulette]|r Osu! hat keinen gültigen Song konfiguriert.")
        return
    end

    Initialize()
    if active then
        StopGame(false)
    end

    local selected = validSongs[math.random(#validSongs)]
    song = selected.song
    challengeID = challengeIDArg
    notes = {}
    activeNotes = {}
    local stepDuration = 60 / song.bpm / song.stepsPerBeat
    local comboNumber = 0
    local previousX
    local previousY
    local previousHitAt
    for index = 1, #selected.chart do
        local key = selected.chart:sub(index, index)
        local hitAt = song.beatOffset + (index - 1) * stepDuration
        if key ~= "-" and hitAt < song.duration then
            comboNumber = comboNumber + 1
            local x, y = GetNextNotePosition(
                previousX,
                previousY,
                previousHitAt and hitAt - previousHitAt or 0,
                hitAt,
                notes
            )
            if not x or not y then
                print("|cffff0000[Lidl Roulette]|r Osu! konnte keinen freien Platz für den nächsten Kreis finden.")
                return
            end
            table.insert(notes, {
                hitAt = hitAt,
                x = x,
                y = y,
                comboNumber = (comboNumber - 1) % 9 + 1,
                judged = false,
            })
            previousX = x
            previousY = y
            previousHitAt = hitAt
        end
    end

    nextNoteToShow = 1
    countdownAt = GetTime()
    lastCountdownNumber = COUNTDOWN_SECONDS
    score = 0
    hits = 0
    misses = 0
    combo = 0
    musicStarted = false
    active = true
    sessionID = sessionID + 1
    feedbackExpiresAt = nil
    cursorFeedbackFrame:Hide()

    local difficultyNames = { easy = "LEICHT", medium = "MITTEL", hard = "SCHWER" }
    songText:SetText(song.title .. "  |  " .. (difficultyNames[song.difficulty] or string.upper(song.difficulty)))
    timeText:SetText("0:00")
    statusText:SetText(TIMING_INSTRUCTION)
    feedbackText:SetText(tostring(COUNTDOWN_SECONDS))
    feedbackText:SetTextColor(1, 1, 1)
    closeButton:SetText("Abbrechen")
    UpdateScore()

    frame:Show()
    frame:Raise()
    local currentSession = sessionID
    ticker = C_Timer.NewTicker(TICK_SECONDS, function()
        if currentSession == sessionID then
            UpdateGame()
        end
    end)
end
