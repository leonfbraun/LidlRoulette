local addonName, addonTable = ...

addonTable.BayonettaComboUi = {}
local ComboUi = addonTable.BayonettaComboUi

local COMBO_TIMEOUT = 8
local SPELL_HIT_WINDOW = 1.25
local MAX_METER_POINTS = 100
local MUSIC_FADE_SECONDS = 3
local frame
local musicFrame
local variantTitle
local pointsText
local pointsLabel
local medalText
local countdownText
local meter
local accent
local comboPoints = 0
local highScore = 0
local lastHitTime
local pendingSpellHitUntil
local activeVariant
local isActive = false
local isPaused = false
local musicVolumeBeforeCombo
local comboMusicPlaying = false

local variants = {
    [1] = {
        name = "BAYONETTA I",
        subtitle = "UMBRAN WITCH",
        music = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\Bayonetta1.ogg",
        background = { 0.035, 0.012, 0.035, 0.96 },
        border = { 0.78, 0.24, 0.48, 1 },
        accent = { 0.95, 0.18, 0.38, 1 },
        score = { 1, 0.78, 0.42 },
    },
    [2] = {
        name = "BAYONETTA II",
        subtitle = "WITCH TIME",
        music = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\Bayonetta2.ogg",
        background = { 0.012, 0.035, 0.075, 0.96 },
        border = { 0.26, 0.7, 0.92, 1 },
        accent = { 0.2, 0.82, 1, 1 },
        score = { 0.72, 0.92, 1 },
    },
}

local medals = {
    { points = 80, name = "PURE PLATINUM", color = { 0.8, 0.95, 1 } },
    { points = 50, name = "PLATINUM", color = { 0.65, 0.86, 1 } },
    { points = 30, name = "GOLD", color = { 1, 0.78, 0.2 } },
    { points = 15, name = "SILVER", color = { 0.82, 0.86, 0.92 } },
    { points = 5, name = "BRONZE", color = { 0.83, 0.49, 0.28 } },
    { points = 0, name = "STONE", color = { 0.72, 0.72, 0.76 } },
}

local function FadeMusicVolume(targetVolume, onFinished)
    musicFrame = musicFrame or CreateFrame("Frame")
    local startVolume = tonumber(GetCVar("Sound_MusicVolume")) or targetVolume
    local elapsed = 0

    musicFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        local progress = math.min(elapsed / MUSIC_FADE_SECONDS, 1)
        local volume = startVolume + (targetVolume - startVolume) * progress
        SetCVar("Sound_MusicVolume", string.format("%.3f", volume))

        if progress >= 1 then
            self:SetScript("OnUpdate", nil)
            if onFinished then
                onFinished()
            end
        end
    end)
end

local function StartComboMusic()
    if not activeVariant then
        return
    end

    musicFrame = musicFrame or CreateFrame("Frame")
    musicFrame:SetScript("OnUpdate", nil)

    if musicVolumeBeforeCombo == nil then
        musicVolumeBeforeCombo = tonumber(GetCVar("Sound_MusicVolume"))
    end
    if musicVolumeBeforeCombo == nil then
        return
    end

    SetCVar("Sound_MusicVolume", "0")
    PlayMusic(activeVariant.music)
    comboMusicPlaying = true
    FadeMusicVolume(musicVolumeBeforeCombo)
end

local function StopComboMusic()
    if not comboMusicPlaying or musicVolumeBeforeCombo == nil then
        return
    end

    local originalVolume = musicVolumeBeforeCombo
    FadeMusicVolume(0, function()
        StopMusic()
        SetCVar("Sound_MusicVolume", tostring(originalVolume))
        musicVolumeBeforeCombo = nil
        comboMusicPlaying = false
    end)
end

local function Initialize()
    if frame then
        return
    end

    frame = CreateFrame("Frame", "LidlRouletteBayonettaComboFrame", UIParent, "BackdropTemplate")
    frame:SetSize(380, 165)
    frame:SetPoint("RIGHT", UIParent, "RIGHT", -90, 40)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    accent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 8)
    accent:SetWidth(4)

    variantTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    variantTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -16)
    variantTitle:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")

    pointsText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    pointsText:SetPoint("CENTER", frame, "CENTER", 0, 15)
    pointsText:SetWidth(330)
    pointsText:SetJustifyH("CENTER")
    pointsText:SetFont("Fonts\\FRIZQT__.TTF", 48, "OUTLINE")

    pointsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pointsLabel:SetPoint("TOP", pointsText, "BOTTOM", 0, -1)
    pointsLabel:SetText("COMBO POINTS")
    pointsLabel:SetTextColor(0.9, 0.87, 0.94)

    medalText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    medalText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 34)
    medalText:SetWidth(210)
    medalText:SetJustifyH("LEFT")
    medalText:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")

    countdownText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    countdownText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 34)
    countdownText:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
    countdownText:SetTextColor(1, 0.4, 0.55)

    meter = CreateFrame("StatusBar", nil, frame)
    meter:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 16)
    meter:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 16)
    meter:SetHeight(6)
    meter:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    meter:SetMinMaxValues(0, MAX_METER_POINTS)
    meter:SetValue(0)

    frame:SetScript("OnEvent", function(_, event, unit, action)
        if not isActive or isPaused then
            return
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if unit == "player" and UnitCanAttack("player", "target") then
                pendingSpellHitUntil = GetTime() + SPELL_HIT_WINDOW
            end
            return
        end

        if event == "UNIT_COMBAT" and unit == "target"
            and UnitCanAttack("player", "target") and action == "WOUND" then
            local points = pendingSpellHitUntil and GetTime() <= pendingSpellHitUntil and 2 or 1
            pendingSpellHitUntil = nil
            ComboUi:RegisterHit(points)
        end
    end)

    frame:Hide()
end

local function GetMedal(points)
    for _, medal in ipairs(medals) do
        if points >= medal.points then
            return medal
        end
    end
    return medals[#medals]
end

local function ApplyVariant()
    frame:SetBackdropColor(activeVariant.background[1], activeVariant.background[2], activeVariant.background[3], activeVariant.background[4])
    frame:SetBackdropBorderColor(activeVariant.border[1], activeVariant.border[2], activeVariant.border[3], activeVariant.border[4])
    accent:SetColorTexture(activeVariant.accent[1], activeVariant.accent[2], activeVariant.accent[3], activeVariant.accent[4])
    variantTitle:SetText(activeVariant.name .. "  /  " .. activeVariant.subtitle)
    variantTitle:SetTextColor(activeVariant.score[1], activeVariant.score[2], activeVariant.score[3])
    pointsText:SetTextColor(activeVariant.score[1], activeVariant.score[2], activeVariant.score[3])
    meter:SetStatusBarColor(activeVariant.accent[1], activeVariant.accent[2], activeVariant.accent[3])
end

local function ResetCombo()
    comboPoints = 0
    lastHitTime = nil
    pendingSpellHitUntil = nil
    if frame then
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
    end
    if countdownText then
        countdownText:SetText("")
    end
    StopComboMusic()
end

local function UpdateComboCountdown()
    if not lastHitTime then
        return
    end

    local remaining = math.max(0, COMBO_TIMEOUT - (GetTime() - lastHitTime))
    countdownText:SetText(string.format("COMBO %.1fs", remaining))
    if remaining <= 0 then
        ResetCombo()
    end
end

function ComboUi:RegisterHit(points)
    if not isActive or isPaused then
        return
    end

    Initialize()
    local wasVisible = frame:IsShown()
    if not wasVisible and not activeVariant then
        activeVariant = variants[math.random(2)]
        ApplyVariant()
    end
    comboPoints = comboPoints + points
    highScore = math.max(highScore, comboPoints)
    lastHitTime = GetTime()

    local medal = GetMedal(comboPoints)
    pointsText:SetText(tostring(comboPoints))
    medalText:SetText(medal.name)
    medalText:SetTextColor(medal.color[1], medal.color[2], medal.color[3])
    meter:SetValue(math.min(comboPoints, MAX_METER_POINTS))
    countdownText:SetText(string.format("COMBO %.1fs", COMBO_TIMEOUT))
    frame:Show()
    if not wasVisible then
        StartComboMusic()
    end
    frame:SetScript("OnUpdate", UpdateComboCountdown)
end

function ComboUi:Start()
    Initialize()
    ResetCombo()
    comboPoints = 0
    highScore = 0
    pendingSpellHitUntil = nil
    activeVariant = nil
    isActive = true
    isPaused = false
    frame:RegisterUnitEvent("UNIT_COMBAT", "target")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
end

function ComboUi:Pause()
    if not isActive or isPaused then
        return
    end

    isPaused = true
    frame:UnregisterEvent("UNIT_COMBAT")
    frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    frame:SetScript("OnUpdate", nil)
    StopComboMusic()
end

function ComboUi:Resume()
    if not isActive or not isPaused then
        return
    end

    isPaused = false
    if frame:IsShown() then
        lastHitTime = GetTime()
        countdownText:SetText(string.format("COMBO %.1fs", COMBO_TIMEOUT))
        StartComboMusic()
        frame:SetScript("OnUpdate", UpdateComboCountdown)
    end
    pendingSpellHitUntil = nil
    frame:RegisterUnitEvent("UNIT_COMBAT", "target")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
end

function ComboUi:Stop()
    local finalHighScore = isActive and highScore or nil
    if frame then
        if frame:IsEventRegistered("UNIT_COMBAT") then
            frame:UnregisterEvent("UNIT_COMBAT")
        end
        if frame:IsEventRegistered("UNIT_SPELLCAST_SUCCEEDED") then
            frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        end
    end
    isActive = false
    isPaused = false
    ResetCombo()
    comboPoints = 0
    highScore = 0
    activeVariant = nil
    return finalHighScore
end