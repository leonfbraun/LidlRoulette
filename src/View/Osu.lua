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
}
local EARLY_MISS_SECONDS = 0.08 -- Klick knapp vor dem Fenster zählt als Fehler (gegen Spammen)

-- Slider
local SLIDER_SPEED = 260        -- Pixel pro Sekunde
local MIN_SLIDER_SECONDS = 0.5
local MAX_SLIDER_SECONDS = 1.6
local MIN_SLIDER_LENGTH = 120
local MAX_SLIDER_LENGTH = 420
local FOLLOW_RADIUS = CIRCLE_SIZE * 0.95
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

local TIMING_INSTRUCTION = "Klicke, wenn der Ring den Kreis berührt  |  Slider: Taste halten und dem Ball folgen  |  Spinner: halten und um die Mitte kreisen"
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
    return IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
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

    -- Slider-Körper: zwei dicke Linien (Rand + Füllung) und eine runde Endkappe.
    view.body = CreateFrame("Frame", nil, bodyLayer)
    view.body:SetAllPoints(playfield)
    view.outline = view.body:CreateLine(nil, "BACKGROUND", nil, 0)
    view.outline:SetThickness(CIRCLE_SIZE)
    view.outline:SetColorTexture(1, 1, 1, 1)
    view.capBorder = CreateMaskedTexture(view.body, "BACKGROUND", 0)
    view.capBorder:SetSize(CIRCLE_SIZE, CIRCLE_SIZE)
    view.capBorder:SetVertexColor(1, 1, 1, 1)
    view.fillLine = view.body:CreateLine(nil, "BACKGROUND", nil, 1)
    view.fillLine:SetThickness(CIRCLE_SIZE - BORDER * 2)
    view.fillLine:SetColorTexture(INNER_COLOR[1], INNER_COLOR[2], INNER_COLOR[3], 1)
    view.capInner = CreateMaskedTexture(view.body, "BACKGROUND", 1)
    view.capInner:SetSize(CIRCLE_SIZE - BORDER * 2, CIRCLE_SIZE - BORDER * 2)
    view.capInner:SetVertexColor(INNER_COLOR[1], INNER_COLOR[2], INNER_COLOR[3], 1)

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
    view.ball:SetFrameLevel(headLayer:GetFrameLevel() + 5)
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
        view.outline:SetStartPoint("BOTTOMLEFT", view.body, obj.x, obj.y)
        view.outline:SetEndPoint("BOTTOMLEFT", view.body, obj.x2, obj.y2)
        view.fillLine:SetStartPoint("BOTTOMLEFT", view.body, obj.x, obj.y)
        view.fillLine:SetEndPoint("BOTTOMLEFT", view.body, obj.x2, obj.y2)
        view.capBorder:ClearAllPoints()
        view.capBorder:SetPoint("CENTER", view.body, "BOTTOMLEFT", obj.x2, obj.y2)
        view.capInner:ClearAllPoints()
        view.capInner:SetPoint("CENTER", view.body, "BOTTOMLEFT", obj.x2, obj.y2)
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
local function IsPositionClear(x, y, spawnAt, list)
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
            for _, point in ipairs(other.points) do
                local dx = x - point[1]
                local dy = y - point[2]
                if dx * dx + dy * dy < SPACING * SPACING then
                    return false
                end
            end
        end
    end

    return true
end

local function GetNextPosition(previousX, previousY, timeSincePrevious, spawnAt, list, rng)
    if not previousX then
        return PLAYFIELD_WIDTH / 2, PLAYFIELD_HEIGHT / 2
    end

    local maxDistance = math.min(MAX_NOTE_DISTANCE, SPACING + 8 + math.max(0, timeSincePrevious - 0.25) * 70)
    local minDistance = math.min(SPACING, maxDistance)

    for _ = 1, 64 do
        local angle = rng() * PI * 2
        local distance = minDistance + rng() * (maxDistance - minDistance)
        local x = previousX + math.cos(angle) * distance
        local y = previousY + math.sin(angle) * distance
        if InBounds(x, y) and IsPositionClear(x, y, spawnAt, list) then
            return x, y
        end
    end

    -- Fallback: freiester Punkt im Spielfeld, am weitesten vom letzten Objekt entfernt.
    local bestX
    local bestY
    local bestDistance = -1
    for x = EDGE_MARGIN, PLAYFIELD_WIDTH - EDGE_MARGIN, 12 do
        for y = EDGE_MARGIN, PLAYFIELD_HEIGHT - EDGE_MARGIN, 12 do
            if IsPositionClear(x, y, spawnAt, list) then
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

    if not bestX then
        bestX = EDGE_MARGIN + rng() * (PLAYFIELD_WIDTH - EDGE_MARGIN * 2)
        bestY = EDGE_MARGIN + rng() * (PLAYFIELD_HEIGHT - EDGE_MARGIN * 2)
    end
    return bestX, bestY
end

-- Gibt Liste der Objekte und die maximal erreichbare Punktzahl zurück.
-- Ablauf: Jede Note des Guitar-Hero-Charts wird zum Kreis. Ist danach eine
-- ausreichend große Lücke, wird daraus (mit Wahrscheinlichkeit sliderChance) ein
-- Slider, bei sehr großer Lücke ein Spinner. Der Zufall ist pro Song fest geseedet,
-- jeder Durchlauf sieht also gleich aus.
local function BuildObjects(songData, chart, diff)
    local list = {}
    local stepDuration = 60 / songData.bpm / songData.stepsPerBeat
    local rng = MakeRng(songData.title)
    local tickInterval = math.max(0.25, 60 / songData.bpm)
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

    local maxScore = 0
    local maxCombo = 0
    local comboNumber = 0
    local previousX
    local previousY
    local previousEnd

    for index, hitAt in ipairs(noteTimes) do
        local nextHitAt = noteTimes[index + 1] or songData.duration
        local gap = nextHitAt - hitAt
        local time = hitAt + songData.timingOffset
        local obj = { kind = "circle", time = time, endTime = time, judged = false }

        local sliderSeconds = 0
        if allowSpinners and gap >= SPINNER_MIN_GAP then
            local spinSeconds = math.min(gap - SPINNER_LEAD_OUT, SPINNER_MAX_SECONDS)
            if spinSeconds >= SPINNER_MIN_SECONDS then
                obj.kind = "spinner"
                obj.endTime = time + spinSeconds
                obj.spawnAt = time - 0.25
            end
        end
        if obj.kind == "circle" then
            local available = math.min(gap - stepDuration, MAX_SLIDER_SECONDS)
            available = math.floor(available / stepDuration) * stepDuration
            if available >= MIN_SLIDER_SECONDS and rng() < sliderChance then
                sliderSeconds = available - 0.05 -- Slider-Ende wird minimal früher gewertet
                obj.kind = "slider"
                obj.endTime = time + sliderSeconds
            end
        end
        if obj.kind ~= "spinner" then
            obj.spawnAt = time - APPROACH_SECONDS
        end

        if obj.kind == "spinner" then
            obj.x = PLAYFIELD_WIDTH / 2
            obj.y = PLAYFIELD_HEIGHT / 2
            obj.required = math.max(2, math.floor((obj.endTime - time) * SPIN_PER_SECOND))
            obj.rotations = 0
            maxCombo = maxCombo + 1
            maxScore = maxScore + 100 + GetComboBonus(maxCombo)
        else
            comboNumber = comboNumber + 1
            obj.number = (comboNumber - 1) % 9 + 1
            obj.x, obj.y = GetNextPosition(
                previousX,
                previousY,
                previousEnd and time - previousEnd or 0,
                obj.spawnAt,
                list,
                rng
            )
            obj.points = { { obj.x, obj.y } }
            maxCombo = maxCombo + 1
            maxScore = maxScore + 300 + GetComboBonus(maxCombo)

            if obj.kind == "slider" then
                local length = Clamp(sliderSeconds * SLIDER_SPEED, MIN_SLIDER_LENGTH, MAX_SLIDER_LENGTH)
                local found = false
                for _ = 1, 32 do
                    local angle = rng() * PI * 2
                    local x2 = obj.x + math.cos(angle) * length
                    local y2 = obj.y + math.sin(angle) * length
                    if InBounds(x2, y2) then
                        local points = {}
                        local clear = true
                        for step = 1, 4 do
                            local progress = step / 4
                            local px = obj.x + (x2 - obj.x) * progress
                            local py = obj.y + (y2 - obj.y) * progress
                            if not IsPositionClear(px, py, obj.spawnAt, list) then
                                clear = false
                                break
                            end
                            table.insert(points, { px, py })
                        end
                        if clear then
                            obj.x2 = x2
                            obj.y2 = y2
                            for _, point in ipairs(points) do
                                table.insert(obj.points, point)
                            end
                            found = true
                            break
                        end
                    end
                end

                if found then
                    obj.ticks = {}
                    obj.nextTick = 1
                    obj.lastTracked = -1000
                    local tickTime = time + tickInterval
                    while tickTime < obj.endTime - 0.12 do
                        table.insert(obj.ticks, tickTime)
                        tickTime = tickTime + tickInterval
                    end
                    for _ = 1, #obj.ticks do
                        maxCombo = maxCombo + 1
                        maxScore = maxScore + 10 + GetComboBonus(maxCombo)
                    end
                    maxCombo = maxCombo + 1
                    maxScore = maxScore + 30 + GetComboBonus(maxCombo)
                else
                    obj.kind = "circle" -- kein Platz für den Slider: normaler Kreis
                    obj.endTime = time
                end
            end
        end

        table.insert(list, obj)
        if obj.kind == "slider" then
            previousX, previousY = obj.x2, obj.y2
        else
            previousX, previousY = obj.x, obj.y
        end
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
    local ballX = obj.x + (obj.x2 - obj.x) * progress
    local ballY = obj.y + (obj.y2 - obj.y) * progress
    view.ball:ClearAllPoints()
    view.ball:SetPoint("CENTER", playfield, "BOTTOMLEFT", ballX, ballY)
    view.ball:Show()

    local dx = cursorX - ballX
    local dy = cursorY - ballY
    if held and dx * dx + dy * dy <= FOLLOW_RADIUS * FOLLOW_RADIUS then
        obj.lastTracked = elapsed
    end

    while obj.ticks[obj.nextTick] and elapsed >= obj.ticks[obj.nextTick] do
        obj.nextTick = obj.nextTick + 1
        if elapsed - obj.lastTracked <= TRACK_GRACE_SECONDS then
            AwardComboPoints(10)
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

local function StopGame(showResult)
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
        statusText:SetText("Song beendet | Treffer: " .. hits .. " | Verfehlt: " .. misses)
        closeButton:SetText("Schließen")
        UpdateScore()
        print("|cff2674cc[L|cffff0000i|rDL Roulette]|r Osu!: " .. song.title ..
            " beendet. Score: " .. score .. " | Treffer: " .. hits .. " | Verfehlt: " .. misses)

        -- Hilfe zum Kalibrieren: Klickst du im Schnitt zu spät, timingOffset erhöhen (und umgekehrt).
        if errorCount >= 15 then
            local meanError = errorSum / errorCount
            if math.abs(meanError) >= 0.02 then
                print(string.format(
                    "|cff2674cc[LiDL Roulette]|r Osu!: Du hast im Schnitt %.0f ms %s geklickt. Ändere timingOffset in OsuSongs.lua um %+.3f, falls es sich verschoben anfühlt.",
                    math.abs(meanError) * 1000, meanError > 0 and "zu spät" or "zu früh", meanError))
            end
        end

        local taxSilver = score < targetScore and addonTable:GetTaxSilver() or 0
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

    -- Ebenen: Approach-Ringe < Slider-Körper < Kreise/Bälle < Spinner
    local baseLevel = playfield:GetFrameLevel()
    approachLayer = CreateFrame("Frame", nil, playfield)
    approachLayer:SetAllPoints()
    approachLayer:SetFrameLevel(baseLevel + 1)
    approachLayer:EnableMouse(false)
    bodyLayer = CreateFrame("Frame", nil, playfield)
    bodyLayer:SetAllPoints()
    bodyLayer:SetFrameLevel(baseLevel + 10)
    bodyLayer:EnableMouse(false)
    headLayer = CreateFrame("Frame", nil, playfield)
    headLayer:SetAllPoints()
    headLayer:SetFrameLevel(baseLevel + 20)
    headLayer:EnableMouse(false)

    spinner = {}
    spinner.frame = CreateFrame("Frame", nil, playfield)
    spinner.frame:SetSize(SPINNER_SIZE, SPINNER_SIZE)
    spinner.frame:SetPoint("CENTER", playfield, "BOTTOMLEFT", PLAYFIELD_WIDTH / 2, PLAYFIELD_HEIGHT / 2)
    spinner.frame:SetFrameLevel(baseLevel + 30)
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
            and type(candidate.title) == "string"
            and type(candidate.bpm) == "number" and candidate.bpm >= 30 and candidate.bpm <= 300
            and type(candidate.duration) == "number" and candidate.duration > 0 and candidate.duration <= 180
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

    local difficultyNames = { easy = "LEICHT", medium = "MITTEL", hard = "SCHWER" }
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