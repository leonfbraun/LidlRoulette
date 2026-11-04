local addonName, addonTable = ...

addonTable.OsuUi = {}
local OsuUi = addonTable.OsuUi

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local PI = math.pi

-- Ablauf
local COUNTDOWN_SECONDS = 3
local MAX_TIMING_OFFSET = 0.3
local MUSIC_FADE_SECONDS = 0.8
local DEFAULT_TARGET_PERCENT = 0.7
local COMBO_BONUS_PER_COMBO = 2
local MAX_COMBO_BONUS = 500

-- Spielfeld / Kreise
local PLAYFIELD_WIDTH = 940
local PLAYFIELD_HEIGHT = 620
local CIRCLE_SIZE = 100
local BORDER = 4
local EDGE_MARGIN = CIRCLE_SIZE / 2 + 10
local SPACING = CIRCLE_SIZE + 24
local MAX_NOTE_DISTANCE = 230
local FLOW_ANGLE = 0.9          -- max. Richtungsänderung bei schnellen Folgen (Bogenmaß)
local MAX_CHART_STEPS = 8192
local MAX_SONG_SECONDS = 600
local Z_RANGE = 200             -- frühere Objekte liegen über späteren
local LAYER_STEP = 300

-- Approach-Ring: startet bei CIRCLE_SIZE * (1 + RING_GROWTH) und ist genau zum
-- Treffzeitpunkt so groß wie der Kreis selbst.
local APPROACH_SECONDS = 1.1
local FADE_IN_SECONDS = 0.35
local RING_GROWTH = 1.2
local RING_THICKNESS = 4

-- Trefffenster (± Sekunden) und Slider-Anteil je Schwierigkeit
local DIFFICULTY = {
    easy   = { w300 = 0.065, w100 = 0.125, w50 = 0.185, sliderChance = 0.5 },
    medium = { w300 = 0.055, w100 = 0.110, w50 = 0.165, sliderChance = 0.4 },
    hard   = { w300 = 0.045, w100 = 0.090, w50 = 0.140, sliderChance = 0.3 },
    legendary = { w300 = 0.040, w100 = 0.085, w50 = 0.130, sliderChance = 0.3 },
}
local EARLY_MISS_SECONDS = 0.08 -- Klick knapp vor dem Fenster zählt als Fehler (gegen Spammen)

-- Slider
local SLIDER_SPEED = 260        -- Pixel pro Sekunde
local MIN_SLIDER_SECONDS = 0.5
local MAX_SLIDER_SECONDS = 1.6
local MIN_SLIDER_LENGTH = 120
local MAX_SLIDER_LENGTH = 420
local FOLLOW_RADIUS = CIRCLE_SIZE * 0.95
local SLIDER_SEGMENTS = 8       -- Anzahl Linienstücke pro Slider (Kurven werden daraus gebildet)
local SLIDER_CURVE_CHANCE = 0.6 -- Anteil gebogener Slider
local TRACK_GRACE_SECONDS = 0.06

-- Spinner
local SPINNER_SIZE = 380
local SPINNER_MIN_GAP = 3.0     -- ab dieser Lücke zwischen zwei Noten wird ein Spinner eingebaut
local SPINNER_MIN_SECONDS = 1.5
local SPINNER_MAX_SECONDS = 4
local SPINNER_LEAD_OUT = 0.6
local SPINNER_DEADZONE = 25
local SPIN_PER_SECOND = 1.5     -- geforderte Umdrehungen pro Sekunde
local SPINNER_CLEAR_RADIUS = SPINNER_SIZE / 2 + CIRCLE_SIZE / 2

-- Farben
local BG_COLOR = { 0.035, 0.075, 0.13 }
local INNER_COLOR = { 0.12, 0.2, 0.35 }
local RING_COLOR = { 0.25, 0.85, 1 }

local TIMING_INSTRUCTION = "Linksklick, Y oder X, wenn der Ring den Kreis berührt  |  Slider: halten und dem Ball folgen  |  Spinner: halten und um die Mitte kreisen"
local ACTION_KEYS = { Y = true, X = true }
local HIT_SOUND_FILE = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\OSU\\OsuHitSound.ogg"

local frame
local playfield
local approachLayer
local bodyLayer
local headLayer
local spinner
local songText
local scoreText
local statusText
local timeText
local feedbackText
local cursorFeedbackFrame
local cursorFeedbackText
local closeButton
local musicFadeTicker
local songSoundHandle
local musicVolumeBeforeGame
local song
local windows
local challengeID
local objects = {}
local activeObjects = {}
local viewPool = {}
local nextToShow = 1
local startedAt
local countdownAt
local lastCountdownNumber
local lastShownSecond
local score = 0
local targetScore = 0
local hits = 0
local misses = 0
local combo = 0
local errorSum = 0
local errorCount = 0
local active = false
local musicStarted = false
local scoreDirty = false
local feedbackExpiresAt
local heldKeys = {}
local keyboardReady = false

local function Clamp(value, low, high)
    if value < low then
        return low
    elseif value > high then
        return high
    end
    return value
end

local function UpdateScore()
    scoreDirty = false
    scoreText:SetText(string.format("%07d / ZIEL %07d    COMBO %d    FEHLER %d", score, targetScore, combo, misses))
end

local function GetComboBonus(comboLength)
    return math.min(comboLength * COMBO_BONUS_PER_COMBO, MAX_COMBO_BONUS)
end

local function AwardComboPoints(basePoints)
    combo = combo + 1
    local bonus = GetComboBonus(combo)
    score = score + basePoints + bonus
    scoreDirty = true
    return bonus
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

local function GetCursorInPlayfield()
    local cursorX, cursorY = GetCursorPosition()
    local scale = playfield:GetEffectiveScale()
    return cursorX / scale - playfield:GetLeft(), cursorY / scale - playfield:GetBottom()
end

local function IsActionDown()
    return next(heldKeys) ~= nil or IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
end

-- SetPropagateKeyboardInput ist im Kampf gesperrt. Dort lösen Y/X zusätzlich ihre Keybinds aus.
local function SetKeyPropagation(enabled)
    if not InCombatLockdown() then
        frame:SetPropagateKeyboardInput(enabled)
    end
end

-- Ein neuer Frame würde alle Tasten schlucken. Die Tastatur wird daher erst aktiviert, sobald
-- die Weitergabe eingeschaltet werden kann. Bis dahin funktioniert nur die Maus.
local function PrepareKeyboard()
    if keyboardReady or InCombatLockdown() then
        return
    end
    frame:SetPropagateKeyboardInput(true)
    frame:EnableKeyboard(true)
    keyboardReady = true
end

-- ---------------------------------------------------------------------------
-- Darstellung (Frames werden gepoolt und wiederverwendet)
-- ---------------------------------------------------------------------------

local function CreateView()
    local view = {}

    -- Approach-Ring: eigene Ebene unterhalb aller Kreise, damit er nie einen anderen Kreis überdeckt.
    view.approach = CreateFrame("Frame", nil, approachLayer)
    view.approach:SetSize(CIRCLE_SIZE, CIRCLE_SIZE)
    view.ringOuter = CreateMaskedTexture(view.approach, "ARTWORK", 0)
    view.ringOuter:SetPoint("CENTER")
    view.ringInner = CreateMaskedTexture(view.approach, "ARTWORK", 1)
    view.ringInner:SetPoint("CENTER")
    view.ringInner:SetVertexColor(BG_COLOR[1], BG_COLOR[2], BG_COLOR[3], 1)

    -- Slider-Körper: Pfad aus SLIDER_SEGMENTS Linienstücken (Rand + Füllung) mit runden Gelenken.
    view.body = CreateFrame("Frame", nil, bodyLayer)
    view.body:SetAllPoints(playfield)
    view.outlines = {}
    view.fills = {}
    view.capBorders = {}
    view.capInners = {}
    for index = 1, SLIDER_SEGMENTS do
        local outline = view.body:CreateLine(nil, "BACKGROUND", nil, 0)
        outline:SetThickness(CIRCLE_SIZE)
        outline:SetColorTexture(1, 1, 1, 1)
        view.outlines[index] = outline

        local fill = view.body:CreateLine(nil, "BACKGROUND", nil, 1)
        fill:SetThickness(CIRCLE_SIZE - BORDER * 2)
        fill:SetColorTexture(INNER_COLOR[1], INNER_COLOR[2], INNER_COLOR[3], 1)
        view.fills[index] = fill
    end
    for index = 1, SLIDER_SEGMENTS + 1 do
        local capBorder = CreateMaskedTexture(view.body, "BACKGROUND", 0)
        capBorder:SetSize(CIRCLE_SIZE, CIRCLE_SIZE)
        capBorder:SetVertexColor(1, 1, 1, 1)
        view.capBorders[index] = capBorder

        local capInner = CreateMaskedTexture(view.body, "BACKGROUND", 1)
        capInner:SetSize(CIRCLE_SIZE - BORDER * 2, CIRCLE_SIZE - BORDER * 2)
        capInner:SetVertexColor(INNER_COLOR[1], INNER_COLOR[2], INNER_COLOR[3], 1)
        view.capInners[index] = capInner
    end
    -- Pfeil am Slider-Ende bei Reverse-Slidern
    view.repeatMark = view.body:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    view.repeatMark:SetFont("Fonts\\FRIZQT__.TTF", 34, "OUTLINE")
    view.repeatMark:SetTextColor(1, 1, 1, 0.95)

    -- Kreis (bzw. Slider-Kopf)
    view.head = CreateFrame("Frame", nil, headLayer)
    view.head:SetSize(CIRCLE_SIZE, CIRCLE_SIZE)
    local border = CreateMaskedTexture(view.head, "ARTWORK", 0)
    border:SetAllPoints()
    border:SetVertexColor(1, 1, 1, 1)
    local inner = CreateMaskedTexture(view.head, "ARTWORK", 1)
    inner:SetPoint("TOPLEFT", view.head, "TOPLEFT", BORDER, -BORDER)
    inner:SetPoint("BOTTOMRIGHT", view.head, "BOTTOMRIGHT", -BORDER, BORDER)
    inner:SetVertexColor(INNER_COLOR[1], INNER_COLOR[2], INNER_COLOR[3], 1)
    view.number = view.head:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    view.number:SetFont("Fonts\\FRIZQT__.TTF", 19, "OUTLINE")
    view.number:SetPoint("CENTER")
    view.number:SetTextColor(1, 1, 1, 0.85)

    -- Slider-Ball mit Follow-Kreis
    view.ball = CreateFrame("Frame", nil, headLayer)
    view.ball:SetSize(CIRCLE_SIZE, CIRCLE_SIZE)
    view.follow = CreateMaskedTexture(view.ball, "ARTWORK", 0)
    view.follow:SetSize(FOLLOW_RADIUS * 2, FOLLOW_RADIUS * 2)
    view.follow:SetPoint("CENTER")
    view.follow:SetVertexColor(1, 1, 1, 0.18)
    view.ballDot = CreateMaskedTexture(view.ball, "ARTWORK", 1)
    view.ballDot:SetSize(CIRCLE_SIZE * 0.65, CIRCLE_SIZE * 0.65)
    view.ballDot:SetPoint("CENTER")
    view.ballDot:SetVertexColor(RING_COLOR[1], RING_COLOR[2], RING_COLOR[3], 0.95)

    view.approach:Hide()
    view.body:Hide()
    view.head:Hide()
    view.ball:Hide()
    return view
end

local function AcquireView(obj)
    if obj.kind == "spinner" then
        obj.rotations = 0
        spinner.frame:Show()
        spinner.frame:SetAlpha(0)
        spinner.progress:SetSize(1, 1)
        spinner.text:SetText("SPIN!")
        return
    end

    local view
    for _, candidate in ipairs(viewPool) do
        if not candidate.obj then
            view = candidate
            break
        end
    end
    if not view then
        view = CreateView()
        table.insert(viewPool, view)
    end

    view.obj = obj
    view.bucket = nil
    obj.view = view

    -- Frühere Objekte liegen über späteren (wie in osu!), Ball immer ganz oben.
    local z = Z_RANGE - (obj.index % Z_RANGE)
    view.approach:SetFrameLevel(approachLayer:GetFrameLevel() + z)
    view.body:SetFrameLevel(bodyLayer:GetFrameLevel() + z)
    view.head:SetFrameLevel(headLayer:GetFrameLevel() + z)
    view.ball:SetFrameLevel(headLayer:GetFrameLevel() + Z_RANGE + 5)

    view.approach:ClearAllPoints()
    view.approach:SetPoint("CENTER", playfield, "BOTTOMLEFT", obj.x, obj.y)
    view.approach:SetAlpha(0)
    view.approach:Show()

    view.head:ClearAllPoints()
    view.head:SetPoint("CENTER", playfield, "BOTTOMLEFT", obj.x, obj.y)
    view.head:SetAlpha(0)
    view.head:Show()
    view.number:SetText(obj.number)

    if obj.kind == "slider" then
        local path = obj.path
        for index = 1, SLIDER_SEGMENTS do
            local from = path[index]
            local to = path[index + 1]
            view.outlines[index]:SetStartPoint("BOTTOMLEFT", view.body, from[1], from[2])
            view.outlines[index]:SetEndPoint("BOTTOMLEFT", view.body, to[1], to[2])
            view.fills[index]:SetStartPoint("BOTTOMLEFT", view.body, from[1], from[2])
            view.fills[index]:SetEndPoint("BOTTOMLEFT", view.body, to[1], to[2])
        end
        for index = 1, SLIDER_SEGMENTS + 1 do
            local point = path[index]
            view.capBorders[index]:ClearAllPoints()
            view.capBorders[index]:SetPoint("CENTER", view.body, "BOTTOMLEFT", point[1], point[2])
            view.capInners[index]:ClearAllPoints()
            view.capInners[index]:SetPoint("CENTER", view.body, "BOTTOMLEFT", point[1], point[2])
        end

        if obj.slides > 1 then
            -- Pfeil zeigt vom Ende zurück Richtung Start.
            local last = path[#path]
            local before = path[#path - 1]
            local dx = before[1] - last[1]
            local dy = before[2] - last[2]
            local arrow
            if math.abs(dx) >= math.abs(dy) then
                arrow = dx < 0 and "<" or ">"
            else
                arrow = dy > 0 and "^" or "v"
            end
            view.repeatMark:SetText(arrow)
            view.repeatMark:ClearAllPoints()
            view.repeatMark:SetPoint("CENTER", view.body, "BOTTOMLEFT", last[1], last[2])
            view.repeatMark:Show()
        else
            view.repeatMark:Hide()
        end
        view.body:SetAlpha(0)
        view.body:Show()
    else
        view.body:Hide()
    end
    view.ball:Hide()
end

local function ReleaseView(obj)
    if obj.kind == "spinner" then
        spinner.frame:Hide()
        return
    end

    local view = obj.view
    if not view then
        return
    end
    view.obj = nil
    obj.view = nil
    view.approach:Hide()
    view.head:Hide()
    view.body:Hide()
    view.ball:Hide()
end

-- ---------------------------------------------------------------------------
-- Chart -> Objekte (Kreise, Slider, Spinner)
-- ---------------------------------------------------------------------------

local function MakeRng(text)
    local state = 12345
    for index = 1, #text do
        state = (state * 31 + text:byte(index)) % 2147483647
    end
    if state == 0 then
        state = 1
    end
    return function()
        state = (state * 16807) % 2147483647
        return state / 2147483647
    end
end

local function InBounds(x, y)
    return x >= EDGE_MARGIN and x <= PLAYFIELD_WIDTH - EDGE_MARGIN
        and y >= EDGE_MARGIN and y <= PLAYFIELD_HEIGHT - EDGE_MARGIN
end

-- Prüft nur gegen Objekte, die zum selben Zeitpunkt wie das neue sichtbar sind.
-- Wie weit müssen sich zwei Objekte voneinander entfernt befinden? Bei schnellen Folgen
-- (Streams) dürfen Kreise dicht beieinander liegen, bei größeren Abständen nicht.
local function RequiredDistance(gapTime)
    if gapTime < 0.12 then
        return 52
    elseif gapTime < 0.22 then
        return 62
    elseif gapTime < 0.4 then
        return 92
    end
    return SPACING
end

-- Prüft nur gegen Objekte, die zum selben Zeitpunkt wie das neue sichtbar sind.
local function IsPositionClear(x, y, spawnAt, hitAt, list, scale)
    scale = scale or 1
    for index = #list, 1, -1 do
        local other = list[index]
        if other.endTime + 0.2 < spawnAt then
            break
        end

        if other.kind == "spinner" then
            local dx = x - other.x
            local dy = y - other.y
            if dx * dx + dy * dy < SPINNER_CLEAR_RADIUS * SPINNER_CLEAR_RADIUS then
                return false
            end
        else
            local gapTime = hitAt - other.endTime
            local count = #other.points
            for pointIndex, point in ipairs(other.points) do
                local required = SPACING
                if other.kind == "circle" or pointIndex == count then
                    required = RequiredDistance(gapTime)
                end
                required = required * scale
                local dx = x - point[1]
                local dy = y - point[2]
                if dx * dx + dy * dy < required * required then
                    return false
                end
            end
        end
    end

    return true
end

local function GetDistanceRange(timeSincePrevious)
    if timeSincePrevious < 0.12 then
        return 54, 64
    elseif timeSincePrevious < 0.22 then
        return 66, 96
    elseif timeSincePrevious < 0.4 then
        return 96, 150
    end
    return SPACING, math.min(MAX_NOTE_DISTANCE, SPACING + 8 + math.max(0, timeSincePrevious - 0.25) * 70)
end

-- Gibt x, y und die Bewegungsrichtung zum letzten Objekt zurück. Bei schnellen Folgen
-- bleibt die Richtung ungefähr erhalten (Flow), nach Pausen springt das Muster.
local function GetNextPosition(previousX, previousY, previousAngle, timeSincePrevious, spawnAt, hitAt, list, rng)
    if not previousX then
        return PLAYFIELD_WIDTH / 2, PLAYFIELD_HEIGHT / 2, nil
    end

    local minDistance, maxDistance = GetDistanceRange(timeSincePrevious)
    local flowing = timeSincePrevious < 0.4 and previousAngle ~= nil

    for attempt = 1, 64 do
        local angle
        if flowing and attempt <= 40 then
            angle = previousAngle + (rng() - 0.5) * 2 * FLOW_ANGLE
        else
            angle = rng() * PI * 2
        end
        local distance = minDistance + rng() * (maxDistance - minDistance)
        local x = previousX + math.cos(angle) * distance
        local y = previousY + math.sin(angle) * distance
        if InBounds(x, y) and IsPositionClear(x, y, spawnAt, hitAt, list) then
            return x, y, angle
        end
    end

    -- Fallback: freier Punkt, dessen Abstand am besten zum Wunschabstand passt. Ist das Feld
    -- zu voll, wird der geforderte Mindestabstand schrittweise etwas verkleinert.
    local bestX
    local bestY
    local bestScore = math.huge
    for _, scale in ipairs({ 1, 0.8, 0.6 }) do
        local stageX
        local stageY
        local stageScore = math.huge
        for x = EDGE_MARGIN, PLAYFIELD_WIDTH - EDGE_MARGIN, 12 do
            for y = EDGE_MARGIN, PLAYFIELD_HEIGHT - EDGE_MARGIN, 12 do
                local dx = x - previousX
                local dy = y - previousY
                local score = math.abs(math.sqrt(dx * dx + dy * dy) - maxDistance)
                if score < stageScore and IsPositionClear(x, y, spawnAt, hitAt, list, scale) then
                    stageX = x
                    stageY = y
                    stageScore = score
                end
            end
        end
        if stageX and (not bestX or stageScore < bestScore) then
            bestX, bestY, bestScore = stageX, stageY, stageScore
        end
        if bestScore <= 40 then
            break
        end
    end

    if not bestX then
        bestX = EDGE_MARGIN + rng() * (PLAYFIELD_WIDTH - EDGE_MARGIN * 2)
        bestY = EDGE_MARGIN + rng() * (PLAYFIELD_HEIGHT - EDGE_MARGIN * 2)
    end
    return bestX, bestY, atan2(bestY - previousY, bestX - previousX)
end

-- Erzeugt den Pfad eines Sliders (gerade oder als Bogen) aus SLIDER_SEGMENTS Stücken.
local function BuildSliderPath(x, y, spanSeconds, spawnAt, hitAt, list, rng)
    local length = Clamp(spanSeconds * SLIDER_SPEED, MIN_SLIDER_LENGTH, MAX_SLIDER_LENGTH)
    local curved = rng() < SLIDER_CURVE_CHANCE

    for _ = 1, 40 do
        local angle = rng() * PI * 2
        local chord = curved and length * 0.85 or length
        local x2 = x + math.cos(angle) * chord
        local y2 = y + math.sin(angle) * chord
        local controlX = (x + x2) / 2
        local controlY = (y + y2) / 2
        if curved then
            local side = rng() < 0.5 and -1 or 1
            controlX = controlX - math.sin(angle) * side * chord * 0.45
            controlY = controlY + math.cos(angle) * side * chord * 0.45
        end

        local path = { { x, y } }
        local valid = true
        for step = 1, SLIDER_SEGMENTS do
            local u = step / SLIDER_SEGMENTS
            local inverse = 1 - u
            local px = inverse * inverse * x + 2 * inverse * u * controlX + u * u * x2
            local py = inverse * inverse * y + 2 * inverse * u * controlY + u * u * y2
            if not InBounds(px, py) or not IsPositionClear(px, py, spawnAt, hitAt, list) then
                valid = false
                break
            end
            path[#path + 1] = { px, py }
        end

        if valid then
            return path
        end
    end

    return nil
end

local function GetPathPoint(obj, fraction)
    local path = obj.path
    local lengths = obj.pathLengths
    local target = fraction * obj.pathTotal
    for index = 2, #path do
        if target <= lengths[index] then
            local segment = lengths[index] - lengths[index - 1]
            local t = segment > 0 and (target - lengths[index - 1]) / segment or 0
            local from = path[index - 1]
            local to = path[index]
            return from[1] + (to[1] - from[1]) * t, from[2] + (to[2] - from[2]) * t
        end
    end

    local last = path[#path]
    return last[1], last[2]
end

-- Wandelt ein Chart in eine Liste von Einträgen { kind, hitAt, seconds, slides } um.
--  * osuSections (eigenes Chart, ein Eintrag pro Tempo-Abschnitt): o = Kreis, s = Slider,
--    r = Reverse-Slider, p = Spinner, "~" verlängert den davorstehenden Slider/Spinner um einen
--    Schritt, "-" = Pause.
--  * sonst wird das Guitar-Hero-Chart automatisch umgewandelt: Jede Note wird zum Kreis,
--    nach ausreichender Lücke (mit Wahrscheinlichkeit sliderChance) zum Slider, bei sehr
--    großer Lücke zum Spinner.
local function CollectEntries(songData, chart, diff, rng)
    local entries = {}
    if songData.osuSections then
        for _, section in ipairs(songData.osuSections) do
            local sectionChart = section.chart:gsub("%s", "")
            local sectionStep = 60 / section.bpm / section.stepsPerBeat
            local index = 1
            while index <= #sectionChart do
                local token = sectionChart:sub(index, index)
                if token == "o" or token == "s" or token == "r" or token == "p" then
                    local steps = 1
                    while sectionChart:sub(index + steps, index + steps) == "~" do
                        steps = steps + 1
                    end

                    local hitAt = songData.beatOffset + section.startTime + (index - 1) * sectionStep
                    if hitAt < songData.duration then
                        local seconds = math.min(steps * sectionStep, songData.duration - hitAt - 0.1)
                        local entry = { kind = "circle", hitAt = hitAt }
                        if token == "p" and seconds >= 0.9 then
                            entry.kind = "spinner"
                            entry.seconds = seconds
                        elseif (token == "s" or token == "r") and seconds - 0.05 >= 0.3 then
                            entry.kind = "slider"
                            entry.seconds = seconds
                            entry.slides = (token == "r" and seconds >= 0.6) and 2 or 1
                        end
                        table.insert(entries, entry)
                    end
                    index = index + steps
                else
                    index = index + 1
                end
            end
        end
        return entries
    end

    local stepDuration = 60 / songData.bpm / songData.stepsPerBeat
    local sliderChance = songData.sliderChance or diff.sliderChance
    local allowSpinners = songData.spinners ~= false
    local noteTimes = {}
    for index = 1, #chart do
        if chart:sub(index, index) ~= "-" then
            local hitAt = songData.beatOffset + (index - 1) * stepDuration
            if hitAt < songData.duration then
                table.insert(noteTimes, hitAt)
            end
        end
    end

    for index, hitAt in ipairs(noteTimes) do
        local nextHitAt = noteTimes[index + 1] or songData.duration
        local gap = nextHitAt - hitAt
        local entry = { kind = "circle", hitAt = hitAt }

        if allowSpinners and gap >= SPINNER_MIN_GAP then
            local spinSeconds = math.min(gap - SPINNER_LEAD_OUT, SPINNER_MAX_SECONDS)
            if spinSeconds >= SPINNER_MIN_SECONDS then
                entry.kind = "spinner"
                entry.seconds = spinSeconds
            end
        end
        if entry.kind == "circle" then
            local available = math.min(gap - stepDuration, MAX_SLIDER_SECONDS)
            available = math.floor(available / stepDuration) * stepDuration
            if available >= MIN_SLIDER_SECONDS and rng() < sliderChance then
                entry.kind = "slider"
                entry.seconds = available
                entry.slides = (available >= 0.9 and rng() < 0.3) and 2 or 1
            end
        end
        table.insert(entries, entry)
    end

    return entries
end

-- Gibt Liste der Objekte und die maximal erreichbare Punktzahl zurück.
-- Der Zufall (Positionen, Slider-Formen) ist pro Song fest geseedet, jeder Durchlauf
-- sieht also gleich aus.
local function BuildObjects(songData, chart, diff)
    local list = {}
    local rng = MakeRng(songData.title)
    local tickInterval = math.max(0.25, 60 / songData.bpm)
    local entries = CollectEntries(songData, chart, diff, rng)

    local maxScore = 0
    local maxCombo = 0
    local comboNumber = 0
    local previousX
    local previousY
    local previousAngle
    local previousEnd

    for _, entry in ipairs(entries) do
        local time = entry.hitAt + songData.timingOffset
        local obj = {
            kind = entry.kind,
            time = time,
            endTime = time,
            judged = false,
            index = #list + 1,
            slides = 1,
        }

        if obj.kind == "spinner" then
            obj.endTime = time + entry.seconds
            obj.spawnAt = time - 0.25
        else
            obj.spawnAt = time - APPROACH_SECONDS
            if obj.kind == "slider" then
                obj.slides = entry.slides or 1
                obj.endTime = time + entry.seconds - 0.05 -- Slider-Ende wird minimal früher gewertet
            end
        end

        if obj.kind == "spinner" then
            obj.x = PLAYFIELD_WIDTH / 2
            obj.y = PLAYFIELD_HEIGHT / 2
            obj.required = math.max(2, math.floor((obj.endTime - time) * SPIN_PER_SECOND))
            obj.rotations = 0
            maxCombo = maxCombo + 1
            maxScore = maxScore + 100 + GetComboBonus(maxCombo)
            previousX, previousY, previousAngle = obj.x, obj.y, nil
        else
            comboNumber = comboNumber + 1
            obj.number = (comboNumber - 1) % 9 + 1
            local moveAngle
            obj.x, obj.y, moveAngle = GetNextPosition(
                previousX,
                previousY,
                previousAngle,
                previousEnd and time - previousEnd or 0,
                obj.spawnAt,
                time,
                list,
                rng
            )
            obj.points = { { obj.x, obj.y } }
            maxCombo = maxCombo + 1
            maxScore = maxScore + 300 + GetComboBonus(maxCombo)
            previousX, previousY, previousAngle = obj.x, obj.y, moveAngle

            if obj.kind == "slider" then
                local spanSeconds = (obj.endTime - time) / obj.slides
                local path = BuildSliderPath(obj.x, obj.y, spanSeconds, obj.spawnAt, time, list, rng)
                if path then
                    obj.path = path
                    obj.points = path
                    obj.pathLengths = { 0 }
                    for index = 2, #path do
                        local dx = path[index][1] - path[index - 1][1]
                        local dy = path[index][2] - path[index - 1][2]
                        obj.pathLengths[index] = obj.pathLengths[index - 1] + math.sqrt(dx * dx + dy * dy)
                    end
                    obj.pathTotal = obj.pathLengths[#path]

                    -- Ticks (10) und Wendepunkte (30), danach das Ende (30)
                    obj.events = {}
                    obj.nextEvent = 1
                    obj.lastTracked = -1000
                    for span = 0, obj.slides - 1 do
                        local spanStart = time + span * spanSeconds
                        local tickTime = spanStart + tickInterval
                        while tickTime < spanStart + spanSeconds - 0.12 do
                            table.insert(obj.events, { t = tickTime, points = 10 })
                            tickTime = tickTime + tickInterval
                        end
                        if span < obj.slides - 1 then
                            table.insert(obj.events, { t = spanStart + spanSeconds, points = 30 })
                        end
                    end
                    for _, event in ipairs(obj.events) do
                        maxCombo = maxCombo + 1
                        maxScore = maxScore + event.points + GetComboBonus(maxCombo)
                    end
                    maxCombo = maxCombo + 1
                    maxScore = maxScore + 30 + GetComboBonus(maxCombo)

                    -- Ein Slider mit gerader Zahl Durchläufe endet wieder am Start.
                    local last = path[#path]
                    local before = path[#path - 1]
                    if obj.slides % 2 == 0 then
                        previousX, previousY = obj.x, obj.y
                        previousAngle = atan2(before[2] - last[2], before[1] - last[1])
                    else
                        previousX, previousY = last[1], last[2]
                        previousAngle = atan2(last[2] - before[2], last[1] - before[1])
                    end
                else
                    obj.kind = "circle" -- kein Platz für den Slider: normaler Kreis
                    obj.slides = 1
                    obj.endTime = time
                end
            end
        end

        table.insert(list, obj)
        previousEnd = obj.endTime
    end

    return list, maxScore
end

-- ---------------------------------------------------------------------------
-- Spiellogik
-- ---------------------------------------------------------------------------

local function RegisterMiss(text)
    misses = misses + 1
    combo = 0
    scoreDirty = true
    ShowCursorFeedback(text, 1, 0.25, 0.25)
end

-- Wertet den Klick auf Kreis bzw. Slider-Kopf. dt < 0 bedeutet zu früh.
local function JudgeHead(obj, dt)
    local timingError = math.abs(dt)
    local direction = dt < 0 and "FRÜH" or "SPÄT"
    obj.headDone = true
    obj.view.head:Hide()
    obj.view.approach:Hide()

    if timingError > windows.w50 then
        RegisterMiss("ZU " .. direction)
        return
    end

    hits = hits + 1
    errorSum = errorSum + dt
    errorCount = errorCount + 1
    PlaySoundFile(HIT_SOUND_FILE, "SFX")

    local points = timingError <= windows.w300 and 300 or timingError <= windows.w100 and 100 or 50
    local comboBonus = AwardComboPoints(points)
    if points == 300 then
        ShowCursorFeedback("PERFEKT  +" .. (points + comboBonus), 0.35, 1, 0.5)
    elseif points == 100 then
        ShowCursorFeedback("GUT  +" .. (points + comboBonus) .. "  " .. direction, 1, 0.9, 0.25)
    else
        ShowCursorFeedback("KNAPP  +" .. (points + comboBonus) .. "  " .. direction, 1, 0.6, 0.2)
    end
end

-- Nur das früheste noch offene Objekt kann getroffen werden, Klicks daneben werden ignoriert.
local function HandleClick()
    if not active or not musicStarted then
        return
    end

    local target
    for _, obj in ipairs(activeObjects) do
        if obj.kind ~= "spinner" and not obj.headDone then
            target = obj
            break
        end
    end
    if not target then
        return
    end

    local dt = (GetTime() - startedAt) - target.time
    if dt < -(windows.w50 + EARLY_MISS_SECONDS) then
        return
    end

    local cursorX, cursorY = GetCursorInPlayfield()
    local dx = cursorX - target.x
    local dy = cursorY - target.y
    if dx * dx + dy * dy > (CIRCLE_SIZE / 2) ^ 2 then
        return
    end

    JudgeHead(target, dt)
    if target.kind == "circle" then
        target.judged = true
        target.finished = true
    end
end

local function UpdateNote(obj, elapsed, cursorX, cursorY, held)
    local view = obj.view
    local fade = Clamp((elapsed - obj.spawnAt) / FADE_IN_SECONDS, 0, 1)

    if not obj.headDone then
        if elapsed - obj.time > windows.w50 then
            obj.headDone = true
            view.head:Hide()
            view.approach:Hide()
            RegisterMiss("VERFEHLT")
            if obj.kind == "circle" then
                obj.judged = true
                obj.finished = true
                return
            end
        else
            local untilHit = obj.time - elapsed
            local progress = Clamp(1 - untilHit / APPROACH_SECONDS, 0, 1)
            local ringSize = CIRCLE_SIZE * (1 + RING_GROWTH * (1 - progress))
            view.ringOuter:SetSize(ringSize, ringSize)
            view.ringInner:SetSize(ringSize - RING_THICKNESS * 2, ringSize - RING_THICKNESS * 2)
            view.head:SetAlpha(fade)
            view.approach:SetAlpha(fade)

            -- Ring wird grün/gelb/orange, sobald er im jeweiligen Trefffenster liegt.
            local timingError = math.abs(untilHit)
            local bucket = timingError <= windows.w300 and 1 or timingError <= windows.w100 and 2
                or timingError <= windows.w50 and 3 or 4
            if bucket ~= view.bucket then
                view.bucket = bucket
                if bucket == 1 then
                    view.ringOuter:SetVertexColor(0.35, 1, 0.5, 0.9)
                elseif bucket == 2 then
                    view.ringOuter:SetVertexColor(1, 0.9, 0.25, 0.9)
                elseif bucket == 3 then
                    view.ringOuter:SetVertexColor(1, 0.55, 0.18, 0.9)
                else
                    view.ringOuter:SetVertexColor(RING_COLOR[1], RING_COLOR[2], RING_COLOR[3], 0.85)
                end
            end
        end
    end

    if obj.kind ~= "slider" then
        return
    end

    view.body:SetAlpha(fade)
    if elapsed < obj.time then
        return
    end

    local progress = Clamp((elapsed - obj.time) / (obj.endTime - obj.time), 0, 1)
    local travelled = progress * obj.slides
    local span = math.min(math.floor(travelled), obj.slides - 1)
    local fraction = travelled - span
    if span % 2 == 1 then
        fraction = 1 - fraction -- Rückweg bei Reverse-Slidern
    end
    local ballX, ballY = GetPathPoint(obj, fraction)
    if span >= 1 then
        view.repeatMark:Hide()
    end
    view.ball:ClearAllPoints()
    view.ball:SetPoint("CENTER", playfield, "BOTTOMLEFT", ballX, ballY)
    view.ball:Show()

    local dx = cursorX - ballX
    local dy = cursorY - ballY
    if held and dx * dx + dy * dy <= FOLLOW_RADIUS * FOLLOW_RADIUS then
        obj.lastTracked = elapsed
    end

    while obj.events[obj.nextEvent] and elapsed >= obj.events[obj.nextEvent].t do
        local event = obj.events[obj.nextEvent]
        obj.nextEvent = obj.nextEvent + 1
        if elapsed - obj.lastTracked <= TRACK_GRACE_SECONDS then
            AwardComboPoints(event.points)
            if event.points >= 30 then
                PlaySoundFile(HIT_SOUND_FILE, "SFX")
            end
        else
            combo = 0
            scoreDirty = true
        end
    end

    if elapsed >= obj.endTime then
        if elapsed - obj.lastTracked <= TRACK_GRACE_SECONDS then
            AwardComboPoints(30)
            PlaySoundFile(HIT_SOUND_FILE, "SFX")
        else
            combo = 0
            scoreDirty = true
        end
        obj.judged = true
        obj.finished = true
    end
end

local function UpdateSpinner(obj, elapsed, cursorX, cursorY, held)
    spinner.frame:SetAlpha(Clamp((elapsed - obj.spawnAt) / 0.25, 0, 1))
    if elapsed < obj.time then
        return
    end

    local dx = cursorX - obj.x
    local dy = cursorY - obj.y
    if held and dx * dx + dy * dy >= SPINNER_DEADZONE * SPINNER_DEADZONE then
        local angle = atan2(dy, dx)
        if obj.lastAngle then
            local delta = angle - obj.lastAngle
            if delta > PI then
                delta = delta - PI * 2
            elseif delta < -PI then
                delta = delta + PI * 2
            end
            obj.rotations = obj.rotations + math.abs(delta) / (PI * 2)
        end
        obj.lastAngle = angle
        spinner.handle:ClearAllPoints()
        spinner.handle:SetPoint("CENTER", spinner.frame, "CENTER",
            math.cos(angle) * (SPINNER_SIZE / 2 - 40), math.sin(angle) * (SPINNER_SIZE / 2 - 40))
    else
        obj.lastAngle = nil
    end

    local progress = Clamp(obj.rotations / obj.required, 0, 1)
    local progressSize = math.max(1, (SPINNER_SIZE - BORDER * 2) * progress)
    spinner.progress:SetSize(progressSize, progressSize)
    if progress >= 1 then
        spinner.text:SetText("GESCHAFFT!")
    else
        spinner.text:SetText(string.format("%d / %d", math.floor(obj.rotations), obj.required))
    end

    if elapsed >= obj.endTime then
        local ratio = obj.rotations / obj.required
        obj.judged = true
        obj.finished = true
        if ratio >= 1 then
            hits = hits + 1
            local bonus = AwardComboPoints(100)
            ShowCursorFeedback("SPINNER  +" .. (100 + bonus), 0.35, 1, 0.5)
        elseif ratio >= 0.4 then
            hits = hits + 1
            local bonus = AwardComboPoints(100)
            ShowCursorFeedback("SPINNER  +" .. (100 + bonus), 1, 0.9, 0.25)
        else
            RegisterMiss("SPINNER ZU LANGSAM")
        end
    end
end

-- canceled: Der Spieler hat abgebrochen. Das zählt immer als nicht bestanden, auch wenn die
-- Punktzahl das Ziel zu diesem Zeitpunkt schon erreicht hatte.
local function StopGame(showResult, canceled)
    if not active then
        return
    end

    active = false
    frame:SetScript("OnUpdate", nil)
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
    heldKeys = {}
    SetKeyPropagation(true)
    cursorFeedbackFrame:Hide()
    feedbackExpiresAt = nil

    for _, obj in ipairs(activeObjects) do
        ReleaseView(obj)
    end
    activeObjects = {}

    if showResult then
        for _, obj in ipairs(objects) do
            if not obj.judged then
                obj.judged = true
                misses = misses + 1
            end
        end
        statusText:SetText((canceled and "Abgebrochen" or "Song beendet") .. " | Treffer: " .. hits .. " | Verfehlt: " .. misses)
        feedbackText:SetText("")
        closeButton:SetText("Schließen")
        UpdateScore()
        print("|cff2674cc[L|cffff0000i|rDL Roulette]|r Osu!: " .. song.title ..
            (canceled and " abgebrochen" or " beendet") .. ". Score: " .. score .. " | Treffer: " .. hits .. " | Verfehlt: " .. misses)

        -- Hilfe zum Kalibrieren: Klickst du im Schnitt zu spät, timingOffset erhöhen (und umgekehrt).
        if errorCount >= 15 then
            local meanError = errorSum / errorCount
            if math.abs(meanError) >= 0.02 then
                print(string.format(
                    "|cff2674cc[LiDL Roulette]|r Osu!: Du hast im Schnitt %.0f ms %s geklickt. Ändere timingOffset in OsuSongs.lua um %+.3f, falls es sich verschoben anfühlt.",
                    math.abs(meanError) * 1000, meanError > 0 and "zu spät" or "zu früh", meanError))
            end
        end

        local taxSilver = (canceled or score < targetScore) and addonTable:GetTaxSilver() or 0
        addonTable:OnLocalTimerEvent(
            challengeID,
            "OSUFINISHED",
            score,
            song.title,
            targetScore,
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

    local now = GetTime()
    if not musicStarted then
        local remaining = COUNTDOWN_SECONDS - (now - countdownAt)
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
        startedAt = now
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

    local elapsed = now - startedAt

    -- Neue Objekte einblenden
    while nextToShow <= #objects do
        local obj = objects[nextToShow]
        if elapsed < obj.spawnAt then
            break
        end
        nextToShow = nextToShow + 1
        if elapsed > obj.endTime + windows.w50 then
            -- Durch einen Hänger komplett verpasst
            obj.judged = true
            misses = misses + 1
            combo = 0
            scoreDirty = true
        else
            AcquireView(obj)
            table.insert(activeObjects, obj)
        end
    end

    local cursorX, cursorY = GetCursorInPlayfield()
    local held = IsActionDown()
    for index = #activeObjects, 1, -1 do
        local obj = activeObjects[index]
        if obj.kind == "spinner" then
            UpdateSpinner(obj, elapsed, cursorX, cursorY, held)
        else
            UpdateNote(obj, elapsed, cursorX, cursorY, held)
        end
        if obj.finished then
            ReleaseView(obj)
            table.remove(activeObjects, index)
        end
    end

    if feedbackExpiresAt and now >= feedbackExpiresAt then
        cursorFeedbackFrame:Hide()
        feedbackExpiresAt = nil
    end

    local currentSecond = math.floor(elapsed)
    if currentSecond ~= lastShownSecond then
        lastShownSecond = currentSecond
        timeText:SetText(string.format("%d:%02d", math.floor(currentSecond / 60), currentSecond % 60))
    end
    if scoreDirty then
        UpdateScore()
    end
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
    statusText:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    statusText:SetText(TIMING_INSTRUCTION)

    local timingLegend = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timingLegend:SetPoint("TOP", statusText, "BOTTOM", 0, -4)
    timingLegend:SetWidth(1000)
    timingLegend:SetJustifyH("CENTER")
    timingLegend:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    frame.timingLegend = timingLegend

    playfield = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    playfield:SetSize(PLAYFIELD_WIDTH, PLAYFIELD_HEIGHT)
    playfield:SetPoint("CENTER", frame, "CENTER", 0, -20)
    playfield:SetFrameLevel(frame:GetFrameLevel() + 1)
    playfield:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    playfield:SetBackdropColor(BG_COLOR[1], BG_COLOR[2], BG_COLOR[3], 1)
    playfield:SetBackdropBorderColor(0.25, 0.5, 0.72, 1)
    playfield:EnableMouse(true)
    playfield:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" or button == "RightButton" then
            HandleClick()
        end
    end)

    -- Y/X zählen wie ein Mausklick und werden während des Spiels nicht ans Spiel weitergegeben.
    frame:SetScript("OnKeyDown", function(_, key)
        if not active or not ACTION_KEYS[key] then
            SetKeyPropagation(true)
            return
        end

        SetKeyPropagation(false)
        if not heldKeys[key] then
            heldKeys[key] = true
            HandleClick()
        end
    end)
    frame:SetScript("OnKeyUp", function(_, key)
        if ACTION_KEYS[key] then
            heldKeys[key] = nil
            SetKeyPropagation(true)
        end
    end)

    -- Ebenen: Approach-Ringe < Slider-Körper < Kreise/Bälle < Spinner
    local baseLevel = playfield:GetFrameLevel()
    approachLayer = CreateFrame("Frame", nil, playfield)
    approachLayer:SetAllPoints()
    approachLayer:SetFrameLevel(baseLevel + 1)
    approachLayer:EnableMouse(false)
    bodyLayer = CreateFrame("Frame", nil, playfield)
    bodyLayer:SetAllPoints()
    bodyLayer:SetFrameLevel(baseLevel + 1 + LAYER_STEP)
    bodyLayer:EnableMouse(false)
    headLayer = CreateFrame("Frame", nil, playfield)
    headLayer:SetAllPoints()
    headLayer:SetFrameLevel(baseLevel + 1 + LAYER_STEP * 2)
    headLayer:EnableMouse(false)

    spinner = {}
    spinner.frame = CreateFrame("Frame", nil, playfield)
    spinner.frame:SetSize(SPINNER_SIZE, SPINNER_SIZE)
    spinner.frame:SetPoint("CENTER", playfield, "BOTTOMLEFT", PLAYFIELD_WIDTH / 2, PLAYFIELD_HEIGHT / 2)
    spinner.frame:SetFrameLevel(baseLevel + 1 + LAYER_STEP * 3)
    spinner.frame:EnableMouse(false)
    local spinnerBorder = CreateMaskedTexture(spinner.frame, "ARTWORK", 0)
    spinnerBorder:SetAllPoints()
    spinnerBorder:SetVertexColor(1, 1, 1, 0.9)
    local spinnerInner = CreateMaskedTexture(spinner.frame, "ARTWORK", 1)
    spinnerInner:SetPoint("TOPLEFT", spinner.frame, "TOPLEFT", BORDER, -BORDER)
    spinnerInner:SetPoint("BOTTOMRIGHT", spinner.frame, "BOTTOMRIGHT", -BORDER, BORDER)
    spinnerInner:SetVertexColor(BG_COLOR[1], BG_COLOR[2], BG_COLOR[3], 0.95)
    spinner.progress = CreateMaskedTexture(spinner.frame, "ARTWORK", 2)
    spinner.progress:SetPoint("CENTER")
    spinner.progress:SetVertexColor(RING_COLOR[1], RING_COLOR[2], RING_COLOR[3], 0.4)
    spinner.handle = CreateMaskedTexture(spinner.frame, "OVERLAY", 0)
    spinner.handle:SetSize(36, 36)
    spinner.handle:SetPoint("CENTER", spinner.frame, "CENTER", SPINNER_SIZE / 2 - 40, 0)
    spinner.handle:SetVertexColor(1, 1, 1, 0.95)
    spinner.text = spinner.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    spinner.text:SetPoint("CENTER")
    spinner.text:SetFont("Fonts\\FRIZQT__.TTF", 28, "OUTLINE")
    spinner.frame:Hide()

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
            StopGame(true, true)
        else
            frame:Hide()
        end
    end)
end

local function AreSectionsValid(sections)
    if #sections == 0 then
        return false
    end
    for _, section in ipairs(sections) do
        if type(section.startTime) ~= "number" or section.startTime < 0
            or type(section.bpm) ~= "number" or section.bpm < 30 or section.bpm > 300
            or type(section.stepsPerBeat) ~= "number" or section.stepsPerBeat < 1 or section.stepsPerBeat > 8
            or section.stepsPerBeat ~= math.floor(section.stepsPerBeat)
            or type(section.chart) ~= "string" then
            return false
        end
        local sectionChart = section.chart:gsub("%s", "")
        if #sectionChart == 0 or #sectionChart > MAX_CHART_STEPS or not sectionChart:match("^[osrp~%-]+$") then
            return false
        end
    end
    return true
end

function OsuUi:Start(challengeIDArg)
    local challenge = addonTable.Roulette.GetChallenge(challengeIDArg)
    if not challenge or not challenge.osu then
        print("|cffff0000[Lidl Roulette]|r Ungültige Osu!-Challenge.")
        return
    end

    -- Optional: Eine Challenge kann mit challenge.osuSong (Songtitel) einen bestimmten Song
    -- erzwingen. Songs mit exclusive = true werden nur auf diese Weise ausgewählt.
    -- Mit challenge.osuDifficulty kommen nur Songs dieser Schwierigkeitsstufe infrage.
    local requestedSong = challenge.osuSong
    local requestedDifficulty = challenge.osuDifficulty

    local validSongs = {}
    for _, candidate in ipairs(addonTable.OsuSongs or {}) do
        local sourceChart
        if type(candidate.osuSections) == "table" then
            -- eigenes Osu!-Chart: BuildObjects liest die Abschnitte direkt aus dem Song
            if AreSectionsValid(candidate.osuSections) then
                sourceChart = ""
            end
        else
            -- Chart wird aus dem Guitar-Hero-Song übernommen
            local chartSource
            for _, source in ipairs(addonTable.GuitarHeroSongs or {}) do
                if source.title == candidate.chartSourceTitle then
                    chartSource = source
                    break
                end
            end
            if chartSource and type(chartSource.chart) == "string" then
                local guitarChart = chartSource.chart:gsub("%s", ""):upper()
                if #guitarChart > 0 and #guitarChart <= 1024 and guitarChart:match("^[WASD%-]+$") then
                    sourceChart = guitarChart
                end
            end
        end

        if sourceChart
            and type(candidate.title) == "string"
            and (requestedSong == nil or candidate.title == requestedSong)
            and (requestedSong ~= nil or not candidate.exclusive)
            and (requestedDifficulty == nil or candidate.difficulty == requestedDifficulty)
            and type(candidate.bpm) == "number" and candidate.bpm >= 30 and candidate.bpm <= 300
            and type(candidate.duration) == "number" and candidate.duration > 0 and candidate.duration <= MAX_SONG_SECONDS
            and type(candidate.beatOffset) == "number" and candidate.beatOffset >= 0 and candidate.beatOffset < candidate.duration
            and type(candidate.timingOffset) == "number"
            and math.abs(candidate.timingOffset) <= MAX_TIMING_OFFSET
            and type(candidate.stepsPerBeat) == "number" and candidate.stepsPerBeat >= 1
            and candidate.stepsPerBeat <= 8 and candidate.stepsPerBeat == math.floor(candidate.stepsPerBeat)
            and (candidate.targetScore == nil or (
                type(candidate.targetScore) == "number"
                and candidate.targetScore > 0
                and candidate.targetScore % 1 == 0
            ))
            and type(candidate.music) == "string" and candidate.music ~= "" then
            table.insert(validSongs, { song = candidate, chart = sourceChart })
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
    PrepareKeyboard()

    local selected = validSongs[math.random(#validSongs)]
    local selectedWindows = DIFFICULTY[selected.song.difficulty] or DIFFICULTY.medium
    local builtObjects, maxScore = BuildObjects(selected.song, selected.chart, selectedWindows)
    if #builtObjects == 0 then
        print("|cffff0000[Lidl Roulette]|r Osu! konnte aus dem Chart keine Objekte erzeugen.")
        return
    end

    song = selected.song
    windows = selectedWindows
    challengeID = challengeIDArg
    objects = builtObjects
    activeObjects = {}
    targetScore = song.targetScore or math.floor(maxScore * (song.targetPercent or DEFAULT_TARGET_PERCENT))

    nextToShow = 1
    countdownAt = GetTime()
    lastCountdownNumber = COUNTDOWN_SECONDS
    lastShownSecond = nil
    score = 0
    hits = 0
    misses = 0
    combo = 0
    errorSum = 0
    errorCount = 0
    musicStarted = false
    active = true
    scoreDirty = false
    feedbackExpiresAt = nil
    cursorFeedbackFrame:Hide()

    local difficultyNames = { easy = "LEICHT", medium = "MITTEL", hard = "SCHWER", legendary = "LEGENDÄR" }
    songText:SetText(song.title .. "  |  " .. (difficultyNames[song.difficulty] or string.upper(song.difficulty or "MITTEL")))
    timeText:SetText("0:00")
    statusText:SetText(TIMING_INSTRUCTION)
    frame.timingLegend:SetText(string.format(
        "|cff59ff7aPERFEKT  ±%.3f s|r     |cffffdf4aGUT  ±%.3f s|r     |cffff9a42KNAPP  ±%.3f s|r     |cffffffffDaneben = Fehlschlag|r",
        windows.w300, windows.w100, windows.w50))
    feedbackText:SetText(tostring(COUNTDOWN_SECONDS))
    feedbackText:SetTextColor(1, 1, 1)
    closeButton:SetText("Abbrechen")
    UpdateScore()

    frame:Show()
    frame:Raise()
    frame:SetScript("OnUpdate", UpdateGame)
end