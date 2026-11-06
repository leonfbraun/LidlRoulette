local addonName, addonTable = ...

addonTable.GuitarHeroUi = {}
local GuitarHeroUi = addonTable.GuitarHeroUi

-- Ablauf
local COUNTDOWN_SECONDS = 3
local MUSIC_FADE_SECONDS = 0.8

-- Wertung
local HIT_WINDOW = 0.24         -- bis hierhin zählt ein Tastendruck als Treffer (± Sekunden)
local WRONG_KEY_WINDOW = 0.12   -- falsche Taste kostet die Note nur, wenn sie so nah dran liegt
local PERFECT_WINDOW = 0.05
local GOOD_WINDOW = 0.1
local MULTIPLIER_STEPS = {      -- absteigend sortiert
    { combo = 50, multiplier = 4 },
    { combo = 25, multiplier = 3 },
    { combo = 10, multiplier = 2 },
}
local COMBO_MILESTONE = 50      -- ab 100 gibt es alle 50 Treffer ein Banner
local RANKS = {                 -- absteigend sortiert, Anteil gewichteter Treffer
    { rank = "S", accuracy = 0.95, color = { 1, 0.84, 0.25 } },
    { rank = "A", accuracy = 0.85, color = { 0.35, 1, 0.5 } },
    { rank = "B", accuracy = 0.7, color = { 0.35, 0.75, 1 } },
    { rank = "C", accuracy = 0.55, color = { 1, 0.65, 0.25 } },
    { rank = "D", accuracy = 0, color = { 1, 0.3, 0.3 } },
}
local MAX_NOTE_POINTS = 100     -- Punkte einer perfekt oder gut getroffenen Note vor dem Multiplikator
local JUDGEMENTS = {
    perfect = { text = "PERFEKT", weight = 1, points = MAX_NOTE_POINTS, color = { 0.45, 1, 0.55 }, particles = 10 },
    good = { text = "GUT", weight = 0.75, points = MAX_NOTE_POINTS, color = { 1, 0.9, 0.3 }, particles = 6 },
    ok = { text = "OK", weight = 0.5, points = 95, color = { 1, 0.62, 0.25 }, particles = 3 },
}
local MISS_COLOR = { 1, 0.28, 0.28 }

-- Layout
local LANE_KEYS = { "A", "W", "S", "D" }
local LANE_COLORS = {
    A = { 0.25, 0.85, 0.42 },
    W = { 0.95, 0.78, 0.22 },
    S = { 0.9, 0.3, 0.28 },
    D = { 0.25, 0.62, 0.95 },
}
local HYPE_COLORS = {
    { 0.55, 0.6, 0.7 },
    { 0.3, 0.8, 1 },
    { 0.85, 0.4, 1 },
    { 1, 0.78, 0.2 },
}
local FRAME_WIDTH = 780
local FRAME_HEIGHT = 680
local LANE_WIDTH = 90
local HIGHWAY_WIDTH = LANE_WIDTH * #LANE_KEYS
local HIGHWAY_HEIGHT = 570
local HIT_Y = 72
local NOTE_SIZE = 62
local PAD_SIZE = 70
local PANEL_WIDTH = 178
local PROGRESS_WIDTH = 720
local BAR_WIDTH = 170
-- Die Spielwelt bleibt durchscheinend sichtbar: Sieht man nur die Ränder sich bewegen, während
-- die Bildmitte stillsteht, kann das Motion Sickness auslösen.
local FRAME_ALPHA = 0.45
local HIGHWAY_ALPHA_BOTTOM = 0.6
local HIGHWAY_ALPHA_TOP = 0.4
local FONT ="Fonts\\FRIZQT__.TTF"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local MULTIPLIER_SOUND = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\OSU\\OsuHitSound.ogg"
local TARGET_REACHED_SOUND = 888
local COUNTDOWN_SOUND = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON

-- Noten
local NOTE_TRAVEL_SECONDS = 1.1
local NOTE_START_Y = HIGHWAY_HEIGHT + NOTE_SIZE / 2
local NOTE_SPEED = (NOTE_START_Y - HIT_Y) / NOTE_TRAVEL_SECONDS
local NOTE_FADE_SECONDS = 0.14
local NOTE_TAIL_SECONDS = HIT_WINDOW + 0.12 -- so lange fällt eine verpasste Note noch sichtbar weiter
local PAD_HINT_SECONDS = 0.14

-- Effekte
local BEAT_LINE_COUNT = 8       -- reicht bis 300 BPM
local PARTICLE_COUNT = 48
local PARTICLE_SECONDS = 0.45
local PARTICLE_GRAVITY = 900
local FLASH_SECONDS = 0.28
local PRESS_FLASH_SECONDS = 0.16
local MISS_FLASH_SECONDS = 0.3
local SCORE_ROLL_SPEED = 12     -- Anteil der Differenz pro Sekunde

local DIFFICULTY_LABELS = {
    easy = "|cff59ff7aLEICHT|r",
    medium = "|cffffdf4aMITTEL|r",
    hard = "|cffff5c5cSCHWER|r",
    extreme = "|cffc85cffEXTREM|r",
}

local frame
local highway
local noteLayer
local fxLayer
local songText
local difficultyText
local timeText
local progressBar
local scoreText
local recordText
local targetLabel
local targetBar
local countersText
local accuracyText
local multiplierPopup
local multiplierBar
local comboText
local bestComboText
local hintText
local closeButton
local missFlash
local missFlashAt
local hypeLeft
local hypeRight
local comboPopup
local countdownPopup
local bannerPopup
local results
local laneViews = {}
local beatLines = {}
local particles = {}
local nextParticle = 1
local markerPool = {}
local activeMarkers = {}

local musicFadeTicker
local songSoundHandle
local musicVolumeBeforeGame
local musicVolumeRestoring
local keyboardReady = false

local song
local challengeID
local notes = {}
local targetScore = 0
local nextToSpawn = 1
local nextToExpire = 1
local beatDuration
local startedAt
local lastCountdownNumber
local lastDisplayedSecond
local counts = {}
local score = 0
local displayedScore = 0
local lastShownScore
local combo = 0
local bestCombo = 0
local multiplier = 1
local timingSum = 0
local timingCount = 0
local judgedWeight = 0
local judgedNotes = 0
local previousRecord
local targetReached = false
local panelsDirty = false
local active = false
local musicStarted = false

local function FormatNumber(value)
    local text = tostring(math.floor(value))
    local formatted = text:reverse():gsub("(%d%d%d)", "%1."):reverse()
    return (formatted:gsub("^%.", ""))
end

local function GetMultiplier(comboLength)
    for _, step in ipairs(MULTIPLIER_STEPS) do
        if comboLength >= step.combo then
            return step.multiplier
        end
    end
    return 1
end

-- targetPercent bezieht sich auf die Maximalpunktzahl: jede Note mindestens "gut" getroffen, ohne Combo-Abriss.
-- Aufgerundet auf Zehner, damit das Ziel nie 0 wird und bei 1 genau das Maximum ergibt.
local function ComputeTargetScore(noteCount, targetPercent)
    local maxScore = 0
    for streak = 1, noteCount do
        maxScore = maxScore + MAX_NOTE_POINTS * GetMultiplier(streak)
    end
    return math.ceil(maxScore * targetPercent / 10) * 10
end

local function GetRecords()
    if type(LidlRouletteDB) ~= "table" then
        return nil
    end
    if type(LidlRouletteDB.guitarHeroRecords) ~= "table" then
        LidlRouletteDB.guitarHeroRecords = {}
    end
    return LidlRouletteDB.guitarHeroRecords
end

-- ---------------------------------------------------------------------------
-- Hintergrundmusik
-- ---------------------------------------------------------------------------

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

local function MuteBackgroundMusic()
    -- Läuft das Einblenden der letzten Runde noch, ist der aktuelle CVar nur ein Zwischenwert.
    musicVolumeBeforeGame = musicVolumeRestoring or tonumber(GetCVar("Sound_MusicVolume"))
    musicVolumeRestoring = nil
    if musicVolumeBeforeGame ~= nil and musicVolumeBeforeGame > 0 then
        FadeBackgroundMusic(0)
    end
end

local function RestoreBackgroundMusic()
    if musicVolumeBeforeGame == nil then
        return
    end
    musicVolumeRestoring = musicVolumeBeforeGame
    musicVolumeBeforeGame = nil
    FadeBackgroundMusic(musicVolumeRestoring, function()
        musicVolumeRestoring = nil
    end)
end

-- ---------------------------------------------------------------------------
-- Tastatur
-- ---------------------------------------------------------------------------

-- Alle Tasten werden bewusst immer ans Spiel weitergegeben: Der Charakter soll beim Spielen mit
-- W/A/S/D sichtbar hin und her laufen, das gehört zum Witz der Challenge.
-- Ein neuer Frame würde alle Tasten schlucken. Die Tastatur wird daher erst aktiviert, sobald
-- die Weitergabe eingeschaltet werden kann. Bis dahin lassen sich die Kreise anklicken.
local function PrepareKeyboard()
    if keyboardReady or InCombatLockdown() then
        return
    end
    frame:EnableKeyboard(true)
    frame:SetPropagateKeyboardInput(true)
    keyboardReady = true
    hintText:SetText("Taste drücken, wenn die Note den Kreis erreicht.")
end

-- Bei jedem Tastendruck erneut setzen: Der Wert wirkt erst dadurch verlässlich auf genau diese
-- Taste. Im Kampf ist der Aufruf gesperrt, dort gilt der zuletzt gesetzte Wert weiter.
local function KeepKeysPropagating()
    if keyboardReady and not InCombatLockdown() then
        frame:SetPropagateKeyboardInput(true)
    end
end

-- ---------------------------------------------------------------------------
-- Bausteine der Darstellung
-- ---------------------------------------------------------------------------

local function CreateSolid(parent, layer, sublevel, red, green, blue, alpha)
    local texture = parent:CreateTexture(nil, layer, nil, sublevel)
    texture:SetColorTexture(red, green, blue, alpha or 1)
    return texture
end

local function CreateCircle(parent, layer, sublevel, size)
    local texture = parent:CreateTexture(nil, layer, nil, sublevel)
    texture:SetTexture(WHITE)
    texture:SetSize(size, size)
    local mask = parent:CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK)
    mask:SetAllPoints(texture)
    texture:AddMaskTexture(mask)
    return texture
end

local function CreateGradient(parent, layer, sublevel, orientation, color, fromAlpha, toAlpha)
    local texture = parent:CreateTexture(nil, layer, nil, sublevel)
    texture:SetTexture(WHITE)
    texture:SetGradient(orientation,
        CreateColor(color[1], color[2], color[3], fromAlpha),
        CreateColor(color[1], color[2], color[3], toAlpha))
    return texture
end

local function CreateText(parent, size, layer)
    local text = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontNormal")
    text:SetFont(FONT, size, "OUTLINE")
    return text
end

-- Text, der aufploppt, nach oben wandert und ausblendet. Die Größe wird über einen inneren Frame
-- animiert, damit der Mittelpunkt beim Skalieren an Ort und Stelle bleibt.
local function CreatePopup(parent, fontSize, anchor, x, y, seconds, rise)
    local popup = { anchor = anchor, x = x, y = y, seconds = seconds, rise = rise or 0 }
    popup.holder = CreateFrame("Frame", nil, parent)
    popup.holder:SetSize(10, 10)
    popup.holder:SetPoint("CENTER", anchor, "BOTTOM", x, y)
    popup.inner = CreateFrame("Frame", nil, popup.holder)
    popup.inner:SetSize(10, 10)
    popup.inner:SetPoint("CENTER")
    popup.text = CreateText(popup.inner, fontSize)
    popup.text:SetPoint("CENTER")
    popup.subText = CreateText(popup.inner, math.floor(fontSize * 0.65))
    popup.subText:SetPoint("TOP", popup.text, "BOTTOM", 0, -1)
    popup.holder:Hide()
    return popup
end

local function PlayPopup(popup, text, color, subText)
    popup.text:SetText(text)
    popup.text:SetTextColor(color[1], color[2], color[3])
    popup.subText:SetText(subText or "")
    popup.subText:SetTextColor(color[1], color[2], color[3])
    popup.bornAt = GetTime()
    popup.holder:SetAlpha(1)
    popup.holder:Show()
end

local function UpdatePopup(popup, now)
    if not popup.bornAt then
        return
    end

    local progress = (now - popup.bornAt) / popup.seconds
    if progress >= 1 then
        popup.bornAt = nil
        popup.holder:Hide()
        return
    end

    local growth = math.max(0, 1 - progress / 0.15)
    popup.inner:SetScale(1 + 0.45 * growth)
    popup.holder:SetAlpha(progress > 0.6 and (1 - progress) / 0.4 or 1)
    if popup.rise ~= 0 then
        popup.holder:ClearAllPoints()
        popup.holder:SetPoint("CENTER", popup.anchor, "BOTTOM", popup.x, popup.y + popup.rise * progress)
    end
end

local function HidePopup(popup)
    popup.bornAt = nil
    popup.holder:Hide()
end

local function CreateMarker()
    local marker = {}
    marker.frame = CreateFrame("Frame", nil, noteLayer)
    marker.frame:SetSize(NOTE_SIZE, NOTE_SIZE)

    marker.glow = CreateCircle(marker.frame, "BACKGROUND", 0, NOTE_SIZE * 1.4)
    marker.glow:SetPoint("CENTER")
    marker.glow:SetBlendMode("ADD")

    local rim = CreateCircle(marker.frame, "ARTWORK", 0, NOTE_SIZE)
    rim:SetPoint("CENTER")
    rim:SetVertexColor(0.02, 0.02, 0.04, 1)

    marker.body = CreateCircle(marker.frame, "ARTWORK", 1, NOTE_SIZE - 6)
    marker.body:SetPoint("CENTER")

    local shine = CreateCircle(marker.frame, "ARTWORK", 2, NOTE_SIZE * 0.5)
    shine:SetPoint("CENTER", 0, NOTE_SIZE * 0.16)
    shine:SetVertexColor(1, 1, 1, 0.22)

    marker.label = CreateText(marker.frame, 24)
    marker.label:SetPoint("CENTER")
    table.insert(markerPool, marker)
    return marker
end

local function AcquireMarker(note, now)
    local marker
    for _, candidate in ipairs(markerPool) do
        if not candidate.note then
            marker = candidate
            break
        end
    end
    marker = marker or CreateMarker()

    local color = LANE_COLORS[note.key]
    marker.note = note
    marker.spawnedAt = now
    marker.label:SetText(note.key)
    marker.label:SetTextColor(1, 1, 1)
    marker.body:SetGradient("VERTICAL",
        CreateColor(color[1] * 0.55, color[2] * 0.55, color[3] * 0.55, 1),
        CreateColor(color[1], color[2], color[3], 1))
    marker.glow:SetVertexColor(color[1], color[2], color[3], 0.3)
    marker.frame:SetAlpha(0)
    marker.frame:Show()
    note.marker = marker
    table.insert(activeMarkers, marker)
    return marker
end

local function ReleaseMarker(marker)
    marker.frame:Hide()
    marker.note.marker = nil
    marker.note = nil
    for index, candidate in ipairs(activeMarkers) do
        if candidate == marker then
            table.remove(activeMarkers, index)
            return
        end
    end
end

-- ---------------------------------------------------------------------------
-- Effekte
-- ---------------------------------------------------------------------------

local function SpawnParticles(key, count, color)
    local now = GetTime()
    local laneX = laneViews[key].x
    for _ = 1, count do
        local particle = particles[nextParticle]
        nextParticle = nextParticle % PARTICLE_COUNT + 1
        local angle = math.random() * math.pi
        local speed = 120 + math.random() * 240
        particle.bornAt = now
        particle.x = laneX
        particle.velocityX = math.cos(angle) * speed
        particle.velocityY = math.sin(angle) * speed
        particle.texture:SetVertexColor(color[1], color[2], color[3], 1)
        particle.texture:Show()
    end
end

local function UpdateFlash(texture, startedFlashAt, seconds, strength, now)
    if not startedFlashAt then
        texture:SetAlpha(0)
        return
    end
    texture:SetAlpha(math.max(0, 1 - (now - startedFlashAt) / seconds) * strength)
end

local function SetHype(value)
    local color = HYPE_COLORS[value]
    hypeLeft:SetGradient("HORIZONTAL", CreateColor(color[1], color[2], color[3], 0.75), CreateColor(color[1], color[2], color[3], 0))
    hypeRight:SetGradient("HORIZONTAL", CreateColor(color[1], color[2], color[3], 0), CreateColor(color[1], color[2], color[3], 0.75))
    multiplierPopup.text:SetTextColor(color[1], color[2], color[3])
    multiplierBar:SetColorTexture(color[1], color[2], color[3], 1)
    frame:SetBackdropBorderColor(color[1], color[2], color[3], 1)
end

local function UpdatePanels()
    panelsDirty = false

    multiplierPopup.text:SetText("x" .. multiplier)
    multiplierPopup.holder:Show()

    -- Fortschritt bis zum nächsten Multiplikator
    local fromCombo = 0
    local toCombo
    for _, step in ipairs(MULTIPLIER_STEPS) do
        if combo >= step.combo then
            fromCombo = step.combo
            break
        end
        toCombo = step.combo
    end
    local fill = toCombo and (combo - fromCombo) / (toCombo - fromCombo) or 1
    multiplierBar:SetWidth(math.max(1, BAR_WIDTH * fill))

    comboText:SetText(combo)
    bestComboText:SetText("BESTE  " .. bestCombo)
    if combo >= 5 then
        comboPopup.text:SetText(combo)
        comboPopup.holder:Show()
    else
        comboPopup.holder:Hide()
    end

    countersText:SetText(string.format(
        "|cff73ff8cPerfekt  %d|r\n|cffffe64dGut  %d|r\n|cffff9e40OK  %d|r\n|cffff4747Miss  %d|r",
        counts.perfect, counts.good, counts.ok, counts.miss))
    accuracyText:SetText(judgedNotes > 0
        and string.format("GENAUIGKEIT  %d%%", math.floor(judgedWeight / judgedNotes * 100 + 0.5))
        or "GENAUIGKEIT  -")
end

local function UpdateScoreDisplay(now, frameSeconds)
    if displayedScore ~= score then
        local difference = score - displayedScore
        displayedScore = displayedScore + difference * math.min(1, frameSeconds * SCORE_ROLL_SPEED)
        if math.abs(score - displayedScore) < 1 then
            displayedScore = score
        end
    end

    local shown = math.floor(displayedScore)
    if shown == lastShownScore then
        return
    end
    lastShownScore = shown
    scoreText:SetText(FormatNumber(shown))
    targetBar:SetWidth(math.max(1, BAR_WIDTH * math.min(1, shown / targetScore)))
    if shown >= targetScore then
        targetBar:SetColorTexture(1, 0.8, 0.2, 1)
        targetLabel:SetText("|cffffcc33ZIEL ERREICHT|r")
    end
end

-- Läuft auch auf dem Ergebnisbildschirm weiter, damit laufende Effekte sauber ausklingen.
local function UpdateEffects(now, frameSeconds)
    for _, key in ipairs(LANE_KEYS) do
        local lane = laneViews[key]
        local pressed = lane.pressedAt and math.max(0, 1 - (now - lane.pressedAt) / PRESS_FLASH_SECONDS) or 0
        local hint = 0
        for _, marker in ipairs(activeMarkers) do
            local note = marker.note
            if note.key == key and not note.judged and math.abs(note.t - (now - startedAt)) <= PAD_HINT_SECONDS then
                hint = 0.35
                break
            end
        end

        local flash = lane.flashAt and math.max(0, 1 - (now - lane.flashAt) / FLASH_SECONDS) or 0
        lane.padFill:SetAlpha(math.max(pressed * 0.55, hint, flash))
        lane.beam:SetAlpha(math.max(pressed * 0.28, flash * 0.75))

        if flash > 0 then
            local size = PAD_SIZE * (1 + (1 - flash) * 0.9)
            lane.burst:SetSize(size, size)
            lane.burst:SetAlpha(flash * 0.65)
        else
            lane.burst:SetAlpha(0)
        end

        UpdatePopup(lane.popup, now)
    end

    for _, particle in ipairs(particles) do
        if particle.bornAt then
            local age = now - particle.bornAt
            if age >= PARTICLE_SECONDS then
                particle.bornAt = nil
                particle.texture:Hide()
            else
                particle.texture:ClearAllPoints()
                particle.texture:SetPoint("CENTER", highway, "BOTTOM",
                    particle.x + particle.velocityX * age,
                    HIT_Y + particle.velocityY * age - PARTICLE_GRAVITY / 2 * age * age)
                particle.texture:SetAlpha(1 - age / PARTICLE_SECONDS)
            end
        end
    end

    UpdateFlash(missFlash, missFlashAt, MISS_FLASH_SECONDS, 0.45, now)
    UpdatePopup(countdownPopup, now)
    UpdatePopup(bannerPopup, now)
    UpdatePopup(results.rankPopup, now)

    -- Puls von Combo und Multiplikator klingt nach jedem Treffer ab
    local pulse = comboPopup.pulseAt and math.max(0, 1 - (now - comboPopup.pulseAt) / 0.2) or 0
    comboPopup.inner:SetScale(1 + 0.18 * pulse)
    multiplierPopup.inner:SetScale(1 + 0.12 * pulse)

    UpdateScoreDisplay(now, frameSeconds)
end

-- ---------------------------------------------------------------------------
-- Spiellogik
-- ---------------------------------------------------------------------------

local function SetCombo(value)
    combo = value
    bestCombo = math.max(bestCombo, combo)

    local newMultiplier = GetMultiplier(combo)
    if newMultiplier ~= multiplier then
        if newMultiplier > multiplier then
            PlayPopup(bannerPopup, "x" .. newMultiplier .. " MULTIPLIKATOR!", HYPE_COLORS[newMultiplier])
            PlaySoundFile(MULTIPLIER_SOUND, "SFX")
        end
        multiplier = newMultiplier
        SetHype(multiplier)
    elseif combo >= COMBO_MILESTONE * 2 and combo % COMBO_MILESTONE == 0 then
        PlayPopup(bannerPopup, combo .. "er COMBO!", HYPE_COLORS[multiplier])
    end
    panelsDirty = true
end

local function RegisterMiss(note, popupKey, popupText)
    note.judged = true
    counts.miss = counts.miss + 1
    judgedNotes = judgedNotes + 1
    SetCombo(0)

    if note.marker then
        note.marker.body:SetVertexColor(0.3, 0.3, 0.34, 1)
        note.marker.glow:SetVertexColor(0, 0, 0, 0)
        note.marker.label:SetTextColor(0.65, 0.65, 0.7)
    end
    PlayPopup(laneViews[popupKey].popup, popupText, MISS_COLOR)
    missFlashAt = GetTime()
end

local function RegisterHit(note, timing)
    local timingError = math.abs(timing)
    local judgementKey = timingError <= PERFECT_WINDOW and "perfect" or timingError <= GOOD_WINDOW and "good" or "ok"
    local judgement = JUDGEMENTS[judgementKey]

    note.judged = true
    counts[judgementKey] = counts[judgementKey] + 1
    judgedNotes = judgedNotes + 1
    judgedWeight = judgedWeight + judgement.weight
    timingSum = timingSum + timing
    timingCount = timingCount + 1
    SetCombo(combo + 1)

    score = score + judgement.points * multiplier
    if not targetReached and score >= targetScore then
        targetReached = true
        PlayPopup(bannerPopup, "ZIEL ERREICHT!", { 1, 0.84, 0.25 })
        PlaySound(TARGET_REACHED_SOUND)
    end

    if note.marker then
        ReleaseMarker(note.marker)
    end

    local lane = laneViews[note.key]
    lane.flashAt = GetTime()
    comboPopup.pulseAt = lane.flashAt
    SpawnParticles(note.key, judgement.particles, LANE_COLORS[note.key])
    local direction
    if judgementKey ~= "perfect" then
        direction = timing < 0 and "FRÜH" or "SPÄT"
    end
    PlayPopup(lane.popup, judgement.text, judgement.color, direction)
end

-- Sucht unter allen offenen Noten im Trefffenster die nächste mit passender Taste. Gibt es keine,
-- kostet der Druck die nächstgelegene Note, damit wildes Drücken aller Tasten sich nicht lohnt.
local function HandlePress(key)
    if not active or not LANE_COLORS[key] then
        return
    end

    laneViews[key].pressedAt = GetTime()
    local elapsed = GetTime() - startedAt
    local matching
    local matchingError = math.huge
    local nearest
    local nearestError = math.huge
    for index = nextToExpire, #notes do
        local note = notes[index]
        local timing = elapsed - note.t
        if timing < -HIT_WINDOW then
            break
        end

        local timingError = math.abs(timing)
        if not note.judged and timingError <= HIT_WINDOW then
            if note.key == key and timingError < matchingError then
                matching = note
                matchingError = timingError
            end
            if timingError < nearestError then
                nearest = note
                nearestError = timingError
            end
        end
    end

    if matching then
        RegisterHit(matching, elapsed - matching.t)
    elseif nearest and nearestError <= WRONG_KEY_WINDOW then
        RegisterMiss(nearest, key, "FALSCH")
        PlayPopup(laneViews[nearest.key].popup, "MISS", MISS_COLOR)
    end
end

local function GetAccuracy()
    return #notes > 0 and judgedWeight / #notes or 0
end

local function ShowResults(taxSilver, canceled)
    local accuracy = GetAccuracy()
    local rank = RANKS[#RANKS]
    for _, candidate in ipairs(RANKS) do
        if accuracy >= candidate.accuracy then
            rank = candidate
            break
        end
    end

    if canceled then
        results.verdict:SetText("|cffff4747ABGEBROCHEN|r")
        results.tax:SetText("Steuern: " .. taxSilver .. " Silber")
    elseif score >= targetScore then
        results.verdict:SetText("|cff73ff8cZIEL ERREICHT|r")
        results.tax:SetText("Keine Steuern!")
    else
        results.verdict:SetText("|cffff4747ZIEL VERFEHLT|r")
        results.tax:SetText("Steuern: " .. taxSilver .. " Silber")
    end
    PlayPopup(results.rankPopup, rank.rank, rank.color)

    results.score:SetText(FormatNumber(score) .. " / " .. FormatNumber(targetScore))
    local lines = {
        string.format("Genauigkeit  %d%%", math.floor(accuracy * 100 + 0.5)),
        "Beste Combo  " .. bestCombo,
        string.format("|cff73ff8cPerfekt %d|r   |cffffe64dGut %d|r   |cffff9e40OK %d|r   |cffff4747Miss %d|r",
            counts.perfect, counts.good, counts.ok, counts.miss),
    }
    if timingCount > 0 then
        local meanTiming = timingSum / timingCount * 1000
        table.insert(lines, string.format("Timing  im Schnitt %d ms %s",
            math.floor(math.abs(meanTiming) + 0.5), meanTiming < 0 and "zu früh" or "zu spät"))
    end
    results.stats:SetText(table.concat(lines, "\n"))

    local isFullCombo = counts.miss == 0 and #notes > 0
    local isRecord = not previousRecord or score > previousRecord
    local badges = {}
    if isFullCombo then
        table.insert(badges, "|cffffcc33FULL COMBO!|r")
    end
    if isRecord and score > 0 then
        table.insert(badges, "|cff66d9ffNEUER REKORD!|r")
        local records = GetRecords()
        if records then
            records[song.title] = score
        end
    elseif previousRecord then
        table.insert(badges, "Rekord: " .. FormatNumber(previousRecord))
    end
    results.badges:SetText(table.concat(badges, "   "))
    results.frame:Show()
end

-- canceled: Der Spieler hat abgebrochen. Das zählt immer als nicht bestanden, auch wenn die
-- Punktzahl das Ziel zu diesem Zeitpunkt schon erreicht hatte.
local function StopGame(showResult, canceled)
    if not active then
        return
    end

    active = false
    if songSoundHandle then
        StopSound(songSoundHandle)
        songSoundHandle = nil
    end
    RestoreBackgroundMusic()
    musicStarted = false
    for index = #activeMarkers, 1, -1 do
        ReleaseMarker(activeMarkers[index])
    end
    HidePopup(countdownPopup)

    if showResult then
        for index = nextToExpire, #notes do
            if not notes[index].judged then
                notes[index].judged = true
                counts.miss = counts.miss + 1
                judgedNotes = judgedNotes + 1
            end
        end
        nextToExpire = #notes + 1
        displayedScore = score
        UpdatePanels()
        closeButton:SetText("Schließen")

        local taxSilver = (canceled or score < targetScore) and addonTable:GetTaxSilver() or 0
        ShowResults(taxSilver, canceled)
        print("|cff2674cc[L|cffff0000i|rDL Roulette]|r WoW-Hero: " .. song.title ..
            (canceled and " abgebrochen" or " beendet") .. ". Score: " .. score .. " | Treffer: " .. (#notes - counts.miss) .. " | Verfehlt: " .. counts.miss)
        addonTable:OnLocalTimerEvent(
            challengeID,
            "GUITARHEROFINISHED",
            score,
            song.title,
            targetScore,
            taxSilver
        )
    else
        frame:Hide()
    end
end

local function StartMusic(now)
    musicStarted = true
    startedAt = now
    local soundStarted
    soundStarted, songSoundHandle = PlaySoundFile(song.music, "SFX")
    if soundStarted then
        MuteBackgroundMusic()
    else
        songSoundHandle = nil
        print("|cffff0000[Lidl Roulette]|r Song konnte nicht abgespielt werden: " .. song.title)
    end
    PlayPopup(countdownPopup, "LOS!", { 1, 0.84, 0.25 })
end

local function UpdateBeatLines(elapsed)
    local firstBeat = math.ceil((elapsed - song.beatOffset - HIT_Y / NOTE_SPEED) / beatDuration)
    for index, line in ipairs(beatLines) do
        local beat = firstBeat + index - 1
        local untilBeat = song.beatOffset + beat * beatDuration - elapsed
        if untilBeat > NOTE_TRAVEL_SECONDS then
            line:Hide()
        else
            line:ClearAllPoints()
            line:SetPoint("CENTER", highway, "BOTTOM", 0, HIT_Y + untilBeat * NOTE_SPEED)
            line:SetAlpha(beat % 4 == 0 and 0.32 or 0.12)
            line:Show()
        end
    end
end

local function UpdateGame(now)
    if not keyboardReady then
        PrepareKeyboard()
    end

    if not musicStarted then
        local remaining = startedAt - now
        if remaining > 0 then
            local countdown = math.ceil(remaining)
            if countdown ~= lastCountdownNumber then
                lastCountdownNumber = countdown
                PlayPopup(countdownPopup, tostring(countdown), { 1, 1, 1 })
                PlaySound(COUNTDOWN_SOUND)
            end
        else
            StartMusic(now)
        end
    end

    local elapsed = now - startedAt

    while nextToSpawn <= #notes and notes[nextToSpawn].t - elapsed <= NOTE_TRAVEL_SECONDS do
        local note = notes[nextToSpawn]
        nextToSpawn = nextToSpawn + 1
        if not note.judged and elapsed <= note.t + NOTE_TAIL_SECONDS then
            AcquireMarker(note, now)
        end
    end

    while nextToExpire <= #notes and elapsed > notes[nextToExpire].t + HIT_WINDOW do
        local note = notes[nextToExpire]
        nextToExpire = nextToExpire + 1
        if not note.judged then
            RegisterMiss(note, note.key, "MISS")
        end
    end

    for index = #activeMarkers, 1, -1 do
        local marker = activeMarkers[index]
        local untilHit = marker.note.t - elapsed
        if untilHit < -NOTE_TAIL_SECONDS then
            ReleaseMarker(marker)
        else
            marker.frame:ClearAllPoints()
            marker.frame:SetPoint("CENTER", highway, "BOTTOM", laneViews[marker.note.key].x, HIT_Y + untilHit * NOTE_SPEED)
            local alpha = math.min(1, (now - marker.spawnedAt) / NOTE_FADE_SECONDS)
            marker.frame:SetAlpha(marker.note.judged and alpha * 0.55 or alpha)
        end
    end

    UpdateBeatLines(elapsed)

    if multiplier >= 2 then
        local phase = ((elapsed - song.beatOffset) / beatDuration) % 1
        local alpha = (0.35 + 0.2 * (multiplier - 2)) * (0.65 + 0.35 * (1 - phase))
        hypeLeft:SetAlpha(alpha)
        hypeRight:SetAlpha(alpha)
    else
        hypeLeft:SetAlpha(0)
        hypeRight:SetAlpha(0)
    end

    if panelsDirty then
        UpdatePanels()
    end

    progressBar:SetWidth(math.max(1, PROGRESS_WIDTH * math.max(0, math.min(1, elapsed / song.duration))))
    local remainingSeconds = math.max(0, math.ceil(song.duration - math.max(0, elapsed)))
    if remainingSeconds ~= lastDisplayedSecond then
        lastDisplayedSecond = remainingSeconds
        timeText:SetText(string.format("%d:%02d", math.floor(remainingSeconds / 60), remainingSeconds % 60))
    end

    if elapsed >= song.duration then
        StopGame(true)
    end
end

-- ---------------------------------------------------------------------------
-- Aufbau
-- ---------------------------------------------------------------------------

-- Kein Merken gedrückter Tasten: Weil die Tasten ans Spiel weitergehen, kommt das Loslassen hier
-- nicht verlässlich an. Eine darauf wartende Taste bliebe sonst dauerhaft gesperrt.
local function HandleKeyDown(key)
    KeepKeysPropagating()
    HandlePress(string.upper(key or ""))
end

local function CreateLane(index, key, padLayer)
    local color = LANE_COLORS[key]
    local laneX = (index - 2.5) * LANE_WIDTH
    local lane = { x = laneX }

    local tint = CreateGradient(highway, "BACKGROUND", 1, "VERTICAL", color, 0.2, 0)
    tint:SetPoint("BOTTOM", highway, "BOTTOM", laneX, 0)
    tint:SetSize(LANE_WIDTH, HIGHWAY_HEIGHT)

    if index > 1 then
        local divider = CreateSolid(highway, "BACKGROUND", 2, 1, 1, 1, 0.08)
        divider:SetPoint("BOTTOM", highway, "BOTTOM", laneX - LANE_WIDTH / 2, 0)
        divider:SetSize(1, HIGHWAY_HEIGHT)
    end

    lane.beam = CreateGradient(highway, "ARTWORK", 0, "VERTICAL", color, 0.8, 0)
    lane.beam:SetPoint("BOTTOM", highway, "BOTTOM", laneX, HIT_Y)
    lane.beam:SetSize(LANE_WIDTH - 2, 300)
    lane.beam:SetBlendMode("ADD")
    lane.beam:SetAlpha(0)

    -- Der Kreis ist auch per Maus bedienbar: Im Kampf gestartet gibt es anfangs keine Tastatur.
    local pad = CreateFrame("Frame", nil, padLayer)
    pad:SetSize(PAD_SIZE, PAD_SIZE)
    pad:SetPoint("CENTER", highway, "BOTTOM", laneX, HIT_Y)
    pad:EnableMouse(true)
    pad:SetScript("OnMouseDown", function()
        HandlePress(key)
    end)

    local rim = CreateCircle(pad, "ARTWORK", 0, PAD_SIZE)
    rim:SetPoint("CENTER")
    rim:SetVertexColor(color[1], color[2], color[3], 1)

    local inner = CreateCircle(pad, "ARTWORK", 1, PAD_SIZE - 8)
    inner:SetPoint("CENTER")
    inner:SetVertexColor(0.04, 0.05, 0.08, 1)

    lane.padFill = CreateCircle(pad, "ARTWORK", 2, PAD_SIZE - 8)
    lane.padFill:SetPoint("CENTER")
    lane.padFill:SetVertexColor(color[1], color[2], color[3], 1)
    lane.padFill:SetAlpha(0)

    local label = CreateText(pad, 24)
    label:SetPoint("CENTER")
    label:SetText(key)
    label:SetTextColor(color[1], color[2], color[3])

    lane.burst = CreateCircle(fxLayer, "ARTWORK", 0, PAD_SIZE)
    lane.burst:SetPoint("CENTER", highway, "BOTTOM", laneX, HIT_Y)
    lane.burst:SetVertexColor(color[1], color[2], color[3], 1)
    lane.burst:SetBlendMode("ADD")
    lane.burst:SetAlpha(0)

    lane.popup = CreatePopup(fxLayer, 16, highway, laneX, HIT_Y + 62, 0.6, 28)
    laneViews[key] = lane
end

local function CreateHighway()
    highway = CreateFrame("Frame", nil, frame)
    highway:SetSize(HIGHWAY_WIDTH, HIGHWAY_HEIGHT)
    highway:SetPoint("BOTTOM", frame, "BOTTOM", 0, 14)
    highway:SetClipsChildren(true)

    local baseLevel = frame:GetFrameLevel()
    highway:SetFrameLevel(baseLevel + 1)

    local background = CreateGradient(highway, "BACKGROUND", 0, "VERTICAL", { 0.07, 0.08, 0.13 }, HIGHWAY_ALPHA_BOTTOM, HIGHWAY_ALPHA_TOP)
    background:SetAllPoints()

    for index = 1, BEAT_LINE_COUNT do
        local line = CreateSolid(highway, "BACKGROUND", 3, 1, 1, 1, 1)
        line:SetSize(HIGHWAY_WIDTH, 2)
        line:Hide()
        beatLines[index] = line
    end

    hypeLeft = highway:CreateTexture(nil, "BACKGROUND", nil, 4)
    hypeLeft:SetTexture(WHITE)
    hypeLeft:SetPoint("TOPLEFT")
    hypeLeft:SetPoint("BOTTOMLEFT")
    hypeLeft:SetWidth(46)
    hypeLeft:SetBlendMode("ADD")
    hypeRight = highway:CreateTexture(nil, "BACKGROUND", nil, 4)
    hypeRight:SetTexture(WHITE)
    hypeRight:SetPoint("TOPRIGHT")
    hypeRight:SetPoint("BOTTOMRIGHT")
    hypeRight:SetWidth(46)
    hypeRight:SetBlendMode("ADD")

    local hitLine = CreateSolid(highway, "ARTWORK", 1, 1, 1, 1, 0.35)
    hitLine:SetPoint("CENTER", highway, "BOTTOM", 0, HIT_Y)
    hitLine:SetSize(HIGHWAY_WIDTH, 2)

    missFlash = CreateGradient(highway, "ARTWORK", 2, "VERTICAL", MISS_COLOR, 0.9, 0)
    missFlash:SetPoint("BOTTOMLEFT")
    missFlash:SetPoint("BOTTOMRIGHT")
    missFlash:SetHeight(170)
    missFlash:SetAlpha(0)

    -- Ebenen: Combo im Hintergrund < Kreise < Noten < Effekte
    local comboLayer = CreateFrame("Frame", nil, highway)
    comboLayer:SetAllPoints()
    comboLayer:SetFrameLevel(baseLevel + 2)
    comboPopup = CreatePopup(comboLayer, 72, highway, 0, 330, 1)
    comboPopup.text:SetTextColor(1, 1, 1)
    comboPopup.holder:SetAlpha(0.13)

    local padLayer = CreateFrame("Frame", nil, highway)
    padLayer:SetAllPoints()
    padLayer:SetFrameLevel(baseLevel + 3)

    noteLayer = CreateFrame("Frame", nil, highway)
    noteLayer:SetAllPoints()
    noteLayer:SetFrameLevel(baseLevel + 4)

    fxLayer = CreateFrame("Frame", nil, highway)
    fxLayer:SetAllPoints()
    fxLayer:SetFrameLevel(baseLevel + 30)

    for index, key in ipairs(LANE_KEYS) do
        CreateLane(index, key, padLayer)
    end

    for index = 1, PARTICLE_COUNT do
        local texture = CreateSolid(fxLayer, "OVERLAY", 0, 1, 1, 1, 1)
        texture:SetSize(5, 5)
        texture:SetColorTexture(1, 1, 1, 1)
        texture:SetBlendMode("ADD")
        texture:Hide()
        particles[index] = { texture = texture }
    end

    countdownPopup = CreatePopup(fxLayer, 96, highway, 0, 340, 0.95)
    bannerPopup = CreatePopup(fxLayer, 28, highway, 0, 430, 1.2, 30)
end

local function CreateBar(parent, width, height)
    local background = CreateSolid(parent, "ARTWORK", 0, 1, 1, 1, 0.1)
    background:SetSize(width, height)
    local fill = CreateSolid(parent, "ARTWORK", 1, 1, 1, 1, 1)
    fill:SetPoint("LEFT", background, "LEFT", 0, 0)
    fill:SetHeight(height)
    fill:SetWidth(1)
    return background, fill
end

local function CreateMultiplierPanel()
    local label = CreateText(frame, 12)
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -108)
    label:SetWidth(PANEL_WIDTH)
    label:SetJustifyH("CENTER")
    label:SetText("MULTIPLIKATOR")
    label:SetTextColor(0.7, 0.74, 0.82)

    local anchor = CreateFrame("Frame", nil, frame)
    anchor:SetSize(PANEL_WIDTH, 80)
    anchor:SetPoint("TOP", label, "BOTTOM", 0, -6)
    multiplierPopup = CreatePopup(frame, 62, anchor, 0, 40, 1)

    local barBackground
    barBackground, multiplierBar = CreateBar(frame, BAR_WIDTH, 8)
    barBackground:SetPoint("TOP", anchor, "BOTTOM", 0, -4)

    local comboLabel = CreateText(frame, 12)
    comboLabel:SetPoint("TOP", barBackground, "BOTTOM", 0, -26)
    comboLabel:SetText("COMBO")
    comboLabel:SetTextColor(0.7, 0.74, 0.82)

    comboText = CreateText(frame, 40)
    comboText:SetPoint("TOP", comboLabel, "BOTTOM", 0, -4)

    bestComboText = CreateText(frame, 12)
    bestComboText:SetPoint("TOP", comboText, "BOTTOM", 0, -6)
    bestComboText:SetTextColor(0.7, 0.74, 0.82)

    hintText = CreateText(frame, 12)
    hintText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 16)
    hintText:SetWidth(PANEL_WIDTH)
    hintText:SetJustifyH("CENTER")
    hintText:SetTextColor(0.7, 0.74, 0.82)
end

local function CreateScorePanel()
    local label = CreateText(frame, 12)
    label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -108)
    label:SetWidth(PANEL_WIDTH)
    label:SetJustifyH("CENTER")
    label:SetText("SCORE")
    label:SetTextColor(0.7, 0.74, 0.82)

    scoreText = CreateText(frame, 30)
    scoreText:SetPoint("TOP", label, "BOTTOM", 0, -6)

    recordText = CreateText(frame, 12)
    recordText:SetPoint("TOP", scoreText, "BOTTOM", 0, -6)
    recordText:SetTextColor(0.7, 0.74, 0.82)

    targetLabel = CreateText(frame, 12)
    targetLabel:SetPoint("TOP", recordText, "BOTTOM", 0, -24)

    local barBackground
    barBackground, targetBar = CreateBar(frame, BAR_WIDTH, 14)
    barBackground:SetPoint("TOP", targetLabel, "BOTTOM", 0, -6)

    accuracyText = CreateText(frame, 12)
    accuracyText:SetPoint("TOP", barBackground, "BOTTOM", 0, -24)

    countersText = CreateText(frame, 14)
    countersText:SetPoint("TOP", accuracyText, "BOTTOM", 0, -14)
    countersText:SetJustifyH("CENTER")
    countersText:SetSpacing(5)
end

local function CreateResults()
    results = {}
    results.frame = CreateFrame("Frame", nil, frame)
    results.frame:SetAllPoints(highway)
    results.frame:SetFrameLevel(frame:GetFrameLevel() + 60)

    local background = CreateSolid(results.frame, "BACKGROUND", 0, 0.03, 0.035, 0.06, 0.94)
    background:SetAllPoints()

    results.verdict = CreateText(results.frame, 28)
    results.verdict:SetPoint("TOP", results.frame, "TOP", 0, -34)

    results.tax = CreateText(results.frame, 15)
    results.tax:SetPoint("TOP", results.verdict, "BOTTOM", 0, -8)
    results.tax:SetTextColor(0.9, 0.9, 0.9)

    results.rankPopup = CreatePopup(results.frame, 120, results.frame, 0, 370, 1e9)

    results.score = CreateText(results.frame, 22)
    results.score:SetPoint("TOP", results.frame, "TOP", 0, -290)

    results.stats = CreateText(results.frame, 14)
    results.stats:SetPoint("TOP", results.score, "BOTTOM", 0, -18)
    results.stats:SetWidth(HIGHWAY_WIDTH - 20)
    results.stats:SetJustifyH("CENTER")
    results.stats:SetSpacing(7)

    results.badges = CreateText(results.frame, 16)
    results.badges:SetPoint("BOTTOM", results.frame, "BOTTOM", 0, 34)
    results.badges:SetWidth(HIGHWAY_WIDTH - 20)
    results.badges:SetJustifyH("CENTER")

    results.frame:Hide()
end

local function Initialize()
    if frame then
        return
    end

    frame = CreateFrame("Frame", "LidlRouletteGuitarHeroFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    local scale = math.min(1, (UIParent:GetWidth() - 40) / FRAME_WIDTH, (UIParent:GetHeight() - 40) / FRAME_HEIGHT)
    frame:SetScale(math.max(0.5, scale))
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 2 })
    frame:SetBackdropColor(0.03, 0.035, 0.06, FRAME_ALPHA)

    songText = CreateText(frame, 20)
    songText:SetPoint("TOP", frame, "TOP", 0, -14)
    songText:SetWidth(FRAME_WIDTH - 160)
    songText:SetJustifyH("CENTER")
    songText:SetWordWrap(false)

    difficultyText = CreateText(frame, 12)
    difficultyText:SetPoint("TOP", songText, "BOTTOM", 0, -6)

    timeText = CreateText(frame, 16)
    timeText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -38)

    local progressBackground
    progressBackground, progressBar = CreateBar(frame, PROGRESS_WIDTH, 4)
    progressBackground:SetPoint("TOP", frame, "TOP", 0, -72)
    progressBar:SetColorTexture(0.85, 0.88, 0.95, 1)

    CreateHighway()
    CreateMultiplierPanel()
    CreateScorePanel()
    CreateResults()
    SetHype(1)

    closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeButton:SetSize(110, 24)
    closeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -50, 16)
    closeButton:SetFrameLevel(frame:GetFrameLevel() + 70)
    closeButton:SetScript("OnClick", function()
        if active then
            StopGame(true, true)
        else
            frame:Hide()
        end
    end)

    frame:SetScript("OnKeyDown", function(_, key)
        HandleKeyDown(key)
    end)
    frame:SetScript("OnUpdate", function(_, frameSeconds)
        local now = GetTime()
        if active then
            UpdateGame(now)
        end
        UpdateEffects(now, frameSeconds)
    end)

    -- Bei /reload oder Logout mitten im Song darf die Musik nicht stumm bleiben.
    frame:RegisterEvent("PLAYER_LOGOUT")
    frame:SetScript("OnEvent", function()
        local volume = musicVolumeBeforeGame or musicVolumeRestoring
        if volume ~= nil then
            SetCVar("Sound_MusicVolume", string.format("%.3f", volume))
        end
    end)

    frame:Hide()
end

local function ResetRound()
    nextToSpawn = 1
    nextToExpire = 1
    lastCountdownNumber = nil
    lastDisplayedSecond = nil
    lastShownScore = nil
    counts ={ perfect = 0, good = 0, ok = 0, miss = 0 }
    score = 0
    displayedScore = 0
    combo = 0
    bestCombo = 0
    multiplier = 1
    timingSum = 0
    timingCount = 0
    judgedWeight = 0
    judgedNotes = 0
    targetReached = false
    musicStarted = false

    results.frame:Hide()
    HidePopup(results.rankPopup)
    HidePopup(bannerPopup)
    HidePopup(countdownPopup)
    missFlashAt = nil
    for _, particle in ipairs(particles) do
        particle.bornAt = nil
        particle.texture:Hide()
    end
    for _, lane in pairs(laneViews) do
        lane.flashAt = nil
        lane.pressedAt = nil
        HidePopup(lane.popup)
    end
    SetHype(1)
    targetBar:SetColorTexture(0.35, 0.75, 1, 1)
end

function GuitarHeroUi:Start(challengeIDArg)
    local songs = addonTable.GuitarHeroSongs or {}
    local challenge = addonTable.Roulette.GetChallenge(challengeIDArg)
    local requiredDifficulty = challenge and challenge.guitarHeroDifficulty
    if not DIFFICULTY_LABELS[requiredDifficulty] then
        print("|cffff0000[Lidl Roulette]|r WoW-Hero hat keine gültige Schwierigkeitsstufe.")
        return
    end

    local validSongs = {}
    for _, candidate in ipairs(songs) do
        if candidate.difficulty == requiredDifficulty
            and type(candidate.bpm) == "number" and candidate.bpm >= 30 and candidate.bpm <= 300
            and type(candidate.duration) == "number" and candidate.duration > 0 and candidate.duration <= 180
            and type(candidate.beatOffset) == "number" and candidate.beatOffset >= 0 and candidate.beatOffset < candidate.duration
            and type(candidate.stepsPerBeat) == "number" and candidate.stepsPerBeat >= 1
            and candidate.stepsPerBeat <= 8 and candidate.stepsPerBeat == math.floor(candidate.stepsPerBeat)
            and type(candidate.chart) == "string" and #candidate.chart > 0 and #candidate.chart <= 1024
            and type(candidate.targetPercent) == "number" and candidate.targetPercent > 0 and candidate.targetPercent <= 1
            and type(candidate.music) == "string" and candidate.music ~= "" then
            local candidateChart = candidate.chart:gsub("%s", ""):upper()
            if candidateChart:match("^[WASD%-]+$") and candidateChart:match("[WASD]") then
                table.insert(validSongs, { song = candidate, chart = candidateChart })
            end
        end
    end

    if #validSongs == 0 then
        print("|cffff0000[Lidl Roulette]|r WoW-Hero hat keinen gültigen Song konfiguriert.")
        return
    end

    Initialize()
    if active then
        StopGame(false)
    end
    PrepareKeyboard()

    local selected = validSongs[math.random(#validSongs)]
    song = selected.song
    challengeID = challengeIDArg
    beatDuration = 60 / song.bpm

    local stepDuration = beatDuration / song.stepsPerBeat
    local stepCount = math.min(#selected.chart, math.floor((song.duration - song.beatOffset) / stepDuration) + 1)
    notes = {}
    for step = 0, stepCount - 1 do
        local key = selected.chart:sub(step + 1, step + 1)
        if key ~= "-" then
            table.insert(notes, { key = key, t = song.beatOffset + step * stepDuration })
        end
    end

    targetScore = ComputeTargetScore(#notes, song.targetPercent)
    local records = GetRecords()
    previousRecord = records and records[song.title]

    ResetRound()
    startedAt = GetTime() + COUNTDOWN_SECONDS
    active = true

    songText:SetText(song.title)
    difficultyText:SetText("WoW-Hero  |  " .. (DIFFICULTY_LABELS[song.difficulty] or string.upper(song.difficulty)))
    targetLabel:SetText("ZIEL  " .. FormatNumber(targetScore))
    recordText:SetText(previousRecord and ("REKORD  " .. FormatNumber(previousRecord)) or "NOCH KEIN REKORD")
    closeButton:SetText("Abbrechen")
    if not keyboardReady then
        hintText:SetText("Im Kampf gestartet:\nKreise anklicken, die Tasten\ngehen nach dem Kampf.")
    end
    progressBar:SetWidth(1)
    UpdatePanels()

    frame:Show()
    frame:Raise()
    KeepKeysPropagating()
end
